# 1427 — the pole-zero analysis was listed and could not be chosen

**Status:** fixed
**Branch:** fluid-editing
**Stage:** the `pz` commit of **Stage 5** of `doc/claude/ase_analyses_batch/` (`tf` is issue
**1426**; `sens` is a separate commit).

## What it was

`pz` was one of the entries Stage 2 registered so the four-state grid could show that the analysis
exists:

```tcl
pz [dict create label pz baseline 1 registered 1 emit {{role probe tmpl {pz}}}]
```

No `fields`, no `emitorder`, no `role analysis` card — so `ase::analysis_renderable` answered 0, the
grid cell read `blocked/unrenderable`, and a hand-enabled row was refused at the gate. The user could
see that ngspice finds poles and zeros and could not ask it to.

It now carries a real entry: six fields, a rank, an emit template, a results destination and four
preconditions.

```tcl
pz [dict create \
  label pz  baseline 1  registered 1  emitorder 60 \
  needs  {pz_shorted pz_nodes pz_devices pz_klu cider_klu} \
  fields {{name inp  kind node required 1 label {Input +}} \
          {name inn  kind node required 0 default 0 whenskipped 0 label {Input -}} \
          {name outp kind node required 1 label {Output +}} \
          {name outn kind node required 0 default 0 whenskipped 0 label {Output -}} \
          {name transfer kind mode required 0 default vol values {vol cur} \
                     label {Input type}} \
          {name mode kind mode required 0 default pz values {pz pol zer} label {Find}}} \
  emit   {{role analysis tmpl {pz @inp @inn? @outp @outn? @transfer? @mode?}}} \
  results {table {kind roots}} \
  plots  {{select {Pole-Zero Analysis} role table results table label pz \
           rootname ::ase::backend::ngspice::pz_root_kind} \
          {select {Distortion Operating Point} role opinfo results viewer \
           when {opt keepopinfo} label {pz operating point}}}]
```

Every measurement below was taken **2026-09-12** on the fork (`build-ver_50`, `ngspice-46+`) **and**
on apt 45.2 (`/usr/bin/ngspice`), on scratch decks under `/tmp/pzprobe`, never on a bench under
`sky130A/`. **The two binaries agreed on every single line.**

## The measurement that matters: a device pz cannot model is simply left out

`cktpzld.c:29` calls a device's `DEVpzLoad` **only when it is not NULL**, and nine device families
declare it NULL (`cpl isrc jfet2 ltra mos6 soi3 tra txl urc`). For the ones that carry no
small-signal stamp anyway (an independent current source is an open circuit) that is correct. For a
transmission line it means the line **contributes nothing to the matrix and nothing at all is said**.

Same two-pole RC, a lossy line hung off a node, against the same deck with the line deleted:

```
no line at all   -> pole(1) -2.61803e+06   pole(2) -3.81966e+05
+ Y1 (TransLine) -> pole(1) -2.61803e+06   pole(2) -3.81966e+05    rc 0
+ P1 (CplLines)  -> pole(1) -2.61803e+06   pole(2) -3.81966e+05    rc 0
+ T1 (Tranline)  -> rc 1  doAnalyses: Transmission lines not supported
+ O1 (LTRA)      -> rc 1  doAnalyses: The input signal is shorted on the way to the output
+ U1 (URC)       -> rc 1  doAnalyses: device already exists, existing one being used
```

**Byte-identical roots, rc 0, nothing on either stream:** the analysis answered for a circuit the
user does not have. That is what `caution` is for. The three that abort are `fatal`, and only the
first of the three says anything a user could act on.

⚠ **`PZinit`'s transmission-line check cannot fire for an LTRA, and `PLAN.md`'s own citation is where
that shows.** `pzan.c:96-106` looks up `"transmission line"`, then `"Tranline"`, then `"LTRA"`, and
**stops at the first name that is a compiled-in device type** rather than the first with instances —
so on any build with `tra` compiled in, `i` is `tra`'s index, `CKThead[tra]` is NULL, and the LTRA
arm is never reached. Measured: an O-card deck does **not** print `Transmission lines not
supported`; a deck with a T card **and** an O card does, because the T card is what the one check
that runs can see. ASE-L therefore names the other families outright instead of relying on a check
that cannot fire.

⚠ **Model-level devices share the defect and are deliberately not covered.** `mos6`, `jfet2` and
`soi3` also declare `.DEVpzLoad = NULL`, and measured: the same topology with `level=6` aborts where
`level=1` answers `pole(1) = -1.00000e+06`. They are selected by a `level=` number and ngspice's
level-to-device map is a per-build decision (level 8 and 49 split between `bsim3` and `bsim3v32` by
a `version=` parameter), so a rule keyed on a level would be a claim about **one** binary's mapping
that ASE-L cannot verify. The device **letter** is a claim about the netlist.

## The rest of what was measured

Each line a `-b` deck, wrapped in this tree's own `sim_status` guard, on both binaries:

```
pz in 0      out 0   vol pz  -> rc 0, REACHED-THE-END, pole(1) pole(2)
pz in 0      out 0   vol zer -> rc 0, REACHED-THE-END, NO VECTORS AT ALL
pz in 0      in  0   cur pz  -> rc 0, REACHED-THE-END, four roots
pz nosuch 0  out 0   vol pz  -> rc 1, doAnalyses: The input signal is shorted on the way
                                      to the output
pz in 0      nosuch 0 vol pz -> rc 1, the SAME sentence
pz in in     out 0   vol pz  -> rc 1, doAnalyses: Input is shorted
pz 0  0      out 0   vol pz  -> rc 1, doAnalyses: Input is shorted
pz in 0      out out vol pz  -> rc 1, doAnalyses: Output is shorted
pz in 0      in  0   vol pz  -> rc 1, doAnalyses: Transfer function is unity
pz 0  in     in  0   vol pz  -> rc 1, doAnalyses: Transfer function is -1
pz in 0      out 0   vol     -> rc 1, Error: no such parameter on this device or
                                      parameter is missing
pz in 0      out 0   pz      -> rc 1, the SAME sentence
.options klu + pz …          -> rc 1, Error: Pole/zero analysis is not (yet) supported
                                      with 'option KLU'. / Use 'option sparse' instead.
```

Four things that came out of that list:

1. **A missing node is not a floating node.** ngspice invents it and the root finder then reports
   `The input signal is shorted on the way to the output` (`cktpzstr.c:213`), which names neither the
   node nor the fact that one was invented. A user reads it and goes to look at their schematic.
2. **The in-is-out refusals are `vol`-only, and that is measured rather than inferred.**
   `pzan.c:117-125` guards both unity arms with `PZinput_type == PZ_IN_VOL`, and `pz in 0 in 0 cur pz`
   reaches the end at rc 0 with four roots. Refusing the current-input case would refuse a real
   analysis — the input admittance of a node, which is the reason `cur` exists.
3. **An omitted picker is not a default, it is an abort.** `PZwhich = 0` makes `PZan` do *neither*
   search and `PZinput_type = 0` is treated as the current case, so both words must always be
   emitted. That is why `transfer` and `mode` are `@x?` slots with declared defaults rather than
   optional ones.
4. **An empty result is normal.** The same two-pole RC asked for `zer` produced **no vectors at all**
   at rc 0 — APPENDIX §2.8 records it, and it is why the entry declares no `vectors` key (below).

## Where the static demotion has a third case

Issue **1423** lowers every `blocked` to `caution` on a static pass and appends *"(read from the
netlist text, which cannot see inside an `.include`)"*. Issue **1426** found that right for one
finding in a predicate and false for another. `pz` adds the third case, which neither had a name for:

| finding | verdict | why |
|---|---|---|
| a node is not in the circuit | `blocked` → `caution` **with** the caveat | an `.include`d file really could define it |
| the row's own two node boxes hold the same word | `fatal`, no caveat | no include can change what the user typed |
| **this deck CONTAINS a `Y` card** | `caution`, no caveat | **the static pass PROVED it** — an `.include` can only ADD devices, never remove the card just read |

The third is the new one. A **positive** finding is not weakened by what the pass could not see, so a
caveat about that would be wrong in the opposite direction from the second row. The demotion only
reaches `blocked`, and no positive finding here is `blocked`. Row **PF228h** is that sentence as an
assertion.

**And the severity still tracks what the static pass can KNOW, never how loudly ngspice complains.**
Every failure in the table above is a hard rc 1 abort; three of the four predicates are `fatal` and
the node check is not.

## What PLAN.md Stage 5 said that the tree refuted

* **C48 — `{build <proc>}` buys `pz` nothing, so its absence costs `pz` nothing.** `PLAN.md` spells
  this entry `{pz {build ase::backend::ngspice::an_pz_nodes} @transfer @mode}`. Issue 1426 found
  that Stage 1 shipped `@x` / `@x?` / `@x!` and no `build` arm at all. For `pz` the escape was never
  needed: `pz NODE1 NODE2 NODE3 NODE4 {cur|vol} {pol|zer|pz}` is six space-separated words and the
  slot grammar joins tokens with a space, so **four node fields are the four node tokens**. The
  missing mechanism is still missing; this entry simply does not want it.
* **C49 — `PZinit`'s transmission-line check is cited for a guarantee it does not give.** The plan's
  `pz_devices` rests on `pzan.c:92-128`. Measured above: that check cannot fire for an LTRA on any
  build with `tra` compiled in, and it never looks at `txl`, `cpl` or `urc` at all. Two of the five
  families are therefore a **silent wrong answer** rather than a refusal, which is a different
  verdict and a different sentence.
* **C50 — `plots`' vector key names a READER here, not a predictor.** `tf`'s `plots` row names a
  proc that computes its three vector names from the row (issue 1426's C45). A `pz` row cannot know
  any of its names: `pzan.c:151`/`:155` emit `pole(i)` and `zero(i)` for `i` in `1..n`, and `n` is
  whatever the root finder converged on — measured, the same row that gives two poles gives **zero**
  zeros. Declaring a `vectors` key would give one key two meanings, so the entry declares none and
  ships `pz_root_kind`, which reads a name back instead.
* **C51 — `tf`'s capital-folding warning does not reach `pz`.** Issue 1426's C46 records that the
  fork writes `v(Transfer_function)` where apt 45.2 writes `v(transfer_function)`, so a
  case-sensitive reader is wrong on the binary a downloading user has. `pz`'s names are built by
  `sprintf(name, "pole(%-u)", i+1)` — **there are no capitals to fold**. Measured, the same deck
  written by both binaries: `v(pole(1))` / `v(pole(2))`, byte-identical `Variables:` blocks, the only
  difference in either header the `Command:` version line. `pz_root_kind` is still case-insensitive,
  because that costs nothing and the measurement is about two binaries rather than about all of them.

⚠ **And `viewrank` is refuted again, with a second reason `tf` did not have.** Measured against a raw
carrying an `Operating Point` plot and a `Pole-Zero Analysis` plot:

```
xschem raw read both.raw pz                   -> raw_read(): no useful data found ... 0
xschem raw read both.raw op                   -> sim_type=op ....................... 1
xschem raw read both.raw {Pole-Zero Analysis} -> sim_type=Pole-Zero Analysis ....... 1
```

`src/save.c`'s `read_dataset()` has six named `Plotname:` arms and then an exact `strcmp` against the
plot name itself; `pz` is in neither set. **And a pz plot is a root list** — `Flags: complex`, **no
scale vector**, one data row — so even a mapping would open the waveform viewer on something that is
not a sweep.

## The upstream mislabel, carried verbatim

`pz`'s operating-point plot is written `Distortion Operating Point` — a copy-paste from `distoan.c`
at `pzan.c:52-61`. Measured on **both** binaries, `.options keepopinfo` then `setplot`:

```
Current pz1   * keepopinfo pz plots (Pole-Zero Analysis)
        op1   * keepopinfo pz plots (Distortion Operating Point)
        const Constant values (constants)
```

Spelling it the way it reads would make Stage 6's reader match nothing on every ngspice that exists.

## End to end, on both binaries

`ase::backend::ngspice::render_deck` against a scratch library with an explicit `rundir`
(`/tmp/pzprobe/e2e`), a state carrying `{type op enabled 1}` and `{type pz enabled 1 inp in outp
out}`, emits

```
op … remzerovec … write …/pzcell_ase.raw
pz in 0 out 0 vol pz … remzerovec … write …/pzcell_ase.raw
```

**rc 0 on the fork and rc 0 on apt 45.2**, two `Plotname:` records in one raw, read back identically
through ASE-L's own readers:

```
ase::cap_raw_plots       -> {{Operating Point} 1 {v(in) v(mid) v(out) i(v1)}}
                            {{Pole-Zero Analysis} 1 {v(pole(1)) v(pole(2))}}
ase::raw_content_verdict -> ok 1 constants 0 appended 0 plotname {Operating Point} …
ase::plot_sim_type       -> op   (pz has no viewrank, so op still wins)
```

## What did not move

**No `seed_enabled`.** `ase::state_default` still seeds exactly four rows and the **104 committed
`.state` files** are untouched — ⚖ R4's recommended answer continuing to ship by construction.
Rows R1, AG3 and CP1–CP4 of `tests/headless/test_ase_core.tcl` did not move.

**`src/ase_window.tcl` is untouched.** The form is built by `ase::ui::chana_field_row` from the
registry: the four nodes fall to the existing default entry arm and the two pickers to the existing
`kind mode` combobox arm. `ase::ui::resulttable`, the s-plane scatter and the `.sens` picker are
Stage 5b's and are **not** in this commit.

## Floors

| suite | before | after | section |
|---|---|---|---|
| `test_ase_core` | 360 | **376** | PZ |
| `test_ase_simcaps_0948` | 170 | **175** | PV |
| `test_ase_preflight` | 164 | **177** | PF228 |
| `test_ase_dialogs` (`:99`) | 271 | **278** | G2pz (headless 37 unmoved) |

Seven existing `test_ase_core` rows **moved** rather than being added, every one expected and every
one named in that file's floor paragraph: `AG1`/`AG2` (the offered list splits at six — `pz` earned
rank 60), `EM7`/`CP6` (five probe-only types, not six), `GR8` (a new declared kind, `node`, added
deliberately), `TF3b` and `D7e3` (both used `pz` as their "unrenderable" control and now use `noise`
and `pss`).

## Sabotage

Forty-one sabotages of `src/ase.tcl`, each a plausible respelling; restore by `cp` from a pristine
copy with an md5 compare after every one. Thirty-eight reddened a named row on the first attempt.
The three that did not are the interesting ones and each bought something:

* **S22 — deleting `pz_nodes`' `$n eq {0}` ground skip SURVIVED**, ALL PASS across the whole
  section, because every deck the other rows use writes node `0` on a card. Measured:
  `ase::netlist_facts` on a deck that spells its reference `gnd` answers a node set with **no `0`
  in it**, and both reference fields *default* to `0` — so without the skip the commonest pole-zero
  row there is would be reported as naming a node the circuit has not got. Row **PF228m** is that
  deck; S22 re-run reddens it alone.
* **S3 — deleting `whenskipped 0` KILLED `test_ase_core`** at 366 of 376 (`key "whenskipped" not
  known in dictionary`): row PZ2c read the field descriptor with a bare `dict get`, which is only
  legal while the key is there, and the key's deletion is the change the row exists to catch.
* **S33 — declaring the `Find` picker `kind node` KILLED `test_ase_dialogs` twice**, first on
  `cget -values` (`-values` exists only on a combobox) and then on `$w.mode set pol` (an Entry has
  no `set`).

Both deaths are the weaker result, and both bought the same hardening the Stage 3 receipt
prescribes: *call the thing inside the row's own `catch` and assert the return code.* Re-run,
S3 reddens **PZ2c** alone and S33 reddens **three G2pz rows** with the file surviving.

## Rulings

⚖ **R9.** Six field labels — `Input +`, `Input -`, `Output +`, `Output -`, `Input type`, `Find` — the
two pickers' value sets, the ground default on the two reference nodes, and **eight precondition
sentences with their eight remedies** — sixteen new user-facing strings in all. Recorded as
`owed.sh add rule 1427`. Batch with 1426's and `sens`'s.
