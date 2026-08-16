# Case-preserving simulation names — overnight batch PLAN

Branch `fluid-editing`. Base HEAD `7924d0db`. Nothing is pushed.

> # ⚠ READ THESE TWO FIRST — 2026-08-16
>
> Large parts of this plan are **superseded**. Nothing below has been deleted,
> because the wrong text is why several things were misjudged and the next
> reader needs to see the shape of the mistake. But do not work from this file
> alone.
>
> 1. **`DECISIONS.md`** — the 13 open decisions, settled with the user
>    2026-08-16, one at a time. Its §3 is the authoritative item-by-item impact
>    table. Four of the user's answers overturned the recommendation recorded
>    here.
> 2. **`DESIGN_REVISION.md`** — the read path is redesigned. The fold at
>    `save.c:1008` is **deleted outright** rather than gated on a mode, and the
>    lookup becomes case-insensitive. This shrinks items 1/2/3/5 and absorbs the
>    VCD sub-step (§5.6) entirely.
>
> **The authoritative item list is now §3b of this file**, not §3.
>
> Base HEAD above is stale. Current base is `577ef5bc`; `open_pdk` merge 5
> landed at `e7ae4d77`. The `full_audit` baseline debt is **paid** — see
> `LEDGER.md`.
>
> Headline reversals, so nobody re-derives them from the stale text:
>
> | § | what this file says | what was decided |
> |---|---|---|
> | §D1/§D2, item 1 | `Raw.case_mode`, three-valued, gates the fold | fold **deleted**; `Raw` gains a **boolean** `case_sensitive`, set only by `distinguish` |
> | §4 Q1 | recommend `preserve` default | **`fold`** default everywhere; both modes opt-in; dialog pre-fill is probe-driven |
> | §D4, item 6 | new registry file `$USER_CONF_DIR/ase_simulators` | **extend the existing** `sim()` array / `simconf` dialog / `simrc` / `cadence_style_rc` |
> | item 8 | report a mismatch and keep going | split — `preserve` reports and continues, **`distinguish` refuses** |
> | §5.6 / item D2 | VCD is a deliberate separate sub-step | **absorbed** into item 2 |
> | §5.7 | backannotation left folding; breaks under `distinguish`; accepted | **superseded** — one lookup authority, schematic-case queries, lazy `ngspice_data` |
> | §5.10 | phantom `v(all)`, undecided | **leave and document** — and it is `v(all)` **and `i(all)`** |
> | item 14a | warn or error, undecided | warn, and **only** under `fold`/`preserve`; silent under `distinguish` |

**Goal.** A net drawn as `EN` reaches the waveform viewer, the signal browser
and the legend as `v(EN)` — the schematic's own spelling — when the user's
ngspice supports it, with **byte-identical behaviour** for every existing user,
schematic, state file and raw file when it does not.

**Enabler.** `/home/qflow/dev/ngspice_test/build-ver_50/src/ngspice`
(`ngspice-46+`), which accepts `-D casemode={fold|preserve|distinguish}`.
Reference: `references/casemode-distinguish-guide.md`. Background analysis:
`doc/claude/code_analysis/ngspice_case_sensitivity.md` (written before this
batch; §Part 3 of it is **superseded** by this plan where they disagree —
see "Corrections to the prior design" below).

State lives HERE, not in the driver's context. After a compaction, re-read this
file and `LEDGER.md`, then continue from the first row that is not
`[x]`/`[E]`/`[D]`/`[F]`.

---

## 0. Measured facts (the evidence base)

Everything below was **measured** on 2026-08-12 against the ver_50 build and
`/usr/local/bin/ngspice` (ngspice-46), not taken from the guide. Decks were
given a proper title line (a deck without one loses its first card, which
silently invalidated an earlier round of these measurements).

### F1 — raw-file labels, schematic net `MidNode`, instance `Vs`

| mode | raw `Variables:` |
|---|---|
| fold *(default; and every ngspice-46)* | `v(in)` `v(midnode)` `i(vs)` |
| **preserve** | `v(In)` `v(MidNode)` `i(Vs)` |
| distinguish | `v(In)` `v(MidNode)` `i(Vs)` |

### F2 — `.save` spelling × mode (this is the backward-compatibility key)

| `.save` card | fold | preserve | distinguish |
|---|---|---|---|
| `.save v(MidNode)` (schematic case) | rc=0 → `v(midnode)` | rc=0 → `v(MidNode)` | rc=0 → `v(MidNode)` |
| `.save v(midnode)` (folded case) | rc=0 → `v(midnode)` | **rc=1, zero vectors** | **rc=1, zero vectors** |

**Emitting the schematic's own case in `.save` is safe in all three modes.**
Emitting the *folded* case is fatal in two of them — and fatal in the worst way:
`Error: no data saved for … analysis; analysis not run`, rc=1, and a raw file
that **exists but holds no vectors**. Every trace in the session is lost.

> **Superseded 2026-08-14 for `preserve`, by upstream `0056`.** The
> `preserve` column of the table above now reads rc=0 → `v(MidNode)`: a folded
> `.save` card resolves under `preserve` exactly as `print` does. The
> `distinguish` column is unchanged and is deliberate — that mode's contract is
> byte-exact. Re-measured against build stamp `Thu Aug 13 22:49:54 UTC 2026`;
> see `doc/claude/ngspice_upstream/REPLY.md` §1. Consequences: §D5's re-case
> pass is `distinguish`-only, and item 10's pre-flight survives for a different
> and stronger reason (§5.1).

### F3 — `print` echo (what `result_probe` regexp-matches)

| mode | `print v(In)` echoes | `print v(in)` echoes |
|---|---|---|
| fold | `v(in) = 3.0` | `v(in) = 3.0` |
| preserve | `v(In) = 3.0` | `v(in) = 3.0` (**correct value**, lenient) |
| distinguish | `v(In) = 3.0` | warning, no line |

So `print` is lenient under preserve where `.save` is strict. And under **fold**
an expression emitted as `v(In)` comes back as `v(in)` — which today's literal
`result_probe` regexp will not match.

### F4 — hierarchy and simulator-constructed names

Deck with `X1` instantiating a subckt containing `Vp`:

| deck spelling | fold | preserve |
|---|---|---|
| `X1` / `Vp` | `i(v.x1.vp)`, `v(x1.mid)` | `i(V.X1.Vp)`, `v(X1.Mid)` |
| `x1` / `vp` | `i(v.x1.vp)`, `v(x1.mid)` | `i(v.x1.vp)`, `v(x1.Mid)` |

**The `v.` branch prefix takes the case of the instance's own first
character as written in the deck.** `get_raw_index`'s special fixup at
`save.c:2263` hardcodes lowercase `"i(v.x"` and will not match `i(V.X1.Vp)`.

### F5 — the capability probe (validated 8/8, ~12 ms)

> **Superseded 2026-08-14 by upstream `0060`: `$curcasemode`.** The deck below
> still works and stays committed as a fallback for a build that predates the
> variable, but item 7 no longer builds on it. The probe is now one pipe with no
> temp deck, no temp raw and no binary grep:
> `printf 'echo CCM=$curcasemode\nquit\n' | $exe -p {*}$args`, run with
> **cwd = the deck's own directory** (measured: probing from elsewhere reports
> `preserve` while the run folds, because `.spiceinit` is searched beside the
> deck). Empty output = a build without the variable = treat as `fold`.
> Evidence: `doc/claude/ngspice_upstream/REPLY.md` R5.

One deck answers all three modes. Voltage label ⇒ fold vs non-fold; the
`let` identity split ⇒ preserve vs distinguish.

```spice
* xschem casemode probe
Vprb CaseProbeNet 0 DC 1
Rprb CaseProbeNet 0 1k
.control
op
write <tmp>.raw
let CaseProbe = 1
let caseprobe = 2
print CaseProbe
.endc
.end
```

| raw label | `CaseProbe = 1` echoed | verdict |
|---|---|---|
| `v(caseprobenet)` | no | **fold** |
| `v(CaseProbeNet)` | no | **preserve** |
| `v(CaseProbeNet)` | yes | **distinguish** |

Measured: ver_50 with no flag / `fold` → fold; `preserve` → preserve;
`distinguish` → distinguish. ngspice-46 → **fold for all four**, including
`-D casemode=distinguish`, which it accepts and ignores. The raw file must be
grepped with `grep -a` (it is binary; an earlier round of this probe reported
`UNKNOWN` for all eight cells purely because of a missing `-a`).

The guide's §9 one-liner is **not** the probe this batch needs: it tests
*identity*, so it reports `folded` for `preserve` — the mode we actually want.

### F6 — `.spiceinit` silently defeats the flag

A `.spiceinit` containing `set casemode=fold`, sitting in the deck's own
directory, beat `-D casemode=preserve` — the raw came back folded. Adding `-n`
restored `preserve`. **ASE-L's `run_cmd` (`ase.tcl:3238`) passes no `-n`**, and
ASE-L runs its deck in the rundir, where a user may well keep a `.spiceinit`.

### F7 — two schematic nets differing only in case

`Out` and `OUT` in one deck: under **fold and preserve alike** they collapse to
one net (`v(out)` / `v(Out)`), first spelling wins, **no diagnostic**. Under
distinguish they are two nets plus an `experimental` banner. Preserve is
therefore no *more* dangerous than today — but it makes the collapse
*look* deliberate, because the surviving label now carries capitals.

### F8 — the xschem end of the chain

- The netlister **already emits the schematic's case verbatim**: the
  `ase_hier_top.sch` fixture (`lab=TOPNET`) netlists as `V9 TOPNET 0 1`.
- `read_dataset` (`save.c:1008`) then folds it. Feeding the **preserve** raw to
  `./src/xschem --nogui` and asking `xschem raw list` returns `v(in)`,
  `v(midnode)` — the capitals are destroyed on read. Values still resolve
  (`xschem raw value v(MidNode)` works) via the probe ladder.

**So exactly one line stands between the user and the feature — and it is in C,
not in ASE-L.**

---

## 0b. Upstream round 2 — what the ngspice side changed (2026-08-14)

The findings in `doc/claude/ngspice_upstream/` were worked by the owner of the
`ver_50` branch and answered in
`doc/claude/ngspice_upstream/feedback/ngspice_upstream/RESPONSE.md`. **The binary
at the recorded path is now that answered tree** (build stamp
`Thu Aug 13 22:49:54 UTC 2026`), so §0's measurements were re-taken against it;
our reply, six new findings and the still-open questions are
`doc/claude/ngspice_upstream/REPLY.md`, repro `repro2/run_round2.sh`.

Four of the nine moved. What that does to the items:

| upstream | effect here |
|---|---|
| `0056` `.save` folds under `preserve` | **F2 preserve row flips.** §D5's re-case pass becomes `distinguish`-only. Item 10 keeps its pre-flight for a stronger, mode-independent reason. |
| `0060` `$curcasemode` | **Item 7 collapses** to one pipe (see F5's note). No temp files, no verdict matrix, no `grep -a`. Item 8's mismatch report becomes a variable read. |
| `0058` warnings latched | log-scraping is stable for the two announcements; **not** for the near-miss warning, which fires twice (REPLY R4). |
| `0057` near-miss named | only under `distinguish`, only when a case twin exists. **No diagnostic exists for a plain absent name** — item 10's pre-flight is the only defence. |
| `0061` `Option:` header | **unbuilt and undecided.** Item 3's `auto` sniff stays a heuristic and stays off by default. Our `read_dataset` is an else-if chain with no catch-all, so the line is already inert for us and one branch away from being read. |
| `0059` constants raw | **fix withdrawn three times.** Defence stays ours. |
| finding 5 `.spiceinit` | deliberate, unchanged. Q2 still live. |
| finding 9 fold collision | **"needs a decision that has not been made"** upstream. Q3 and item 14a still ours. |

Three things measured in round 2 change work here and are not in §0:

> **WRONG — corrected 2026-08-15 (receipt `00c`), re-measured 2026-08-16.**
> Item 1 below is false for the shape we actually emit, and it misled this batch
> for four days. It was measured on `ctl_fail.cir`, a deck carrying an analysis
> **dot card *and* a `.control run`**. `render_deck` emits neither: analyses are
> **control commands** (`op`/`dc`/`ac`/`tran`), no dot card, no `run`, bare
> `write <abs path>` with no vector list. In *that* shape a failed analysis
> returns **rc=1**, on both binaries:
>
> ```
> ver_50  rc=1 | Plotname: constants | No. Variables: 12 | names the bad token: 0
> stock   rc=1 | Plotname: constants | No. Variables: 12 | names the bad token: 0
> ```
>
> So `rc` **is** a legitimate corroborating signal — but rc=1 arrives **with the
> constants file already written**, so the content checks stay mandatory, and
> the `$sim_status` guard is better still (it quits before `write`, leaving no
> artefact, and works on stock). The rest of item 1's advice — test content, not
> the exit code — survives for that reason. See `DECISIONS.md` §C3/§C4.

1. **`rc` is unavailable in our deck shape.** The same failing `.save` exits 1
   from a plain `-b -r` deck and **0** from a deck that drives the run from a
   `.control` block — which is exactly what `render_deck` emits (`ase.tcl:3169`,
   `:3229`). So §5.1's empty-raw defence cannot lean on the exit code: it must
   test content (`Plotname: constants`, a `Date:` equal to the build stamp, a
   vector-count floor) and must also cover the `set appendwrite` shape, where
   the constants plot hides *behind* a real one.
2. **The constants artefact has nothing to do with casemode.** `.save` of a node
   that is in no netlist yields rc=0, no diagnostic naming the token, and a
   well-formed 12-variable constants raw — in **fold, preserve and distinguish
   alike, and on stock `ngspice-46`**. This is a live xschem defect today, not a
   migration risk. It promotes item 10's pre-flight from a `preserve` guard to a
   standalone fix worth doing on its own merits.
3. **A phantom `v(all)`.** A deck whose total saved-vector count is exactly one
   gains a second rawfile vector named `v(all)` — on stock too. ASE-L emits one
   `.save` card per output, so a session with exactly one output hits it and the
   signal browser lists `v(all)` as if it were a net. New hole, §5.10.

And one rule for anything that emits a `.control` block: **never a `set` and an
`unset` of the same simulator variable** — SIGABRT on both binaries
(upstream `0067`, REPLY R6). The current generator does not; items 8 and 10
were heading toward emitting `set` cards.

---

## 1. Corrections to the prior design doc

`doc/claude/code_analysis/ngspice_case_sensitivity.md` was written from source
reading only. Three of its rulings are now known to be wrong:

1. **It proposed `distinguish`-shaped thinking (a boolean `case_sensitive`).**
   The right target is **`preserve`**, and the right field is **three-valued**.
   Under preserve, identity still folds, so none of the guide's §5 silent traps
   (mis-cased subckt parameter, floating `.global`) can fire, and PDK libraries
   defining `.SUBCKT NAND2` stay callable as `nand2`.
2. **It proposed caching the probe per binary, keyed on mtime.** F6 kills that:
   the answer depends on the *rundir's* `.spiceinit`, not only the binary. The
   probe is 12 ms — **probe per run, in the rundir, with the same argv**. No
   cache, no invalidation surface.
3. **It proposed dropping the UPPER/lower rungs of `get_raw_index` whenever
   case is preserved.** That regresses every `.sch` already on disk whose graph
   `node=` attribute holds a folded name. The rungs must survive under
   `preserve` (where they are unambiguous) and be dropped only under
   `distinguish`.

It was right about: `save.c:1008` being the load-bearing line; the flag
belonging on the `Raw` struct rather than a global; `result_probe` needing
`-nocase`; the `hilight.c` senders being a separate un-hooked path; and the
`model_name()` dedup-key trap.

---

## 2. Design

### D1 — mode is three-valued and lives on the `Raw`

`Raw` (`xschem.h`) gains `int case_mode;` — `0 = fold` (default, today's
behaviour), `1 = preserve`, `2 = distinguish`. It is a property **of the run
that wrote the file**, set at read time, never a global.

| | `read_dataset` folds names | `get_raw_index` ladder |
|---|---|---|
| fold | yes | verbatim → UPPER → lower → `v(…)` (unchanged) |
| preserve | **no** | verbatim → `v(verbatim)` → UPPER → lower → `v(…)` |
| distinguish | **no** | verbatim → `v(verbatim)` **only** |

The preserve row keeps the fold rungs as a *fallback after* the verbatim
probes, so a schematic saved last year with `node="v(midnode)"` still resolves
against a raw holding `v(MidNode)`. Under preserve that can never be ambiguous:
identity folds in the simulator, so at most one spelling per net exists.

### D2 — the mode reaches the reader three ways, in priority order

1. **Explicit**, from ASE-L: `xschem raw read <f> <type> -case <mode>`.
2. **Global default**, a new `MIRRORED IN TCL` variable `sim_case_mode` =
   `fold` (default) | `preserve` | `distinguish` | `auto`, settable in
   `xschemrc`. Serves the plain File→Open-raw path (`xschem.tcl:4801`), which
   has no ASE-L session to ask.
3. **`auto`** only: sniff the Variables section — any uppercase letter ⇒
   treat as `preserve`. Off by default because Xyce writes `V(EN)` uppercase
   under semantics that are not preserve.

### D3 — ASE-L always emits the schematic's case

`sod_expr` stops folding **unconditionally** (F2: schematic case is safe in all
three modes). It does not need to know the mode. This keeps it the pure string
op that `test_ase_interact` H1 asserts, and it means a state file written today
is correct under a simulator installed tomorrow.

The mode is still needed for two things ASE-L cannot do case-blind: emitting
`-D casemode=…`, and re-casing **legacy** state files (§D5).

### D4 — the simulator profile registry

Today `simulator` (state key, default `ngspice`) names a *backend* — the hook
set. A user-registered simulator is a different thing: an executable, its
arguments, and a measured capability. Conflating them would break
`ase::backend_hook`.

- `simulator` keeps its meaning exactly. Every existing state file is unchanged.
- New state key **`sim_profile`** (added to `schema_keys` **and
  `omit_if_empty`** — mandatory, per the `ase.tcl:41` byte-stability contract),
  naming a row in a user-level registry. Empty = the built-in default =
  today's exact command line.
- Registry file `$USER_CONF_DIR/ase_simulators`, one flat Tcl dict:
  `name → {backend ngspice exe <path> args {…} casemode <requested> detected <measured> probed <iso-date>}`.

### D5 — legacy `.save` migration and the pre-flight

A state file written before this batch holds `v(en)`. Under `preserve` that
deck dies (F2). Two defences, both required:

1. **Re-case pass** at `render_deck` time when the requested mode is not fold:
   build a `fold(name) → name` map from the *netlist artifact* just produced,
   and rewrite each output `expr`'s identifier to the netlist's spelling.
2. **Pre-flight refusal.** Any `.save`/`print` identifier that still does not
   appear in the netlist map is reported and the run **refuses to start**, with
   the offending expressions listed. Never hand ngspice a deck that will die
   with "analysis not run" — that failure mode produces a raw file that exists
   and is empty, which downstream code treats as a successful attach.

Simulator-*constructed* names (`i(V.X1.Vp)`, `V1#branch`) are not in the
netlist map. Those are exempted from the refusal and handled by §D6.

> **Revised 2026-08-14 (§0b).** Defence 1's premise is gone for `preserve`:
> upstream `0056` makes a folded `.save` card resolve, so a legacy state file no
> longer dies there. Build the re-case pass **only for `distinguish`**, or defer
> it with a filed issue — `distinguish` is opt-in, carries a dialog warning, and
> is the one mode where the pass is load-bearing.
>
> Defence 2 gets *more* important and stops being about case at all. The
> failure it guards is reachable with no casemode flag, on stock ngspice, from a
> plain typo: rc **0**, no diagnostic naming the token, and a raw that is not
> empty but holds the twelve built-in constants. "Refuses to start" stays the
> primary defence; the secondary one is a **content** check on the raw, not the
> exit code and not a zero-vector test.

### D6 — currents

`sod_qualify`'s current arm builds `i(v.<lowercased sch_path><token>)`. Per F4
the truth under preserve is `i(V.X1.Vp)`: path segments as written, and the
prefix letter taking the case of the instance's own first character. Two parts:

1. **Generation**: stop lowercasing the path; derive the prefix letter from the
   instance name's first character.
2. **Post-load repair**: after `attach_raw`, resolve any unmatched current
   expression case-insensitively against `xschem raw list` and rewrite it to
   the database's actual spelling. This is the only correct source for a
   constructed name, and it is exactly what `resolve_signal_db` already does
   for the name-lookup case.

---

## 3. Items — SUPERSEDED 2026-08-16 by §3b below

> The table in this section is kept for its scope notes and file lists, which
> are still largely accurate. **Its item definitions are not authoritative any
> more** — see §3b, and `DECISIONS.md` §3 for the reasoning behind each change.

Verdicts: `[x]` done+verified · `[E]` done, eyeball pending (pixels) ·
`[D]` deferred (needs a filed issue) · `[F]` failed (needs a filed issue).

Every item: build → its own tests → **sabotage-verify** (break the new code,
watch the new checks go red) → full headless suite → commit. Never push.
Receipts in `doc/claude/casemode_batch/receipts/NN-<slug>.md`, 120 lines max.

**Default at every stage is `fold`.** No item may change behaviour for a user
who does not opt in; the audit diff for items 1–8 should be *empty*.

| # | item | scope | depends |
|---|------|-------|---------|
| 0 | **Setup.** Baseline `full_audit` (stash-diff contract, ~80 min for the pair). Commit `fixtures/tr_fold.raw` + `tr_preserve.raw` (already staged) and the probe deck. Record the baseline file name in `LEDGER.md`. | — | — |
| 1 | **`Raw.case_mode` + reader gate.** Field in `xschem.h`; `read_dataset` folds only when 0; `extra_rawfile()` carries the mode; `xschem raw read <f> <t> -case <mode>` and a read-only `xschem raw case`. Test against the two committed fixture raws: preserve+`-case preserve` ⇒ `raw list` yields `v(In)`/`v(MidNode)`; every existing call site unchanged ⇒ `v(in)`. | C: `xschem.h`, `save.c`, `scheduler.c` | 0 |
| 2 | **`get_raw_index` three-valued ladder** (§D1 table), incl. the `"i(v.x"` fixup at `save.c:2263` becoming case-aware (F4). Test the full 3 modes × {verbatim, UPPER, lower, `v()`-wrapped} matrix, both fixtures. | C: `save.c` | 1 |
| 3 | **`sim_case_mode` global + `auto` sniff** (§D2 items 2–3), `MIRRORED IN TCL`, default `fold`. Covers the File→Open-raw path. Test: sniff on both fixtures; Xyce-shaped uppercase raw stays fold unless `auto`. | C + `xschem.tcl` | 1 |
| 4 | **The four `hilight.c` senders** — `send_net_to_graph` `:1601`, `send_current_to_graph` `:1718`, gaw `:1639`/`:1758`. Gate each `strtolower` on the current `Raw`'s mode, falling back to `sim_case_mode` when nothing is loaded. This is the Ctrl-K path, entirely outside ASE-L. | C: `hilight.c` | 1 |
| 5 | **Viewer Tcl matching** — `wviewer::resolve_signal_db` `:2538` and `validate_rpn` `:3237` consult `xschem raw case`. `validate_rpn`'s comment claims its rule is `get_raw_index`'s verbatim; keep that true or expressions get accepted and rejected inconsistently. | `wave_viewer.tcl` | 2 |
| 6 | **Profile registry model** (§D4), pure Tcl in `ase.tcl`, **no Tk** (`test_ase_core` runs this file headless). `ase::simprofile_{load,save,list,get,add,delete}`, `$USER_CONF_DIR/ase_simulators`. New `sim_profile` state key in `schema_keys` + `omit_if_empty`. Round-trip byte-stability test on a pre-batch state file. | `ase.tcl` | 0 |
| 7 | **The probe**, now via `$curcasemode` (§0b, F5 note). `ase::backend::ngspice::case_probe {exe args rundir}` → `fold|preserve|distinguish|unknown`, by piping `echo CCM=$curcasemode` into `$exe -p` with the **same argv** and **cwd = the deck's directory** (not merely the rundir — measured, the wrong cwd answers confidently wrong). Empty/absent variable ⇒ `unknown` ⇒ caller treats as `fold`. No temp files. Test against both real binaries **and** with a `.spiceinit` beside the deck, which the probe must absorb; skipped, not failed, when ver_50 is absent. | `ase.tcl` | 6 |
| 8 | **`run_cmd` becomes profile-aware.** `[list $exe -b {*}$args {*}$casearg $deckpath 2>@1]`; identical to today's list when no profile is set. Probe immediately before the run, in the rundir; if the requested mode is not what came back, **say so in the log and the CIW and keep going in the measured mode** — never silently proceed as if the request took (guide §9, closing paragraph). | `ase.tcl` | 7 |
| 9 | **`sod_expr` stops folding** (§D3) + `sod_qualify` current arm (§D6 part 1). `sod_expr` keeps its `#`-strip and stays pure. This is the item that flips ~20 committed test expectations — that breakage **is** the evidence; update them here with the receipt showing before/after. | `ase_window.tcl` + tests | 8 |
| 10 | **Pre-flight + empty-raw reject** (§D5, and §0b items 1–2 which re-motivate it). Refuse the run, listing the offending expressions, when a `.save`/`print` identifier does not appear in the netlist map — this now defends a **live, mode-independent** defect: an absent node yields rc=0, no diagnostic, and a 12-variable constants raw on stock ngspice too. Reject that raw on **content** (`Plotname: constants`, `Date:` == build stamp, vector-count floor, and the `appendwrite` shape where it hides behind a real plot) — **never on rc**, which is 0 for our deck shape. The §D5 re-case pass is now `distinguish`-only (`0056` fixed `preserve`); build it thin or defer it with a filed issue. | `ase.tcl` | 9 |
| 11 | **`result_probe` `-nocase`** (F3). Under fold, an expression emitted as `v(In)` echoes as `v(in)`; without this, item 9 silently empties the Outputs pane's Value column for every mixed-case net. | `ase.tcl` | 9 |
| 12 | **Post-load current repair** (§D6 part 2) — resolve unmatched current expressions against `xschem raw list` after `attach_raw`. | `ase_window.tcl` / `wave_viewer.tcl` | 8 |
| 13 | **`Setup > Simulator…` dialog.** Registry list + Add/Edit/Delete + a **Test** button that runs item 7's probe and reports the measured mode. On Add, if `[string match -nocase *ngspice* [file tail $exe]]`, probe automatically and pre-fill `casemode`. Menu home is `Setup` (`ase_window.tcl:419`) — the ADE-L analogue of *Setup > Simulator/Directory/Host…*. `[E]`, pixels. | `ase_window.tcl` | 6,7 |
| 14 | **Netlister-side.** (a) `check.c`/netlist warning when two schematic nets fold to one name (F7) — the collapse is silent today in every mode. (b) `model_name()` dedup key (`spice_netlist.c:143`, `spectre_netlist.c:29`) folds correctly under fold/preserve; gate it on distinguish only. | C | 3 |
| 15 | **Docs.** Rewrite `doc/claude/code_analysis/ngspice_case_sensitivity.md` §Part 3 against what shipped; new `doc/claude/specs/simulator_profiles.md`; FAQ entry; a `references/` pointer. | docs | 1–14 |

---

## 3b. Items — AUTHORITATIVE, 2026-08-16

Every item, unchanged from the batch's standing rule: build → its own tests →
**sabotage-verify** → full headless suite → commit. Never push. Receipts in
`receipts/NN-<slug>.md`, 120 lines max. **Default at every stage is `fold`**, so
the audit diff for items 1–9 must be **empty** — judged by DIFFING the baseline
by test NAME and STATUS, never by the red count.

| # | item | scope | depends |
|---|------|-------|---------|
| **0a** | **Suite sweep.** ~20 headless suites touch `raw read`/`raw list`. `DESIGN_REVISION.md` changes what a VCD or table lookup returns, so find every committed assertion that encodes a folded name **before** item 1. Record the list; it is item 1's expected-diff contract. | tests | — |
| 1 | **Delete the fold + `Raw.case_sensitive`.** Remove `strtolower(varname)` (`save.c:1008`). `Raw` gains a **boolean** `case_sensitive`, set only by `distinguish`. `xschem raw read <f> <t> -case <mode>`, and `xschem raw case` becomes settable (a set **re-reads** the file — folding is destructive and cannot be undone in memory). | C: `xschem.h`, `save.c`, `scheduler.c` | 0a |
| 2 | **One lookup ladder.** `get_raw_index` (`save.c:2251`): exact → case-folded alias → `v()` wrap → the `i(v.x` fixup (`save.c:2274`, now case-aware) + the `@dev[param]` shape (`i(@R.X1.Rq[i])`). **Build no folded alias when two stored names collide** (D2) — exact lookups unaffected, the fuzzy rung declines to guess. Alias entries go in `raw->table`; verified nothing enumerates that table, so they are invisible to `raw list`. Covers all four AC-derived names per variable. Suppressed entirely when `case_sensitive`. **Absorbs the VCD sub-step** (old §5.6): retire `vcd_read.c:140`'s apology. | C: `save.c` | 1 |
| 3 | **Mode resolution, four sources in order** (B2a): explicit user setting → `Option: casemode=` header (match the **key anywhere in the header**, two positions, trim around the first `=`) → **schematic-name comparison** → capital sniff (last resort, off by default). Absence is **unknown, never `fold`** (B2b). The old `sim_case_mode` global shrinks to the floor for the no-profile path. | C + `xschem.tcl` | 1 |
| 4 | **The four `hilight.c` senders** — `:1601`, `:1718`, gaw `:1639`/`:1758`. Gate each `strtolower` on the loaded `Raw`, falling back to the global. This is the Ctrl-K path, outside ASE-L. | C: `hilight.c` | 1 |
| 5 | **Viewer Tcl + browser scan.** `resolve_signal_db` and `validate_rpn` consult `xschem raw case`; keep `validate_rpn`'s rule identical to `get_raw_index`'s. Audit the two-pane browser's group/class parser against `i(@R.X1.Rq[i])`. Narrower than before: only `distinguish` needs it. | `wave_viewer.tcl` | 2 |
| **5b** | **NEW (D3) — one lookup authority.** Backannotation calls `get_raw_index`; the Tcl-side `string tolower` and hand-rolled `v(...)` rung in `ngspice::get_diff_voltage` / `get_current` (`xschem.tcl:2669`, `:2688`–`:2700`, `:2724`) are **deleted, not ported**. Queries carry the **schematic's own spelling**, so the mode never appears in backannotation code. Then `ngspice_data` becomes a **read-traced lazy view** over the same authority — no eager `Tcl_SetVar2` per variable. Keep `info exists` working (`actions.c:4081`) and turn the five `array unset`/`Tcl_UnsetVar` sites into trace resets. | C + `xschem.tcl`, `ngspice_backannotate.tcl` | 2 |
| 6 | **Extend the existing simulator config** (B1 i) — **not** a new registry file. `sim($tool,$i,exe|args|casemode|detected|probed)` alongside the untouched `cmd` strings; `save_sim_defaults` writes them; `simrc` and any `cadence_style_rc` set them. New `sim_profile` ASE-L state key in `schema_keys` + `omit_if_empty`. Byte-stability round-trip on a pre-batch state file. Pure Tcl, **no Tk** (`test_ase_core` runs this headless). | `xschem.tcl`, `ase.tcl` | 0a |
| 7 | **The capability probe.** `printf 'echo CCM=$curcasemode\nquit\n' \| $exe -p {*}$args`, cwd = **the deck's directory**. **Hard timeout, mandatory** (B3) — a missing `quit` hangs forever; measured. Empty/absent ⇒ `unknown`. Test against both binaries **and** with a `.spiceinit` beside the deck **and** a `~/.spiceinit` (both override — measured). Skip, not fail, when ver_50 is absent. | `ase.tcl` | 6 |
| 8 | **Profile-aware `run_cmd` + mismatch policy.** Replace the hardcoded `[list ngspice -b $deckpath 2>@1]` (`ase.tcl:3238`). No `-n` by default; per-profile `-n` checkbox. Probe immediately before the run, in the rundir. **`preserve` mismatch → report in log + CIW and continue. `distinguish` mismatch → REFUSE** (B4 d). | `ase.tcl` | 7 |
| 9 | **`sod_expr` stops folding** + `sod_qualify`'s current arm (§D6 part 1). Flips ~20 committed assertions — that breakage **is** the evidence; the receipt shows before/after and which mode each surrounding check exercises. | `ase_window.tcl` + tests | 8 |
| 10 | **Three defences** (C3 + C4), all required: (a) **pre-flight refusal** naming every `.save`/`print` identifier absent from the netlist map, **and offering the legacy corrections** for confirmation (D1) — never a silent rewrite; (b) the **`$sim_status` guard** emitted after **each** analysis (`$?sim_status` existence check first; last-writer-wins per analysis), which leaves no artefact at all and works on stock; (c) **content-based rejection** of the constants raw (`Plotname: constants`, `Date:` == build stamp, vector-count floor, the `appendwrite` shape). `rc` is a legitimate corroborating signal but arrives with the file already written. | `ase.tcl` | 9 |
| 11 | **`result_probe` `-nocase`** (F3). Without it item 9 silently empties the Outputs pane's Value column for every mixed-case net under fold. | `ase.tcl` | 9 |
| 12 | **Post-load current repair** (§D6 part 2) — resolve unmatched current expressions against `xschem raw list` after `attach_raw`, rewrite to the database's real spelling. | `ase_window.tcl` / `wave_viewer.tcl` | 8 |
| 13 | **Simulator dialog** — extends the existing `simconf` (`xschem.tcl:3092`), not a new window. Per-row exe/args/casemode, **Test** button running item 7's probe, auto-probe on Add **only** when the exe filename matches `*ngspice*` (B3). Mode dropdown offers **only what the probe measured** (A1); pre-fill is probe-driven, never a constant. `[E]`, pixels — record `owed.sh add look`. | `xschem.tcl` | 6,7 |
| 14 | **Netlister side.** (a) fold-collision check firing **only under `fold`/`preserve`** where xschem and the simulator disagree; **silent under `distinguish`**; **warn, not error**; assume `fold` when no profile is set. Plus **relay** ngspice's own line (parse-time, so off the run log, deduped on the quoted pair — it repeats per subckt instantiation). (b) `model_name()` dedup key gated on `distinguish` only. | C | 3 |
| 15 | **Docs.** Rewrite `ngspice_case_sensitivity.md` §Part 3; new `specs/simulator_profiles.md`; FAQ entry; `references/` pointer. Must document: the phantom as **`v(all)` AND `i(all)`** (C1), and that Xyce remains **unverified**. | docs | 1–14 |

**Two open items carried into the batch, neither blocking:**

* **Xyce is unverified.** This plan asserts Xyce writes `V(EN)` uppercase. There
  is no Xyce on this machine and it has **not** been measured. Item 1 must
  either measure a real Xyce raw or keep a Xyce-specific fold. Note a Xyce raw
  already gets one transformation (`:` → `.`, `save.c:1010`), so there is a
  Xyce-shaped branch to hang it on.
* **The one ver_50 ask worth making:** send the written-but-unsent `cp_remvar`
  patch that makes `casemodewrite` default on. It is what turns the `Option:`
  header from "files we generated" into "any file from a modern ngspice", which
  is the difference between an exact read and a guess on the File→Open path.

---

## 4. Open decisions — ALL SETTLED 2026-08-16, see `DECISIONS.md`

> Q1, Q2 and Q3 below are **answered**. Kept for the evidence they carry, not as
> live questions. Q1 → **`fold`** default (not the `preserve` recommended here);
> Q2 → **no `-n`**, with a per-profile checkbox; Q3 → **warn**, and only under
> `fold`/`preserve`. Ten further decisions that this section never contemplated
> are in `DECISIONS.md`.

### (original text follows)

## 4-orig. Open decisions — need the user before item 8

**Q1. `preserve` or `distinguish` as the default requested mode?**
The stated goal ("display names from the schematic identically") is exactly
`preserve`. The stated premise ("`EN != en != En`, everywhere") is
`distinguish`. They are different bargains:

- `preserve` — labels keep capitals; identity still folds. Libraries defining
  `.SUBCKT NAND2` stay callable as `nand2`. None of the guide's §5 silent traps
  can fire. Two schematic nets `Out`/`OUT` remain one net (F7).
- `distinguish` — `Out` and `OUT` become two nets. Also: a mis-cased subckt
  parameter silently takes its default, a mis-cased `.global` silently floats,
  both rc=0; and **every PDK library name becomes case-exact**, which xschem
  does not control.

Recommendation: **`preserve` default, `distinguish` opt-in per profile with a
warning in the dialog.** Both are implemented either way; this only sets which
one a fresh profile proposes.

**Strengthened 2026-08-14 by upstream `0056`** (§0b): a stored folded `.save`
card is now fine under `preserve` and still fatal under `distinguish`. So the
two modes no longer differ only in net identity — they differ in whether a state
file written before this batch survives at all. The dialog's `distinguish`
warning should say that in those terms, and upstream has confirmed the strict
`.save` is that mode's contract rather than an interim state (REPLY §3 Q2).

**Q2. Is `-n` (`--no-spiceinit`) acceptable on the real run?**
It is the only way to *guarantee* the requested mode (F6). It also discards the
user's own `.spiceinit` customisations, which is a real behaviour change.
Plan currently assumes **no `-n`**, probing with identical argv instead so the
answer describes the real run. A per-profile `-n` checkbox is cheap to add.

**Cheaper than it was, 2026-08-14.** `$curcasemode` reports the mode *after*
`.spiceinit` has had its say (REPLY R5), so the no-`-n` route now yields the
truth rather than an inference — the run proceeds in whatever mode came back and
says so. Upstream confirms the precedence is deliberate and unchanged, so `-n`
remains the only override. Recommendation firms up: **no `-n` by default**, with
the checkbox for a user who knows their `.spiceinit` is the problem.

**Q3. Should the schematic net-case collapse (F7, item 14a) be a warning or an
error?** It is silent today. Warning is proposed.

---

## 5. Known holes and risks

1. **The empty-raw failure mode is indistinguishable from success downstream.**
   A `.save` case miss yields rc=1 *and* a raw file that exists with zero
   vectors. `ase::attach_dbs` reads it, `xschem raw read` returns 1, and the
   viewer attaches an empty database. Item 10's pre-flight is the defence;
   `attach_dbs` rejecting a zero-vector raw is a cheap second one and should be
   folded into item 10.
   **Revised 2026-08-14 (§0b):** the artefact is not zero-vector and not
   casemode-specific — it is the 12-variable `constants` plot, it happens under
   `fold` on stock ngspice for any `.save` of an absent node, and in our
   `.control` deck shape it comes back **rc=0**. So: content checks, not rc, and
   the defence is worth having whether or not anyone ever selects `preserve`.
2. **Simulator-constructed names cannot be predicted from the schematic
   alone.** F4 gives a rule for `v.`-prefixed branch currents that holds for
   the cases measured; `#branch`-style and `@dev[param]` names are not covered.
   Item 12's post-load repair is the general answer, but it cannot help a
   `.save` card, which is emitted before any raw exists. If item 12 proves
   insufficient, the fallback is `.options savecurrents` / `save_all_i`, which
   need no name at all.
3. **Currents behave exactly like voltages** (re-measured on a *titled* deck;
   an earlier round of this row claimed `.save i(Vs)` fails in both modes,
   which was an artefact of a deck whose first card was eaten as the title):
   `.save i(Vs)` rc=0 in all three modes, `.save i(vs)` rc=1 under
   preserve/distinguish. So F2's rule covers currents too, and item 10's
   re-case pass must handle `i(…)` identifiers, not just `v(…)`.
4. **~20 committed test assertions encode the fold** (`v(topnet)` ×5 against a
   fixture whose net is `lab=TOPNET`, `v(x1.x2.mid)` ×6, `v(d)` ×68, …). Item 9
   flips them. The risk is updating an assertion that was testing something
   *else* and happened to be lowercase; each edit needs the receipt to show
   which mode the surrounding check is exercising.
5. **The two-pane signal browser** groups and classes names by parsing them;
   whether any of that folds has not been audited. Add a scan to item 5.
6. **`vcd_read.c` already keeps names verbatim** and its `:140` comment
   documents the resulting `get_raw_index` mismatch as a known cost. Item 2
   should set a VCD `Raw`'s `case_mode` to `preserve` and delete that comment's
   apology — but that changes VCD lookup behaviour, so it is a *deliberate*
   sub-step with its own checks, not a drive-by.
7. **Backannotation (`token.c`, 10 sites) is left folding** and keeps working,
   because `get_raw_index` retains the fold rungs under preserve (§D1). Under
   `distinguish` it will break. Accepted for this batch; note it in item 15's
   docs as a known distinguish-mode limitation.
8. **The GUI-test gate.** Item 13 is the only item with pixels. Press
   `Allow 2h` once before starting it rather than per-run (see `CLAUDE.md`).
9. **ver_50 is a private build at an absolute path.** Every test that needs it
   must **skip, not fail**, when it is absent, or the suite becomes
   unrunnable for anyone else. Guard on
   `[file executable $::env(NGSPICE_CASE_TEST)]` with a documented default.
   **The binary has moved once already** (round 1 measured the 2026-08-12 build;
   the path now holds the 2026-08-13 one with `0056`/`0057`/`0058`/`0060` in
   it). A test that pins a *behaviour* of that build is pinning a moving target:
   assert on `$curcasemode` where possible, and re-run `repro2/run_round2.sh`
   before trusting any §0 row again.
10. **Phantom `v(all)`** (§0b item 3). A deck whose total saved-vector count is
   exactly one gains a rawfile vector named `v(all)`, on stock too. ASE-L emits
   one `.save` card per output, so a one-output session shows it in the signal
   browser as if it were a net. Filtering it by name is the only lever we have
   and it is a poor one — a real net could be called `all`. Not in any item yet;
   decide with the user whether to filter, warn, or leave it and cite the
   upstream report (REPLY R3).

---

## 6. Sabotage checklist (per item, minimum)

- Item 1: force `case_mode` to 0 inside `read_dataset` ⇒ the preserve-fixture
  label checks must go red.
- Item 2: drop the verbatim rung ⇒ mixed-case lookup checks red.
- Item 7: return a constant `fold` from the probe ⇒ the ver_50 probe checks red.
- Item 9: restore the `string tolower` ⇒ the new schematic-case checks red.
- Item 10: bypass the pre-flight ⇒ the "refused before launch" check red.
- Item 11: drop `-nocase` ⇒ the fold-mode Value check red.

A check that stays green when its own code is broken is not a check.
