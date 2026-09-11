# Dossier — the working conventions of `xschem-claude`, for the ASE-L analyses plan

**Area:** house rules, spec-of-record content on ANALYSES, prior art to cite, and the exact
shape the new plan document must take.
**Repos read (read-only, nothing mutated):** `/home/analog/dev/xschem-claude` at branch
`fluid-editing`, HEAD `5fb8f465` with an uncommitted working tree (see §1.4).
**Anchor convention in this dossier:** every claim carries `path:LINE` relative to
`/home/analog/dev/xschem-claude/` unless stated otherwise. Line numbers were read on
2026-09-09 against the working tree, which is NOT clean — see §1.4 and §10.2 on why the
plan itself should cite *section names*, not line ranges.

---

## 0. The one-paragraph version

This tree runs on a very specific working style: **a batch directory per unit of work**
(`doc/claude/<slug>_batch/`) containing `CREW_BRIEF.md` + `PLAN.md` + `DECISIONS.md` +
`LEDGER.md` (+ `receipts/`), with **numbered items** that each name their files, their
suite rows, their acceptance and their debts; **one spec of record per feature** under
`doc/claude/specs/` that the batch must amend when it lands; **one numbering authority**
(`doc/claude/issues/NUMBERING.md`) that must be advanced in the same commit as any issue
it mints; and **three ledger debt kinds** (`rule` / `look` / `suite`) that record what the
work still owes the USER. Testing is not "add a test" — it is *raise a named suite's floor,
never lower it, sabotage-verify the new rows, run `run_regression.tcl` solo, and report T1
at ZERO*. The ASE-L spec of record (`doc/claude/specs/ase_l.md`) currently specifies
**exactly four analyses — op, dc, ac, tran** — hardcoded in three places, with a measured
silent-drop failure for anything else; a fifth type is a **spec change plus new
user-facing strings that need the user's ratification**, and it collides with a hard
byte-identity constraint on **105 committed `.state` files**.

---

## 1. The house rules a plan author must honour

### 1.1 From `CLAUDE.md` (repo root) — the load-bearing ones for this work

| rule | anchor | what it means for an analyses plan |
|---|---|---|
| **Give the binary a path.** Never a bare `xschem`. `/usr/local/bin/xschem` is **3.4.6 from Jan 2025**, predates issue 0119, and rewrites `~/.xschem/recent_files`. One run of it emptied the user's *File > Open Recent* (issue **0924**). | `CLAUDE.md`, "Tests" bullet 3 | Every probe/measurement line in the plan writes `./src/xschem`, `$XSCHEM`, or `devdisplay.sh exec ./src/xschem`. |
| **Run `run_regression.tcl` SOLO.** Two at once corrupt each other; the loser prints a `FATAL` that never happened. `exit -1` is the tell. Filed as **0990**. | `CLAUDE.md`, "⚠ RUN `run_regression.tcl` SOLO" | The plan's acceptance section says "T1 solo". A T1 number taken while another suite was live is not evidence. |
| **T1's baseline is ZERO counted failures.** "A standing red is a defect, not furniture." Eight issue files were filed four times each because crews carried "3 FAIL — pre-existing" forward. | `CLAUDE.md`, "T1's baseline is ZERO" | The plan must not permit "pre-existing" in a receipt. If T1 is not zero, say which case and why, per case. |
| **No test harness builds.** `full_audit.sh:49` runs `$REPO/src/xschem` as it finds it. A correct source tree + a stale binary produces a *plausible* audit. **Rebuild before any audit that is meant to be evidence.** | `CLAUDE.md`, "⚠ NO TEST HARNESS BUILDS" | Any item that touches `src/*.tcl` only still needs the reader to know Tcl is sourced at runtime — but any item touching C (none expected here) must rebuild. |
| **The dev display.** `tests/headless/devdisplay.sh start` (Xvfb `:99` + openbox), and the arm `tests/headless/xvfb_arm.sh` is the default for `full_audit.sh` / `run_suites.sh` / `gated_xschem.sh`. `AUDIT_SCREEN` default `1920x1080x24` — **pin it**, never `1600x1200`. | `CLAUDE.md`, "The persistent dev display", "The display arm" | GUI rows for a new Choose-Analyses form run on `:99`; the `:0` run is a *deliberate* extra. |
| **There are THREE X servers here and `:0` is not the user's screen.** `:0` = WSLg Xwayland; `$DISPLAY` = `<win-ip>:0`, the Windows X server the user actually looks at; `:99` = Xvfb. `AUDIT_DISPLAY=:0` exports the literal `:0` (`tests/headless/xvfb_arm.sh:140`). | `CLAUDE.md`, "⚠ THERE ARE THREE X SERVERS HERE" | A look debt that says "on the user's real screen" must be paid with `AUDIT_DISPLAY=$DISPLAY` or by hand. Do not "correct" WSLg to VcXsrv in any doc. |
| **The GUI-test control gate** lives in the harness (`tests/headless/gui_gate.sh`), **not** a Claude Code settings hook — a prior hook-based gate died silently when `settings.local.json` was rewritten; **do not reintroduce it as a hook**. It fails open (no `DISPLAY`, `GUI_GATE=0`, closed panel → tests just run). `GUI_GATE=0` is *forced* by the Xvfb arm. | `CLAUDE.md`, "GUI-test control gate"; spec `doc/claude/specs/gui_test_gate.md:1-40` | See §4 — yes, there is a GUI test gate; it is now *rare* by design and a panel popping for a routine suite is a symptom. |
| **The owed ledger** (`tests/headless/owed.sh`): `add rule <id>` (a ruling owed by the user), `add look <what>` (pixel deliverable), `add suite <name>` (a `:0` run). `rule` and `look` are the user's queue and **clear only when the user says so**; `suite` clears itself on a pass. **No command converts one kind into another.** | `CLAUDE.md`, "The owed ledger"; spec `doc/claude/specs/owed.md:1-100` | Every new analysis field label, unit string, refusal sentence and dialog caption in this plan is a `rule` debt. Every new form's appearance is a `look` debt. |
| **Issue numbers: `doc/claude/issues/NUMBERING.md` is the ONLY authority.** Read its *tail*. Do not trust a number quoted anywhere else, *including CLAUDE.md itself*, which was wrong by 700+ for months. Record the new number in `NUMBERING.md` **as part of the same commit**. | `CLAUDE.md`, "Issue numbers" | See §2. |
| **AI/planning docs live under `doc/claude/`** and are not installed (`doc/Makefile` ships only `*.svg/*.html/*.css/*.png`). Source comments reference them **by full path**. | `CLAUDE.md`, "AI / planning docs" | The plan will be cited from `src/ase.tcl` / `src/ase_window.tcl` comments as `doc/claude/...`; keep the path stable once chosen. |
| **`src/xschem.tcl` ↔ C mirroring** (`MIRRORED IN TCL` in `xschem.h`) and the `xschem <subcommand>` dispatcher in `scheduler.c`. | `CLAUDE.md`, "Layering", "The `xschem` Tcl command" | ASE-L is **pure Tcl** by decision (§5.1 D4). An analyses plan that needs C is out of the spec's stated shape and must say so loudly. |
| **Editing `src/Makefile.in` obliges you to re-run `./configure`** — `src/Makefile` is generated with no self-regeneration rule; an un-installed helper segfaults the installed binary at startup (issues 0423/0424). Verify with `grep -c <newfile> src/Makefile` — expect **2**. | `CLAUDE.md`, "Build & run" | Only relevant if the plan adds a NEW `.tcl` file (e.g. a separate analyses module). If it does, this check is a mandatory line in that item. |

### 1.2 Standing crew rules — from the `CREW_BRIEF.md` family

These are not in `CLAUDE.md`; they are re-stated in every batch brief and are the
operational half of the house style. The canonical current copy is
`doc/claude/ase_l_ux_batch/CREW_BRIEF.md:12-38` ("Standing rules every crew obeys"):

- Give the binary a path (as above, issue 0924).
- **Every launch carries `--nolog`. Never `--logdir`.** Two reasons, both measured:
  `--logdir` changed the thing under test and produced two false reds in
  `test_ase_core` NT17/NT18 (`doc/claude/ase_registry_batch/CREW_BRIEF.md`, "A METHOD
  CORRECTION"), and the user's own action log is `/tmp/Xschem.log.N` — **do not write to
  it**; issue **1359** is the scar, "a crew destroyed this user's log twice in the last
  session" (`doc/claude/rdw_sim_batch/CREW_BRIEF.md:50-55`).
- **Never touch, move, back up or read-modify-write anything under `~/.xschem/`.**
  ⚠ **A SIMULATION RUN IS SUCH A WRITE.** `ase::rundir` with an empty `rundir` key returns
  `set_netlist_dir 0` — `~/.xschem/simulations`, one global directory for every state of
  every cell. **No crew runs a simulation on a bench under `sky130A/`**; a probe that needs
  a run uses a scratch library and an explicit `rundir`. Reading is fine.
  The incident: `doc/claude/ase_l_ux_batch/LEDGER.md:3-40` — an audit agent's run destroyed
  the user's `tb_bandgap_ase.raw` (a 20502-point transient) and truncated its log.
- **Never** `git checkout --`, `git restore`, `git stash`, `git clean` against uncommitted
  work. **Never `git push`, never open a PR.** Sabotage restores are done by `cp` from a
  pristine copy plus an md5 compare (`doc/claude/ase_l_ux_batch/LEDGER.md`, "Sabotage").
- **Floors are RAISED when rows are added and NEVER lowered.**
- **UI copy is terse and acronyms are UPPERCASE** (MOS, SPICE, PDK, OP, ASE-L, CIW, PATH).
- **A new user-facing sentence is the USER'S ruling, not a crew's.** Mint it, ship it, and
  record `owed.sh add rule` for it. Never leave it in a write-up only.
- **A pixel deliverable is never "done" on a green suite.** Record `owed.sh add look` and
  say "suites green, please look".
- **Report the user's words verbatim; do not paraphrase them in issue files**
  (`doc/claude/rdw_sim_batch/CREW_BRIEF.md:3`).

Two more that recur and matter here:

- **Suites must be hermetic about the developer's `HOME`.** Four ASE suites went red only
  because they read the developer's real `~/.xschem/ase_simulators`
  (`doc/claude/ase_registry_batch/CREW_BRIEF.md`, "A NEW DEFECT … item 1377"). Since then
  the pattern is a **scratch `HOME`** plus
  `XSCHEM_DEVDISPLAY_DIR=$HOME_REAL/.claude/xschem_dev_display`, because `devdisplay.sh`,
  `gui_gate.sh`, `xvfb_arm.sh` and `spawn_reaper.sh` all resolve their state dir under
  `$HOME` and a bare scratch `HOME` silently produces a "clean zero" that verified nothing
  (`doc/claude/ase_l_ux_batch/LEDGER.md`, "Operational notes from item 1").
  Issue **1397** is the open filing.
- **Full parallelism can OOM this box.** `test_njobs` = CPUs − 4 with no knob;
  `taskset -c 0-7` in front of `tclsh` is the external knob
  (`doc/claude/ase_l_ux_batch/LEDGER.md`, same section).

### 1.3 Commit style

Conventional-commit *prefix* with the **issue number(s) in the parentheses**, then a
sentence — not a noun phrase — in the tree's own voice. Measured over the last 40 subjects
(`git log --format=%s -40`):

```
fix(1396): Save State asked nothing before it destroyed an existing state
fix(1395): the simulator registry is environment, the choice is the bench's
fix(0643): Netlist and Run works from inside the design, because ADE-L has no such rule
feat(1382,1384,1388): the RDW gets a Close button, the sheet says what the pick is waiting for, …
batch(ase_registry): seven simulator-registry loose ends, and the reason the suites could not see them
docs(ase-l): a measured UX audit of ASE-L, and the look debts you closed
tools(look): this tree could not photograph its own dialogs, and the first photograph found 1379
```

Prefixes in use: `fix`, `feat`, `docs`, `batch`, `tools`. Scope is either the issue
number list or an area slug (`ase-l`, `rdw`, `ciw,rdw`, `annotation`, `blog`, `look`).
Lowercase after the colon. Long, declarative, states the *defect or the gain*, not the
diff. A batch's planning commit is its own `batch(<slug>): …` commit landed **before** the
item commits, so item commits' citations resolve
(`doc/claude/ase_l_ux_batch/LEDGER.md`: "The UX audit … went in first, as `66992a1d`, so
this commit's citations resolve").

### 1.4 The tree is not clean — state this in the plan's preflight

At the time of reading, `git status --short` showed modified `src/ase_window.tcl`,
`src/xschem.tcl`, `tests/headless/test_ase_window.tcl`,
`doc/claude/ase_l_ux_batch/LEDGER.md`, `doc/claude/issues/NUMBERING.md`, plus an untracked
`.xschem/` and new PNGs under `doc/claude/ase_l_ux_batch/shots/`. **The `NUMBERING.md`
tail's "next free number is 1400" is an UNCOMMITTED value** (it reads 1398 at HEAD; the
diff adds 1398 and 1399). A plan that mints a number must re-read the tail at the moment
it mints, not trust this dossier.

---

## 2. Issue numbering — the exact procedure

**Authority:** `doc/claude/issues/NUMBERING.md`, and nothing else. 977 files currently in
`doc/claude/issues/`.

Reserved blocks that must be **skipped** (`doc/claude/issues/NUMBERING.md:7-12`):

| block | owner |
|---|---|
| **0500–0599** | the fluid-editing branch |
| **0700–0799** | reserved (user, 2026-08-24) |
| **1000–1199** | reserved (user, 2026-08-30) |

Current tail (working tree, uncommitted): **"The next free number is 1400."**
(`doc/claude/issues/NUMBERING.md`, last line). HEAD's committed tail says 1398.

Procedure, as the tree actually practises it:

1. **Grep the issues directory before minting** — `CLAUDE.md` says so explicitly, because
   a duplicated number rots silently and a collision cost a renumbering of 0420–0432 (+80,
   2026-08-19).
2. **File `doc/claude/issues/NNNN-<kebab-slug>.md`.** The slug is a *sentence fragment*
   describing the defect, e.g.
   `0967-ticking-the-device-numbers-box-silently-changed-which-analysis-the-outputs-value-column-reads.md`,
   `0928-device-op-save-cards-ride-along-on-analyses-that-cannot-use-them.md`.
3. **Record the number in `NUMBERING.md` in the SAME commit**, as a `- **NNNN** — …`
   paragraph appended before the tail line, and advance the tail line.
4. **Batching rule for rulings.** `doc/claude/ase_l_ux_batch/README.md`, "Not filed yet,
   deliberately": a plan's open rulings are *not* filed until the work starts, and then
   they go in as **one issue** plus **one `owed.sh add rule <that issue>`** — "a ledger
   entry is a record of an unratified decision that is already in the tree". A plan may
   therefore *list* its rulings without minting anything.

---

## 3. "Do not change designs" — what that phrase maps onto here

There is no literal string "do not change designs" in the tree. It resolves to **three
distinct rules**, and a plan should be explicit about which one it means:

**(a) The ASE-L founding doctrine — the schematic carries only the circuit.**
`doc/claude/specs/ase_l.md:7-20`: the target cell "will contain **only the circuit**
(device, sources, net labels) while everything else lives in a new **`ngspice_state1`
view**". Analyses, models, variables, outputs, options, run dir and simulator choice are
STATE, not schematic content. **Consequence for the analyses plan: no new analysis
capability may be delivered by putting anything back on the schematic** — no
`code_shown`/`simulator_commands` instance, no `corner.sym`, no `flags=graph` block. The
migration tool exists precisely to *remove* those (`doc/claude/specs/ase_l.md:554-572`,
`tools/migrate/ase_migrate.py`).

**(b) Do not touch the user's own designs, benches or artifacts.** `sky130A/` benches,
`~/.xschem/`, `/tmp/Xschem.log.*` (§1.2). Probes use a scratch library with an explicit
`rundir`. Fixtures are built under `/tmp`; "never write into committed `xschem_library*`"
(`doc/claude/specs/create_symbol_view.md:109`).

**(c) Do not silently dirty the user's schematic as a side effect of a walk.** The
0643/`ase::with_design_current` round trip is built entirely around this: `go_back` calls
`load_backup_as()` whenever a `<cell>~.sch` exists, ending in `set_modify(1)`, so the trip
parks `autosave_backup`, restores `readonly`, and **REFUSES** outright for a modified
buffer with autosave off (`doc/claude/specs/ase_l.md:697-772`, issues 0626 / 0432).
Anything the analyses plan adds that netlists or descends inherits this doctrine — carry
it, do not re-derive it.

---

## 4. Is there a GUI test gate? Yes — and what it obliges

**Spec:** `doc/claude/specs/gui_test_gate.md` (SHIPPED v6/v7).
**Files:** `tests/headless/gui_gate.sh`, `tests/headless/gui_gate_widget.tcl`,
`tests/headless/gated_xschem.sh`, wired into `full_audit.sh` and `run_suites.sh`.
**Control dir:** `~/.claude/gui_test_gate/`, shared by the main session and every worktree
/ subagent run, so one Pause pauses every suite.

What a plan author must know:

- It **fails open**: no `DISPLAY`, `GUI_GATE=0`, or a closed panel → tests just run. CI and
  headless are unaffected (`CLAUDE.md`, "GUI-test control gate").
- Since v7 the everyday arm is **Xvfb**, and `GUI_GATE=0` is *forced* by `xvfb_arm.sh` —
  not left to the caller — because a virtual display would otherwise arm the gate and
  `_gate_attention` would relaunch the user's Pause panel where nobody can see it
  (`doc/claude/specs/gui_test_gate.md:22-31`). **A panel popping for a routine suite is a
  symptom**, not the design.
- The user's own advice, in `CLAUDE.md`: **"Don't press Proceed forty times"** — press
  `Allow 30m` / `Forever` once.
- **Do not reintroduce it as a Claude Code settings hook.** A prior hook-based gate died
  silently when `settings.local.json` was rewritten (`CLAUDE.md`, same section).
- A separate, differently-scoped gate exists for the build loop: `tools/review_gate/`
  (`doc/claude/specs/review_gate.md`) — "ask, then self-release", default 30 min timeout,
  `PROCEED|STOP|TIMEOUT|NOGATE`, exit 3 = stop. **It must be run in the background** (a
  30-minute foreground wait exceeds the 600 s per-command ceiling). Deliberately a
  *different* control dir from the GUI gate: "I have eyeballed item 5" and "do not flood
  my display" are different questions and one must never release the other.

---

## 5. What `specs/ase_l.md` already says about ANALYSES

`doc/claude/specs/ase_l.md` is 1193 lines and is the **spec of record**. It was last
touched 2026-09-09. Below is everything in it that constrains analyses.

### 5.1 The four locked v1 decisions (`:22-37`)

Dated 2026-07-20, "Decisions locked with the user":

1. **D1** — v1 scope is the full de-clutter set: **analyses**, corner, variables, outputs,
   sim/run-dir, netlist viewer, log viewer, Design Window. *Plotting via existing
   graphs/gaw deferred.*
2. **D2** — state is a **single Tcl-dict text file** per view:
   `<lib>/<cell>/ngspice_state1/<cell>.state`.
3. **D3** — v1 simulator = **ngspice only**, but "state schema + deck generation behind a
   **per-simulator table** so others can slot in". *This is the seam that makes
   "expose everything ngspice can do" legal — but it also means an analysis set that is
   hardcoded rather than declared by the backend violates the stated architecture.*
4. **D4** — implementation is **pure Tcl** (`src/ase.tcl`); C is touched only if view
   dispatch/netlisting force it.

### 5.2 The analyses key in the state schema (`:38-110`)

```tcl
analyses    {{type op enabled 1}
             {type dc enabled 0 source V2 start 0 stop 1.8 step 0.01}
             {type ac enabled 0 points 10 start 1 stop 1e9 dec 1}
             {type tran enabled 1 step 1n stop 1u}}
```

Spec statements attached to it:

- "`analyses` render into **one `.control` block** (op → `op`, dc → `dc V2 0 1.8 0.01`, …)
  **in a fixed order**; only `enabled 1` entries emit." (`:76-78`)
- "Loader/saver in `ase.tcl`; **unknown keys preserved round-trip** (forward compat)."
  (`:109`) — the forward-compat promise the state file makes.
- Ordering of keys in the file follows `ase::schema_keys` (`:70`, and the code at
  `src/ase.tcl:68`).

### 5.3 Deck assembly, and where analyses sit in it (`:111-130`)

1. `xschem netlist` the clean schematic → `<rundir>/<cell>.spice`.
2. ASE post-processes: strip trailing `.end`, then append **in order**:
   `.include` includes → `.lib` models → `.param` variables → `.options` →
   `.save` outputs → **`.control` analyses block** → `.end`.
3. Write `<rundir>/<cell>_ase.spice`; run `<simulator> -b <cell>_ase.spice 2>@1` from the
   run directory. **There is no `-o`** — stdout must flow into `execute(data,$id)` for the
   live log; the log file is written by ASE itself (`ase::run_log_write`), framed.
4. **Per-simulator seam:** steps 2+3 live behind `ase::backend::<sim>::render_deck` /
   `run_cmd`; v1 registers `ngspice` only.

`pre_commands` render at the **head of the `.control` block**, ahead of the analyses
(`:88-101`), because ngspice runs `pre_*` before the netlist is parsed — that is the only
way to load an OSDI Verilog-A module.

### 5.4 The Choose Analyses dialog — the whole of what is specified (`:1094-1099`)

> **Choose Analyses dialog** — Two vertical sections: top = analysis types with radio
> buttons (selects which analysis the bottom shows); bottom = per-analysis form: Enable
> checkbox + quick fields (e.g. DC: source/start/stop/step; TRAN: step/stop; AC:
> points/start/stop) + an **Options** button for nuanced options.

That is **six lines**. There is no specification of noise/pz/sens/disto/sp/pss, no
specification of sweeps, no specification of corners or Monte Carlo, and no statement of
how the type list is derived. **The area the new plan is about is essentially unspecified
in the spec of record.**

Adjacent, and binding:

- **Analyses pane** (`:892-895`): columns *Type, Enable (checkbox), Arguments (view-only
  one-line summary)*. One row per chosen analysis, row-numbered.
- **Interaction model** (`:900-904`): NO inline +/- buttons; add via right-click, menu bar
  or action strip; **double-click a row → edit dialog**; multi-select within ONE pane;
  global Delete is noun-verb on the current selection.
- **Menu** (`:1041`): `Analyses — Choose… (Choose Analyses dialog)`. That is the entire
  menu entry.
- **Action strip** (`:906-914`): `OP,TR` → Choose Analyses dialog.
- **Dialog style** (`:1100-1106`): named fonts, `ttk::combobox` with type-to-filter for
  library/cell lists, **Return = proceed**, per-window state arrays cleaned on destroy,
  **ESC dismisses through the same cancel path as Cancel** (main window and log window
  exempt).
- **Simulation menu** (`:1063-1067`): Netlist > Recreate; Netlist > Display; Netlist and
  Run; Run (uses EXISTING netlist — supports hand-edited decks); Stop; Log;
  **Options… (simulator-specific options dialog, minimal for now)**.
- **Outputs > Save All…** (`:1057-1060`): "ngspice mapping v1: allv → `.save all`, alli →
  `.options savecurrents`".
- **Temperature** (`:820-824`): a toolbar numeric entry, default 27, emits `.temp <T>`;
  state key `temperature`.

### 5.5 What the spec explicitly puts OUT of scope

- **Plotting via existing graphs/gaw is deferred to a later phase** (`:26-27`) — P5,
  "deferred — results" (`:1170-1171`). *(Partly overtaken: Direct Plot and the waveform
  viewer are LIVE, `:1068-1088`.)*
- **Per-terminal currents of devices other than sources** are deferred from Select On
  Design: they need `.options savecurrents` plus `@m.x<inst>.<subdev>[id]`-style names that
  depend on subcircuit internals invisible to a schematic click (`:924-929`).
- **Concurrent sessions**: one ASE toplevel per state view; no locking in v1 (`:1190-1192`).
- **Windows**: subprocess + fileevent path must not regress the Windows build; v1 may gate
  live-follow on unix (`:1187-1189`).

### 5.6 Decisions already taken that a new analyses plan MUST NOT CONTRADICT

These are the ones with teeth. Every one of them is a measured, argued decision in the
spec or in `src/ase.tcl`'s own comments:

| # | decision | anchor | why it binds an analyses plan |
|---|---|---|---|
| **A** | **`op` must be LAST in the emit order** — every analysis after `op` re-records the device numbers (74.9 MB measured). But when the op-tier lists are non-empty the order becomes `dc ac tran op`. | `src/ase.tcl:10855-10863`, `:10939`; issue 0964 | A new analysis type has to declare where it sits in `anorder` **and** what it does to the device-parameter tier. |
| **B** | **The `print` anchor is computed from the ENABLED SET alone and the emit order cannot move it**; it is `dc ac tran op` with op last so last-enabled-wins picks op whenever enabled. | `src/ase.tcl:10925-10939`; issues 0967, 1243 | The Outputs Value column is a **scalar** column (`result_probe` accepts `<expr> = <number>` and nothing else). A new analysis whose answer is a spectrum or a sweep **has no home in that column** and must say where its answer goes. |
| **C** | **Transient-only is deliberately BLANK in the Value column**, on the ledger as a `rule` debt; guessing would put an unlabelled number beside a row. | `src/ase.tcl` 1243 comment block | Same rule applies to noise/pz/sp: do not invent a scalar. |
| **D** | **A `sim_status` guard is emitted after EVERY analysis, never once at the end.** Measured: one guard at the end → rc=0 and a 2198-byte raw with the failure completely masked. | `src/ase.tcl` (casemode item 10 comment, just below the `switch`) | Every new analysis arm must be followed by the guard and by `remzerovec`. |
| **E** | **`remzerovec` before every write, not once at the end** — `.options savecurrents` leaves zero-length vectors and ngspice's `write` then aborts SILENTLY (probe-verified, ngspice-42). It is per-PLOT. | same block | Same. |
| **F** | **Device `@dev` names ride the `op` write and no other.** A bare `@dev` on a multi-point write is silently wrong — dims=1, one non-zero sample at index 0. Rows E5/M1 fail if loosened. | `src/ase.tcl`, 0963 tier b comment | A new multi-point analysis must not be given the device write. |
| **G** | **The deck's `.control` shape and the framed log** — output region byte-identical to `$::execute(data,last)`, `$data` never mutated, `ase::run_done`'s 4th param stays DEFAULTED (341 checks die on `wrong # args` otherwise). | `doc/claude/specs/ase_l.md:605-644`; issue 0618 | Any new result-parsing must read `$data` in memory, not the file. |
| **H** | **Netlist and Run works from any level of the design** (0643): the door asks *reachability*, not currency; the walk belongs to `ase::netlist`, not the door. `Simulation > Run` needed no change. | `doc/claude/specs/ase_l.md:697-772` | An analyses plan must not re-introduce a "top-only" guard. Note `:1032-1035` still carries the OLD claim that "RUNNING is still top-only" — **that paragraph is stale** and contradicts `:697-772`. |
| **I** | **`sim_entry` is state; the registry is environment** (1395). The run applies the *running session's* `sim_entry`. `omit_if_empty` protects the committed `.state` files. | `doc/claude/specs/ase_l.md:254-296`; `src/ase.tcl:58-110` | If analyses become simulator-declared (§9.3), the declaration is read through `ase::sim_status`/`ase::sim_capabilities`, never from a bare backend name. |
| **J** | **`ase::sim_capabilities`** answers what the build that will ACTUALLY start can do, by a **probe run, never a version string**; `known 0` means nobody measured and the capability keys are **absent, not 0**; only a `known 1` answer is cached (0950). | `doc/claude/specs/ase_l.md:297-553` | The existing, working precedent for "ask the simulator what it can do". A capability-driven analysis list should extend this machinery rather than invent a second one. |
| **K** | **Backend hook set.** `ase::register_backend` REQUIRES exactly `render_deck run_cmd log_file result_probe raw_file`; `capabilities`, `op_param_set`, `op_param_enumerable` ride optionally. | `src/ase.tcl:663-672` | A new `analysis_line` (or `analysis_types`) hook is **optional** by this precedent and costs no contract change. |
| **L** | **Save State confirms before it overwrites an existing state**; D13 is RETIRED (user overruled it 2026-09-09). Two mutually-exclusive predicates, both sentences minted in the `ase::ui::lbl_*` family. | `doc/claude/specs/ase_l.md:1119-1137`; `doc/claude/ase_l_ux_batch/DECISIONS.md` S-1…S-9 | Cite, don't re-litigate. |
| **M** | **Bus picks open a Select Bus Bits dialog** (0159); a multi-bit `v(a[1:0])` `.save` **aborts the entire analysis** as the only `.save` in a deck (measured, ngspice-42), and is silently dropped alongside a valid one. | `doc/claude/specs/ase_l.md:968-1000` | Any new analysis that takes an output/probe expression inherits this. |
| **N** | **Value display is engineering notation**, gated by `ase_eng_notation` (default 1); display-only, state files and edit dialogs always carry raw values. Formatter `ase::format_value`. | `doc/claude/specs/ase_l.md:896-905` | New numeric fields follow it. |

---

## 6. The hard migration constraint: 105 committed `.state` files

- **Count on disk today: 105** (`find . -name '*.state' -not -path './.git/*' | wc -l`).
  Every doc in the tree says "104" — that number is now stale by one. Say 105, or count
  again at plan time.
- **Every single one carries exactly four analysis rows**, enabled or not:
  `grep -ho 'type [a-z]*'` over all of them → `105 type tran / 105 type op / 105 type dc /
  105 type ac` and nothing else. Example, the user's own bench
  (`sky130A/xschem_libs/sky130_tests_ase/tb_bandgap/ngspice_state1/tb_bandgap.state`):
  ```
  analyses {{type op enabled 1} {type dc enabled 0} {type ac enabled 0} {type tran enabled 1 stop 200u step 10n}}
  ```
- **`ase::state_default`** seeds precisely those four rows (`src/ase.tcl:502-514`).
- **Five suites assert load→save byte-identity** and are named in the code as
  **F3/G3/R4/V4/R2**: `tests/headless/test_ase_final.tcl:108` (F3),
  `tests/headless/test_ase_view.tcl:76` (V4), `tests/headless/test_ase_persist.tcl:187`
  (R2), plus G3 and R4. The `omit_if_empty` mechanism (`src/ase.tcl:103-110`) exists
  *entirely* to keep them green when a key is added.
- **Therefore:** adding a fifth analysis type to `ase::state_default` gives every NEWLY
  created state a fifth row while every existing file keeps four (dict merge is per-key, so
  the file's `analyses` list wins whole). That asymmetry is survivable but must be
  **stated and tested**, because the pane, the dialog and any golden that compares a
  freshly seeded view will move.
- **Stage F4's own warning** (`doc/claude/ase_l_ux_batch/PLAN.md`, R-16): "the 105
  committed `.state` files may carry stored keys that would suddenly become **live
  simulator input**" — today an unknown key in an analysis row is preserved on round trip
  and rendered as `key=value` in the Arguments column but never emitted; the moment the
  emitter learns to emit tail keys, those stored keys change what runs.

---

## 7. Existing issues, findings and batch docs that already touch analyses — cite, do not duplicate

### 7.1 The single most important prior finding

**`doc/claude/ase_l_ux_batch/FINDINGS.md`, finding id `no-noise-analysis-and-silent-drop`
([MAJOR], effort large)** — the direct ancestor of the new plan. Verbatim substance:

- Three hardcoded lists, all measured at the time of writing (line numbers there are
  already stale; the current ones are in §8):
  - `foreach t {op dc ac tran}` builds the radio set,
  - `chana_fields` knows only three field sets,
  - `set anorder {op dc ac tran}` is the emit loop.
- **MEASURED:** a state whose only analysis is
  `{type noise enabled 1 output v(VBG) source v1 points 10 start 1 stop 1meg}` renders a
  `.control` block containing **only the five `print` lines** — `PROBE noise-in-deck: 0`;
  no analysis, no warning, exit would be 0, and `arg_summary` happily renders
  `output=v(VBG) source=v1 …` in the pane **beside a ticked Enable box**.
- Proposed fix, two separable pieces: **(1)** a default arm in the emit loop that raises a
  clean error naming the unsupported type — "a state ASE-L cannot render refuses to run
  instead of running empty"; **(2)** the feature half: `noise` in the radio set,
  `chana_fields` → `{output source points start stop}`, one deck arm
  `noise <output> <source> dec <points> <start> <stop>`, **plus a result path — noise's
  answer is a spectrum, so it lands in the viewer, not the Value column.**
- **"Per the memory rule on capability gating, the type list should come from what the
  registered simulator declares rather than being a second hardcoded list."**
- **Risk:** `tests/headless/test_ase_dialogs.tcl` **G1/G2/GE4** drive
  `$top.chana.types.tran` **by path** and would need the new row added, not moved. "A new
  analysis type is a **spec change** (`doc/claude/specs/ase_l.md`) and the field labels are
  **new user-facing strings needing ratification**."
- **ADE-L reference (the parity bar):** "ADE-L's Choosing Analyses form lists tran, dc, ac,
  noise, xf, sens, dcmatch, stb, pz, sp, envlp, pss/pac/… — **every analysis the attached
  simulator declares**. Noise is a first-class row with Output/Input probe pickers."

### 7.2 The rest of the analyses-adjacent prior art, with paths

| doc | what it already settles / measures |
|---|---|
| `doc/claude/ase_l_ux_batch/PLAN.md` **Stage F1** | `analysis_line` as an **optional backend hook**, so the pane's Arguments column and the deck line have **one producer**. "Land it as a pure refactor whose first version reproduces today's emitter byte for byte. Prove `tests/headless/gold/cmos_example.spice` unchanged." Moves two display strings: `test_ase_window.tcl:525` (P4), `test_ase_dialogs.tcl:492` (G2). ≈ +34 lines. **This is the structural precondition for any new analysis type.** |
| `doc/claude/ase_l_ux_batch/PLAN.md` **Stage F4** ("The analysis form stops lying") | Positional-token emission with the dependency honoured (`tmax` without `tstart` must substitute `tstart 0`, not shift a slot); a tail emitter for unknown keys mirroring the `.options` emitter; **refuse at OK any option that cannot be emitted, rather than storing it**; real per-type field sets for tran/ac/dc/op incl. UIC and unit labels; the Points label following the sweep type. **Plus two state-machine bugs:** a radio click discards what you typed (recorded decision **D4**), and `chana_ok` searches for the *first* row of the type, "so **the dialog can never create a second `dc`** — a bench sweeping both VIN and temperature cannot say so through any control in the program." Rulings **R-14** (labels/units/UIC caption), **R-15** (reversing D4), **R-16** (the `.state` key migration). |
| `doc/claude/ase_l_ux_batch/PLAN.md` **Stage F2** | The Outputs Value column should read the answers **from disk** via the existing `log_file` + `result_probe` hooks, gated on `ase::has_results` (`src/ase.tcl:7691`, issue 0838). ADE-L note: "The pane is a view onto the selected result, not a side effect of having pressed Run in this session." |
| `doc/claude/ase_l_ux_batch/PLAN.md` **Stage F3** | Five real status states + elapsed time; the 30 s `ase::cap_budget_ms` blind gap between press and launch. Ruling **R-13**. |
| `doc/claude/ase_l_ux_batch/PLAN.md` **Stage F5** | `ase::rundir` keyed on lib/cell/view; **`rundir` is read in two places and has NO writer anywhere in the tree**. Ruling **R-17**, a real migration. Directly relevant if new analyses mean more artifacts per state. |
| `doc/claude/ase_l_ux_batch/FINDINGS.md`, `choose-analyses-fights-you` [MAJOR] | Four measured defects in the dialog: it hardcodes `op` on open even when op+tran are enabled; **focus is on the toplevel, nothing focused**; no `selection range` anywhere in the 7491-line file; a radio round trip loses typing (D4); no `wm transient`, dialog landed at `+1536+848` on a 1920×1080 screen. Seven pointer gestures to change a transient stop time. |
| `doc/claude/ase_l_ux_batch/FINDINGS.md`, `refusals-appear-in-a-different-window` [MAJOR] | `chana_ok`'s "ase: enabled $type analysis needs a non-empty '$f'" and `chana_x_add`'s "option name must not be empty" go to the CIW, not the dialog. Proposed `ase::ui::dialog_status`. **chana already reserves grid rows 8 and 9 for exactly this.** |
| `doc/claude/ase_l_ux_batch/FINDINGS.md`, `no-undo-no-confirm-no-revert` [MAJOR] | Deleting an Analyses row has no confirm and no undo; `ase::session_revert` exists but is not in any menu. |
| **Issue 0928** `doc/claude/issues/0928-device-op-save-cards-ride-along-on-analyses-that-cannot-use-them.md` | device OP save cards on analyses that cannot use them |
| **Issue 0929** `…0929-only-the-last-analysis-reached-the-raw-so-op-annotation-had-nothing-to-read.md` | `set appendwrite`; multi-analysis raws |
| **Issue 0964** `…0964-device-operating-point-cards-ride-every-timepoint-of-the-transient.md` | the emit-order reorder (decision A above) |
| **Issue 0967** `…0967-ticking-the-device-numbers-box-silently-changed-which-analysis-the-outputs-value-column-reads.md` | the print anchor (decision B) |
| **Issue 0968** `…0968-the-blanket-request-is-emitted-where-it-applies-to-every-analysis.md` | blanket save scope vs per-analysis |
| **Issue 0278** `…0278-render-deck-prints-every-transient-point-to-the-log.md` | why `print` on a multi-point plot is a 108k-line log |
| **Issue 0856 / 0860 / 0862 / 0872 / 0893 / 0902** | the annotation side's per-analysis gates: a transient's t=0 shown as the operating point; the gate refusing every non-op/dc database; a DC sweep's first step published as the OP. **These are the downstream consumers a new analysis type must not break.** |
| **Issue 0434** `…0434-bogus-save-card-failure-mode-depends-on-the-ngspice-invocation-idiom.md` | `ngspice -b -r out.raw deck.sp` fabricates a column for an unrecognised `@…[id]`; the failure mode depends on the invocation idiom |
| `doc/claude/casemode_batch/PLAN.md` §0 F1–F8 + `doc/claude/specs/simulator_profiles.md` | the whole case-mode axis: `.save` spelling × mode, `print` echo (what `result_probe` regexp-matches), hierarchy names, `.spiceinit` silently defeating the flag. Any new analysis that takes a node/probe name inherits this. |
| `doc/claude/specs/calculator.md:585` | "`pzbode` / `pzfilter` … ✘ (**ngspice `pz` output not modelled**)" — the Calculator explicitly does not model pole-zero output today. |
| `doc/claude/specs/calculator.md:62` | "Families across corners/Monte Carlo — v1 handles the *single-raw multi-dataset* family" — the corner/MC axis is acknowledged and scoped out there. |
| `doc/claude/issues/0210-ase-migrate-source-library-leaks-and-sg13g2.md:99` | a model-level Monte-Carlo draw was proven to change between runs of the *same* migrated state — relevant to any MC feature. |
| `doc/claude/code_analysis/1243_op_values_differ_between_runs.md:91` | "nominal run and keep `agauss` for the Monte Carlo sweep it was written for" |
| `doc/claude/specs/mixed_signal_signal_browser.md`, `waveform_viewer*.md`, `results_selection.md`, `raw_case_mode.md`, `typed_signal_accessors.md` | where a non-scalar analysis result would actually land. Large; read the relevant section only. |

**Nothing in the tree specifies pz, sens, disto, sp, pss, `.tf`, `.four`, a parametric
sweep, a corner sweep or a Monte Carlo driver for ASE-L.** The only design-level mentions
of those words are the Calculator's exclusion list and ADE-L's own inventory quoted in
FINDINGS. That is the gap the new plan fills.

---

## 8. Code anchors the plan will need (current, working tree, 2026-09-09)

| what | anchor |
|---|---|
| Analysis emit loop, `anorder`, the four `switch` arms | `src/ase.tcl:10863`, `:10939-10970` |
| The op-tier reorder, the print anchor and their whole rationale | `src/ase.tcl:10840-10940` (comment block; issues 0964, 0967, 1243) |
| `sim_status_guard` + `remzerovec` + the `op`-only device write | `src/ase.tcl` immediately after the `switch`, `:10970-10995` |
| `ase::schema_keys` | `src/ase.tcl:68-71` |
| `ase::omit_if_empty` and the byte-identity doctrine | `src/ase.tcl:73-110` |
| `ase::state_default` (seeds the four analysis rows) | `src/ase.tcl:502-514` |
| `ase::register_backend` — the five REQUIRED hooks | `src/ase.tcl:663-672` |
| `ase::backend_hook` / `ase::backend_names` | `src/ase.tcl:676`, `:688` |
| `anaargs` — the pane's argument order table | `src/ase_window.tcl:83-84` |
| `ase::ui::arg_summary` — the Arguments column renderer | `src/ase_window.tcl:1528-1543` |
| `ase::ui::chana_fields` — the dialog's per-type quick fields | `src/ase_window.tcl:4534-4543` |
| `ase::ui::chana_row` — "the FIRST state row of `type`" (the can't-create-a-second-`dc` bug) | `src/ase_window.tcl:4545-4553` |
| `ase::ui::choose_analyses` (`type {}` preselects `op`) | `src/ase_window.tcl:4556-4587` |
| `chana_show` / `chana_ok` / `chana_cancel` | `src/ase_window.tcl:4588`, `:4615`, `:4656` |
| `chana_options` / `chana_x_fill` / `chana_x_add` / `chana_x_del` / `chana_x_ok` (the extra-key escape hatch) | `src/ase_window.tcl:4675`, `:4722`, `:4733`, `:4750`, `:4775` |
| Deck goldens | `tests/headless/gold/{cmos_example,dlatch,flop,nand2,tb_test_evaluated_param}.spice`, `tests/headless/gold/state.txt` |
| Pre-cosim state fixture | `tests/headless/fixtures/ase_state_v1_pre_cosim.state` |
| The ASE suite family (36 files) | `tests/headless/test_ase_*.tcl` — core, window, dialogs, persist, plot, final, final_gf180, view, interact, launch, preflight, cosim, optier_0963, simcaps_0948, simreg_0931, simdlg_0937, simchoice_1395, result_case, savestate_adopt, dirty, bus_bits_0159, hier_pick_0161, hier_plot_0168, locked_wire_pick_0160, print_bracket_0167, sod_case, unnamed_net, current_repair, log_seam_0207 |
| Which of them T1 actually runs | `tests/run_regression.tcl:27-94` — `hcases` (`:64-72`) and `dcases` (`:90-94`). **Not every ASE suite is in T1** (issue 1399 is exactly this class: `test_wave_sigbrowser_0312` is not in the case list, so T1 has never covered it). |
| Fixtures that hardcode the four-row analyses list (will move if the default changes) | `test_ase_core.tcl:173`, `:410`; `test_ase_window.tcl:1314`, `:1440`; `test_ase_simcaps_0948.tcl:2991-2993`; `test_ase_optier_0963.tcl:269-270`, `:1515`, `:2845`; `test_ase_plot.tcl:145`; `test_ase_preflight.tcl:440`, `:869`; `test_op_dump_altshow.tcl:81` |

---

## 9. Three shape questions the plan will have to answer, with what the tree already implies

### 9.1 Hardcoded list vs simulator-declared list
The spec's own D3 ("state schema + deck generation **behind a per-simulator table**",
`:33-35`) and the ADE-L parity bar ("every analysis the attached simulator declares",
FINDINGS) both point at **declared**. The machinery already exists and is battle-tested:
`ase::sim_capabilities` (`doc/claude/specs/ase_l.md:297-553`) is a probe-run capability
answer with a `known 0 / known 1` discipline, a cache keyed on resolved path + mtime + size,
a 30 s budget, and a `noplace`/`timeout` reason vocabulary. A new `analysis_types` hook
would be **optional** by the `register_backend` precedent (`src/ase.tcl:663-672`).
⚠ But note the standing costs already recorded against that machinery: issues **0953's
other half** (the probe is paid inside the user's Run gesture), **0958** (paid on EVERY
press), **0959** (the bound and the never-cache rule evaporate silently without
`timeout(1)`). A plan that puts a *startup* probe in front of the analyses list inherits
all three.

### 9.2 Where a non-scalar answer goes
Decisions B and C (§5.6) mean the Outputs **Value** column can only hold a scalar. A noise
spectrum, an AC sweep, a pz root list and an sp matrix all need a different destination —
the waveform viewer (`wviewer::open`, per-token idempotent,
`doc/claude/specs/ase_l.md:1084-1086`), the Calculator, or a new surface. The plan must name
the destination per analysis type or it will ship the FINDINGS defect in a new shape.

### 9.3 The silent-drop fix is separable and should go FIRST
FINDINGS' piece (1) — "give the emit loop a default arm that raises a clean error naming
the unsupported type" — is small, safe, needs no ruling, and converts the worst failure
mode available (a run that completes, writes a file and produces nothing, with the pane
showing the analysis enabled) into a refusal. Under this tree's own sequencing habit
(`ase_l_ux_batch/PLAN.md`: "Stage 1 alone is one rebuild, zero rulings, zero suites
moved"), that is item 1.

---

## 10. The SHAPE the plan document must take

### 10.1 One big document or a directory? — **A directory.**

Measured across the tree: of the batch directories under `doc/claude/`, **every** one that
represents real, multi-item work is a directory (`ase_l_batch`, `ase_l_ux_batch`,
`casemode_batch`, `results_batch`, `op_param_batch`, `hierarchy_editor_batch`,
`descend_run_batch`, `ase_simchoice_batch`, `rdw_batch`, `calculator_batch`,
`signal_browser_batch`, `batch_F`, …). The single-file form is used only for
`doc/claude/suggestions/*.md` — session prompts and one-shot proposals — and those are
explicitly "session prompts, plans" in `CLAUDE.md`'s taxonomy, not batches.

The canonical file set, in the order they are read:

| file | required? | what it holds | exemplar |
|---|---|---|---|
| `README.md` | optional but excellent | what was asked for (verbatim), a file table, a one-paragraph version, and "not filed yet, deliberately" | `ase_l_ux_batch/README.md` |
| `CREW_BRIEF.md` | **yes** | the user's request verbatim; the standing rules every crew obeys; what the driver MEASURED before the crews started, "so nobody re-derives it"; the user's bench and its exact registry line | `ase_l_ux_batch/CREW_BRIEF.md`, `rdw_sim_batch/CREW_BRIEF.md` |
| `PLAN.md` | **yes** | the item list, authoritative | see §10.3 |
| `DECISIONS.md` | **yes** | numbered decisions a crew, a suite row and a commit message can all cite; ⚖ marks the USER'S | `ase_l_ux_batch/DECISIONS.md`, `casemode_batch/DECISIONS.md` |
| `LEDGER.md` | **yes** | baseline (git HEAD, md5s, counts) taken BEFORE crew 1; one section per item with status/commit/T1/ledger-debts; the adversary findings table with dispositions; floors before→after by name; "Debts this batch leaves" | `ase_l_ux_batch/LEDGER.md`, `descend_run_batch/LEDGER.md` |
| `MEASUREMENTS.md` | when there are probe numbers | numbered measurements on the built binary, with ⚠ CORRECTION blocks where a first claim was refuted | `ase_l_ux_batch/MEASUREMENTS.md` |
| `FINDINGS.md` | when there was an audit | untriaged findings, severity-ordered within each lens, each with **id / effort / Evidence / Why it hurts / Fix / Risk / ADE-L** | `ase_l_ux_batch/FINDINGS.md` |
| `receipts/NN-item-<slug>.md` | **yes, one per item** | what the crew actually did and what proves it | `descend_run_batch/receipts/`, `ase_simchoice_batch/receipts/` |
| `OPEN_QUESTIONS.md` / `ADVERSARY_FINDINGS.md` / `EYEBALL_SIGNOFF.md` | as needed | | `casemode_batch/`, `rdw_batch/`, `calculator_batch/` |

**Proposed path — the concrete recommendation:**

```
doc/claude/ase_analyses_batch/
    README.md          <- what was asked, the file table, the one-paragraph version
    PLAN.md            <- THE deliverable; the item list, authoritative
    CREW_BRIEF.md      <- standing rules + the measured facts, so nobody re-derives them
    DECISIONS.md       <- D1…Dn, ⚖ for the user's
    LEDGER.md          <- baseline, per-item status, floors, debts
    APPENDIX_ngspice_analyses.md   <- the ngspice-side inventory this dossier's siblings produce
    receipts/          <- one per item, created as the work lands
```

`ase_analyses_batch` is the right slug: it is the noun the work is about, it sorts beside
`ase_l_batch` / `ase_l_ux_batch` / `ase_simchoice_batch` / `ase_run_guard_batch`, and it
does not collide with an existing directory. If the driver prefers to bind it to the UX
work, `ase_l_analyses_batch` is equally house-shaped.

**Where the ngspice-side inventory goes.** The other dossiers in this pass are raw material
about ngspice's own capabilities. House style keeps *evidence* out of `PLAN.md` and in a
sibling (`MEASUREMENTS.md`, `FINDINGS.md`, `casemode_batch/PLAN.md` §0 "Measured facts").
Put the ngspice analysis/option inventory in `APPENDIX_ngspice_analyses.md` (or a §0
"Measured facts" section of `PLAN.md`, as `casemode_batch/PLAN.md:58-190` does) and have
every item cite it rather than restating it.

**And the spec of record must be amended, not replaced.** `doc/claude/specs/ase_l.md` is
the spec; a batch closes by rewriting the paragraphs it invalidated. Precedent: the 0643
batch's item D says in as many words *"Update `doc/claude/specs/ase_l.md:601`, which
documents the old refusal as covered behaviour"* (`descend_run_batch/PLAN.md`, Item D), and
DECISIONS S-8 says *"A spec that still says 'needs NO confirm' next to code that confirms
is how the next reader gets it wrong."* For this work that means, at minimum:
`ase_l.md:1094-1099` (Choose Analyses dialog), `:76-78` (the render rule), `:892-895` (the
pane), `:1041` (the menu), and the **stale** `:1032-1035` (which still claims running is
top-only, contradicting `:697-772`).

### 10.2 How evidence is cited

- **Every non-obvious claim carries an anchor**: `src/ase.tcl:10863`, `test_ase_dialogs.tcl
  G1/G2/GE4`, `issue 0964`, `doc/claude/specs/ase_l.md:697`.
- **Prefer a SECTION NAME to a line range for anything that will be edited.** This is a
  ruling the tree already took: adversary finding #4 of the 1396 item was *"Three
  `:321-335` citations stale the day they land"* → **"FIXED. Line ranges replaced by
  section names — a section survives an edit, a line range does not."**
  (`doc/claude/ase_l_ux_batch/LEDGER.md`, item 1 findings table). FINDINGS.md's own
  `ase_window.tcl:4104` / `:4098` citations are **already stale** — the current lines are
  `:4556` / `:4559`. Cite `ase::ui::choose_analyses`, not a number, and give the number
  only as a hint.
- **Measurements are quoted, not paraphrased**, with the probe line that produced them:
  `PROBE noise-in-deck: 0`, `447 ms cold / 0 ms warm / 31.2 s`, `20502-point transient`.
- **Where a claim was refuted, the refutation stays in the document** as a ⚠ CORRECTION
  block. `ase_l_ux_batch/PLAN.md` opens with "§0. Corrections — nine claims that did not
  survive checking … including two of the lead's own". `casemode_batch/PLAN.md` has "§1.
  Corrections to the prior design doc". Do not silently delete a wrong claim.
- **Refuse-list.** Both large PLANs end with a section naming what the plan **refuses** and
  why (`ase_l_ux_batch/PLAN.md`, "What this plan refuses, and why"). This is where the
  reader learns that a tempting change (a ttk theme swap, an icon strip, a
  `ttk::panedwindow`) was considered and costed. **An analyses plan should have one** —
  e.g. "no Monte Carlo driver in this pass, and here is the measured reason".

### 10.3 `PLAN.md` — section headings and item shape

Two house shapes exist. Pick by size.

**Shape A — small batch (≤ ~6 items), the `descend_run_batch` / `ase_simchoice_batch`
form.** Best if the analyses work is split into several batches.

```markdown
# PLAN — <batch slug>

<one paragraph: how many items, what runs in parallel, what must land first,
 and "Read CREW_BRIEF.md first — every measurement is there and none of it
 should be re-derived.">

Issue **NNNN** is minted for this batch (`doc/claude/issues/NUMBERING.md` tail
said "next free NNNN"). Issue **MMMM** is the standing report and is CLOSED by item D.

---

## Item A — <the noun, and the file it lives in> (`src/ase.tcl`)

### A1. `ase::<proc> {args}`
<what it answers, in one line>
```tcl
proc ase::<proc> {…} { … }
```
* bullets: preconditions, the decision table, what it must never do, the
  measured reason for each.
* **Rows** go in `tests/headless/test_ase_core.tcl` (floor 203, `--nogui` and `:99` both).

### A2. …

---

## Item B — <…> (`src/ase_window.tcl`)
…
**Rows** go in `tests/headless/test_ase_window.tcl` (floor 245 under X, 32 `--nogui`).

---

## Item C — pin what already works, and the end-to-end row
1. …  2. …  3. …

---

## Item D — the write-up
* **Close issue NNNN.**  * **File issue MMMM** … record in `NUMBERING.md` in the same commit.
* Update `doc/claude/specs/ase_l.md:<section>`.
* `owed.sh add rule <id> …` for the unratified sentences; `owed.sh add look` for what only eyes can confirm.
```

Plus, for a table-of-crews batch, `ase_simchoice_batch/PLAN.md`'s opener:

```markdown
| crew | scope | files |
|---|---|---|
| **A** | the core split | `src/ase.tcl`, `tests/headless/test_ase_…` |
Order: A + D in parallel; then B + C in parallel; then the lead verifies.

## The twelve fixes
1. … (A)   2. … (A)   …

## Acceptance
* Every touched suite green with floors RAISED, never lowered; report before/after per suite.
* The 105 committed `.state` files still round-trip byte-identically.
* A measured end-to-end on the user's own gesture shape.
* `run_regression.tcl` **solo** (issue 0990), T1 at ZERO counted failures.
```

**Shape B — large staged plan, the `ase_l_ux_batch` form.** Best if this is one big pass.

```markdown
# <Title in the tree's voice — e.g. "Every analysis ngspice has, reachable — a staged plan">

## 0. Corrections — N claims that did not survive checking
## 1. <The axis split>   (UX used LOOK vs FUNCTION; here it might be
                          CORRECTNESS FIRST vs CAPABILITY vs SURFACE)

# <AXIS 1>
## Stage 1 — <the noun>
### 1a. <sub-item>            <- code block showing the shape, with the comment
                                 that explains why, in the tree's own comment voice
### What you see, the moment the window reopens
### Files and lines
### Suites that move
### Re-measure on the dev display
### Rulings in this stage

# <AXIS 2>
## Stage F1 — …

## The ruling ledger — batch these, ask once
| # | Stage | The question | My recommendation |
## What this plan refuses, and why
## Sequencing at a glance
| commit | stages | lines | rulings | tests moved |
```

**Item numbering and sizing — the measured house norms:**

- **Identifiers are short and stable**: `A`/`B`/`C`/`D` (descend_run), `A1…A7`, `B1…B5`
  with re-do suffixes `B2a`, `B2a-2`, `B4-3` (op_param), `Stage 1…8` + `Stage F1…F5`
  (ase_l_ux), `Item 1…10` with a kebab id per item (`read-restamp-0509`,
  `results-tcl-resolver`) (results_batch). **A re-done item keeps its letter and gains a
  suffix** — the history is never renumbered.
- **Every item names its files and a line count.** `ase_l_ux_batch` quotes `≈ +34`,
  `+97 / −11`, `+28`. `results_batch` gives each item a kebab id and a verification map.
- **Every item names the suites it moves, by file and row name**, e.g. "two golden strings
  move — `test_ase_window.tcl:525` (P4) and `test_ase_dialogs.tcl:492` (G2). Both are
  display strings, not deck output."
- **Every item states its rulings, or says `Ruling: none` and why.** "This change is
  rendering only, by construction."
- **Items carry a status marker once work starts**, inline in the heading:
  `✅ **DONE (status E), 2026-09-02**`, `⛔ **NOT LANDED (status F)**`, and a
  `### What <item> learned that binds later items` section. The status vocabulary is
  `E` (landed, with an open question that is the user's) / `x` (landed clean) /
  `F` (refuted, reverted). A `[E]` in `results_batch` marks a **PIXEL DELIVERABLE**.
- **Sizing.** The tree's own verdict is explicit: *"Stage 1 alone is one rebuild, ~97
  lines, zero rulings, zero suites moved."* Aim for items that are **one commit, one
  crew, one receipt**, name their suite floors, and can be sabotage-verified. The
  op_param batch is the counter-example the tree learned from — four reverts on items that
  were too big, each documented in place.
- **Sequencing table at the end**, mapping commit → items → lines → rulings → tests moved.

### 10.4 The acceptance boilerplate every plan carries

Lift this shape verbatim (`ase_simchoice_batch/PLAN.md`, "Acceptance", plus
`descend_run_batch/LEDGER.md`'s floor table):

* Every touched suite green with **floors RAISED, never lowered**; report before/after per
  suite, by name, per arm (`--nogui` and `:99` differ — `test_ase_window` is 32 headless
  and 267 on `:99`).
* **Sabotage-verify each new proc**: no-op it, confirm the named rows go red, restore by
  `cp` from a pristine copy and md5-compare. Never `git checkout/restore/stash/clean`.
  (`doc/claude/suggestions/green_but_hollow_tests.md` is the doctrine: "a test suite can be
  100 % green while the code you changed never executes"; ask the falsification question,
  prove the suite can go red.)
* The **105 committed `.state` files still round-trip byte-identically** (rows F3/G3/R4/V4/R2).
* The deck goldens unchanged where the change is meant to be rendering-only
  (`cmp tests/headless/gold/cmos_example.spice`).
* A **measured end-to-end on the user's own gesture shape**, on a scratch library with an
  explicit `rundir` — never a bench under `sky130A/`.
* `run_regression.tcl` **solo** (issue 0990), **T1 at ZERO counted failures**, run under a
  scratch `HOME` with `XSCHEM_DEVDISPLAY_DIR` exported, `--nolog` throughout.
* Debts recorded at the moment they are incurred: `owed.sh add rule <issue>` for every new
  user-facing sentence, `owed.sh add look <what>` for every pixel deliverable,
  `owed.sh add suite <name>` for the `:0` run.

---

## 11. Gaps and cautions for the plan author

1. **`ase_l.md:1032-1035` is stale** — it still says "RUNNING is still top-only … ascend
   before Run", which issue 0643 (`:697-772`, same file) explicitly abolished. Fix it while
   you are in there, or the next reader inherits the contradiction.
2. **"104 committed `.state` files" is stale everywhere** — it is **105** on disk today.
   Re-count at plan time; the number appears in `src/ase.tcl`'s comments, in NUMBERING.md
   and in three batch docs.
3. **`NUMBERING.md`'s tail is uncommitted.** Re-read it at the moment of minting.
4. **FINDINGS.md's line citations are already stale** (`ase_window.tcl:4104` → `:4556`).
   Re-grep before quoting.
5. I did not read `doc/claude/specs/mixed_signal_signal_browser.md` (238 KB),
   `results_selection.md` (188 KB), `simulator_profiles.md` (244 KB), `op_annotation.md`
   (351 KB) or `op_param_lists.md` (214 KB) in full — only the sections the greps surfaced.
   A plan that routes a non-scalar analysis result into the viewer or the Calculator must
   read the relevant sections of those before committing to a destination.
6. **I did not verify the ngspice side of anything.** Which analyses ngspice-46/ver_50
   actually supports, their exact card syntax, option names and defaults is the other
   dossiers' area; nothing here should be read as a claim about ngspice.
7. **The `xschem-claude` tree was not built, run or modified by me.** Every number above is
   read from source or from committed documents. The measured probe numbers quoted
   (`PROBE noise-in-deck: 0`, `447 ms cold`, `20502 points`) are the tree's own recorded
   measurements, re-quoted with their source, not measurements I took.
8. **Unresolved product question I could not settle from the documents:** whether the new
   analysis list should be *declared by the simulator* (§9.1) or *hardcoded and gated*.
   FINDINGS recommends declared and cites a "memory rule on capability gating"; the spec's
   D3 points the same way; but issues 0953/0958/0959 record real, open costs in the
   existing probe machinery. **This is a ruling, and per the pinned house rule it should be
   put to the user as one question, on its own, with the evidence and a recommendation.**
9. **⚠ Work is IN FLIGHT in this area right now.** While this dossier was being written,
   `doc/claude/ase_l_ux_batch/DECISIONS.md` and `LEDGER.md` gained the **item 2** section —
   the font/theme derivation, **issue 1398**, decisions **T-1…T-9**: four derived font
   roles (`AseEntryFont` data, `AseBodyFont` chrome, `AseLabelFont` headings-only-and-bold,
   `AseMonoFont` machine text), `font configure` never `font actual`, a refuse-don't-clamp
   size knob, `ase::palette` untouched (⚖ T-4), a readonly Entry on `disabledbg` (T-5), a
   **horizontal scrollbar rather than a `wm minsize`** for pane overflow (T-6), a live knob
   that also retunes columns (T-7), and the combobox popdown scoped on the ROOT path
   component (T-8). **An analyses plan that adds widgets to the Choose Analyses form or
   columns to the Analyses pane must build on that derived policy — font metrics and
   `-minwidth` of the heading's own ink — not on the pixel constants FINDINGS measured.**
   Re-read both files at plan time; they are moving.
