# 0217 — ngspice device-class prefixes render as fake hierarchy levels in the Signal Browser

Status: **FIXED** 2026-08-07 — `wviewer::sig_declass` + `wviewer::sig_class`, item 1 of the
two-pane Signal Browser batch (`doc/claude/specs/waveform_signal_browser_two_pane.md` §3).
Both rulings owed below were taken by the driver: the `class` field **YES** (§3.2), device
internals hidden by default behind a toggle **YES** (spec R11). Covered by the 32-check DC
group in `tests/headless/test_wave_sigsearch.tcl`, with all three sabotages here run and
caught (DC09 / DC12 / DC13), each with a positive control on the same fixture.

⚠ **One claim in this file is WRONG and is corrected in place below**: §"Consumers" names
`tests/headless/test_ase_hier_pick_0161.tcl` as affected. It is not — that file calls no
`wviewer::` proc; it merely contains the literal `i(v.x1.x2.v1)` as an ASE pick-naming
expectation produced by ASE's own naming code. Measured: it passes unchanged (21 checks).

Originally filed as: **OPEN**. A real defect, not a declared limit. Pre-existing since Signal Browser
item 9 (the tree); the same wrong split also reaches `Descend to here` (item 11).
Found by: the user, reading a browser row and asking *"there is no `m` instance in
tb_bandgap — what is the `m` in `v(m.x1.x2.x3...)`?"*
Spec: `doc/claude/specs/waveform_signal_browser.md` §5 (ruling 14), §10.
Map: `doc/claude/code_analysis/signal_browser_reference.md` §3.

## Symptom

The Signal Browser's tree shows top-level nodes that **do not exist in the design**. For
`tb_bandgap`, whose netlist has exactly one subcircuit instance (`x1`) plus voltage sources,
the tree's top level is:

| node | signals | is it real? |
|---|---|---|
| `m` | 234 (55%) | **no** |
| `v` | 50 (12%) | **no** |
| `x1` | 122 (29%) | yes |
| bare nets (`vbg`, `clk`, `vss`, …) | 18 | yes |

Netlist, verbatim (`tb_bandgap.spice`): `x1 START CLK EN_N VBG VCC VSS bandgap`, then
`V1`…`V5`, `VCC`, `XQ1`, `XQ2`, `Vc1`, `Vb1`, `Vb2`, `Vc2`. **There is no `m` instance and
no `v` instance.**

Measured across all 22 raws in `tests/headless/.scratch/0211/work/run_new/`:
**2026 of 2338 hierarchical signals — 87% — sit under a fake root.**

```
m     1400 signals      @c     61
@m     360              @r     24
v      155              @b     15
                        @q     10 , n 1
```

## What the prefixes actually are

They are ngspice **device-class tags**, applied only when the object lives *inside* a
subcircuit:

| form | meaning | measured signature |
|---|---|---|
| `v(m.<path>.<dev>#<node>)` | internal MOSFET nodes — sky130 runs BSIM4 `RBODYMOD`, so every MOS gets `#body`/`#dbody`/`#sbody` | 1400 signals, **100% `voltage`, 100% leaf contains `#`** |
| `v(n.<path>.<dev>#…)` | same class, other device | 1 signal, voltage, leaf contains `#` |
| `i(v.<path>.<vsrc>)` | branch current of a voltage source inside a subcircuit | 155 signals, **100% `current`, 0% `#`** |
| `i(@m.<path>.<dev>[id])` | device *parameter* accessor | 360, mostly `current`, never `#` |
| `@c` `@r` `@b` `@q` | ditto, per device class | 110 total |

The tell-tale: **at the top level ngspice adds no prefix.** The same raw carries bare
`i(v1)`, `i(vcc)` for top-level sources but `i(v.x1.v1)` for one inside `x1`. The prefix
exists only to reach inside.

So in `v(m.x1.x1.x1.xm1.msky130_fd_pr__nfet_01v8#body)` the real design path is
**`x1.x1.x1.xm1`** and the real leaf is `msky130_fd_pr__nfet_01v8#body`. The `m.` is a
namespace tag bolted on the front.

## Mechanism

`wviewer::sig_split` (`src/wave_viewer.tcl:1726`) splits the unwrapped name on its last dot
and hands everything before it to `browser_rows` (`:6008`), which mints one tree node per
dot segment. It has no notion of a class prefix, so the tag becomes a hierarchy level.

Measured, current behaviour:

```
v(m.x1.x1.x1.xm1.msky130_fd_pr__nfet_01v8#body)  -> path 'm.x1.x1.x1.xm1'  leaf 'msky130_..#body'
i(v.x1.v1)                                       -> path 'v.x1'            leaf 'v1'
i(@m.x1.xm1.msky130_fd_pr__nfet_01v8[id])        -> path '@m.x1.xm1'       leaf 'msky130_..[id]'
v(x1.adj)                                        -> path 'x1'              leaf 'adj'     (already correct)
```

## Two consequences worse than the clutter

1. **The real hierarchy is duplicated.** A net inside `x1.x1.x1` files under
   `x1 > x1 > x1`. A MOS internal node at the *same design location* files under
   `m > x1 > x1 > x1 > xm1`. The same place appears in two unrelated branches, so a user
   expanding `x1` sees only part of what is there.
2. **`Descend to here` cannot work on 87% of the tree.** `browser_target_path` (`:7321`)
   returns `m` / `v` / `@m…` as the instance path, and `hier_walk` then tries to descend
   into an instance that does not exist. It fails loudly rather than silently, but it fails.

## Why the fix is sound, not a heuristic

**SPICE grammar guarantees it.** A hierarchy level in a raw name comes from a *subcircuit
instance*, and SPICE requires subcircuit instances to begin with `X`. A device-class tag is
exactly one letter (optionally `@`-prefixed), and a one-letter segment therefore **cannot**
be a subcircuit instance — `m…` parses as a MOSFET, not a subckt call.

Corroborated: every real root in the 22-raw corpus starts with `x`
(`x1 x2 x3 x4 x7 x10 xr1 xr2`); every fake root matches `^@?[a-z]$`. Zero overlap.

**Rule:** if the first segment of the unwrapped name matches `^@?[a-z]$` (case-insensitively
— ngspice lowercases) **and** at least two segments follow, it is a device-class tag: strip
it, then split normally.

Applied to the four cases above:

```
-> path 'x1.x1.x1.xm1'  leaf 'msky130_fd_pr__nfet_01v8#body'
-> path 'x1'            leaf 'v1'
-> path 'x1.xm1'        leaf 'msky130_fd_pr__nfet_01v8[id]'
-> path 'x1'            leaf 'adj'                            (unchanged)
```

### Declared residual risk

A top-level *net* named `m` cannot collide (nets carry no dots). A subcircuit instance named
`m` cannot exist (SPICE grammar). The only way to defeat the rule is a non-SPICE producer
writing a raw with a one-letter hierarchy level. That is out of scope and should be stated,
not defended against.

## The fix, as a batch item

### Item — `sig_declass`: strip ngspice device-class prefixes before splitting

**Scope.** New pure proc `wviewer::sig_declass {bare}` → `{class rest}`; `{}` class when the
name has no tag. `wviewer::sig_split` calls it before splitting. Nothing else changes shape.

⚠ **Ruling 14 stays true and needs one amendment**: `path`/`leaf` still split the
**unwrapped** name — the class strip is a step *before* the split, not instead of it. Add
the strip to the spec §5 contract text for `sig_split`.

**Files:** `src/wave_viewer.tcl`.

**Consumers — measured, the whole list:** `sig_split` has exactly three callers —
`signal_entry` (`:1737`), `browser_target_path` (`:7323`), and one comment (`:1558`). Both
real callers *want* the corrected value. Two test files reference device-prefixed names:
`test_wave_sigsearch.tcl` and `test_ase_hier_pick_0161.tcl`.

**Test (as shipped):** 32 checks, prefix `DC`, in `test_wave_sigsearch.tcl`. Two existing
checks were re-pinned: SB07 `sig_split {@m.x1.m1[id]}` `{@m.x1 …}` -> `{x1 …}`, and SB10's
`signal_entry` key set `{leaf name path type}` -> `{class leaf name path type}`. MEASURED
safe and confirmed: BT10 does **not** red (its `BTFIX` fixture carries no class-tagged
names). Suite total went 660 -> 692 `--nogui` checks, all seven files green.

**Test (as planned):** new checks in `test_wave_sigsearch.tcl` (the `sig_*` file, prefix `SM`/`DS` band).
All pure, all `--nogui`. Cover: each of the six observed classes; the no-tag case unchanged;
a one-letter head with **only one** following segment (must NOT strip — `m.foo` is
ambiguous, and stripping would produce an empty path); case-insensitivity; `@`-forms; a leaf
containing `#` and one containing `[…]`; and the `v(n.xu1.n1#flow(out))` shape, whose leaf
contains parentheses.

**Sabotages (3):**
(a) drop the `≥2 following segments` guard → the `m.foo` check fails;
(b) make the match case-sensitive → the uppercase-name check fails;
(c) strip a two-letter head (e.g. `xm`) → the real-instance check fails, proving the rule
does not over-reach. **Each needs a positive control on the same fixture** — assert the
un-stripped shape is still produced for a real path, or the negative proves nothing.

**Size:** S. **Risk:** low — pure, three callers, both of which benefit.

### Two rulings owed before implementing

1. **Does `signal_entry`'s dict gain a `class` field?** Reference §5 documents
   `{name type leaf path}`. Adding `class` is additive (dict), so existing readers are
   unaffected — and it is what would let the browser badge, group or filter device
   internals later. Recommend **yes**; it is the difference between fixing the tree and
   also enabling the next feature.
2. **Should device internals be hidden by default?** 87% of the corpus is device internals
   and parameter accessors. ADE/ViVA do not show these unless asked. A "show device
   internals" toggle would take `tb_bandgap`'s browser from 424 rows to ~140 — the single
   biggest usability win available in the browser. **This is a product decision, not an
   engineering one**, and it should be ruled on separately from the split fix.

## Interaction with planned work

- **Fix this before the two-pane browser.** A two-pane left tree for `tb_bandgap` would show
  three peers — `m`, `v`, `x1` — two of them fiction holding 67% of the signals. That is a
  worse first screen than today's interleaved tree, where the real top-level nets at least
  appear at the root.
- Independent of `doc/claude/signal_browser_detach_batch/` — the detach batch changes where
  the browser lives, not what it shows. Either order works; this one is smaller.
- Related, **not** the same: **0212** (vector instance slices not addressable) is path
  arithmetic below `hier_walk`; this is path *derivation* above it. Fixing 0217 does not
  fix 0212.
- The other live `browser_target_path` defect found in the same pass — group ids prefixed
  `d:N|` by `browser_rows_reparent` are mis-decoded by `[string range $id 2 end]` at `:7321`,
  so `Descend to here` is *enabled* on foreign All-DBs rows and fires a garbage path — is a
  **separate** bug in the same proc. File and fix it independently; both touch `:7321` and
  will conflict if scheduled in parallel.
