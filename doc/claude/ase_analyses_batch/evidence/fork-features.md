# Dossier: the two fork features the user named — casemode, and the "blanket OP device info save"

**Reader:** the crew that designs the version-hooks layer, and whoever writes the release note
for a "basic ASE-L" that runs on an `apt`-installed or stock-built ngspice.

**Scope:** the user's question names two things our ngspice fork adds — *casemode support* and
*the blanket OP device info save* — and asks what ASE-L loses without each. This dossier
answers exactly that, end to end, by measurement. It does **not** re-derive the four-category
taxonomy (driver V3), the probe machinery (V4) or the adapter doctrine (V5); it tests them
against these two features and reports where the framing needs correcting.

**Anchors.** Bare `src/…` paths are `/home/analog/dev/ngspice/…`. `ase.tcl`, `op_annot.tcl`,
`xschem.tcl`, `rdw.tcl`, `save.c` are `/home/analog/dev/xschem-claude/src/…`. Procs and
functions are cited **by name**, never by line number — both trees move under this work.

**MEASURED** marks something run here on 2026-09-10. **SOURCE** marks something read here.
Nothing in either repository was modified outside this directory. Scratch decks and captured
output live in this session's scratchpad; every deck below is reproduced inline in full, so
nothing here depends on that scratchpad surviving.

**The three binaries.**

| tag | path | banner | notes |
|---|---|---|---|
| **apt** | `/usr/bin/ngspice` | `ngspice-45.2` | Debian `45.2+ds-1`, KLU |
| **fork** | `/home/analog/dev/ngspice/build-ver_50/src/ngspice` | `ngspice-46+` | `ngspice-46-419-gccebdf2a2`, KLU |
| **stock 47** | *not built* | — | `origin/pre-master-47`; read as SOURCE only. See §15. |

---

## 0. Executive summary — the headline is a correction

**The fork does not implement a blanket OP device-parameter save, and neither does anything
else.** MEASURED and SOURCE, three ways:

* `grep -rniE "saveopparam|saveoppoint|saveopinfo|oppoint|opparams|allop" src/` over the fork
  returns **nothing**.
* `git log --oneline origin/pre-master-47..ver_50` — all 207 fork-only commits — contains no
  such feature. The fork's entire diff to `src/frontend/breakp2.c` (the `save` grammar) is two
  `eq` → `eqc` substitutions, i.e. *case-insensitive matching of the words `all` and `nosub`*
  and nothing else.
* MEASURED: the wildcard request the ASE-L probe measures, `save @m.xo1.xi1.m1[*]`, produces
  **byte-identical failure** on apt 45.2 and on the fork — same two lines, same rc 0, no raw
  file at all. ASE-L's own probe comment already says so: *"NO RELEASED NGSPICE CAN, and this
  probe must keep answering that honestly rather than by assumption"*.

`doc/claude/ngspice_enhancement_request_op_parameter_saving.md` is dated 2026-08-29 and its own
status line reads **"draft — not yet sent"**. It is a *request*, not a shipped feature. What
ASE-L actually has is a four-shape **workaround** (`ase::op_save_tier`, tiers a/b/c/d) built
entirely on the xschem side.

**And the one tier that behaves like a blanket save — tier `d`, `set altshow` + `show all >` —
is an UPSTREAM capability, not a fork one.** It works on a build carrying upstream commit
`10276f993` (alto555, 2026-07-07, `git tag --contains` → nothing, i.e. **in no release**). That
commit is in `origin/pre-master-47` and therefore in **stock 47**. It is *not* in 45.2 and not
in 46. So on this axis the fork and stock 47 are the same, and only the older releases differ.

**Casemode is genuinely fork-only.** MEASURED, and `git grep casemode origin/pre-master-47 --
src/` returns **zero files**: stock 47 has no casemode either.

**The single most important measured fact for the hook design:** on the default path — case mode
`fold`, which is the shipped floor — the fork and apt 45.2 produce **byte-identical raw files**
for every deck shape ASE-L emits. The compatibility contract already holds. What follows is the
map of exactly where it stops holding and what it costs.

---

## 1. The measured capability dict, per binary

Every key below was produced by running ASE-L's **own** probe decks (`ase.tcl`,
`ase::backend::ngspice::capabilities`, decks A/B/C plus the casemode leg from
`::sim_probe_capability` in `xschem.tcl`) by hand, verbatim.

| key | apt 45.2 | fork 46+ | stock 47 (SOURCE) |
|---|---|---|---|
| `known` | 1 | 1 | 1 |
| `usable` | 1 | 1 | 1 |
| `appendwrite` | **1** | 1 | 1 |
| `hier_op_names` | **1** | 1 | 1 |
| `blanket_op_save` | **0** | **0** | **0** |
| `altshow_op_dump` | **0** | **1** | **1** (carries `10276f993`) |
| `casemode_detected` | **`{fold}`** | **`{fold preserve distinguish}`** | **`{fold}`** |

Consequence, through `ase::op_save_tier` unchanged:

| binary | guard that fires | tier | reason token | sentence the user is shown |
|---|---|---|---|---|
| apt 45.2 | G4 (`appendwrite 1` ∧ `hier_op_names 1`) | **c** | `unsafe` | *"…There is a much shorter way your simulator would accept, but it is all or nothing…"* |
| fork 46+ | G3a (`altshow_op_dump 1`) | **d** | `dump` | *"…can print out every device's operating-point numbers in one go…"* |
| stock 47 | G3a | **d** | `dump` | same as the fork |

The **only** difference the fork makes to this table is nothing at all: apt-vs-fork here is
apt-vs-**upstream-47**, and the fork sits on the 47 side of it purely because it was branched
after `10276f993`.

---

# PART 1 — the blanket OP device info save

## 2. What ASE-L asks ngspice for, in deck text

`ase::backend::ngspice::render_deck` consumes a block built at netlist time by
`op_annot::save_cards` and never rebuilt (invariant I1). Five arms, and the shape is chosen by
`ase::op_save_tier`, pinned once per run by `ase::op_tier_arm` / `ase::op_tier_now` (issue 1366).

**Tier a — blanket** (`blanket_op_save 1`; nothing on earth answers 1):
```
.save all                                   <- deck level
...
.control
save all @m.x1.m1[*] @m.x1.m2[*] ...        <- immediately before `op`
op
```

**Tier d — the dump** (`altshow_op_dump 1`):
```
.save all                                   <- deck level
...
.control
op
set altshow                                 <- AFTER op: `show` reads live CKT state
show all > <rundir>/<cell>.opinfo           <- path lowercased by op_annot::opdump_path
```

**Tier b — the write line** (never chosen automatically; guard G4 demotes it):
```
.control
op
write <raw> all @m.x1.m1 @m.x1.m2 ...       <- bare device names, OP write ONLY
```

**Tier c, >1 analysis** — the workhorse, and the one every stock user gets:
```
.save all                                   <- deck level, leader is load-bearing
...
.control
set appendwrite
tran ... / ac ... / dc ...
write <raw>
save all @m.x1.m1[id] @m.x1.m1[gm] ...      <- inside .control, `op` moved LAST (issue 0964)
op
write <raw>
```

**Tier c, 1 analysis** — the captured block verbatim, at deck level:
```
.save all
.save @m.x1.m1[id]
.save @m.x1.m1[gm]
...
```

Two spellings that are load-bearing everywhere and were re-confirmed here: the requests go
through **bare** (`@m…[id]`, never `i(@m…[id])` — the wrapper is the *read* shape,
`op_annot::vector`), and every device path is **lower case** (`op_annot::_lower`).

## 3. MEASURED — every shape, apt 45.2 against the fork

Reference circuit (ASE-L's own probe circuit — PDK-free, level-1 MOS two subcircuits deep):

```
.model nm1 nmos level=1 vto=0.7 kp=100u
.subckt inner d g s
m1 d g s s nm1 w=1u l=1u
.ends
.subckt outer d g s
xi1 d g s inner
.ends
vdd dd 0 1.8
vg gg 0 1.2
xo1 dd gg 0 outer
```

| shape | apt 45.2 | fork 46+ | verdict |
|---|---|---|---|
| **c**, 1 analysis (`.save all` + 6 `.save @m…[p]` cards) | 718 B raw, 10 vectors, 6 device params | 717 B raw, 10 vectors, 6 device params | **byte-identical apart from the `Command:` banner line** |
| **c**, multi-analysis (requests in `.control`, `op` last) | 2 plots; OP plot 7 vars, 3 device params; **transient plot carries 0 device vectors** | identical | identical apart from the banner and **one** transient timestep (`4.928e-09` vs `4.914e-09`, row 57) — an unrelated 45.2/46 timestep-control difference |
| **b** (bare device on the OP write line) | 4511 B, **75** device parameters | 4510 B, **75** | byte-identical apart from the banner |
| **a** (`save @m…[*]`) | `Warning from checkvalid: vector @m.xo1.xi1.m1[*] is not available or has zero length.` / `Error during 'write': no writable vector found.` / rc 0 / **no raw file** | **identical, verbatim** | the fork adds nothing here |
| **d** (`set altshow` ; `show all >`) | dump written, 3694 B | dump written, 2749 B | **differs — see §4** |

The 0964 scoping trick — asking inside `.control` and moving `op` last so the sticky
forward-only save list never reaches the transient — **works unchanged on apt 45.2**. Measured:
zero `@` vectors in the transient plot on both binaries.

Also MEASURED, because op_annot's own contract depends on it: `.save @M.XO1.XI1.M1[ID]` (upper
case) against a lower-case deck resolves identically on both binaries under `fold`, producing
`i(@m.xo1.xi1.m1[id])`. The two fork `.save`-case fixes (`08451f50a`, `3330047d4`) are scoped to
`preserve` and `distinguish` and change nothing under `fold`. **SOURCE:** their own commit
messages say so; `08451f50a` is about `.save v(midnode)` missing `MidNode` *under preserve*, and
`3330047d4` is a *warning* that fires only under `distinguish`.

## 4. Shape d — the one real difference, and it is upstream's

MEASURED, one PWL source added to the reference circuit, `op ; set altshow ; show all > f`:

```
apt 45.2                              fork 46+ (and stock 47)
vpw:                                  vpw:
    pulse   = 0                           pulse   =        -
    pulse   = 0                           sin     =        -
    pulse   = 1e-06                       exp     =        -
    pulse   = 1                           pwl     = 0
    ...                                   pwl     = 0
    sin     = 0     <- the PWL list       pwl     = 1e-06
    sin     = 0        replayed under     pwl     = 1
    sin     = 1e-06    EIGHT names        ...
    ...                                   sffm    =        -
    exp / pwl / sffm / am: same again     am      =        -
```

`ase::cap_altshow_verdict` asks **the defect, not the feature** — correctly, because
*"Does this ngspice have altshow?"* is answered YES by every release since ng-37 / ngspice-22
(upstream `0a8a56c65`, 2007-10-09), the distro package included. On apt 45.2 the verdict is
**0** (a non-`pwl` waveform keyword carries a number); on the fork it is **1**.

Two things worth recording that the shipped comment does not:

1. **On 45.2 the MOS block itself is perfectly intact.** MEASURED, same dump, same device:
   `id = 1.25e-05`, `vgs = 1.2`, `vds = 1.8`, `vdsat = 0.5`, `gm = 5e-05`, `gds = 0` — identical
   to the fork's. The corruption is confined to *source* devices' vector parameters. The probe's
   refusal is therefore **conservative, not necessary** for a design with no stimulus sources —
   which is the right call, because a reader cannot know in advance which devices a design has.
2. **The blow-up is bounded on ordinary decks.** MEASURED, 40 PWL sources × 6 coefficients:
   apt 0.10 s / 15.4 MB RSS / 150,127 B dump; fork 0.10 s / 15.4 MB RSS / 47,367 B dump. The
   *"ran essentially forever"* and *"tens of GB"* of `10276f993`'s message need a query that
   leaves `v.numValue` unset; a plain PWL is not it. So the honest release-note claim about
   45.2's `show` is **"3.2× larger and it invents numbers"**, not "it hangs".

## 5. What a stock user actually loses — concretely

**Nothing about correctness, and nothing about the Outputs pane.** The correction to the
question's framing, stated plainly:

* **The Outputs pane's Value column is not fed by device OP saves at all.** SOURCE
  (`evidence/ase-ui.md` §2.9, `ase.tcl` render_deck's print anchor): that column is filled from
  the `print` lines ASE-L emits into the run log, at the last-enabled-wins anchor
  `{dc ac tran op}`. **No column of the Outputs pane goes empty on stock ngspice.** The
  `save_options_cell` column shows `allv` / `alli` from the `Save All…` blankets, which map to
  `.save all` and `.options savecurrents` — both of which exist in every ngspice ever released.
* The device OP numbers feed **two other surfaces**: the schematic operating-point annotation
  (`op_annot`), and the Results Display Window (`rdw.tcl`, keys 1/2/3).

What is actually lost, in the concrete terms of the user's own `tb_bandgap` bench (numbers from
the shipped source comments, which measured them on that bench — not re-derived here):

| | tier d (fork / stock 47) | tier c (apt 45.2, and 46) |
|---|---|---|
| deck lines for device OP | **2** (`set altshow`, `show all >`) | **468** `.save @dev[param]` cards |
| devices covered | **212** | **78** — only those a PDK descriptor can name |
| parameters per MOSFET available to RDW key 3 | **88** | **6** (the descriptor's declared list) |
| devices with no PDK descriptor | covered — incl. **the two PNPs that ARE the bandgap reference**, 24 resistors, 38 capacitors, 12 B-sources | **not covered at all**; `.save @q` cards in that deck: **0** |
| agreement, where both cover a device | 468 of 468 pairs recovered, worst relative error 4.70e-06 (`show`'s `%.6g` print rounding) | reference |
| a PDK with no descriptor written yet | works | **annotation does not work at all** until somebody writes one |

So the loss on stock ngspice ≤ 46, said as a release note would say it:

> Operating-point annotation still works, and every number it shows is the same number. What you
> lose is **coverage and speed**: xschem must name every device itself, so only devices your PDK
> descriptor knows how to name get annotated — bipolars, resistors, capacitors and B-sources
> usually do not — and the deck grows one line per device per parameter instead of two lines
> total. On a 78-transistor bench that is 468 extra lines; on a 500-device block, ~3000.

And the second-order loss, which is the one that generates support traffic: a PDK that has no
`op_annot` descriptor **cannot be annotated at all** on 45.2/46, whereas on 47 the dump covers it
without one. SOURCE, `render_deck`'s tier-d arm: *"IT STILL RUNS THE HIERARCHY WALK IT DOES NOT
NEED. Reaching this arm requires a non-empty `$opblk`"* — so today even tier d is gated behind
a successful descriptor walk. **That gate is the thing to lift if "works on any PDK" is wanted**,
and it is orthogonal to which ngspice the user has.

## 6. Two tier-c hazards that a stock user meets and a fork user does not

Both are already handled; recorded so the hook design does not re-open them.

* **Guard G6 beats the override.** `ase::op_ctl_saves` splits at 999 names per `save` line,
  which is safe (MEASURED upstream in the tree: two `save` lines of 300 names leave 500 distinct
  vectors, byte for byte what one line of 600 gives). Tier **b** has no such split — two `write`
  lines under `set appendwrite` produce two plots both named `Operating Point` and
  `xschem raw read <file> op` picks one — so tier b is refused above 998 devices.
* **Guard G3b (`dumppath`, issue 1334) is a stock-vs-fork *non*-issue.** ngspice case-folds the
  whole `show >` target, directory component included, and exits 0 having written nothing. That
  is true on **both** binaries — it is not a version difference — but it only *bites* a build
  that would take tier d, i.e. the fork and 47. A 45.2 user never reaches the guard.

---

# PART 2 — casemode

## 7. What casemode is, and what the fork actually changed

`casemode` is a fork-only ngspice variable with three values, requested with
`-D casemode=<mode>` or `set casemode=`, and reported by `$curcasemode`:

* **`fold`** — every released ngspice's behaviour: identifiers are folded to lower case at read.
  The shipped default, and the one request no binary can silently fail.
* **`preserve`** — names are stored as the deck spells them; identity still folds, so `v(in)`
  and `v(In)` both resolve, and the raw file carries the real spelling.
* **`distinguish`** — names are stored verbatim **and** identity is case-sensitive; `EN` and `en`
  are two nodes.

SOURCE: `git grep casemode origin/pre-master-47 -- src/` → **no files**. Stock 47 has none of it.
Of the fork's 105 functional commits, roughly 80 are casemode work (`fix: fold the …`,
`fix: match … case insensitively`, `feat: add the casemode switch …`), plus
`9e341a8b7` / `731c01455` (the opt-in `Option: casemode=` raw header) and
`6780b6a40` (`curcasemode`).

## 8. MEASURED — the probe, both binaries, every leg

ASE-L's probe deck, verbatim (`sim_probe_deck`, `xschem.tcl`):

```
* xschem casemode capability probe
.control
echo CCM=$curcasemode
quit
.endc
.end
```

run as `ngspice -b -n [-D casemode=<mode>] <deck>`:

| request | apt 45.2 | fork 46+ |
|---|---|---|
| *(no `-D`)* | `CCM=` + `Error: curcasemode: no such variable.` | `CCM=fold` |
| `-D casemode=fold` | `CCM=` + same error | `CCM=fold` |
| `-D casemode=preserve` | `CCM=` + same error | `CCM=preserve` |
| `-D casemode=distinguish` | `CCM=` + same error | `CCM=distinguish` |
| `-D casemode=PRESERVE` (wrong-case **value**) | `CCM=` + same error | `CCM=preserve` — accepted |
| `-D CaseMode=preserve` (wrong-case **key**) | `CCM=` (no error line — a different, unset variable) | **`CCM=fold`** — silently ignored |

Every documented claim in `xschem.tcl`'s ruling block reproduces exactly. The wrong-case-key row
is the reason each mode is probed separately rather than inferred from `$curcasemode` existing.

**The answer to the driver's question — error, silent ignore, or silently wrong?**
apt 45.2 **silently ignores** `-D casemode=<anything>`: rc 0, no diagnostic about the flag, and
the run is byte-identical to a run without it. MEASURED on a mixed-case deck
(`V1 In 0 1 / R1 In Mid 1k / R2 Mid 0 1k / V2 EN 0 2 / R3 EN 0 10k`):

| | raw variable names | `print v(In)` | `print v(EN)` |
|---|---|---|---|
| apt, no flag | `v(in) v(en) v(mid) i(v1) i(v2)` | `v(in) = 1.0` | `v(en) = 2.0` |
| apt, `-D casemode=preserve` | **identical to the row above** | `v(in) = 1.0` | `v(en) = 2.0` |
| fork, no flag (`fold`) | `v(in) v(en) v(mid) i(v1) i(v2)` — **identical to apt** | `v(in) = 1.0` | `v(en) = 2.0` |
| fork, `-D casemode=preserve` | `v(In) v(EN) v(Mid) i(V1) i(V2)` | `v(In) = 1.0` | `v(EN) = 2.0` |

Two things to take from this table. First, **the fork under `fold` is byte-identical to stock** —
the compatibility contract holds at the file level, not just in spirit. Second, the ignore is
*benign in isolation*: what 45.2 does instead of `preserve` is exactly what it has always done.
It becomes "silently wrong" only if a **reader** has been told the run was `preserve` and then
looks up `v(In)`. §10 is why that does not happen.

## 9. Which ASE-L behaviours depend on casemode

Seven sites, SOURCE, all read here:

1. **`ase::run_casemode_flag`** — appends `-D casemode=<m>` to the run command, **only** when the
   requested mode is not `fold`. `fold` emits nothing, so an ordinary user's command line is
   byte-identical to what it has always been.
2. **`ase::preflight_scan`** — the Outputs pre-flight compares each output expression's
   identifiers against the netlist's names; `cs` is set case-sensitive **only** under
   `distinguish`.
3. **`ase::backend::ngspice::result_probe`** — matches `print` labels in the log
   case-sensitively under `distinguish`, and case-blind otherwise. It also **sniffs the log**:
   a `casemode=distinguish` banner or a `differs only in case` warning forces the strict path
   even for a `fold` request, because `~/.spiceinit` can override `-D casemode=`.
4. **`netlist_case_mode()`** (`save.c`) → `sim_netlist_casemode` — reaches only two consumers:
   `node_hash.c` (the netlister's case-collision warning) and `spice_netlist.c` /
   `spectre_netlist.c` (`keep_model_case`, live **only** under `distinguish`). Under `fold` and
   `preserve` the emitted netlist is unchanged.
5. **`Raw.case_sensitive`** — the *lookup* flag in xschem's raw reader, with its own verb
   (`xschem raw case`) whose set **re-reads the file**.
6. **`xschem raw casemode`** — the four-source mode resolution (explicit → `Option: casemode=`
   header → schematic-name comparison → the off-by-default capital sniff).
7. **The Simulators dialog's Case chooser** — built from `ase::casemode_selectable_in`.

**`render_deck` emits nothing casemode-conditional.** MEASURED by grep over its whole body: the
only `casemode` token in it is a comment. The deck text a stock user gets is the deck text a fork
user gets.

## 10. The fallback — does the existing machinery already degrade? Yes, and here is why

Rule **A1**, stated in `ase.tcl`: *"nobody may select a mode their simulator will silently
ignore. So the selectable set is exactly what was MEASURED, and an unmeasured program offers
`fold` alone."* The chain that enforces it, verified end to end against the apt binary:

```
apt answers `CCM=` + "Error: curcasemode: no such variable."
  -> sim_probe_capability: status `nocasemode`, detected {fold}, complete 1
  -> capabilities: casemode_detected {fold}
  -> ase::casemode_selectable_in -> {fold}          the chooser offers fold ONLY
  -> ase::sim_casemode_requested -> entry field, else ase::sim_casemode_floor
  -> ase::run_casemode_flag: m eq fold -> {}        NO -D flag on the command line
```

`nocasemode` recording `detected {fold}` rather than `{}` is deliberate and is the clause that
makes the ordinary `apt install` binary work: `{}` would mean *"measured, and it delivers
nothing we recognise"*, and the chooser would then offer **no** mode at all.

**The one way a `fold`-less request can still reach a stock binary** is the global floor: a user
who has `set sim_case_mode preserve` in an rc (or carried a registry entry over from a fork
machine) makes a request with no chooser involved. That path is covered too, and the coverage was
verified against a real measurement of the apt binary:

* **requested `preserve`, stock binary** — the run probe (`ase::sim_probe_run`) reads
  `nocasemode` as *a measured delivery of `fold`* (`delivers fold`), so
  `ase::run_casemode_verdict` returns **`action report`**: the run proceeds and the log carries
  *"the simulator was measured to deliver 'fold'"*. Cosmetic — same circuit, same numbers,
  lower-case labels.
* **requested `distinguish`, stock binary** — same measurement, `delivers fold` ≠ `distinguish`,
  and `distinguish` is the arm that **refuses**. `ase::run_precheck` raises *before its first
  `open`*: no deck, no raw, no log, no VCD deleted, no `.so` rebuilt, no process started, no
  `last_run` update. The advice clause even distinguishes the floor case (*"No simulator is
  registered — the request came from the global floor `sim_case_mode`"*) from the registry case.
  This is right: a `distinguish` downgrade **merges nets the user deliberately kept separate** —
  the same deck file, a different circuit — and on a stock binary the merge is completely silent,
  because the fork's fold-collision warning does not exist there.

**Verdict: the existing machinery degrades correctly. It does not assume the fork anywhere.**
Three caveats, all pre-existing and all stated in the source:

* **A `fold` request is not probed at all**, deliberately (arming is gated on the mode not being
  `fold`), so a `.spiceinit` that turns a `fold` request into `preserve` or `distinguish` is not
  detected before the run. `result_probe`'s log sniff is the compensating measure, and it is
  over-approximate in the safe direction (a false positive costs an empty Value cell).
* **The floor never leaks into the reader.** `xschem raw casemode` returns `unknown` when all
  four sources are silent; `sim_case_mode` is *"a request about a run we are about to make, never
  a claim about a file somebody else wrote"*. So a `preserve` floor against a stock binary does
  **not** make the reader look up `v(In)` in a file full of `v(in)`.
* **The probe costs a launch.** `ase::sim_capabilities` starts the user's simulator (deck A, deck
  B, deck C, then three casemode legs) out of one 30 s budget on a cache miss. Known costs are
  issues 0953 / 0958 / 0959. A stock user pays exactly what a fork user pays.

## 11. The one genuine cross-version hazard: the `Option: casemode=` raw header

`9e341a8b7` adds `Option: casemode=<mode>` to the raw header, **off by default** behind the
`casemodewrite` variable. Its commit message states the reason: the line *"puts a casemode key
into that session's variable space, and an ngspice-46 that then unsets it dies — that is
`doc/codex/issues/0067`, fixed in the commit before this one and in nothing released. Our files
must not become somebody else's crash."*

MEASURED here, on a raw the fork wrote with `set casemodewrite`:

```
Plotname: Operating Point
Option: casemode=fold          <- present only with casemodewrite set
Flags: real
```

* apt 45.2 **loads it fine** — `load hdr.raw ; print v(in)` → `v(in) = 1.000000e+00`, rc 0.
* apt 45.2, `load hdr.raw ; unset casemode` → rc 0, but prints
  `Error: casemode is read-only.` and `cp_remvar: Internal Error: var 99`.
* the fork, same sequence → rc 0, silent.

The *aborting* arm of 0067 is the sibling one, and it is not raw-file-specific. MEASURED on a
two-resistor divider:

```
printf 'source deck.cir\nset temp=27\nunset temp\nquit 0\n' | ngspice -p -n
  apt  45.2  ->  rc=134   (SIGABRT, core dumped)
  fork 46+   ->  rc=0
```

SOURCE: `origin/pre-master-47:src/frontend/variable.c` still carries the unconditional
`free_struct_variable(v)` at the end of `cp_remvar()`, so **stock 47 aborts here too**. This is a
driver-category-(b) item — a bug the fork fixed that is live upstream — and it belongs to task C;
it is recorded here because 0067 is the stated reason the header is opt-in.

**Whether this hazard is even reachable from ASE-L, today:** it is not. MEASURED by grep —
`casemodewrite` appears **nowhere** in `ase.tcl` or `ase_window.tcl`. `ase::run_casemode_flag`
returns `[list -D casemode=$m]` and nothing else. Only the **legacy** run path
(`sim_run_flags` in `xschem.tcl`, used by `proc simulate` / the Simulation menu) rides
`-D casemodewrite` along with a non-`fold` mode.

⚠ **This contradicts the shipped spec.** `doc/claude/specs/raw_case_mode.md` §10's issue-0506
correction asserts *"Both run paths now emit `-D casemodewrite` alongside any non-`fold`
`-D casemode=`"*. That was true on `fluid-editing`; it is not true of ASE-L's own `run_cmd` on
this branch. The practical consequence is that **an ASE-L run never produces a self-describing
raw**, so `xschem raw casemode` answers `unknown`/`none` (or `fold`/`schematic`) for every file
ASE-L causes to be written, even on the fork. That is a small, safe gap — but it is a gap
between a spec and the code, and the hooks crew will read that spec.

## 12. What "basic ASE-L" can and cannot do — casemode

**Can:**
* Run every deck ASE-L emits, unchanged, with byte-identical results to the fork under `fold`.
* See the Case chooser correctly offering `fold` and nothing else, with a status line that says
  why rather than telling the user to press Detect again (issue 1371's fix).
* Get a clear pre-run refusal, before anything is written, if a `distinguish` request would have
  silently merged nets.

**Cannot:**
* Keep the case of net, node, instance or model names in the raw file, in the waveform browser,
  or in `print` output. Everything arrives lower case, as it always has.
* Distinguish `EN` from `en` as two nets. There is no way to do this on a stock binary and no
  way to fake it.
* Read a self-describing raw. `xschem raw casemode` will answer `unknown`/`none` for anything a
  stock ngspice wrote — permanently, since the upstream patch that would default `casemodewrite`
  on has not been sent.
* Get the fork's fold-collision warning, the near-miss `.save` warning, or the subcircuit-pin and
  event-node case-miss reports. On a stock binary a case near-miss is **silent**, which is
  precisely the class of defect the fork's warnings exist to delete.

---

## 13. Consequences for the hook design

### 13.1 Driver principle V6 — "gate capabilities up, apply mitigations down" — holds for both features, with one refinement

**Capabilities gate up, and the tree already does it correctly.** Both `blanket_op_save` and
`casemode_detected` are proven-before-offered, both treat a missing key as *"not measured"*
rather than *"no"*, and both fall to the shape that always works. Nothing needs changing.

**Mitigations apply down — but neither of these two features has one.** Neither casemode nor the
OP save has an *unconditional* mitigation to apply, because neither has an unprobeable hazard:

* the OP shapes are all probeable (`altshow_op_dump` is measured on a real dump; `blanket_op_save`
  on a real raw);
* casemode's hazard is *silence on a request*, which a request-versus-answer comparison catches
  exactly.

**The refinement the design should absorb:** there is a third posture beside "gate up" and
"mitigate down", and both of these features already use it — **probe the defect, not the
feature**. `ase::cap_altshow_verdict`'s comment states the whole doctrine: *"Does this ngspice
have altshow?" is answered YES by every release since ng-37, the distro package included, so it
separates nothing.* The question that decides usability is whether a specific fix is present, and
**no version string can answer it** — `10276f993` is in no release at all, so 45.2 says no,
46 says no, 47 will say yes, a master build says yes. A crew tempted to key this on a version
number would get it wrong in both directions.

The same shape appears on the casemode side: *"the variable exists, therefore all three modes
work"* is an inference, and a measured-false one (the wrong-case-key row of §8).

### 13.2 A version-keyed table is needed for exactly one thing here, and it is not either feature

The only version-keyed fact this pass produced is the **cp_remvar abort** (§11) — a crash, and
therefore driver-category (d), unprobeable by construction. Its key is not a version number
either: it is *"does this build carry `ac1819ff8`"*, which is true of the fork and false of 45.2,
46 and 47 alike. A table keyed on `<version> → hazards` would record it as "every ngspice except
ours", which is correct and is worth writing down exactly that way.

### 13.3 What a "basic ASE-L" needs to *do* differently — nothing, and that is the finding

Neither feature needs a new mechanism, a stock/enhanced split, or a second code path. The
existing probe already produces the right answer on the apt binary, and the existing tier and
casemode machinery already consume it correctly. What "basic ASE-L" needs is:

1. **A release note that says what is degraded**, in §5's and §12's terms — because today a
   45.2 user is told *"There is a much shorter way your simulator would accept, but it is all or
   nothing"* (the `unsafe` sentence), which is **true but is the wrong explanation**: the reason
   they are on tier c is `altshow_op_dump 0`, i.e. their `show` printer is broken, and the
   sentence never mentions it. **This is a real defect in the mint**, and it is the one concrete
   change Part 1 produces: `ase::op_save_tier`'s G4 `unsafe` arm is reached *after* the
   `altshow_op_dump` guard has already said no, so on 45.2 the user is given a sentence about a
   risk (tier b's all-or-nothing write) instead of the fact (their build's `show` is unsound and
   47 fixes it). A fifth reason token — `dumpunsound` — would let the sentence say
   *"upgrading to ngspice 47 will make this much faster"*, which is actionable, where `unsafe`
   is not.
2. **The `casemodewrite` spec/code divergence closed** (§11), in one direction or the other.
3. **The descriptor gate on tier d lifted** if "annotation works on any PDK" is a goal (§5) —
   but that is a fork-independent change and belongs to its own item.

---

## 14. Quick reference — the claims a release note may make

| claim | evidence |
|---|---|
| ASE-L runs correctly on `apt`-installed ngspice 45.2 with no configuration | MEASURED, §3 §8 |
| Operating-point annotation works on stock ngspice and shows identical numbers | MEASURED, §3 (shape c byte-identical); §5 (4.70e-06 worst error is tier-d rounding, the other direction) |
| On stock ngspice ≤ 46, annotation covers only devices your PDK descriptor names | SOURCE, §5 |
| ngspice **47** gets the fast path back — it is upstream, not ours | SOURCE `10276f993` ∈ `origin/pre-master-47`, §0 §4 |
| Case-mode features require our build; there is no fallback and no emulation | MEASURED §8, SOURCE `git grep casemode origin/pre-master-47` → none |
| Asking for `distinguish` on a build that lacks it is refused before anything is written | SOURCE `ase::run_casemode_verdict` / `ase::run_precheck`, driven by the MEASURED `nocasemode` → `delivers fold` |
| Asking for `preserve` on a build that lacks it runs and reports; nothing is wrong with the numbers | same, `action report`; MEASURED §8 (identical raw) |
| A raw file our build writes is readable by every ngspice | MEASURED §11 (loads on 45.2; header absent unless `casemodewrite`) |
| `set X=v ; unset X` aborts on 45.2, 46 and 47; our build fixed it | MEASURED (rc 134 vs rc 0); SOURCE for 47 |

---

## 15. Gaps — what this pass could not settle

1. **Stock 47 was not built.** Driver task A owns that build and it did not exist when this pass
   ran, so every stock-47 row above is SOURCE (source diff + `git tag --contains` +
   `git grep`), not MEASURED. The two claims that matter and that a 47 build should confirm:
   (a) `altshow_op_dump` probes **1** on 47, putting it on tier d with the fork;
   (b) `casemode_detected` probes **`{fold}`** on 47, i.e. identical to 45.2.
   Both follow from a source diff that is unambiguous, but neither has been watched happen.
2. **The tier-d agreement numbers are the tree's, not this pass's.** The 468-of-468 / 4.70e-06 /
   212-vs-78 figures come from `render_deck`'s and `op_annot.tcl`'s own comments, measured on the
   user's `tb_bandgap`. This pass verified the *mechanism* on a 5-device deck and did not re-run
   the bandgap.
3. **The catastrophic `show` case was not reproduced.** §4 measured a 3.2× dump and fabricated
   numbers; it did not reproduce `10276f993`'s runaway loop or its O(n²) leak, which need a
   device query that leaves `v.numValue` unset. A release note should not claim 45.2 "hangs".
4. **Whether the `unsafe`/`dumpunsound` mint change in §13.3 is wanted is a ruling, not a
   finding.** It is one sentence in `ase::sim_why` plus one reason token in `ase::op_save_tier`,
   and it changes what a 45.2 user is told about why their deck is 468 lines long.
5. **Not investigated here, by scope:** the other 100-odd fork bug fixes (driver task C), and
   whether ASE-L silently depends on any of them. §11's `cp_remvar` abort is one hit found in
   passing and is handed to that task, not closed here.
