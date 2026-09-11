# ASE-L Analyses — DESIGN OF RECORD

**Scope: ANALYSIS only. Nothing here is done. This is the plan the next session implements from.**

| | |
|---|---|
| ngspice tree | `/home/analog/dev/ngspice`, `ver_50`, `ngspice-46-419-gccebdf2a2` |
| binary for every measurement | `/home/analog/dev/ngspice/build-ver_50/src/ngspice` |
| xschem tree | `/home/analog/dev/xschem-claude`, `fluid-editing` — **dirty and moving**. Every anchor below is a **proc name**; line numbers are hints, re-derive before quoting |
| evidence base | `../dossiers/` (20 files), `00-critique.md` first, `builds.md` last and decisive |
| designs merged | `design-A.md` (spine of the writer + the twelve-row table), `design-B.md` (spine of the architecture), `design-C.md` (spine of the campaign generator + the sidecar) |
| my scratch decks | `../dor/` (durable) |
| written | 2026-09-09 |

Nothing in either repository was modified.

**Citation convention.** `F<n>` = a fact from the brief. `[crit §x]`, `[builds §x]`, `[ase-ui §x]` =
the dossier that owns the evidence. `[A-Pn]`/`[B-Dn]`/`[C-Cn]` = a decision inherited from that
design. **`[R-M<n>]` = measured by me, this pass**, deck in `../dor/`. `CODE-HERE` = read by me in
the tree named.

---

## 0. Thesis

Three things are true at once and the design has to hold all three.

1. **A hardcoded analysis list is the original sin.** [B] is right. Four literal lists
   (`state_default`'s seed, `anaargs`, the radio `foreach`, `anorder` + the switch) plus three more
   (`chana_fields`, `chana_show`'s destroy list, `plot_sim_type`) are seven copies of the answer to
   "what is a dc analysis", each of which fails **silently** when it drifts — and one already has
   (`ac`'s `dec` key is advertised in `anaargs`, omitted from `chana_fields`, and hardwired in
   `render_deck`). Collapse them into one declarative registry and every new capability becomes a
   column, not a seventh list.

2. **A GUI that shows a setting it cannot emit is not a feature gap, it is a correctness defect.**
   `ase::ui::chana_options` collects name/value pairs, round-trips them, renders them in the
   Arguments column, and never emits them (F3). The acceptance criterion for this whole batch is
   one sentence: *nothing the window shows may fail to reach the deck, and nothing the deck
   contains may be unshowable in the window.*

3. **The GUI is the only validator in the system.** ngspice accepts unknown option names in
   silence, drops out-of-range values in silence, turns a `CP_BOOL` written `=1` OFF in silence
   (F15), returns one point for `ac lin 2` in silence (**[R-M18]**), and **segfaults** on a
   distortion analysis whose save list does not resolve (**[R-M13]**). A design that does not model
   option *types*, delivery *doors*, and netlist *admissibility* cannot be honest no matter how
   good its layout is.

And one fact that the three designs argued about and the build probes settled: **`-b` is not
progress-blind and `-p` is a five-millisecond graceful abort against the binary the user already
has** [builds §3.2, §4.3, **[R-M8]**]. That reframes the transport question from "do we need
libngspice" to "when do we take `-p`", and it is R1.

---

## 0.1 What I measured myself, this pass

Nineteen. Seven are new; the rest reconfirm something a design or a judge asserted that I refused to
build on second-hand. Decks in `../dor/`.

**[R-M1] THE WRITER.** `setplot previous` + a per-write plotmap sidecar captures every plot of a
multi-plot analysis, leaves the **first plot in the file genuine data**, and does not touch the
`op` write line. Deck `pm.cir`:

```
noise v(mid) v1 dec 2 1k 10k
remzerovec / echo "PLOT noise n1 |$curplotname|" >> pm.map / write pm.raw
setplot previous
remzerovec / echo "PLOT noise n1 |$curplotname|" >> pm.map / write pm.raw
op
remzerovec / echo "PLOT op o1 |$curplotname|" >> pm.map / write pm.raw
```
→ `pm.map`:
```
PLOT noise n1 |Integrated Noise|
PLOT noise n1 |Noise Spectral Density Curves|
PLOT op o1 |Operating Point|
```
→ `pm.raw` `Plotname:` records, in the same order, 1:1: `Integrated Noise`,
`Noise Spectral Density Curves`, `Operating Point`. rc 0. **This is the design's writer.**

**[R-M2] AND THIS IS WHY IT IS NOT F6's LOOP.** `foreach p $plots / setplot $p / write raw all`
writes `constants` **first**: `Title: Constant values`, `Plotname: constants`, `No. Variables: 12`,
`No. Points: 1`, `Date` identical to the build stamp — all four markers `ase::raw_content_verdict`
(CODE-HERE, `src/ase.tcl`) treats as decisive. It returns `ok 0` and `ase::attach_dbs` answers
`NOT ATTACHED … the analysis did not run`. The same proc explicitly **tolerates** a `constants`
plot *appended behind* real data. `destroy const` before the loop is refused outright —
`Error: can't destroy the constant plot` — and `$plots` still reads `const op1 noise1 noise2`.
There is no in-deck filter either (B-M5: `.control` `if` on strings takes the false branch both
ways). **Design B's writer mode B produces a rawfile ASE-L itself rejects. Repaired here.**

**[R-M3] The walk's failure mode is benign; the loop's was not.** Over-walking `setplot previous`
by one re-writes the previous analysis's plot, by two writes `constants` — silently. But plot 1 in
the file is still genuine data, so the file still attaches. **An over-count degrades the result set;
it never destroys it.** (Deck `ov.cir`.) The mitigation is §9.3's post-run reconciliation, and it
is cheap because the sidecar already says what was captured.

**[R-M4] Decision F is load-bearing and no capture change may move it.** With `.save all` in the
deck: `write raw all @m1[gm] @m1[id] @m1[vdsat]` produces a 7-variable OP plot **carrying those
three device vectors**; `setplot op1` + `write raw all` produces **zero**. The device-parameter
names on the write line are the *generator* of those vectors, not a filter over vectors that exist.
(Deck `ot2.cir`.) The `setplot previous` walk keeps the `op` write exactly as it is today, so
**[B-R6] dissolves — there is no ruling to ask.**

**[R-M5] SP PORTS NEED NO SCHEMATIC CHANGE.** On two *ordinary* V sources that declare no port in
the netlist:
```
alter v1 portnum = 1 / alter v1 z0 = 50 / alter v2 portnum = 2 / alter v2 z0 = 50
sp lin 3 100meg 1g
```
→ rc 0, `$curplotname` = `SP Analysis`, `s_1_1[1] = 1.674674e-05,-2.89363e-03`. (Deck `m7.cir`.)
Design B makes `two_ports` a `fatal` precondition with no route to satisfy it; that is a refusal
where two emitted lines are an enablement. **Repaired: §6.6's Ports table.**

**[R-M6] XSPICE EVENT RESULTS ARE REACHABLE, THROUGH THE DOOR ASE-L ALREADY OWNS.** Deck `mx.cir`,
an adc_bridge → d_inverter → dac_bridge chain:
* `edisplay` prints a machine-readable inventory — `din : d , 7` / `dout : d , 7` — of the event
  nodes in the current plot, with no netlist parsing;
* `eprvcd din dout > mx.vcd` writes a **valid VCD** (`$timescale 1 ps`, `$var wire 1 ! din`, value
  changes);
* `write mx.raw all` contains `time i(adac) v(aout) v(in) i(vin)` and **not** `din`/`dout` —
  silently, confirming `xspice.md` §7.6.

ASE-L already has a complete VCD pipeline (`ase::cosim_map`, `ase::last_vcdfiles`,
`ase::attach_dbs {rawfile sim_type {vcdfiles {}}}` — CODE-HERE). **The digital half of a
mixed-signal run is one `eprvcd` line away from the viewer.** No design proposed this.

**[R-M7] `.spiceinit` CHAINING: COPY, NEVER `source`.** With a user file holding
`set frobnicate` / `set myother = 77` and ours holding `set myres = 4700`:
* **copied in** → `@r1[resistance] = 4700`, `FROB SET`, `MYOTHER = 77`. Everything survives.
* **`source <userfile>`** → ngspice parses the target as a **netlist** (`Circuit: set frobnicate`,
  `Error on line 2 … Unable to find definition of model`), and the user's variables are **lost**.

Design B's D19/M4 mitigation is wrong as written. **Repaired: ASE-L reads the user's file and
copies its lines under a banner.** (Decks `si3/`.)

**[R-M8] `-b` IS NOT PROGRESS-BLIND.** `tran 10n 20m` under plain `-b` printed **8**
` Reference value :  1.80112e-02` records on stdout, `\r`-terminated, no newline. The GUI wrote
`tstop`, so `refvalue/tstop` is a percentage it can compute for tran, dc, ac, noise, disto and sp
alike [builds §3.2]. Design B's transport table says "progress: none" for `-b` and `-p`. **Wrong.**
(Deck `tick.cir`.)

**[R-M9] THE POST-RUN VERIFICATION CHANNEL, which no design used.** After
`option reltol=0.05 itl4=7 method=gear`, a bare `option` printed
`reltol (current) = 0.05`, `itl4 (transient iterations) = 7`, `Integration Method = GEAR`,
plus temp/tnom/maxorder/solver/pivtol/gmin/gminsteps/srcsteps/trtol/delmin. A bare `set` listed
every variable in force — **including `bogusopt 3`, silently created by `option bogusopt=3`**, and a
bare `set frobnicate`. Neither reveals a `CP_` class, so the type table still ships — but together
they are a *requested-vs-effective diff* that catches F15's silent drops and proves a pre-deck
delivery landed. (Decks `m6.cir`, `m7.cir`.)

**[R-M10] PHASE IS IN RADIANS BY DEFAULT.** `vp(mid)` on an AC run = `-4.96729e-04`; after
`set units=degrees`, `-2.84605e-02` — a factor of 57.2958. `units` is a `CP_STRING` variable
(CODE-HERE `src/frontend/miscvars.c:124`, read at `src/frontend/options.c:419`). **Every design
routes a phase margin to the Value column and none of them says this.** A generated PM is wrong by
a factor of 57 under a correct heading.

**[R-M11] TWO ANALYSES, ONE PLOTNAME.** `sens v(mid) dc` and `sens v(mid) ac dec 2 1k 10k` in one
deck both report `$curplotname` = `Sensitivity Analysis`; `$plots` = `const sens1 sens2 dc2`.
**Matching results on the `Plotname:` literal alone cannot separate them**, and it cannot separate
two rows of the same type either. The sidecar's *creation order* can, and does. (Deck `m6.cir`.)

**[R-M12] `dc <src> a b s temp x y z` RUNS NATIVELY.** `dc v1 0 1 0.5 temp -40 60 50` → 9 rows, one
flattened `v-sweep` scale, no `Dimensions:` header. So "DC sweep at N temperatures" is **one
command** whenever the temperatures are uniformly stepped, and only a campaign when they are not.
(Deck `m6.cir`.)

**[R-M13] THE DISTO REFUSAL, NARROWED.** Four decks:

| deck | rc |
|---|---|
| `.control`: `save v(nosuchnode)` + `disto` (ASE-L's exact shape) | **139** |
| the same with a `.save all` card above `.control` | 0 |
| `.control`: `disto` + `op`, **no save at all** (the naive two-checkbox deck) | **0** |
| dot cards `.op` + `.disto` + `.control run` | **139** |

So the trigger is **"a save list that resolves to nothing"**, not "a narrowed save" and not "no
save". Design C's R2 (refuse `disto` + zero saved outputs) **would refuse a deck that works**.
(Decks `d1..d4.cir`.)

**[R-M14]** `sens … ac` under `.options klu` → **rc 139**; `sens … dc` under klu → rc 0. (`k1.cir`.)

**[R-M15]** `option keepopinfo` then `ac` → `$plots` gains `op1 ac1`; `option keepopinfo=0` then
`ac` → gains only `ac2`. **The flag really is restorable**, so §7.5's set-before / restore-after
fiction works for the flag class. (`ko.cir`.)

**[R-M16] THE CAPABILITY PROBE.** One `-b` deck: `op`, then
`foreach v <verbs> / echo "== $v" >> cap.txt / help $v >> cap.txt / end`, then `devhelp >> fam.txt`.
rc 0. All ten present verbs answered; `pss` and `hb` returned `Sorry, no help for …`; `optran`,
`meas`, `fourier`, `linearize` answered. The upstream copy-paste bug is confirmed —
`help tf` prints `tf [.tran line args] : Do a transient analysis.` — and the **first-token** parse
rule survives it. (`p1.cir`.)

**[R-M17]** A `.spiceinit` beside the deck is read **from a foreign cwd** (`var(myres)` → 4700 with
cwd `/tmp`); `-n` silently drops it (`1e-12`, and the only message is a *resistor* warning, not a
word about the ignored file); `-D casemode=preserve` **composes** with it. (`si/`.)

**[R-M18]** `ac lin 2 1k 11k` → `length(frequency) = 1`; `lin 3` → 3. (`l2.cir`.)

**[R-M19] A generated deck cannot build a plot list as a string.** `set wl = "$wl $p.all"` inside a
`foreach p $plots` produced `Error: p.all: no such variable` four times and then
`Error during 'write': no writable vector found` — the `.` is swallowed by `$` substitution
(`orchestration.md` §1.4's rule, measured here on the exact shape a capture loop would want). So the
one remaining escape from **[R-M2]** — naming the plots explicitly on a single `write` line, which
*does* work when the names are literal (`write f op1.all noise1.all noise2.all` → three plots, no
`constants`) — **cannot be generated from inside the deck**, and the GUI cannot know the counter-
based typenames at render time. The `setplot previous` walk is the only shape left. (`m4.cir`, `m3.cir`.)

---

## 0.2 Coverage map — the eight areas

| | area | answered in | one line |
|---|---|---|---|
| **S1** | the type list | §1, §4 | registry ∩ measured capability ∩ netlist admissibility, in four visible states, **never invisible** |
| **S2** | per-type metadata | §3.1, §5 | one `ase::analysis_types` entry per type; all twelve tabulated, five written out in full |
| **S3** | the form | §6 | typed fields with units, a mode selector that relabels its neighbour, schematic pickers, refusals on the form, a Ports table for SP |
| **S4** | the options surface | §7 | one ~250-row catalogue with `cptype` + `door` + `phase` + `inert`; one speller; search-first, difference-first; a live deck preview; convergence as remedies with `optran` visible |
| **S5** | the deck | §8 | `.control` commands one at a time, no in-deck branching, the `setplot previous` writer, twelve refusals, `<rundir>/.spiceinit` for pre-deck options |
| **S6** | results | §9 | a destination per plot, joined through a creation-ordered sidecar; scalars from one-point plots; **a real measurement surface**; event data via `eprvcd` |
| **S7** | beyond ADE | §10 | the shard-runner campaign, six picks from F14, transient noise **and** `trrandom` |
| **S8** | sequencing | §13 | thirteen stages; the first two carry zero rulings |

---

## 1. The four gates

Every analysis type, every field, every option passes the same four gates. This is the architecture.

| gate | question | source of truth | cost | what it removes |
|---|---|---|---|---|
| **L0 vocabulary** | can ASE-L render this at all? | `ase::analysis_types`, declarative, Tk-free `ase.tcl` | free | F2's silent drop — a type outside the registry is **refused at render, loudly** |
| **L1 capability** | does the attached binary have it? | `ase::sim_capabilities` + one new probe leg **[R-M16]** | one probe run per binary, cached on path+mtime+size | `pss: no such command` in a log nobody opens |
| **L2 admissibility** | does this netlist permit it, now? | `ase::netlist_facts` (new, pure Tcl) + `ase::netlist_map_resolve` (exists) | free, cached on the netlist text | **[R-M13]**'s segfault, SP's `controlled_exit`, NOISE's `E_NOACINPUT`, DISTO's silent zeros |
| **L3 delivery** | can this value physically reach the simulator? | the option catalogue's `cptype` + `door` + `phase` | free | F15's four silent type failures and the 26 pre-deck variables that `.options` cannot reach |

**Presentation rule — four states, never invisible:**

| state | when | what the user sees |
|---|---|---|
| `ok` | L0 ∧ L1 ∧ L2 | normal |
| `caution` | L2 with warnings | offered; a sentence saying what will be wrong ("3 of 14 device families contribute no noise: `e1`, `g2`, `t1`") |
| `blocked` | L0 ∧ L1 ∧ ¬L2 | offered, **disabled**, with the reason **and the fix** |
| `absent` | L0 ∧ ¬L1 | listed, **disabled**, "this ngspice was built without PSS (`--enable-pss`)", plus a **Detect** button |

A user who cannot find `pss` in ADE-L has no way to learn why. This costs one column in a table and
is the first place the design is plainly better than ADE-L.

### 1.1 The unmeasured case

`ase::sim_capabilities`' standing contract: **a missing key means "not measured", never "no"**
(decision J). Applied naively, an unmeasured probe would empty the dialog. So the registry carries
`gated 0|1`, sourced from the `#ifdef` set in `src/frontend/commands.c:312-362` — `ac dc op tran pz
tf disto noise sens` are unconditional in every ngspice that has ever shipped; only `sp` (RFSPICE)
and `pss` (WITH_PSS) are bracketed.

* `analyses_available` present → it is the authority for gated and ungated alike.
* absent → offer the **ungated baseline** as `ok`, show every `gated 1` type as `absent`-with-Detect.

We never claim a measurement; we fall back to a source-verified invariant. `[B-D6]`, adopted whole.

---

## 2. Decisions

`⚖` marks one that needs a user ruling (§14). Each is citable from a commit message and a suite row.

### Architecture

**DR1 — One registry, `ase::analysis_types`, in `ase.tcl` (Tk-free), is the single description of
an analysis.** Radio row, form, Arguments column, emit arm, validation, plot list, results
destination, capability gate and refusal set all derive from it. Seven literals become seven
readers. `[B-D1]`/`[A-thesis]`/`[C-C2]`, unanimous.

**DR2 — The registry is per backend, through an OPTIONAL hook.** `ase::register_backend` requires
exactly five hooks (`render_deck run_cmd log_file result_probe raw_file` — CODE-HERE) and tolerates
extras; `capabilities` already rides that way. `analysis_types` joins it. Satisfies spec **D3**.

**DR3 — The state schema does not change in stages 0-8.** `analyses` stays a list of open dicts;
`version` stays 1; no new top-level key. 105 committed `.state` files and five byte-identity rows
(F13). Everything new is a per-row key, absent by default. The one exception is the campaign
(**DR26**), which is ⚖ R8.

**DR4 — Exactly two optional per-row keys: `id` and `x`.** `id` is a stable handle that makes N
rows of one type addressable (⚖ R6). `x` is a *labelled* verbatim list of `.control` lines that
**actually emits**, rendered in the Arguments column as `verbatim: <n> line(s)`. `state_serialize`'s
`[list]` quoting round-trips both byte-stably.

**DR5 — `ase::state_default` keeps its four rows.** ⚖ R4. Today it would change by accident.

### Capability

**DR6 — Offered = registry ∩ `analyses_available`, with the ungated baseline as the fallback.** §1.1.

**DR7 — One new probe leg, in the existing capability deck, verdict from a file.** **[R-M16]**'s
`help <verb>` redirect per registry verb plus `devhelp`. Never `help all` (truncates at the first
NULL `co_func`, `com_help.c:56` — [crit §3.2]). Never the exit code (**[B-M4]**: a parse-only deck
exits 1 while writing its redirects correctly). Parse rule: keep a stanza only when **its first
token equals the verb probed** — which survives the `help tf` upstream bug **[R-M16]**.

**DR8 — The dialog never starts a probe.** `ase::sim_caps_have_path` (signature
`{backend path {eargs {}}}`, returns 0/1 — CODE-HERE) is the free peek; **Detect** is the only door
to a cold measurement. Measured worst case for a program that never answers: **31.2 s**
(issues 0953/0958/0959). A startup probe in front of the analyses list would make opening it take
31 s.

**DR9 — Two caches, two keys.** Binary → resolved path + mtime + size. Netlist → the exact netlist
text (the key `op_annot` already uses). They invalidate on different events.

### Netlist admissibility

**DR10 — `ase::netlist_facts {netlist_text}` is a second pure-Tcl pass beside `ase::netlist_map`.**
It reuses the continuation folding and `.subckt` scope stack but **keeps the `k=v` parameter tokens
`netlist_map` discards**, which is the only way to answer "does this source carry an `ac` value",
"a `distof1`", "a `portnum`", "a `trnoise`".

**DR11 — Static by default, exact on request.** Static (`netlist_facts`, free) **warns**; exact
(**[B-M2]**'s `show v : acmag` parse-only probe, one run per netlist, verdict from a file)
**blocks**. A false refusal is worse than a missed one, and the stand-down precedent for
`.include`-bearing scopes is already ruled in `netlist_map_resolve`.

**DR12 — The device × analysis matrix is computed for the user's deck.** The binary's families
(`devhelp`, same probe run) × the deck's families × the hook matrix. The distinction that matters:
a missing **contribution** hook (`DEVnoise`, `DEVdisto`) is usually *correct* → `caution`; a missing
**matrix stamp** (`DEVacLoad`, `DEVpzLoad`) is always wrong → `blocked`. `[B-D12]`.

### The deck

**DR13 — Analyses are `.control` COMMANDS, one at a time.** Five measured reasons: a bare `run`
dispatches every card in `analInfo[]` order regardless of type [crit §5.5]; `.op`/`.tf` cards starve
the save scope; two `.sens` **cards** abort with rc 134 while two `sens` **commands** are fine
[crit §D5]; `-b` double-runs; and the dot-card route is one of the two that reaches **[R-M13]**'s
segfault. Unanimous across all three designs.

**DR14 — No conditional logic in the generated deck except the numeric `$sim_status` guard.**
**[B-M5]**: `.control`'s `if` on strings takes the **false** branch for both `eq` and `ne`. Every
decision belongs to the renderer, in Tcl, where it is testable.

**DR15 — Decisions A / D / E / F stand unchanged.** `op` last (and the `dc ac tran op` reorder when
device-OP requests are live); a `$sim_status` guard after **every** analysis, **above** any write;
`remzerovec` before **every** write, because it is per-plot; the device `@dev` names ride the `op`
write **and no other** — **[R-M4]** proves those names *create* the vectors, so this is not a style
choice.

**DR16 — THE WRITER IS THE `setplot previous` WALK, plus a per-write sidecar.** ⚠ This replaces
design B's mode B, which **[R-M2]** shows produces a rawfile ASE-L rejects. Contract:

* a single-plot analysis emits exactly what it emits today — `remzerovec` then `write <raw>` —
  so **single-plot decks stay byte-identical** and the committed goldens do not move at stage 1;
* a multi-plot analysis appends `(nplots-1)` × { `setplot previous` ; `remzerovec` ;
  `write <raw>` };
* from stage 6 an `echo "PLOT <type> <id> |$curplotname|" >> <cell>_ase.plotmap` line precedes each
  write, giving a **creation-ordered, 1:1** map from the rawfile's `Plotname:` records to the
  analysis row that produced them — which is the only thing that separates **[R-M11]**'s two
  `Sensitivity Analysis` plots and two rows of one type;
* `<cell>_ase.plotmap` is **deleted before every run**, exactly as the rawfile is, because `>>`
  appends (repairs `[C]`'s unnamed defect);
* `nplots` is a **predicate**, not a constant (§5.3), and an over-count degrades rather than
  destroys **[R-M3]**, so §9.3's post-run reconciliation is the safety net and not a blocker.

**DR17 — Pre-deck options go into `<rundir>/.spiceinit`, plus `-D` for the bool/string subset.**
**[R-M17]**: the file beside the deck is found first from any cwd (`main.c:1264-1300`, netlist dir
then `$SPICE_USERINIT_DIR` then cwd then `$HOME`, `break` on first hit — CODE-HERE). `-D name`
makes a `CP_BOOL`; `-D name=v` makes a `CP_STRING` and **nothing else** (`main.c:984-999` —
CODE-HERE), so it cannot carry a `CP_NUM`, `CP_REAL` or `CP_LIST`. ⚖ R2.

**DR18 — Every pre-deck option and the entire campaign mechanism are REFUSED when the simulator
entry carries `-n`.** **[R-M17]**: the same deck gives 4700 with the file honoured and 1e-12 with
`-n`, and the only message is about the resistor. `ase::sim_nospiceinit` already answers the
question, so the refusal is free. `[A-P27]`/`[B-D18]`.

**DR19 — ASE-L owns `<rundir>/.spiceinit`, and CHAINS BY COPYING, NOT BY `source`.** ⚠ **[R-M7]**
corrects both B and C: `source <user file>` inside a `.spiceinit` is parsed as a **netlist** and the
user's variables are lost. ASE-L reads `$HOME/.spiceinit` (or `$SPICE_USERINIT_DIR`'s) itself and
copies its lines under a banner, deletes and rewrites the file per run, refuses when it finds one it
did not write, and prints one line in the run log saying the file exists and what it shadows.
⚠ `ase::rundir` falls back to `set_netlist_dir 0` when the state has no rundir — a directory shared
by every cell and by xschem's own netlister — so **the campaign and the pre-deck class require an
explicit per-session rundir**, and the refusal must name that.

**DR20 — One internal run interface, `-b` first.** ⚖ R1, and it is the most consequential ruling in
this document. `refuse libngspice` (§15). See §8.6.

### Honesty

**DR21 — Any value the form collects and cannot emit is REFUSED at OK, never stored.** The only
storable-but-unemitted thing is `x` (DR4), which *does* emit and says so. This is what deletes F3.

**DR22 — Refusals appear where the typing is.** Generalise `ase::ui::rsel_status` into
`ase::ui::dialog_status {w key msg}` at a reserved grid row; keep the `ase::echo` line for the
action log and for headless assertions. Today OK "does nothing" and the sentence lands in another
window.

**DR23 — Every option descriptor carries its type and its door, and ONE emitter is the only thing
allowed to spell an option line.** ⚠ **The type is not one field.** The `cp_getvar` half needs
`CP_BOOL|CP_NUM|CP_REAL|CP_STRING|CP_LIST`; **the OPTtbl half needs its own split**, because
`cktsopt.c` (CODE-HERE) mixes `IF_FLAG` (`keepopinfo`, `klu`, `oldlimit`, `noopiter`), `IF_INTEGER`
(`itl4:294`, `srcsteps:297`, `gminsteps:298`, `maxord:314`) and `IF_REAL` (`trtol:285`, `temp:290`)
in one table. Design C's single `class opt` arm emits `.options gminsteps` for a user who typed 0 —
a window reporting a setting that is not in force, inside the proc written to prevent exactly that.

**DR24 — An option that is INERT in this build is never offered as a live field**, and its
catalogue row keeps the reason so the next reader does not re-add it from the manual. Three shapes:
not offered at all / offered with a clamp and the reason / kept as a tombstone. §7.4.

**DR25 — The GUI is the sole authoritative store of analysis settings.** OP has zero parameters and
nothing about a DC or OP job can be read back (F12). The simulator is asked only what it *can* do,
never what it *was told*. The one exception is §7.6's **post-run verification** (**[R-M9]**), which
asks what actually took effect and reports the difference — the opposite direction.

**DR26 — Campaigns are generated, sharded, and the GUI is the random number generator.** §10.1. ⚖ R8
decides where the configuration lives.

**DR27 — Phase is rendered in degrees, always, and the deck says so.** ⚠ **[R-M10]**: `vp()` returns
**radians**. Any `meas`, any derived phase margin, any phase trace must be preceded by
`set units=degrees` in the `.control` block, and the Y-axis label must say `deg`. No design caught
this and all three route a phase margin to the user.

**DR28 — Event-driven results ride a VCD, not the rawfile.** **[R-M6]**. §9.5.

---

## 3. The data structures

Real shapes, in the house's Tcl idiom. `ase.tcl` stays Tk-free; only §6's renderers touch Tk.

### 3.1 `ase::analysis_types` — the registry

```tcl
# ── ase.tcl ────────────────────────────────────────────────────────────────
# THE analysis registry. Backends declare it through the OPTIONAL
# `analysis_types` hook (DR2); ase::analysis_types resolves the hook for the
# simulator in force and falls back to {} -- never to a literal list.
#
# CONTRACT, key by key
#   label      display noun. A user-facing string -> ratify before minting.
#   verb       the .control command word AND what `help <verb>` is probed with
#              (DR7). ngspice has THREE namespaces for one analysis: verb
#              `noise`, registry `NOISE`, plot `Noise Spectral Density Curves`.
#   gated      1 when an #ifdef in commands.c can remove it (DR6).
#   emitorder  ascending. op=0 dc=10 ac=20 tran=30 reproduces today's order
#              exactly; new types take 40+. `op` LAST is a separate named rule
#              (DR15), not this number -- its reason is about op's sticky save
#              list and does not generalise.
#   viewrank   which analysis the waveform window opens on when several are
#              enabled. SEPARATE FROM emitorder ON PURPOSE: ase::plot_sim_type
#              is a PREFERENCE ranking (CODE-HERE: it walks a fixed order and
#              takes the LAST enabled, and its header says issue 0964 broke the
#              coupling to emit order and it must not be re-established).
#   fields     ORDERED list of field descriptors (3.2). ONE list, three roles:
#              form order, Arguments-column order, emit slot order. Two lists
#              is how `ac.dec` drifted.
#   emit       a TOKEN TEMPLATE (3.3), or {build <proc>} for the two shapes a
#              template cannot express.
#   plots      list of {match <glob on the Plotname literal> when <pred>
#                       role <r> results <dest> label <user string>}
#              -- see 5.3. LENGTH IS A PREDICATE, NOT A CONSTANT.
#   needs      precondition ids evaluated against netlist_facts (3.5).
#   fatal      the subset of `needs` whose failure DESTROYS the run rather than
#              degrading it. Re-checked in render_deck, not only in the dialog.
#   rules      cross-field and option x analysis refusals (3.4).
#   options    the per-analysis option catalogue subset this type may carry.
#   results    every plot names a destination. NO ANALYSIS MAY BE REGISTERED
#              WITHOUT ONE -- that is how decisions B and C are enforced
#              structurally instead of remembered.
#   registered 0 means "declared so the reader knows why it is missing"; the
#              entry carries the closing procedure in a comment.
proc ase::analysis_types {{sim {}}} { … resolve the hook, cache per sim … }
proc ase::analysis_entry {sim type} { … {} when absent … }
proc ase::analysis_field {sim type field} { … }
```

### 3.2 The field descriptor — `kind` is the whole type system

| `kind` | widget | validate | emits | picker |
|---|---|---|---|---|
| `int` | entry | integer, `min`/`max` | bare | — |
| `real` | entry + suffix parser | SPICE suffix `f p n u m k meg g t` | **verbatim as typed** | — |
| `freq` | entry + suffix, unit `Hz` | `> 0` for `dec`/`oct` | verbatim | — |
| `time` | entry + suffix, unit `s` | `>= 0` | verbatim | — |
| `mode` | readonly `ttk::combobox` | member of `values` | the token | — |
| `bool` | `checkbutton` | — | present/absent, **never `=1`** | — |
| `node` | entry + **Pick** | `netlist_map_resolve` | `v(<n>)` | `select_on_design` |
| `nodepair` | two entries + Pick | both resolve; ref optional | `v(a)` or `v(a,b)` | `select_on_design` |
| `source` | combobox from `netlist_facts` + Pick | in the filtered set | instance name | `select_on_design` |
| `device` / `param` | combobox from `netlist_facts` / `devhelp -flags` | in the set | as typed | — |
| `glob` | entry | non-empty | as typed | the §10.2 picker |
| `expr` | entry | the measure grammar (§9.4) | as typed | Calculator |

**`real`/`freq`/`time` emit VERBATIM.** ngspice's own parser is the authority and a round trip
through a Tcl double turns `1meg` into `1000000.0`. The GUI parses only to validate and to compute
derived readouts. Decision N already requires this for stored numerics.

**`relabels` is one line**, because `ase::ui::dialog_row` names its label `$w.l$ename`
(CODE-HERE, `src/ase_window.tcl`):

```tcl
# the mode field carries the labels as DATA on its target:
points {kind int labels {dec {Points per decade} oct {Points per octave}
                         lin {Number of points (2 gives ONE point)}} …}
# and the -command is:
proc ase::ui::chana_mode_changed {key type field} {
  set w   [ase::ui::chana_form $key]
  set tgt [dict get [ase::analysis_field $sim $type $field] relabels]
  set lbl [dict get [ase::analysis_field $sim $type $tgt] labels \
             [ase::ui::form_get $key $field]]
  $w.l$tgt configure -text "$lbl:"
}
```
Today the label is `[string totitle $f]:` with no unit and no hint (CODE-HERE, `chana_show`). This
is the ADE-L behaviour people actually miss, and it is the fix for `lin` meaning *total* while
`dec` means *per decade*.

### 3.3 The emit template

```
@name    required slot
@name?   optional; omitted when empty
@name!   optional WITH A DEPENDENCY: emitting it forces every EARLIER optional
         slot to be materialised with its `whenskipped` default, because
         ngspice's argument lists are POSITIONAL. This is the rule
         `tran tstep tstop [tstart [tmax]] [uic]` needs: a tmax with no tstart
         must emit `tstart 0`, never shift a slot.
{build <proc>}  the escape hatch, used by exactly two types (NOISE's
         v(out,ref) composite; PZ's four-node + two-mode-word form).
```
**ONE emitter builds both the deck line and the Arguments column** (`[C-C6]`). The `ac.dec` drift
exists precisely because there are two producers today; with one, the column and the deck cannot
disagree, and ⚖ R-none: the Arguments column becomes the emitted line (`[A-R8]`), which is the
strongest available statement that the window and the simulator agree.

### 3.4 Cross-rules

```tcl
rules {
  {lin_two   {sweep eq lin && points eq 2}  refuse
     {a linear sweep of 2 points yields ONE point (acan.c:103-114); use 3 or more}}
  {klu_sens_ac {opt klu && mode eq ac}      refuse
     {ngspice SEGFAULTS on AC sensitivity under the KLU solver (cktsens.c's guard
      is commented out); use `sparse`, or switch this sensitivity to DC}}
  {single_f  {start eq stop}                warn
     {a single-frequency noise run produces NO Integrated Noise plot}}
  {step_sign {sgn(stop-start) ne sgn(step)} refuse
     {this sweep produces zero points and ngspice reports nothing at all}}
}
```

### 3.5 `ase::netlist_facts` and the `needs` vocabulary

```tcl
# ase.tcl -- a SECOND pass over the text ase::netlist_map already walks, keeping
# the k=v parameters netlist_map deliberately drops.
#  -> {sources {<inst> {scope <s> letter v|i ac <mag> dc <v> portnum <n> z0 <r>
#                       distof1 <a> distof2 <a> stimulus 0|1
#                       trnoise <args> trrandom <args>}}
#      families {resistor 1 vsource 1 mos1 1 …}
#      events   {<node> …}          ;# from `a` lines + .model d_* / *_bridge
#      models   {<name> {type numd|nbjt|numos|bsim4|… level <n>}}
#      nodes    <from netlist_map>
#      exact    0|1}                ;# 1 after DR11's parse probe
proc ase::netlist_facts {netlist_text} { … }
```

| id | predicate | verdict | evidence |
|---|---|---|---|
| `ac_source` | ≥1 independent source with a non-zero AC magnitude | `caution` static / `blocked` exact | **[B-M2]** |
| `input_source_ac` | NOISE's named source exists, is V or I, has `acGiven` | `blocked` | `noisean.c:110-142`, `E_NOACINPUT` |
| `output_node_resolves` | every node named on the form resolves | `blocked` | `netlist_map_resolve` |
| `two_ports` | ≥2 ports **after ASE-L's own `alter portnum` lines** | **fatal** | `span.c:376-386` `controlled_exit` (CODE-HERE), satisfied by §6.6 |
| `contiguous_ports` | portnums are 1..N, unique | `blocked` | span.c port promotion |
| `distof_source` | ≥1 source carrying `distof1` (and `distof2` when `f2overf1` is set) | `caution` | an-smallsig §6.4 |
| `saves_resolve` | **every** save/output/analysis-field name resolves | **fatal when `disto` is enabled** | **[R-M13]** |
| `disto_devices` / `noise_devices` | ≥1 family with `DEVdisto` / `DEVnoise` | `caution` ("will return zeros") | cider-devices §2.6 |
| `pz_devices` | no family lacking `DEVpzLoad`; **no transmission line** | `blocked` | `pzan.c:92-128` |
| `sens_params` | ≥1 eligible perturbable parameter | `caution` | the `devhelp -flags` predicate [crit §5.6] |
| `sweep_target` | DC's target is a V, an I, a **resistor**, or the literal **`temp`** | `blocked` | `dctrcurv.c:89-151`, **[R-M12]** |
| `no_event_nodes` | the deck has no XSPICE event node | `caution` for `dc`; **blocked** for `.probe alli` | xspice §5.5, §12.1 |
| `cider_klu` | no CIDER device while `.options klu` is set | **fatal** | builds §2.3 (`exit(1)`, the rest of `.control` never runs) |

⚠ **`saves_resolve` is not new work — most of it ships.** `ase::preflight_scan` already calls
`ase::netlist_map_resolve` per output identifier and `ase::preflight_gate` already **REFUSES** a run
whose saved output names do not resolve, case-mode aware, with repair suggestions, wired ahead of
any deck write (CODE-HERE). Design B's "built and unused" is **wrong** (§12 C2). What is genuinely
new: (a) the same check applied to identifiers typed on **analysis form fields**, which
`preflight_scan` does not see; (b) the `k=v` facts `netlist_map` discards; and (c) the disto
cross-rule, which **must not be defeasible by `set ase_preflight 0`** — that escape exists today and
it would re-open a SIGSEGV.

### 3.6 The option catalogue

```tcl
# ase.tcl -- ONE row per option over BOTH catalogues (OPTtbl's ~86 keywords and
# hidden-vars' 163 cp_getvar variables, provably disjoint). ~250 rows, generated
# once from the dossiers and hand-maintained. The five columns that matter are
# cptype, door, phase, scope and inert; without them the GUI is guessing (DR23).
variable ase::sim_options {
  reltol    {cat task cptype optreal door options scope global group tolerances
             default 1e-3 gt 0 results 1
             help {relative error tolerance of the Newton loop}}
  gminsteps {cat task cptype optint  door options scope global group convergence
             default 10 min 0 results 1
             help {number of gmin-stepping steps; 0 disables gmin stepping}}
  keepopinfo {cat task cptype optflag door options|control scope {analysis ac noise pz tf disto sp}
             group output default 0 plots 1
             help {keep the operating point ngspice computes before a small-signal
                   analysis, as an extra plot}}
  klu       {cat task cptype optflag door options scope global group solver default 0
             help {KLU direct solver} conflicts {sens_ac cider}}
  oldlimit  {cat task cptype optflag door options scope global
             inert {TSKfixLimit is never copied by CKTnewTask (cktntask.c:68), so
                    this option is silently dropped on the .control route ASE-L uses}}
  itl4      {cat task cptype optint door options scope {analysis tran} group iteration
             default 100 min 100
             clamp {niiter.c:37-39 raises every iteration limit below 100 to 100, so
                    the shipped default of 10 is already 100}}
  sqrnoise  {cat var  cptype bool   door options|control scope {analysis noise sp}
             group output default 0 plots 1 results 1
             help {report noise as V^2/Hz instead of V/sqrt(Hz); RENAMES both plots}}
  units     {cat var  cptype string door control scope global group output
             default radians values {radians degrees} results 1
             help {angle unit for vp()/ph(). ⚠ RADIANS BY DEFAULT -- a phase margin
                   computed without this is wrong by 57.3x}}
  interp    {cat var  cptype bool   door control scope global phase output results 1
             group output default 0
             help {resample every plot onto a uniform grid before it is written}}
  casemode  {cat var  cptype string door predeck scope global phase L1
             values {fold preserve distinguish} owner casemode_batch
             help {node-name case policy; MUST reach ngspice before the deck is read}}
  wnflag    {cat var  cptype num    door predeck-file scope global phase L1
             help {MOS W is total (0) or per finger (1)}}
  norefprint {cat var cptype bool   door control scope global group diagnostics
             help {kills the ` Reference value ` progress ticker -- ASE-L must NOT
                   emit this while a progress bar is on screen}}
  ramptime  {inert {the live code is inside #ifdef XSPICE_EXP, which is defined
                    nowhere in this tree. It is an XSPICE code-model knob plus one
                    breakpoint, NOT a supply ramp}}
  nosavecurrents {inert {documented by the manual §13.7; the string appears NOWHERE
                    in this source tree. Tombstone -- do not re-add it}}
  …
}
```

`door` is **computed, never typed**:

| `door` | emitted as | when |
|---|---|---|
| `options` | `.options name` / `.options name=v` above `.control` | OPTtbl keywords; `cp_getvar` vars read at or after `inp.c:1376` |
| `control` | `set name` / `set name=v` inside `.control` | same set, when the value must not survive into a sibling deck |
| `predeck` | `-D name` or `-D name=<string>` | `phase L1/L2` **and** `cptype ∈ {bool, string}` |
| `predeck-file` | a `set` line in `<rundir>/.spiceinit` | `phase L1/L2` **and** `cptype ∈ {num, real, list}` |
| `cmdline` | a real argv flag (`--soa-log=…`) | the handful that are flags |

And **one speller**, which is where F15's traps become type errors:

```tcl
proc ase::opt_line {name value} {
  set d [dict get $::ase::sim_options $name]
  if {[dict exists $d inert]} {
    return -code error "ase: option '$name' does nothing in this build:\
 [dict get $d inert]"
  }
  switch -- [dict get $d cptype] {
    bool    { if {$value in {1 true yes on}} { return "set $name" }
              return {} }            ;# absence IS off. `set x=1` is ALSO off. Never `=`.
    num - real { if {$value eq {}} { return {} }
                 return "set $name=$value" }   ;# a bare `set` here is silently inert
    string  { return "set $name=$value" }
    list    { return "set $name = ( [join $value { }] )" }
    optflag { if {$value in {1 true yes on}} { return ".options $name" }
              return {} }            ;# IF_FLAG: a value is meaningless
    optint - optreal - optstring {
              if {$value eq {}} { return {} }
              return ".options $name=$value" }  ;# ⚠ THE SPLIT DR23 REQUIRES:
                                     ;# gminsteps/srcsteps/itl4/maxord are IF_INTEGER
                                     ;# and trtol/temp are IF_REAL. Emitting a bare
                                     ;# `.options gminsteps` for a user who typed 0
                                     ;# is F3 inside its own antidote.
    default { return -code error "ase: option '$name' has no cptype" }
  }
}
```
Three of F15's four traps die in that `switch`; the fourth (`-D name=value` is always a
`CP_STRING`) dies in the `door` computation, which never routes a `num`/`real`/`list` to `-D`.

### 3.7 The capability answer, extended

```
{known 1 usable 1 appendwrite 1 blanket_op_save 0 hier_op_names 1
 analyses_available {ac dc disto noise op pz sens sp tf tran}
 devices_available  {resistor capacitor vsource … d_cosim adc_bridge …}}
```
`analyses_available` = the first-token scan of **[R-M16]**'s per-verb file, published only when the
file parsed cleanly. `devices_available` = the `devhelp` dump, which is a **stronger** XSPICE signal
than the `codemodel` command (the command proves XSPICE was compiled; the models prove `spinit`
actually loaded them) and is also the CIDER probe. ⚠ Do **not** test CIDER by row count: a
non-installed build lacks `spinit` and loses 81 XSPICE rows. Grep `^(NUMD|NBJT|NUMOS)`
[builds §2.1]. Derived booleans stay derived: `has_sp`, `has_pss`, `has_cider`, `has_xspice`,
`has_osdi`.

⚠ **OSDI.** `osdi_add_device` appends OpenVAF devices to `DEVices` at load time
(`src/spicelib/devices/dev.c:584,608` — CODE-HERE), so a `devhelp` run against a **scratch** deck
cannot see the user's PDK devices. DR12's family accounting must therefore treat an **unknown**
family as `caution`, never `blocked`, and the exact leg (DR11) must run `devhelp` against the
**user's own deck** when it runs at all. Otherwise the design's worst outcome — refusing an analysis
that would have run — is the likely one on any Verilog-A PDK.

---

## 4. S1 — the type list

§1 is the model; §3.7 is the measurement. What remains is the six hard cases.

**PSS — the build probes changed the answer, and all three designs are now wrong.** Every design
refused a PSS form on the grounds that nobody had ever run it. Somebody has: `builds.md` §1 built
`--enable-pss` and ran it. PSS is **SHIPPABLE as an explicitly-experimental panel**, gated on
`help pss` (`pss [.pss line args] : Do a periodic state analysis.` present vs `Sorry, no help for
pss.` here), *if and only if the form is a hard validator*. Measured: a 3-stage ring in 0.91 s, Van
der Pol in 0.41 s, both `Convergence reached`, both within ~1 % of their documented f0. Two plots,
literals **`Time Domain Periodic Steady State Analysis`** (points+1 rows, scale `time`, **absolute
circuit time, not 0..T**) and **`Frequency Domain Periodic Steady State Analysis`** (exactly
`harmonics` rows including DC, scale `frequency`, magnitudes only, every variable tagged `plot=1`).
The form **must refuse**: `harmonics < 2` (0 = SIGSEGV, 1 = infinite recursion at 199 % CPU),
`fguess <= 0`, `fguess` biased **high** (2.1× high aborts; 19× low converged — bias the default
low), `points < 8`, `sc_iter > 1023` or `< 5`, `steady_coeff < 1e-6` (1e-9 gave a **false**
`Convergence reached` 4.5 % wrong). And: **rc is not a success signal** — `Convergence not reached`
returns **rc 0** with both plots full of plausible data, so the panel scrapes stdout for the verdict
string; the plot numbering is **not** fixed (the recursive relaunch produces 2×(1+relaunches)
plots), so take the **last** TD/FD plot by Plotname; and `oscnode` steers nothing — say so on the
field. ⚖ R7. [builds §1.10]

**SP — offered, and made satisfiable.** `gated 1`. `needs {two_ports contiguous_ports}` with
`two_ports` **fatal** because `span.c` calls `controlled_exit(EXIT_BAD)` below two ports (CODE-HERE):
the process dies, the `.control` block never resumes, and `run_done` may still see rc 0 if an
earlier analysis succeeded. **But the precondition is satisfied by the GUI, not merely checked**:
**[R-M5]** proves `alter <src> portnum = N` / `alter <src> z0 = R` on ordinary V sources makes `sp`
run and return a correct `s_1_1`. §6.6 is the Ports table that emits those lines. This honours F13's
founding doctrine (nothing goes on the schematic) and turns a dead end into a feature ADE-L's own
setup assistant does not beat.

**DISTO — offered, `ok`, with the narrowest true refusal.** **[R-M13]**: the trigger is *a save list
that resolves to nothing*, not "a narrowed save" and not "no save" — a `.control` deck with `disto`
and **no** save at all returns rc 0. So: `saves_resolve` is promoted to **fatal** whenever `disto`
is enabled, checked in the dialog **and** re-checked in `render_deck`, **and not defeasible by
`set ase_preflight 0`**. When the netlist cannot answer (an `.include`-bearing scope where
`netlist_map_resolve` stands down), **widen to a `.save all` card and say so in the run log** — a
wide save is a big file; a segfault is a lost run, and `.save all` alongside the narrow save is
measured safe (**[R-M13]** row 2). The one-line upstream fix (capture `OUTpBeginPlot`'s return at
all five `distoan.c` sites, mirroring `acan.c:169-175`) is filed separately and blocks nothing.

**SENS — offered, with an option × analysis cross-rule.** **[R-M14]**: `sens … ac` under
`.options klu` is a SIGSEGV while `sens … dc` is safe. This is only expressible because §3.6 models
options as typed objects rather than free text (§3.4's `klu_sens_ac`). The refusal offers the fix at
the moment of typing. ADE-L has no sensitivity analysis at all.

**CIDER — detect it, do not offer it, do not ignore it.** CIDER adds no analysis, no dot card and no
`SPICEanalysis`; it is model authoring and belongs in a model editor. But the analyses pane owes it
four things [builds §2.4]: (1) **warn before running** when the netlist has `.model … numd|nbjt|
numos` and the probe says CIDER is absent — ngspice's own message is `could not find a valid
modelname`, naming neither CIDER nor the flag; (2) **never emit `.options klu`** on such a deck —
measured `exit(1)` with every later `.control` command skipped; (3) mark noise/disto/SOA **silently
incomplete** and pz **unreliable** (`DEVnoise`/`DEVdisto`/`DEVsoaCheck` are NULL; the shipped
`bjt/pz.cir` prints `Pole-zero iteration limit reached`); (4) **budget minutes, not seconds** — the
shipped examples span 0.10 s to **329.5 s**, so the run timeout and the progress UI must not assume
a toy. Also export `CIDER_COM_QUIT=OFF` when driving non-interactively.

**And F2's silent drop dies first.** ⚠ The cause is **not only** the missing `default` arm. The emit
loop is `foreach type $anorder { foreach a [analyses] { if type ne $type continue … } }`
(CODE-HERE) — an unknown type is **never visited at all**, while `ase::n_enabled_analyses` still
counts it and the pane still shows it ticked. So Stage 0 must (a) iterate the **enabled rows**, not
the fixed order, (b) raise a named error on a row whose type is not in the registry, and (c) add the
same check to `ase::preflight_gate` so the refusal arrives before any artifact is touched.

---

## 5. S2 — per-type metadata: all twelve

### 5.1 The reference table

Grammars are from the parser (`inp2dot.c`, the `*setp.c` files), not from the manual or from
`src/ngspice.txt` — those disagree in three places, and **[R-M16]** measured a fourth (`help tf`
prints the transient help).

| type | emitorder | viewrank | gated | fields, in order | emitted line | plots (literal `Plotname:`) |
|---|---|---|---|---|---|---|
| `op` | 0 (**last**) | 40 | — | *(none)* | `op` | `Operating Point` |
| `dc` | 10 | 10 | — | `target kind start stop step` + optional `target2 kind2 start2 stop2 step2` | `dc <t> <a> <b> <s> [<t2> <a2> <b2> <s2>]` | `DC transfer characteristic` |
| `ac` | 20 | 20 | — | `sweep points start stop` | `ac <sweep> <n> <fa> <fb>` | `AC Analysis` (+ `AC Operating Point` under `keepopinfo`) |
| `tran` | 30 | 30 | — | `step stop tstart tmax uic` + §10.3's noise section | `tran <step> <stop> [<tstart> [<tmax>]] [uic]` | `Transient Analysis` |
| `noise` | 40 | 0 | — | `output outref source sweep points start stop contributors ptssum` | `noise v(o[,r]) <src> <sweep> <n> <fa> <fb> [<pps>]` | `Noise Spectral Density Curves`†, `Integrated Noise`‡ (+ `NOISE Operating Point`) |
| `tf` | 50 | 0 | — | `outkind outnode outref outsrc insrc` | `tf {v(n[,r])\|i(vsrc)} <insrc>` | `Transfer Function` |
| `pz` | 60 | 0 | — | `in1 in2 out1 out2 transfer mode` | `pz <n1> <n2> <n3> <n4> {vol\|cur} {pol\|zer\|pz}` | `Pole-Zero Analysis` (+ an OP plot mislabelled **`Distortion Operating Point`** — upstream copy-paste, `pzan.c:58`) |
| `disto` | 70 | 0 | — | `sweep points start stop f2overf1` | `disto <sweep> <n> <fa> <fb> [<r>]` | 2 harmonic plots, or **3** IM plots when `f2overf1` is given |
| `sens` | 80 | 0 | — | `outkind outnode outref outsrc filters mode sweep points start stop` | `sens <out> [<globs>] {ac <sweep> <n> <fa> <fb> \| dc}` | `Sensitivity Analysis` — **the same literal in both modes, [R-M11]** |
| `sp` | 45 | 20 | `has_sp` | `sweep points start stop donoise` (+ the Ports table, §6.6) | `sp <sweep> <n> <fa> <fb> [<donoise>]` | `SP Analysis` (+ `AC Operating Point`) |
| `pss` | 90 | 0 | `has_pss` | `fguess stabtime oscnode steady_coeff points harmonics sciter uic` | `pss <7 positional> [uic]` | `Time Domain Periodic Steady State Analysis`, `Frequency Domain Periodic Steady State Analysis` |
| *(`options`)* | — | — | — | **not an analysis** — the ~86-keyword task settings sheet, i.e. §7's catalogue | — | — |

† renamed `… - (V^2 or A^2)/Hz` under `sqrnoise`. ‡ **exists only when `start != stop`**
(`noisean.c:511`); renamed `Integrated Noise - V^2 or A^2` under `sqrnoise`.
**`SEN2` and `HB` are not in this table and never will be** — `SEN2info` and `HBinfo` are `extern`
declared and defined nowhere (F1).

⚠ **`viewrank` is not `emitorder`.** `ase::plot_sim_type` walks a fixed order and takes the LAST
enabled; its own header says issue 0964 broke the coupling to emit order and it **must not be
re-established** (CODE-HERE). With twelve types someone has to say which analysis the waveform
window opens on when noise, tran and sp are all enabled; the table above answers it as data, and
today's answer (`tran` wins over `op`) falls out unchanged.

### 5.2 The three entries written out

**NOISE — the hard case** (a node-pair argument, a filtered source picker, a mode selector, two
plots, a scalar *and* a spectrum, an optional argument that changes what the other plots contain,
and a device-support caveat):

```tcl
noise {
  label {Noise}  verb noise  gated 0  emitorder 40  viewrank 0  registered 1
  fields {
    output {kind nodepair label {Output} pick node required 1
            help {the node whose noise you want; a reference is optional}}
    source {kind source   label {Input source} pick source required 1
            filter {letter {v i} acgiven 1}
            help {a V or I source that carries an AC value; noise is referred to it}}
    sweep  {kind mode label {Sweep type} values {dec oct lin} default dec
            relabels points}
    points {kind int  label {} required 1 min 1 default 10
            labels {dec {Points per decade} oct {Points per octave}
                    lin {Number of points (2 gives ONE point)}}}
    start  {kind freq label {Start frequency} unit Hz required 1 gt 0}
    stop   {kind freq label {Stop frequency}  unit Hz required 1 gt 0}
    contributors {kind bool label {Per-device contributor table} default 0
            help {every device's own noise vectors, inside the spectrum plot}}
    ptssum {kind int label {Report every N points} default 1 min 1 advanced 1
            depends {contributors 1}
            help {ngspice couples the contributor table to spectrum DECIMATION.
                  1 = the table AND the full spectrum. 4 over 21 points leaves 6 rows.}}
  }
  emit  {noise {build ase::an_noise_probe} @sweep @points @start @stop @ptssum?}
  rules {{lin_two {sweep eq lin && points eq 2} refuse {…}}
         {single_f {start eq stop} warn
            {a single-frequency noise run produces NO Integrated Noise plot}}}
  needs {ac_source input_source_ac output_node_resolves noise_devices}
  plots {
    {match {Noise Spectral Density Curves*} role spectrum results viewer
     label {Noise — spectral density}}
    {match {Integrated Noise*} role scalars results value
     when {expr {start ne stop}} label {Noise — integrated}
     vectors {onoise_total inoise_total}}
    {match {NOISE Operating Point} role opinfo results viewer
     when {opt keepopinfo} label {Noise — operating point}}
  }
  results {viewer {traces {onoise_spectrum inoise_spectrum}}
           value  {vectors {onoise_total inoise_total}}
           table  {kind contributors when {field contributors 1}}}
  options {sqrnoise keepopinfo noisyxspice}
}
```

Two things in that entry are the whole argument for a registry. **`ptssum` is `depends`-gated
behind a checkbox named for the thing the user actually wants** — the raw parameter is a decimation
factor whose *side effect* is the contributor table, and nobody should have to know that
(`[C]`, the single best UI idea in the three designs). And **`plots` is a predicate list**, because
NOISE writes one, two or three plots depending on `sqrnoise`, on `start == stop`, and on
`keepopinfo`.

**DC — the entry no design wrote, and the most common bench task**:

```tcl
dc {
  label {DC sweep}  verb dc  gated 0  emitorder 10  viewrank 10  registered 1
  fields {
    kind    {kind mode label {Sweep variable} default source
             values {source isource resistor temp}
             labels_for target {source {V source} isource {I source}
                                resistor {Resistor} temp {}}
             relabels target
             help {dctrcurv.c:89-151 accepts exactly these four}}
    target  {kind source label {} pick source required 1 depends {kind ne temp}
             filter {letter {v i r} by kind}}
    start   {kind real label {Start} required 1}
    stop    {kind real label {Stop}  required 1}
    step    {kind real label {Step}  required 1 ne 0}
    kind2   {kind mode label {Second sweep} default {} advanced 1
             values {{} source isource resistor temp}}
    target2 {kind source label {} pick source advanced 1 depends {kind2 ne {}}}
    start2  {kind real label {Start} advanced 1 depends {kind2 ne {}} required_with kind2}
    stop2   {kind real label {Stop}  advanced 1 depends {kind2 ne {}} required_with kind2}
    step2   {kind real label {Step}  advanced 1 depends {kind2 ne {}} required_with kind2}
  }
  emit  {dc @target @start @stop @step @target2? @start2! @stop2! @step2!}
  rules {{step_sign {sgn(stop-start) ne sgn(step)} refuse
            {this sweep produces zero points and ngspice reports nothing at all}}
         {step_zero {step eq 0} refuse {a zero step is refused by inp2dot.c:320}}
         {three_deep {kind3 ne {}} refuse
            {ngspice supports exactly TWO nest levels; a third triple is silently dropped}}
         {mixed_events {netlist has_events} warn
            {a DC sweep on a deck with auto-bridged event nodes has an unexplained
             failure mode with no root cause (xspice.md 12.1) — check the result}}}
  needs {sweep_target}
  plots {{match {DC transfer characteristic} role sweep results viewer
          label {DC sweep}}}
  notes {nested {a nested DC sweep comes back FLATTENED into one 1-D vector with no
                 Dimensions: header; the family of curves is re-split by ASE-L using
                 the point count ASE-L computed}}
  options {keepopinfo}
}
```

`temp` as a second sweep level is **[R-M12]**, measured: `dc v1 0 1 0.5 temp -40 60 50` → 9 rows.
So "sweep the bias at three temperatures" is **one command** when the temperatures are uniformly
stepped, and only a campaign (§10.1) when they are not — and the form says which route it is taking.
"DC sweep variable: [V source | I source | Resistor | Temperature]" is the cheapest genuine
ADE-beater in the document: ADE-L makes you know which variables are sweepable.

**TRAN — because it carries three things nobody offers today**:

```tcl
tran {
  label {Transient}  verb tran  gated 0  emitorder 30  viewrank 30  registered 1
  fields {
    step   {kind time label {Time step} unit s required 1 gt 0
            help {⚠ NOT an output interval. Its only structural role is to become
                  the default tmax. For a uniform output grid use the Output grid
                  control below.}}
    stop   {kind time label {Stop time} unit s required 1 gt 0}
    tstart {kind time label {Start recording at} unit s advanced 1 whenskipped 0
            help {the simulation still starts at 0; this is when data is KEPT}}
    tmax   {kind time label {Maximum time step} unit s advanced 1}
    uic    {kind bool label {Use initial conditions (skip the operating point)}
            advanced 1 depends_note {needs .ic or .nodeset rows — see Initial conditions}}
    grid   {kind mode label {Output grid} values {native interp linearize} default native
            advanced 1
            help {native = whatever the integrator chose. interp = `set interp`
                  before the run. linearize = `linearize` after it, into a new plot
                  named `<old> (linearized)`.}}
  }
  emit  {tran @step @stop @tstart! @tmax! @uic?}
  plots {{match {Transient Analysis} role sweep results viewer label {Transient}}
         {match {Transient Analysis (linearized)} role sweep results viewer
          when {field grid linearize} label {Transient (uniform grid)}}}
  rules {{uic_no_ic {field uic 1 && no ic_rows && no nodeset_rows} warn
            {uic skips the operating point and starts from the initial conditions
             in the deck; this deck declares none, so every node starts at 0}}}
  options {itl4 trtol method maxord interp}
  sections {trnoise}                     ;# 10.3's collapsible section
}
```

The `grid` field is F12 made reachable: **`tstep` is not an output interval**, and neither `interp`
nor `linearize` appears in design A or B at all. A GUI that labels the field "Time step" with no
hint manufactures the classic misunderstanding it was handed the evidence to prevent.

### 5.3 `plots` is a predicate, and the count is not a constant

Five measured ways "one analysis, one plot" is wrong:

1. `noise` writes **2**, or **1** at a single frequency (`noisean.c:511`);
2. `disto` writes **2** (harmonic) or **3** (IM, with `f2overf1`);
3. `keepopinfo` prepends an extra OP plot to `ac`, `noise`, `pz`, `tf`, `disto`, `sp`;
4. `pz`'s OP plot is labelled **`Distortion Operating Point`** (`pzan.c:58`, upstream copy-paste);
5. `pss` writes **2 × (1 + relaunches)** — measured 4 with `sc_iter=0`, 3 with `points=2`
   [builds §1.6], so the panel takes the **last** TD/FD pair by Plotname.

The registry's `plots` list carries `when` predicates over fields and options, and
`ase::analysis_plots {sim row opts}` evaluates them to a count and a match list. §9.3 reconciles the
prediction against the rawfile after every run.

---

## 6. S3 — the form

### 6.1 Layout

Keep `ase::ui::choose_analyses`' skeleton — the suites drive it **by path**
(`$top.chana.types.tran`, `.step`, `.stop`, `.opts`, `.btns.proceed`), so **adding** paths is safe
and **moving** them is not.

```
.aseN.chana
 ├── .types      wrapping GRID of radiobuttons, 4 per row, state-coloured per §1     row 0
 ├── .enable     "Enable" checkbutton                                                row 1
 ├── .form       ONE child frame — the swapped-in per-type form                      row 2
 │    ├── .l<f> / .<f>    label + widget pairs, built from `fields`
 │    ├── .p<f>           a Pick button at column 2 for pick-able kinds
 │    └── .adv            a disclosure holding every `advanced 1` field
 ├── .note       the precondition banner (§1's caution/blocked sentence)             row 7
 ├── .status     ase::ui::dialog_status                                              row 8
 ├── .opts       "Options…"                                                    row 8 col 2
 └── .btns       Apply / OK / Cancel                                                 row 9
```

⚠ **The `.form` child frame is not cosmetic and it is not free.** It kills two problems at once —
`chana_show`'s hardcoded five-name destroy list `{source start stop step points}` (CODE-HERE),
which `ase-ui.md` calls "the single sharpest trap in the analysis code", and the ceiling where a
seventh quick field collides with the fixed rows 8 and 9. NOISE has eight fields and DC-with-a-
second-sweep has ten; the current layout cannot hold either. **But it relocates `$w.step` and
`$w.stop` to `$w.form.step` / `$w.form.stop`, which five lines of `test_ase_dialogs.tcl` drive by
path.** Design B billed this as "no suites move"; it moves those five lines, deliberately, at
stage 1, and the stage says so.

### 6.2 The fifteen ADE-L behaviours

| # | ADE-L behaviour | verdict |
|---|---|---|
| 1 | type row = what the simulator declares | **improve** — §1's four states with a reason and a Detect button; ADE-L shows no reason for an absent analysis |
| 2 | form swaps in place | adopt; move to one `.form` frame |
| 3 | Enable checkbox on the form | adopt |
| 4 | Enabled column in the list | **improve** — today a `☑` glyph in a text cell with no keyboard reach and no undo; make it Tab-reachable and Space-togglable |
| 5 | sweep mode relabels its neighbour | **adopt** (§3.2) — **improve** by adding a Start/Stop ⟷ Centre/Span pair computed in the GUI (ngspice has no centre/span) |
| 6 | typed Options… sub-dialog | **improve, and this is the correctness item** — §7 |
| 7 | Apply | adopt ⚖ — a third button moves the button bar, which GE4 reads |
| 8 | per-type form memory across a type switch | adopt, **reverses recorded decision D4** ⚖ R5 |
| 9 | several analyses of one type | adopt via `id` ⚖ R6 |
| 10 | list starts empty | refuse for now ⚖ R4 |
| 11 | field-level rejection on the form | adopt — DR22 |
| 12 | typed unit-bearing fields | **improve** — plus the derived readouts nobody offers: "61 points", "≈ 24 MB", "a single-frequency noise run produces no Integrated Noise plot" |
| 13 | pick from the design | **improve** — point `select_on_design` at a **source instance** for DC's target, NOISE's input and TF's input, not only at a net. ADE-L makes you type those names |
| 14 | analyses run in list order | refuse — `emitorder` + the op-last rule; issue 0964's 74.9 MB is the reason |
| 15 | the setup travels with the cellview | already true, and better (multiple `.state` views per cell) |

### 6.3 Where a refusal appears — three tiers

1. **live, per field** — a `-validate key` handler (the `simdlg_editor` idiom, with the `after idle`
   deferral the tree measured) writes a sentence into `.status` and prefixes the label with `⚠ `.
   **No new colour**: the 9-colour palette is locked and a glyph is theme-proof.
2. **at Apply/OK** — `required`, `rules`, `needs`. Refuse, keep the dialog up, sentence in
   `.status`, and — new — **focus the offending widget**. There is no `focus` call anywhere in
   `choose_analyses` today.
3. **at render** — `fatal` preconditions and DR21. `render_deck` refuses, `run_deck` re-raises, the
   run never starts, no artifact is touched. This tier exists because a `.state` can be hand-edited
   and a netlist can change under a saved analysis.

### 6.4 The `.sens` parameter picker, computed offline

A three-device deck yields ~90 sensitivity vectors, which is unusable. `devhelp -csv -type -flags
<device>` prints exactly the four facts `cktsgen.c:193-216`'s eligibility rule needs, so the picker
is computable **with no run**: eligible = `Dir == inout` **and** `Type == real` **and** flags contain
neither `X` (IF_NONSENSE) nor `R` (IF_REDUNDANT) — and, in DC mode, neither `A` nor `AA`. The
selection compiles to `.sens`'s glob filter (`sens v(out) r*:r m*:vth0 ac dec 10 1k 1meg`). A
checkbox tree instead of a 90-row dump, and **ADE-L has no sensitivity analysis at all**.

### 6.5 Initial conditions — the surface `uic` needs

⚠ A `uic` checkbox with no way to author, view or edit the initial conditions it consumes is a
control that changes the answer and reports nothing about what it is using — F3 reintroduced. So the
Analyses dialog gains a small **Initial conditions** sub-dialog (one `listdlg` config) holding:

* **`.ic` rows** — `v(<node>) = <value>`, emitted as one `.ic` card above `.control`; the node picker
  is `select_on_design`;
* **`.nodeset` rows** — same shape, emitted as `.nodeset`; the hint states the difference (a
  `.nodeset` is a *hint* used to find the OP and then released; an `.ic` is *held* during the OP when
  `uic` is off, and is the starting state when `uic` is on);
* **Save this solution** / **Start from a saved solution** — `wrnodev <file>` after a converged `op`,
  and a `.include <file>` row; this is F14 #6, "the closest thing ngspice has to Cadence's
  save/restore DC solution", and ADE-L parity that ASE-L lacks entirely.

### 6.6 The Ports table — SP made satisfiable

```
S-parameter ports
  ┌──────────┬──────┬──────────┐
  │ Source   │ Port │ Z0 (Ω)   │        [Add from schematic…]
  ├──────────┼──────┼──────────┤
  │ v1       │  1   │ 50       │
  │ v2       │  2   │ 50       │
  └──────────┴──────┴──────────┘
  Ports are assigned at run time. Nothing is written to your schematic.
```
emits, immediately before the `sp` line:
```
alter v1 portnum = 1
alter v1 z0 = 50
alter v2 portnum = 2
alter v2 z0 = 50
```
**[R-M5]**, measured on two ordinary V sources declaring no port at all. The `two_ports` fatal
precondition is then evaluated **after** these lines are computed — it refuses only when the *table*
is short, which the user can fix in the dialog. ⚠ `portnum` is **not readable back**
(`show v : portnum` returns 0 for a source declared `portnum 1` — **[B-M3]**), so the table is
GUI-owned state and the netlist scan only *adds* sources that already declare one.

---

## 7. S4 — the options surface

### 7.1 First, stop lying

`ase::ui::chana_options` collects free-text name/value pairs, round-trips them, renders them in the
Arguments column, and **never emits them** (F3, measured end to end: `uic 1 tstart 5u tmax 1n`
typed, all three shown, deck said `tran 10n 200u`). The fix is not to make free text emit; it is to
**delete free text**:

* every field a type genuinely has becomes a **typed field** in `fields` (§5.2) — most of them
  behind the `advanced` disclosure;
* every *option* becomes a row in §3.6's catalogue with a `cptype` and a `door`;
* anything else is **refused at OK** with "ASE-L cannot emit an option named `<x>`";
* the one honest hatch is `x` (DR4) — raw `.control` lines, emitted verbatim immediately before the
  analysis, shown in the Arguments column as `verbatim: <n> line(s)`.

### 7.2 Finding one option among ~250

1. **Search first** — one entry filtering name, group and help text, live
   (`ase::ui::combo_filter`'s prefix-match idiom generalises).
2. **"Changed only" is the DEFAULT view**, with `[Show all]`. A bench normally differs from default
   in 0-5 places; the wall only exists if you insist on rendering it. It is a *filter*, not a
   feature, because the catalogue carries `default`.
3. **Groups, not an alphabet** — the eleven categories already tabulated in `hidden-vars.md` §7.
4. **Two scopes on two surfaces** — global options in `Simulation > Options…` (which already exists
   and already has a state key and an emitter); per-analysis options behind the analysis form's
   `Options…`, filtered by `scope {analysis <type>}`. An option shown in the wrong scope is worse
   than one not shown.
5. **A ⚠ badge on every `results 1` row** — the 21 options that change numbers.
6. **A LIVE DECK PREVIEW PANE** showing the exact lines that will be emitted **and where**:
   `.options gmin=1e-10` above `.control`, `set sqrnoise` inside it, `-D casemode=preserve` on the
   command line, `set wnflag=1` into `<rundir>/.spiceinit`. *A setting with no line in the preview
   is visibly not in force.* This is `[A]`'s best idea and it is what structurally prevents F3 from
   returning; extend it to the whole deck, not only options.

### 7.3 The pre-deck class, made visible

26 of F15's variables are unreachable from `.options` **and** from `.control`. They get their own
group, labelled **"Applied before the netlist is read"**, and each row says which door it will use.
This is not a nicety: `.options casemode=preserve` and `.options nosubckt` are *silently ignored*,
and a GUI that offers them beside `reltol` teaches the user something false. Delivery is DR17/DR19;
the `-n` refusal is DR18.

### 7.4 The inert list — three shapes

* **not offered at all**: `ramptime` (live code inside `#ifdef XSPICE_EXP`, defined nowhere),
  `klu_memgrow_factor`, `nosavecurrents` (absent from this tree entirely), `scalm`, `itl3`, `itl5`,
  `x11lineararcs`, `debug`, `newtrunc` (needs `PREDICTOR`);
* **offered with a clamp and the reason**: `itl1`/`itl2`/`itl4`, widget minimum **100**, tip
  "ngspice raises any iteration limit below 100 (`niiter.c:37-39`), so the shipped defaults 50 and
  10 are already 100";
* **kept as a tombstone**: `oldlimit` — it works from a dot card and is dropped on the `.control`
  route we use (`TSKfixLimit` is never copied, `cktntask.c:68`), so it is not offered, and the row
  keeps the reason so the next reader does not re-add it from the manual.

### 7.5 Per-analysis scope is a GUI fiction, and the GUI says so

ngspice has **no** per-analysis option scope: `option keepopinfo` inside `.control` stays set for
every later analysis. The GUI emits the option immediately before its analysis and **restores it
immediately after** from the catalogue's `default` column — **[R-M15]** proves this works for the
flag class. Two honest limits, both stated on the form: an option with **no known default** is
labelled *global* and offered only on the global surface; and if the live value differs from the
catalogue default (a user `.spiceinit`, a deck `.options`), the restore writes the default and thus
changes a global — which §7.6's verification leg will *report*.

### 7.6 Post-run verification — requested vs effective

⚠ New, from **[R-M9]**, and no design proposed it. At the end of every deck, before `.endc`:

```
option   > <cell>_ase.effective
set      >> <cell>_ase.effective
```

`option` prints the effective task settings and reflects what actually took (`reltol (current) =
0.05`, `itl4 (transient iterations) = 7`, `Integration Method = GEAR`). `set` lists every variable
in force, including ones ngspice silently invented from an unknown `.options` name. ASE-L diffs
**requested vs effective** and surfaces *"you asked for X, the simulator is using Y"*. This is the
only way to catch F15's silently-dropped out-of-range values, it is the cheapest possible staleness
check on a shipped catalogue against an unfamiliar binary, and it **proves a pre-deck delivery
landed** — which closes measurement debt M4 outright instead of deferring it. Caveat: neither
channel reveals a `CP_` class, so §3.6's type table still ships.

### 7.7 Convergence as a remedy, not a field wall

One panel, four rungs matching `cktop.c`'s actual ladder, emitting **either** `.options
noopiter/gminsteps/srcsteps` **or** one `optran` line, **never both** — `optran`'s first three
arguments supersede them on the same task:

```
Operating point strategy
  [x] 1. Newton from the initial guess                       -> optran arg 1
  [x] 2. gmin stepping        steps [ 10 ]                   -> optran arg 2
  [x] 3. source stepping      steps [ 10 ]                   -> optran arg 3
  [x] 4. transient operating point   step [ 100n ] to [ 10u ] -> optran args 4,5
        ⚠ ON BY DEFAULT in this ngspice (`optran 1 1 1 100n 10u 0`, injected by
          init.c:77-94). It returns the TRANSIENT state at the stop time as your
          operating point — measured 0.9999550 instead of 1.0 on a 1 us RC.
      [ Pick a settle time for me ]  = 100 x tstep before a transient,
                                       0.1 / fstart before an AC or noise run
  emits:  optran 1 10 10 100n 10u 0
```
plus **a sentence on the OP form itself**: *"this operating point may come from a transient"*. That
sentence is a fact about the numbers in the Value column and no ngspice user has ever seen it.
⚠ The ramp argument is **always emitted as 0**: `optran.c:670-671` has no clamp, the factor
oscillates and returns to 0 at 2×ramptime, and `README.optran` says ramping is not established.

**The live ladder pane** parses the fixed strings `Starting dynamic gmin stepping` →
`… completed|failed` → `Starting true gmin stepping` → `Starting source stepping` →
`Transient op started`. Two parser rules that must be **comments in the code**: the two `ngdebug`
per-step lines (`Trying gmin = …`, `Supplies reduced to …%`) end **without a newline**, and the
ladder is on **stderr** while `CKTncDump` and SOA warnings are on **stdout** — ASE-L folds them with
`2>@1`, so **match on line CONTENT, never on arrival order**, and never build a state machine that
assumes sequence.

---

## 8. S5 — the deck

### 8.1 The shape

Unchanged above `.control` except for three new card slots. The block becomes:

```
.ic  v(out)=0.9                      ; §6.5, when rows exist
.nodeset v(mid)=0.6                  ; §6.5
.probe p(xu1)                        ; §9.4 card slot -- REFUSED when the deck has event nodes
.four 1meg v(out)                    ; §9.4 card slot
.save all                            ; existing, or the disto widen-fallback (§4)
.control
<pre_commands verbatim>
<cosim bridges>
set appendwrite                      ; when >=1 analysis is enabled
set units=degrees                    ; DR27, whenever any phase is measured or plotted
<global `set` options>               ; ase::opt_line, door=control
<setseed N>                          ; only when a stochastic feature asked for one
<optier_ctl device save commands>    ; before `op`
--- per analysis, in emitorder, op LAST -------------------------------------
<x verbatim lines of this row>                              ; DR4
<per-analysis `set`/`option` lines>                         ; §7.5
<alter portnum/z0 lines>                                    ; §6.6, sp only
<alter <src> trnoise = [ ... ] lines>                       ; §10.3, tran only
<THE ANALYSIS LINE>
if $?sim_status = 0 … end / if $sim_status ne 0 … quit 1 … end   ; DR15, EVERY analysis
<restore lines for the per-analysis options>                ; §7.5
remzerovec
echo "PLOT <type> <id> |$curplotname|" >> <cell>_ase.plotmap ; stage 6+
write <raw> [all <device names>]                             ; device names: op ONLY
   ... repeated (nplots-1) times: --------------------------
   setplot previous
   remzerovec
   echo "PLOT <type> <id> |$curplotname|" >> <cell>_ase.plotmap
   write <raw>
-----------------------------------------------------------------------------
<meas lines>                         ; §9.4, after their own analysis
<eprvcd <event nodes> > <cell>_ase_evt.vcd>   ; §9.5, when the deck has event nodes
<print lines at the anchor>
option  > <cell>_ase.effective       ; §7.6
set    >> <cell>_ase.effective
.endc
.end
```

Notes that are decisions, not taste:

* **The guard stays immediately after each analysis, above any write** (DR15). Measured: one guard
  at the end → rc 0 and a 2198-byte raw with the failure completely masked.
* **`remzerovec` before every write, including every write after a `setplot previous`** — it is
  per-plot, and it is also the structural cure for `hidden-vars` §4.2's measured hazard where one
  zero-length vector makes `checkvalid` abort the **entire** `write` (`savecurrents`+AC being merely
  the easiest way to create one).
* **`<cell>_ase.plotmap` and `<cell>_ase.effective` are deleted before every run**, exactly as the
  rawfile is, because `>>` appends.
* **`set units=degrees` is emitted whenever any phase is measured or plotted** (DR27, **[R-M10]**).

### 8.2 The decks the GUI must refuse to generate

This list is the design. Each row is a `rules`/`needs` entry with a measurement behind it.

| # | refuse | because | evidence |
|---|---|---|---|
| 1 | `disto` enabled together with **any** save/output/field name that does not resolve | **SIGSEGV rc 139** | **[R-M13]** |
| 2 | `sens … ac` while the solver is `klu` | SIGSEGV; `dc` mode is safe | **[R-M14]** |
| 3 | any sweep with `lin` and points = 2 | silently yields **one** point | **[R-M18]** |
| 4 | `sp` with fewer than two ports **after** the Ports table's `alter` lines | `controlled_exit(1)` kills the process and every later analysis with it | `span.c:376-386` |
| 5 | an enabled analysis whose `type` is not in the registry | today: rc 0, a raw written, nothing happened, box still ticked | F2 |
| 6 | an enabled analysis missing a `required` field | `render_deck`'s bare `dict get` raises a raw Tcl error mid-run | ase-state §3.4 |
| 7 | two `.sens` **dot cards** | rc 134, `malloc(): unsorted double linked list corrupted` | [crit §D5] — n/a on our route, recorded so nobody adds a card path |
| 8 | any pre-deck option while `-n` is in force | silently ignored, 4700 → 1e-12, no message | **[R-M17]** |
| 9 | `.options klu` on a deck with a CIDER device | `exit(1)` and every later `.control` command is skipped | builds §2.3 |
| 10 | `.probe alli` on a deck with event nodes | `Error: Dot command '.probe alli' and digital nodes are not compatible`, fatal | xspice §5.5 |
| 11 | `trrandom` on a **current** source | freezes after the first missed timepoint; emit a V source + a VCCS instead | F16 |
| 12 | a bare `@dev` name on any write other than the `op` write | dims=1, one non-zero sample at index 0, silently | decision F / **[R-M4]** |
| 13 | `set norefprint` / `.options norefvalue` while a progress bar is on screen | kills the only progress feed `-b` has | **[R-M8]** |

Items 1, 4, 5 and 9 are `fatal`: checked in the dialog **and** re-checked in `render_deck`, and
item 1 is **not defeasible by `set ase_preflight 0`**.

### 8.3 Dot cards

Still none for analyses (DR13). Three *non-analysis* cards want the slot above `.control`:
`.ic`/`.nodeset` (§6.5), `.probe` (§9.4, refused under XSPICE event nodes) and `.four` (§9.4).
`.meas` is refused with `-r` and is fine as a **command**, so it stays inside `.control` [crit §5.3].
The invariant: **nothing analysis-shaped ever goes in that slot.**

### 8.4 Scalars come from the rawfile, not the log

Today the Outputs Value column is filled by `result_probe` parsing `<expr> = <number>` out of
`print` output, anchored on `op` because a multi-point `print` emits a 20,514-row table that yields
nothing (issue 1243). Every scalar an analysis produces is **a one-point plot in the rawfile**:
`Operating Point`, `Integrated Noise`, `Transfer Function`, `Sensitivity Analysis` (dc mode). Reading
them from the raw (a) removes `result_probe`'s case-folding ladder, (b) gives NOISE, TF and SENS a
scalar home the current rule denies them, and (c) is what UX Stage F2 already proposed for another
reason. ⚖ **R3, and the ruling must be posed with its cost**: arbitrary user-typed *expressions*
(`v(a)*2`) are the only thing that column holds today and they are **not** vectors in the raw. The
honest shape is *both* — rawfile vectors for named scalars, `print` for expressions — and R3 asks
whether that split is acceptable.

⚠ **TF's vector names are not what any design wrote.** Measured spellings are `v1#Input_impedance`
and `output_impedance_at_V(b)` — with a capital `V` — so a probe keyed on `Input_impedance` /
`output_impedance_at_<node>` finds nothing. The registry carries the measured spelling.

### 8.5 Transport — `-b` now, `-p` next, `libngspice` refused

| | `-b` batch (today) | `-p` pipe | `libngspice` |
|---|---|---|---|
| abort | SIGKILL only; SIGINT is rc 130 with **nothing written** (no handlers in batch) | SIGINT **pauses in < 5 ms**; partial results intact (388 MB raw written after a stop); `resume` continues; `quit` rc 0 | `bg_halt` 10 ms — **but it wedges on `disto` and on `sens`** |
| progress | ⚠ **yes** — ` Reference value : <scale>\r`, ~4 Hz, stdout, covers tran/dc/ac/noise/disto/sp | the same ticker | `SendStat` per analysis — but **op, noise, disto, pz, tf, sens emit nothing at all** |
| pre-deck options | `.spiceinit` + `-D` (two doors, four traps) | **`set` before `source`** — one door, no file, no shadowing | one door |
| crash blast radius | the child dies; xschem lives | the child dies; xschem lives | **xschem dies** — measured: F7's `.disto` NULL-deref killed the host at rc 139 |
| deployment | any ngspice the user has | any ngspice the user has | ships and ABI-pins `libngspice.so.0`, sets `SPICE_LIB_DIR`, adds Tcl↔C FFI to a 19.4k-line pure-Tcl codebase |
| exists today | yes, `run_cmd` pinned by goldens | no | no shared build on this machine |

**Position: define ONE internal run interface — start, progress event, abort, results-located — with
`-b` as its first implementation this pass and `-p` as a named later stage. Refuse `libngspice`.**
The decisive rows are the crash blast radius (this design's entire L2 layer exists because a stale
name in an Outputs pane makes ngspice segfault) and `ngSpice_Circ`-after-`ngSpice_Reset`, which
SEGFAULTs because `Reset` is a full teardown and `ngSpice_Circ` lacks the `is_initialized` guard
`ngSpice_Command` has — the exact recurring bug class ngspice's own `CLAUDE.md` names. ⚖ **R1** asks
whether `-p` comes *now* instead, because `builds.md` recommends exactly that and it is a genuine
disagreement with design B.

**And a better abort exists that needs no transport change at all**: §10.1's shard runner. One
process per point means Stop kills the current shard, every completed shard survives on disk, and
progress is `k/N` with nothing to parse.

---

## 9. S6 — results

Decisions B and C say the Value column holds **a scalar and nothing else**. Every analysis therefore
needs a named destination, and "the waveform viewer" is not an answer for six of them.

### 9.1 The routing table

| analysis | plot (`Plotname:` literal) | destination | label shown |
|---|---|---|---|
| OP | `Operating Point` | Value column (1-point plot) + the existing canvas annotation | *Operating point* |
| DC | `DC transfer characteristic` | viewer; the scale is `v-sweep`/`i-sweep`/`temp-sweep`/`res-sweep` and the axis label follows it | *DC sweep* |
| TRAN | `Transient Analysis` (+ `… (linearized)`) | viewer | *Transient* |
| AC | `AC Analysis` | viewer | *AC response* |
| NOISE | `Noise Spectral Density Curves*` | viewer | *Noise — spectral density* |
| NOISE | `Integrated Noise*` | **Value column** (1 point) | *Noise — integrated* |
| NOISE (`contributors`) | per-device vectors **inside** the spectrum plot | **Result Table** | *Noise contributions* |
| TF | `Transfer Function` (3 vectors, 1 point) | **Value column** ×3 | *Transfer function / Input impedance / Output impedance* |
| PZ | `Pole-Zero Analysis` (complex, no scale) | **Result Table** (Re, Im, f, Q) + an s-plane scatter | *Poles and zeros* |
| DISTO | `DISTORTION - 2nd harmonic` / `- 3rd harmonic`, or the three IM literals | viewer, one trace group per plot, **named by the literal** | *Distortion — 2nd harmonic* … |
| SENS (dc) | `Sensitivity Analysis`, real, 1 point, ~90 vectors | **Result Table**, sorted by \|value\|, with a normalised column | *Sensitivity* |
| SENS (ac) | `Sensitivity Analysis`, complex, `frequency` scale | viewer | *Sensitivity vs frequency* |
| SP | `SP Analysis` | viewer + **S-parameter surface** (matrix picker, Smith/polar, `wrs2p`) | *S-parameters* |
| PSS | `Time Domain …` / `Frequency Domain …` | viewer (TD) + **Result Table** (FD harmonics, `plot=1` = stem hint) | *PSS — time domain / harmonics* |
| `.four` | `fourierMN` 2-D vectors + `thdMN` | **Result Table** (harmonic, magnitude, phase, % of fundamental) + THD as a Value scalar | *Fourier* |
| `fft`/`spec` | `Spectrum` | viewer | *Spectrum* |
| `psd` | `PSD` | viewer | *Power spectral density* |
| `meas` | one length-1 vector each | **Value column** | the measurement's own name |
| event nodes | `<cell>_ase_evt.vcd` | the **existing VCD pipeline** — digital pane | *Digital* |

**⚠ Two plots, one literal — the discriminator.** **[R-M11]**: `sens … dc` and `sens … ac` both
write `Sensitivity Analysis`, and two rows of one type collide the same way. Matching on the literal
alone **does not survive**. The join is therefore **positional on creation order**: the plotmap
sidecar's line *k* corresponds to the rawfile's `Plotname:` record *k*, and the sidecar carries the
`<type> <id>` that produced it (DR16). The literal remains the *label*; the sidecar is the *identity*.

**⚠ `AC Operating Point` reads back as `op`.** xschem's `read_dataset` matches `strstr(lowerline,
"operating point")` before the AC arm (CODE-HERE, `src/save.c`), so a `keepopinfo` OP plot from an
AC, NOISE, PZ, TF, DISTO or SP run attaches with `sim_type = op` and collides with the real
operating point. The registry's `role opinfo` plots are therefore **not** handed to `xschem raw read`
with `op`; they are read for their vectors and labelled from the sidecar.

**Four new tables are ONE thing.** Poles & Zeros, Sensitivity, Noise contributions, the S-matrix,
Fourier harmonics and campaign runs are all a **sortable scalar grid with a copy action**.
`ase::ui::listdlg` is already config-driven (`ttk::treeview`, `cols`/`heads` from a config dict —
CODE-HERE), but it is an **editor** whose rows come from session state; a read-only, sortable
`ase::ui::resulttable` sharing its column policy and theming is the honest estimate. Six bespoke
panes would be six half-finished panes.

**⚠ The noise contributor table has three naming hazards** and a table that sums them without all
three gets the wrong answer: two conventions coexist (`onoise_total_<inst>_<mech>` with underscores
for most devices, `onoise.<inst>.<mech>` with dots for the BSIM3/4/SOI/HiSIM family); the
**empty-suffix** entry is the device *total*, so a naive sum double-counts; and OSDI emits
`onoise_total_<inst>` **with a trailing space**.

### 9.2 The plotmap sidecar

```
PLOT noise n1 |Integrated Noise|
PLOT noise n1 |Noise Spectral Density Curves|
PLOT op o1 |Operating Point|
```
**[R-M1]**, measured. `<type>` and `<id>` are what ASE-L wrote; `$curplotname` is ngspice's own
literal. No counter guessing, no string building, no assumption that `noise1` means anything. For a
campaign the generator appends the axis coordinates to the same line
(`PLOT ac a1 |AC Analysis| rload=1000 temp=27`), which is exactly how four identically-named
`AC Analysis` plots become a labelled family.

### 9.3 Post-run reconciliation — the safety net for the walk

After every run, before attaching: compare the rawfile's `Plotname:` list against the union of the
enabled rows' `plots` predictions, using the header parser `ase::cap_raw_plots` already has.

* **prediction == reality** → attach, label from the sidecar.
* **over-count** (a duplicate, or a trailing `constants`) → attach, drop the duplicate, and log
  *"this run captured N plots where the registry expected M; the extra ones were ignored."*
  **[R-M3]** proves this degrades and does not destroy.
* **under-count** → attach what is there and log *"one plot of the `<type>` analysis was not
  captured"*, naming the type. This is the case that used to be silent.

### 9.4 THE MEASUREMENT SURFACE — new, and it is the biggest gap in all three designs

ASE-L has **zero** measurement support today: `grep -c '\bmeas\b' src/ase.tcl` returns **0**
(CODE-HERE). All three designs gave `.meas` one results-routing row and no form, no grammar, no
stage. Two of the six ADE tasks — *read back the phase margin* and *the spread of one measurement
over 200 Monte Carlo runs* — end at "you are on your own". That is the bar the design opened by
condemning, so it is designed here.

**A `measurements` list beside `outputs`, one row per measurement**, edited in a Measurements
sub-dialog and emitted as `meas` **commands** inside `.control`, immediately after the analysis they
read:

```tcl
# a measurement row -- an open dict, same discipline as an analysis row
{name pm  analysis ac  id a1  kind param
 expr {180 + vp(out)[i_at_ugf]}  unit deg}
{name f3db analysis ac id a1 kind when
 target {vdb(out)} value -3.0103 dir fall}
{name gain analysis ac id a1 kind max target {vdb(out)}}
{name tr   analysis tran id t1 kind trigtarg
 trig {v(out)} trigval 0.1 trigdir rise
 targ {v(out)} targval 0.9 targdir rise}
{name irms analysis tran id t1 kind rms target {i(vdd)} from 1u to 10u}
```

emitting, per `measure.md`'s grammar:
```
meas ac  f3db when vdb(out)=-3.0103 fall=1
meas ac  gain max vdb(out)
meas tran tr  trig v(out) val=0.1 rise=1 targ v(out) val=0.9 rise=1
meas tran irms rms i(vdd) from=1u to=10u
```

The `kind` vocabulary is `measure.md`'s: `trigtarg` (delay), `find`/`when`, `avg`/`rms`/`min`/`max`/
`pp`/`integ`, `deriv`, `param`. Every kind is one form shape; the expression fields accept
`par('…')`. **Four grammar traps the form must encode**, all from `measure.md`: `expr=` is broken
(refused); `param=` is one-shot per session (refused when the same circuit is re-run in one
process — which the shard runner never does); `.meas` **dot cards are refused under `-r`** so we use
the command; and the created vector carries only **7 significant digits** (`"%e"` at
`measure.c:138`), so when full precision matters the GUI redirects `meas … > file` and parses the
printed line.

**⚠ And the one nobody caught: `set units=degrees` is mandatory** (DR27, **[R-M10]**). A phase
margin computed from `vp()` without it is wrong by 57.2958×. The Measurements dialog emits it
automatically the moment any row's expression mentions `vp`, `ph`, `cph` or `phase`, and says so in
the preview.

**Derived analog answers that ship as named templates** (the user picks one and fills two fields —
this is what "better than ADE-L" means for the daily task):

| template | emits |
|---|---|
| DC gain | `meas ac gain max vdb(out)` |
| −3 dB bandwidth | `meas ac f3db when vdb(out)=<gain-3.0103> fall=1` |
| Unity-gain frequency | `meas ac ugf when vdb(out)=0 fall=1` |
| **Phase margin** | `set units=degrees` + `meas ac ugf when vdb(out)=0 fall=1` + `meas ac pm find vp(out) when vdb(out)=0` + `let pm = 180 + pm` |
| Gain margin | `meas ac gm find vdb(out) when vp(out)=-180` |
| Slew rate | `meas tran sr trig v(out) val=<10%> rise=1 targ v(out) val=<90%> rise=1` |
| Settling time | `meas tran ts when v(out)=<final±tol> cross=last` |
| THD | `.four <f0> v(out)` card + `thd1` read from the Result Table |

**`.four` / `fft` / `spec` / `psd` / `linearize` get producers, not only destinations.** `.four` is a
**card** in §8.1's slot (its `fourierMN` 2-D vectors and `thdMN` scalar already exist and are today
only printed as text). `fft`/`spec`/`psd` are **commands** after the transient, and each writes a
new plot whose literal is `Spectrum`, `Spectrum` and `PSD` respectively — ⚠ **not** `spectrum` as
`outputs.md` §3 says, and the typename is `spN`, not `spectN`, because `ft_plotabbrev()` returns the
first substring match and `sp` shadows `spect` [crit §C4]. `linearize` writes
`<old> (linearized)`. All four are captured by the same walk and named by the same sidecar.

### 9.5 Event-driven results — the digital half

⚠ New, from **[R-M6]**, and absent from all three designs. XSPICE is **on by default in this
build**, so a mixed-signal deck is an ordinary deck.

* **Inventory**: `edisplay` prints `din : d , 7` / `dout : d , 7` — the event nodes in the current
  plot, machine-readable, no netlist parsing. It is also the check that decides whether any of this
  is emitted at all.
* **Transport**: `eprvcd <nodes> > <cell>_ase_evt.vcd` writes a **valid VCD**. The rawfile is *not*
  a viable transport — `write raw all` silently omits event nodes, and naming them explicitly
  produces vectors declared `dims=10` while `No. Points: 119`, zero-padded and not truncated on read
  [xspice §7.6].
* **Attach**: ASE-L already has a complete VCD pipeline — `ase::cosim_map` computes per-model VCD
  paths, `ase::last_vcdfiles` serves them, `ase::attach_dbs {rawfile sim_type {vcdfiles {}}}` takes
  them (CODE-HERE). The event VCD joins that list. **This is one emitted line and one list append.**
* **Two cautions the analyses pane owes a mixed deck**: `trtol` is **silently forced to 1** whenever
  event nodes exist (`xspice.md` §5.1), which changes numbers and belongs in the `caution`
  vocabulary; and the DC-sweep + auto-bridge failure has a reproducer and no root cause, so `dc` on
  a deck with event nodes is `caution`, not `ok` (§5.2's `mixed_events` rule).
* **Refused**: `.probe alli` on such a deck (fatal, §8.2 item 10) and `snsave`/`snload`.

---

## 10. S7 — beyond ADE-L

### 10.1 Campaigns — sweeps, corners, Monte Carlo

F10: ngspice has no `.step` and no corner construct; `.dc` nests exactly twice and sweeps only
R / V / I / `temp`; nested sweeps come back **flattened with no `Dimensions:` header**. So the GUI
generates the campaign, and being a good code generator is the job.

**The design-variable mechanism, measured.** `.param rv = 'var(myres)'` in the deck plus
`set myres = 4700` in `<rundir>/.spiceinit` gives `@r1[resistance] = 4700` **with the process cwd
somewhere else entirely** (**[R-M17]**). The schematic is untouched (F13's founding doctrine), the
deck is **byte-identical between shards**, and the only thing that varies is a two-line file.
ASE-L already renders `.param <name>=<value>` from its `variables` state key, so for a variable ASE-L
itself rendered, `alterparam <name> = <v>` + `reset` is the cheaper primitive and `var()` is the
fallback for a value ASE-L did not render (a number inside a subcircuit or a `.lib`).

**Architecture: one process per point.**

```
campaign/
  deck.spice                 <- ONE deck, byte-identical for every shard
  shard-0001/.spiceinit      <- set myres=4700 / set ase_temp=27 / set mc_vth=0.71
  shard-0001/<cell>_ase.raw
  shard-0001/<cell>_ase.plotmap
  shard-0002/…
  index.tsv                  <- shard | axis coordinates | exit code | raw path
                             |  + ONE COLUMN PER MEASUREMENT (§9.4)
```

| | shard runner | one process, a `.control` loop |
|---|---|---|
| abort | kill the current shard; **every completed shard survives** | Ctrl-C is timing-dependent and the user cannot tell which happened |
| an interrupted run | its shard has a non-zero exit code | leaves `sim_status = 0` — **indistinguishable from success** |
| progress | `k/N`, free | a generated `echo` the GUI must parse |
| the deck | one artifact, reviewable, diffable, hand-runnable | a generated loop nobody can read |
| results | one raw per point; the family is a directory | one raw with N plots, or a hand-built collector with the default-scale trap |
| parallelism | trivially available later | none |
| cost | N process starts + N parses | N parses (`reset`) or none (`alter`) |

⚠ **The honest counter-row**: `alter`/`altermod` avoid the re-parse and are ~10× cheaper per run on
a big PDK deck. So **`alter`-only axes may be collapsed into one shard**, and the runner **says which
mode it chose** in the run log.

**Axis kinds:**

| kind | realisation |
|---|---|
| design variable | `.param x='var(ase_x)'` + `set ase_x=<v>` per shard, or `alterparam x = <v>` + `reset` when ASE-L rendered the `.param` |
| instance parameter | `alter <flat> <param>=<v>` — no re-parse, same shard |
| model parameter | `altermod @<model>[<p>]=<v>` — same |
| temperature | ⚠ **`temp` is not a `.param`.** Uniform step and the analysis is OP/DC → collapse to `dc … temp a b s` (**[R-M12]**). Otherwise **`.options temp=<v>` re-rendered per shard** (an OPTtbl `IF_REAL` keyword, §3.6) — the campaign never uses `set temp` |
| corner | **re-render the deck** with a different `.lib <file> <section>` row. ASE-L already emits `.lib` rows per `models` entry; a corner is a named set of model rows + variable overrides + a temperature. `.lib` section selection happens at parse time and cannot be `alter`ed, so corners always shard |
| statistical | the GUI draws the samples in Tcl and writes them per shard |

**Monte Carlo: the GUI is the random number generator.** Not `agauss` in the netlist and not
`sgauss` in the control language. Reasons, all measured by others: ngspice's seeding has two serious
traps and three routes of which one silently does nothing; a model-level draw was *proven* to change
between runs of the same migrated state (issue 0210); and F16 records that transient white and 1/f
noise are **irreproducible under every seed control** because the Wallace pool is seeded from
`getpid()`. When the GUI draws, the sample set is reproducible, inspectable, exportable, re-runnable
point by point, and **is a column in `index.tsv`**. ADE-L cannot show you its samples.

**And the campaign ends with a NUMBER, not a directory.** `index.tsv` carries one column per
`measurements` row (§9.4), and the campaign's Result Table offers **histogram, mean, sigma, min/max,
yield against a spec limit, and a scatter of any two columns** — statistics computed **in Tcl**,
because ngspice has no sort, no median, no percentile and no histogram. That closes the gap the UX
judge called "one step before the number I opened it for".

**Generator rules, each with its measured reason** (a first implementation falls into every one of
these):

| rule | reason |
|---|---|
| re-emit `save` after every `reset` | the save list does not survive a re-parse; the shipped ngspice examples get this wrong |
| name the collector: `setplot new aselres "ASE-L results" aseldata` | a bare `setplot new` gives `unknown1`/`Anonymous` |
| never compare strings in `.control` | **[B-M5]** — both `eq` and `ne` take the false branch |
| never put `.` `-` `(` `[` in a generated variable name | `$` substitution swallows them — and **[R-M19]** `set wl = "$wl $p.all"` produced `p.all: no such variable`, measured here |
| `set x = "$&vec"` to move a vector value into a shell variable | `$&vec` alone loses precision |
| statistics in Tcl, never in the deck | ngspice has no sort/median/percentile/histogram |
| `setseed <n>` once, and say what it does **not** reproduce | white and 1/f transient noise are `getpid()`-seeded; RTS and `trrandom` are reproducible |
| filter `Reset re-loads circuit <title>` from stdout | printed on every `reset` (`inp.c:551`) |

### 10.2 Six picks from F14

A design that lists all seventeen has chosen nothing.

**Pick 1 — `CKTncDump`'s starred nodes, highlighted on the canvas.** After a failed operating point
ngspice prints a `Last Node Voltages` table with a trailing ` *` on **every node that still fails
the convergence test** (`cktncdump.c:11-43`). `convergence.md` calls it "the single most useful
diagnostic in ngspice" and nobody has ever put a UI on it. Parse it, map the names through
`ase::netlist_map`'s existing hierarchy-qualified resolution, **highlight those nets on the
schematic**. Every piece exists; it needs no ngspice change; ADE-L gives you an opaque `sim.log`.
**Biggest win per line of code in the entire evidence base.**

**Pick 2 — the convergence ladder pane + the remedy assistant + `optran`.** §7.7. Pick 1 says
*where*; pick 2 says *what to do*; and `optran` — on by default, superseding `noopiter`/`gminsteps`/
`srcsteps`, silently deciding the accuracy of every fallback operating point, never seen by any
ngspice user — finally becomes visible.

**Pick 3 — the `.sens` parameter picker, computed offline.** §6.4. ADE-L has no sensitivity analysis
at all; this is the cheapest place to be plainly ahead.

**Pick 4 — `wrnodev`, i.e. save/restore of a DC solution.** §6.5. ADE parity that ASE-L lacks
entirely, and the fastest fix for a bench that takes four minutes to find its operating point.

**Pick 5 — transient noise and `trrandom`.** §10.3. ADE-L has no transient-noise feature at all.

**Pick 6 — `.probe` power probing.** `.probe p(XU1)` yields a `xu1:power` vector and **works in
every analysis including AC**, unlike `savecurrents`. A "power" column in the Outputs pane, nearly
free. ⚠ Refused on a deck with event nodes for the `alli` form (§8.2 item 10).

**Refused from F14, with reasons:** `iplot` and `stop`/`resume`/`step` (need interactive or `-p` —
they are the pipe transport's first customers, R1); `speedcheck`/`deltacheck` (need `set ngdebug`,
which floods the log — kept as a one-line run-health strip instead); `diff` (real, but its
regression feature has no owner in this batch); `rusage devtimes` / `tranpoints accept rejected`
(kept as one line in a run-health strip, not a pane); `--soa-log` (ships *with* the options stage,
because `warn` is a two-door feature — a `.options` value **and** a command-line flag, and emitting
one without the other leaves the log empty); the Calculator's `group_delay`/`cph`/`mtimeavg`
vocabulary (its own spec, its own owner).

### 10.3 Transient noise AND `trrandom`

Both are `IF_REALVEC` instance parameters on **both** `vsrc` and `isrc` — the manual's "isrc not yet
available" is wrong here, measured — documented nowhere in-tree. They belong on the **Tran form** as
a collapsible section: they are a simulation setting, not a source property, and F13's founding
doctrine forbids putting them on the schematic.

**Two injection routes, neither touching the schematic:**
1. `alter <src> trnoise = [ 10m 1u 0 0 ]` on an existing DC-only source — the GUI knows which
   sources it drives and greys out the ones carrying a stimulus (trap T5: the stimulus is replaced);
2. a parallel current source added by `render_deck` in a slot right after the netlist:
   `ase_inoise_1 0 out dc 0 trnoise(1m 1u 1 0.1m 5m 18u 30u)` — validated against
   `netlist_map_resolve` first.

**The form**, one row per noisy source:

| field | meaning | validation |
|---|---|---|
| NA | white-noise amplitude | density = `NA*sqrt(2*TS)` V/√Hz — **shown as a derived readout** |
| TS | **the timestep**, not `tstep` | > 0. ⚠ **a negative TS HANGS ngspice**. Points ≈ `5*tstop/TS` — shown as a derived readout with an estimated file size |
| NALPHA | 1/f exponent | **strictly 0 < NALPHA < 2**; NALPHA = 2 is a silent zero |
| NAMP | 1/f amplitude | ≥ 0 |
| RTSAM / RTSCAPT / RTSEMT | RTS amplitude / mean-low time / mean-high time | ≥ 0 |

**All seven `trnoise` arguments and all five `trrandom` arguments are emitted, always, positionally,
padded with 0.** Short forms are a heap read and a silent zero, and two shipped ngspice examples get
them wrong. (⚠ `trnoise.md` §10.3 says to omit args 5-7 when RTS is off; `builds`-era measurement
found padding benign — stddev 8.59e-4 unpadded vs 8.65e-4 padded, no DC offset — so **pad**, and the
correction is recorded in §12.)

**`trrandom` gets equal billing**, because F16 says so and every design half-covered it: five
distributions (`1` uniform, `2` gaussian, `3` exponential, `4` poisson) with `TYPE TS TD PARAM1
PARAM2`, its own row kind in the same table, the same derived readouts, and two refusals — on a
**current** source it freezes after the first missed timepoint (emit a V source + a VCCS instead,
§8.2 item 11), and under an `optran` fallback operating point it **pollutes the OP**, so the section
warns when rung 4 is armed. The `notrnoise` kill switch (`miscvars.c:98`, `1-f-code.c:122`) is a
catalogue row.

**And one sentence, on screen, worth more than the whole manual on the subject:**
*"White and 1/f noise are not reproducible in this build — the generator is seeded from the process
id."*

---

## 11. Worked example — NOISE, form to plot and back

**11.1 The form.** The user picks `Noise` in the type grid. `chana_show` destroys `.form` and
rebuilds it from `fields`:

```
Enable  ☑
Output            [ v(out)        ] [Pick]     <- nodepair, select_on_design
Reference         [               ] [Pick]        (blank means ground)
Input source      [ v1        ▾   ] [Pick]     <- combobox FILTERED to {V,I} sources
                                                  that carry an ac value
Sweep type        [ Decade    ▾   ]
Points per decade [ 10            ]            <- label minted by `relabels`
Start frequency   [ 1        ] Hz
Stop frequency    [ 1meg     ] Hz
 ▸ Advanced
   ☐ Per-device contributor table
   ☐ Report as V²/Hz (sqrnoise)                <- a per-analysis OPTION, not a field
   61 points · Integrated Noise will be produced
```

The last line is a derived readout computed with the same arithmetic `noisean.c:145-168` uses
(6 decades × 10 + 1 = 61), plus the note that a single-frequency run would produce **no** Integrated
Noise plot. Nothing in ADE-L tells you that.

**11.2 The preconditions.** `needs {ac_source input_source_ac output_node_resolves noise_devices}`.
`netlist_facts` reports `v1` has `ac 1` → `ok`. If it did not, the banner would read *"`v1` has no
AC value — a noise analysis needs an AC input source (`ac 1` on the source, any magnitude)"*, which
is the exact remedy for `E_NOACINPUT`, offered **before** the run instead of after it.
`noise_devices` reports 11 of 14 families contribute noise → `caution`: *"3 devices contribute no
noise: `e1`, `g2` (behavioural sources are noiseless), `t1` (transmission line)"*. That is
`cider-devices.md`'s silent-zeros trap turned into a fact the user knows before misreading a plot.

**11.3 The state.** One row, merged over defaults, **no schema change, no version bump**, absent keys
absent, so all 105 committed files keep round-tripping:

```tcl
analyses {{type op enabled 1}
          {type dc enabled 0}
          {type ac enabled 0}
          {type tran enabled 1 step 10n stop 200u}
          {type noise enabled 1 id n1 output v(out) source v1
           sweep dec points 10 start 1 stop 1meg}}
```

**11.4 The deck.** `noise` is multi-plot with `start != stop`, so `nplots = 2`; `emitorder 40` puts
it before `op` (DR15):

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
remzerovec
echo "PLOT noise n1 |$curplotname|" >> /…/tb_ase.plotmap
write /…/tb_ase.raw
setplot previous
remzerovec
echo "PLOT noise n1 |$curplotname|" >> /…/tb_ase.plotmap
write /…/tb_ase.raw
save @m.xi1.m1[gm]                      ; optier_ctl, immediately before op
op
if $?sim_status = 0
  …the same guard…
end
remzerovec
echo "PLOT op o1 |$curplotname|" >> /…/tb_ase.plotmap
write /…/tb_ase.raw all @m.xi1.m1[gm]
print v(out)
option  > /…/tb_ase.effective
set    >> /…/tb_ase.effective
.endc
```

Three things to notice. `save v(out)` is validated against the netlist **before** it is emitted
(`saves_resolve`) — the **[R-M13]** mitigation applied to every run, not only to DISTO. The
device-parameter request stays on the **`op` write line**, because **[R-M4]** proves those names are
what create the vectors. And `op` is still last.

**11.5 What comes back.**
```
PLOT noise n1 |Integrated Noise|
PLOT noise n1 |Noise Spectral Density Curves|
PLOT op o1 |Operating Point|
```
and the rawfile's `Plotname:` records in exactly that order — **[R-M1]**, measured. Plot 1 is genuine
data, so `raw_content_verdict` returns `ok 1` and `attach_dbs` attaches. The GUI joins positionally:

* record 1 → `Integrated Noise` → `role scalars` → **Value column**: `onoise_total`, `inoise_total`,
  a one-point real plot, a legitimate scalar under decision B, labelled *"Noise — integrated"*;
* record 2 → `Noise Spectral Density Curves` → `role spectrum` → the **viewer**, trace group
  *"Noise — spectral density"*, vectors `onoise_spectrum` / `inoise_spectrum`, y-unit V/√Hz — or
  V²/Hz if `sqrnoise` is on, and the GUI knows which because it emitted the option;
* record 3 → the operating point, canvas annotation, unchanged.

**Today, this same state renders a `.control` block with no analysis in it at all**, exits 0, writes
an empty raw, and shows a ticked Enable box beside `output=v(out) source=v1 …` in the Arguments
column. That is the distance this design closes.

**11.6 Back into the GUI.** Reopening Choose Analyses rebuilds the form from the state row through
the registry. **No round trip through ngspice, ever** (DR25).

---

## 12. CORRECTIONS — claims from the three designs that did not survive checking

Every entry was checked by me, in this tree or against this binary. **ACCEPTED** = the judge's
finding is real and is repaired above. **REJECTED** = the finding is wrong and the design stands.
**CORRECTED** = the design was wrong and the judge did not catch it.

### C1 — ACCEPTED, and it is the largest single repair. Design B's writer produces a rawfile ASE-L rejects.

`[B-D16]`'s mode B (F6's `foreach p $plots` capture loop) writes `constants` **first**. **[R-M2]**:
`Title: Constant values` / `Plotname: constants` / `No. Variables: 12` / `No. Points: 1` / `Date` ==
the build stamp — all four markers `ase::raw_content_verdict` (CODE-HERE) treats as decisive. It
returns `ok 0` and `ase::attach_dbs` echoes `NOT ATTACHED … the analysis did not run`. The same proc
explicitly *tolerates* a `constants` plot **appended behind** real data. `destroy const` before the
loop is refused outright (`Error: can't destroy the constant plot`) and `$plots` is unchanged, and
`.control` cannot filter on a string (**[B-M5]**). **Repair: DR16 adopts `[A-P12]`'s `setplot
previous` walk instead** — measured **[R-M1]**: first plot genuine, both NOISE plots captured, `op`
write untouched, single-plot emission byte-identical.

### C2 — ACCEPTED. `ase::netlist_map_resolve` is NOT "built and unused".

Design B calls it built-and-unused and calls `saves_resolve` "the single most valuable thing L2
buys". CODE-HERE: `ase::preflight_scan` calls it per output identifier and `ase::preflight_gate`
**already REFUSES** a run whose saved output names do not resolve — case-mode aware, with repair
suggestions, wired ahead of any deck write. B inherited a dossier assertion without checking it.
**Repair:** §3.5 restates what is genuinely new — the same check on **analysis form fields**, the
`k=v` facts `netlist_map` discards, and the disto cross-rule made **non-defeasible** by
`set ase_preflight 0`.

### C3 — REJECTED. Design A's self-declared "sharpest hole" does not exist.

A's Risk 2 asserts `ase::run_existing` "never calls `render_deck`", so P14/P15 and every precheck
are absent on that path. CODE-HERE: `run_existing` ends in `return [ase::run_deck $state $nl …]`,
and `run_deck`'s own header reads *"render deck from `netlistfile` → `<rundir>/<cell>_ase.spice`"*.
It skips **netlisting**, not deck rendering. A future session would have spent a stage plugging a
hole that is not there.

### C4 — CORRECTED. `-b` is not progress-blind, and all three designs say it is.

**[R-M8]**: `tran 10n 20m` under plain `-b` printed **8** ` Reference value : <scale>\r` records on
stdout. `outitf.c` has five such sites, ~4 Hz of CPU, no newline. The GUI wrote `tstop`, so
`refvalue/tstop` is a percentage — for tran, dc, ac, noise, disto and sp, i.e. **wider coverage than
libngspice's `SendStat`**, which emits nothing at all for op, noise, disto, pz, tf and sens
[builds §3.1, §3.2]. Design B's transport table row "progress: none" for `-b` **and** `-p` is wrong,
and it was one of the arguments for libngspice.

### C5 — CORRECTED. `.spiceinit` chaining by `source` does not work.

B's D19 and its measurement debt M4 propose `source <user's ~/.spiceinit>` from inside the generated
file. **[R-M7]**: ngspice parses the target as a **netlist** (`Circuit: set frobnicate`,
`Unable to find definition of model`) and the user's variables are lost. **Copying the user's lines
in works perfectly** — ours and theirs both live. **Repair: DR19 copies.** M4 is closed, by
measurement, not deferred.

### C6 — ACCEPTED, and it dissolves a ruling. `[B-R6]` need never be asked.

**[R-M4]**: `write raw all @m1[gm] @m1[id] @m1[vdsat]` produces those three device vectors;
`setplot op1` + `write raw all` produces **zero**. The names on the write line are the **generator**,
not a filter. Any capture change that removes the per-analysis `op` write destroys the device-OP
tier, which rows E5/M1 exist to pin. The `setplot previous` walk leaves that line exactly as it is,
so **there is no downgrade to rule on.**

### C7 — ACCEPTED. Design C's single `class opt` arm is F3 inside its own antidote.

`ase::opt_emit`'s `opt` arm returns a bare `.options <name>` whenever the value is `{}` or `1`, and
nothing when it is 0. CODE-HERE, `cktsopt.c`: OPTtbl mixes `IF_FLAG` with `IF_INTEGER`
(`itl4:294`, `srcsteps:297`, `gminsteps:298`, `maxord:314`) and `IF_REAL` (`trtol:285`, `temp:290`).
`.options gminsteps=0` — disable gmin stepping — is a real setting; under C's proc the dialog shows
0, the deck contains **nothing**, and gmin stepping runs at 10. **Repair: DR23 splits the OPTtbl
half into `optflag`/`optint`/`optreal`/`optstring`.**

### C8 — CORRECTED, against design C. The DISTO refusal must be narrower than C proposed.

C's R2 refuses "`disto` enabled AND zero saved outputs", citing a **dot-card** deck — a shape C7
itself forbids the GUI from generating. **[R-M13]**: `disto` + `op` inside `.control` with **no save
at all** returns **rc 0**. C's rule would refuse a deck that works, and the tree's own rule is that
pre-flight "is the only one that can be wrong in the expensive direction". **The true trigger is a
save list that resolves to nothing.**

### C9 — ACCEPTED, all three designs. Phase is in RADIANS.

**[R-M10]**: `vp()` = -4.96729e-04 where `set units=degrees` gives -2.84605e-02. Every design routes
a phase margin to the Value column; none says this. A generated PM is wrong by 57.2958×.
**Repair: DR27** makes `set units=degrees` mandatory whenever a phase is measured or plotted.

### C10 — ACCEPTED. Two analyses share one `Plotname:` literal.

**[R-M11]**: `sens … dc` and `sens … ac` both report `Sensitivity Analysis`; `$plots` shows
`sens1 sens2`. Design B asserts that matching on the literal "is the only shape that survives" and
routes the two to different destinations. It does not survive, and it does not survive two rows of
one type either. **Repair: the join is positional on creation order through the sidecar (DR16, §9.2);
the literal is the label, not the identity.**

### C11 — ACCEPTED. SP was blocked where two emitted lines enable it.

**[R-M5]**: `alter v1 portnum = 1` / `alter v1 z0 = 50` on **ordinary** V sources makes `sp` run and
return a correct `s_1_1`. Design B makes `two_ports` a `fatal` precondition with no route to satisfy
it — contradicting its own second pillar ("ADE-L cannot do this because Spectre owns the netlist;
ASE-L generates the netlist"). It generates the `.control` block too. **Repair: §6.6's Ports table.**

### C12 — ACCEPTED. There was no measurement surface anywhere in any design.

`grep -c '\bmeas\b' src/ase.tcl` = **0** (CODE-HERE). All three designs gave `.meas` a results row
and nothing else; `.four`, `fft`, `spec`, `psd` and `linearize` got destinations with **no
producers**; `interp` appears zero times in A and B. **Repair: §9.4 designs the whole surface, and
Stage 8 ships it.** Without it, two of the six ADE tasks end at "you are on your own".

### C13 — ACCEPTED. Event-driven results were unreachable, and the door was one line away.

XSPICE is **on by default** in this build. `esave`/`eprint`/`eprvcd`/`edisplay` appear zero times in
design B, and its entire results architecture is the rawfile. **[R-M6]** shows the fix is trivial:
`edisplay` inventories the event nodes, `eprvcd <nodes> > f.vcd` writes a valid VCD, and ASE-L
**already has a VCD pipeline**. **Repair: §9.5, DR28.**

### C14 — ACCEPTED. `.ic` / `.nodeset` were absent while `uic` was offered.

"nodeset" appears zero times in design B; `.ic` appears once, as `wrnodev`'s output format. A `uic`
checkbox with no surface for the conditions it consumes is F3 reintroduced in the design's own stage
3. **Repair: §6.5, shipped in the same stage as `uic`.**

### C15 — ACCEPTED. OSDI is invisible to both measurement legs, and DR12 could refuse something that works.

`osdi_add_device` appends OpenVAF devices to `DEVices` at load time (`dev.c:584,608` — CODE-HERE),
so `devhelp` against a **scratch** probe deck cannot see a PDK's Verilog-A devices. Design B's `D12`
phrases `pz_devices` as "no family lacking `DEVpzLoad`" and calls it `blocked`. **Repair: §3.7 —
an unknown family is `caution`, never `blocked`, and the exact leg runs `devhelp` against the user's
own deck.**

### C16 — CORRECTED, against all three. PSS is shippable; the build probes say so.

Every design refused a PSS form on the grounds that nobody had ever run it. `builds.md` §1 built
`--enable-pss` and ran it: 0.91 s and 0.41 s on the two shipped oscillators, both `Convergence
reached`, both within ~1 % of their documented f0, deterministic to the centisecond, two plots with
recorded literals. **Repair: §4 ships it as an explicitly-experimental panel with a hard validator,
⚖ R7** — and the validator's refusals are not optional (`harmonics<2` is a SIGSEGV or an infinite
recursion; `steady_coeff` too small gives a **false** `Convergence reached` 4.5 % wrong; **rc is not
a success signal**).

### C17 — CORRECTED. `oscnode` steers nothing, and A rendered it as a live control.

Design A ships `pss`'s `oscnode` "as a control that does nothing", contradicting its own P20.
`builds.md` §1.7 measured that a **nonexistent** `oscnode` runs normally with no NULL deref
(correcting `an-rf-pss.md` §3.4). **Repair:** the field stays, because the argument list is
positional, and its hint says *"ngspice records this and never reads it"*.

### C18 — ACCEPTED, small but real. The `.form` frame moves widget paths.

Design B says "adding widget paths is safe and moving them is not" and then relocates `$w.step` /
`$w.stop` into `$w.form`, which five lines of `test_ase_dialogs.tcl` drive by path — while billing
stage 1 as "no suites move". **Repair: §6.1 states it and Stage 1 owns the move.**

### C19 — ACCEPTED. `ase::rundir` can be a shared directory.

`ase::rundir` falls back to `set_netlist_dir 0` when the state carries no rundir (CODE-HERE) — a
directory shared by every cell and by xschem's own netlister. B's D19 anticipates only a
user-authored `.spiceinit`. **Repair: DR19 requires an explicit per-session rundir before the
pre-deck class or a campaign may run, and names that in the refusal.**

### C20 — ACCEPTED. `ase::ui::listdlg` is an editor, not a result table.

It is a config-driven `ttk::treeview` whose rows come from session state with Add/Edit/Delete, and
it has no sorting (CODE-HERE). "Four config entries plus one reader each" understates it.
**Repair: §9.1 names a read-only sortable `ase::ui::resulttable` sharing listdlg's column policy.**

### C21 — ACCEPTED. Two procs used in design B's code sketches do not exist.

`ase::ui::chana_path` and `ase::ui::dlg_get`. **Repair:** §3.2 uses `ase::ui::chana_form` and
`ase::ui::form_get`, both new and named as such. Likewise design A's `chana_offered` calls
`ase::sim_caps_have_path` with one argument and reads a 0/1 return as a dict; the real signature is
`{backend path {eargs {}}}` (CODE-HERE).

### C22 — ACCEPTED. The "seven places" is an undercount.

Beyond the seven, `ase::op_param_set` carries a `{op dc}` analysis-type allow-list pinned by
`test_rdw_seam_1245` row G3b, `rdw.tcl` carries the same list, and `xschem.tcl` carries a sim-type
combobox `{dc ac tran op sp spectrum noise constants table}`. Two of those are in the RDW this
design routes per-analysis scalars into. **Repair:** Stage 1's acceptance criterion names all of
them as readers-or-declared-out-of-scope.

### C23 — REJECTED. A curated ~120-row option catalogue is not enough.

Design A proposes "~120 rows to start … not 250: the catalogue's job is to be a CURATED surface".
F15 is explicit that there is **no runtime way to discover a variable's class**, so a variable
omitted from the table is a variable the GUI cannot spell safely — and `interp` (F12's only
uniform-grid switch), `plainwrite`, `noquotesinoutput` and `keep#branch` are exactly the rows a
curator drops. **The catalogue ships all of both catalogues**, with `inert` and `hidden` columns
deciding what is *offered*. Curation is a **view**, not a table.

### C24 — RESOLVED. `sqrnoise` is per-position, and design C contradicted itself three ways.

C's §6.3 calls it "genuinely per-position", §7.3 "genuinely global while set", and R7 rules it
global-only. `noisean.c:242` reads it **at analysis time**, so a `set`/`unset` pair around each noise
row works and R7 forbids something ngspice permits. **Repair: §7.5's set-before / restore-after,
which [R-M15] proves works for the flag class.** No ruling needed.

### C25 — RESOLVED. Pad the `trnoise` argument list.

`trnoise.md` §10.3 says to omit args 5-7 when RTS is off; design C says emit all seven padded with
0 and cites §10.3 while contradicting it. Padding was measured benign (stddev 8.59e-4 unpadded vs
8.65e-4 padded, no DC offset). **Pad** — short forms are a heap read and a silent zero, and two
shipped ngspice examples get them wrong.

### C26 — CORRECTED. TF's vector spellings.

Design C names them `Input_impedance` and `output_impedance_at_<node>`; measured they are
`v1#Input_impedance` and `output_impedance_at_V(b)` — with a capital `V`. A Value-column probe keyed
on C's spelling finds nothing. The registry carries the measured spelling.

### C27 — CORRECTED, carried forward from the critique. Post-processed `Plotname:` literals.

`outputs.md` §3's last three rows are wrong: `fft`/`spec` write `Spectrum` (typename `spN`, not
`spectN`, because `ft_plotabbrev()` returns the first substring match and `sp` shadows `spect`),
`psd` writes `PSD`, and `linearize` writes `<old> (linearized)` — `transient` is the abbreviation
lookup key, never the `Plotname:`. §9.4's producers carry the measured literals.

### C28 — ACCEPTED, cosmetic but in the one place honesty was demonstrated.

Design B's §11.1 mock form shows "41 points" as its flagship derived readout while its own prose
says 61; 61 is right (6 decades × 10 + 1). Fixed in §11.1 here. And B-M6's "with no warning of any
kind" is off by one line: **[R-M17]** confirms the `-n` run **does** print a resistor warning — the
*option* is silent, the *consequence* was not.

### C29 — ACCEPTED, editorial. `.meas` card vs command.

Design A's §8.2 routes `.meas` as a dot card above `.control` and its §9 routes it as the `meas`
command inside it. **Resolved: `.four` and `.probe` are cards; `.meas` is a command** — it is refused
under `-r` and works cleanly as a command [crit §5.3], and §8.3 states the split.

---

## 13. STAGES

Each stage is shippable alone and names what it moves. **Stages 0 and 1 carry no rulings** — this
tree's own sequencing habit.

| # | stage | what it changes | what it unlocks | suites that move | ruling first? |
|---|---|---|---|---|---|
| **0** | **The silent drop dies** | the emit loop iterates the **enabled rows** instead of `$anorder`; a row whose type is not in the registry raises a named error; the same check joins `ase::preflight_gate`; `plot_sim_type` returns `{}` honestly | every later stage's drift announces itself instead of failing silently | **RED first**: a new row asserting that a `{type noise enabled 1}` state today renders a deck with no analysis, rc 0, and says nothing. No existing suite moves | **none** |
| **1** | The registry, byte-identically | `ase::analysis_types` with exactly today's four types; `emit` templates reproducing today's four lines; the radio literal, `anaargs`, `chana_fields`, `anorder`+switch, `plot_sim_type` and `chana_show`'s **five-name destroy list** all become readers; the `.form` child frame | adding a type becomes one registry entry | **acceptance is BYTE-IDENTITY**: deck golden D1, row E12, W1p, the 105 `.state` round trips, the print anchor. ⚠ five path lines of `test_ase_dialogs.tcl` move with `.form` (C18). If byte-identity cannot be met, **the descriptor's shape is wrong and the plan stops here** | **none** |
| **2** | The type list is measured | **[R-M16]**'s probe leg on the existing capability deck (no new run); `analyses_available` + `devices_available`; the four-state wrapping radio grid with reasons and a **Detect** button; the ungated-baseline fallback | honest availability; `sp`/`pss` reachable at all | `test_ase_simcaps_0948` gains rows | **R4** |
| **3** | **The form stops lying** | typed fields for the four types (`tran` `tstart`/`tmax`/`grid`/`uic`, `ac` `lin\|oct\|dec` — killing the dead `dec` —, `dc`'s four sweep kinds and second triple, unit labels, the SI-suffix parser, `relabels`); `dialog_status`; refuse-at-OK; the `x` verbatim hatch; Apply; **§6.5's Initial conditions sub-dialog**, because shipping `uic` without it re-creates F3 | the F3 correctness defect is gone for the four shipped types | G2's display string; `test_ase_persist`'s `arg_summary` rows; deck goldens gain optional tokens | **R5**, R9 |
| **4** | The netlist permits | `ase::netlist_facts`; the `needs` predicates; the `fatal` re-check inside `render_deck`; the DISTO save-list rule (non-defeasible); the device × analysis matrix with the contribution-vs-stamp split | preconditions become filters, not error messages | new suite; `netlist_map_resolve` gains its second **kind** of customer | R9 |
| **5** | Single-plot analyses | `tf`, `pz`, `sens` (DC): three registry entries, three `precheck` rows. **No writer change at all** — each is one plot, so emission stays byte-identical | three of the eight missing types, at zero writer risk | new deck goldens only | R9 |
| **6** | **The writer, and the multi-plot analyses** | DR16's `setplot previous` walk; the plotmap sidecar (pre-run delete); §9.3's reconciliation; `noise`, `disto`, `sens` (AC); per-plot `remzerovec`; result labels from the registry; the read-only `resulttable` | NOISE and DISTO stop silently losing a plot; every result carries the name of the analysis that produced it | **every deck golden moves, once, deliberately** (the sidecar line). Rows E5/M1 must be re-proven green — **[R-M4]** says they will be, because the `op` write is untouched | **R3** |
| **7** | The options surface | the ~250-row catalogue with `cptype`/`door`/`phase`/`scope`/`inert`; `ase::opt_line` as the only speller; search-first + changed-only + groups + the ⚠ badge + **the live deck preview**; the pre-deck class; `<rundir>/.spiceinit` (copy-chained); the `-n` refusal; §7.6's verification leg | both option catalogues become reachable and safe; F15's four traps become type errors | new suite; `run_cmd` goldens the first time `-D` is emitted (`test_ase_simreg_0931` row D4 pins the word order) | **R2**, R9 |
| **8** | **Measurements and post-processing** | the `measurements` state list; the Measurements sub-dialog; `meas` command emission; the eight derived templates including **phase margin with `set units=degrees`**; `.four`/`fft`/`spec`/`psd`/`linearize` producers; THD and the harmonic table | *"read a number back"* — the task all three designs lost | new suite; the Value column gains rows | R9 |
| **9** | SP end to end | the gated type; **§6.6's Ports table** emitting `alter portnum`/`z0`; the `two_ports` fatal evaluated after those lines; the S-parameter surface (matrix picker, Smith/polar); `wrs2p` with the `.csparam Rbase=50` workaround | S-parameters with no schematic edit | new goldens | R9 |
| **10** | Convergence and diagnosis | the ladder pane (content-matched, never order-matched); **`CKTncDump`'s starred nodes highlighted on the canvas**; the remedy assistant with a diff preview; the `optran` panel and the sentence on the OP form; `wrnodev` save/restore; the run-health strip | the failure story ADE-L answers with `sim.log` | new suite; **M2 (stderr/stdout separation) must close first** | R9 |
| **11** | Campaigns | the campaign configuration; the shard runner; `.param x='var(…)'` + per-shard `.spiceinit`; corners as re-rendered `.lib` decks; GUI-drawn MC samples; `index.tsv` **with a column per measurement**; histogram/mean/sigma/yield in Tcl; abort = kill the current shard | sweeps, corners and Monte Carlo — with the number at the end | new suite; the multi-raw family question goes to the Calculator's spec (M5) | **R8**, R2 |
| **12** | Event-driven results | `edisplay` inventory; `eprvcd <nodes> > <cell>_ase_evt.vcd`; the VCD joins `attach_dbs`' list; the `trtol`-forced-to-1 caution; the `dc`+auto-bridge caution; the `.probe alli` refusal | the digital half of a mixed-signal run | new goldens | R9 |
| **13** | Transient noise and `trrandom` | the Tran form's collapsible section; both injection routes; all seven / all five arguments padded; the derived readouts; the rms `meas`; the `notrnoise` row; the honest seed sentence | a category ADE-L does not have | new goldens | R9 |
| **14** | PSS, explicitly experimental | the gated type; the **hard validator** (§4); the stdout verdict scrape; last-TD/FD-by-Plotname; the transient+FFT cross-check offer; the `oscnode` hint | the twelfth analysis | new suite | **R7** |
| — | **deferred** | the `-p` transport + the transient debugger (`iplot`, `stop when`, `resume`, `step`); `libngspice`; offering CIDER as anything but a detection; `sens2`/`hb` | — | — | **R1 reorders this** |

**Ship stage 0 this week.** Stages 1-3 repay themselves: after them, adding an analysis is one
registry entry and the window can no longer report a setting that is not in force. Stages 6 and 8
are the two that change what a user can *get out* of a run.

---

## 14. RULINGS

House rule: **one at a time, discussed before the next is raised.** Ordered by consequence, not by
stage. **None of them blocks Stage 0 or Stage 1.** Ask R1 first and stop.

---

**R1 — The transport. Do we move from `-b` to `-p` in this batch, or keep `-b` and treat `-p` as a
later stage?**
*Blocks: nothing until stage 10; but it REORDERS stages 7, 10, 11 and it changes R2's stakes.*

* **Option A — keep `-b` this batch** (design B's position). Zero change to `run_cmd`, whose word
  order is pinned byte-for-byte by `test_ase_simreg_0931` row D4; the pre-deck door stays
  `<rundir>/.spiceinit` + `-D`; abort stays SIGKILL and the shard runner is what makes a long
  campaign interruptible.
* **Option B — move to `-p` now** (`builds.md`'s recommendation). Graceful abort measured at **under
  5 ms** with partial results fully intact (a valid 388 MB rawfile written after the stop, `resume`
  continuing to 5.1 M points, `quit` rc 0), against **any ngspice the user already has**; and the
  pre-deck problem collapses from three doors and four traps to **one** — `set` before `source` —
  which would make R2 moot and delete DR19 entirely.

*Trade-off in one sentence each.* `-b` costs nothing now and leaves the only measured
capability gap — "stop and keep what you have" — permanently open on a single long run.
`-p` costs one asynchronous reader that parses the `ngspice N -> ` prompt plus a rewrite of
`run_cmd` and the log framing (decision G) and the exit-status contract (I6), and buys the abort,
the option door, and the transient debugger (`iplot`/`stop`/`resume`/`step`) that stages after this
one all want.

**Recommendation: define ONE internal run interface now (start / progress event / abort /
results-located), implement it with `-b` for stages 0-9, and schedule `-p` as its second
implementation immediately after stage 10** — because the abort story matters most once campaigns
(stage 11) exist, and because **[R-M8]** removes the progress argument for hurrying. Refuse
`libngspice` either way (§15).

---

**R2 — May ASE-L write `<rundir>/.spiceinit`, copying the user's own file into it?**
*Blocks: stages 7 and 11.* (If R1 = B, this ruling largely disappears.)

* **Option A — yes.** It is the **only** door to 26 pre-deck variables (`CP_NUM`/`CP_REAL`/`CP_LIST`
  cannot ride `-D`) and therefore the only door to the campaign's design-variable axis. Ours
  **shadows `$HOME/.spiceinit` entirely** for that run (`main.c` searches the netlist directory first
  and `break`s), so we copy the user's lines in — measured working, **[R-M7]**.
* **Option B — no.** Then `casemode`, `wnflag`, `ngbehavior` and 23 others stay unreachable, and the
  campaign falls back to `alterparam` over ASE-L's own `.param` rows only.

*Trade-off.* Yes buys the whole pre-deck class and the campaign, at the cost of ASE-L owning a file
in the run directory that changes what a hand-run deck in that directory does. No keeps the run
directory inert and leaves a documented capability class permanently out of reach.

**Recommendation: yes**, with four conditions: the file is deleted and rewritten per run; the user's
own file is **copied** in under a banner, never `source`d (**[R-M7]**); the run log says once that
the file exists and what it shadows; and it is **refused** when the rundir is the shared
`set_netlist_dir 0` fallback (C19) or when `-n` is in force (DR18).

---

**R3 — Do the Outputs Value-column numbers come from the rawfile's one-point plots instead of the
`print` log?**
*Blocks: stage 6.*

* **Option A — move to the rawfile.** Every scalar an analysis produces is a one-point plot
  (`Operating Point`, `Integrated Noise`, `Transfer Function`, dc `Sensitivity Analysis`). It removes
  `result_probe`'s case-folding ladder and it is what gives NOISE, TF and SENS a scalar home at all.
* **Option B — keep the log.** `result_probe` parses `<expr> = <number>` out of `print` output, which
  is the **only** thing that can evaluate an arbitrary user-typed expression such as `v(a)*2` — that
  is not a vector in the raw.
* **Option C — both.** Named vectors from the raw; expressions from `print`, still anchored per
  issue 1243's ruling.

*Trade-off.* A is cleaner and unlocks three analyses but silently breaks every expression row a user
has typed. B keeps expressions and leaves three analyses with nowhere to put their answer. C keeps
both at the cost of two readers and a rule about which wins.

**Recommendation: C**, with the rule stated on screen: a row whose expression names exactly one
vector reads the raw; anything else reads the log. Issue 1243 was the user's own ruling and this
extends it rather than reversing it.

---

**R4 — Does `ase::state_default` gain any of the new analysis types?**
*Blocks: stage 2.*

* **Option A — no.** All 105 committed `.state` files carry exactly four rows,
  `test_ase_core.tcl` R1 asserts "the four types in order", and Cadence does not add analyses to your
  bench either. New types arrive through the dialog.
* **Option B — yes**, seeding the full twelve as disabled rows so every type is visible on a fresh
  bench.

*Trade-off.* No keeps every golden and every existing bench identical, and costs a user one click to
add a type. Yes makes the whole surface discoverable at a glance and moves R1's assertion, the D1
golden and every freshly created view.

**Recommendation: A (no).** Discoverability is served by §1's four-state grid, which shows all twelve
whether or not they are in the state file. **But today this would change by accident, so it must be
a decision.**

---

**R5 — Reverse recorded decision D4: should switching the analysis type keep what you typed?**
*Blocks: stage 3.*

* **Option A — reverse it.** Cache per-type edits for the dialog's lifetime and commit only the
  visible type at OK. D4's stated reason — "deterministic, no hidden multi-type writes" — is
  satisfied, because nothing is written until OK.
* **Option B — keep D4.** A radio click discards the form.

*Trade-off.* Reversing costs one dict per dialog and makes the type row explorable; keeping it is
defensible with four types and a trap with twelve.

**Recommendation: A (reverse).**

---

**R6 — Do analysis rows gain identity (`id`), i.e. two DC sweeps or two AC sweeps at once?**
*Blocks: nothing; wanted after stage 3.*

* **Option A — yes.** One optional per-row key, absent on all 105 committed files, no schema
  version. It is the difference between a bench that can say "sweep VIN **and also** sweep
  temperature" and one that cannot, and it is ADE-L behaviour #9.
* **Option B — no.** `ase::ui::chana_row` returns the **first** row of a type and `pane_dblclick`
  discards the index, so the addressing work must come first either way.

*Trade-off.* Yes needs the dialog to address rows by index before the key is useful; no leaves a
common bench shape unsayable for the life of the plan.

**Recommendation: A**, sequenced after stage 3 so the addressing lands with the form work.

---

**R7 — Do we ship a PSS panel at all, given that `builds.md` ran it successfully?**
*Blocks: stage 14 only.*

* **Option A — ship it, explicitly experimental**, gated on `help pss`, with the hard validator of
  §4 and the stdout verdict scrape. It runs in under a second on both shipped oscillators and its
  plot literals are now recorded.
* **Option B — declare it and offer no form**, as all three designs proposed before the build probes.

*Trade-off.* Shipping gives ngspice's only large-signal periodic analysis a home and is defensible
because every crashing input is now known and refusable; not shipping avoids owning a panel whose
`Convergence not reached` returns **rc 0 with plausible-looking data**.

**Recommendation: A**, last, with the word *experimental* on the form, the transient+FFT cross-check
offered beside the answer, and the sentence that `oscnode` steers nothing.

---

**R8 — Where does a campaign's configuration live?**
*Blocks: stage 11.*

* **Option A — a new top-level `sweep` state key** joining `ase::omit_if_empty`, absent on all 105
  files. DR3 forbids new top-level keys; this would be the single named exception.
* **Option B — outside the state file**, as a sibling artifact in the run directory.

*Trade-off.* A keeps the campaign with the bench, travels with the cellview, and round-trips through
the existing serializer — at the cost of the one schema exception. B keeps the schema untouched and
makes a campaign something you can lose.

**Recommendation: A**, with `omit_if_empty` so byte-identity for the 105 committed files is
preserved by construction, and `version` still 1.

---

**R9 — The standing label ratification.** Every new user-facing sentence in this document — the four
type states, every field label and unit, every precondition sentence, every refusal, the `optran`
sentence, the transient-noise seed sentence — is the user's to ratify
(`tests/headless/owed.sh add rule <id>`). **Recommend batching per stage**, because twelve analyses
otherwise means twelve rounds of asking, which is exactly what the standing preference forbids.

---

## 15. REFUSALS — what this plan will not do in this pass, with the measured reason

**`libngspice`.** Measured, this session: the F7 `.disto` NULL-deref driven through the library
**killed the host process at rc 139** — the SIGSEGV handler is installed only during `ngSpice_Init`
and restored before it returns; `sens … ac` under KLU and PSS `harmonics<2` are in the same class.
`ngSpice_Circ` after `ngSpice_Reset` SEGFAULTs because `Reset` is a full teardown and `ngSpice_Circ`
lacks the `is_initialized` guard `ngSpice_Command` has — the exact recurring bug class ngspice's own
`CLAUDE.md` names. `bg_halt` **wedges** on `disto` (1.0095 s, `Error: Couldn't stop ngspice`) and on
`sens`. `--with-ngshared` builds **no `ngspice` binary**, so the GUI would ship and ABI-pin
`libngspice.so.0` and set `SPICE_LIB_DIR`. And `SendStat` emits **nothing at all** for op, noise,
disto, pz, tf and sens, while the `-b` ticker covers all of them (**[R-M8]**). [builds §3.3, §3.5,
§3.7, §4.3]

**Conditional logic in the generated deck.** **[B-M5]**: `.control`'s `if` on strings takes the
**false** branch for both `eq` and `ne`. Only the numeric `$sim_status` guard survives.

**A free-text option escape hatch on the analysis form.** That is precisely what lies today (F3).
Replaced by typed fields, a typed catalogue, and one *labelled* verbatim `.control` list that
actually emits.

**`ttk::notebook`, a scrolling form, and any modal analysis dialog.** The notebook appears nowhere in
the xschem tree except a comment explaining why it was not used; a scrolling form has no idiom in
`ase_window.tcl` and would need a `Canvas` theming arm; a modal dialog **would hang the headless
suites**. The form fits because `advanced` fields fold and options moved to the options surface.

**A new colour in the locked 9-colour palette.** A `⚠ ` glyph on the label plus the status line does
the job, is theme-proof, and needs no ruling.

**Hiding an analysis the probe could not measure.** Hiding is how the current code lies. §1.1.

**A corner / Monte Carlo engine inside the control language.** Ctrl-C there is timing-dependent (it
either kills one run and continues or discards the whole control block, indistinguishably) and an
interrupted run reports `sim_status = 0` — *indistinguishable from success*.

**Statistics inside the deck.** ngspice has no sort, no median, no percentile, no histogram. Read
the sample out and compute in Tcl.

**Any `.step`-shaped promise.** ngspice has none. Everything sweep-shaped is plainly labelled as
generated by the GUI, because when it breaks the user needs to know where to look.

**Three-deep `.dc` nesting, and any sweep target but V / I / resistor / `temp`.** A third triple is
silently dropped; `dctrcurv.c:89-151` accepts exactly those four.

**Offering CIDER as an analysis capability.** It adds no analysis, no dot card and no
`SPICEanalysis`; it is model authoring. Detected and warned about (§4), never offered here.

**`sens2` and `hb`.** `SEN2info` and `HBinfo` are `extern` declared and defined **nowhere**.

**Dead knobs offered as live ones.** §7.4's three shapes. `nosavecurrents` in particular is
documented by the manual §13.7 and the string appears **nowhere** in this tree.

**Round-tripping any analysis setting through ngspice.** OP has zero parameters and nothing about a
DC or OP job can be read back (F12). §7.6's verification leg asks what took **effect**, which is the
opposite direction and is not a round trip.

**`iplot`, `stop when`, `resume`, `step`.** All need interactive or `-p` mode. They are the pipe
transport's first customers (R1).

**`speedcheck` / `deltacheck`.** They need `set ngdebug`, which floods the log with per-step traces.

**Any analysis capability delivered by putting something on the schematic.** F13's founding
doctrine. Transient noise uses `alter` or a generated parallel source; SP ports use `alter portnum`;
design variables use `.param x='var(…)'`.

**A promise of "stop and keep what you have" for a `-b` run.** No signal handlers are installed in
batch: SIGINT is rc 130 with nothing written. The honest partial-result story is the shard runner
(§10.1) until R1 says otherwise.

---

## 16. OPEN — what still needs measuring, and the exact experiment

| # | question | why it matters | the experiment |
|---|---|---|---|
| **M1** | Can the ladder pane get stdout and stderr as **two ordered streams**? ASE-L folds them with `2>@1` and two `ngdebug` lines carry **no trailing newline**. | Blocks stage 10's live pane; without it the pane reads the log file after the fact. | Run a deliberately non-converging OP through `ase::run_deck`'s existing capture with `set ngdebug`, and diff the interleaving against two separate `-o`/`2>` files. One deck, before stage 10. |
| **M2** | Does `help <verb>` answer the same way on a build with a **relocated or stripped** help database? **[R-M16]** is one build. | A wrong `analyses_available` either hides a working analysis or offers a missing one. | Run the same probe against `/usr/bin/ngspice` (a different build, present on this machine) and against the `--enable-pss` build. Cross-check every verdict against `devhelp`'s families. Publish only on a clean parse. |
| **M3** | Does `write <raw>` (no `all`, no names) write **every** vector of the current plot, on every plot type? Today's non-`op` write is bare. | The walk emits the bare form for every extra plot; if it drops vectors on a complex or multi-point plot, NOISE's spectrum loses traces. | One deck with `noise`, `disto` and `sens ac`; compare `write f` against `write f all` per plot, vector count for vector count. **Before stage 6.** |
| **M4** | What are the **exact** `Plotname:` literals of `disto`'s three IM plots, and of `sens ac` vs `sens dc` beyond the shared name? | §9.1's routing table has the two harmonic literals measured and the three IM ones from source. | One deck with `disto dec 2 1k 10k 0.9`; `foreach p $plots / setplot $p / echo $curplotname`. Ten minutes. **Before stage 6.** |
| **M5** | A **multi-raw family** (one raw per shard) is new to the waveform viewer and to the Calculator, whose spec says v1 handles only the single-raw multi-dataset case. | Stage 11's family-of-curves display has no owner. | Not an experiment — a conversation with that spec's owner, at stage 11, not at stage 0. |
| **M6** | Does the F7 DISTO segfault exist upstream in `pre-master-47`? `/usr/bin/ngspice` is on this machine and has never been run against it. | Blocks *filing* it upstream. Blocks no stage — the GUI-side mitigation is required either way. | `/usr/bin/ngspice -b ../dor/d1.cir; echo $?`. One command. |
| **M7** | Does `.probe p(XU1)` really yield `xu1:power`, and what are the differential / power vector spellings (`vd_R1`, `mq1:power`)? Documented by the manual §11.6.5, **never verified against source or a run by anyone**. | Pick 6's Outputs column is keyed on those names. | One deck with `.probe p(x1)` and `.probe vd(r1)`; `display` and `write`, then read the names. **Before stage 10.** |
| **M8** | Does `set interp` change a **complex** AC plot and a **nested DC** sweep correctly? Measured only on a real transient (21 points from `tran 1u 20u`). | The Tran form's `grid` field is stage 3; the AC/DC arms are stage 6. | Three decks, `length()` and a spot value before and after. |
| **M9** | Does the `eprvcd` VCD attach cleanly through `ase::attach_dbs` **alongside** a rawfile, and does the digital pane label the nodes with their ngspice names? | Stage 12's whole claim. | Drive `../dor/mx.cir` through a real ASE-L session with the VCD in `vcdfiles`. |
| **M10** | `Nintegrate()`'s definition was never located, so nobody can explain an `onoise_total` number to a user. | The Value column will show it. A tooltip that says what it is would be better than one that does not. | `grep -rn "Nintegrate" src/`, then read. Twenty minutes. |
| **M11** | Does `alterparam` + `reset` preserve `.options` and `set` variables across the re-parse, and does it re-read `<rundir>/.spiceinit`? | Stage 11's collapse-into-one-shard mode depends on it. | One deck: `option reltol=0.05`, `alterparam`, `reset`, then `option` — diff the effective settings (§7.6 gives the reader for free). |
| **M12** | What does `wrs2p` actually emit for an `sp` run with the `.csparam Rbase=50` workaround, and is it a valid Touchstone file? | Stage 9's export. | One two-port deck, `wrs2p out.s2p`, and open it in any Touchstone reader. |

---

## 17. Where the evidence lives

| claim class | owner |
|---|---|
| contradictions between dossiers, and four new ngspice defects | `../dossiers/00-critique.md` |
| **PSS actually run; CIDER actually built; libngspice vs `-p` vs `-b`, all measured** | `../dossiers/builds.md` |
| per-analysis parameter tables | `an-core.md`, `an-smallsig.md`, `an-rf-pss.md` |
| the two option catalogues | `options.md` (OPTtbl + `set`), `hidden-vars.md` (163 `cp_getvar`, the CP-type table, the 26 pre-deck) |
| plot names, rawfile shape, the libngspice API | `outputs.md` (⚠ §3's last three rows corrected by [crit §C4] and §9.4 here) |
| sweeps, corners, Monte Carlo, abort, progress | `orchestration.md` |
| transient noise and `trrandom` | `trnoise.md` |
| the device × analysis matrix and its predicate | `cider-devices.md` |
| `.meas`, `four`, `fft`, the expression vocabulary | `measure.md` |
| the event-driven surface | `xspice.md` |
| ASE-L's state schema and blast radius | `ase-state.md` |
| `render_deck`, the run pipeline, the capability probe | `ase-deck.md` |
| the window, the dialog, the ADE-L parity table | `ase-ui.md` |
| house rules, the spec of record, decisions A-N, the document shape | `ase-conventions.md` |
| **my own measurements [R-M1]…[R-M18]** | `../dor/` — `m1`..`m7`, `pm`, `ov`, `ot`/`ot2`, `d1`..`d4`, `k1`, `ko`, `p1`+`cap.txt`/`fam.txt`, `si/`, `si2/`, `si3/`, `mx`+`mx.vcd`, `tick`, `l2` |

**Where this document goes when it is adopted.** `ase-conventions.md` §10 is unambiguous: a batch is
a **directory**, not a file. This becomes `doc/claude/ase_analyses_batch/` — `README.md`,
`PLAN.md` (§13's stages as items), `CREW_BRIEF.md` (§0.1's measurements, so nobody re-derives them),
`DECISIONS.md` (§2, with ⚖ on §14's rulings), `LEDGER.md`,
`APPENDIX_ngspice_analyses.md` (§5.1's table plus the dossiers' inventory), and `receipts/`.
And the spec of record must be **amended, not replaced**: `specs/ase_l.md`'s Choose Analyses
paragraph is **six lines** today, and it is the reason this area drifted for so long.
