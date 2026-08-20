# 0508 — the Waves-menu result chooser discards the whole registry, and no test drives it

**Status:** **FIXED 2026-08-20** — results batch item 8, branch `fluid-editing`.
⚠ **FIXED HERE MEANS GATED, NOT REPAIRED. `xschem raw_read` STILL CLEARS THE
WHOLE REGISTRY, AND OUTSIDE `cadence_compat` THE WAVES MENU STILL REACHES IT.**
Read the *Resolution* section below before assuming the destructive behaviour is
gone; it is not, and that is a user ruling (U4/U12), not an oversight.
Measured on branch `fluid-editing` at `58b2c24d`, 2026-08-18.
**Area:** `proc load_raw` / `proc waves` / `proc select_raw`
(`src/xschem.tcl:16874` / `:6373` / `:16672`), the Waves menubar cascade
(`src/xschem.tcl:17332-17348`), the `raw_read` and `raw_clear` scheduler arms
(`src/scheduler.c:10850` / `:10835`).
**Found:** 2026-08-18, mapping xschem's surfaces against Cadence ADE-L's
`Results > Select…`.

> **Line numbers in this issue were RE-DERIVED 2026-08-20** when item 8 closed
> it. The `src/scheduler.c` numbers as filed (`:10776`, `:10761`, `:10791`,
> `:10810`, `:10380-10404`) were staled by items 1 and 3 of the results batch,
> which added `raw select` and `raw non_spice` to the same file; the
> `src/xschem.tcl` numbers were staled by item 2's `source results.tcl` block and
> again by item 8's own gate. This is landmine **L9** and its twin — see
> `doc/claude/specs/results_selection.md` §11.

---

## What

Two `xschem` verbs are one underscore apart and do **opposite** things to the
raw registry:

| verb | registry effect | implementation |
|---|---|---|
| `xschem raw read <file> [type]` | **appends** a database and makes it current | `extra_rawfile(1 \| RAW_READ_REBIND, …)`, `scheduler.c:10355` |
| `xschem raw_read <file> [type]` | **clears every loaded database**, then reads | `extra_rawfile(3, NULL, NULL, …)` at `scheduler.c:10865`, then `read_rawfile_by_type()` at `:10884`; arm `:10850-10889` |

The arm's own header comment (`scheduler.c:10844-10849`) says only *"If a raw
file is already loaded delete from memory"* — singular, which reads as "replaces
the current one", not "empties the registry". The registry-wide truth is stated
only in an unrelated inline comment further down the same arm, where it is
mentioned in passing as a precondition for something else — nowhere a caller
would look.

**The schematic editor's only result chooser uses the destructive one**, and
belts it: `load_raw` (`xschem.tcl:16874-16898`) calls `xschem raw_clear` first
and *then* `xschem raw_read`, so the wipe happens twice. **Eight** Waves-menu
entries route there — `Load first analysis found`, `Op`, `Dc`, `Ac`, `Tran`,
`Noise`, `Sp`, `Spectrum`, all via `waves <type>` → `load_raw`. The other three
do not: `External viewer` takes the `waves external` branch, `Clear` calls
`xschem raw_clear` directly and openly, and `Op Annotate` calls `select_raw`
itself.

## Measured

```
== 'xschem raw read' (space) — the APPEND verb ==
after two 'raw read': registry holds 2 databases
1 current
0 .../srlatch/srlatch_ase.raw dc
1 .../cmos_ac_sweep/cmos_ac_sweep_ase.raw ac

== 'xschem raw_read' (underscore) — what the Waves menu uses ==
free_rawfile(): clearing data
free_rawfile(): clearing data
after one 'raw_read': registry holds 1 databases
0 current
0 .../tb_diff_amp/tb_diff_amp_ase.raw dc
```

`src/xschem --nogui --pipe -q --script`, 2026-08-18. Two databases the user had
open are gone, with no prompt and no message — the only trace is two
`free_rawfile(): clearing data` lines at `dbg` level.

## Why it matters

The registry is not bookkeeping. Things reference it by name:

- a graph rect carries `rawfile=` + `sim_type=` and its `node=` tokens may carry
  a `%<dataset> <rawfile>` suffix resolved through `node_token_split()`;
- the signal browser's **All DBs** search walks every loaded database;
- ASE-L's cosim attaches VCDs *alongside* the raw (`ase::attach_dbs`,
  `ase.tcl:2866`, which deliberately purges and re-reads in a controlled order).

So picking a Tran result from the Waves menu can silently drop the VCD half of a
mixed-signal session, or the second database a graph was comparing against, in
the same window. The user asked to *load a result*; they were not told they were
also unloading three.

Note the blast radius is one `xctx` — the registry is per window/tab
(`xschem.h:2036-2043`) — which is why this has survived: it does not disturb a
*separate* viewer window.

## And no test drives any of it

```sh
grep -rn "select_raw\|load_raw" tests/
```
returns four hits in two files, and **not one of them executes the path**:

- `tests/headless/test_backannotate_digital.tcl:303`, `:691` — prose comments
  about `select_raw`'s dialog.
- `tests/headless/test_wave_sigbrowser_i1315.tcl:7`, `:426-431` — BR04, which
  greps the **string** `select_raw` out of `wviewer::rawbar_browse`'s body
  (captured at `:354`) to prove the viewer's Browse button reuses it rather than
  reimplementing a second file dialog. That is a source-text assertion about a
  *different* proc, and it never executes either one.

So the surface every reader named as xschem's closest analogue to
`Results > Select…` has **zero functional coverage**: nothing asserts what the
registry looks like before and after, nothing asserts the cancel case
(`select_raw` returns `{}` and `load_raw` silently does nothing), nothing
asserts the `type ne {}` branch.

⚠ **A test cannot get the cancel case by running headless.** `select_raw`
computes a guessed default (`$netlist_dir/<cell>.raw`) *first* and only
overwrites it with `tk_getOpenFile` inside `if {[info exists has_x]}`
(`src/xschem.tcl:16676-16684`) — with no `has_x` it returns the **guess**, not
`{}`. The cancel arm has to be reached by shimming `select_raw`.

## Fix

1. **Decide the semantics and write them down.** Either
   (a) `load_raw` moves to the appending `xschem raw read`, and the Waves menu
   grows an explicit `Clear` (it already has one at `xschem.tcl:17262`), or
   (b) the replace-everything behaviour is kept as deliberate and *said so* — in
   the menu label, in `raw_read`'s comment, and in the spec.
   (a) is the better answer if `doc/claude/specs/results_selection.md` lands,
   because that feature is precisely "hold several results, pick which is
   current".
2. **Rename or alias so the two verbs cannot be confused.** `raw_read` is
   upstream and load-bearing (141 launcher instances across the three PDK
   workareas call it, plus `raw_read_from_attr`), so it cannot simply go — but
   its comment must state *"clears the entire registry first"*.
3. **Cover the path.** A headless case that: loads two databases with
   `raw read`; drives `load_raw` with `select_raw` shimmed to return a path;
   asserts the resulting registry; repeats with the shim returning `{}` (cancel)
   and asserts **nothing changed**. Shimming `select_raw` is the established
   idiom — `test_calc_skeleton.tcl` S26 shims the Calculator's whole resolution
   order the same way.

## Related

- issue **0507** — `raw_is_loaded` parses `xschem raw info` by word; the sibling
  defect on the same selection path.
- `doc/claude/specs/results_selection.md` — the feature that makes the
  append-vs-replace question user-visible.
- `doc/claude/specs/simulator_profiles.md` §14.7 — the existing enumeration of
  raw-adopt paths and which of them skip `ase::raw_content_verdict`.

---

## Resolution — 2026-08-20, results batch item 8

**Fix option (b) was taken, in the narrow form user ruling U4/U12 specifies: the
menu is GATED on `cadence_compat`, not repaired.** The Waves menu is legacy
upstream xschem — `proc waves` arrives in `5e8df730`, *"populating xschem git
repo"*, the repo's first commit, and the menubar it hangs on came from
`b23b162f`. The direction is away from it, and repairing it in place would be
adopting it. Spec: `doc/claude/specs/results_selection.md` R505, §7.2 (rulings
R505a–R505d) and §17.2.

### What is TRUE AFTER the fix — the part a reader must not get wrong

- **`xschem raw_read` is unchanged.** Not one line of C was touched. It still
  does `extra_rawfile(3, NULL, …)` and then reads, i.e. it still clears the whole
  registry, and `raw_read` is still one underscore away from the appending
  `raw read`. Item 8 declined the rename in point 2 below as well.
- **WITHOUT `cadence_compat` (the default, `set_ne cadence_compat 0`,
  `src/xschem.tcl:18435`) the Waves menu behaves EXACTLY as this issue
  describes.** Two loaded results in, one out, no prompt, no message. That is
  ruled deliberate: *"a user outside Cadence mode may mess things up if they
  wish"*. The behaviour is now **documented** — in the block comment above
  `proc load_raw`, in spec §7.2, and here — rather than fixed.
- **WITH `cadence_compat` set**, the eight loading entries (`Load first analysis
  found`, `Op`, `Dc`, `Ac`, `Tran`, `Noise`, `Sp`, `Spectrum`) and `Op Annotate`
  refuse with a sentence that says why, names `cadence_compat` twice (the setting
  and the way out), and points at `ASE-L ▸ Results ▸ Select…` — a menu entry
  that exists as of results batch item 7, so the sentence is a direction and not
  a promise. Nothing is greyed out: U12 says a blocked entry *says why* when
  clicked. **Fixer round, 2026-08-20 (spec §7.2, R505e–R505g):** the eight
  loading entries and `Op Annotate` state **different** reasons, because
  `annotate_op` does a targeted delete plus an appending read and does **not**
  wipe the registry — telling its user it did would have been a sentence this
  item measured to be false; the pointer also names `Tools ▸ Launch ASE-L`,
  because `Results ▸ Select…` exists only on an ASE-L session window; the flag is
  read with Tcl's boolean rules, so `set cadence_compat true` no longer walks
  through the gate while C considers Cadence mode on; and a second blocked click
  while the refusal box is still up retexts that box instead of throwing
  `window name "alert" already exists in parent` out of a menu `-command`.
- **`Clear` and `External viewer` keep working in both modes.** Neither loads a
  result, and the `Clear` entry's `xschem raw_clear` is the sole permitted caller
  of that verb on this surface.

### Point 3 — the coverage half — IS fully paid

This issue's second complaint was that the surface had **zero functional
coverage**. `tests/headless/test_waves_gate.tcl` (new, **SEL417-SEL458**, 42
checks with a DISPLAY / 33 without) now:

- takes a **census** of every call site of `xschem raw_clear`, `xschem raw_read`
  and `xschem raw_read_from_attr` across **both** dispatch surfaces for the Waves
  group — `src/xschem.tcl` and `src/actions.csv`'s nine command-palette rows —
  comment-stripped and classified, so a new caller cannot hide (SEL418/SEL419/
  SEL457, with SEL420 proving the detector fires);
- asserts the gate's **ordinal position** inside `load_raw` — before the clear,
  not after it — with SEL422 proving that detector can tell *no gate* from
  *gate too late* (SEL421/SEL423);
- **drives every entry in both flag states**, headlessly through the entry
  commands and through the real menubar with `$m invoke` (SEL430-SEL450),
  asserting the destructive legacy behaviour **positively** when the flag is off
  so *"we broke the menu for everyone"* cannot read as a pass;
- reaches the cancel arm the issue said a headless test cannot get to, by
  **shimming `select_raw`** exactly as recommended (landmine L1: it does not
  return `{}` headlessly, it returns a guessed path and a real selection);
- and, from the fixer round, drives the gate with an **empty registry** in both
  flag states (SEL454/SEL455 — every other drive loads two databases first, so a
  gate conditioned on *"something is already loaded"* passed all 34 of the
  original checks), asserts a refused entry leaves `show_hidden_texts` and
  `tctx::retval` untouched (SEL456), pins the two entries' **different reasons**
  apart off the wire (SEL451), pins the pointer's follow-up step (SEL452), drives
  a ten-row boolean table through `load_raw` (SEL453), and clicks a second
  blocked entry through the real menubar with the **real unshimmed** `alert_`
  (SEL458) — the class no shim-counting check can see.

### What was NOT done, and why

- **Point 1(a) — `load_raw` moving to the appending `xschem raw read`** — is the
  repair U4 declined. Doing it would be adopting the legacy menu.
- **Point 2 — renaming or aliasing `raw_read`** — untouched. It is upstream and
  load-bearing (141 launcher instances across the three PDK workareas, plus
  `raw_read_from_attr`). Its comment still says *"if a raw file is already loaded
  delete from memory"*, singular, which is the misleading wording this issue
  named; correcting that comment is a C-side change item 8's fence excluded.
  **If someone reopens this, that comment is the cheapest remaining win.**
- **Two verbatim twins one menu over are left open on purpose** and are recorded
  in spec §18: `Simulation ▸ Graphs ▸ Annotate Operating Point into schematic`
  (`src/xschem.tcl:17709-17718`, the same body as `Op Annotate`) and
  `Simulation ▸ Graphs ▸ Add waveform reload launcher`
  (`src/xschem.tcl:17704-17708`), which places a symbol whose `tclcommand=` is a
  bare registry-clearing `xschem raw_read` — a drawn object inside a `.sch`, i.e.
  U10's territory.
