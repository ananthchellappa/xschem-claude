# ⚖ R4's unpaid obligation — the row that names `seed_enabled`

**One task, one row plus its control, one file.** `tests/headless/test_ase_core.tcl`
only. **`src/ase.tcl` was NOT changed** — the row needed no source change, and the
md5 below proves it went back untouched after every sabotage.

**Floor: 600 → 602, identical on both arms.** The file's own
`AND RAISED 600 -> 602.` paragraph is in the same diff.

| | before | after |
|---|---|---|
| headless `--nogui --pipe -q --nolog` | `RESULT: ALL PASS (600 checks)` | `RESULT: ALL PASS (602 checks)` |
| display `devdisplay.sh exec` (`:99`, Xvfb + openbox) | `RESULT: ALL PASS (600 checks)` | `RESULT: ALL PASS (602 checks)` |

Nothing else moved. Both baselines were re-measured here rather than taken from the
dispatch, and both matched the driver's number.

---

## The shape found: `seed_enabled` IS a literal registry key — the first of the two

The task said to decide by reading, not to assume. Measured live against
`ase::analysis_types ngspice` through the built binary:

```
ALLTYPES:  op dc ac tran noise tf pz sens disto sp pss     (11)
DECLARING: {op 1} {dc 0} {ac 0} {tran 0}
  op    registered=1  seed_enabled=1        noise registered=1  seed_enabled=<none>
  dc    registered=1  seed_enabled=0        tf    registered=1  seed_enabled=<none>
  ac    registered=1  seed_enabled=0        pz    registered=1  seed_enabled=<none>
  tran  registered=1  seed_enabled=0        sens  registered=1  seed_enabled=<none>
                                            disto registered=1  seed_enabled=<none>
                                            sp    registered=1  seed_enabled=<none>
                                            pss   registered=1  seed_enabled=<none>
```

So it is a real key, spelled exactly `seed_enabled`, living inside each analysis
entry of the dict `ase::backend::ngspice`'s `analysis_types` hook returns
(`src/ase.tcl`, the `return [dict create op [dict create label op …]]` block). It
is **not** absent, so the row is **not** the "no registered type declares it"
fallback shape the task offered as the alternative. The evidence that chose it is
the transcript above: four of eleven entries declare it, with values `1 0 0 0`.

**Therefore the row asserts the SPLIT, not a blanket "off".** "No type declares
`seed_enabled`" would be false of the four rows the user just ratified. What must
stay off is *declaring the key on anything else* — and the reason is in
`ase::analysis_seed`'s own comment: **declaring the key is what puts a type in a
fresh bench; its value is only the tick** (`if {![dict exists $e seed_enabled]}
{ continue }`).

---

## What was already there, and the hole it left

| existing row | what it asserts | why it is not enough |
|---|---|---|
| `R1 analyses are the four types in order` | the seed's **output** | a count and a name list; says nothing about the key |
| `R1 only op enabled by default` | the seed's **output** | same |
| `AG3` | the seed's **output**, verbatim | same — this is the row ⚖ R4 called "merely the existing assertion that four rows come out" |
| `AG16` | the **mechanism** on a scratch backend (`agseed`, types `zzin`/`zzon`/`zzout`) | proves what the key does; asserts nothing about the shipped registry |
| `TF6` / `PZ6` / `SE6` | `[dict exists [ase::analysis_entry ngspice <ty>] seed_enabled]` is 0 | **three types only** — `noise`, `disto`, `sp` and `pss` are named by nothing |

The hole: **no row asked the question of the registry as a whole.** A twelfth type
arriving seeded was caught by a *count*; the four existing ticks were pinned by
their *output*; and four of the seven silent types were pinned by nothing at all.

---

## The row

**`AG3b`** — placed immediately after `AG3`, whose weakness it names.

```tcl
proc ag_seed_census {d} {
  set decl {} ; set silent {}
  foreach ty [dict keys $d] {
    set e [dict get $d $ty]
    if {[dict exists $e seed_enabled]} {
      lappend decl $ty [dict get $e seed_enabled]
    } else {
      lappend silent $ty
    }
  }
  return [list $decl $silent [llength [dict keys $d]]]
}
check "AG3b exactly four of this registry's eleven entries declare seed_enabled,\
 op alone with the tick on, and the other seven declare no such key -- so a\
 twelfth type that arrives seeded reddens a row that NAMES the key" \
  [ag_seed_census [ase::analysis_types ngspice]] \
  [list {op 1 dc 0 ac 0 tran 0} {noise tf pz sens disto sp pss} 11]
```

Three things are pinned in one value, and each reds for a different reason:

* **who declares the key**, with the tick — a type moving *into* this list is ⚖ R4
  being violated;
* **who does not** — a type moving *into* this list is a twelfth analysis type
  arriving, which is ordinary, and the author adds the name here **having looked at
  whether it should be seeded**. That look is the mechanism the ruling asked for;
* **the entry count**, `11` — the cheap guard against the census walking an empty
  or renamed dict and agreeing with nothing.

### ⚠ It walks `dict keys`, not `ase::analysis_offered`, and the difference is reachable

`ase::analysis_offered` drops `registered 0` entries, and `ase::analysis_seed`
iterates *it*. So a type declared `registered 0 seed_enabled 1` is invisible to
every output-shaped row today — and joins every fresh bench as an **enabled** row
the instant somebody flips one word. That is sabotage **S3** below, and it is the
finding: it reds `AG3b` and **nothing else in 602 checks**.

**`AG3c`** — the positive control, on the shipped registry rather than a stand-in:

```tcl
set AG3C [ase::analysis_types ngspice]
dict set AG3C disto seed_enabled 1
check "AG3c …" [ag_seed_census $AG3C] \
  [list {op 1 dc 0 ac 0 tran 0 disto 1} {noise tf pz sens sp pss} 11]
```

It performs AG3b's own sabotage in process. Both halves move — `disto` joins the
declaring list at its declaration position and leaves the silent one — which is
what proves AG3b reads the key rather than reciting a literal that happens to
match. `{} {} 0`, which a mistyped key, a renamed accessor or an empty dict all
produce, fails **both** rows (sabotage **S4**).

---

## THE SABOTAGE CAMPAIGN

Restores are `cp` from a pristine copy taken before the first edit, with an md5
compare. Pristine md5s: `src/ase.tcl` **614c3836fa8b206445dbff9665c228b5**,
`tests/headless/test_ase_core.tcl` after the row **4c6f0546931cddc0bd5caa9e743c84f1**.

| # | what was broken | verdict | rows reddened, by name |
|---|---|---|---|
| **S1** | `noise`'s registry entry gains `seed_enabled 1` — the task's named sabotage | `9 FAILED (593 passed)` | **AG3b**, **AG3c**, R1 ×2, AG3, AG4, TF6, PZ6, SE6 |
| **S2** | `op`'s `seed_enabled 1` → `0` — the *value* half | `5 FAILED (597 passed)` | **AG3b**, **AG3c**, R1, AG3, AG4 |
| **S3** | a twelfth entry `zzlatent`, `registered 0 seed_enabled 1` | `2 FAILED (600 passed)` | **AG3b**, **AG3c** — **and nothing else** |
| **S4** | the census asks for `seed_enabledX` — an extractor that reads nothing | `2 FAILED (600 passed)` | **AG3b**, **AG3c** |
| **S5** | `AG3c`'s own injection line deleted — the control stops controlling | `1 FAILED (601 passed)` | **AG3c** |

`AG3b`'s verdict line names the key and the offender, which is the whole difference
from the rows beside it. S1's:

```
FAIL: AG3b … -> {{op 1 dc 0 ac 0 tran 0 noise 1} {tf pz sens disto sp pss} 11}
              (exp {{op 1 dc 0 ac 0 tran 0} {noise tf pz sens disto sp pss} 11})
```

against AG3's, for the same defect, which says only that there are five rows where
there were four.

### S3 is the finding, and S3b is why it matters

With `zzlatent` declared `registered 0 seed_enabled 1`, **600 of 602 checks pass.**
AG1, AG2, AG5, AG16, CP5, CP6, R1, AG3, AG4, TF6, PZ6 and SE6 are all green, because
`ase::analysis_offered` never sees the entry. Flip that one word:

```
# S3b: the same entry, registered 1
DECLARING: {op 1} {zzlatent 1} {dc 0} {ac 0} {tran 0}
SEED:      {type op enabled 1} {type dc enabled 0} {type ac enabled 0}
           {type tran enabled 0} {type zzlatent enabled 1}
```

A fifth row, **ticked on**, on every fresh bench — from a one-word commit that the
suite could not have warned about before AG3b existed. That is the "this would
change by accident" (D5) that made ⚖ R4 a ruling, in its least visible form.

### The four ways a row fails to fail, answered

1. **Fixtures that never disagree** — AG3b reads the **shipped** registry through
   `ase::analysis_types ngspice`. It builds no fixture. AG3c mutates that same
   shipped registry rather than a hand-built stand-in.
2. **Asking about position where the mechanism is last-writer-wins** — not this
   row's shape, and deliberately not asked: ordering of the offered list is AG1/AG2's
   subject. What is pinned here is *membership of the declaring set* plus the tick.
   The declaration order that does appear is Tcl dict insertion order, which the
   S1/S3 transcripts show moving correctly with the entry.
3. **An extractor that returns nothing cannot disagree** — S4 blinds the extractor
   and **both** rows red; the `11` element means an empty registry reds too; and
   AG3c is the standing positive control that the key is genuinely read.
4. **A sabotage missing from the generator** — S5 exists for exactly this: it
   sabotages the *control*, and AG3c reds alone. A control whose injection silently
   stopped injecting cannot pass here.

### Restore, verified

```
614c3836fa8b206445dbff9665c228b5  src/ase.tcl
614c3836fa8b206445dbff9665c228b5  /tmp/r4_pristine_ase.tcl
4c6f0546931cddc0bd5caa9e743c84f1  tests/headless/test_ase_core.tcl
4c6f0546931cddc0bd5caa9e743c84f1  /tmp/r4_after_test_ase_core.tcl
```

`git diff --stat` after the campaign: `tests/headless/test_ase_core.tcl | 76 +, 1 -`
and **no `src/ase.tcl` entry at all**.

---

## Three binaries — not applicable, and why that is said rather than skipped

The brief's rule is that any change touching what ASE-L **emits, reads back or
offers** is verified against `/usr/bin/ngspice` (apt 45.2) as well as the fork,
"(this does not apply to pure-Tcl rows that never start a simulator; say that
instead of testing twice)". **AG3b and AG3c start no simulator and read no binary.**
They call `ase::analysis_types`, which resolves a Tcl literal through the backend
hook; no probe, no capability cache, no `auto_execok`. The suite's own `E*` leg and
its capability stubs are untouched, and both arms are ALL PASS, so the answer is the
same on every binary by construction.

---

## Files changed

* `tests/headless/test_ase_core.tcl` — **+76 / −1**: rows `AG3b` and `AG3c` with the
  `ag_seed_census` helper (after `AG3`, before `AG4`), and the floor paragraph
  `600 -> 602` plus `AND RAISED 600 -> 602.` in the header.
* `doc/claude/ase_analyses_batch/receipts/26-r4-seed-enabled-row.md` — this file.

Nothing else. `src/ase.tcl` unchanged (md5 above). `src/ase_window.tcl` and
`tests/headless/test_ase_dialogs.tcl` were **not opened for writing** — they were
already dirty from the live crew when this task started and are dirty in the same
way now. Nothing staged, nothing committed, no git history touched.

---

## For the driver

* **No issue was minted.** The row pays a ruling's stated obligation; it fixes no
  defect and `NUMBERING.md` was not advanced. If you want the commit to cite a
  number, mint one at commit time — the two checks above are the whole of it. Cite
  **⚖ R4** either way, and `DECISIONS.md`'s R4 block already carries the
  obligation's wording verbatim.
* **No ledger debt was added.** No new user-facing sentence (a test row's name is
  not UI copy), no pixel deliverable, and the suite passes on the dev display as
  well as headless. A `:0` run is not owed for a schema row that renders nothing.
* **`T1` was not run** — it is yours and runs solo (issue 0990). Note that
  `tests/run_regression.tcl` runs `headless/test_ase_core` (line 75), so the count
  it sees moves 600 → 602 with this diff.
* **The one thing worth carrying forward.** ⚖ R4's obligation is discharged for the
  *registry*, not for the *seed key's meaning*. If a later stage ever gives
  `ase::analysis_seed` a second way in — a `seeded` companion key, a per-adapter
  default, anything that makes membership computable rather than declared — AG3b
  goes on passing while the seed grows. The comment above the row says so; the row
  itself can only see the key it names.
