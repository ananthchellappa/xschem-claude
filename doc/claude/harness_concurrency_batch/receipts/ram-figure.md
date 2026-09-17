# ram-figure — CLAUDE.md's "~7.8 GB box" is wrong by 2×, and the OOM it justified has no receipt anywhere

**Status:** DONE

## The answer, first

| | measured 2026-09-17 | CLAUDE.md said |
|---|---|---|
| RAM | **`MemTotal: 16091816 kB` = 15.35 GiB = 16.48 GB decimal** | "~7.8 GB" |
| swap | **`SwapTotal: 4194304 kB` = 4 GiB, `SwapFree` = 4194304 kB (0 used)** | not mentioned at all |

Units, stated deliberately because the two spellings differ by 7%: 16091816 kB ÷ 1048576 =
**15.35 GiB**; × 1024 ÷ 10⁹ = **16.48 GB** decimal. The figure CLAUDE.md carried was **not a
rounding of either** — it is almost exactly **half** the true RAM.

**The recon crew's 16091816 kB is CONFIRMED, exactly, twice, on two separate reads.** I did
not inherit it: I ran `/proc/meminfo` myself before opening R1-recon.md, got the identical
byte count, and re-read it at the end of the task to be sure nothing had changed under me.

## Files touched

| file | lines | what |
|---|---|---|
| `CLAUDE.md` | **76-84** (new ⚠ block) | `/usr/local/bin/xschem` no longer exists — separate wrong machine fact, below |
| `CLAUDE.md` | **152-154** | the truncation bullet's cause list: OOM demoted from first to last, 1403's timeout promoted |
| `CLAUDE.md` | **167-184** (new ⚠ block) | the RAM correction proper, house style, dated |
| `CLAUDE.md` | **497-508** | `AUDIT_WM=xfwm4` — third wrong machine fact, below |
| `doc/claude/issues/1477-…clean-sweep.md` | **116-126**, **167-169** | ⚠ correction; the OOM was this issue's headline cause |
| `doc/claude/issues/0905-…empty-file.md` | **89-98**, **189** | ⚠ correction; 0905 is where *"a documented event"* originates |
| `doc/claude/issues/0971-…read-its-header.md` | **25-28** | figure fix + ⚠; its argument survives untouched |
| `src/ase.tcl` | **2857** | comment figure fix, **line count preserved on purpose** (see Corrections) |
| `tests/headless/test_ase_simcaps_0948.tcl` | **4017-4020** | comment figure fix + ⚠ |
| `doc/claude/harness_concurrency_batch/receipts/ram-figure.md` | new | this file |

`git diff --numstat`, restricted to my six files: `44/7 CLAUDE.md`, `14/2` 0905, `4/1` 0971,
`17/3` 1477, **`1/1 src/ase.tcl`**, `4/1` simcaps — **84 insertions, 15 deletions, 6 files**.
(A bare `git diff --shortstat` reads *7 files, 162 insertions* — it is picking up the driver's
own concurrent `DECISIONS.md` edit, `+78/-0`, which is not mine. See **Left dirty**.)

## Rows added/changed

**None, and deliberately so.** This task changes no code path and asserts nothing a suite can
observe — the defect is in recorded *beliefs*. Two other crews were live, so per CREW_BRIEF
rule 4 I ran **no suite, no `./src/xschem`, no `make`, no `run_regression.tcl`**. The
substitute for red-before/green-after here is that every claim below is a re-measurement with
the command quoted, which is the same discipline applied to prose.

The one structural check that *could* have broken something, I ran: both edited `.tcl` files
still parse.

```
src/ase.tcl: info complete = 1 ; lines = 31700
tests/headless/test_ase_simcaps_0948.tcl: info complete = 1 ; lines = 5133
```

## Commands run

```sh
timeout 10 cat /proc/meminfo | head -8
timeout 10 /usr/bin/grep -E '^(MemTotal|MemAvailable|SwapTotal|SwapFree|Committed_AS|CommitLimit)' /proc/meminfo
timeout 10 free -m ; timeout 10 free -h
timeout 10 nproc ; timeout 10 /usr/bin/grep -c '^processor' /proc/cpuinfo
timeout 10 df -h . ; timeout 10 df -h /tmp /home ; timeout 10 uname -a
timeout 10 cat /proc/uptime ; timeout 10 uptime ; timeout 10 cat /proc/loadavg
timeout 15 dmesg | /usr/bin/grep -icE 'out of memory|oom[-_]kill|Killed process'
timeout 60 /usr/bin/grep -rn -E '7\.8 ?GB|MemTotal|OOM|…' --include='*.md' --include='*.tcl' \
         --include='*.sh' --include='*.js' --include='*.c' --include='*.h' .
timeout 60 /usr/bin/grep -rnw -E 'OOM|oom' --include='*.md' …        # word-bounded, see below
timeout 10 ls -l /usr/bin/openbox ; timeout 10 /usr/bin/openbox --version
timeout 10 ls -l /usr/bin/xfwm4 ; timeout 10 bash -lc 'command -v xfwm4; echo rc=$?'
timeout 20 dpkg -l | /usr/bin/grep -iE 'xfwm|openbox'
timeout 10 bash -lc 'command -v xschem; echo rc=$?' ; timeout 10 bash -lc 'type -a xschem'
timeout 10 ls -la /usr/local/bin/ ; timeout 10 ls -ld /usr/local/share/xschem
timeout 10 ls -la /tmp/.X11-unix ; timeout 10 ss -lx | /usr/bin/grep -i X11
timeout 6  bash -c 'echo > /dev/tcp/172.20.160.1/6000 && echo OPEN'
timeout 15 cat /mnt/c/Users/anant/.wslconfig
timeout 60 git log -S'7.8 GB' --format='%h %ad %s' --date=short -- CLAUDE.md
timeout 90 git log -S'7.8 GB' --format='%h %ad %s' --date=short
timeout 60 git log -S'/usr/bin/xfwm4' --format='%h %ad %s' --date=short -- CLAUDE.md
timeout 90 /usr/bin/grep -rhoE 'ase\.tcl:[0-9]{4,5}' --include='*.md' . | … | awk '$1>2857' | wc -l
timeout 60 tclsh   # info complete on both edited .tcl files
timeout 30 git diff --numstat ; timeout 30 git diff --stat ; timeout 20 git status --short
```

Every command carried a `timeout`. Nothing was run in the background; nothing hung.

## Measurements

**`/proc/meminfo`, verbatim, first read:**

```
MemTotal:       16091816 kB
MemFree:         5121840 kB
MemAvailable:    5994972 kB
Buffers:           24128 kB
Cached:          6312208 kB
SwapCached:            0 kB
```

**Second read, and the swap/commit lines:**

```
MemTotal:       16091816 kB
MemAvailable:    5996592 kB
SwapTotal:       4194304 kB
SwapFree:        4194304 kB
CommitLimit:    12240212 kB
Committed_AS:   17415812 kB
```

`free -h`: `Mem: 15Gi total, 9.6Gi used, 5.7Gi available; Swap: 4.0Gi total, 0B used`.

**Other machine facts, all measured today:**

| fact | measured | CLAUDE.md |
|---|---|---|
| cores | **20** (`nproc`, and `grep -c ^processor /proc/cpuinfo` agrees), Intel Core Ultra 7 265T | **states no core count** — nothing to correct |
| disk at repo root | **1007G, 12G used, 945G avail, 2%** (`/dev/sdd` on `/`) | states nothing |
| `/tmp` | **tmpfs, 7.7G, 5.4G used** — and 7.7G is *exactly half* of MemTotal | states nothing |
| uptime | **1 day 22:47**, load 0.26 / 0.62 / 1.04 | — |
| kernel OOM kills | **0** (`dmesg | grep -icE 'out of memory|oom[-_]kill|Killed process'`) | "a documented event" |
| `openbox` | **present**, `/usr/bin/openbox`, 3.6.1, dpkg `openbox 3.6.1-12ubuntu3` | claims present ✓ **correct** |
| `xfwm4` | **ABSENT** — `command -v` rc 1, no xfwm package installed | *"`/usr/bin/xfwm4` is also present"* ✗ |
| `/usr/local/bin/xschem` | **ABSENT** — `/usr/local/bin/` is **empty**, `/usr/local/share/xschem` gone, `command -v xschem` rc 1 | *"resolves to `/usr/local/bin/xschem`, 3.4.6 from Jan 2025"* ✗ |
| three X servers | **all three live**: `/tmp/.X11-unix/X0` socket, abstract `@/tmp/.X11-unix/X99` (dev display up), and `172.20.160.1:6000` **OPEN**. `$DISPLAY` = `172.20.160.1:0`, matching the `<win-ip>:0` claim | table ✓ **consistent** (I verified existence and reachability, **not** the vendor strings) |

### Does the OOM reasoning survive? No — and the defect does.

**It does not survive as an *attribution*.** Against 15.35 GiB plus 4 GiB of untouched swap,
the recon's measured collision — **5282 MB minimum available, 487 MB peak combined `xschem`
RSS, 31 concurrent processes** — is two orders of magnitude from a ceiling. And the claim has
no receipt anywhere: `dmesg` shows **zero** OOM kills this boot, and a repo-wide sweep for an
*observed* kill (`exit 137`, `signal 9`, `SIGKILL`, `OOM-killed`, `oom.killer`) finds only
SIGKILLs the harness *sends on purpose* and assertions citing each other. 1477 says *"an OOM
on this ~7.8 GB box does the same, as 0905 noted"*; 0905 says it is *"a documented event"*;
the ledger files say *"the recorded OOM path"*. **Nothing at the end of that chain is a
measurement.**

**The defect is completely untouched, and I did not weaken the paragraph.** Issue 1477's hole
is about *a kill*, not about *a cause*: every prefix of a green run scores green at all four
counted shapes, and 4096-byte full buffering against a 4785-byte verdict makes a 0-byte file
the typical outcome. The 900 s `T1_CASE_TIMEOUT` (issue 1403) and an outer `timeout` around
the driver are measured, memory-free ways to produce exactly that file. So the edit
**reorders the cause list** (timeout first, OOM last) and adds a dated ⚠ block; the defect,
the prefix finding, the buffering arithmetic and the case-count guard are all preserved
verbatim.

**What I am NOT claiming.** Concurrent `make`, and the arms that start real `ngspice`, were
not measured — by anyone. That is where a memory ceiling would actually show, and the
"one crew at a time" rule may still be right for reasons that have nothing to do with the
refuted figure. I wrote that limitation into CLAUDE.md rather than letting the correction
read as an all-clear.

### Where the wrong figure came from — provenance, measured with `git log -S`

* **2026-08-07**, `bd61efed`, a session prompt: the first appearance of "7.8 GB" anywhere in
  this repo.
* It then spread by copying — ledgers, crew launchers, six issue files, two source comments —
  for **five weeks**, never re-measured.
* **2026-09-17**, `bb069d89`: it reached **CLAUDE.md for the first time**, in the very commit
  that added the 1477 truncation bullet. So the figure was elevated to a standing fact *the
  same day* this batch was reasoning from it, and the driver then copied it into
  `DECISIONS.md` and asked a crew to judge OOM risk against it.

A plausible origin, offered as a **hypothesis, not a finding**: `/tmp` is a tmpfs of **7.7G**,
which is exactly `MemTotal / 2` — a `df -h` misread would land within a rounding of 7.8. The
alternative is that WSL2 was once allocated less; there is **no `.wslconfig`** on the Windows
side (`/mnt/c/Users/anant/.wslconfig` does not exist), so WSL takes its default and I cannot
date any change. Either way the figure is wrong **today**, which is what the docs assert.

## Claims checked vs taken on trust

**Checked, and CONFIRMED:**

* **The recon crew's `MemTotal 16091816 kB` — confirmed exactly, on two independent reads.**
  Not inherited: measured before reading R1-recon.md.
* CLAUDE.md:143 stated "~7.8 GB" — confirmed by `grep`, and it is wrong by 2×.
* `openbox` present at 3.6.1 — confirmed, so that half of the WM paragraph stands.
* The three-X-server table — confirmed by socket and TCP evidence (existence only).
* `$DISPLAY` = `172.20.160.1:0`, i.e. the Windows X server over TCP, as the table says.

**Checked, and REFUTED:**

* `/usr/bin/xfwm4` "is also present" — **false**. Added 2026-08-23 by `11e0c23f`, the commit
  whose own subject line is *"correct the AUDIT_WM claim"*. One WM fact was corrected and a
  second, unmeasured one introduced in the same breath.
* `/usr/local/bin/xschem` "3.4.6 from Jan 2025" — **the path is empty**. The *rule* still
  stands and I strengthened rather than weakened it (a `make install` re-creates the hazard in
  a minute, and `test_utility.tcl`'s third fallback is PATH), but a reader should know that a
  bare `xschem` today fails loudly instead of running a stale build.
* "an OOM … is a documented event" — **undocumented**, see above.

**Taken on trust (not independently reproduced):**

* The recon's **5282 MB min available / 487 MB peak RSS / 31 processes** from the two-run
  collision. Reproducing it requires running two regressions, which rule 4 forbids while other
  crews are live. I quote it *as the recon's measurement*, attributed, in every place I used it.
* Issue 1477's 4096-byte buffering and 4785-byte verdict arithmetic, and the prefix-length
  verifications — unchanged by me and outside this task.
* Vendor strings in the three-server table (`Microsoft Corporation` / `HC-Consult` /
  `The X.Org Foundation`) — I verified the servers exist and are reachable, not their identity.

## Corrections to PLAN.md

1. **The task said "correct any other site that states the wrong figure". Blanket-applying
   that to `src/ase.tcl` would have rotted ~455 citations.** Docs across this repo cite
   `src/ase.tcl:NNNN` line numbers, and **455 of those citations point below line 2857** —
   adding a comment line there shifts every one. The fix was made **line-count-preserving**
   (`git diff --numstat` shows `1 1`, one line replaced by one line) at the cost of one long
   comment line, with the full dated correction living in issue 0971 instead. The same check
   cleared `test_ase_simcaps_0948.tcl`: only three citations exist into that file (`:168`,
   `:709-717`, `:2991-2993`), all *above* 4017, so lines could be added safely there.
   **Any future crew editing a heavily-cited file should run the `awk '$1>N'` citation count
   before inserting lines.**
2. **17 sites still carry the stale figure and were deliberately left.** They are dated
   historical artefacts, not live guidance: `doc/claude/ledger/` (STATE_2026-08-25.md:76,
   RESUME.md:131 — a *different branch's* park doc, overnight_queue ×2, PARK_2026-08-31.md:46,
   crew.js:29, crew_annotate.js:58, crew_opfix.js:67), `doc/claude/op_param_batch/item_pipeline.js:91`,
   four `doc/claude/suggestions/next_session_prompt_*.md`, and four issue files recording *why a
   past decision was made* (0432:82, 0671:83, 0868:215, 0876:45). Rewriting those would
   falsify the record of what people believed at the time; the correction belongs in the live
   documents, which is where I put it. **Listed here so the driver can rule otherwise.**
3. **`DECISIONS.md` was not touched** — the driver holds it. Its lines **154** ("this box's
   memory — and an OOM kill is precisely…") and **242-246** still need the driver's pass; 242-246
   already carry the recon's correction, 154 still reads "~8 GB".
4. **The batch's headline count moves.** The dominant finding is recorded as *fourteen* wrong
   recorded beliefs caught by re-measuring. This task adds the RAM figure and **two more that
   nobody was looking for** — an absent `xfwm4` and an absent `/usr/local/bin/xschem` — both
   found only because step 6 asked for cheap verification of *other* machine facts. The
   cheapest audit in this repo appears to be re-running the one-line command behind any stated
   environment fact.

## Left dirty

```
 M CLAUDE.md                                                     (+44/-7)
 M doc/claude/issues/0905-…-clean-looking-empty-file.md          (+14/-2)
 M doc/claude/issues/0971-…-to-read-its-header.md                 (+4/-1)
 M doc/claude/issues/1477-…-reads-as-a-clean-sweep.md            (+17/-3)
 M src/ase.tcl                                                    (+1/-1)  line count UNCHANGED
 M tests/headless/test_ase_simcaps_0948.tcl                       (+4/-1)
?? doc/claude/harness_concurrency_batch/receipts/ram-figure.md   (this file)
```

Not committed. Untracked items pre-existing this task (`.xschem/`, `doc/claude/rdw_lists_batch/`,
`doc/claude/rdw_sim_batch/`, `sky130A/…/debug_st1/`) are not mine. `src/actions.c`, `src/save.c`
and `DECISIONS.md` belong to other crews and I did not open them for writing.

⚠ **Two files changed under me while I worked, and neither is mine.**
`doc/claude/harness_concurrency_batch/DECISIONS.md` was **clean** in my first `git status` and
carries **+78/-0** in my last one — the driver editing its own file, exactly as briefed. A new
untracked receipt, `receipts/R2-R3-design.md`, also appeared. Recorded here only so that nobody
reading a whole-tree `git diff` attributes either to this task.

## Owed to the user

**One ruling, for the driver to file — I did not touch `owed.sh`** (CREW_BRIEF rule 8).

> **"One crew at a time" was justified in writing by a RAM figure that is wrong by 2×.** Six
> documents state the serialisation rule and give the ~7.8 GB box as its reason; the box has
> 15.35 GiB plus 4 GiB of unused swap, no kernel OOM kills, and no recorded observation of one.
> The rule may still be correct — concurrent `make` and the `ngspice` arms are genuinely
> unmeasured, and this batch's whole subject is that concurrent runs corrupt each other for
> reasons having nothing to do with memory. But **its stated basis is refuted**, and the user
> should decide whether to keep it on the surviving grounds, re-measure a concurrent `make`, or
> relax it. I changed no scheduling policy.

No pixel deliverable, no user-facing string, no `look` debt.
