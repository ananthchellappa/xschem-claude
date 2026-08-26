# 0838 — a FAILED run leaves `Results > Annotate` live, and annotating then paints the PREVIOUS run's numbers

Status: **FIXED 2026-08-26.** The predicate is now
`ase::results_stale` (`src/ase.tcl`) and it gates all three doors: the menu
greying, the menu tick's raw-attach, and the `6`/`Alt-6` chords.
`tests/headless/test_results_freshness.tcl`, 20 checks, ALL PASS; five sabotages
red the right rows including the over-tightening direction. Verified against the
user's OWN artifacts: `results_stale = 1`, `has_results = 0`, `last_rawfile`
still non-empty. Originally measured on the real bench 2026-08-26, reported by
the user.
Severity: **HIGH. Silent wrong data.** The tool showed operating-point numbers for
a netlist that had just failed to simulate, with no visual difference from a good
run. This is the worst failure class an analog tool has.
Related: 0625 (the `-` placeholder), 0682 (which moved this control to ASE-L),
0683, 0684, 0807/0813/0814 (the stale-raw family), 0836.

## The user's report, verbatim

> I ensure that "Save OP info" is NOT checked and then, uncheck OP and TRAN
> simulations in the Analysis pane and do Netlist and Run and see an error in the
> simulation log window that pops up. But, now, results > Annotate > Operating
> Point Info and Node voltages are NOT greyed out and I am able to annotate with
> 6 and Alt-6.
>
> I can descend into x1 > x1 and see FET info like id and gm

and, separately, on two clean relaunches with **no run at all**:

> Results > Annotate entries are NOT greyed out.

## Measured — the file times prove it

`~/.xschem/simulations/`, `ls --time-style=+%F_%T`:

```
tb_bandgap_ase.spice  2026-08-26_08:57:59   <- deck, just netlisted
tb_bandgap_ase.log    2026-08-26_08:58:02   <- exit 1
tb_bandgap_ase.raw    2026-08-26_08:52:31   <- 5m28s OLDER than the deck
```

`tb_bandgap_ase.log` tail:

```
Error: incomplete or empty netlist
       or no ".plot", ".print", or ".fourier" lines in batch mode;
no simulations run!
=== exit 1 after 3.22 s ===
```

`no simulations run!` — and the `id`/`gm` the user then read off the FETs came
from the **08:52:31** raw. The action log `/tmp/Xschem.log.9` records the whole
sequence in order: `xschem netlist …` → `#= ase: simulation finished (exit 1)` →
`xschem descend -inst x1` ×2.

## Root cause — one line

`src/ase.tcl:1267`:

```tcl
proc ase::has_results {key} {
  return [expr {[ase::last_rawfile $key] ne {}}]
}
```

and `src/ase.tcl:1237-1244`:

```tcl
proc ase::last_rawfile {key} {
  ...
  if {$rf ne {} && [file isfile $rf]} { return $rf }
  return {}
}
```

**The predicate is `[file isfile]`.** It asks *"does a raw file exist on disk"*,
not *"does this session have results for THIS deck"*. It cannot distinguish:

* a raw from the run that just succeeded,
* a raw from a run that succeeded five minutes and one netlist ago,
* a raw from a different day, surviving a relaunch of xschem.

`ase_window.tcl:2244-2251` (`annot_menu_sync`) greys the two entries on exactly
this predicate, so all three read *"has results"* and the menu goes live.

The predicate's own comment (`ase.tcl:1259`) says it is *"SESSION-SCOPED AND
FILE-BASED, and that is the right scope"* — it is right about the **scope** and
wrong about the **question**. 0682's decision D3 asked for one named boolean and
got one; nobody asked whether file existence answers it.

## Why the in-memory exit code cannot fix this alone

`ase::run_finished` does record the exit code — but into `ase.tcl:61`'s
`variable last_run`, which is (a) a **single** namespace variable, not per
session, and (b) **in memory only**. It does not survive the relaunch, which is
the case the user hit twice. The durable evidence has to come off the filesystem.

## As fixed (2026-08-26)

The predicate is spelled **`ase::results_stale`**, a POSITIVE claim, not
`results_current`. That is not cosmetic. A `current`-shaped predicate has to
answer 0 for *"unknown session key"*, *"no state dict"*, *"unreadable mtime"* —
and 0 there means REFUSE, so it silently conflates *"I don't know"* with *"it's
stale"*. Measured during implementation: the `current` spelling made
`cadence::_annot_raw_candidate` report `stale` for any session whose state it
could not resolve, which reddened `test_op_annot` row N11 (whose fixture stubs
`ase::last_rawfile` but not the new seam). Two callers want opposite defaults
from the unknown case and only the positive spelling gives both what they want.

Three doors, one predicate:

| door | file | behaviour on a stale raw |
|---|---|---|
| menu greying | `ase::has_results` → `ase.tcl` | both entries **disabled** |
| the tick's raw-attach | `ase::ui::annot_ensure_loaded` → `ase_window.tcl` | refuses, and `ase::echo`s why |
| the `6` / `Alt-6` chords | `cadence::_annot_raw_candidate` → `annot_mode.tcl` | new `stale` state + status message |

⚠ **The chord door does NOT fall through to the `netlist_dir` arm on a refusal.**
That arm reaches for `$netlist_dir/$cell.raw` — very often the same stale file
under another name — and falling through would have turned the refusal into a
silent success.

⚠ **`ase::last_rawfile` was deliberately left LOOSE.** Its three other callers
(`ase_window.tcl` :2118, :4035, :4583) are all waveform-plotting paths, and
plotting the last good run's traces after a failed netlist is legitimate.
Refusing that would have traded this defect for a regression. Row **W1** pins it:
`last_rawfile` still returns the stale raw while `has_results` refuses the very
same file.

`ase::deck_file` was added as the one owner of `<rundir>/<cell>_ase.spice`, and
`ase::run`'s render site (`ase.tcl:995`) now goes through it, so the compared
path cannot drift from the written one.

## Fix — the invariant

**A raw describes a deck. It is usable iff it is at least as new as the deck it
claims to describe.**

```
mtime(<cell>_ase.raw) >= mtime(<cell>_ase.spice)
```

That single test rejects every case above:

| case | deck | raw | verdict |
|---|---|---|---|
| run succeeded | T | T+n | **live** |
| run failed after a netlist | T | T-328s | **greyed** ← the reported bug |
| never ran this session, raw+deck both old and consistent | T-1d | T-1d+n | **live** — correct, this is annotating saved results, which Cadence also allows |
| netlisted, never ran | T | T-1d | **greyed** |

Add the in-session exit code as a *second, additive* gate (a run that exits
non-zero greys the entries immediately, without waiting for anyone to look at
mtimes), but do **not** make it the primary test — it is not durable.

⚠ **`mtime` alone is not a freshness proof for a RUNNING sim.** ngspice writes
`No. Points: 0` at the start of a run and backfills at the end (issue 0299), so a
raw can be newer than the deck and still be a zero-point file. That is 0836's
territory and is not this issue's to solve; the two compose (0836 guards the
read, 0838 guards the offer).

⚠ **Do not fix this by deleting the stale raw at netlist time.** The raw is the
user's data — a netlist that silently destroys the previous run's results would
trade a wrong number for a lost one. Grey the control; leave the file.

## Acceptance

1. Netlist a deck that fails to run (uncheck every analysis). Both
   `Results > Annotate` entries are **greyed** after the run finishes.
2. The `6` and `Alt-6` chords in that state annotate **nothing** — see the ⚠
   below.
3. A successful run makes both entries live, and annotation shows THAT run's
   numbers.
4. Relaunch xschem with only an old raw and an old deck present, consistent with
   each other: entries are **live** (annotating saved results is legitimate).
5. Relaunch with a raw OLDER than the deck: entries are **greyed**.
6. The greyed state is reachable in the GUI *and* readable headlessly, so it gets
   a test row rather than only a look debt.

⚠ **ACCEPTANCE 2 IS A SEPARATE DEFECT AND IT IS NOT FIXED BY THIS ISSUE.**
`cadence::annot_mode` (`utils/annot_mode.tcl:276`) has **no session gate at all**
— verified, there is no `annot_binding_ok` in that file — so `6` / `Alt-6` /
`Ctrl-6` write `annot_show` regardless of what the menu says. Greying the menu
while leaving the chords live would make the menu a decoration. Filed as part of
this issue's fix scope; the chords must consult the same one predicate.

## Still open

* **Which surface tells the user WHY it is greyed.** A greyed menu item with no
  explanation is the complaint 0683 already collected about the stock refusal
  notice. Unratified — `rule` debt.
* **The two-relaunch reports have a second cause not yet separated.** On the
  relaunches the user did not run at all, so the deck may also predate the raw
  and rule 4 would legitimately show them live. The reported bug is
  reproducible from the failed-run case alone; the relaunch case needs one more
  measurement to say whether it is the same defect or correct behaviour that
  merely looks wrong.
