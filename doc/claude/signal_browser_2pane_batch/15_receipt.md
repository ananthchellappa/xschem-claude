# TWO-PANE item 15 — R7: All-DBs headers + a design root per DB

Two-pane item 15 (**not** single-pane item 15). Spec
`doc/claude/specs/waveform_signal_browser_two_pane.md` **R7**, §4.1, §4.2, §4.3,
**M11**. PLAN item 15. Commit **`e1cfd5ff`**, NOT pushed. Files touched:

* `src/wave_viewer.tcl`
* `tests/headless/test_wave_sigbrowser_i14.tcl`
* `tests/headless/test_wave_sigbrowser_i1315.tcl`
* this receipt

`LEDGER.md` was deliberately **not** touched by the implementer — its own header
reserves it for the pipeline's ledger stage, which wrote the `[E]` mark, the
eyeball row and the new baseline after this receipt was verified.

---

## 1. The baselines, re-measured on the UNCHANGED tree first

Both reproduced **exactly** before a line was written, so every red afterwards is
attributable to this item.

| arm | recorded baseline | re-measured before | after item 15 |
|---|---|---|---|
| headless, 14 wave files | **1628**, 0 fail | **1628**, 0 fail, every per-file figure identical | **1637**, 0 fail |
| X, 11 suites via `xarm.sh suites` | **11/11, 2174** | **11/11, 2174**, every per-suite figure identical | **11/11, 2192** |

**headless per file, after:** sigsearch 146, sea 6, sigbrowser 135, 2pane 108,
panes 15, i11 50, i12 40, i1315 88, **i14 56** (was 47), grid 231, modes 212,
viewer 57, markers 437, tabs 56. The whole **+9** is in `i14` and it is the nine
PURE checks `BD60`, `BD61`, `BD62`, `BD62b`, `BD63`, `BD64`, `BD65`, `BD66`,
`BD66b`. **Every other file byte-identical.**

**X per suite, after:** panes 81, 2pane 108, sigbrowser 353, sigsearch 233,
sea 79, grid 356, i11 74, modes 488, i12 123, **i1315 190** (was 188),
**i14 107** (was 91).

| suite | before | after | why |
|---|---|---|---|
| `i14` | 91 | **107** | +16: the nine PURE above, plus `BD67`, `BD68`, `BD69`, `BD70`, `BD70b`, `BD70c`, `BD70d` in the Tk block |
| `i1315` | 188 | **190** | +2: `BP43a`'s new negative control, and `BP47b`, the id-scheme control |
| every other suite | — | **byte-identical** | untouched |

**18 new check calls**, 15 restated, **none deleted**.

The X arm ran under **Xvfb** (`SUITE_TIMEOUT=400`), which the ledger records as
count-identical to `:0`. It has **no window manager** — correct for this item,
which lives entirely inside one toplevel, and a further reason §11's eyeball
cannot be closed by a check.

**Independently re-measured by the verifier**, not adopted: all 14 headless files
run by hand (1637 / 0 fail, per-file exact) and all 11 X suites re-run
(11/11, 2192). `nonBaselineFails` is genuinely empty; no known flake (`BR25`,
`MG16`) fired, no `NORESULT`.

---

## 2. ⚠⚠ WHAT THE PLAN GOT WRONG, WITH THE MEASUREMENT THAT SAYS SO

### 2.1 THE BIG ONE — the `d:0|` prefix on the current DB is REFUSED

**PLAN item 15 prescribes a `d:0|` prefix on group 0.** It does not get one. It
gets a **HEADER** and keeps its bare ids: `g:`, `g:x1`, `s:v(n)`.

Two reasons, and **the deciding one came out of the RED run, before a line of
source was written**:

1. **Spec §4.3's closing sentence rules it** — *"the current DB is always group
   0, unlabelled and unprefixed, and that invariant is what makes 'current'
   well-defined when two DBs have different top cells."* Only the *unlabelled*
   half can survive R7. The task's own precedence rule (spec beats PLAN) applies.
2. **MEASURED.** The prefix would carry the DB's **registry index**, which is not
   a property of the design. `test_wave_sigbrowser_i1315.tcl`'s restore fixture
   snapshots with **two** raws loaded, where the current one is slot **1**, and
   `restore` brings back **one**, where it is slot **0**. Under the PLAN's scheme
   every persisted `d:1|g:x1.x2` names a row that no longer exists — the user's
   selection and open set silently evaporate and `BP52`, `BP53`, `BP54`, `BP55`
   all go red **with no defect in the persistence code at all**. The first RED
   run produced exactly that: `BP47b -> {0 1 1}` against `{1 1 1}`.

`BP47b` is the check that records it. It asserts the slot really does move
`1 -> 0` across the restore **and** that the persisted bare ids survive it
anyway, pinned to the literals `1` and `0` rather than to "they are equal", so it
stops saying anything only when the drift stops happening.

**The verifier reproduced this from the other side.** Its invented sabotage
`VS3` — collapse "absent" and "deliberately empty" prefix in `browser_rows_multi`
(`[llength $g] < 5` → `$gpfx eq {}`) — reds 17 checks in `i14` **and nine in
`i1315`, including `BP52`-`BP55`**. So the divergence is forced by measurement,
not preference.

R7's letter — *"per-database headers become the tree's top level, above each DB's
design root"* — is satisfied either way. `BD68` is the check that says so. Blast
radius fell from ~20 existing checks to **15**.

### 2.2 Four more PLAN errors, each measured

| # | PLAN says | measured |
|---|---|---|
| a | `BD67` expects `[::wviewer::db_label $cur]` | `db_label` takes **two** mandatory args (`src/wave_viewer.tcl:2038`, path AND analysis). The PLAN's spelling throws `wrong # args`. Written with two; the `i14` current DB's label measures `bd_b.raw (tran)` |
| b | `BD68` expects `{d:0 d:1}`, `BD70` expects `d:0\|g:` | **Wrong DB.** In the `i14` fixture the current DB is registry slot **1** and the foreign one slot **0** — `BD31`, `BD31b`, `BD43` pin it — and `browser_rows_multi` emits group 0 (current) FIRST while `browser_populate` inserts `end`. Every X check now derives its header id from the **engine** (`rawinfo_parse`'s `cur` in `i14`, `signal_list_all`'s `cur` flag in `i1315`, which carries its own 0173 context bracket), and `BD67`'s third leg asserts the derived index itself — so a fixture that reorders its raws fails loudly instead of re-deriving a wrong id and going green |
| c | `BD65` expects `bd_has $r {d:1}` == 0 for the empty group | Mechanism right, **id backwards** for this fixture, where `d:1` is the CURRENT DB. The PURE fixture numbers its own groups (current `d:0`, foreign `d:1`) and asserts BOTH absences plus a positive control on the same list |
| d | break-list names **2** existing checks (`BD50`, `BD51`) and prescribes a `BD51` fix for a form two-pane item 10 had already replaced | The real radius is **15 across two files**, three of them TOMBSTONES (`BD48c`, `BD50c`, `BP43a`) whose own comments already spelled out what item 15 owed. The PLAN's `BD51` fix was already done and its "value stands" claim is false — legs 2 and 3 both move |

### 2.3 The PLAN contradicts itself on the helper

It states *"`browser_rows_multi`'s helper contract is NOT changed"* and then
prescribes a `BD50` replacement whose parent row reads `bd_a`. **The unchanged
helper provably cannot produce that**: it threads ONE `$root` string into every
group, so every DB's root renders the **current** design's name under a
**foreign** DB's header (probe: `d:0|g:|d:0|bd_b|group`). Measured fix — an
optional per-group root — gives `d:0|g:|d:0|bd_a|group`, with both
3-element-compat probes measuring 1. See §5's divergence list.

### 2.4 The one thing the PLAN got right

*"The `$glab eq {}` flat arm stays exactly as it is, which keeps
`BD19`/`BD21`/`BD22`/`BD25` green."* Correct — and see §6.3, because their
staying green proves **nothing**.

The band `BD60`-`BD70` was also correctly measured free (highest BD in use was
`BD59`). First time this batch.

---

## 3. Traps that cost real time — all found by running

### 3.1 ⚠ `BD06`'s BARE-NAME GREP GUARDS THE EXACT BLOCK THIS ITEM EDITS

`BD06` counts **`browser_alldbs`** bare, file-wide, expecting **2** (defined
once, called once). Item 15 edits `browser_refresh` in the very block whose
comment warns about it, and edits `browser_reload`. Two-pane item 12 red this
check exactly this way, by naming an accessor *in prose*.

Handled by the standing rule, and re-grepped by hand after the fact by both the
implementer and the verifier: **`grep -c browser_alldbs src/wave_viewer.tcl`
== 2.** Every new or edited comment says *"the All-DBs checkbox"*, never the proc
name. Same discipline kept `BW59` (`browser_devint`/`browser_srccur` == 4 each)
untouched.

### 3.2 ⚠ THE NEW ARRAY'S NAME WAS NEARLY A `BP04` RED

`BP04`'s zero-hit leg counts `sbcase(|sbcfg(|sballdb(|dest(` inside
`browser_state`'s body and expects **0**. The new per-token array is
`browsercurdb(`, which matches none of the four — **but `browserdest(` WOULD have
matched `dest(`.** The name was checked against that regex before it was chosen,
not after it went red.

### 3.3 ⚠ `BD58`'s SEEDED FIXTURE CANNOT BE "FIXED" — THE FIX EATS IT

`BD58` hand-seeds a **3-key** foreign inventory dict `{id label names}` — no
`path` key — so its design root floors its text at `design`
(`browser_root_label`'s floor). The obvious tidy-up is to call
`browser_refresh $tok 1` so the real pipeline fills it in; that **re-enters
`browser_reload` and destroys the seed**, which is a control eating its own
fixture (two-pane item 12's §4.2, one item over).

Resolved by leaving the seed deliberately un-widened and having `BD58` assert the
root's **ID**, never its text. Recorded as declared limit **D4**.

### 3.4 `$first` IS FALSE ON THE POPULATE THAT MATTERS MOST

The obvious spelling of the new open rule is *"open the header too when
`$first`"*. `$first` means **the tree was empty** — and ticking the All-DBs box
re-shapes an **already-drawn** tree, so under `$first` the header and root arrive
**collapsed on the very gesture that creates them**. Replaced by a "newly born"
test, which is a strict superset. The verifier's `VS1` is the measurement of this
(see §7).

### 3.5 THE `.ph` STATUS LINE MUST NOT BE TIDIED INTO THE LOOP

`extra`/`ndbs` are incremented only inside the **foreign** loop. Folding the
current DB into that loop — which R7's "the current DB is a group like any
other" reading invites — reds `BD52b` (`"+3 from 1 other DB"`) and breaks item
12's carried-in `.ph` freeze across four files. Left alone on purpose; limit D5.

---

## 4. What landed

### Source — `src/wave_viewer.tcl`, four edits, **NO new proc**

* **`browser_reload`** captures the current DB's **header identity**
  (`{id d:<registry idx> label …}`) into a new per-token array
  `browsercurdb($token)`, in the same pass that already captures item 10's raw
  path — so `browser_refresh`, which rides both searchbars' key pump, never takes
  a context loan per character. Each FOREIGN dict gains a `path` key beside
  id/label/names. The array is declared at the top of the namespace and **unset
  in `forget`**; `BD56`/`BD56b` are the live teardown legs.
* **`browser_rows_multi`** takes two **OPTIONAL** extra tuple elements:
  `{gid glab entries ?root? ?prefix?}`. Dispatch is on **`[llength $g] >= 5`**,
  never on `$gpfx ne {}` — `{}` **is** the value the current DB passes, and
  "absent" and "deliberately empty" must not collapse. That comment is what the
  verifier's `VS3` aimed at.
* **`browser_refresh`** always computes the root label, labels group 0 **on the
  checkbox alone** — never on how many foreign DBs matched — and gives each
  foreign group its own root label.
* **`browser_populate`** opens the design root's **PARENT** as well as the root,
  when both are newly born. `see` is still absent from this proc (`BW53`).

### Tests

* **`tests/headless/test_wave_sigbrowser_i14.tcl`** — `BD60`-`BD66b` (nine PURE,
  both arms) and `BD67`-`BD70d` (seven X-only), **+9 headless / +16 X**, plus 11
  restatements. `BD70d` and `BD69` both write their restore **after** every read,
  so no check asserts its own helper's restore (two-pane item 12's §4.4 lesson).
* **`tests/headless/test_wave_sigbrowser_i1315.tcl`** — `BP43a` gains a negative
  control and `BP47b` is new, **+2 X only**, plus four restatements.

---

## 5. Every divergence

| # | from | divergence, and why |
|---|---|---|
| D1 | **PLAN item 15** | The current DB gets a HEADER and keeps **UNPREFIXED** ids; no `d:0\|` prefix. §2.1 — spec §4.3 rules it and the registry-slot measurement forces it |
| D2 | **PLAN item 15** ("helper contract is NOT changed") | The helper gained **two optional** tuple elements. §2.3 — the PLAN's own `BD50` replacement is unreachable without them. Both optional; every 3-element call byte-identical (`BD19`-`BD25c`, `TP33`, `TP40`, `TP41` green untouched); `BD62b` is the leg |
| D3 | **spec §4.1** ("Inserted closed — R1. **This is the single change in `browser_populate`**") | It is now **two** changes: the current DB's header is born open as well as its root, because R4's selected root otherwise sits inside a collapsed parent nobody can see and §4.2 forbids `see` here (`BW53`). **M11's own rationale applies verbatim.** Foreign headers stay collapsed — `BD70b` leg 3 |
| D4 | the obvious spelling | `$first` was **REPLACED** by a "newly born" test, not joined to it. §3.4. `{}` existed ⇒ everything is newly born, so item 10's carry-over is untouched. `BD69` is R5's guard on it |
| D5 | **PLAN `BD67`** | `db_label` called with **two** args, not one — the PLAN's spelling throws |
| D6 | **PLAN `BD68`/`BD70`/`BD65`** | Header ids derived from the **engine**, not from the PLAN's literals, which name the wrong DB in this fixture. §2.2 |
| D7 | **spec §4.3's text** | Now stale in one clause ("unlabelled"). **Item 19 owns the spec edit.** R7 and §4.3's first sentence already rule the other way, as do the shipped comments on `browser_id_path` and `browser_root_id` |
| D8 | the pipeline's own convention | `LEDGER.md` was **not** edited by the implementer; the new baseline was recorded in §10 here and the ledger stage transcribed it |

---

## 6. The checks that were VACUOUS on the RED run, and what was done

Checks were written and run **before** any source edit. In the headless arm 9 of
9 new PURE checks failed; in the X arm every new check failed **except one**.

### 6.1 ⚠ `BD69` AS FIRST WRITTEN PASSED BEFORE THE CODE EXISTED

*"box OFF: the tree's TOP LEVEL is the single design root"* is **item 10's
shipped shape**. It could not fail in the direction this item moves — a control
that is not evidence.

**Fixed, not excused**, both halves:

* the box-OFF reading became a **CAPTURE** (`set bd_top_off …`) folded into
  `BD68`'s tuple as **leg 1**, so `BD68` now carries its own control in the same
  tuple and is red-before;
* the `BD69` **id was re-spent** on a genuinely new, red-before claim — R5's
  guard that a **search keystroke never re-opens a DB header the user
  collapsed**.

### 6.2 Two legs individually passed, and are kept as LEGS

* `BD62` leg 5 (`bd_has $bd_rooted {d:0|g:}` == 0) and `BD65` legs 1-2 each
  passed before the code — there were no roots at all to be absent.
* Kept **as legs, not as checks**: each sits in a tuple whose other legs are
  red-before, which is exactly the "carry the positive evidence in the SAME
  tuple" rule. `BD62` leg 5 is the **discriminator** separating this design from
  the PLAN's prefix-everything one, and it is what sabotage `S1` has to defeat.

### 6.3 ⚠ NOT VACUOUS, BUT WORTH NAMING: the checks that stay green and prove nothing

`BD19`, `BD21`, `BD22`, `BD25` stay green through the whole item, and the PLAN
offers that as reassurance. **It proves nothing.** They call
`browser_rows_multi` **directly** with a hand-built `{}`-labelled group — a code
path production no longer takes. That is silent-green trap §3.2.

**`BD67` exists solely because of it**: it watches `browserrows` after a **LIVE**
refresh, and it is red under `S1`, `S3` and `S5`.

### 6.4 Two expected literals were predicted wrong; the measurement won

* `BD49` leg 4 — `bd_ids_for {time}` was predicted as one id and measured as
  **two**: `time` is in both fixture raws, so it resolves to the current DB's
  unprefixed id AND the foreign DB's prefixed one. The measured form is the
  better leg (both id schemes on one name, in row order).
* `BP53` — the restored open set was predicted to contain the current DB's header
  and measured **not** to. That prediction losing is declared limit **D1** in §9,
  and is asserted as a value in `BP53` leg 4 rather than written off.

---

## 7. Sabotages — RUN

Driver: a **LOCK** file, an `EXIT`/`INT`/`TERM` trap restoring from a
**byte-exact BACKUP** (never `git checkout --` — the item was uncommitted at the
time), a **PRE-STATE occurrence assertion** before each patch, a **sha256 change
proving the mutation reached disk**, a `diff` on restore, and an output filter
counting **`NORESULT` and `TIMEOUT` as REDS**. Clean baseline and clean re-run
either side: **107 / 190 / 108, 0 fails.** No row scored zero, and check COUNTS
are reported alongside fail counts because a throw that truncates a file is a
different failure from a red check.

### 7.1 The item's own seven

| # | injected | failed exactly? | reds | positive control | reverted |
|---|---|---|---|---|---|
| `S1` | `browser_rows_multi`: `set gpfx {}` instead of `"$gid\|"` — a foreign group is never prefixed | **no, deliberately** | `i14` **24** (`BD62`, `BD64`, `BD66`, `BD66b`, `BD60` leg 2, + the live duplicate-`g:` throw), `i1315` 1 (`BP43a`), `2pane` 6 (`TP33`×2, `TP41`, `TP43`×3). **`i14`'s COUNT fell 107 → 83** — a shared `g:` THROWS in ttk, which is the failure the prefix exists to prevent and is visible only because the count is diffed, not just the fail number | `BD19`/`BD21`/`BD22` (the unlabelled arm) **GREEN** | ✔ byte-exact |
| `S2` | `browser_refresh`: drop each FOREIGN group's own root label (its 4th tuple element) | **yes** | `i14` **exactly 3** — `BD48`, `BD50`, `BD50b`, all three the ROOT TEXT leg. `i1315` and `2pane` untouched | **`BD62b` (PURE) GREEN** — the helper is provably fine, the **CALLER** is the defect. This is the sabotage proving the PLAN's "helper contract is NOT changed" clause would have shipped a tree naming the wrong run | ✔ |
| `S3` | `browser_refresh`: `if {0 && $alldbs …}` — foreign DBs get headers, the current one never does | **yes** | `i14` **11** (`BD49`, `BD48c`, `BD50c`, `BD67`, `BD68`, `BD70b`, `BD51`, `BD70c`, `BD69`, `BD51c`, `BD58c`), `i1315` **4** (`BP43a`'s control, `BP43`, `BP45`, `BP53`) — all fifteen caller-side claims | **`BD62` (PURE), `BD48`, `BD50` (the foreign side) GREEN** — provably about the CALLER, which is §6.3's whole point and the reason `BD67` exists | ✔ |
| `S4` | `browser_rows_multi`: drop the `if {$grt eq {}} {set grt $root}` fallback — the per-group root becomes MANDATORY | **yes** | `i14` **1** (`BD61`'s 4th-leg pair), `2pane` 5 (`TP33`×3, `TP41`, `TP43`) — exactly the backward-compatibility surface | **`BD60` leg 1 (the unlabelled arm) GREEN** — a different code path. ⚠ The PLAN predicted this reds `BD60` and `BD22`; **measured, it does not**, because both are built with no `$root` argument at all | ✔ |
| `S5` | `browser_reload`: hard-code `id "d:0"` for the current DB instead of its registry idx | **no** | `i14` **20**, count 107 → **87** (the collision with the foreign `d:0` throws), `i1315` 5. An id collision is systemic, not single-target | **the id/label separation is VISIBLE**: `BD67`'s TEXT leg is still right while its ID legs are wrong, so label and id are provably separately wired | ✔ |
| `S6` | `browser_populate`: open only `$rootid`, never `$rootpar` — revert item 15's second change | **yes** | `i14` **EXACTLY 1 — `BD70b`, alone, its named target** — plus `i1315` 2 (`BP43`/`BP45`'s open-set legs) | not a coverage hole: the change with the **smallest** surface is pinned in **two** files, which is what the scout feared would be a zero | ✔ |
| `S7` | `browser_refresh`: gate the header on the foreign match count — `if {$ndbs == 0} {set groups [list [list {} {} $entries $root]]}` | **yes** | `i14` **3** — `BD70c` (its named target), `BD51`, `BD69` — and `i1315` 1 (`BP53`). All four the flicker family | **`BD67` and `BD68` GREEN**, because with a foreign DB *matching* nothing looks wrong; the flicker only shows under a **pattern** | ✔ |

### 7.2 ⚠ A CORRECTION: `S6` DOES NOT RED `BD69`

The first version of this receipt claimed in prose that *"`BD69` is now the ONLY
check sabotage `S6` fails in `i14`"* while its own table said *"`i14` EXACTLY 1 —
`BD70b`, alone"*. **The table is right and the sentence was wrong.** The verifier
settled it by replaying `S6` verbatim: it reds **`BD70b`** in `i14`, plus
`BP43`/`BP45` in `i1315`.

`BD69` fires on the **opposite** defect — opening the header on *every* populate,
not never opening it. Both checks exist and both are real coverage; the two
directions of the open rule are each pinned by exactly one check:

| defect | sole witness |
|---|---|
| the header is **never** born open (`S6`) | **`BD70b`** |
| the header is **always** re-opened (`VS2`, and `$first` joined instead of replaced — `VS1`) | **`BD69`** |

**Neither may be weakened**, and this correction matters because it is the record
item 16 inherits.

### 7.3 The verifier's own unnamed sabotages

Three invented, plus the `S6` replay, all under the verifier's **own** locked and
trapped driver (lock dir, `EXIT`/`INT`/`TERM` restore from a byte-exact backup,
a Python pre-state occurrence assertion exiting 8 on ≠ 1 match, sha256 before and
after, `diff` + sha equality on restore, and a filter treating a missing
`RESULT:` line as `NORESULT` == RED).

| # | injected | reds | what it proves |
|---|---|---|---|
| `VS1` | `browser_populate`: restore `$first` semantics **while keeping** the `rootpar` clause — `[lsearch -exact $existed $id] < 0` → `![llength $existed]` | `BD70b` (`i14`) + `BP43`, `BP45` (`i1315`) | **The most valuable row.** It aims at the one design claim the item DECLARED as a divergence but that **none of its own seven sabotages tested** (§5 D4). The `i14` fixture ticks the box AFTER a box-off populate, so `$first` is false exactly on the populate that creates the header — the joined spelling ships a **collapsed** header on the one gesture that makes it. The claim is now measured, not merely asserted |
| `VS2` | `browser_populate`: open the header + root on **EVERY** populate (drop the newly-born guard entirely) | **`BD69` ALONE**; `i1315` and `2pane` fully green | R5's guard earns the id it was re-spent on (§6.1), and the two directions of the open rule are each pinned by exactly one check (§7.2) |
| `VS3` | `browser_rows_multi`: collapse "absent" and "deliberately empty" prefix — `[llength $g] < 5` → `$gpfx eq {}`, precisely the trap the source comment warns about | **17** in `i14` (`BD62`, `BD62b`, `BD65`, `BD66`, `BD66b`, `BD49`, `BD50`, `BD48c`, `BD50c`, `BD70`, `BD70b`, `BD51`, `BD70c`, `BD69`, `BD51b`, `BD58b`, `BD54`) and **9** in `i1315` (`BP43a`×2, `BP43`, `BP45`, `BP47b`, `BP52`, `BP53`, `BP54`, `BP55`) | **The strongest single result of the verification.** Reding `BP52`-`BP55` independently reproduces §2.1's rationale from the other side: the PLAN's `d:0\|` prefix really does make every persisted tree id name a row that no longer exists, evaporating the user's selection and open set with **no defect in the persistence code**. The divergence is forced by measurement, not preference |
| `S6` replay | verbatim | `BD70b` (`i14`), `BP43`/`BP45` (`i1315`) | settled §7.2's contradiction |

Check **COUNTS held at 107 / 190 / 108** on every one of these runs (no file
aborted early), and the tree was restored byte-exact each time — sha256 of
`src/wave_viewer.tcl` back to its shipped value, `git diff --quiet HEAD --
src/wave_viewer.tcl` clean, and a clean 2/2 green re-run afterwards (107 and
190, zero fails).

**No sabotage aimed at the item core stayed green. No coverage hole found.**

---

## 8. Every existing check RESTATED — 15 across two files, none deleted

### `tests/headless/test_wave_sigbrowser_i14.tcl`

| id | what moved | why |
|---|---|---|
| `BD48` | leg 3's parent moves from the DB header to that DB's **own** design root (`bd_a`); a NEW leg 4 carries the old header value at its new depth | the claim "a foreign leaf is labelled with its SOURCE" is **re-anchored, not weakened** |
| `BD49` | **TITLE REWRITTEN**, not just re-valued. New leg 5 is the negative: the PREFIXED spelling must NOT exist | item 14's invariant was *"the current DB's rows stay TOP-LEVEL and UNPREFIXED"*. R7 kills the first half (a header now); §4.3 keeps the second. **A title still promising "top-level" would be a lie in the test file.** ⚠ THE PLAN DID NOT NAME THIS CHECK |
| `BD48c` | **ITEM 15'S OWN TOMBSTONE, INVERTED.** `browser_root_id` `{}` → `g:`; leg 2 `absent` → the current DB's header; new leg 4 pins that no PREFIXED current-DB root exists | its item-14 comment said a green version after item 15 would mean item 15 never ran. ⚠ THE PLAN DID NOT NAME IT |
| `BD50` | leg 2's parent → `bd_a`; NEW leg 3 → `bd_b` | the two copies of `v(shared)` are now provably from **different runs**. The only check the PLAN named correctly, though for the wrong reason |
| `BD50b` | leg 4's model parent → `bd_a`; NEW leg 5 keeps the header claim as the **grandparent**; legs 1-3 untouched | ⚠ THE PLAN DID NOT NAME IT |
| `BD50c` | upper-pane id set `{d:0}` → `{d:1 g: d:0 d:0\|g:}` (measured depth-first order, current DB first) | **ITEM 14 PREDICTED THIS RED IN ITS OWN COMMENT.** ⚠ THE PLAN DID NOT NAME IT |
| `BD51` | leg 2 `empty` → the current DB's header + root; the foreign `absent` **stands** | the tree is legitimately non-empty now, and leaving `empty` would make a **correct** tree read as a regression. The foreign `absent` is the negative this check exists for. The PLAN named `BD51` but prescribed a fix for a form item 10 had already replaced |
| `BD51c`, `BD58c` | row count 7 → **10** (2 headers + 2 design roots + 6 leaves) | MEASURED, not derived. ⚠ THE PLAN DID NOT NAME EITHER |
| `BD58` | leg 4's node parent moves from the header `d:9` to that DB's own root `d:9\|g:` | item 12's ONLY All-DBs class-filter check. The seeded 3-key dict was deliberately **not** widened with a `path` key — that would be a control eating its own fixture (§3.3) — so the check asserts the ID, never the text. ⚠ THE PLAN DID NOT NAME IT |
| `BD56`, `BD56b` | a **third** per-token array (`browsercurdb`) joins the live teardown pair | a new per-window leak is caught by a **live** check rather than a source grep |

### `tests/headless/test_wave_sigbrowser_i1315.tcl`

| id | what moved | why |
|---|---|---|
| `BP43a` | **ITS OWN TOMBSTONE, INVERTED.** `no-root`/`none` → `g:`/`g:`; `exists g:` 0 → 1; **legs 5-7 STAY 1** | its comment said a GREEN `BP43a` after item 15 means item 15 did not do its job. That legs 5-7 do **not** move is itself §2.1's ruling |
| `BP43` | `bp_open0` `none` → `{d:N g:}`; the open-set legs gain the two born-open rows | ⚠ THE PLAN DID NOT NAME IT |
| `BP45` | the snapshot's `open` field, the same way | ⚠ THE PLAN DID NOT NAME IT |
| `BP53` | open set `g:y3` → `{g: g:y3}`, **plus a new leg 4 pinning the DB header CLOSED** | that fourth leg is declared limit **D1** measured as a value instead of only in prose (§9) |

### Restated, then MEASURED NOT TO MOVE — kept with their item-12/14 values and a comment saying why

`BD51b`, `BD54`, `BD58b`, `BP52`, `BP54`, `BP55`, and the three fixture pokes at
`g:x1` / `g:y3` / `g:x1.x2`.

**That they did NOT move is the evidence for §2.1's ruling.** Under the PLAN's
design all seven would have re-keyed — and `BD54` in particular would have failed
as a **WRONG VALUE** (0, from "nothing selected to plot"), reading exactly like a
real cross-DB plotting regression rather than like a scheme change.

---

## 9. Declared limits — measured, shipped, stated

| # | limit |
|---|---|
| **D1** | **A persisted DB-HEADER open state does not survive a registry renumber.** The header id is the ONE id that must carry the registry index. `browser_populate` inserts it open, but **§4.2 rules that the persisted `open` set WINS**, and that set named the old slot — so after a restore that renumbers the registry the current DB's header comes back **COLLAPSED** and the restored selection is scrolled out of sight until one click. **Predicted otherwise; the measurement won.** Asserted as a value in `BP53` leg 4. The **SELECTION** and the instance-node collapse both survive, which is the whole point of the unprefixed ids (`BP47b`, `BP52`, `BP54`, `BP55`). Fixing it means either overriding §4.2 or teaching persistence about DB identity; both are larger than R7 |
| **D2** | **The lower pane always shows the CURRENT DB's names.** `browserseaent` holds the current DB's entries only, and a FOREIGN design root decodes to the empty path exactly like the current one — so clicking a foreign root shows the **current** DB's own-level signals. Reachable for the FIRST TIME here (foreign roots did not exist before item 15). Asserted as a VALUE in `BD70d`, with a positive control taken **before** the foreign root is selected, rather than left to be discovered. Scoping the sea per DB belongs with §7.2's caption |
| **D3** | **Selecting a DB HEADER (not a root) sends the sea a path of `<idx>`**, which matches nothing and leaves the pane empty. Pre-existing — item 14 shipped the headers — but item 15 makes headers far more clickable. Not fixed here |
| **D4** | **A seeded foreign inventory carrying no `path` key floors its design-root text at `design`** (`browser_root_label`'s floor). `BD58`'s block hand-seeds a 3-key dict and must **NOT** be "fixed" by calling `browser_refresh $tok 1` — see §3.3. The check asserts the root's ID, never its text |
| **D5** | **`.ph` is still class-filter blind and is UNTOUCHED.** `extra`/`ndbs` stay strictly inside the FOREIGN loop, so the current DB is never folded into them; `BD52`, `BD52b` and the `.ph` freeze carried in from item 12 (`BX37`, `BX42`, `BX44`-`BX46`, `BH50`, `BH51`, `BH54`) hold byte-identically |
| **D6** | **Cross-DB plotting is still unguarded** — item 14's declared limit D5, re-measured green here. A foreign row plots exactly like a current one and the trace then resolves its expression against the **CURRENT** DB. Item 15 adds no guard; `BD54` pins the behaviour that exists |

---

## 10. Frozen oracles, re-grepped by hand after the fact

Both the implementer and the verifier re-checked these by running greps, not by
assuming:

* **`BD06`** — `grep -c browser_alldbs src/wave_viewer.tcl` == **2**. Item 15
  edits the exact block that warning lives in; **the accessor is named in NO new
  comment** (§3.1).
* **`GS1`/`GS2`** — `git show e1cfd5ff -- src/wave_viewer.tcl | grep -E '^[+-]proc '`
  is **empty**: zero new procs, so the parent spec's contract list does not move.
* **`BW53`** — `see` is still absent from `browser_populate` (§4.2's prohibition).
* `BW59` (`browser_devint`/`browser_srccur` == 4 each, one of each in
  `browser_refresh`), `BD07` (`signal_list`/`signal_list_all` == 1 each in
  `browser_reload`), `browser_reload` names the checkbox reader **0** times,
  `browser_refresh` carries exactly one `catch {wviewer::browser_reload` and one
  `catch {wviewer::browser_populate`, `BP04`'s zero-hit leg (§3.2), the three
  `forget` per-name counts, `BT08`/`BT09`, `BS01`-`BS03`, `BP07`, `BD01`/`BD01b`,
  `BW52`, `TP33`/`TP40`/`TP41`/`TP42`/`TP43`, `GH0`/`GH2`/`GH4`/`GH8`/`GH9`, and
  the `.ph` pins `BD52`/`BD52b`/`BX37`/`BX42`/`BX44`-`BX46`/`BH50`/`BH51`/`BH54`.

**All green, all measured, none by assumption.** `git show --stat e1cfd5ff` is
exactly four files; `git status` over `src/` and `tests/` is clean — **no
droppings left in the repo**.

---

## 11. ⚠ THE OWED EYEBALL — item 15 is `[E]`, not `[x]`

No check in this batch judges pixels, and item 15's deliverable is a tree whose
**top level changes shape on screen**. The 18 new checks judge widget **STATE**
(ids, text, `-open`, selection), which is program behaviour; what they cannot
judge is that the state **reads as the right thing**. The X arm also ran under
**Xvfb, with no window manager**, which is correct for this item but is a further
reason the appearance claim cannot be closed by a check.

**Script — 3 minutes, needs a real display:**

1. Open the waveform viewer, **load TWO raws** (the second via the usual load
   path, so both sit in the registry) and show the Signal Browser sidebar.
2. **Tick the All-DBs box.** The tree's **TOP LEVEL** must become one row per
   database — **the current one included**. Two raws ⇒ **two** top rows, and
   nothing else at that level.
3. Each header must carry **that database's own design root**, named for **that
   database's own raw**. ⚠ The failure this replaces is a foreign header whose
   root reads the **current** design's name — see §7.1 `S2`. If both roots read
   the same name, item 15 is wrong even though `BD48` is green.
4. **The current DB's header AND its root come back OPEN**; **the foreign
   header stays COLLAPSED.** (Not "eventually opens" — on the tick itself. §3.4
   is exactly the bug where they arrive collapsed on the gesture that makes
   them.)
5. **Collapse a header by hand, then type in the search bar.** It must **stay**
   collapsed — R5's guard, `BD69`.
6. **Judge the picture, which is what no check does:** indentation and nesting
   depth read as sensible at a glance; the header and the root beneath it are
   distinguishable, not a doubled-up row; and a **real** raw path does not
   truncate the label into uselessness.
7. Click a **foreign** design root. ⚠ Expected today: the lower pane shows the
   **CURRENT** DB's own-level signals — declared limit **D2**, not a bug to
   report. Clicking a **header** leaves it empty — **D3**.

**A one-DB tree answers nothing**, and neither does the box left OFF — that is
item 10's shape and it is unchanged.

Fail on any of steps 2-6 → item 15 goes **`[F]`**, not `[E]`.

---

## 12. Owed / for the next item

* **The eyeball above.** Item 15 is `[E]` with a row in `LEDGER.md`'s eyeball
  queue against `e1cfd5ff`.
* **Item 19 owns the spec edit.** §4.3's "unlabelled" clause is stale (D7) and
  §4.1's "this is the single change in `browser_populate`" is now two (D3). Both
  are flagged in the shipped comments as well as here.
* **D1 is a real user-visible loss** and is nobody's yet: a restore that
  renumbers the registry brings the current DB's header back COLLAPSED. Settling
  it means overriding §4.2 or teaching persistence about DB identity.
* **D2/D3 belong with spec §7.2's per-node caption** — scoping the sea per DB and
  giving a header selection something to say are the same piece of work.
* **`.ph` is still class-filter blind** (D5), carried forward from item 12
  unchanged. Whoever takes §7.2's three-state caption settles it; nobody else may
  move it.
* **Cross-DB plotting is still unguarded** (D6). `BD54` pins what exists.
* **Item 16 (R9, Ctrl-L → Ctrl-B) must restate `BS03`**, which pins Ctrl-L as a
  WaveViewer default that breaks. Item 15 deliberately did not touch
  `BS01`-`BS03`, `BT08`/`BT09` or any binding, key or menu row.
* **Next free check ids:** `BD71` in `i14`, `BP78` in `i1315`. Other bands, for
  the record and not to be taken here: `BW79`, `TP45`, `BX54`, `BH55`.
* **The new baseline for item 16:** headless **1637** / 14 files / 0 fail
  (`i14` at **56**, every other file as in the item-14 table); X **11/11,
  2192** (`i14` **107**, `i1315` **190**, every other suite as before). Baseline
  fails: **NONE**. Transcribed into `LEDGER.md`'s "Recorded baseline" section by
  the ledger stage.
