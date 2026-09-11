# Design B — "the simulator declares, the netlist permits, the GUI reflects"

**A design of record for ASE-L's analysis surface.**
Scope: ANALYSIS only. No design changes are proposed as *done*; everything here is a plan.
Reader: the future Claude Code session that will implement it in `/home/analog/dev/xschem-claude`.

| | |
|---|---|
| ngspice tree | `/home/analog/dev/ngspice`, `ver_50`, `ngspice-46-419-gccebdf2a2` |
| binary for every measurement below | `/home/analog/dev/ngspice/build-ver_50/src/ngspice` |
| xschem tree | `/home/analog/dev/xschem-claude`, `fluid-editing` — **dirty and moving**; every anchor below is a **proc or section name**, never a bare line number |
| evidence base | the 19 dossiers in `../dossiers/`, `00-critique.md` first |
| my scratch decks | `./probe-B/` (durable, beside this file) |
| written | 2026-09-09 |

Nothing in either repository was modified.

**Citation convention.** `F<n>` = a fact established in the brief. `[crit §x]`, `[ase-deck §x]`,
`[hidden-vars §x]` = the dossier that owns the evidence — cited, not restated.
**`[B-M<n>]` = measured by me in this pass**, deck in `./probe-B/`.

---

## 0. Thesis

> **A hardcoded analysis list is the original sin.** It is the single cause of every defect in
> this area: the silent drop (F2), the Options dialog that reports settings which are not in
> force (F3), the `dec` field that exists in three tables and reaches the deck in none
> (`ase-state.md` §3.1), and the seven-places-to-edit tax (`ase-ui.md` §2.10). It also violates
> the spec's own **D3** — "state schema + deck generation behind a per-simulator table"
> (`specs/ase_l.md`, quoted in `ase-conventions.md` §5.1).

The design replaces the four literal lists with **one declarative registry** and derives every
surface from it; and it derives what that registry is *allowed to offer* from two measurements
rather than from a literal:

1. **what the attached binary actually has** — extending `ase::sim_capabilities`, the probe-run
   machinery ASE-L already ships (F4), never a version string, never a hardcoded `#ifdef` guess;
2. **what the user's actual netlist actually permits** — an AC analysis with no AC source, an SP
   with fewer than two ports, a NOISE whose input source has no AC value, a `save` name that does
   not resolve (which is F7's segfault). ADE-L cannot do this because Spectre owns the netlist;
   ASE-L generates the netlist, so it can.

And one rule that makes both honest:

> **Nothing the window shows may fail to reach the deck, and nothing the deck contains may be
> unshowable in the window.** F3 is a *correctness* defect, not a feature gap. Fixing it is not
> optional and is not a stage — it is the acceptance criterion for the whole batch.

The forcing argument for the third pillar is F15: **the GUI is the only validator in the system.**
Unknown option names are accepted in silence, out-of-range values are dropped in silence, a
`CP_BOOL` written as `=1` is killed in silence, hex literals become `0` in silence. A design that
does not model option *types* and *delivery doors* cannot be honest, no matter how good its
layout is.

---

## 0.1 What I measured myself in this pass

Seven things. Five are new; two reconfirm a brief fact I was unwilling to build on second-hand.
Decks in `./probe-B/`.

**[B-M1] `help <verb>` redirects to a file, including the negative answer.** One `.control` deck
with `foreach v ac dc op tran pz tf disto noise sens sp pss hb optran / help $v >> f / end`
produces a file whose every stanza is either `<verb> [...] : <description>` or
`Sorry, no help for <verb>.` — `pss` and `hb` gave the negative, everything else gave the
positive, `optran` included. rc 0. *This is the capability probe.* It uses the **reliable**
per-command loop (`com_help.c:84`), not `help all`'s loop that truncates at the first NULL
`co_func` [crit §3.2], and it satisfies `ase::cap_run`'s standing doctrine — **the verdict comes
out of a file the deck asked for, never out of the log or the exit code** [ase-deck §6.2]. It is
strictly better than `ase-deck.md` §6.4's proposed `help all` probe, at the same cost (one run).

**[B-M2] `show v : acmag` answers exactly, after parse, with no analysis, and it sees inside
subcircuits.** On a deck with a top-level `v1 … ac 0`, a top-level `v2 … ac 1` and a source
buried in a subcircuit, the redirect produced:
```
     device                    v2                    v1             v.xi1.vin
      acmag                     1                     0                     2
```
So "does this circuit have an AC source, and which ones" is an **exact, expansion-aware,
hierarchy-aware** question with a cheap answer. This is the netlist-precondition engine's
strongest leg and no dossier proposed it.

**[B-M3] …but `portnum` is not readable that way.** `show v : portnum` returns `0` for a source
declared `portnum 1`, both before and after an `op`. `z0` *does* read back the given value. So
the SP port precondition must be a **static scan of the deck text**, not a `show` probe. Recorded
so nobody re-hunts it.

**[B-M4] A deck that parses and runs no analysis exits 1.** `Error: incomplete or empty netlist
… no simulations run!`, rc 1, while the redirects it asked for were all written correctly. A
parse-only introspection run therefore **must not** be judged by its exit code — which is exactly
the file-verdict doctrine ASE-L's probe already obeys.

**[B-M5] `.control` cannot branch on a string — in either direction.** With `set p = "const"`:
`if "$p" ne "const"` took the **false** branch and `if "$p" eq "const"` also took the **false**
branch. [crit §5.2] measured only the `ne` half. The full statement is: **a generated deck
contains no conditional logic at all**, except the numeric `$sim_status` guard ASE-L already
emits. Every decision belongs to the GUI, at render time. This is load-bearing for §8.

**[B-M6] The `.spiceinit` beside the deck wins, and `-n` kills the channel silently.** A
`.spiceinit` written into the deck's own directory is read **even when the process cwd is
elsewhere** — `main.c:1274-1279` searches `ngdirname(argv[optind])` *first*, then
`$SPICE_USERINIT_DIR`, then cwd, then `$HOME`, and stops at the first hit. Measured with
`.param rv = 'var(myres)'` + `set myres = 4700` in that file:
`resistance = 4700`. The same deck with **`-n`**: `resistance = 1e-12` — the resistor minimum,
**with no warning of any kind**. This is simultaneously the mechanism S7 needs (F15) and a
silent-failure mode the design must refuse to generate.

**[B-M7] Reconfirmed, because I am about to design refusals around them.** `.disto` with a
non-resolving `save` in ASE-L's exact `.control` shape → **SIGSEGV, rc 139** (F7); the same deck
with a resolving `save` → rc 0. And `ac lin 2 1k 11k` → `length(frequency) = 1`, `lin 3` → 3 (F8 /
[crit §D2]).

Also reconfirmed end to end, because the whole results design rests on it: F6's capture loop.
`set appendwrite` + `foreach p $plots / setplot $p / echo "PLOTMAP $p |$curplotname|" >> map /
write raw all / end` produced a four-plot rawfile and this map:
```
PLOTMAP const  |constants|
PLOTMAP op1    |Operating Point|
PLOTMAP noise1 |Noise Spectral Density Curves|
PLOTMAP noise2 |Integrated Noise|
```
Both plots of the NOISE analysis, captured, named, and mapped — with no counter guessing and no
string building. `echo … >> file` inside `.control` works, so the map is a **sidecar file**, not
a log line.

---

## 0.2 Coverage map

The brief names eight areas. Where each is answered, and the one-line answer.

| | area | answered in | the answer in one line |
|---|---|---|---|
| **S1** | the type list | §1, §4, D6–D12 | registry ∩ measured capability ∩ netlist admissibility, in four visible states — `ok` / `caution` / `blocked` / `absent` — and never invisible |
| **S2** | per-type metadata | §3.1, §3.2, §5 | one `ase::analysis_types` entry per type, with `fields`, `emit` as a token template, `plots` as measured literals, `needs`, `rules`, `options` and `results`; NOISE and SP filled in |
| **S3** | the form | §3.2, §6 | nine typed field kinds, a mode selector that relabels its neighbour, pickers reusing `select_on_design`, refusals on the form, and a verdict on all fifteen ADE-L behaviours |
| **S4** | the options surface | §3.3, §7 | delete the free text; one ~250-row catalogue carrying `cptype` + `door` + `phase` + `inert`; search-first with a changed-only default; convergence as guided remedies with `optran` finally visible |
| **S5** | the deck | §8 | `.control` commands, one at a time, no in-deck branching; two writer modes; eleven decks the GUI must refuse to generate; pre-deck options into `<rundir>/.spiceinit` |
| **S6** | results routing | §9 | a destination per plot, keyed on the literal `Plotname:`, joined through a plotmap sidecar; scalars from one-point plots; four new tables that are four `listdlg` configs |
| **S7** | beyond ADE | §10 | a shard runner driven by `.param x='var(…)'` + a per-shard `.spiceinit`, with the GUI as the random number generator; and five picks from F14, argued |
| **S8** | sequencing | §12, §13 | twelve stages, the first two carrying zero rulings; seven rulings, ordered, one at a time |
| — | the transport fork | §8.6, D20 | keep `-b`; add `-p` later as an additive second `run_cmd`; **refuse `libngspice`**, because ngspice segfaults on ordinary GUI-generated decks and in-process means the schematic dies with it |

---

## 1. The three-layer model

Every analysis type, every field on its form, and every option in its options sheet passes through
the same three gates. This is the whole architecture in one table.

| layer | question | source of truth | cost | failure mode it removes |
|---|---|---|---|---|
| **L0 — vocabulary** | *Can ASE-L render this at all?* | `ase::analysis_types`, a declarative Tcl registry in `ase.tcl` (Tk-free) | free | F2's silent drop: a type outside the registry is **refused at render**, loudly |
| **L1 — capability** | *Does the attached binary have it?* | `ase::sim_capabilities` extended with an `analyses_available` key, from **[B-M1]**'s probe deck | one probe run per binary, cached on path+mtime+size | a `pss` line that produces `pss: no such command available` in a log the user never opens |
| **L2 — admissibility** | *Does this netlist permit it, right now?* | `ase::netlist_facts`, a new pure-Tcl pass over the netlist text ASE-L already holds, plus (optionally) one parse-only probe run using **[B-M2]** | free / one parse per netlist, cached on the netlist text | F7's segfault, SP's `controlled_exit`, NOISE's `ac input not found`, DISTO's silent zeros |

**The presentation rule.** A type is in exactly one of four states, and **never invisible**:

| state | when | what the user sees |
|---|---|---|
| `ok` | L0 ∧ L1 ∧ L2 | normal |
| `caution` | L0 ∧ L1 ∧ L2-with-warnings | offered; the form carries a sentence saying what will be wrong (e.g. "3 of 14 devices contribute no noise") |
| `blocked` | L0 ∧ L1 ∧ ¬L2 | offered, **disabled**, with the reason and the fix ("SP needs two sources with `portnum`; this netlist has none") |
| `absent` | L0 ∧ ¬L1 | listed, **disabled**, greyed, with "this simulator does not have `pss`" and a **Detect** button |

Nothing is hidden. A user who cannot find `pss` in ADE-L has no way to learn why; a user who sees
it greyed with a sentence has learned something about their build. **That is the first place this
design is better than ADE-L, and it costs one word in a table.**

### 1.1 The unmeasured case, and the rule that stops it emptying the dialog

`ase::sim_capabilities`' standing contract is that a **missing key means "not measured", never
"no"**, and readers must not treat absence as a negative (`specs/ase_l.md` capability section;
decision **J** in `ase-conventions.md` §5.6). Applied naively to a type list, an unmeasured probe
would empty the Analyses dialog. That is unacceptable and unnecessary.

**Decision (D6 below): the registry declares `gated 0|1` per type, sourced from the `#ifdef` set
in `src/frontend/commands.c:312-362`.** `ac dc op tran pz tf disto noise sens` are unconditional
in every ngspice build that has ever shipped; `sp` (`RFSPICE`) and `pss` (`WITH_PSS`) are not.
So:

* `analyses_available` present → it is the authority, for gated **and** ungated types alike.
* `analyses_available` absent (unmeasured) → offer the **ungated baseline** as `ok`, and show
  every `gated 1` type as `absent`-with-Detect. We never *claim* a measurement; we fall back to a
  source-verified invariant. This keeps the contract and keeps the dialog useful.

---

## 2. Decisions

Each is numbered, has a reason, and is citable from a commit message, a suite row and a receipt.
⚖ marks one that **needs the user's ruling before it can ship** (collected in §13).

### Architecture

**D1 — One registry, `ase::analysis_types`, in `ase.tcl`, is the single description of an
analysis.** The radio row, the form, the Arguments column, the emit arm, the validation, the plot
map, the results destination and the capability gate all derive from it. *Reason:* today those
are seven independent literals and missing one fails silently (`ase-ui.md` §2.10); `ase.tcl` must
stay Tk-free so `--nogui` can drive every proc (`ase-state.md` §9.1 constraint 5).

**D2 — The registry is per backend, reached through an OPTIONAL hook, not a global.**
`ase::register_backend` requires exactly five hooks and tolerates extras (`ase::register_backend`,
`ase.tcl`); `capabilities` already rides optionally. `analysis_types` joins it. *Reason:* spec D3
demands the per-simulator table; a future Xyce backend must be able to declare a different
vocabulary without ASE-L knowing anything about Xyce.

**D3 — The state schema does not change.** `analyses` stays a list of open dicts with `type` and
`enabled`; `version` stays 1; no new top-level key. *Reason:* 105 committed `.state` files and
five byte-identity test rows (F13, `ase-conventions.md` §6). Everything new is either a per-row
key (merged over defaults, absent-by-default, free) or lives outside the state file entirely.

**D4 — Two optional per-row keys and no others: `id` and `x`.** `id` is a stable token that makes
several rows of one type addressable; `x` is a **verbatim escape hatch** (a list of raw `.control`
lines) which the Arguments column marks as unvalidated. *Reason:* `id` unblocks ADE behaviour #9
(`ase-ui.md` §6) without a schema version; the escape hatch replaces today's lying free-text
Options… bag with one that actually emits and says so.

**D5 — `ase::state_default` keeps its four rows.** ⚖ *Reason:* changing the seed moves
`test_ase_core.tcl` R1, the D1 golden and every freshly-created view; and Cadence does not add
analyses to your bench either. But it must be a **decision**, not an accident
(`ase-state.md` §6.4). See R1.

### Capability

**D6 — The type list is the join of the registry with `analyses_available`, with the ungated
baseline as the fallback.** §1.1. *Reason:* keeps the missing-key contract without emptying the
dialog.

**D7 — The capability leg is one new probe deck, added to the existing budget, verdict from a
file.** The deck is **[B-M1]**'s: `op`, then one `help <verb>` redirect per registry verb into a
single file, then `devhelp > families.txt`. It obeys `ase-deck.md` §6.4's five rules: budget
check first, publish only on a complete measurement, a timed-out leg does not poison the earlier
legs' answers, read the file not the log, one `cap_run` not five. *Reason:* F5 measured that
`help all` is wrong as a general inventory and `help <verb>` is the only reliable enumerator;
**[B-M1]** proves the redirect carries the negative answer too.

**D8 — The probe's three standing costs are paid, not inherited silently.** Issues 0953/0958/0959
(the probe runs inside the user's Run gesture, on every press, and its bound evaporates without
`timeout(1)`). The analysis dialog must use the **free peek** (`ase::sim_caps_have_path`, measured
447 ms cold / 0 ms warm / **31.2 s** for a program that never answers) and offer a **Detect**
button for the paid case — the pattern `simdlg_case_show` already ships. *Reason:* a startup probe
in front of the analyses list would make opening the dialog take 31 s on a bad binary
(`ase-conventions.md` §9.1).

**D9 — Capability answers about the *binary* and facts about the *netlist* are two different
caches with two different keys.** Binary → `ase::cap_key` (resolved path + args, stamped on
mtime+size). Netlist → the **exact netlist text**, which is already the key `op_annot::save_cards`
uses for the device-OP block. *Reason:* they invalidate on different events; conflating them
re-probes the binary on every schematic edit.

### Netlist admissibility

**D10 — `ase::netlist_facts {netlist_text}` is a pure-Tcl second pass beside `ase::netlist_map`.**
It reuses that proc's continuation-folding and `.subckt` scope stack, but *keeps* the parameter
tokens `netlist_map` throws away, and records per device: element letter, instance name, scope,
the `k=v` parameters and the positional tail. *Reason:* `netlist_map` deliberately discards
`k=v` tokens, so it cannot answer "does this source have an AC value"; the walk is worth reusing
and the map's `nodes`/`insts`/`devs` tables are exactly what a node picker and a source picker
need. `ase::netlist_map_resolve` — which `ase-state.md` §3.4 records as **built and unused** —
becomes the validator for every analysis argument that names something, which is its second
customer after the F7 mitigation.

**D11 — Preconditions are computed statically by default and exactly on request.** Static
(`netlist_facts`, free, runs on every netlist) can produce false negatives when the stimulus lives
in an `.include`d file — the blind spot `ase::netlist_map_resolve` already names and already
stands down for. Exact is **[B-M2]**'s parse-only probe (`show v : acmag`, `show all :`), one run
per netlist, verdict from a file, exit code ignored (**[B-M4]**). *Reason:* a false refusal is
worse than a missed one; the static pass **warns**, the exact pass **blocks**.

**D12 — The device × analysis matrix is computed for the user's deck, not asserted.** Two joins:
the binary's compiled-in families (`devhelp`, from D7's same probe run) × the deck's actual
families (element letter + `.model` type + `level`/`version`, the static table in
`cider-devices.md` §2.8(a); or `show all :` for the exact answer) × the hook matrix
(`cider-devices.md` §2.5). The distinction that matters and that the dossier states plainly:
**a missing *contribution* hook (`DEVnoise`, `DEVdisto`) is usually correct** (an ideal E-source
is genuinely noiseless — `caution`), **a missing *matrix stamp* (`DEVacLoad`, `DEVpzLoad`) is
always wrong** (`blocked`, or a modal-strength warning for Mos6 / CplLines / TXL / LTRA).
*Reason:* this is the second thing the GUI can know that ADE-L cannot.

### The deck

**D13 — Analyses are emitted as `.control` COMMANDS, one at a time. Confirmed, not revisited.**
*Reason:* the critique's four, plus one of mine. A bare `run` dispatches **every** card in
`analInfo[]` order regardless of type [crit §5.5], which (a) reorders results, (b) starves
`.op`/`.tf` save scope, (c) is what surfaces F7's DISTO crash, (d) doubles a run under `-b`,
(e) makes two `.sens` cards abort with rc 134 while two `sens` commands are fine [crit §D5]. And
**[B-M5]**: the deck cannot branch, so a card-based deck could not even guard itself.

**D14 — The `.control` block contains no conditional logic other than the numeric `$sim_status`
guard.** *Reason:* **[B-M5]** — string `if` silently takes the false branch in **both**
directions. Every choice (which analysis, which plot gets the device names, which corner) is made
by the renderer, in Tcl, where it can be tested.

**D15 — Decisions A/D/E/F stand, in their existing shape.** `op` last (and the `dc ac tran op`
reorder when device-OP requests are live); a `sim_status` guard after **every** analysis, above
the write; `remzerovec` before every write, per plot; device `@dev` names ride the `op` write and
no other. *Reason:* every one is measured, with a cost figure or a masked-failure demonstration
attached (`ase-conventions.md` §5.6, `ase-deck.md` §4). New types declare an `emitorder`; the
op-last rule stays an explicit special case because its reason — ngspice's forward-only sticky
save list — is about `op` specifically and does not generalise.

**D16 — Two writer modes, chosen at render time by the enabled set.** ⚖
*Mode A (legacy)* — a `write` per analysis, exactly as today, when every enabled analysis is
declared single-plot and no multi-plot option (`keepopinfo`) is on. Renders **byte-identically**;
row E12 and the D1 golden prove it.
*Mode B (capture)* — no per-analysis `write`; instead F6's loop at the end of the block, with
`remzerovec` **inside** it so every plot is cleaned, and an `echo PLOTMAP …` sidecar line per plot
(**[B-M1]**/F6). Used whenever any enabled analysis is multi-plot (`noise`, `disto`, `sp`, `pss`)
or `keepopinfo` is on. *Reason:* F6 is analysis-blind and future-proof, but it cannot carry the
device-name write line (decision F), and mixing the two writers duplicates plots. The mode B
consequence — `op_save_tier`'s write-side tier `b` must downgrade to the save-side `optier_ctl`
shape — is the ruling (R6).

**D17 — Pre-deck options are delivered by a `.spiceinit` written beside the deck, plus `-D` for
the bool/string subset.** **[B-M6]** proves the file beside the deck is found first, from any cwd.
*Reason:* F15 §3.2's 26 variables cannot be reached by `.options` or `.control` at all, and `-D`
can only ever make a `CP_STRING` or a `CP_BOOL` (`main.c:984-999`), so it cannot deliver a
`CP_NUM`, `CP_REAL` or `CP_LIST`.

**D18 — If the simulator registry entry carries `-n` (`--no-spiceinit`), every pre-deck option and
the entire sweep/corner/MC mechanism are REFUSED, with a sentence.** **[B-M6]**: under `-n` the
same deck silently produced `1e-12` instead of `4700`. *Reason:* this is the exact class of silent
lie the design exists to delete, and ASE-L already knows whether `-n` is in force
(`ase::sim_nospiceinit`).

**D19 — ASE-L owns `<rundir>/.spiceinit` and says so.** It is deleted and rewritten per run like
the rawfile is (invariant I3's discipline), and if a `.spiceinit` is found there that ASE did not
write, the run is refused until the user rules. *Reason:* **[B-M6]**'s search order means our file
**shadows the user's `$HOME/.spiceinit` entirely** — silently changing what their other decks do
would be a betrayal, and silently *losing* their settings on this deck is the same bug the
casemode batch already recorded ("a `.spiceinit` silently defeating the flag").

### Transport

**D20 — Stay on `-b` batch for this batch. Design a `-p` pipe transport as a second, additive
`run_cmd` behind a registry flag. Refuse `libngspice`.** Argued in full in §8.6.

### Honesty

**D21 — Any value the form collects and cannot emit is REFUSED at OK, not stored.** This is UX
Stage F4's own ruling, adopted verbatim. The only storable-but-unemitted thing is the explicitly
labelled `x` verbatim list (D4), which *does* emit. *Reason:* F3 — the window currently reports
simulation settings that are not in force, across 420 analysis rows in the tree.

**D22 — Refusals appear where the typing is.** Generalise `ase::ui::rsel_status` into
`ase::ui::dialog_status {w key msg}`, gridded at a reserved high row — Choose Analyses already
reserves rows 8 and 9 for exactly this reason. The `ase::echo` line stays, for the action log and
for headless assertions. *Reason:* `FINDINGS.md` `refusals-appear-in-a-different-window`; today
OK "does nothing" and the sentence lands in another window.

**D23 — Every option descriptor carries its `CP_` type and its delivery door, and the emitter is
the only thing allowed to spell an option line.** *Reason:* F15's four silent-failure traps are
all type errors: a `CP_BOOL` written `=1` is off; a `CP_NUM` written bare is off; `-D name=value`
is always a string; a quoted number is inert. There is **no runtime way to discover a variable's
class**, so the table ships with the GUI or the GUI is guessing.

**D24 — An option that is INERT in this build is never offered as a live field.** The
do-not-offer list is `hidden-vars.md` §7.11 plus F8: `itl1/itl2/itl4` below 100 (clamped by
`niiter.c:37-39` — the widget clamps to ≥100 and says why), `itl3`, `itl5`, `ramptime`,
`oldlimit` (dead on the `.control` route, which is *our* route), `klu_memgrow_factor`, `newtrunc`,
`scalm`, `nosavecurrents` (does not exist), `x11lineararcs`, `debug`.

---

## 3. The data structures

Real shapes, in the house's Tcl idiom. `ase.tcl` is Tk-free; only §3.6's renderers live in
`ase_window.tcl`.

### 3.1 `ase::analysis_types` — the analysis registry

One entry per type. Everything a consumer needs is here and nowhere else.

```tcl
# ── ase.tcl ────────────────────────────────────────────────────────────────
# THE analysis registry. Backends declare it through the optional
# `analysis_types` hook (D2); ase::analysis_types resolves the hook for the
# simulator in force and falls back to {} — never to a literal list.
#
# CONTRACT
#   * `verb`      is what `help <verb>` is probed with (D7) AND what is emitted.
#   * `gated 1`   means an #ifdef in commands.c can remove it (D6).
#   * `fields`    is BOTH the form order and the Arguments-summary order. One
#                 list, so `anaargs` and `chana_fields` cannot drift again
#                 (they already did: `ac`'s dead `dec`, ase-state.md 3.1).
#   * `emit`      is DATA, not code: a token template. `build` is the escape
#                 hatch for a composite argument (noise's v(out,ref)).
#   * `plots`     is the list of Plotname: LITERALS this analysis can write.
#                 Measured, per outputs.md 3 with the critique's C4 corrections.
#   * `needs`     is a list of precondition ids evaluated against netlist_facts.
#   * `results`   names the destination for each plot (S6). No analysis may be
#                 registered without one — that is how decision B/C is enforced
#                 structurally instead of remembered.
proc ase::analysis_types {{sim {}}} { … resolve the hook, cache per sim … }
```

A hard entry, filled in completely — **NOISE**:

```tcl
noise {
  label      {Noise}
  verb       noise
  gated      0
  emitorder  40
  multiplot  1                                    ;# forces writer mode B (D16)
  fields {
    output {kind nodepair  label {Output}          pick node
            required 1  unit {}  help {noise output summation node, optional ref}}
    source {kind source    label {Input source}    pick source
            required 1  filter {type {v i} acgiven 1}
            help {must be a V or I source WITH an ac value}}
    sweep  {kind mode      label {Sweep type}      values {dec oct lin}
            default dec  relabels points}
    points {kind int       label {}                ;# minted by `relabels`
            required 1  min 1  default 10}
    start  {kind freq      label {Start frequency} unit Hz  required 1  gt 0}
    stop   {kind freq      label {Stop frequency}  unit Hz  required 1  gt 0}
    ptssum {kind int       label {Points per summary}  min 0  default {}
            advanced 1
            help {0 = spectrum only. >=1 also produces the per-device
                  noise-contribution vectors AND decimates the spectrum by
                  this factor. 1 gives the breakdown with no decimation.}}
  }
  emit {noise @output @source @sweep @points @start @stop @ptssum?}
  rules {
    {lin_two   {sweep eq lin && points eq 2}   refuse
       {a linear sweep of 2 points yields ONE point; use 3 or more}}
    {single_f  {start eq stop}                 warn
       {single-frequency noise produces NO Integrated Noise plot}}
    {klu       {opt klu}                       ok}        ;# noise refuses KLU itself, cleanly
  }
  needs {ac_source input_source_ac output_node_resolves}
  plots {
    {match {Noise Spectral Density Curves*}  role spectrum
     results viewer   label {Noise — spectral density}}
    {match {Integrated Noise*}               role scalars
     results outputs  label {Noise — integrated}}
    {match {NOISE Operating Point}           role opinfo
     results viewer   label {Noise — operating point}  when {opt keepopinfo}}
  }
  options {sqrnoise keepopinfo noisyxspice enable_noisy_r}   ;# per-analysis subset (S4)
}
```

And a **gated** one, to show what changes — **SP**:

```tcl
sp {
  label      {S-parameter}
  verb       sp
  gated      1                                    ;# RFSPICE; --disable-sp removes it
  emitorder  45
  multiplot  1                                    ;# keepopinfo adds "AC Operating Point"
  fields {
    sweep   {kind mode  label {Sweep type} values {dec oct lin} default dec relabels points}
    points  {kind int   label {} required 1 min 1 default 10}
    start   {kind freq  label {Start frequency} unit Hz required 1 gt 0}
    stop    {kind freq  label {Stop frequency}  unit Hz required 1 gt 0}
    donoise {kind bool  label {Compute noise figure} default 0}
  }
  emit  {sp @sweep @points @start @stop @donoise}
  rules {{lin_two {sweep eq lin && points eq 2} refuse
            {a linear sweep of 2 points yields ONE point; use 3 or more}}}
  needs {two_ports contiguous_ports}              ;# BOTH are `blocked`, never `caution`
  fatal {two_ports contiguous_ports}              ;# <-- see below
  plots {
    {match {SP Analysis}       role smatrix results sparam label {S-parameters}}
    {match {AC Operating Point} role opinfo  results viewer label {SP — operating point}
     when {opt keepopinfo}}
  }
  options {keepopinfo noopac sqrnoise}
}
```

**The `fatal` key is the point of the whole design.** `span.c:376-386` calls
`controlled_exit(EXIT_BAD)` when there are fewer than two ports: the process dies, the `.control`
block never resumes, **and every other analysis in the deck is lost** — while `run_done` may still
see rc 0 if a later analysis already succeeded (`ase-deck.md` I6 records exactly that shape). A
precondition listed in `fatal` is one where an unmet condition does not degrade the run, it
destroys it. Those preconditions are **checked in `render_deck` as well as in the dialog**, and
`render_deck` refuses to produce the deck.

### 3.2 The field descriptor

`kind` is the whole type system. Nine kinds, each with exactly one widget, one validator and one
emitter.

| `kind` | widget | validate | emits | picker |
|---|---|---|---|---|
| `int` | entry | integer, `min`/`max` | bare | — |
| `real` | entry + suffix parser | SPICE suffix (`f p n u m k Meg G T`) | as typed | — |
| `freq` | entry + suffix, unit `Hz` | `> 0` for `dec`/`oct` | as typed | — |
| `time` | entry + suffix, unit `s` | `>= 0` | as typed | — |
| `mode` | readonly `ttk::combobox` | member of `values` | the token | — |
| `bool` | `checkbutton` | — | present/absent, **never `=1`** | — |
| `node` | entry + **Pick** button | `netlist_map_resolve` `present` | `v(<n>)` | `select_on_design` |
| `nodepair` | two entries + Pick | both resolve; ref optional | `v(a)` or `v(a,b)` | `select_on_design` |
| `source` | combobox from `netlist_facts` + Pick | in the filtered set | instance name | `select_on_design` |
| `device` / `param` | combobox from `netlist_facts` / `devhelp -flags` | in the set | as typed | — |

`relabels <field>` is the sweep-mode mechanism ADE-L is known for, and it is **one line** here
because `ase::ui::dialog_row` names its label `$w.l<ename>`:

```tcl
# ase_window.tcl — the mode selector's -command
proc ase::ui::chana_mode_changed {key type field} {
  set w   [ase::ui::chana_path $key]
  set fd  [ase::analysis_field $type $field]           ;# the mode descriptor
  set tgt [dict get $fd relabels]
  set lbl [dict get [ase::analysis_field $type $tgt] labels [ase::ui::dlg_get $key $field]]
  $w.l$tgt configure -text $lbl                        ;# "Points per decade:" etc.
}
```
with the label set as data on the target field:
```tcl
points {kind int  labels {dec {Points per decade} oct {Points per octave}
                          lin {Number of points}} …}
```
There is no other way in this codebase that a user learns `points` means *per decade* — today it
renders as `Points:` from `[string totitle $f]` with no unit and no hint (`ase-ui.md` §2.5).

### 3.3 The option catalogue

Two catalogues (F15: OPTtbl's ~86 keywords and 163 `cp_getvar` variables, **provably disjoint**),
one table, four extra columns that make them safe.

```tcl
# ase.tcl — one row per option, ~250 rows, generated once from the dossiers and
# then hand-maintained. THE FOUR COLUMNS THAT MATTER ARE cptype, door, phase
# and inert; without them the GUI is guessing (D23).
variable ase::sim_options {
  reltol   {cat task  type real   door options   scope global
            group tolerances  default 1e-3  gt 0
            help {relative error tolerance of the Newton loop}}
  sqrnoise {cat var   cptype bool door options|control  scope {analysis noise}
            group output  default 0
            help {report noise as V^2/Hz instead of V/sqrt(Hz)}}
  interp   {cat var   cptype bool door control    scope global  phase output
            group output  default 0  results 1
            help {resample every plot onto a uniform grid before writing}}
  warn     {cat var   cptype num  door options    scope global
            group diagnostics  default 0
            help {enable SOA checking (OP, DC, TRAN only)}}
  casemode {cat var   cptype string door predeck  scope global  phase L1
            values {fold preserve distinguish}
            owner casemode_batch
            help {node-name case policy; MUST be delivered before the deck is read}}
  wnflag   {cat var   cptype num  door predeck-file  scope global  phase L1
            help {MOS W is total (0) or per finger (1)}}
  itl1     {cat task  type int    door options   scope {analysis op}
            group iteration  default 100  min 100
            clamp {niiter.c floors every limit at 100; values below it are inert}}
  oldlimit {cat task  type bool   door options   scope global
            inert {TSKfixLimit is never copied by CKTnewTask, so this option is
                   silently dropped on the .control route ASE-L uses}}
  ramptime {inert {live code is inside #ifdef XSPICE_EXP, defined nowhere}}
  …
}
```

`door` is the delivery decision and it is **computed, never typed by a user**:

| `door` | emitted as | when |
|---|---|---|
| `options` | `.options name` / `.options name=v` above `.control` | OPTtbl keywords; `cp_getvar` vars read at/after `inp.c:1376` |
| `control` | `set name` / `set name=v` inside `.control` | same set; used when the value must not survive into a sibling deck |
| `predeck` | `-D name` or `-D name=<string>` | `phase L1/L2` **and** `cptype` ∈ {bool, string} |
| `predeck-file` | a `set` line in `<rundir>/.spiceinit` (D17/D19) | `phase L1/L2` **and** `cptype` ∈ {num, real, list} |
| `cmdline` | a real argv flag (`--soa-log=…`) | the handful that are flags |

And the emitter is the only speller (D23):

```tcl
proc ase::opt_line {name value} {
  set d [dict get $::ase::sim_options $name]
  if {[dict exists $d inert]} {
    return -code error "ase: option '$name' does nothing in this build: [dict get $d inert]"
  }
  switch -- [dict get $d cptype] {
    bool   { if {$value in {1 true yes on}} { return "set $name" }
             return {} }                    ;# absence IS off; `set x=0` is ALSO off, but
                                            ;# `set x=1` would be off too — never emit `=`
    num - real { if {$value eq {}} { return {} }
                 return "set $name=$value" } ;# a bare `set` here is silently inert
    string { return "set $name=\"$value\"" }
    list   { return "set $name = ( [join $value { }] )" }
    default { return [ase::opt_dotline $name $value] }   ;# OPTtbl: .options name=v
  }
}
```
Three of F15's four traps die in that `switch`; the fourth (`-D name=value` is always a string)
dies in the `door` computation, which never routes a `num`/`real` to `-D`.

### 3.4 The capability answer, extended

Two new keys, following the existing naming and the missing-key contract:

```
{known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1
         analyses_available {ac dc disto noise op pz sens sp tf tran}
         devices_available  {resistor capacitor vsource … d_cosim adc_bridge …}}
```
`analyses_available` is the `^(\S+) ` scan of **[B-M1]**'s per-verb file, keeping only stanzas
whose first token equals the verb probed. `devices_available` is the `devhelp` dump, which is a
*stronger* XSPICE signal than the `codemodel` command (the command proves XSPICE was compiled;
the models prove `spinit` actually loaded them) and is the CIDER probe (`numd`/`nbjt`/`numos`).

Derived booleans stay derived, never stored: `has_sp`, `has_pss`, `has_cider`, `has_xspice`.

### 3.5 `ase::netlist_facts` — the netlist answer

```tcl
# ase.tcl — a SECOND pass over the same text ase::netlist_map walks, keeping the
# k=v parameters that netlist_map deliberately drops.
#   -> {sources {<inst> {scope <s> letter v|i ac <mag> dc <v> portnum <n>
#                        z0 <r> stimulus 0|1 trnoise <args>}}
#       families {resistor 1 vsource 1 mos1 1 …}      ;# static guess (cider 2.8a)
#       nodes    <from netlist_map>
#       exact    0|1}                                  ;# 1 after the parse probe
proc ase::netlist_facts {netlist_text} { … }
```

Predicate table — the `needs` vocabulary, each with its verdict class and its evidence:

| id | predicate | verdict | evidence |
|---|---|---|---|
| `ac_source` | ≥1 independent source with a non-zero AC magnitude | `caution` static / `blocked` exact | **[B-M2]**; `vsrcload.c` AC arm |
| `input_source_ac` | NOISE's named source exists, is V or I, and has `acGiven` | `blocked` | `noisean.c:110-142`, `E_NOACINPUT` |
| `output_node_resolves` | every node named on the form resolves | `blocked` | `ase::netlist_map_resolve` |
| `two_ports` | ≥2 V sources carrying `portnum` | **fatal** | `span.c:376-386` `controlled_exit` |
| `contiguous_ports` | portnums are 1..N, unique | `blocked` | `span.c` port promotion |
| `distof_source` | ≥1 source carrying `distof1` (and `distof2` when `f2overf1` is set) | `caution` | `an-smallsig.md` §6.4 |
| `disto_devices` | ≥1 device family with `DEVdisto` | `caution` ("will return zeros") | `cider-devices.md` §2.6.1 |
| `noise_devices` | ≥1 device family with `DEVnoise` | `caution` | `cider-devices.md` §2.6.2 |
| `pz_devices` | no family lacking `DEVpzLoad` | `blocked` (Mos6/CplLines/TXL/LTRA) | `cider-devices.md` §2.6.4 |
| `sens_params` | ≥1 eligible perturbable parameter | `blocked` | the `devhelp -flags` predicate, [crit §5.6] |
| `saves_resolve` | **every** `save`/output name resolves | **fatal when `disto` is enabled** | F7 / **[B-M7]** |
| `sweep_target` | DC's source is an R, a V, an I, or the literal `temp` | `blocked` | `dctrcurv.c:89-151`, F10 |

`saves_resolve` deserves its own line: it is a *cross-row* precondition — a stale Outputs row plus
an enabled DISTO is a **SIGSEGV**, and ASE-L's Outputs pane emits exactly those `save` lines
today. This is the single most valuable thing L2 buys.

### 3.6 What the GUI derives, and what it stops owning

| consumer | today | after |
|---|---|---|
| radio row | `foreach t {op dc ac tran}` | `foreach t [ase::analysis_types_offered $key]` — a **wrapping grid**, not `pack -side left` (which overflows past ~8) |
| the form | `chana_fields` + `[string totitle $f]:` | `fields` → typed widgets, real labels, units, pickers |
| the destroy list | **a hardcoded five names** | every widget the previous type built, tracked in `dlg($key,anwidgets)` — this is `ase-ui.md`'s "single sharpest trap" and it must die in stage 1 |
| Arguments column | `anaargs` order then unknown keys | `fields` order, then `x` marked `verbatim:` |
| the emit arm | a four-arm `switch` | `ase::emit_analysis $row` over `emit`, plus a loud `default` |
| `plot_sim_type` | a fourth literal list | the `plots` table, matched on the literal `Plotname:` |
| validation | "non-empty when enabled" | `required` / `min` / `gt` / `values` / `rules` / `needs` |

---

## 4. S1 — the type list

Answered by §1 and D6–D12. What remains is the three named hard cases.

**PSS — an analysis the binary lacks.** `gated 1`, absent from `analyses_available` on this build
(**[B-M1]**: `Sorry, no help for pss.`). Shown greyed with "this ngspice was built without PSS
(`--enable-pss`)". **And it is refused even on a build that has it**, until someone runs it:
nobody has ever executed PSS (F1, [crit §5.7 item 1]), the two plot-name literals are read from
source and unverified, and `dcpss.c:988-996` has a recursive re-entry nobody has proven
terminates. `registered 0` in the registry — present so the reader knows why it is missing, with
the closing procedure written in the entry itself. See §14.

**DISTO — an analysis that exists but is dangerous.** Offered, `ok`, **with `saves_resolve`
promoted to `fatal` whenever it is enabled** (§3.5). The mitigation ladder, in the order the
critique gives it: (1) never emit a narrowed `save` in the same run as `disto`; (2) validate every
`save` name against the netlist first; (3) upstream, capture `OUTpBeginPlot`'s return at all five
`distoan.c` sites, mirroring `acan.c:169-175`. This design takes (2) as the rule and (1) as the
fallback when the netlist cannot answer (an `.include`-bearing scope, where
`netlist_map_resolve` stands down): **if we cannot prove the save list resolves, we widen it to
`save all` for that run and say so.** A wide save is a big file; a segfault is a lost run.

**SENS + KLU — a combination that is dangerous.** `sens … ac` under `option klu` is a SIGSEGV
while `sens … dc` is safe (F8 / [crit §D3]); NOISE and PZ refuse KLU cleanly themselves. This is
an **option × analysis cross-rule**, and it is only expressible because §3.3 models options as
typed objects rather than free text:
```tcl
{klu_sens_ac  {opt klu && type eq sens && mode eq ac}  refuse
   {ngspice segfaults on AC sensitivity under the KLU solver; use 'sparse',
    or switch this sensitivity to DC}}
```
The refusal offers the fix, in the dialog, at the moment of typing. ADE-L has no sensitivity
analysis at all.

**And F2's silent drop dies first, before any of this.** `render_deck`'s `switch` gains a
`default` arm that raises a named error; `ase::n_enabled_analyses` and the pane keep counting the
row, so the refusal is coherent with what the window shows. One rebuild, zero rulings, zero
suites moved — §12 Stage 0.

---

## 5. S2 — per-type metadata

§3.1 is the answer; two design notes remain.

**Why `emit` is a token template and not a `render` proc.** `ase-state.md` §9.3 proposes
`render ase::backend::ngspice::an_noise` — a proc per type. That is one file's worth of hand-written
emitters, and it puts the positional-argument rules (which F8, F16 and `dot_noise`'s parser prove
are the whole hazard) back into prose. A template plus **one** generic emitter means the
positional/optional/dependent rules are written once and tested once:

```tcl
# `@name`  a required slot        `@name?`  optional; omitted when empty
# `@name!` optional WITH A DEPENDENCY: emitting it forces every earlier
#          optional slot to be materialised with its `whenskipped` default,
#          because ngspice's argument lists are POSITIONAL. This is the rule
#          `tran tstep tstop [tstart [tmax]] [uic]` needs: a tmax with no
#          tstart must emit `tstart 0`, never shift a slot (UX Stage F4).
proc ase::emit_analysis {sim row} {
  set type [ase::state_get $row type]
  set e [ase::analysis_entry $sim $type]
  if {$e eq {}} {
    return -code error "ase: this simulator cannot run a '$type' analysis;\
 remove the row or disable it"                                    ;# THE default arm (Stage 0)
  }
  if {[dict exists $e build]} { return [[dict get $e build] $sim $row] }
  set out {}
  foreach tok [dict get $e emit] { … }
  return [list [join $out { }]]
}
```
`build` stays as the escape hatch for exactly two shapes that a template cannot express — NOISE's
`v(out,ref)` composite and PZ's four-node + two-mode-word form — and the registry entry says so.

**Why `plots` is a list of match patterns rather than one name.** Because one analysis is not one
plot, and the count is *conditional*: `noise` writes 2 (or 1 at a single frequency, measured);
`disto` writes 2 or **5** with `f2overf1`; `ac`/`sp`/`noise`/`pz`/`disto` each write an **extra**
operating-point plot under `keepopinfo`; and `pz`'s op plot is labelled `Distortion Operating
Point` — an upstream copy-paste bug, verified. A GUI that assumes one plot per analysis is wrong
five different ways. Matching on the measured literal, with `when` clauses for the conditional
ones, is the only shape that survives.

---

## 6. S3 — the form

### 6.1 Layout

Keep `ase::ui::choose_analyses`' skeleton — it is already an ADE-alike (F3) and the suites drive
it by path, so **adding** widget paths is safe and **moving** them is not.

```
.aseN.chana
 ├── .types      wrapping GRID of radiobuttons (4 per row), state-coloured per §1
 ├── .enable     "Enable" checkbutton
 ├── .form       ONE frame at grid row 2 — the swapped-in per-type form
 │    ├── .l<f> / .<f>          label + widget pairs, from `fields`
 │    ├── .p<f>                 a Pick button at column 2 for pick-able kinds
 │    └── .adv                  a disclosure holding `advanced 1` fields
 ├── .note       the precondition banner (§1 caution/blocked sentence)   row 7
 ├── .status     ase::ui::dialog_status                                  row 8
 ├── .opts       "Options…"                                              row 8 col 2
 └── .btns       Apply / OK / Cancel                                     row 9
```

**Putting the whole form inside one child frame at one grid row** kills two problems at once: the
hardcoded five-name destroy list (destroy `.form`, rebuild it), and the "seven or more quick
fields collide with the fixed rows 8 and 9" ceiling (`ase-ui.md` §5.3). NOISE has seven fields
today and SP has five plus a bool; DC-with-a-second-sweep has eight. The current layout cannot
hold any of them.

### 6.2 The fifteen ADE-L behaviours — adopt, improve, refuse

Against `ase-ui.md` §6, in its numbering.

| # | ADE-L behaviour | verdict |
|---|---|---|
| 1 | type row = what the simulator declares | **improve** — §1's four states; ADE-L shows no reason for an absent analysis |
| 2 | form swaps in place | **adopt** — already have it; move to one `.form` frame (§6.1) |
| 3 | Enable checkbox on the form | adopt, unchanged |
| 4 | Enabled column in the list | **improve** — today a `☑` glyph in a text cell: no keyboard reach, no undo, and a stray click in a 63 px column silently edits the deck. Make it Tab-reachable and Space-togglable |
| 5 | sweep mode selector that relabels its neighbour | **adopt** — §3.2's `relabels`; **improve** by adding the Start/Stop ⟷ Center/Span pair for AC and SP, computed in the GUI (ngspice has no center/span) |
| 6 | typed Options… sub-dialog | **improve, and this is the correctness item** — §7 |
| 7 | Apply | **adopt** ⚖ — a third button moves the button bar, which GE4 reads |
| 8 | per-type form memory across type switches | **adopt, but it reverses recorded decision D4** ⚖ R2 |
| 9 | several analyses of the same type | **adopt** via `id` (D4) ⚖ R3 |
| 10 | list starts empty | **refuse for now** ⚖ R1 — 105 states and W1p |
| 11 | field-level rejection on the form | **adopt** — D22 |
| 12 | typed, unit-bearing fields | **improve** — §3.2; plus the *derived readouts* nobody offers: "5 decades × 10 = 51 points", "≈ 2.1 MB", "flat to 500 kHz" |
| 13 | pick from the design | **improve** — `select_on_design` already turns a schematic click into a hierarchy-qualified, bus-aware name, for outputs. Point it at a **source instance** for DC's sweep source and NOISE's input source, and at a **net** for NOISE's output. ADE-L makes you type those names |
| 14 | analyses run in list order | **refuse** — `emitorder` + the op-last rule; issue 0964's 74.9 MB is the reason |
| 15 | the setup travels with the cellview | already true, and better (multiple `.state` views per cell) |

### 6.3 Where a refusal appears

Three tiers, and the tier is a property of the *rule*, not of the moment:

1. **live, per field** — a `-validate key` handler (the idiom exists in `simdlg_editor`, with the
   `after idle` deferral the tree measured) writes a sentence into `.status` and marks the label
   with a `⚠ ` prefix. No red: **the locked 9-colour palette has no error colour**, and adding one
   is a ruling I do not need. A glyph is theme-proof.
2. **at Apply/OK** — `required`, cross-field `rules`, and `needs`. Refuse, keep the dialog up,
   sentence in `.status`, and — new — **focus the offending widget**. Today there is no `focus`
   call anywhere in `choose_analyses`.
3. **at render** — `fatal` preconditions and D21. `render_deck` refuses, `ase::run_deck` re-raises
   unchanged, the run never starts, no artifact is touched. This tier exists because a `.state`
   can be hand-edited and because a netlist can change under a saved analysis.

---

## 7. S4 — the options surface

### 7.1 First, stop lying

`ase::ui::chana_options` collects free-text name/value pairs, round-trips them, renders them in
the Arguments column — and **never emits them** (F3, measured end to end: typed
`uic 1 tstart 5u tmax 1n`, the pane showed all three, the deck said `tran 10n 200u`). The fix is
not to make free text emit; it is to **delete free text** (D21):

* every field a type genuinely has becomes a **typed field** in `fields` (`tran`'s `tstart`,
  `tmax`, `uic`; `ac`'s `lin|oct|dec`; `dc`'s second sweep; `noise`'s `ptssum`) — most of them
  behind the `advanced` disclosure;
* every *option* becomes a row in §3.3's catalogue with a door and a type;
* anything else is **refused at OK** with the sentence "ASE-L cannot emit an option named `<x>`";
* and the one honest escape hatch is `x` (D4) — a list of raw `.control` lines, emitted verbatim
  immediately before the analysis, rendered in the Arguments column as `verbatim: <n> line(s)`.

That single change converts the worst failure mode in the area (a window that reports settings
which are not in force) into either a working setting or a refusal.

### 7.2 Finding one option among ~250 without a wall of fields

Four affordances, in the order a user reaches for them:

1. **Search first.** One entry at the top of the Options dialog, filtering the whole catalogue on
   name, group, and help text, live. `ase::ui::combo_filter`'s prefix-match idiom generalises.
2. **"Changed only" is the default view.** The table shows what differs from default, with a
   `[Show all]` toggle. A design's option sheet is normally 0–5 rows; the wall only exists when
   you insist on rendering it.
3. **Groups, not an alphabet.** `hidden-vars.md` §7's eleven categories are the grouping, already
   done: tolerances, iteration limits, timestep/integration, convergence aids, device defaults,
   temperature, solver, output/formatting, diagnostics, netlist processing, inert.
4. **Two scopes, on two surfaces.** Global options live in `Simulation > Options…`, which already
   exists and already has a state key (`options`) and an emitter. Per-analysis options live behind
   the analysis form's `Options…` button, filtered by `scope {analysis <type>}` — the mapping is
   `options.md` §10.2, already tabulated per analysis. An option shown in the wrong scope is worse
   than one not shown.

### 7.3 The pre-deck class, made visible

26 of F15's variables are unreachable from `.options` and from `.control` (§3.2 there). They get
their own group, labelled **"Applied before the netlist is read"**, and the dialog says which door
each will use. This is not a nicety: `.options casemode=preserve` and `.options nosubckt` are
*silently ignored*, and a GUI that offers them beside `reltol` teaches the user something false.

Delivery is D17/D19; the `-n` refusal is D18. The `.spiceinit` we write also carries `source
<user's ~/.spiceinit>` when one exists, so shadowing does not mean losing — with a measurement
debt (§15 M4).

### 7.4 The inert list, and the clamp

D24. Three shapes:

* **not offered at all** — `ramptime`, `klu_memgrow_factor`, `nosavecurrents`, `scalm`, `itl3`,
  `itl5`, `x11lineararcs`, `debug`, `newtrunc`;
* **offered with a clamp and a reason** — `itl1`/`itl2`/`itl4`, whose widget minimum is **100**
  with the tooltip "ngspice raises any limit below 100 (`niiter.c:37-39`), so the shipped defaults
  50 and 10 are already 100";
* **offered with a route warning** — `oldlimit`, which works from a dot card and is dropped on
  the `.control` route ASE-L uses (`cktntask.c:68`). Since we cannot honour it, D24 says do not
  offer it; the row stays in the catalogue with its `inert` reason so the *next* reader does not
  re-add it.

### 7.5 The convergence surface — a remedy, not a field wall

`options.md` §7 already contains the whole design: the four-rung `CKTop` ladder, its exact
`Note:`-prefixed progress strings, and a symptom → remedy table. Build it as:

* a **status pane** that parses the ladder live from the run's stderr — `Starting dynamic gmin
  stepping` → `… completed|failed` → `Starting true gmin stepping` → `Starting source stepping` →
  `Transient op started`. Two parser rules the dossier measured: the two `ngdebug` lines carry
  **no trailing newline**, and stdout/stderr are separately buffered so they must be captured as
  two ordered streams (ASE-L folds them with `2>@1` today — that is a **measurement debt**, §15
  M2);
* a **"Simulation failed — try this"** assistant, each remedy showing the exact `.options` line it
  will add, with a diff preview. Not thirty numeric fields;
* **`optran` as a panel** (F11, F14 #3). It is on by default (`1 1 1 100n 10u 0`, injected by
  `cp_init`), it returns the *transient* state at `opfinaltime` as the operating point (measured
  0.9999550 instead of 1.0 on a 1 µs RC), and it **supersedes** `noopiter`/`gminsteps`/`srcsteps`.
  No ngspice user has ever seen this knob. Four toggles plus two numbers plus a ramp, emitting one
  `optran a b c <step> <stop> <ramp>` line — and, crucially, a sentence in the OP form saying
  *"this operating point may come from a transient"*, because that is a fact about the numbers in
  the Value column.

---

## 8. S5 — the deck

### 8.1 Shape

Unchanged above `.control` (it is already schema-driven and generalises, `ase-deck.md` §7.1). The
block becomes:

```
.control
<pre_commands verbatim>
<cosim bridges>
set appendwrite                     ; when >=1 analysis is enabled
<setseed N>                         ; only when a stochastic feature asked for one
<optier_ctl device save commands>   ; before `op` (or before the first analysis in mode B)
--- per analysis, in emitorder with op last ---------------------------------
<x verbatim lines of this row>      ; D4, if any
<the analysis line from ase::emit_analysis>
if $?sim_status = 0 … end / if $sim_status ne 0 … quit 1 … end     ; D15, EVERY analysis
[mode A] remzerovec
[mode A] write <raw> [all <device names>]
-----------------------------------------------------------------------------
[mode B] foreach p $plots
[mode B]   setplot $p
[mode B]   echo "PLOTMAP $p |$curplotname|" >> <cell>_ase.plotmap
[mode B]   remzerovec
[mode B]   write <raw> all
[mode B] end
<print lines at the anchor>
.endc
```

Notes that are decisions, not taste:

* **The guard stays immediately after each analysis, above any write** (D15). In mode B this means
  a failure at analysis 3 of 4 writes *nothing at all*, where mode A would have written the first
  two — which is not a regression, because everything downstream is gated on `exitcode == 0`
  anyway (`ase::ui::run_finished`).
* **`remzerovec` moves inside the loop in mode B, and that is strictly better**: it is per-plot,
  and today's single post-analysis call only ever cleans the plot the simulator happens to be
  standing in — which for `noise` is `Integrated Noise`, not the spectrum.
* **The plotmap sidecar is deleted before the run**, exactly like the rawfile, because `>>`
  appends (invariant I3's discipline generalised).
* **The `constants` plot comes along** in the capture loop and the *reader* filters it. It cannot
  be filtered in the deck: **[B-M5]**.

### 8.2 The decks the GUI must refuse to generate

This list is the design. Each item is a `rules`/`needs` entry, each has a measurement.

| # | refuse | because | evidence |
|---|---|---|---|
| 1 | `disto` enabled together with any `save`/output name that does not resolve | **SIGSEGV, rc 139** | F7 / **[B-M7]** |
| 2 | `sens … ac` while the solver is `klu` | SIGSEGV; `dc` mode is safe | F8 / [crit §D3] |
| 3 | any sweep with `lin` and `numsteps` = 2 | silently yields **one** point | F8 / **[B-M7]** |
| 4 | `sp` with fewer than two `portnum` sources, or non-contiguous port numbers | `controlled_exit(1)` kills the process and every later analysis with it | `span.c:376-386` |
| 5 | an enabled analysis whose `type` is not in the registry | today it runs, exits 0, writes a raw and produces nothing | F2 |
| 6 | an enabled analysis missing a `required` field | `render_deck`'s bare `dict get` raises a raw Tcl error mid-run | `ase-state.md` §3.4 |
| 7 | two `.sens` **dot cards** | rc 134, `malloc(): unsorted double linked list corrupted` | [crit §D5] — n/a on our route, recorded so nobody adds a card path |
| 8 | any pre-deck option while `-n` is in force | silently ignored; **[B-M6]** measured 4700 → 1e-12 with no message | D18 |
| 9 | `trrandom` on a *current* source | freezes after the first missed timepoint; emit a V source + a VCCS instead | F16 |
| 10 | `trnoise` attached to a source that carries a stimulus | the stimulus is replaced | F16 T5 |
| 11 | a bare `@dev` name on any write other than the `op` write | dims=1, one non-zero sample at index 0, silently | decision F |

Items 1, 4 and 5 are `fatal`: checked in the dialog **and** re-checked in `render_deck`, because a
state file can be hand-edited and a netlist can change under a saved analysis.

### 8.3 Where the pre-deck options go

Outside the deck, by definition (F15). `<rundir>/.spiceinit` (D17/D19, **[B-M6]**) plus `-D` for
the `CP_BOOL`/`CP_STRING` subset, plus real argv flags for the handful that are flags
(`--soa-log=FILE`, which is *paired* with `warn` — a `.options` value and a command-line flag, two
doors for one feature, and the plan must emit both or the log file stays empty).

### 8.4 Dot cards

Still none for analyses (D13). But three *non-analysis* cards want the slot above `.control`, and
`ase-deck.md` I2 says a card must go there: `.four`, `.probe` and `.meas`. `.meas` is refused with
`-r` and is fine as a command; **`.probe` and `.four` are cards**. The design reserves one new
emission slot — after the `.save` block, before the op-annot block — and states the invariant:
**nothing analysis-shaped ever goes there.**

### 8.5 The scalar answers stop coming from the log

Decision B routes the Outputs Value column through `print` in the log, parsed by `result_probe`
for `<expr> = <number>`, anchored on `op` because a multi-point `print` emits a 20,514-row table
that yields nothing (issue 1243). That anchor is a workaround for a missing capability, and the
capability now exists: **every scalar an analysis produces is a one-point plot in the rawfile**
— `Operating Point`, `Integrated Noise`, `Transfer Function`, `Sensitivity Analysis` (DC). Reading
scalars from the raw instead of the log (a) removes the case-folding fragility `result_probe`'s
two-rung ladder exists to manage, (b) gives NOISE, TF and SENS a home in the Value column that
decision B currently denies them, and (c) is exactly what UX Stage F2 already proposed for a
different reason. ⚖ R4 — it changes what the pane shows.

### 8.6 The transport fork — `-b` vs `-p` vs `libngspice`

**Position: keep `-b`; add `-p` later as an additive second `run_cmd`; refuse `libngspice`.**

| | `-b` batch (today) | `-p` pipe | `libngspice` |
|---|---|---|---|
| abort | SIGKILL only. **No signal handlers are installed in batch** (F9): SIGINT is immediately fatal, rc 130, nothing written | SIGINT **pauses**; `resume` continues; `write` then `quit` salvages partials | `bg_halt`, a real pause/stop |
| progress | none. `HAS_PROGREP` is `HAS_WINGUI ∨ SHARED_MODULE`; this build has neither | none (same binary) | `SendStat`, throttled to 150 ms |
| live vectors | none | `$plots` on demand between commands | `ngSpice_AllVecs`, `ngSpice_CurPlot` |
| pre-deck options | `.spiceinit` + `-D` | **`set` before `source`** — no file, no shadowing | direct |
| blast radius of an ngspice crash | the child dies; xschem lives | the child dies; xschem lives | **xschem dies** |
| exists today | yes, pinned by `run_cmd` goldens (D4 row) | no | **no shared build exists on this machine** |

The decisive argument is the last row but one. **F7 is a four-line reproducible SIGSEGV in an
ordinary GUI-generated deck**, F8 is a second one, and this design's whole L2 layer exists because
ngspice can be made to die by a stale name in an Outputs pane. Linking that process into the
schematic editor means the user loses their unsaved schematic to a distortion analysis. On top of
that: no shared build exists, nobody has ever built one, and `CLAUDE.md` names
"anything touching global/static simulator state must survive repeated `ngSpice_Reset`" as a
*recurring bug class* with two recent commits. `libngspice` is refused (§14).

`-p` is genuinely attractive — it is the only route to graceful abort, and it makes the pre-deck
door a `set` line instead of a file that shadows `$HOME` — but it is a **different deck shape** (a
command stream, not a file), it changes `run_cmd`, and `run_cmd`'s word order is pinned byte for
byte by `test_ase_simreg_0931.tcl` D4 and must mirror the probe's. It is a stage of its own, and
its first customer is the transient debugger (`stop when` / `resume` / `step`), which cannot work
in batch at all.

**And a better abort exists that needs no transport change at all**: §10.1's shard runner. One
process per sweep point / corner / MC sample means Stop kills the current shard, every completed
shard's results survive on disk, and progress is `k/N` with no `SetAnalyse` and no parsing. The
architecture that S7 needs for other reasons happens to solve F9's worst symptom.

---

## 9. S6 — results routing

Decisions B and C say the Value column holds a **scalar and nothing else**. Every analysis
therefore needs a named destination, and "the waveform viewer" is not an answer for six of them.

| analysis | plots (measured `Plotname:` literals) | destination | label shown to the user |
|---|---|---|---|
| OP | `Operating Point` | Value column (1-point plot, §8.5) + canvas annotation (exists) | *Operating point* |
| DC | `DC transfer characteristic` | viewer; scale is `v-sweep`/`i-sweep`/`temp-sweep`/`res-sweep` and the axis label follows it | *DC sweep* |
| TRAN | `Transient Analysis` | viewer | *Transient* |
| AC | `AC Analysis` (+ `AC Operating Point` under `keepopinfo`) | viewer | *AC response* |
| NOISE | `Noise Spectral Density Curves[ - (V^2 or A^2)/Hz]` | viewer | *Noise — spectral density* |
| NOISE | `Integrated Noise[ - V^2 or A^2]` | **Value column** (1 point) | *Noise — integrated* |
| NOISE (`ptssum≥1`) | per-device vectors **inside** the spectrum plot | **new: Noise Summary table**, sorted by contribution | *Noise contributions* |
| TF | `Transfer Function` (3 vectors, 1 point) | **Value column** ×3 | *Transfer function / Input impedance / Output impedance* |
| PZ | `Pole-Zero Analysis` (complex, no scale) | **new: Poles & Zeros table** (Re, Im, f, Q) + an s-plane scatter | *Poles and zeros* |
| DISTO | `DISTORTION - 2nd harmonic`, `- 3rd harmonic`, or the three IM plots | viewer, one trace group per plot, **named by the literal** | *Distortion — 2nd harmonic* … |
| SENS (dc) | `Sensitivity Analysis` (real, 1 point, ~90 vectors) | **new: Sensitivity table**, sorted by \|value\|, with a normalised column | *Sensitivity* |
| SENS (ac) | `Sensitivity Analysis` (complex, `frequency` scale) | viewer | *Sensitivity vs frequency* |
| SP | `SP Analysis` | viewer + **new: S-parameter surface** (matrix picker, Smith/polar, `wrs2p` export) | *S-parameters* |
| PSS | two plots | **refused** (§14) | — |
| `.four` | a printed table + `fourierMN`/`thdMN` vectors | **new: THD readout + harmonic bar chart** | *Fourier* |
| `meas` | one length-1 vector each | Value column | the measurement's own name |
| trnoise run | `Transient Analysis` + an on-demand `linearize`+`fft` plot | viewer + Value column for the rms `meas` | *Transient (noise)* |

**Four new surfaces, and they are four instances of one thing**: a sortable two-to-four-column
table with a copy action. `ase::ui::listdlg` is *already* a config-driven table engine and
"adding a third entry is ~6 lines" (`ase-ui.md` §3.4). Poles & Zeros, Sensitivity, Noise
Contributions and the Fourier readout are four config entries plus one reader each. The
S-parameter surface is the only genuinely new one, and it can be deferred to its own stage.

**How the user is told which plot is which.** The plotmap sidecar (§8.1, **[B-M1]**) gives
`typename → literal Plotname` for every plot in the raw. The GUI joins that against each
registry entry's `plots` patterns and labels every trace group with the registry's `label`, not
with `noise1` and not with a guess. This is the fix for the "which analysis is the Value column
showing?" complaint (issue 0967/1243) generalised: **every result carries the name of the analysis
that produced it, everywhere it appears.**

---

## 10. S7 — beyond ADE-L

### 10.1 Sweeps, corners, Monte Carlo — the shard runner

F10: ngspice has no `.step` and no corner construct; `.dc` nests exactly twice, sweeps only
R / V / I / `temp`, and returns nested sweeps **flattened with no `Dimensions:` header**. So the
GUI generates the campaign. F15 + **[B-M6]** hand us the mechanism.

**The mechanism, measured.** A design variable declared as
```
.param rv = 'var(myres)'          <- emitted by ASE into the deck's .param slot
```
plus, in `<rundir>/.spiceinit`,
```
set myres = 4700
```
gives `@r1[resistance] = 4700` — **[B-M6]**, with the process cwd somewhere else entirely. The
schematic is untouched (F13's founding doctrine), the deck is untouched **between shards**, and
the only thing that varies is a two-line file.

**The architecture: one process per point.**

```
campaign/
  deck.spice                 <- ONE deck, byte-identical for every shard
  shard-0001/.spiceinit      <- set myres=4700 / set temp=27 / set mc_vth=0.71
  shard-0001/<cell>_ase.raw
  shard-0002/.spiceinit
  …
  index.tsv                  <- shard, axis coordinates, exit code, raw path
```

Why this shape and not a generated `.control` loop:

| | shard runner | one process, `.control` loop |
|---|---|---|
| abort | kill the current shard; **every completed shard survives** | Ctrl-C is *timing dependent*: it either kills one run and continues or discards the whole control block, and the user cannot tell which (`orchestration.md` §9.3) — "unusable as an abort mechanism" |
| progress | `k/N`, free | a generated `echo` the GUI must parse |
| an interrupted run | its shard has a non-zero exit code | leaves `sim_status = 0` — **indistinguishable from success** (`runcoms.c:343-347`) |
| the deck | one artifact, reviewable, diffable, hand-runnable | a generated loop nobody can read |
| results | one raw per point; the family is a directory | one raw with N plots, or a hand-built collector plot with the default-scale trap |
| parallelism | trivially available later | none |
| cost | N process starts + N parses | N parses (`reset`) or none (`alter`) |

The last row is the honest cost: `alter`/`altermod` avoid the re-parse and are much faster on a
big PDK deck. So: **`alter` axes may be collapsed into one shard** when every axis of the campaign
is an instance/model parameter, and the runner says which mode it chose. Everything else shards.

**Axis kinds**, each with its realisation (`orchestration.md` §11's model, made concrete):

| kind | realisation | notes |
|---|---|---|
| design variable | `.param x='var(ase_x)'` + `set ase_x=<v>` in the shard's `.spiceinit` | **[B-M6]**; needs no schematic change |
| instance parameter | `alter <flat> <param>=<v>` | no re-parse; same shard |
| model parameter | `altermod @<model>[<p>]=<v>` | same |
| temperature | re-render `.temp <v>` per shard; collapse to `dc temp a b s` when it is the only axis and the analysis is OP/DC | F10 |
| corner | **re-render the deck** with a different `.lib <file> <section>` row | ASE already emits `.lib` rows per `models` entry — a corner is a named set of model rows + variable overrides + a temperature. **No control-language corner machinery at all** |
| statistical | the GUI draws the samples in Tcl and writes them per shard | see below |

**Monte Carlo: the GUI is the random number generator.** Not `agauss` in the netlist and not
`sgauss` in the control language. Reasons, all measured by others: seeding has "two serious
traps" and three routes of which one silently does nothing (`orchestration.md` §6.3); a
model-level draw was *proven* to change between runs of the same migrated state
(issue 0210); and F16 records that transient white/1-f noise is **irreproducible under every seed
control** because the Wallace pool is seeded from `getpid()`. When the GUI draws, the sample set
is reproducible, inspectable, exportable, re-runnable point by point, and shows up as a column in
`index.tsv`. **ADE-L cannot show you its samples.** That is the claim, and it is defensible.

**What the GUI must show and ngspice cannot**: the family-of-curves display. A nested `.dc` comes
back flattened into one 1-D vector with no `Dimensions:` header (F10), so even the built-in nested
sweep needs the GUI to re-split it using the point count *the GUI itself computed*. The shard
runner never has this problem — every point is its own raw. That is a second reason to prefer it.
⚠ The Calculator's spec says v1 handles the *single-raw multi-dataset* family; a multi-raw family
is new work and belongs to that spec's owner (§15 M5).

### 10.2 Five picks from F14, and why these five

A design that lists all seventeen has chosen nothing.

**Pick 1 — `CKTncDump`'s starred nodes, highlighted on the canvas.** After a failed operating
point ngspice prints a `Last Node Voltages` table with a trailing ` *` on **every node that still
fails the convergence test** (`cktncdump.c:11-43`). `convergence.md` calls it "the single most
useful diagnostic in ngspice" and nobody has ever put a UI on it. ASE-L can parse it, map the
names back through `ase::netlist_map` (which already does hierarchy-qualified name resolution) and
**highlight those nets on the schematic**. ADE-L gives you an opaque `sim.log`. This is the
biggest single win available, it needs no ngspice change, and every piece of machinery it needs
already exists in this tree.

**Pick 2 — the convergence ladder as a live pane, and a remedy assistant.** §7.5. It pairs with
pick 1: pick 1 says *where*, pick 2 says *what to do*, and `optran` (F11) — on by default, never
seen by anyone, and silently deciding the accuracy of every fallback operating point — finally
becomes visible.

**Pick 3 — the `.sens` parameter picker, computed offline.** A three-device deck yields ~90
sensitivity vectors, which is unusable. `devhelp -csv -type -flags <device>` prints exactly the
four facts `cktsgen.c:193-216`'s eligibility rule needs, so the picker — a checkbox tree of
perturbable parameters — is computable **without running anything**, and `.sens`'s glob filters
(`sens v(out) r*:r m*:vth0`) turn the selection into one card. **ADE-L has no sensitivity analysis
at all.** This is the cheapest place to be plainly ahead.

**Pick 4 — `wrnodev`, i.e. save/restore of a DC solution.** `com_wr_ic.c:25-66` writes the current
node voltages as a ready-to-`.include` `.ic` file — "the closest thing ngspice has to Cadence's
save/restore DC solution". Two buttons on the OP form (*Save this solution* / *Start from a saved
solution*), one `.include` row. It is the ADE-parity item that ASE-L currently lacks entirely, and
it is also the fastest fix for a bench that takes four minutes to find its operating point.

**Pick 5 — transient noise (F16).** Two `IF_REALVEC` instance parameters on **both** vsrc and isrc
(the manual's "isrc not yet available" is wrong here, measured), documented nowhere in-tree, with
seven positional arguments whose calibration nobody knows, twelve traps including a **hang** on a
negative `TS`, and a `TS` that — not `tstep` — sets the transient timestep. Design it as
`trnoise.md` §10 specifies: a collapsible section on the **Tran** form, a small table of noisy
sources, two injection routes that need no schematic change (`alter` an existing DC-only source,
or a generated parallel current source), every field carrying its unit and a **derived readout**
("≈ 1.0 M timepoints, ≈ 24 MB"), all seven arguments always emitted positionally, and one
sentence that is worth more than the entire ngspice manual on the subject: *"White and 1/f noise
are not reproducible in this build — the generator is seeded from the process id."*
**ADE-L has no transient-noise feature at all.**

**Refused from F14, with reasons:** `iplot` and `stop`/`resume`/`step` (need interactive or `-p`,
refused in batch — they are the pipe transport's first customers, §8.6); `speedcheck`/`deltacheck`
(need `set ngdebug`, which floods the log with per-step traces); `diff` (real, but it belongs to a
regression feature that has no owner in this batch); `--soa-log` (needs the two-door `warn`
delivery from §7.3 — it ships *with* the options stage, not as a feature of its own);
`rusage devtimes` and `tranpoints accept rejected` (kept, but as one line in a run-health strip,
not a pane); the Calculator's `group_delay`/`cph`/`mtimeavg` vocabulary (the Calculator has its
own spec and its own owner).

---

## 11. Worked example — NOISE, end to end

The hard case, because it has a node-pair argument, a filtered source picker, a sweep-mode
selector, two plots, a scalar answer *and* a spectrum, an optional argument that changes what the
other plots contain, and a device-support caveat.

**11.1 The form.** The user picks `Noise` in the type grid. `chana_show` destroys `.form`,
rebuilds it from `fields`:

```
Enable  [x]
Output           [ v(out)        ] [Pick]      <- kind nodepair, select_on_design
Reference        [               ] [Pick]         (optional; blank means ground)
Input source     [ v1        ▾   ] [Pick]      <- combobox filtered to {V,I} sources
                                                  WITH an ac value — from netlist_facts
Sweep type       [ Decade    ▾   ]
Points per decade[ 10            ]             <- label minted by `relabels`
Start frequency  [ 1        ] Hz
Stop frequency   [ 1meg     ] Hz
   ▸ Advanced
     Points per summary [ 0 ]                  <- advanced 1
     ☐ Report as V²/Hz (sqrnoise)              <- a per-analysis OPTION, not a field
        41 points · integrated noise available
```

The last line is a **derived readout**: `dec` × 10 over 6 decades → 61 points… computed by the
same arithmetic `noisean.c:145-168` uses, and a note that a single-frequency run would produce no
`Integrated Noise` plot at all (measured). Nothing in ADE-L tells you that.

**11.2 The preconditions.** `needs {ac_source input_source_ac output_node_resolves}`.
`netlist_facts` reports `v1` has `acmag 1` → `ok`. If it did not, the banner would read *"`v1` has
no AC value — a noise analysis needs an AC input source (`ac 1` on the source, any magnitude)"*,
which is the exact remedy for `E_NOACINPUT`, offered before the run instead of after it.
`noise_devices` reports 11 of 14 device families contribute noise → `caution`: *"3 devices
contribute no noise: `e1`, `g2` (behavioural sources are noiseless), `t1` (transmission line)"*.
That sentence is `cider-devices.md` §2.6.2's silent-zeros trap, turned into a fact the user knows
before they misread a plot.

**11.3 The state.** One row, merged over the defaults, no schema change, no `version` bump, and
absent keys stay absent so the 105 committed files keep round-tripping:

```tcl
analyses {{type op enabled 1}
          {type dc enabled 0}
          {type ac enabled 0}
          {type tran enabled 1 step 10n stop 200u}
          {type noise enabled 1 id n_out output v(out) source v1
           sweep dec points 10 start 1 stop 1meg}}
```

**11.4 The deck.** `noise` is `multiplot 1`, so writer **mode B** (D16). `emitorder 40` puts it
before `op` (D15):

```
.control
set appendwrite
save v(out)
noise v(out) v1 dec 10 1 1meg
if $?sim_status = 0
  echo NO-SIM-STATUS
end
if $sim_status ne 0
  echo RUN-FAILED
  quit 1
end
save @m.xi1.m1[gm]                      ; optier_ctl, immediately before op
op
if $?sim_status = 0
  …the same guard…
end
foreach p $plots
  setplot $p
  echo "PLOTMAP $p |$curplotname|" >> /…/tb_ase.plotmap
  remzerovec
  write /…/tb_ase.raw all
end
print v(out)
.endc
```

Three things to notice. The `save v(out)` is validated against the netlist *before* it is emitted
(§3.5 `saves_resolve`) — that is the F7 mitigation applied to every run, not just to DISTO. The
device-parameter request rides the save side, not the write line, because mode B has no per-analysis
write (R6). And `op` is still last.

**11.5 What comes back.** The plotmap sidecar, exactly as **[B-M1]** measured:
```
PLOTMAP const  |constants|
PLOTMAP noise1 |Noise Spectral Density Curves|
PLOTMAP noise2 |Integrated Noise|
PLOTMAP op1    |Operating Point|
```
The GUI joins it against the registry's `plots` patterns:
* `noise1` → `role spectrum` → the **viewer**, trace group labelled *"Noise — spectral density"*,
  vectors `onoise_spectrum` and `inoise_spectrum`, y-unit V/√Hz (or V²/Hz if `sqrnoise` is on —
  and the GUI knows which, because it emitted the option);
* `noise2` → `role scalars` → the **Outputs Value column**: `onoise_total`, `inoise_total`, a
  one-point real plot, a legitimate scalar under decision B, labelled *"Noise — integrated"*;
* `op1` → the operating point, canvas annotation, unchanged.

Today, this same state renders a `.control` block **with no analysis in it at all**, exits 0,
writes an empty raw, and shows a ticked Enable box beside `output=v(out) source=v1 …` in the
Arguments column (F2, measured by `FINDINGS.md`). That is the distance this design closes.

**11.6 Back into the GUI.** Reopening Choose Analyses on that row rebuilds the form from the state
row through the registry — no round trip through ngspice, ever (F12: OP has zero parameters and
nothing about a DC or OP job can be read back). The GUI is the sole authoritative store; the
simulator is asked only what it *can* do, never what it *was told*.

---

## 12. S8 — sequencing

Each stage is shippable on its own and names what moves. Stage 0 and 1 carry no rulings, which is
this tree's own sequencing habit ("Stage 1 alone is one rebuild, zero rulings, zero suites moved").

| # | stage | ships | suites that move | ruling |
|---|---|---|---|---|
| **0** | **The silent drop dies** | a `default` arm in the emit `switch` raising a named error; the same check in `ase::preflight_gate`; `plot_sim_type` returns `{}` honestly instead of accidentally | RED test first: a `{type noise enabled 1}` state renders a deck and says nothing today | none |
| **1** | The registry, byte-identically | `ase::analysis_types` with exactly the four existing types; `emit` templates reproducing today's four lines; `anaargs`/`chana_fields`/the radio literal/`plot_sim_type` all read it; **the hardcoded destroy list dies**; `analysis_line` as the optional backend hook UX Stage F1 already specified | D1 golden + E12 prove byte-identity; G1/G2 keep driving `.chana.types.tran` by path | none |
| **2** | The type list is measured | the **[B-M1]** probe leg; `analyses_available` + `devices_available`; the four-state radio grid with reasons and a Detect button; the ungated-baseline fallback (D6) | `test_ase_simcaps_0948` gains rows; W1p unaffected | R5 (sentences) |
| **3** | **The form stops lying** | typed fields for the four existing types (`tran` `tstart`/`tmax`/`uic`, `ac` `lin|oct|dec` — killing the dead `dec` key —, `dc`'s second sweep, unit labels, the `relabels` mode selector); `dialog_status`; refuse-at-OK (D21); the `x` verbatim hatch; Apply | G2's display string; `test_ase_persist` `arg_summary` rows; deck goldens gain optional tokens | R2 (D4 reversal), R5 |
| **4** | Single-plot analyses | `tf`, `pz`, `sens` (DC); scalars read from one-point plots (§8.5); Poles & Zeros and Sensitivity tables as `listdlg` configs | new deck goldens; a `result_probe` row | **R4** |
| **5** | Multi-plot analyses | writer mode B; the plotmap sidecar; `noise` and `disto`; per-plot `remzerovec`; result labels from the registry | E5/M1 interplay — see R6 | **R6** |
| **6** | The netlist permits | `ase::netlist_facts`; the `needs` predicates; the `fatal` re-check in `render_deck`; the DISTO save-list rule; the device × analysis matrix | new suite; `ase::netlist_map_resolve` gains its second customer | R5 |
| **7** | The options surface | the ~250-row catalogue with `cptype`/`door`/`phase`/`inert`; `ase::opt_line` as the only speller; search + changed-only + groups; the pre-deck class; `<rundir>/.spiceinit`; the `-n` refusal | new suite; `run_cmd` goldens if `-D` is used | **R7**, R5 |
| **8** | SP | the gated type end to end; the port precondition (`fatal`); the S-parameter surface; `wrs2p` with the `.csparam Rbase=50` workaround | new goldens | R5 |
| **9** | Campaigns | the shard runner; `.param x='var(…)'` + per-shard `.spiceinit`; corners as re-rendered decks; GUI-drawn MC samples; `index.tsv`; abort = kill the current shard | new suite; the multi-raw family question goes to the Calculator's spec | R5, and the Calculator owner |
| **10** | Convergence | the ladder pane; `CKTncDump` → canvas highlight; the remedy assistant; the `optran` panel | new suite; the stderr-separation debt (M2) must close first | R5 |
| **11** | Transient noise | the Tran form's section; the injected-source emission slot; the rms `meas`; the honest seed sentence | new goldens | R5 |
| — | **deferred** | PSS, `libngspice`, CIDER, `sens2`/`hb`, the `-p` transport + the transient debugger | — | — |

Stage 0 is the one to ship this week. Stages 1–3 are the ones that repay themselves: after them,
adding an analysis type is **one registry entry**, and the window can no longer report a setting
that is not in force.

---

## 13. Rulings the user must give

House rule: **one at a time, discussed before the next is raised.** Ordered by what blocks
soonest. I give a recommendation with each; the reader should ask R1 first and stop.

**R1 — Does `ase::state_default` gain the new types?** *Recommendation: no.* Every one of the 105
committed states carries exactly four rows; seeding a fifth makes new views differ from every
existing bench, and Cadence does not add analyses to your bench either. New types arrive through
the dialog's Add path. But today this would happen **by accident**, and it must be a decision
(`ase-state.md` §6.4). Blocks stage 2.

**R2 — Reverse recorded decision D4 (a radio click discards what you typed)?**
*Recommendation: yes*, caching per-type edits in `dlg($key,anform,<type>)` for the dialog's
lifetime. D4's stated reason — "deterministic, no hidden multi-type writes" — is satisfied by
committing only the visible type at OK. Blocks stage 3.

**R3 — Do analyses gain row identity (`id`), i.e. two DC sweeps at once?**
*Recommendation: yes, but after stage 3.* It is the difference between a bench that can say
"sweep VIN, and also sweep temperature" and one that cannot. `chana_row`'s first-of-type
addressing and `test_ase_dialogs.tcl`'s assumptions both move.

**R4 — Do the Outputs Value numbers move from the log to the rawfile?**
*Recommendation: yes.* It is what gives NOISE, TF and SENS a scalar home at all, and it removes
the case-folding ladder. But it changes what the pane shows for existing benches, and issue 1243
was ruled by the user. Blocks stage 4.

**R5 — The standing label ratification.** Every new user-facing sentence in this design — the
four type states, every field label and unit, every precondition sentence, every refusal — is the
user's to ratify (`tests/headless/owed.sh add rule <id>`). Recommend batching them per stage.

**R6 — In writer mode B, may the device-OP request downgrade from the write-side tier to the
save-side tier?** Mode B has no per-analysis write to splice bare device names into, and rows
E5/M1 pin the write-side behaviour. *Recommendation: yes, with a measurement first* — the
downgrade target (`optier_ctl`, per-device `save` commands before `op`) is already the shape used
whenever more than one analysis is enabled, which is exactly when mode B applies. Blocks stage 5.

**R7 — May ASE-L write `<rundir>/.spiceinit`?** It is the only door to 26 options and to the whole
campaign mechanism (**[B-M6]**), and it **shadows the user's `$HOME/.spiceinit` for this run**.
*Recommendation: yes, with `source <user file>` included and a line in the run log saying so.*
Blocks stages 7 and 9.

---

## 14. What this design refuses, and why

**PSS.** It is not compiled here, and — more to the point — **nobody has ever run it, anywhere, in
this project**. Its two plot names, its convergence signal and whether `dcpss.c:988-996`'s
recursive re-entry terminates are all unverified (F1, [crit §5.7]). Shipping a PSS panel would be
shipping a form whose emit arm has never produced a correct result. It stays in the registry with
`registered 0` and the closing procedure written into the entry: build with `--enable-pss`, run
`examples/pss/ring_osc_pss_ctrl.cir`, record the two `Plotname:` literals, the numbering, and the
success signal.

**`libngspice`.** §8.6. The decisive fact is that this design's entire L2 layer exists because a
stale name in the Outputs pane can make ngspice **segfault** (F7, reconfirmed **[B-M7]**). Linking
that into the schematic editor trades the user's unsaved work for a progress bar. Add that no
shared build exists on this machine, and that surviving repeated `ngSpice_Reset` is a *named
recurring bug class* in the ngspice `CLAUDE.md`.

**Conditional logic in the generated deck.** **[B-M5]**: `.control`'s `if` on strings takes the
false branch for both `eq` and `ne`. Every choice is made at render time, in Tcl, where it is
testable. The only surviving in-deck conditional is the numeric `$sim_status` guard.

**A free-text option escape hatch on the analysis form.** That is precisely what lies today (F3).
It is replaced by typed fields, a typed option catalogue, and one explicitly-labelled verbatim
`.control` list that actually emits (D4/D21).

**`ttk::notebook`, a scrolling form, and a modal analysis dialog.** The notebook appears nowhere
in the xschem tree and the one place it was considered has a comment explaining why not; a
scrolling form has no idiom in `ase_window.tcl` and would need a `Canvas` theming arm; and a modal
dialog **would hang the headless suites** (`ase-ui.md` §3.2, §5.3). The form fits because
`advanced` fields fold and options move to the options surface.

**An error colour in the locked 9-colour palette.** A `⚠ ` glyph on the label plus the status line
does the job, is theme-proof, and needs no ruling.

**Hiding an analysis the probe could not measure.** §1.1. Hiding is how the current code lies.

**A corner/MC engine inside the control language.** §10.1's table: the interrupt semantics alone
disqualify it, and an interrupted run reports `sim_status = 0`.

**`.step`-shaped promises.** ngspice has none (F10). Everything sweep-shaped in this design is
plainly labelled as generated by the GUI, because when it breaks the user needs to know where to
look.

---

## 15. Risks and measurement debts

| # | risk / debt | how it closes |
|---|---|---|
| **M1** | `help <verb>`'s output could differ on a build with a relocated or stripped help database (**[B-M1]** is one build). | Belt-and-braces second signal, already available in the same probe run: a verb that answers `Sorry, no help` **and** whose family is absent from `devhelp` is absent. Publish `analyses_available` only when the file parsed cleanly. |
| **M2** | The convergence-ladder pane needs stdout and stderr as **two ordered streams**; ASE-L folds them with `2>@1` today, and two of the `ngdebug` lines carry **no trailing newline**. | Measure before stage 10: run a failing OP through the existing capture and see whether the interleaving is usable. If not, the pane reads the log file, not the live stream. |
| **M3** | The probe's three standing costs (0953/0958/0959) get worse the more the GUI asks of it. | D8: the dialog uses the free peek and a Detect button; the run-time probe stays inside the Run gesture where it already is. Do not add a startup probe. |
| **M4** | `<rundir>/.spiceinit` shadows `$HOME/.spiceinit` (**[B-M6]**). `source ~/.spiceinit` from inside ours is the intended mitigation and is **unmeasured**. | One deck, before stage 7. |
| **M5** | A multi-raw *family* (one raw per shard) is new to the waveform viewer and to the Calculator, whose spec says v1 handles the single-raw multi-dataset case. | Raise with that spec's owner at stage 9, not at stage 0. |
| **M6** | Mode B changes when results appear (all at the end, none on early failure). | Stated in §8.1; everything downstream is gated on `exitcode == 0` already, so the user-visible change is nil. Assert it. |
| **M7** | The static `netlist_facts` pass has a real blind spot: stimulus in an `.include`d file. | D11: static **warns**, exact **blocks**. The stand-down rule `ase::netlist_map_resolve` already implements is the precedent, and it is already ruled. |
| **M8** | `ase_window.tcl` is being edited concurrently by another batch. | Every anchor in this document is a proc or section name. Re-grep before quoting a line to anyone. |
| **M9** | F7's DISTO crash may or may not exist upstream in `pre-master-47`; `/usr/bin/ngspice` on this box was never run against it. | One command, before anyone files it upstream. It does not block any stage here — the GUI-side mitigation is required either way. |

---

## 16. Where the evidence lives

| claim class | owner |
|---|---|
| contradictions between dossiers, and four new ngspice defects | `../dossiers/00-critique.md` |
| per-analysis parameter tables | `an-core.md`, `an-smallsig.md`, `an-rf-pss.md` |
| the two option catalogues | `options.md` (OPTtbl + `set`), `hidden-vars.md` (163 `cp_getvar`, the CP-type table, the 26 pre-deck) |
| plot names, rawfile shape, the libngspice API | `outputs.md` |
| sweeps, corners, Monte Carlo, abort, progress | `orchestration.md` |
| transient noise and `trrandom` | `trnoise.md` |
| the device × analysis matrix and its predicate | `cider-devices.md` |
| `.meas`, `four`, `fft`, the expression vocabulary | `measure.md` |
| ASE-L's state schema and blast radius | `ase-state.md` |
| `render_deck`, the run pipeline, the capability probe | `ase-deck.md` |
| the window, the dialog, the ADE-L parity table | `ase-ui.md` |
| house rules, the spec of record, decisions A–N, the document shape | `ase-conventions.md` |
| **my own measurements [B-M1]…[B-M7]** | `./probe-B/` — `p1.cir` … `p7.cir`, `rundir/` |

**Where this document goes when it is adopted.** `ase-conventions.md` §10 is unambiguous: a batch
is a **directory**, not a file. This design becomes
`doc/claude/ase_analyses_batch/` — `README.md`, `PLAN.md` (§12's stages as items),
`CREW_BRIEF.md` (§0.1's measurements, so nobody re-derives them), `DECISIONS.md` (§2, with ⚖ on
§13's rulings), `LEDGER.md`, `APPENDIX_ngspice_analyses.md` (the dossiers' inventory), and
`receipts/`. And the spec of record must be **amended, not replaced**: `specs/ase_l.md`'s Choose
Analyses paragraph (six lines today), its render rule, its pane description, its menu entry, and
the stale paragraph that still claims running is top-only.
