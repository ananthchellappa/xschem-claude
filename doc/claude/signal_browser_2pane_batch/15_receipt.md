# TWO-PANE item 15 — R7: All-DBs headers + a design root per DB

`doc/claude/specs/waveform_signal_browser_two_pane.md` R7 / §4.1 / §4.3, M11.
PLAN item 15. Files touched:

* `src/wave_viewer.tcl`
* `tests/headless/test_wave_sigbrowser_i14.tcl`
* `tests/headless/test_wave_sigbrowser_i1315.tcl`

---

## 1. Baselines, re-measured FIRST on the unchanged tree

| arm | recorded | re-measured | drift |
|---|---|---|---|
| headless, 14 wave files | 1628 / 0 fail | **1628 / 0 fail**, every per-file figure identical | none |
| X, 11 suites via `xarm.sh suites` | 11/11, 2174 | **11/11, 2174**, every per-suite figure identical | none |

So every red below is attributable.

## 2. What shipped

**R7's tree shape.** With the All-DBs box ticked, the tree's TOP LEVEL is now the
per-database headers — the CURRENT database included — and each header carries
that database's OWN design root, named for that database's OWN raw.

Four source edits:

* **`browser_reload`** captures the current DB's HEADER IDENTITY
  (`{id d:<registry idx> label ..}`) into a new per-token array
  `browsercurdb($token)`, in the same pass that already captures item 10's raw
  path — so `browser_refresh`, which rides both searchbars' key pump, never takes
  a context loan per character. Each FOREIGN dict gains a `path` key beside
  id/label/names. The array is declared at the top of the namespace and unset in
  `forget`; BD56/BD56b are the live teardown legs.
* **`browser_rows_multi`** takes two OPTIONAL extra tuple elements:
  `{gid glab entries ?root? ?prefix?}`. Every 3-element call is byte-identical.
* **`browser_refresh`** always computes the root label, labels group 0 when the
  box is ticked (and only then), and gives each foreign group its own root label.
* **`browser_populate`** opens the design root's PARENT as well as the root, when
  both are newly born.

## 3. THE DIVERGENCE THAT MATTERS: the current DB keeps UNPREFIXED ids

**PLAN item 15 says group 0 gets a `d:0|` prefix.** It does not. It gets a
HEADER; its rows keep `g:`, `g:x1`, `s:v(n)`.

Two reasons, and the second is a measurement that the RED run produced:

1. **Spec §4.3's closing sentence rules it**: "the current DB is always group 0,
   unlabelled and unprefixed, and that invariant is what makes 'current'
   well-defined when two DBs have different top cells." Only the *unlabelled*
   half can survive R7. The task's own precedence rule (spec beats PLAN) applies.
2. **MEASURED**: the prefix would be the DB's REGISTRY INDEX, which is not a
   property of the design. `test_wave_sigbrowser_i1315.tcl`'s restore fixture
   snapshots with TWO raws loaded, where the current one is slot **1**, and
   `restore` brings back ONE, where it is slot **0**. Under the PLAN's scheme
   every persisted `d:1|g:x1.x2` names a row that no longer exists, so the user's
   selection and open set silently evaporate — BP52, BP53, BP54 and BP55 all go
   red with no defect in the persistence code at all. That is what the FIRST RED
   RUN produced (`BP47b -> {0 1 1}` against `{1 1 1}`), and the design was
   corrected before any source was written.

`BP47b` is the check that records it: it asserts the slot really does move
`1 -> 0` across the restore AND that the persisted bare ids survive it anyway.
It is pinned to the literals `1` and `0` rather than to "they are equal", so it
stops saying anything only when the drift stops happening.

R7's letter — "per-database headers become the tree's top level, above each DB's
design root" — is satisfied either way; `BD68` is the check that says so.

### The other divergences

* **The helper gained two optional tuple elements.** PLAN item 15 states
  "browser_rows_multi's helper contract is NOT changed" and then prescribes a
  BD50 replacement whose parent row reads `bd_a`. The unchanged helper provably
  cannot produce that — it threads ONE root string into every group, so every
  DB's root renders the CURRENT design's name under a FOREIGN DB's header. Both
  new elements are optional and every 3-element call is byte-identical
  (BD19-BD25c, TP33, TP40, TP41 all green untouched). `BD62b` is the leg.
* **`browser_populate` gets a SECOND change.** Spec §4.1 says "Inserted closed
  (`-open 0`) — R1. This is the single change in `browser_populate`." Item 15
  makes it two: the current DB's header is born open as well as its root, because
  R4's selected root otherwise sits inside a collapsed parent that nobody can see
  and `see` is forbidden here (§4.2, BW53). M11's own rationale applies verbatim.
  Foreign headers stay collapsed (BD70b leg 3).
* **`$first` was replaced by "newly born", not joined to it.** `$first` means
  "the tree was empty", which is FALSE on the populate that matters most —
  ticking the box re-shapes an already-drawn tree, so under `$first` the header
  and root arrive collapsed on the one gesture that creates them. "Newly born" is
  a strict superset ({} existed ⇒ everything is newly born) and leaves item 10's
  carry-over untouched. `BD69` is R5's guard on it: a search keystroke never
  re-opens a header the user collapsed.
* **§4.3's own text is now stale** in one clause ("unlabelled"). Item 19 owns the
  spec edit; R7 and §4.3's first sentence already rule the other way, as do the
  shipped comments at `browser_id_path` and `browser_root_id`.

## 4. Numbers

**headless — 1637 over 14 files, 0 fail** (was 1628). The whole +9 is in
`test_wave_sigbrowser_i14` (47 → **56**): BD60, BD61, BD62, BD62b, BD63, BD64,
BD65, BD66, BD66b, the nine PURE checks. Every other file byte-identical.

**X arm — 11/11, 2192 checks** (was 2174).

| suite | before | after | why |
|---|---|---|---|
| `i14` | 91 | **107** | +16: the 9 PURE above plus BD67, BD68, BD69, BD70, BD70b, BD70c, BD70d |
| `i1315` | 188 | **190** | +2: `BP43a`'s new negative control, and `BP47b` |
| every other suite | — | **identical** | untouched |

## 5. The RED run, and the one vacuity it caught

Checks were written and run BEFORE any source edit. In the headless arm 9 of 9
new PURE checks failed; in the X arm every new check failed **except one**:

* **`BD69` as first written** ("box OFF: the tree's top level is the single
  design root") **PASSED on the RED run.** It is item 10's shipped shape, so it
  could not fail in the direction this item moves — a control that is not
  evidence. It was rewritten: the box-OFF reading became a CAPTURE folded into
  `BD68`'s tuple as leg 1 (so BD68 now carries its own control), and the `BD69`
  id was re-spent on a genuinely new claim — R5's guard on the new open rule,
  which is red before the code and is the ONLY check S6 fails.

Two expected literals were predicted wrong and the MEASUREMENT won; both are
recorded in the check comments:

* `BD49` leg 4: `bd_ids_for {time}` was predicted as one id and measured as
  **two** — `time` is in both fixture raws, so it resolves to the current DB's
  unprefixed id AND the foreign DB's prefixed one. The measured form is the
  better leg: both id schemes on one name, in row order.
* `BP53`: the restored open set was predicted to contain the current DB's header
  and measured NOT to. See the declared limit in §7.

## 6. Existing checks RESTATED (never deleted) — 15 across two files

`test_wave_sigbrowser_i14.tcl`

| id | what moved |
|---|---|
| `BD48` | leg 3's parent header → that DB's own root `bd_a`; a NEW leg 4 carries the old header value at its new depth |
| `BD49` | **TITLE REWRITTEN** — item 14's "stay top-level and unprefixed" is half inverted (a header now) and half load-bearing (still unprefixed); leg 5 is the negative for the PLAN's design |
| `BD48c` | **item 15's tombstone, inverted.** `browser_root_id` `{}` → `g:`; leg 2 `absent` → the current DB's header; new leg 4 pins that no PREFIXED current-DB root exists |
| `BD50` | leg 2's parent → `bd_a`; new leg 3 → `bd_b`, so the two copies are provably from different runs |
| `BD50b` | leg 4's parent → `bd_a`; new leg 5 keeps the header claim as the grandparent |
| `BD50c` | **item 14 predicted this red.** id set `{d:0}` → `{d:1 g: d:0 d:0|g:}` |
| `BD51` | leg 2 `empty` → the current DB's header + root (the tree is legitimately non-empty now) |
| `BD51c`, `BD58c` | row count 7 → **10** (2 headers + 2 roots + 6 leaves) |
| `BD58` | leg 4's node parent `d:9` → `d:9|g:` |
| `BD56`, `BD56b` | a third per-token array joins the teardown pair |

`test_wave_sigbrowser_i1315.tcl`

| id | what moved |
|---|---|
| `BP43a` | **its own tombstone, inverted.** `no-root`/`none` → `g:`/`g:`; `exists g:` 0 → 1; legs 5-7 stay 1, which is the ruling |
| `BP43` | `bp_open0` `none` → `{d:N g:}`; the open set gains the two born-open rows |
| `BP45` | the `open` field the same way |
| `BP53` | open set `g:y3` → `{g: g:y3}`, plus a new leg pinning the header CLOSED (see §7) |

**Restated and then measured NOT to move after the design correction — kept with
their item-12/14 values and a comment saying why:** `BD51b`, `BD54`, `BD58b`,
`BP52`, `BP54`, `BP55`, and the three fixture pokes at `g:x1`/`g:y3`/`g:x1.x2`.
That they did not move IS the evidence for §3's ruling.

## 7. Declared limits (measured, shipped, stated)

1. **A persisted DB-HEADER open state does not survive a registry renumber.**
   The header id is the one id that must carry the index. `browser_populate`
   inserts it open, but §4.2 rules that the persisted `open` set WINS, and that
   set named the old slot. After such a restore the current DB's header comes
   back COLLAPSED and the restored selection is scrolled out of sight until one
   click. MEASURED and asserted as a value in `BP53` leg 4; the SELECTION and the
   instance-node collapse both survive (`BP47b`, `BP52`, `BP54`, `BP55`).
2. **The lower pane always shows the CURRENT DB's names.** `browserseaent` holds
   the current DB's entries only, and a FOREIGN design root decodes to the empty
   path exactly like the current one — so clicking it shows the current DB's
   own-level signals. Reachable for the first time here (foreign roots did not
   exist before). Asserted as a VALUE in `BD70d` rather than left to be
   discovered. Scoping the sea per DB belongs with §7.2's caption.
3. **Selecting a DB HEADER (not a root) sends the sea a path of `<idx>`**, which
   matches nothing. Pre-existing (item 14 shipped headers); item 15 makes headers
   more clickable. Not fixed here.
4. **A seeded foreign inventory with no `path` key floors its root text at
   `design`.** BD58's block hand-seeds a 3-key dict and must NOT be "fixed" by
   calling `browser_refresh $tok 1`, which re-enters `browser_reload` and destroys
   the seed. The check asserts the root's ID, never its text.
5. **`.ph` is still class-filter blind and is UNTOUCHED.** `extra`/`ndbs` stay
   inside the foreign loop, so BD52/BD52b and the `.ph` freeze carried in from
   item 12 hold byte-identically.

## 8. Sabotage verification

Run under a LOCKED driver with an EXIT/INT/TERM trap restoring from a byte-exact
BACKUP (never `git checkout --` — the item was uncommitted), a PRE-STATE
occurrence assertion before each patch, a sha256 change proving the mutation
reached disk, a `diff` on restore, and an output filter counting **NORESULT and
TIMEOUT as reds**. Clean baseline and clean re-run either side: 107 / 190 / 108,
0 fails.

| # | injected | reds | positive control |
|---|---|---|---|
| S1 | `browser_rows_multi` never prefixes a foreign group | i14 **24** (BD62, BD64, BD66, BD66b + the live throw), i1315 1, 2pane 6 (TP33, TP41, TP43). **i14's count fell 107 → 83** — the duplicate `g:` really does throw and take the file's outer catch, which is the failure the prefix exists to prevent | BD19/BD21/BD22 (the unlabelled arm) GREEN |
| S2 | `browser_refresh` drops each FOREIGN group's own root label | i14 **3** — BD48, BD50, BD50b, all three the ROOT TEXT | **BD62b (PURE) GREEN** — the helper is fine, the CALLER is the defect |
| S3 | `browser_refresh` never labels group 0 | i14 **11**, i1315 **4** | **BD62/BD48/BD50 GREEN** — the foreign side is untouched, so this is provably about the caller (trap §3.2's whole point) |
| S4 | the per-group root becomes MANDATORY (shared-`$root` fallback dropped) | i14 1 (BD61's 4th leg pair), 2pane 5 (TP33, TP41) | BD60 leg 1 GREEN — the unlabelled arm is a different code path |
| S5 | `browser_reload` hard-codes `d:0` as the current DB's header id | i14 **20**, i1315 **5**; the collision with the foreign `d:0` throws, count 107 → 87 | — (the label survives; BD67's TEXT leg is right and its ID legs are wrong, which is the id/label separation) |
| S6 | `browser_populate` opens only the root, never the header above it | i14 **1 — BD70b ALONE**, i1315 2 (BP43/BP45's open-set legs) | everything else GREEN. Not a coverage hole: A4 is pinned in two files |
| S7 | the current DB's header is gated on how many FOREIGN DBs matched | i14 **3** — BD70c (its named target), BD51, BD69 | **BD67/BD68 GREEN** — with a foreign DB present nothing looks wrong; the flicker only shows under a pattern |

## 9. Frozen oracles, re-grepped after the fact

`BD06` (`browser_alldbs` file-wide == 2 — item 15 edits the exact block that
warning lives in and the accessor is named in NO new comment), `BW59`
(`browser_devint`/`browser_srccur` == 4 each), `BW53` (`$tv see` == 0 in
`browser_populate`), `BD07` (`signal_list`/`signal_list_all` == 1 each in
`browser_reload`), `browser_reload` names the checkbox reader 0 times,
`browser_refresh` carries exactly one `catch {wviewer::browser_reload` and one
`catch {wviewer::browser_populate`, `BP04`'s zero-hit leg (the new
`browsercurdb(` matches none of `sbcase(|sbcfg(|sballdb(|dest(` and
`browser_state` never reads it), `GS1`/`GS2` (**no new proc** — the item adds
zero `proc wviewer::` lines), `BT08`/`BT09`, `BS01`-`BS03`, `BP07`, `BD01`/
`BD01b`, `BW52`, the three `forget` per-name counts, `TP33`/`TP40`/`TP41`/
`TP42`/`TP43`, and the `.ph` pins `BD52`/`BD52b`/`BX37`/`BX42`/`BX44`-`BX46`/
`BH50`/`BH51`/`BH54`. **All green, all measured, none by assumption.**

## 10. The new baseline for item 16

**headless 1637 / 14 files / 0 fail** — `i14` at **56**, every other file as in
the item-14 table.
**X 11/11, 2192** — `i14` **107**, `i1315` **190**, every other suite as before.
Baseline fails: NONE. Next free check ids: `BD71` in i14, `BP78` in i1315.
