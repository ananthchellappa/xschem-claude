# 1453 — ASE-L's probe decks took over the user's File > Open Recent

**Branch:** fluid-editing · **Filed:** 2026-09-13 · **Status:** **FIXED 2026-09-13**, option B · rule debt filed
**Found by:** Stage 9's crew, in passing. **Verified by the driver, read-only.**
**Mechanism MEASURED 2026-09-13** by the 1453 crew — see "The writer, found by measurement".

## What the user sees

`File > Open Recent` holds **ten entries and not one of them is the user's**. Every one is an
ASE-L capability-probe scratch deck:

```
/home/analog/.xschem/simulations/.ase_probe/p3438206_3/probe_a.sp
/home/analog/.xschem/simulations/.ase_probe/p3438206_2/probe_a.sp
/home/analog/.xschem/simulations/.ase_probe/p3438206_1/probe_a.sp
/home/analog/.xschem/simulations/.ase_probe/p3390969_3/probe_a.sp
…
```

Four different pids, three decks each. **The directories no longer exist**, so every entry is
also dead. Whatever the user had in that menu has been pushed out of it.

⚠ **This is the SECOND time this file has been damaged.** Issue **0924** is the first: a bare
`xschem` on `PATH` resolving to a 3.4.6 binary that predates the gate emptied it. That one was
about a stale binary; this one is **ASE-L's own probe**, in this tree, today.

## The writer, found by measurement — and it is not this process

⚠ **THE TWO SECTIONS THIS REPLACES WERE BOTH WRONG.** The first draft said the probe
"loads a file from the event loop" and that each such load records. The driver withdrew that
by reading the code, and left an open question. Both drafts were hunting the writer **in the
wrong process.**

### The instrumented run that settled it (writes nothing)

A scratch `HOME`, so nothing of the user's moved. In the probing session,
`update_recent_file`, `write_recent_file` and `update_recent_dir` were renamed aside and
replaced by wrappers that log their argument and the whole `info level` stack and **do not
call through**. Then a live probe was driven:
`ase::sim_capabilities ngspice`, on the dev display, under
`./src/xschem --pipe -q --nolog --script`.

```
HOME=/tmp/w1453/home
nameofexecutable=/home/analog/dev/xschem-claude/src/xschem
no_recent_files=1
update_recent_files=0
elapsed_ms=30279
caps: known 0 unmeasured timeout secs 31

$ cat /tmp/w1453/parent.log
start Sun Sep 13 18:44:22 MST 2026            <-- and NOT ONE CALL after it

$ head -1 /tmp/w1453/home/.xschem/recent_files
set recentfile {/tmp/w1453/home/.xschem/simulations/.ase_probe/p3644712_1/probe_a.sp}
```

**The probing session never calls the recorder, and the file is written anyway.** The writer
is therefore a **different process**.

### Which process, and why it records

The user's registry (`~/.xschem/ase_simulators`) holds:

```
ase::sim_register ng-cm3 /home/analog/dev/xschem-claude/src/xschem -args {} -backend {} -casemode {} -nospiceinit 1
ase::sim_select ng-cm3
```

**The registered "simulator" is the xschem binary itself.** `ase::cap_run` then builds
`timeout <secs> <program> -b <deck>` and `exec`s it. `-b` is ngspice's *batch*; in
`src/options.c` it is xschem's **`--detach`**, and `<deck>` is a plain argument, so it becomes
`cli_opt_filename` → `src/xinit.c`'s `tcl_call("update_recent_file", fname, NULL, NULL)` — in a
**child that carries no `--nogui`, no `--pipe` and no `--norecent`**. `no_recent_files` is
therefore **0 in that process**, and it rewrites `$USER_CONF_DIR/recent_files` with the probe
deck.

Measured directly, against scratch HOMEs:

```
$ HOME=<scratch> ./src/xschem -q --nolog -b <deck>            rc=0  108 ms
  <scratch>/.xschem/recent_files  ->  set recentfile {<deck>}
$ HOME=<scratch> ./src/xschem -q --nolog --norecent -b <deck> rc=0  106 ms
  <scratch>/.xschem/recent_files  ->  absent
```

Both with **and without** `DISPLAY` — the child records either way. What is display-only is the
**parent**: `test_ase_dialogs`' row G13 is a GUI leg, so only the display arm reaches the probe
at all. That is why the pollution renews on that arm and not on the headless one.

### The gate is not at fault, in either process

`src/xinit.c`'s `tclsetintvar("no_recent_files", (cli_opt_nogui || cli_opt_pipe ||
cli_opt_norecent) ? 1 : 0)` and the `--script`-body save/zero/restore around
`source_tcl_file` (issue **0119**) are doing exactly what they were designed to do, in the
probing session **and** in the child. **A fix that touched the gate would have been a worse
defect than this one** — it would stop the user's own opens recording. `test_ase_simcaps_0948`
row **XE11** exists to keep that true.

### Three things the earlier drafts got right, kept

* `ase::cap_run` only `exec`s — `exec {*}$cmd < $nul 2>@1`. It never touches the editor **in
  this process**. True, and it is exactly why the writer was missed.
* There is **no `xschem load` anywhere on the capability-probe path**. True.
* The C callers of `update_recent_file` are `xschem load` / `load_new_window`
  (`src/scheduler.c`) and the **command-line filename** (`src/xinit.c`). ⚠ **Incomplete** —
  `src/actions.c` has three more (`saveas`, and both arms of `ask_new_file`). None of them is
  the writer here; the command-line one is.

## What has to change, and what must not

**The fix belongs in ASE-L, not in the gate.** The gate's behaviour is correct for a human's
loads; a capability probe is not a human's load. Either the probe suppresses
`no_recent_files` around its own `xschem load`s and restores it, or it stops loading a deck into
the editor at all — it is measuring the *simulator*, and `evidence/binary-differences.md` records
that a probe launch costs ≈5 ms, so there is no reason the editor has to see the file.

⚠ **The existing ten entries are the USER'S to repair, and nobody else's.** The standing rule in
this tree is that nothing touches, moves, backs up or read-modify-writes anything under
`~/.xschem/` — and that rule exists *because* of 0924. This issue does not repair the list, and
whoever fixes the probe must not repair it either.

## What was shipped — option B, aimed at the measured writer

**Option A was recommended against a mechanism that turned out not to exist.** There are no
"probe loads" to wrap a flag around: the probe does not load anything into this editor. The
measured shape is *ASE-L started the editor as if it were a simulator*, so the repair is
**option B — the probe stops putting its deck in front of an editor at all**, by refusing to
start one.

| | what | disposition |
|---|---|---|
| **A** | the probe sets `no_recent_files` around its loads | **refuted** — there are no loads on the probe path |
| **B** | the probe stops putting its deck in front of the editor | **SHIPPED** |
| **C** | `--norecent` on every probe launch | **refused** — it would mean spelling one program's command line into ASE-L's own source (D34–D36), and it silences the symptom while a second editor still starts, taking the user's `geometry` with it |
| **D** | do nothing | no |

**Two guards, in `src/ase.tcl`:**

1. **`ase::sim_check` gains a fifth ordered guard, `iseditor`**, after the four filesystem
   ones — so a missing path, a folder and a non-executable still get the more specific
   answer. `ase::sim_why iseditor` is its sentence. Because the validator is the one place
   every door goes through, this refuses at registration, in the Simulators list's Problem
   column, at `ase::sim_status` (so a run refuses), at `ase::sim_capabilities_path` (the
   typed-location / Detect door) and at the casemode readers — **one guard, every door**.
2. **`ase::sim_capabilities_at` refuses at the probe funnel**, returning
   `known 0 unmeasured iseditor` in the vocabulary's own shape, **before** the cache read and
   before `ase::cap_workdir`. No folder is made, no deck is written, no program is started.

`ase::sim_is_editor` answers by **identity, not name**: normalised path first, then
device+inode when the spellings differ, so a symlink, a hard link and `./src/xschem` are one
answer. A basename test was considered and refused — it buys a false positive (a simulator
somebody named `xschem`) and still misses a second xschem build under another name.

### The residual, said out loud

**A DIFFERENT xschem binary is not caught** — `/usr/local/bin/xschem`, an installed copy, a
build in another tree. Telling one apart from a simulator means starting it, which is the
thing being refused. If that shape is ever met, it is a new issue and not a silent gap here.

### What the user will now see

Their `ng-cm3` entry is still in the registry and will now be reported **unrunnable**, with the
`iseditor` sentence, at startup and in the Simulators window. That is correct: it could never
have simulated anything. The sentence is new user-facing text and therefore theirs to ratify
(⚖ R9); a `rule` debt is filed.

### Rows

`tests/headless/test_ase_simcaps_0948.tcl` section **XE**, floor **199 → 211**. The rows assert
**the call**, never the file: XE8 and XE10 count `ase::cap_workdir` and `ase::cap_run` through a
watcher, so the verdict is *no folder was made and nothing was started*. XE9 is the control a
guard refusing **everything** would fail; XE11 is the control a "fix" that silenced the
recorder would fail. Six sabotages, each reddening a named set — and sabotage **S2** (funnel
guard removed) reproduced the defect inside the suite's own throw-away HOME:

```
set recentfile {…/.scratch/_simcaps0948_3670235/simdir/.ase_probe/p3670235_582/probe_a.sp}
```

## Where it lives

**The fix:** `src/ase.tcl` — `ase::sim_is_editor` (new), `ase::sim_check`'s fifth guard,
`ase::sim_why`'s `iseditor` arm, `ase::sim_capabilities_at`'s funnel refusal.
**The rows:** `tests/headless/test_ase_simcaps_0948.tcl` section **XE** (XE1–XE12).
**The probe:** `ase::cap_workdir` / `ase::cap_run` / `ase::backend::ngspice`'s `capabilities`
hook, writing `<simulation folder>/.ase_probe/p<pid>_N/`.
**The gate, unchanged and not at fault:** `src/xinit.c`'s `no_recent_files`, and
`src/xschem.tcl`'s `update_recent_file` / `update_recent_dir` / `write_recent_file`.
**Prior art:** issues **0119** (the gate) and **0924** (the first time this file was
destroyed, by a stale binary on `PATH`).

## ⚠ The ten dead entries are the USER'S to repair

Nothing in this tree touches, moves, backs up or read-modify-writes anything under
`~/.xschem/` — that rule exists *because* of 0924. This issue did not repair the list and the
fix does not repair it. **And it kept being renewed while the fix was being verified**: every
display-arm run of `tests/headless/test_ase_dialogs.tcl` reaches G13 and therefore a live
probe, so the crew's own verification runs added process numbers to it. Counted in the receipt
(`doc/claude/ase_analyses_batch/receipts/34-1453-probe-decks-in-open-recent.md`).

**With the fix in, a display-arm run of that suite can no longer add to it**, because the
probe refuses to start the program the user registered.
