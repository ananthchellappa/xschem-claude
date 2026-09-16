# Debt M12, second half — INDEPENDENT VERIFICATION of receipt 51

**One task from the driver: disbelieve receipt 51's conclusion and find out whether it is
true.** No implementation, no commit, no change to ASE-L's export. Files touched: **this one
only**. `git status` is byte-for-byte what it was at hand-over; `git diff --stat -- src/ tests/`
is empty; HEAD is `0ed75642` before and after; `owed.sh count` is **187 rule, 70 look, 11 suite**
before and after.

Everything below was produced **from scratch** — my own benches, my own render script, my own
reference extraction, my own checker — in
`…/scratchpad/v12/`, never in the repository and never on a bench under `sky130A/`. The crew's
files were **read** (to audit their claims against their own artifacts) and **never reused as
evidence**.

| | |
|---|---|
| reader | **scikit-rf 2.1.0**, numpy 2.5.3, CPython 3.14.4, `~/.venvs/skrf/bin/python` — nothing installed, nothing modified |
| apt 45.2 | `/usr/bin/ngspice`, `ngspice-45.2`, rc 0 on all 8 of its runs, never crashed or hung |
| the fork | `/home/analog/dev/ngspice/build-ver_50/src/ngspice`, `ngspice-46+` |
| xschem | `src/ase.tcl` md5 `78adcd17…`, `src/ase_window.tcl` `b38be6df…`, `src/xschem` `96fc4899…`, `make -q -C src` rc **0** — a stale binary would have produced a plausible answer |

⚠ **NO TOUCHSTONE PARSER WAS WRITTEN HERE, FOR ANY PURPOSE.** The only file parsed by hand is
an ngspice `wrdata` ASCII column dump.

---

## THE VERDICT

**Receipt 51's conclusion is TRUE: ASE-L writes a valid Touchstone file.** It survived a harder
bench than the one it was measured on. Two statements in the write-ups are **overstated**, one
of them demonstrably false against the crew's own artifacts, and neither touches the conclusion.

---

## 1. What I built that they did not

Three benches through `ase::backend::ngspice::render_deck`, driven by an `ase::state_default`
state with an `sp` row carrying `s2p 1` — the same path section **SE** of
`test_ase_sp_1452.tcl` uses. The rendered deck carries `sp_export_lines`' three lines verbatim,
between the `$sim_status` guard and `remzerovec`/`write`:

```
let Rbase = 50 / wrs2p <rundir>/vabench_ase_sp1.s2p / unlet Rbase
```

| bench | netlist | why it exists |
|---|---|---|
| **VA** | `l1 in mid 220n`, `c1 mid 0 30p`, `r1 mid out 33` | complex, frequency-dependent, and **asymmetric** so S11 ≠ S22 |
| **VB** | `rin in 0 200`, `e1 amp 0 in 0 8`, `rout amp out 30`, **`rfb out in 5k`**, `c1 out 0 3p` | **non-reciprocal AND bilateral** — see §3 |
| **VC** | three ports, `r1/l2/c3` into a common node | the 3-port case `sp_row_check` cautions about |

**Two deliberate improvements on their method**, each of which could have changed the answer:

* **The reference is full double precision.** `set numdgt = 17` makes `wrdata` write **18
  significant digits**. The crew used `wrdata`'s default, which is **9** (measured on their own
  `ref/apt_m12bench_ase.txt`). See §2.
* **Reference columns are mapped BY NAME** from the `wr_vecnames` header, not by position, so
  my checker carries no assumption about the order the reference was written in. Theirs assumed
  a fixed column order.

## 2. Claim 1 and 2 — parse, read-back, and the values — CONFIRMED

Six shipped-path files (3 benches × 2 binaries) plus 2 no-unlet variants. **Identical on both
binaries, every file:**

```
PARSE: OK   WARNINGS: NONE   NPORTS: 2   NPOINTS: 11
Z0-UNIQUE: [50.+0.j]   FUNIT: Hz   F-HZ-FIRST: 1.0000000000e+06
16 lines, trailing newline present, zero CR bytes
```

`FREQ-MAX-ABS-DIFF-HZ` is **`0.000000e+00`** on all eight. Cross-binary: apt and fork produce
files **identical past the generated-at line** on all three benches.

**The comparison is not circular, and I re-derived that rather than taking it.** The reference
comes from a **separate** ngspice invocation that `load`s the `.raw` the same run wrote, does
`setplot sp1` (`CURPLOTNAME: SP Analysis`) and `wrdata`s `real/imag` of `s_1_1 … s_2_2`. The
`.raw` is written by `write`; the `.s2p` by `wrs2p`. **Two different writers serialising the
same in-memory doubles** — so this measures the *writer and the format*, not the computation,
which is exactly the claim receipt 51 §9 makes and does not exceed.

### The bound is honest, and it is TIGHTER than they showed

`wrs2p` writes `%.6e` — seven significant decimal digits — so the residual can only be decimal
rounding. Per printed real number the bound is half a step, `0.5e-6 × 10^floor(log10|v|)`,
taken from the **reference** value; real and imaginary are combined as `hypot`, which is the
tight bound on `|Δre + i·Δim|`.

| bench / binary | max\|ΔS\| | max(\|ΔS\|−bound) | violations | **budget used** |
|---|---|---|---|---|
| VA apt / fork | 6.092676e-08 | −9.783920e-09 | **0/44** | **86.2 %** |
| VB apt / fork | 4.257272e-07 | −4.001139e-11 | **0/44** | **99.3 %** |
| VC apt / fork | 6.263829e-08 | −2.427569e-09 | **0/44** | **95.2 %** |
| VA no-unlet apt / fork | 6.092676e-08 | −9.783920e-09 | **0/44** | 86.2 % |

⚠ **`BOUND-FRACTION-MAX` is the number that makes "0 violations" mean something**, and neither
write-up reports it. The worst component uses **86–99 % of its own rounding budget** and never
exceeds it. A bound nothing approaches proves little; this one is approached to within 0.7 % on
VB and is still not crossed. The agreement is therefore the full precision the format can
carry, not a loose epsilon — their formulation is correct.

Controls, all discriminating: `CTRL-PERTURBED` 1.0e-03, `CTRL-RI-AS-MA` 5.1e-01 to 6.5e-01,
`CTRL-DIAG-SWAPPED` 5.7e-01 to 1.24e+00. Negative controls on the reader itself:
`FileNotFoundError` / `EOFError: Ran out of input` / `ValueError: could not convert string to
float: 'this'`.

### ⚠ OVERSTATEMENT 1 — "the raw carries full doubles"

`evidence/m12-touchstone-validity.md` §4 justifies the bound with *"`wrs2p` writes `%.6e` …
while the raw carries full doubles"*. The `.raw` does. **The numbers they actually compared
against did not** — measured on their own reference file, `CREW-REF-SIG-DIGITS: 9`. `wrdata`'s
default is 9 significant digits, and `set numdgt = 17` (which they did not set) is what raises
it to 18.

Nine digits against a seven-digit bound leaves the reference's own quantisation at ~1 % of the
budget being tested. That is enough headroom for the verdict to survive — and it **does**
survive: re-run at 18 digits, every bench is still 0/44. But the sentence claims a precision
the measurement did not have, and it is the sentence the "0 violations" figure rests on.

## 3. Claim 3 — the transposition, THE LOAD-BEARING SELF-CORRECTION — CONFIRMED, and their bench was weaker than they said

Touchstone's 2-port column order is **S11 S21 S12 S22**. Their correction **C2** — that their
first bench was reciprocal and could not have caught a transposed S12/S21 — is **real and
correctly diagnosed**. I reproduced both halves.

**I did not settle for a numerical control; I built a file that IS transposed** and put it
through the same check. The transposed file was written by **scikit-rf's own writer**
(`Network.s = s.transpose(0,2,1)`, `write_touchstone(form="ri")`), so no parser of mine is in
the loop:

| transposed file, same reference | max\|ΔS\| | violations | verdict |
|---|---|---|---|
| **VA** (reciprocal) | 6.092676e-08 | **0/44** | ⚠ **passes with the defect physically present** |
| **VB** (non-reciprocal) | **8.232570e+00** | **22/44** | **caught, by 8 orders of magnitude** |

So the check genuinely distinguishes S12 from S21, and it does so **only** on a non-reciprocal
bench. Receipt 51's conclusion is supported on the one axis that matters.

### ⚠ OVERSTATEMENT 2 — their unilateral bench has a hole mine closes

Their bench B is a bare VCVS, and its **S12 is identically `0.000000e+00`** — in the `.s2p`
*and* in the reference. Consequences, measured on their own files through my checker:

* **11 of their 44 complex components have a derived bound of exactly 0 and a diff of exactly
  0.** Their reported *"bench B sits exactly ON the bound (`+0.000000e+00`)"* is not a half-ulp
  tie, as `evidence` §4 implies — it is `0 − 0` on the identically-zero S12 column. My checker
  reports `VIOLATIONS-STRICT: 0/44` but `VIOLATIONS-AT-OR-OVER: 11/44` on that file, which is
  the same fact said out loud.
* **A writer that emitted a literal zero into the S12 slot would pass their bench.** Theirs
  cannot tell "ngspice's `s_1_2` was written here" from "a zero was written here".

My **VB** closes it: `|S12|` ranges 6.157897e-03 … 6.174427e-03 (**non-zero**) and `|S21|`
8.216687e+00 … 8.238744e+00, so both off-diagonals carry real numbers differing by ~1300×, and
every one of the 44 components has a non-degenerate bound. `S12-MAX-ABS-DIFF` is **4.624824e-10**
against a non-zero bound — i.e. the S12 slot is *verified to hold ngspice's own S12*, not merely
verified to be zero.

**Their bench A reproduces exactly under my checker** (`5.825805e-08`, `−4.497951e-12`,
`BOUND-FRACTION-MAX 0.823893`), so their arithmetic is honest; it is the bench design and the
explanation of the `+0.00e+00` row that are weaker than stated.

## 4. Claim 4 — the `unlet Rbase` reversal — CONFIRMED IN SUBSTANCE, **THE STATED FORM IS FALSE**

The substance holds, on both binaries: the leak is real and is **confined to the `.raw`**.

```
shipped (with unlet):   No. Variables: 21      rbase lines in raw: 0
no-unlet variant:       No. Variables: 22      rbase lines in raw: 1
                            17  rbase  notype dims=1
```

(My bench gives 21 → 22 where theirs gives 20 → 21, and index 17 where theirs is 16 — the
**delta of +1 and the `rbase notype dims=1` column** are the fact; the absolute count and the
index are bench-specific and should not be quoted as universal.)

⚠ **BUT "BYTE-IDENTICAL, md5 `5b892d5e…`" IS FALSE AGAINST THE CREW'S OWN FILES.** Receipt 51
headline 2 prints a table giving md5 `5b892d5e…` for *both* the shipped and the no-unlet
`.s2p`, and `evidence` §5 says *"Both `.s2p` files carry md5 `5b892d5e…`"*. Measured:

* their **apt** pair is **not** byte-identical — `979b635f…` (shipped) vs `5b892d5e…`
  (no-unlet), differing in one line: `!Generated by ngspice at … 22:15:37` vs `22:15:38`;
* the `5b892d5e…` they quote is shared by three of their four files — apt-no-unlet,
  fork-shipped, fork-no-unlet — the three runs that happened to land in the **same clock
  second**.

**My run reproduced the mirror image**, which is what proves it is a clock artifact and not a
property of the files: my **apt** pair is byte-identical (`5fdd25f7…` twice) and my **fork**
pair differs by exactly one second in the generated-at line.

**The correct claim is the one their own §5 also makes — "identical past the generated-at
line".** "Byte-identical" and the md5 table must not be carried forward; they are true only of
whichever pair the clock happened to favour on the day.

**The ledger and the crew do NOT disagree.** `LEDGER.md`'s M12 row says dropping the `unlet`
*"leaks an `rbase` column into the results file"*, and in this tree's vocabulary the results
file **is** the `.raw` — `sp_export_lines`' own comment says *"the results file grows a `16
rbase notype dims=1` column"*. Both are right and they are saying the same thing. What resolves
the other way is the **driver brief's conditional** (*"if an independent reader rejects or
misreads that file, the `unlet` is … a correctness requirement"*): the reader does neither, so
the conditional never fires. Receipt 51 is correct that nobody should be told the `unlet`
protects the `.s2p`.

## 5. Claim 5 — the option line is load-bearing — CONFIRMED EXACTLY

Measured against bench VA's reference:

| the file | FUNIT | f[0] read back | max\|ΔS\| | violations | z0 |
|---|---|---|---|---|---|
| **as ASE-L writes it** | Hz | 1.0000000000e+06 | 6.092676e-08 | 0/44 | 50 |
| `#` line **deleted** | **GHz** | **1.0000000000e+15** | **6.504616e-01** | **44/44** | 50 |
| `# GHz S MA R 50` forced | GHz | 1.0000000000e+15 | 6.504616e-01 | 44/44 | 50 |
| `# Hz S RI R 75` forced | Hz | 1.0000000000e+06 | 6.092676e-08 | 0/44 | **75** |

**`PARSE: OK` and `WARNINGS: NONE` on every row**, the deleted-header one included. A missing
option line is not an error to a Touchstone reader — it is **GHz / MA / R 50** by specification,
and scikit-rf applies exactly that. **1 MHz is read as 1 PHz, a factor of 10⁹, silently.** The
`R` field really does carry port 1's Z0 as `sp_export_lines` intends: forcing `R 75` moves
scikit-rf's `z0` to 75 and moves nothing else.

## 6. Claim 6 — nothing else moved — CONFIRMED

* `git status --porcelain` is identical to hand-over: `M LEDGER.md` (the driver's) plus the six
  pre-existing untracked entries **plus** the crew's two new files, and now this receipt.
* `git diff --stat -- src/ tests/` **empty**; `git status --porcelain -- src/ tests/` **empty**
  — no suite row added, `test_ase_sp_1452.tcl` unmodified.
* `owed.sh count` **187 rule, 70 look, 11 suite**, before and after. Nothing added, nothing
  cleared, the ledger never written, so no backup was needed.
* **`~/.xschem/` byte-for-byte untouched by me.** Baselined before my first launch and
  re-checked after the last: every mtime identical, `recent_files` still **2026-09-13 18:53**
  (issue 0924's file), `ase_simulators` still 2026-09-14 00:22. Every xschem launch used a
  **scratch `HOME`** with `XSCHEM_DEVDISPLAY_DIR` pointed at the real one.
* `tests/run_regression.tcl` **NOT run**, by instruction — no code changed and it must never
  race another run.

## 7. Hygiene and named outcomes

* **Every command carried a `timeout`** (ngspice 120 s, xschem 180 s, Python 120–300 s, the
  batch script 560 s). **None fired.** Nothing was backgrounded, so there was no wait to bound.
* **`/usr/bin/ngspice` was never crashed or hung** — rc 0 on all eight of its deck runs.
* ⚠ **A NAMED OUTCOME, not a failure: the eight reference read-back runs exit rc 1.** The
  reference deck is a dummy circuit with no analysis, so batch mode prints *"incomplete or empty
  netlist … no simulations run!"* and exits 1 — **after** the `.control` block has run. `PLOTS:`,
  `CURPLOTNAME: SP Analysis` and `REF_DONE` all printed and all eight reference files were
  written. Recorded because an rc-1 line in a log is otherwise indistinguishable from a broken
  measurement.
* ⚠ **AND THE RC-0 TRAP FIRED ON ME, WHICH IS WORTH RECORDING.** My first render script called
  `sp_row_check` with the wrong arity. `xschem --nogui --pipe` printed the Tcl error and
  **exited 0**. Had I read the exit code instead of the output I would have proceeded with three
  decks that were never written. This is the documented `--nogui --pipe` behaviour meeting a
  verifier in the first five minutes of the task.
* **No snapshots taken, nothing to disarm** — this task mutated nothing outside its own scratch
  directory. No `pkill`, no `pgrep -f`; nothing was matched by a pattern my own command line
  contained.
* Artifacts at `…/scratchpad/v12/` — `vrender.tcl`, `run_all.sh`, `vcheck.py`, `prec_probe.cir`,
  `out/{apt,fork}/`, `ref/`, `ctrl/`, `logs/`.

## 8. What this binds

1. **Never write "byte-identical" or quote an md5 for two `.s2p` files from two runs.** The
   `!Generated by ngspice at` line carries a wall-clock second. The durable claim is *identical
   past the generated-at line* (§4).
2. **A non-reciprocal bench is necessary but not sufficient for an S-parameter value test.** It
   must also be **bilateral** — an identically-zero S12 gives a zero rounding bound on those
   components and cannot tell a written value from a written zero (§3).
3. **Report the fraction of the rounding budget used, not only the violation count.** "0
   violations" against an unapproached bound is decoration; 86–99 % used and none crossed is
   evidence (§2).
4. **`wrdata`'s default is 9 significant digits.** Any reference extracted from a `.raw` for a
   precision comparison needs `set numdgt = 17` first, or it is not "full doubles" (§2).
5. Receipt 51's binding items **1 (the `unlet` protects the `.raw`)**, **2 (`# Hz S RI R 50` is
   the file's meaning)**, **3 (a value test needs a non-reciprocal bench)** and **4 (a 3-port
   row's `.s2p` cannot say it is one)** are all **independently confirmed here** and stand.
6. **Unmeasured, and no claim is made**: any reader other than scikit-rf 2.1.0; Touchstone v2;
   a `donoise 1` row through `wrs2p`; whether the S-parameters are physically right for the
   circuit. "Valid to scikit-rf" is the claim; "valid to ADS" is not.
