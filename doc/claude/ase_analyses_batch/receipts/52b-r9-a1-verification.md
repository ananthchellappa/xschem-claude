# 52b — independent verification of ⚖ R9 ruling A1 (receipt 52)

**Role:** independent verifier. I did not implement, commit, or fix anything. The working tree was
handed to me with receipt 52's uncommitted work in it; HEAD was `89677ac5` at start and at finish,
and `git status` shows the same seven modified paths it showed at hand-over.

**Brief's two exclusions honoured:** the duplicated empty `### ✅ CONSEQUENCE` heading near line 147
of `R9_COPY_REVIEW.md` and the missing `R9` handle for the new `noise` sentence are the driver's and
were neither verified nor touched.

**Standing rules:** binary always by path (`./src/xschem`, `tests/headless/devdisplay.sh exec`),
always `--nolog`, never `--logdir`, never a bare `xschem`. No `git checkout --` / `restore` / `stash`
/ `clean` / `commit` / `push`. No simulation under `sky130A/`. Every command under `timeout`; the one
wait that outlasted a tool call (T1) carried a self-announcing deadline and was polled. Processes
matched by name (`ps -eo pid,comm=`), never by a pattern my own argv contained; no `pkill`.

---

## Verdict summary

| # | claim | verdict |
|---|---|---|
| 1 | Part 1 — plain `Number of points`, colon is `form_label`'s, arithmetic moved | CONFIRMED |
| 2 | Headline — the shared sentence was false for `noise` and `disto` | CONFIRMED, both binaries |
| 3 | `disto`'s precondition removed from the registry, no other surface moved | CONFIRMED |
| 4 | Part 2 — three lowercased, both `NOT`s rewritten, fragment in all four places | CONFIRMED |
| 5 | The exceptions, and the rows that pin them | CONFIRMED (after correcting my own arms) |
| 6 | Suites, both arms, as a name diff | CONFIRMED; family size misstated (44, not 32) |
| 7 | `G2sens` reds identically on the pristine tree | CONFIRMED |
| 8 | `.state` 104/104, both controls live, driven as a proc | CONFIRMED |
| 9 | Eleven sabotage arms red by name | CONFIRMED by my own arms |
| 10 | `owed.sh` unchanged at 187/70/11 | CONFIRMED |
| 11 | `tclsh run_regression.tcl` solo, baseline zero | CONFIRMED — 0 counted, 83 cases |

---

## 1 — Part 1, the field labels

`src/ase.tcl` registry, four sweep-bearing entries, line numbers as they stand:

| line | entry | label under `lin` |
|---|---|---|
| 26878 | `ac` | `Number of points` |
| 26912 | `noise` | `Number of points` |
| 26999 | `disto` | `Number of points` (never carried arithmetic — R9-040) |
| 27037 | `sp` | `Number of points` |

The trailing colon on the rendered form is `ase::ui::form_label`'s: `src/ase_window.tcl:5266` is
`return "$txt:"`, after the optional unit clause. So `R9-030`'s `Number of points:` is the rendered
form of `R9-011`'s source literal and the colon is correctly excluded from the copy change.

`src/ase_window.tcl` is **not modified** — md5 `b38be6dffdf3b99aa0df5db3a6b476fb`, byte-identical to
`git show HEAD:src/ase_window.tcl`. `git diff --name-only src/` returns `src/ase.tcl` alone.

The arithmetic now lives in `ase::needs_eval`'s `lin_points` arm (`src/ase.tcl:12770`ff), per type.

**Byte-accuracy of `R9_COPY_REVIEW.md` against the source it ships from.** I extracted every changed
handle's fenced `text` block and compared it to the literal in `src/`:

| handle | doc block | source |
|---|---|---|
| R9-011 / R9-040 / R9-051 | `Number of points` | registry lines above |
| R9-030 | `Number of points:` | `form_label` rendering of the above |
| R9-118 | `a noise analysis measures a voltage, and '<outv>' is a current` | `ase.tcl:12610` (`'$outv'`; `<outv>` is the document's pre-existing placeholder convention) |
| R9-138 | `add \`distof1 <mag> <phase>\` to the input source (phase is in degrees)` | `ase.tcl:13095` |
| R9-153 | `a linear sweep of 2 points yields one point, and $sim says nothing about it` | `ase.tcl:12831` |
| R9-171 | `set for the $atype analysis and left in force for every analysis after it -- [ase::opt_leak_why $sim $name]` | `ase.tcl:7792` (continued string; the backslash-newline collapses to the single space shown) |
| R9-078 | `… no deck, no raw, no log. Any files already in [file normalize $rd] are from an earlier run. \`set ase_preflight 0\` leaves this check in force.` | `ase.tcl:13890-13893` with `$rdnote` from `:13886-13889`, which is exactly that sentence and is conditional on the rundir existing, as the note says |
| R9-190 | `NOT OFFERED: [ase::opt_inert $sim $name]` | `ase_window.tcl:9080`, unchanged |

A scan of **every** fenced `text` block in the document for the old spellings
(`gives ONE point`, `measures a VOLTAGE`, `is in DEGREES`, `yields ONE point`, `does NOT disable`,
`NOT put back`) returns **nothing** — no shipped-string block still quotes a string the tree no
longer has. The remaining hits in that file are all in prose or in `*Note:*` lines describing what
the string *used to* say, which is the document's convention.

Handle bookkeeping: 727 lines match `^**R9-`, **726 distinct**, at HEAD and now — the 727th is the
prose range header the receipt names. No duplicate handle number anywhere (`uniq -d` silent). The
document's own `726 strings, from 38 issues` claim at line 14 is intact, and the last handle is
`R9-726`.

## 2 — THE HEADLINE. Re-measured independently, on both binaries

I wrote my own decks (scratchpad only, nothing under `sky130A/`) and ran them on **both** registered
binaries: the fork `/home/analog/dev/ngspice/build-ver_50/src/ngspice` and `/usr/bin/ngspice`
(45.2). Neither crashed nor hung; every invocation returned.

Bench: `v1 in 0 dc 0 ac 1 distof1 1 0 distof2 1 0`, `r1 in mid 1k`, `c1 mid 0 1n`. Counts read from
the **named** plot, with `$plots` printed alongside so an empty answer could not read as a number.

| | `lin 1` | `lin 2` | `lin 3` | `lin 4` |
|---|---|---|---|---|
| `ac` | 1 | **1** — collapses | 3 | — |
| `noise` | **1 point, `$plots` = `const noise1`** | 2, `const noise1 noise2` | 3, `const noise1 noise2` | — |
| `disto` | 3 | **4** | 5 | 6 |

**Identical on both binaries.** So, plainly:

* **`noise lin 1` really does lose the Integrated Noise plot.** `noise2` is not in `$plots` at one
  point and is present from two points up. ngspice also prints
  `Warning: Noise measurement at a single frequency 1000 only!`, which is a warning about the
  frequency, not about the missing plot. The crew's claim is **true as stated**.
* **`disto` really returns N+2 and never collapses** — 3/4/5/6 for 1/2/3/4. The old shared sentence
  told a `disto lin 2` row it would get one point; it gets four. **False as it stood.**

⚠ **A caveat on my first attempt, recorded because it is the shape this batch keeps meeting:** my
first probe script emitted `noise lin 1 1k 11k` with **no output node and no input source** — a
malformed command. ngspice answered with no noise plot at all, which looks *exactly* like the
finding ("`noise1` is all there is"). It was the plot list printed beside the count that showed the
run had not happened (`$plots` was bare `const`, so even `noise1` was missing). The crew's own
correction C4 records the same trap from the other side. A measurement of an absence needs the
positive control, and here it was load-bearing.

**So the registry removal in claim 3 rests on a correct measurement, not a wrong one.** Nothing was
deleted that was working.

## 3 — the `disto` removal

`needs` for `disto` is now `{disto_saves disto_f1src disto_f2src cider_klu}` (`ase.tcl:26993`);
`lin_points` remains on `ac` (26872), `noise` (26904) and `sp` (27022).

Consumers of a `needs` list in shipped code are `ase::analysis_needs` (`ase.tcl:11996`, which simply
iterates), reached from `ase.tcl:13188` and `:13471`. Nothing keys on `lin_points` by name outside
`ase::needs_eval` and the suites. The only suite that enumerates a `needs` list is
`test_ase_effective_1442`'s `RU8`, which moved with the change; `test_ase_trnoise_1466:312` and
`test_ase_trnoise_gui_1467:189` manipulate `needs` but only to strip `stimuli_check`, and both are
green. `disto_saves` is untouched and `test_ase_core`'s `WD5b`/`WD5d` (the two rows that assert
disto's save-list behaviour) are green. **No other surface moved.**

## 4 — Part 2, the shouted words inside sentences

* `VOLTAGE` → `voltage` (`ase.tcl:12610`), `DEGREES` → `degrees` (`:13095`) — confirmed by diff and
  by grep; no `measures a VOLTAGE` or `in DEGREES` remains in `src/`.
* `R9-171`'s `NOT` is **gone, not lowercased**: the sentence is now
  `set for the $atype analysis and left in force for every analysis after it -- [why]`.
* `R9-078`'s fragment: `leaves this check in force` appears **4** times in `src/ase.tcl`
  (lines 13852, 13893, 13946, 13981) and `does NOT disable` appears **0** times. `ase::preflight_gate`
  begins at `:13811`, so **all four are inside that one proc** — the count is exactly four, as
  claimed, and no fifth copy of the fragment exists elsewhere in the file.

## 5 — THE EXCEPTIONS, AND THE ROWS THAT PIN THEM

Unchanged as required:

* `SEGFAULTS` — `ase.tcl:12948`, in the disto refusal, untouched by the diff.
* `NOT OFFERED: ` — **1** occurrence, and it is in `src/ase_window.tcl:9080`, a file that is
  byte-identical to HEAD. `SET ELSEWHERE:` / `CLAMPED:` / `SCOPED:` likewise (`:9081`, `:9082`,
  `:9095`).
* `NOT MEASURED: ` — **10** occurrences, all in `src/ase.tcl`'s option catalogue, untouched.

1 + 10 = the eleven prefixes the ruling kept.

**I broke each exception myself and confirmed the named row goes red** (each arm: restore, mutate,
verify the md5 moved off the finished value, run, restore):

| arm | mutation | suite | reds |
|---|---|---|---|
| S6 | `ngspice SEGFAULTS,` → `ngspice segfaults,` | preflight | `PF234a` **and** `PF230h` |
| S10 | `NOT OFFERED:` → `not offered:` in `ase_window.tcl` | optsheet | `HK4` |
| S11t | first `NOT MEASURED: ` → `not measured: ` in `ase.tcl` | optsheet | `HK5` |

All three exceptions are genuinely pinned: none of the three rows can be satisfied by a tree that has
lowercased the word. The receipt's incidental finding that `PF230h` was pinning `SEGFAULTS`'
capitals by accident all along reproduces.

⚠ **Two of my own arms were mis-aimed on the first pass and I record it rather than quietly redoing
it**, because it is the same defect class the brief warns about:

1. My helper that resolved a registry label's line number returned **empty**, so `sed -i "${L}s/…/"`
   became an **unaddressed** substitution and rewrote **all four** labels at once. Both S1 and S2
   then reddened the same set and neither proved what it claimed. The md5 guard did **not** catch
   this — the md5 moved, because the sed really did change the file, just far more of it than
   intended. **An md5-moved check proves a sed matched something; it does not prove it matched the
   right thing.** Redone with the line resolved by entry key (`ac`=26878, `noise`=26912).
2. My first S11 lowercased `SCOPED:` in `ase_window.tcl` — an `HK4` term — and duly reddened `HK4`.
   Had I stopped there I would have reported `HK5` as proven on the strength of a red row that was
   not `HK5`. Redone against `NOT MEASURED: ` in `ase.tcl`, which reds `HK5` alone.

## 6 — suites, both arms, as a name diff

I ran the pristine state by copying `git show HEAD:<file>` over the six modified sources
(`src/ase.tcl` plus the five suites), running both arms, then restoring from a snapshot taken first
and verifying **8/8 md5 OK**. No git state-changing command was used.

| suite / arm | before | after | gained | lost |
|---|---|---|---|---|
| `test_ase_preflight` nogui | 235 | **238** | `PF234a` `PF234b` `PF234c` | none |
| `test_ase_effective_1442` nogui | 94 | **97** | `RU6c` `RU6d` `RU6e` | none |
| `test_ase_optsheet_1441` nogui | 62 | **64** | `HK4` `HK5` | none |
| `test_ase_optsheet_1441` disp | 87 | **89** | `HK4` `HK5` | none |
| `test_ase_dialogs` nogui | 37 | 37 | none | none |
| `test_ase_dialogs` disp | 384 passed | **385 passed** | `G2e2` | none |
| `test_ase_core` nogui | 652 | 652 | none | none |

Every claimed count reproduces exactly. No row name was lost anywhere, which is consistent with the
receipt's warning that `G2e` and `G2g` changed *content* under unchanged names — proven instead by
sabotage (below).

**The 32-suite family sweep is the one overstatement I found.** `ls tests/headless/test_ase_*.tcl`
is **44** files, not 32. I ran all 44 headless: **42 PASS, 2 SKIP** — and the two that skip are
exactly the two the receipt names (`test_ase_dirty`, `test_ase_log_seam_0207`, both self-skipping
for want of X). So the *substance* is sound and in fact stronger than claimed; the family size is
simply misstated. Nothing in the sweep suggests the registry change disturbed a golden.

## 7 — `G2sens`

On the **pristine** tree (`src/ase.tcl` and all five suites at HEAD), `test_ase_dialogs` on the
display arm reports `1 FAILED (384 passed)` with

```
G2sens … -> {1 1 0 1 0 Entry Entry normal} (exp {1 1 0 0 0 Entry Entry normal})
```

and on the working tree `1 FAILED (385 passed)` with the **identical** actual value. Verified by
running it, not by assertion. It is not this crew's.

## 8 — `.state` round trip

Driven as a proc, as the brief requires:

```tcl
source [file join $repo tests headless state_roundtrip.tcl]
set r [ase_state_roundtrip $repo]
```

→ `tracked 104  bad {}  control_disagrees 1  control_agrees 1`. Both controls live, `bad` empty.

## 9 — sabotage, my own arms

Eleven arms, each run by me, each guarded by an md5-moved check and restored from a snapshot with an
`EXIT INT TERM HUP` trap:

| arm | mutation | reds |
|---|---|---|
| S1t | `ac` label (line 26878) regains `(2 gives ONE point)` | `G2e` `G2e2` `G2g` |
| S2t | `noise` label (line 26912) regains `(1 gives ONE point)` | `G2e2` |
| S3 | ac caution re-shouts `ONE` | `RU6c` |
| S4 | `noise` arm disabled, inherits ac's rule | `RU6d` |
| S5 | `lin_points` put back on `disto`'s `needs` | `RU6e` `RU8` |
| S6 | `SEGFAULTS` lowercased | `PF234a` `PF230h` |
| S7 | one of the four gate sentences reverted (line 13852) | `PF234b` |
| S8 | `degrees` re-shouted | `PF234c` |
| S9 | `voltage` re-shouted | `PF230b` |
| S10 | `NOT OFFERED:` lowercased | `HK4` |
| S11t | one `NOT MEASURED:` lowercased | `HK5` |

(`G2sens` also appears in every display-arm run and is the pre-existing red of §7.)

Every red set matches the receipt's, including the two rows a name diff cannot see: **S9 proves
`PF230b` moved** and **S1t proves `G2g` moved**. S1t/S2t further show the two labels are pinned
*separately* — breaking only `noise` reds `G2e2` alone, which is what makes `G2e2` a per-type guard
rather than a single-form one.

**Restored-tree row, positive:** `src/ase.tcl` `66acc5b7085df31e5ebcb792dc66ad36` and
`src/ase_window.tcl` `b38be6dffdf3b99aa0df5db3a6b476fb`, both equal to the snapshot taken before any
mutation; the six-file swap for §6 verified 8/8 `md5sum -c` OK.

## 10 — the owed ledger

`owed.sh count` → **187 rule, 70 look, 11 suite**, matching the receipt. Newest entries are `rule/1474`
(18:12) and a `look` at 15:43, both from before this task; `cleared.log` was last written
**2026-09-13 22:10**, days before, so nothing was cleared. No `rule` was added for A1, which is
correct — this *is* the ruling being implemented.

(Unrelated to this task, and reported only because the ledger was inspected: four entries are
**unstamped** — `rule/1357`, `rule/1357@xschem-claude`, one `look` and `suite/test_hier_pdf_links_1333`.
Against a stamped ledger that is evidence of another clone's older `owed.sh` having overwritten
something. Not this crew's doing, and not acted on.)

## 11 — T1

Run **solo** — `ps -eo pid,lstart,comm=` showed exactly **one** `tclsh` (pid 828135, 23:46:00) for
the whole run, so issue 0990's collision (the loser reporting a `FATAL` that never happened) is
excluded by measurement, not by assumption. Invoked as `cd tests && tclsh run_regression.tcl`, never
from the repo root. Polled **by PID in the foreground** under a deadline until the process exited;
counted only afterwards.

**Verdict: T1 is at its ZERO baseline.**

| | |
|---|---|
| `results.log` mtime | `19:33:13` → **`23:52:01`** — moved. (It passed through 0 bytes at 23:46 when the run truncated it, 4096 B at 23:51, **4721 B at exit**. A 0-byte log at exit would have been a death, not a zero.) |
| counted lines (`FAIL$`, `GOLD?`, `RESULT?`, leading `FATAL`) | **0** |
| `Total num fail:` other than 0 | **none** |
| `couldn't execute` / `exit 127` / `exit -1` | **none** — the binary launched and nothing collided |
| cases | **83**, every `Start` matched by a `Finish`, none run twice |

⚠ **Two things worth recording.**

1. **The log's md5 came back byte-identical to the pre-run value** (`8456b56c837201e29f8663fbe7ae0e97`
   before and after). That is exactly the trap the brief names: a green run is byte-deterministic, so
   an md5 comparison cannot distinguish "ran again, all green" from "never ran and you are reading
   yesterday's file". **Only the mtime separates them**, and it moved.
2. **The case count is 83, not the 82 I was told to expect** — and my own pre-run arithmetic off the
   script also said 82, so the two agreed and were both wrong. The run is the authority:
   **68 headless + 11 display + 4 top-level** (`create_save`, `open_close`, `netlisting`,
   `xschemtest`) = 83, with `Start` and `Finish` counts equal and every entry unique. Nothing was
   skipped; the expectation is simply one low. Not this crew's doing and not a defect in their work.

## Hygiene notes

* **`~/.xschem/geometry` moved during my session** — `23:37:23` → `23:39:18`, across a window in
  which I ran two display-arm `test_ase_dialogs` runs. I did not write it deliberately and touched
  nothing under `~/.xschem` by hand. The receipt records the same ambiguity from its own window and
  notes two interactive `xschem` processes were alive; **both remain alive here and I measured it
  rather than repeating it** — `ps -eo pid,lstart,comm=` shows `xschem` 807232 (22:42:28) and
  809774 (22:46:56), the same two pids and start times the receipt names, plus `Xvfb` 1116
  (08:09:29), the shared `:99` dev display. Matched by name, never by a pattern my own command line
  contained; nothing was killed and no `pkill` was used. `recent_files` is
  **untouched at 2026-09-13 18:53**, so the issue 0924 canary is clean. A future pass wanting
  certainty should run GUI suites under a scratch `HOME`.
* `/usr/bin/ngspice` was run **13** times and the fork **14** (the extra one is the malformed-deck
  diagnosis in §2), rc 0 every time; neither crashed nor hung, and no `sp` deck was run on either,
  precisely because issue 1452 records that a misplaced `sp` card kills the process. No deck lived
  under `sky130A/`; all nine live in the scratchpad with explicit output paths.
* Every suite invocation carried `timeout`; the ASE family sweep classified each suite as
  `PASS` / `FAIL` / `TIMEOUT` / `NORESULT` so that a stall could not read as silence.
