# Receipt 19 — issue 0319: Ctrl-Alt-V on a FET asked for a name the raw does not use

**Task** `doc/claude/suggestions/next_task_0319_ctrl_alt_v_on_a_primitive_fet.md`.
**Start HEAD** `a55cba16`, branch `fluid-editing`. **Nothing pushed.**
**Verdict: (a) a real fix.** The issue's hypothesis is refuted; the path for a
primitive IS constructible, and the probe reaches it unchanged.

---

## 1. THE MEASUREMENT — the four unknowns, closed

The task's first deliverable. Everything below is a value read out of the tool
or the raw, not an inference.

### U1 — what `M18` actually looks like in the raw

`/home/qflow/.xschem/simulations/tb_bandgap_ase.raw`, 424 variables. Grepping
the header for `m18` gives **six** names and no others:

```
v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#body)
v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#dbody)
v(m.x1.x1.xm18.msky130_fd_pr__nfet_01v8_lvt#sbody)
v(m.x1.x2.xm18.msky130_fd_pr__nfet_01v8_lvt#body)
v(m.x1.x2.xm18.msky130_fd_pr__nfet_01v8_lvt#dbody)
v(m.x1.x2.xm18.msky130_fd_pr__nfet_01v8_lvt#sbody)
```

There is **no bare `m18`** anywhere in the file.

**So the issue's hypothesis is wrong.** It guessed that "a primitive's internal
nodes plausibly hang off the parent level with the device fused into the leaf,
contributing no path segment at all". The device contributes a segment. It is
spelled **`xm18`**.

Why: the schematic draws it as

```
C {sky130_fd_pr/nfet_01v8_lvt} 800 -290 0 0 {name=M18
L=4  W=6  nf=1 mult=1  model=nfet_01v8_lvt  spiceprefix=X }
```

and the symbol's format begins `@spiceprefix@name`, so the netlist writes
`XM18` (`/home/qflow/.xschem/simulations/tb_bandgap_ase.spice:110`:
`XM18 G2 G1 VSS VSS sky130_fd_pr__nfet_01v8_lvt L=4 W=6 …`) and ngspice
lower-cases the whole raw to `xm18`. xschem's own source states the naming rule
verbatim at `src/token.c:4435`:

```
Id=@spice_get_node i(\@m.@path@spiceprefix@name\.msky130_fd_pr__@model\[id])
```

0217's declass rule was checked against the raw rather than assumed: the
single-letter head `m.` is what the class filter strips, which is why the whole
name is *classified* a device internal — but the `xm18` **between** the head and
the model tag survives as a genuine path segment, exactly like the `xm1` item 18
was built on.

### U2 — how the asked path `segs` is built for a primitive

Producer: `ase::show_in_browser_for_current` (src/ase.tcl), steps 2 and 3b.
Measured on the real design, two descends in, with `M18` selected:

```
wviewer::hier_now            -> {x1 x1}        (sim_sch_path = "x1.x1.")
ase::browser_sel_segment     -> {ok M18}       (the SCHEMATIC spelling, verbatim)
=> segs                      =  {x1 x1 M18}
```

`browser_sel_segment`'s header says so in as many words: "`<name>` is the
SCHEMATIC's own spelling, passed through verbatim". Nothing in the chain knew
about the netlister's `@spiceprefix`.

### U3 — what the probe answers, and whether item 18 is wrong

Both row models built from the real 424 names through the shipped
`signal_entry` → `browser_class_filter` → `browser_rows_multi`:

| rows model | `node_for {x1 x1 M18}` | `node_for {x1 x1 XM18}` | `node_for {x1 x1 xm18}` |
|---|---|---|---|
| device internals HIDDEN (185 rows) | `g:x1.x1`, **2 of 3** | `g:x1.x1`, 2 of 3 | `g:x1.x1`, 2 of 3 |
| device internals SHOWN (503 rows) | `g:x1.x1`, **2 of 3** | `g:x1.x1.xm18`, **3 of 3** | `g:x1.x1.xm18`, 3 of 3 |

Groups under `x1.x1` with internals shown: `x1 x3 xm1 xm2 xm3 xm4 xm5 xm6 xm7
xm8 xm9 xm10 xm11 xm18 xm20 xr5`. With them hidden: `x1 xr5`.

⚠ The 185/503 are `llength $rows` over all 424 raw variables with the
source-currents box OFF — **not** the `45 → 129` the R12 comment quotes, which
counts tb_bandgap's *tree nodes* on item 18's own fixture. Two different
denominators; neither contradicts the other, and this receipt uses only its own.

So R12's probe answered `pmatched == 2`, `[llength $segs] == 3`, **for the right
reason**: with internals shown the asked path *still* does not resolve, because
`M18` is not what that row is called. The gesture then fell through to
improve-or-restore and landed on `g:x1.x1` — the reported symptom, reproduced
exactly.

**Item 18 is therefore neither wrong nor narrower than advertised.** Its promise
is reachable for this device; the *question it was asked* was malformed. The
`==` is correct and is **not touched** — and BN36 in the new file re-measures
BK43's limit from the 0319 side.

### U4 — does descending matter? **No. It is scenery.**

`test_nfet_final` (sky130_tests, committed) puts its FET at the **top level**,
with no descend anywhere: `C {sky130_fd_pr/nfet_01v8} … {name=M1 W=1 L=0.15
nf=1}`. Its raw's first variable is

```
i(@m.xm1.m0[id])
```

— the same `M1` → `xm1` mismatch, zero descends. `hier_now` is `{}` there, so
the descend contributes only the ancestor prefix `{x1 x1}`, which resolves 2 of
2 either way. What decides the outcome is whether the SELECTED instance carries
a spiceprefix, not how deep it is.

**And this control earned its keep**: it broke the first cut of the fix. See §3.

---

## 2. The verdict, and why

**(a) A REAL FIX.** The path for a primitive is constructible — it is
`@spiceprefix@name`, the netlist's own spelling — and once the gesture asks for
it, item 18's shipped probe ticks the box, re-resolves, lands on the device and
reports R12's tenth kind. Nothing in `src/wave_viewer.tcl` changed.

(b) was on the table and is now wrong: a primitive is not path-less, so a
sentence saying "the device's internals live at the parent's level" would be a
false statement about this design. (c) is half true — the issue's *mechanism*
was wrong and the issue has been rewritten — but a refutation alone would leave
the user's gesture broken when it is one line from working.

---

## 3. The change — `src/ase.tcl` only

**`ase::spice_seg_name {name prefix fmt}`** — PURE. The rule: prefix the name
iff the name is non-empty and the format string actually consumes
`@spiceprefix`. Separate from the reads so the rule is assertable with no
design, no raw and no viewer (`browser_origin_drop`'s reason).

**`ase::inst_path_segment {nm}`** — the reads. Refuses an all-digit name
(`get_instance` would read it as an index), asks the **netlister** for the
prefix — `xschem translate <inst> {@spiceprefix}` — and then reads the format
with the NON-EVALUATING accessor (`getprop instance_notcl`) over the attribute
the netlister would use: `lvs_format` when `lvs_netlist` is on, else `format`,
instance before symbol, falling back to plain `format`. That is
`token.c:2468-2479`'s chain, mirrored. Three of those five properties are
review findings — see §5 A-1, A-2, A-3.

**The call site**, the `ok {` arm of item 17's switch:
`lappend segs $selname` → `lappend segs [ase::inst_path_segment $selname]`.
`$selname` itself is unchanged, deliberately: step 3c's digital probe reads
`getprop instance <name> model`, which only answers for the schematic's
spelling, and 6b's "'<name>' has no level in the simulation data" sentence has
to name what the user selected.

### The first cut was live-broken, and the top-level control is what caught it

The first version read the prefix with `xschem getprop instance $nm
spiceprefix`. That reads `inst.prop_ptr` **only** (`scheduler.c:5224`). `M18`
happens to carry `spiceprefix=X` in its own property string, so the reported
repro passed — but `test_nfet_final`'s `M1` does **not**; it inherits the token
from the symbol template, and `translate()` is what applies that fallback.
Measured: getprop answers `{}` for `M1`, so the first cut silently did nothing
on the commoner of the two shapes. `xschem translate` fixes that and brings two
more properties with it: it honours the global `spiceprefix` variable
(Simulation > "Use 'spiceprefix' attribute", `xschem.tcl:15148`, default 1 at
`:15708` — measured off → `M18`, on → `XM18`), and it cannot drift from the
netlister because it *is* the netlister.

### The format guard is not defensive padding

`devices/netlist_options` carries `spiceprefix=true` in its template and has no
format at all. Without the guard, selecting one and pressing Ctrl-Alt-V would
ask the browser for a node called `trueNETLIST_OPTIONS`. Measured on a placed
instance: `translate NOPT {@spiceprefix}` → `true`, `cell::format` → empty,
segment → `NOPT`. Survey: 122 `.sym` files mention `spiceprefix` —
`xschem_library` 26, `xschem_libs_newsym` 26, `sky130A/xschem_libs` 70 — and
exactly **two** never use `@spiceprefix`: the same `netlist_options` symbol,
once per library layout. Also checked, both empty: no shipped format ESCAPES
the token (`\@spiceprefix`) and none hides it inside a `@tcleval`, so the
`string first` test cannot be fooled either way on this tree.

### Declared limits (all of them, after review)

* `xschem set format <attr>` can point the netlister at an arbitrary attribute
  (`xctx->format`); this reads `format`/`lvs_format`. No in-tree caller sets it.
* The global `spiceprefix` switch is read at GESTURE time, not simulation time,
  so flipping it after a run makes this disagree with the raw on disk.
* A format whose `@spiceprefix` appears only AFTER Tcl evaluation reads as "no
  prefix" (the price of not executing the symbol's Tcl — see §5 A-2). No
  shipped symbol is like that.
* A format that emits SEVERAL devices from one instance (`passgate.sym`) is
  detected as prefixed but its device names are `<pfx>MA<name>` — unreachable
  today, §5 A-5.
* A vector instance name (`M1[3:0]`) yields a segment in no netlist — but so
  did the bare name, §5 A-7.
* Ctrl-Alt-V from inside a descended-into **symbol** view is unfixed, §5 A-9.
* **Every one of these degrades to the shipped `partial` landing on the parent
  — the pre-fix behaviour.** With `lvs_format` now honoured there is no known
  input for which this fix produces a *wrong* node rather than a missed one.

---

## 4. Checks — `tests/headless/test_wave_sigbrowser_0319.tcl`, 35 checks

24 run on the `--nogui` arm (the rule, the reader on six real designs including
a gf180 one, the source claims); 11 more under X (the seeded browser, the
shipped resolver, the R12 probe, and the REAL gesture driven end to end).

Two are worth naming:

* **BN32** is the **bug itself, pinned as a value**: `x1.x1.M18` must keep
  answering `partial` on `g:x1.x1` with the box unticked. It is the tombstone
  for "fix 0319 in the resolver" — sabotage S16 teaches `browser_node_for` to
  guess an `x` prefix and BN32 is the only thing that reds.
* **BN41/BN42** drive `ase::show_in_browser_for_current` itself on the real
  descended design against the seeded tree, stubbing only the session plumbing:
  the box ticks, the tree selects `g:x1.x1.xm18`, and the gesture's whole CIW
  account is one plain line, `ase: signal browser: showing device internals to
  reach x1.x1.xm18`.

### 4.1 Sabotage — measured twice, 16 rows then 25

Full table in the file header. Every mutation reds at least one check; the run
after the final revert is `RESULT: ALL PASS (35 checks)`.

**Round 1 (16 rows) found one hole, and it was in the fix rather than in the
file.** S6 dropped `spice_seg_name`'s `$prefix eq {}` guard and red exactly one
SOURCE check and no behaviour — `"$prefix$name"` with an empty prefix *is* the
name, in every state. A line no sabotage could reach, so it was removed and S6
now measures the **re-add**.

**Round 2 (25 rows) exists because the reviews rewrote the code.** Nine rows are
new (S19-S25 plus the re-aimed S17/S21), and each was green on the round-1 file:
`lvs_format` ignored, the Tcl-executing reader, the index-ambiguous digit name,
a constant prefix in the reader, `!= 0` for `< 0`, an idempotence guard, and
6b's `$base` → `$segs`.

**One round-1 row had no teeth and was re-aimed.** S21 (deleting the all-digit
refusal) originally red only a source grep, because in the first fixture the
wrong instance happened to have no prefix and the answer came out the same. The
fixture was reordered so index 2 *is* the prefixed FET; S21 now reds BN26.

**Six checks are reached by no mutation, and the table says which and why**:
four are preconditions (the procs exist, the design loaded, the class filter
really hides and shows) and two — BN13, BN43 — are the "must not change"
controls, which no *single* edit can red because three things must be wrong at
once. Two rows red source checks only, and both say why: S14 cannot fire in a
fixture that stubs `wviewer::open`, and S12's damage is invisible on this design.

---

## 5. Adversarial review — two lenses, neither by the implementer

**Both reviews broke the first version.** Between them they found **three live
defects in the fix** and **five mutations that were green on all 30 checks**.
Every CONFIRMED finding below was re-measured by me before I acted on it.

### Lens A — resolver and path semantics

**A-1 `lvs_format` excluded on a measurement that is false for this repo.
CONFIRMED, FIXED — this is the serious one.** My comment said no shipped symbol
disagrees between `format` and `lvs_format` about `@spiceprefix`. It swept
**three of this repo's five** symbol libraries. Re-measured: **54 symbols
disagree** — 19 in `gf180mcuD/xschem_libs/gf180mcu_pr`, 35 in
`ihp-sg13g2/xschem_libs/sg13g2_pr`, where LVS hardcodes a *different* letter per
class (`M@name`, `C@name`, `R@name`, `L@name`, `Q@name`). And the direction
matters: with LVS netlisting on, gf180's `M1` is emitted **bare**, so prefixing
it does not merely fail to help — it **breaks a segment that used to match**.
The declared limit I had written ("never a wrong node") was wrong there too.
Fixed by mirroring `token.c:2468-2479`'s own attribute chain. Pinned by **BN24**
(gf180, both modes, `XM1` / `M1`) and BN21; sabotage **S19**.

**A-2 the format read EXECUTES the symbol's Tcl. CONFIRMED, FIXED.** `getprop
instance` looks the token up with `with_quotes = 0` (scheduler.c:5213/5221/5224),
which routes through `tcl_hook2` (token.c:533-537) and runs any `tcleval(...)`
value; `print_spice_element` uses `with_quotes = 2` and does not. Measured with
a tripwire proc on a symbol whose format is `tcleval([boom])`: the plain read
fired it, `instance_notcl` did not. `xschem_library/analyses/command_block.sym`
ships `format="tcleval([::analyses::netlister spice])"` — a read that would run
the netlister on a key press. Fixed to `instance_notcl`; pinned by **BN25**
(which also asserts the tripwire is armed); sabotage **S20**.

**A-3 an all-digit instance name resolves as an INDEX. CONFIRMED, FIXED.**
`get_instance` (scheduler.c:187-190) reads an all-digit string as an index, so
every by-name read answered about a different device — silently, with no throw.
Measured. `hier_resolve` guards the MIRROR direction against exactly this and
says so at wave_viewer.tcl:10725-10732, so leaving it unguarded here was
inconsistent, not merely unlucky. Fixed by refusing rather than guessing;
pinned by **BN26**; sabotage **S21**.

**A-4 the raw I quoted belongs to the wrong PDK. CONFIRMED, FIXED.** Both
sky130 and gf180 ship a `test_nfet_final`, and
`~/.xschem/simulations/test_nfet_final_ase.raw` — whose `i(@m.xm1.m0[id])` I
cited — is **gf180mcuD's**; its Title line says so. The claim it supports is
unchanged (both netlist `XM1`), but the citation was wrong and is corrected in
the source comment and in §1 here. Pointedly: that fixture's own library is one
of the two A-1's sweep had omitted.

**A-5 a format can contain `@spiceprefix` and still not emit `<prefix><name>`.
CONFIRMED as analysis, NOT FIXED — declared limit.** `xschem_library/ngspice/
passgate.sym` and `inv-2.sym` emit TWO devices from one format
(`@spiceprefix\MA#@name`, `…MB…`). Unreachable today (their templates define no
`spiceprefix`), and the failure mode is a non-matching path → the shipped
`partial`, never a wrong node.

**A-6 round-trip asymmetry. CONFIRMED, NOT FIXED — filed separately.** The
gesture now deliberately parks the user on `g:x1.x1.xm18`, and the mirror
(`hier_resolve`) cannot resolve `xm18` back to the schematic's `M18`, so
"Descend to here" on that row refuses. Pre-existing, but the fix turns it from
unreachable into the row the user is standing on. Filed as its own issue rather
than widening this one, per the task's rule about third instances.

**A-7 vector instance names. No regression, declared limit.** `name=M1[3:0]`
netlists as `XM1[3] XM1[2] …`; the segment becomes `XM1[3:0]`, which is in no
netlist — but the bare `M1[3:0]` was equally absent before.

**A-8 `xschem set format <attr>` (custom_format) and the global `spiceprefix`
toggle read at gesture time rather than at simulation time. Declared limits**,
both now written into the source comment. No in-tree caller sets custom_format.

**A-9 `descend_symbol()` has no type guard**, so descending into a FET's SYMBOL
view puts `M18` into `sch_path` untransformed and Ctrl-Alt-V from *there* still
asks `x1.M18`. **RECORDED, out of reach of this fix** — that segment comes from
the hierarchy path, not from the selection.

### Lens B — evidence quality

**B-1 the prefix's VALUE was never pinned. CONFIRMED, FIXED.** Every shipped
`spiceprefix=` value is `X`, so the reader could hand the rule a **constant**
`X` and pass all 30 checks — measured by the reviewer. Closed by **BN27** (a
placed instance carrying `spiceprefix=Q` → `QM6`) and BN02 leg 2; sabotage
**S22** and S17.

**B-2 "consumes `@spiceprefix`" was only ever tested as "begins with".
CONFIRMED, FIXED.** Every shipped format puts the token at index 0, so
`[string first …] < 0` and `!= 0` were indistinguishable. Closed by BN02 leg 3;
sabotage **S24**.

**B-3 an idempotence guard was invisible AND is a real defect. CONFIRMED,
FIXED — the most valuable single finding.** The plausible later "hardening" is
a guard that refuses to double-prefix; it passed all 30 and re-opens 0319 for a
device the user renamed `X1`, because the netlister does not dedupe (`XX1` in
the netlist, `xx1` in the raw). Closed by BN02 leg 4 and BN27 leg 2 (`XX1`
measured on a placed instance); sabotage **S23**.

**B-4 / B-5 6b's last-mile retry was driven by nothing, and the fix's own
justification had only a source grep. CONFIRMED, both FIXED by one check.**
Swapping `[join $base .]` for `[join $segs .]` — one token, inside the block
this fix edits — was green on all 30 while turning the retry into a re-ask of
the failing path and painting the log red. And the reason `$selname` keeps the
schematic spelling is that 6b's sentence names it, which nothing asserted.
**BN44** drives a prefixed FET whose segment matches nothing, and pins the
sentence verbatim: `'M8' has no level in the simulation data`. Sabotage **S25**.

**B-6 `set ::XSCHEM_LIBRARY_PATH {}` is INERT. CONFIRMED, FIXED.** The write
trace compares the UNQUALIFIED name (xschem.tcl:15219), so the qualified
spelling never fires `set_paths` and the ambient 13-directory path stays.
(This is the repo's own recorded gotcha.) Fixed in this file only — every
neighbouring test carries the same inert line and fixing them is not this
task's business.

**B-7 the seeded inventory's survival across the `partial` reload was
unasserted. CONFIRMED, FIXED** — BN32 gained a fifth leg.

**B-8 five check names overclaimed. CONFIRMED, FIXED.** BN41 said "Ctrl-Alt-V"
when no key event is delivered; BN02 said "consumes"; BN17 said "grew no third";
BN23 says DESIGN context but proves source ORDER. All renamed or qualified.

**B-9 the X arm is silently optional. CONFIRMED, NOT FIXED.** `full_audit.sh`
greps the `RESULT: ALL PASS` string without comparing counts, so all ten X-only
checks could vanish and the file would still score PASS. This is the shared
house idiom in every sigbrowser file; changing it here alone would be a private
convention. Recorded.

**B-10 two stubs hide what two checks are about. ACKNOWLEDGED, declared.**
`wviewer::open` stubbed removes the very context switch BN23 guards (that is
S14's row, and it says so), and `session_for_current` pinned to level 0 leaves
the `$drop`-before-append landmine to `_i12`'s BX48.

**B-11 the in-file sabotage table was inconsistent. PARTLY a stale read, one
real correction.** The reviewer read the pre-measurement draft; the table had
already been replaced by a measured one. But its S3 row did say "every guard
dropped" when the mutation *bypasses* rather than deletes them — corrected. The
table has now been measured twice end to end (16 rows, then 25).

**B-12 BN30 leg 4 / BN31 leg 3 are mildly tautological.** Kept as
preconditions, and now listed in the table's explicit "reached by no mutation"
group with the reason.

### Categories that yielded NOTHING (checked, not assumed)

Ancestor segments needing the same treatment (0 of 1408 descendable symbols use
`@spiceprefix`, and `sim_sch_path` never transforms a name); escaped
`\@spiceprefix` in any shipped format (none); `@spiceprefix` reachable only
after Tcl evaluation in a shipped format (none); the other consumers of
`$selname` (`browser_digital_probe` and 6b — both verified clean, and `$base` is
captured before the append); `wvproc_body` matching prose rather than code (it
strips whole-line comments and no extracted body has a trailing `;#`).

---

## 6. Suites

Run TWICE — once on the first version, once on the post-review code. Both under
`GUI_GATE=1` through `run_suites.sh`, panel approved, display `VERDICT: HEALTHY`.

### 6.2 The post-review run — 18 suites, 15/18

Same family plus `test_ase_final` and `test_ase_final_gf180` (added because the
review's A-1 finding made the gf180 workarea part of this fix's blast radius).
Everything in the family PASSED, including `_0319` at **35 checks**. Three reds,
all attributed:

| suite | result | attribution |
|---|---|---|
| `_i1315` | 2 FAILED (189 passed): `BR25`, `BP77` | `BP77` is the LEDGER's own documented `:0` sash-geometry flake; `BR25` is a `<Return>` key-delivery stall, the tree's known ~1-in-5 `event generate` flake. This file also passed 191/191 four times earlier today, twice PRISTINE. |
| `test_ase_final` | 1 FAILED (9 passed) | **PRE-EXISTING.** A/B measured: identical failure with my `src/ase.tcl` STASHED — `ase: design sky130_tests/test_nfet_final is not the current schematic`. |
| `test_ase_final_gf180` | 1 FAILED (10 passed) | **PRE-EXISTING**, same A/B, same sentence for the gf180 cell. |

Both `test_ase_final*` are `PASS` in the 2026-08-09 baseline, so they are a
pre-existing drift this change did not cause and does not fix.

### 6.1 The first run — 16 suites, 14/16

**14/16 runs passed**, and both NORESULTs are batching artefacts, re-measured:

| suite | batched | standalone |
|---|---|---|
| `test_wave_sigbrowser` | PASS (353) | — |
| `_sea` | PASS (79) | — |
| `_panes` | PASS (81) | — |
| `_2pane` | PASS (108) | — |
| `_i11` | PASS (74) | — |
| `_i12` | PASS (126) | — |
| `_i14` | PASS (109) | — |
| `_i1315` | **NORESULT** | see below |
| `_keys` | PASS (49) | — |
| `_digital` | **NORESULT** | **PASS (82)** |
| `_0312` | PASS (69) | — |
| `_0315` | PASS (28) | — |
| `_0318` | PASS (17) | — |
| **`_0319` (new)** | **PASS (30)** | — |
| `test_ase_cosim` | PASS (342) | — |
| `test_wave_sigsearch` | PASS (233) | — |

**`_i1315` was chased to ground rather than waved off.** It was NORESULT once
batched and once standalone (both `exit 1 — binary never reported`, i.e. the
process died before printing its banner — the WSLg shape, and the panel did in
fact die and revive at 11:08:40 this session). Then:

* driven directly through `gated_xschem.sh`: **ALL PASS (191 checks)**
* `run_suites.sh -n 2` on the **PRISTINE** tree (my `src/ase.tcl` stashed):
  **2/2 PASS (191, 191)**
* `run_suites.sh -n 2` with the change restored: **2/2 PASS (191, 191)**

and the file contains **zero** references to `inst_path_segment`,
`spice_seg_name`, `show_in_browser_for_current` or `browser_sel_segment`. Not a
regression. (The LEDGER already records that this file's X count is 190 *or*
191 on identical bytes; mine measured 191 four times.)

---

## 7. The audit, diffed by test NAME

`GUI_GATE=1 bash tests/headless/full_audit.sh` on the FINAL tree, display
`VERDICT: HEALTHY` before and no panel death during it.

```
SUMMARY: 290 pass  23 fail  1 crash/timeout  1 skip  (total 315)
WIREEDIT: ALL PASS          SCRATCH: 0 leaked dir(s)
```

**The count is not the evidence — the names are.** Diffed against
`doc/claude/batch_F/baseline_status.txt` (2026-08-09, 306 audit rows + 58
wireedit rows).

### RED-WARD: four rows. ALL FOUR GREEN WHEN RE-RUN STANDALONE.

| row | audit | standalone re-run |
|---|---|---|
| `test_altf5_ciw` | FAIL | **ALL PASS** (`--logdir`) |
| `test_delete_cut_selflog` | SKIP | **ALL PASS** (`--logdir`) |
| `test_hover_highlight` | FAIL | **ALL PASS** |
| `test_wave_sigbrowser_i1315` | FAIL | **ALL PASS (191)** — and 4× today, twice on the PRISTINE tree; the two reds are `BP77` (the LEDGER's own `:0` sash flake) and `BR25` (key delivery) |

`_i1315` is the only one of the four inside this change's blast radius, and it
is green four times over, twice with `src/ase.tcl` stashed.

### GREEN-WARD: eight rows

`test_ase_persist`, `test_ase_plot` (TIMEOUT→PASS), `test_fluid_bodyshove_
guards_0132`, `test_rotate_stretch_dangling_0103`, `test_wave_axis_zoom`,
`test_wave_crossdb_trace`, `test_wave_markers`, `test_wire_vertex_grab`.

### NEW SINCE THE BASELINE: nine rows, all PASS

`test_backannotate_digital`, `test_cosim_golden_e2e`, `test_raw_read_failure_
0306`, `test_wave_cursor_crossdb`, `test_wave_sigbrowser_0312`, `_0315`,
`_0318`, **`_0319` (this change)**, `test_wave_sigbrowser_digital`.

### ONLY IN THE BASELINE

The 58 `test_wireedit_*` rows, which the baseline lists individually and
`full_audit.sh` reports as the single line `WIREEDIT: ALL PASS`. Not a
disappearance.

### The whole sigbrowser family in this run

`test_wave_sigbrowser`, `_0312`, `_0315`, `_0318`, **`_0319`**, `_2pane`,
`_digital`, `_i11`, `_i12`, `_i14`, `_keys`, `_panes`, `_sea`,
`test_wave_sigsearch` and `test_ase_cosim` — **all PASS**; `_i1315` as above.

### A note on `test_ase_final` / `test_ase_final_gf180`

Both **PASS in the audit** (and PASS in the baseline), so they are not part of
this diff. They FAIL when I drive them by hand through `gated_xschem.sh` —
`ase: design … is not the current schematic` — and that failure is
**pre-existing and environment-dependent**: A/B measured, identical with my
`src/ase.tcl` STASHED. Recorded because §6.2 reports the hand run.

### One honesty note about the tree that was audited

One COMMENT-only edit landed in `src/ase.tcl` after the audit finished (the
digit-fixture description in `inst_path_segment`). `wvproc_body` strips
whole-line comments, so no check in the tree can see it, and the file was
re-run green (35/35) afterwards. No executable line changed after the audit.

---

## 8. What this does NOT claim

* **It does not claim the pixels were seen.** Every X check reads widget state —
  `browser_devint`, the treeview selection, the captured echo — not an image.
  The issue is marked **FIXED pending an eyeball** and carries GUI steps.
* **It does not claim a raw was read.** The 69 MB `tb_bandgap_ase.raw` is a user
  artifact outside the repo; BN3x/BN4x seed the inventory with 11 names copied
  verbatim out of its header and let the shipped `browser_refresh` build the
  tree. The class filter, the row model, the resolver and the R12 probe are all
  the shipped code.
* **It does not claim every device class is covered.** Measured: sky130 FETs
  (instance-carried and template-inherited prefix), an ammeter, a parax_cap, a
  vsource, a subcircuit and `netlist_options`. Resistors, capacitors and diodes
  in other PDKs use the same `@spiceprefix@name` idiom but were not measured
  one by one.
* **It does not claim the MIRROR direction works.** `wviewer::hier_resolve`
  (browser node → schematic descend) has no such rule, so "Descend to here" on
  the very row this gesture now selects refuses. The refusal is the right
  OUTCOME (a primitive has nothing below it) and the wrong REASON. Not a
  regression, but newly reachable — **filed as issue 0321** rather than
  widening this one.
* **It does not claim anything about issues 0318, 0320 or 0315.** None were
  touched.
