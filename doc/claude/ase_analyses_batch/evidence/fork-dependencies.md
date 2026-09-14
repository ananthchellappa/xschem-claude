# Dossier: what ASE-L silently depends on in *our* ngspice

**Reader:** the crew that builds the stock/basic ASE-L the user asked for — the one that
must work on `apt install ngspice` and on a plain `git clone && ./configure && make` of
upstream — and anyone who later asks "will this deck run on a binary that is not ours?"

**The question this pass answers.** ASE-L was developed against the fork, where 105
functional commits' worth of fixes are present. Some of those fixes are things ASE-L's own
behaviour now assumes. On apt 45.2 or on stock upstream those bugs are **live**, and ASE-L
will misbehave in ways nobody has ever seen. This dossier finds them, measures them, and
says what ASE-L must do about each.

**Anchors.** Bare `src/…` paths are `/home/analog/dev/ngspice/…`. `ase.tcl`,
`ase_window.tcl` and `op_annot.tcl` are under `/home/analog/dev/xschem-claude/src/`;
that tree is dirty and moving, so **everything in it is cited by proc name, never by line
number**.

**The two binaries.** Everything marked **MEASURED** was run here on 2026-09-10 against
both of:

| tag | path | banner | provenance |
|---|---|---|---|
| **APT** | `/usr/bin/ngspice` | `ngspice-45.2` | Debian `45.2+ds-1`, KLU. **The fixes below are ABSENT.** |
| **FORK** | `/home/analog/dev/ngspice/build-ver_50/src/ngspice` | `ngspice-46+` | `ver_50`, `git describe = ngspice-46-419-gccebdf2a2`, KLU. |

**Stock upstream 47 was not built** and is not measured here (driver task A, still open).
Where a claim would differ between "apt 45.2" and "upstream 47" I say so; where I could
not tell, §10 says so. Nothing in either repository was modified. Scratch decks and
captured output are in this session's scratchpad
(`…/scratchpad/fd/`); the load-bearing output is quoted inline below so the dossier
survives the scratchpad.

---

## 0. Executive summary — five sentences

1. **The ordinary ASE-L deck is byte-identical on apt 45.2 and on the fork.** The full
   render — `.options savecurrents` / `.temp` / `.save all` / per-output `.save` /
   `.save @dev[param]` / `.control` with `set appendwrite`, `set filetype=ascii`, the
   `$sim_status` guard, `remzerovec`, `write`, `print` — produced the same two-plot raw
   with the same ten operating-point vectors on both (§4.0). **That is the headline: ASE-L
   is not broadly broken on stock ngspice.**
2. **The driver's highest-risk suspicion is wrong, and that is worth knowing.** The two
   `.save` name-resolution fixes (`08451f50a`, `3330047d4`) are **`casemode=preserve` /
   `distinguish` only**. In the default `fold` mode a `.save v(midnode)` against a net the
   deck spells `MidNode` resolves identically on both binaries (§4.6). ASE-L's Outputs pane
   is safe on stock.
3. **Five fork fixes are hard crashes, measured live on apt 45.2** — SIGABRT or SIGSEGV,
   *with stdout destroyed because `abort()` does not flush stdio* — and three more are
   memory-safety or leak defects of the same family. Every one of the five is reachable
   only from text ASE-L does not itself emit (`unset`, `define`, `load`, a deck-level `.op`
   on an empty netlist), but every one of them **is** reachable from a user's
   `pre_commands` row, a hand-edited `.control` block, or a schematic's own code block —
   all three of which ASE-L passes through verbatim. §3, class **B1**.
4. **One fix produces a phantom signal in a shape ASE-L emits every day.** On apt 45.2, an
   operating-point plot holding **exactly one** vector is written with a second, bogus
   vector named `all` carrying the same data (`25e891ec3`). `.save v(out)` + `op` is
   exactly that shape. §4.2 — this is the one entry in the table that needs a mitigation
   in ASE-L's own emission, not a warning.
5. **The `casemode` capability cannot be probed by reading `$casemode`.** MEASURED: apt
   45.2 accepts `-D casemode=preserve` **silently, rc=0, no warning**, then answers
   `$casemode` → `preserve` while folding everything anyway. Only `$curcasemode` — which is
   fork-only (`6780b6a40`) and answers `no such variable` on stock — distinguishes *asked
   for* from *in force*. §6.3. This is the single strongest piece of evidence for V4's
   "probe the run, never a version string" doctrine, and it says the naive probe is a
   false positive.

---

## 1. Method, and what "classify" means here

```sh
git -C /home/analog/dev/ngspice log --oneline origin/pre-master-47..ver_50 \
  | grep -E "^\w+ (fix|feat):"      # -> 105 commits
```

All 105 were read to the point of knowing what behaviour changed. The fork's commit
messages carry an explicit **modes** paragraph — most say either "Not fold-mode visible"
with the reduction, or "This changes default mode behaviour; it is not a no-op". That
paragraph is the primary classifier; every claim that matters was then re-measured against
APT rather than trusted.

The three buckets from V3, with the counts:

| bucket | meaning | count |
|---|---|---|
| **(a)** extra capability | observable only under `-D casemode=preserve` / `distinguish`, or a fork-only variable / header line / diagnostic. **Stock is unaffected because the feature is not there.** | **60** |
| **(a′)** new output in the *default* mode | a fork-only diagnostic that fires with no flag at all. Stock is *quieter*, not wrong. This is the **reverse** dependency — §5. | **5** |
| **(b)** bug fixed here, live upstream | real behaviour delta in the default `fold` mode on a stock binary. **§3 is this list.** | **35** |
| **(n)** neither | fixes a regression the fork itself introduced, or touches only `doc/claude/` tooling. | **5** |

*(n) in full, so nobody re-derives them:* `7b5884249` (`constantplot`'s initialiser — the
missing member `pl_fromfile` is **fork-added**, so upstream's initialiser is complete),
`3d3e56e75` (repairs the fork's own `5573790ee` in `--with-ngshared`), `ce6d99d7b`
(repairs the fork's own `00446226e`), `b712fc9c6` (a `doc/claude/scripts/` python file, no
C at all), and `7304bba95` (four of its five defects are regressions from the fork's own
`4caf2ff35`; the fifth is upstream issue 0005's `is_xspice_model()` substring test, which
is a real upstream defect but is not reachable from anything ASE-L emits).

**The classification is complete and exclusive**: 60 + 5 + 35 + 5 = 105, every hash
accounted for exactly once, checked mechanically against the `git log` output rather than
by eye. The (a) list is not reproduced here — it is "everything else", and its members are
identifiable from their subjects, every one of which either names a casemode, names a
`fold`/`preserve`/`distinguish` gate, or is a `.model`/`.subckt`/device-letter fold whose
own commit message carries the "Not fold-mode visible" reduction.

---

## 2. What ASE-L actually hands to ngspice — the exposure surface

Read out of `ase::backend::ngspice::render_deck`, `ase::op_ctl_saves`,
`ase::backend::ngspice::sim_status_guard`, `ase::cosim_default_bridges`,
`::op_annot::save_cards`, `::op_annot::opdump_request` and
`ase::backend::ngspice::capabilities`. **SOURCE.**

**Deck level:** `.include` / `.lib` / `.param` (user text), `.options <name>[=<v>]`,
`.options savecurrents`, `.temp <n>`, `.save all`, `.save <expr>` per ticked output,
`.save @<dev>[<param>]` (op_annot tier c).

**Inside `.control`:** the user's `pre_commands` **verbatim**; `pre_set auto_bridge_d_in` /
`auto_bridge_d_out` for mixed-signal; `set appendwrite`; `save all <dev>[<wildcard>]…`
(tier b); `op` / `dc … / ac dec … / tran …`; `set altshow` + `show all > <path>` (tier d);
the `$sim_status` guard (`if $?sim_status = 0` / `echo NO-SIM-STATUS` / `end` /
`if $sim_status ne 0` / `echo RUN-FAILED` / `quit 1` / `end`); `remzerovec`;
`write <path>` or `write <path> all <names…>`; `print <expr>` per ticked output.

**Command line:** `<exe> -b [registry args] [-n] [-D casemode=<mode>] <deck>`.

**Not emitted anywhere:** `.op` as a dot card (the operating point is the `.control`
command `op`), `unset`, `define`, `undefine`, `unlet`, `load`, `source`, `diff`, `alter`,
`altermod`, `meas`, `linearize`, `settype`, `wrdata`, `eprvcd`, `setcs`, `uic`,
`gridstyle` / `plotstyle` / `hcopydevtype`. Every one of those is a *user-supplied-text*
exposure only, and that distinction is what the "does ASE-L touch it" column below records.

**Results are read by xschem, not by ngspice.** `ase::attach_dbs` calls
`xschem raw read <file> <type>`; `ase::raw_content_verdict` parses the raw header in Tcl.
ASE-L never issues an ngspice `load`, `unset`, `define` or deck-level `.op`. That single
fact — that every measured crash in §3 lives in *user-supplied* text — is what the
"does ASE-L touch it" column records, and it is why the answer to "will ASE-L work on
stock ngspice" is yes for the generated deck and "only with a linter" for what the user
types into it.

---

## 3. THE DEPENDENCY TABLE

One row per fork fix that is **live upstream**. `ASE-L touches it?` distinguishes
**EMIT** (ASE-L's own generated text reaches the defect), **PASS-THROUGH** (only a user's
`pre_commands` / hand-edited `.control` / schematic code block can reach it), and
**READ** (ASE-L consumes an artifact the defect corrupts).

### B1 — crashes and memory-safety faults, live on apt 45.2

| # | fork fix | what breaks without it (MEASURED on APT) | ASE-L touches it? | what ASE-L must do on a binary that lacks it |
|---|---|---|---|---|
| B1.1 | `ac1819ff8` — `cp_remvar` frees a node only when nothing points at it | `set temp=27` then **`unset temp`** → **SIGABRT rc=134**, stdout destroyed. `unset curplot` and `unset plots` the same, each by a different arm. §4.3 | **PASS-THROUGH** — no ASE-L path emits `unset` | **WARN + REFUSE.** Refuse to emit a `pre_command` or control line whose first word is `unset` on a binary without the fix. There is no salvage: `abort()` eats the log, so the user sees an empty pane and rc=134. |
| B1.2 | `c214616d2` — a define whose body is one node survives its own first call | `define c(x) 5` then `print c(2)` twice → **SIGABRT rc=134**. Default mode, three lines. §4.4 | **PASS-THROUGH** | **WARN.** Any `define` in user text is a hazard on stock. ngspice's own built-ins (`vm`, `vp`, `vdb`, `vr`, `vi`) are operator-rooted and unaffected — only a user `define` whose body is a bare value or vector. |
| B1.3 | `00446226e` — a function argument outlives the frame that hands it out | `define d(x,y) x` then `print d(2,3)` → **SIGSEGV rc=139**. §4.5 | **PASS-THROUGH** | same as B1.2 — one warning covers both. |
| B1.4 | `62c6a707a` — a computed variable is answered by its computation, not by a file | `load` a raw whose header carries `Option: curplot=…` (or `plots=`, or `curplotname=`) → **SIGSEGV rc=139** on the *next* command that walks the variable list. §4.8 | **PASS-THROUGH** (ASE-L reads raws with `xschem raw read`, never ngspice `load`) | **WARN** on a user `load`. **And measured good news:** the fork's own `casemodewrite` header line is `Option: casemode=…`, which does **not** collide with a computed name and loads cleanly on APT (§4.8b) — so a fork-produced raw is safe to hand to a stock binary. |
| B1.5 | `ce48f9630` — report an `.op` card with no netlist instead of aborting | A deck-level `.op` with no non-ground node → **SIGABRT rc=134**, `assertion 'plot_cur->pl_dvecs != NULL' failed`, **stdout gone**. §4.1 | **PASS-THROUGH** — `render_deck` emits `op` *inside* `.control`, which does **not** abort (MEASURED, both binaries, rc=0) | **NOTHING, structurally.** ASE-L is already immune by construction. Record it as a reason `op` must stay a control command: moving it to a dot card would import a crash on every stock binary for any empty schematic. |
| B1.6 | `75fb84480` — the auto-bridge's dead empty-family guard and its NULL `strcmp` | `family=""` on a `.model` card reaches `find_bridge()` as a name and silently selects the default bridge (a different device, different levels); and a family-bearing node meeting a family-less bridge passes NULL to `strcmp`. Both in the **default fold mode** (fork's own RED evidence; not re-measured here — see §10) | **PASS-THROUGH** — `ase::cosim_default_bridges` emits `pre_set auto_bridge_d_in/out`, the *manual* override, and names no `family` at all | **WARN** only if a user's `.model` card carries `family=`. ASE-L's own bridges never reach the NULL arm, because it needs at least one family-bearing node. |
| B1.7 | `db9d99843` — the subcircuit multiplier pass writing into its caller's arrays | Writes index `NPARAMS` of two `char *[NPARAMS]` stack arrays when `inp_get_params()` returns exactly `NPARAMS` (= 10000), and leaks the pair unconditionally | **PASS-THROUGH**, and unreachable in practice | **NOTHING.** Listed for completeness; a 10000-parameter `.subckt` is not an ASE-L shape. |
| B1.8 | `3c1386e30` — `undefine` reclaims the vector a stored body owns | Not a fault, a leak: `define c(x) 5` then `undefine c` loses 170 bytes; 2000 define/undefine cycles lose 319,840 bytes in 1,999 blocks. `free_pnode_x()` frees `pn_value` only at `pn_use == 1` and a stored body's root rests at 0. Mode-independent, upstream | **PASS-THROUGH** | **NOTHING.** Bounded by how many `define`s a user writes, and a batch process exits. Listed because §3 is meant to be exhaustive about (b), not because it is actionable — and because it is one more reason the `define` warning of B1.2/B1.3 is worth having. |

### B2 — silent wrong answers and lost data, live on apt 45.2

| # | fork fix | what breaks without it (MEASURED on APT) | ASE-L touches it? | what ASE-L must do |
|---|---|---|---|---|
| **B2.1** | **`25e891ec3` — withhold the wildcard rename from a one-vector match** | A plot holding **exactly one** vector is written with a **second, phantom vector named `all`** carrying the same data. `.save v(in)` + `op` + `write f` → the raw's `Variables:` block is `v(in)` **and** `v(all)`. Two saves or more: clean. A `tran` plot: clean (the `time` scale is a second vector). §4.2 | **EMIT — this is the only row in the table on ASE-L's own generated path** | **MITIGATE UNCONDITIONALLY** (V6 holds here). Two candidates, both free on a fixed build: (i) never let an operating-point plot carry exactly one vector — the `.save all` leader that `render_deck` already emits under `save_all_v` does this, so **make it unconditional whenever the op plot would otherwise hold one save**; or (ii) have `ase::raw_content_verdict` drop a variable literally named `all`/`allv` when it is a duplicate of another column. Prefer (i): it fixes the file, not the reader, so xschem's browser and any third-party viewer both see the truth. |
| B2.2 | `5573790ee` — a loaded plot does not answer the reader's policy questions | `load` a raw whose header carries `Option: no_auto_gnd`, then `source` a deck: **the deck is parsed under `no_auto_gnd`** — a data file reconfigured the reader. MEASURED, and the direction is unmistakable: on APT the deck ran (rc=0, `v(in)=1`); on FORK the same deck correctly died `Fatal error: instance v1 is a shorted VSRC`, because `gnd`→`0` was restored. §4.9. Same for `ngbehavior`, `sourcepath`, `casemode`. | **PASS-THROUGH** | **WARN** on a user `load` followed by a `source`/`.include`. Note the *safe* direction: the guard makes stock more permissive, never less, so nothing ASE-L emits gets *rejected* — it gets silently parsed under someone else's dialect. |
| B2.3 | `131779106` — keep the `gnd` rewrite out of control-language command text | A whitespace- or paren-delimited bare `gnd` in a **control command argument** is rewritten to ` 0 `. MEASURED on APT: `echo M7MARK my gnd rail` → `M7MARK my 0 rail`; `shell echo "M7SH rail gnd here"` → `M7SH rail 0 here`; `echo v(gnd)` → `v( 0 )`. Paths are safe (`/`, `_`, `-`, `.` are not delimiters), so `write .../gnd/x.raw` survives. §4.7 | **PASS-THROUGH** for `echo`/`shell`/`source`/`cd`/`wrdata`; ASE-L's own two `echo` markers are `NO-SIM-STATUS` and `RUN-FAILED` | **WARN** if a user control line carries a bare `gnd` token. Low blast radius but the `shell` arm is a command with side effects doing something else than what was written. |
| B2.4 | `47c52c7dd` — report vector names as stored instead of lowercasing them on output | `let MyVec = 5` then `write f MyVec` stores the column as **`myvec`**. MEASURED: APT `myvec`, FORK `MyVec`. (`print` echoes lowercase on **both**, so only the *file* differs.) §4.10 | **PASS-THROUGH** — `render_deck` emits no `let` | **NOTHING**, unless a user's control text builds vectors with `let` and expects the browser to show its spelling. Then: warn. |
| B2.5 | `3b6780fc2` — pair diff's vectors across plots by the mode's name rule | `diff p1 p2` pairs vector names byte-exactly, so under the **default fold mode** two plots that spell one vector two ways hold one vector between them and `diff` reports nothing — an empty list reads as "the two plots agree" | **not touched** — ASE-L emits no `diff` | **NOTHING.** Listed because it is genuinely fold-visible and a crew might reach for `diff` when building a compare-runs feature. Do not. |
| B2.6 | `ec174074f` — give the four XSPICE event-node lookups findvec's case rule | Two of the four are fold-visible: `evtshared.c:253` (`ngGet_Evt_NodeInfo()`, the **libngspice** API) and `evtprint.c:341` (`eprint`/`esave`/`eprvcd`). A query from a host program, from a typed word or from `ngSpice_Command()` is never folded by the reader, so on stock the **event** half of the interface rejects spellings the **analog** half accepts | **not touched today** — ASE-L drives `ngspice -b`, not `libngspice`, and emits no `eprvcd` | **NOTHING today; a hard blocker for the `--with-ngshared` route.** If ASE-L ever moves to libngspice (R1 Option B), this is on the list of reasons a stock shared library answers differently. |

### B3 — "stock accepts fewer spellings": the keyword census on unfolded paths

Nineteen commits, **one behaviour**. In the default `fold` mode the reader lowercases every
deck card, so a keyword comparison against a lower-case literal is a no-op *for a deck*.
It is **not** a no-op on the three paths the reader never folds:

1. the interactive prompt and `ngspice -p` stdin;
2. a value read out of a **shell variable** (`gridstyle`, `plotstyle`, `hcopydevtype`,
   `specwindow`, the auto-bridge setup card, `ngbehavior` set with `setcs`);
3. a **whitelisted `.control` line**, whose case `inp_read()` preserves on purpose:
   `echo`, `shell`, `write`, `wrdata`, `source`, `cd`, `load`, `setcs`, `strcmp`,
   `strstr`, `codemodel`, `osdi`, `pre_osdi` — and, after `455221ae4`, the same list
   behind a `*#` prefix.

The commits, with their own census counts of fold-visible sites: `d9278225f` options.c
(39), `18a21697a` resource.c (16), `1f3e7cb15` breakp (15), `432341da2` spec/sndprint
(15), `71e318f6e` spiceif/typesdef (15), `daf3f5f08` postcoms/outitf (13), `77e4bdb0b`
inpcompat (13), `902841fa6` variable/define (11), `87bca7129` plotit/hardcopy (13),
`62a42e919` device/inpaname (9), `bdf40d5e5` parse/com_let/com_compose/diff (13),
`871f85f32` inpcom/inp.c (6), `8727232a2` XSPICE mif/evt (2), `2b74a3417` inp2dot (4, prompt
only), `4d06fdab2` control.c (all, prompt/pipe only), `5fde565f1` the `all`/`allv`/`alli`/
`ally`/`alle` wildcards, `455221ae4` the `*#` prefix, `11364fb32` `$` refs on `echo` lines,
`ac671722c` the `cistrstr` helper itself.

**MEASURED, the shape closest to ASE-L** (§4.11): `write <file> ALL @M1[ID]` inside
`.control` —

```
APT :  Warning from checkvalid: vector ALL is not available or has zero length.
       Error during 'write': no writable vector found.        -> NO FILE, rc=0
FORK:  v(dd) i(@m1[id]) v(gg) i(vdd) i(vg) i(@M1[ID])         -> file written
```

Note the failure mode: **rc=0 with no raw**. ASE-L's `$sim_status` guard does **not** fire
(the analysis succeeded); `ase::last_rawfile` finds nothing and `ase::attach_dbs` reports
`NOT ATTACHED`. Confusing, but detected.

| ASE-L touches it? | what ASE-L must do |
|---|---|
| **EMIT — but safely.** Every keyword `render_deck`, `op_ctl_saves` and `sim_status_guard` emit is already lower case (`all`, `set`, `if`, `end`, `echo`, `quit`, `write`, `print`, `save`, `op`, `dc`, `ac`, `tran`, `remzerovec`). Device and node names inside a `write` line keep their case, and `findvec()` is `cieq` under `fold` **on both binaries**, so those resolve either way (MEASURED, §4.11 lower arm). | **NOTHING to ASE-L's own emission — and a rule: keep it that way.** Add a lint to whatever writes control text that every ngspice *keyword* it emits is spelled lower case, so a future contributor cannot introduce a stock-only failure by capitalising a word. **WARN** for user `pre_commands` / control text: on a binary without the census, an upper-case ngspice keyword on a whitelisted line, at the prompt, or in a shell variable is rejected — usually silently. |

### B4 — the Verilog co-simulation shim

Both **MEASURED as absent from apt 45.2** by diffing the shipped files, which is the
strongest form this evidence takes: apt installs the shim sources itself.

| # | fork fix | what breaks without it | ASE-L touches it? | what ASE-L must do |
|---|---|---|---|---|
| B4.1 | `e47a2abc8` — link the VCD runtime object for Verilator trace builds | `grep -c verilated_vcd_c /usr/share/ngspice/scripts/vlnggen` → **0** (fork: 1). Verilator writes `verilated_vcd_c.o` beside the other globals rather than into `Vlng__ALL.a`, so a **`--trace` build fails the final shared-library link with unresolved symbols.** | **READ** — `ase::attach_dbs` loads the VCDs named in `vcdfiles`, and a Verilog block's VCD is what `--trace` produces | **WARN, loudly, at the point the user asks for Verilog waveforms.** This is a *build-time* failure of `vlnggen`, not a run-time one, so it happens outside ASE-L and arrives as "my wrapper won't link". ASE-L should name the cause. A workaround exists and is one line: the seven-line `fopen` probe in the fork's `vlnggen` can be pasted into the user's copy. |
| B4.2 | `c2722d89b` — keep `VerilatedContext` alive for model lifetime | `diff /usr/share/ngspice/scripts/src/verilator_shim.cpp <fork>` → apt has `const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};` and **no `contextp.release()`**. The `Vlng` model holds a **non-owning** pointer to a context the `unique_ptr` destroys when `Cosim_setup()` returns. **Use-after-free for the entire simulation.** | **PASS-THROUGH / READ** — every ASE-L Verilator co-simulation runs on this shim | **WARN and hand over the patch.** Undefined behaviour that may or may not show up as a crash; a run that "worked" on stock is not evidence the memory was valid. The fix is one line and does not require rebuilding ngspice — only the user's wrapper `.so`. |

---

## 4. The receipts

Every deck below is in `…/scratchpad/fd/`; the output is quoted as it was produced.

### 4.0 The ordinary ASE-L deck is identical on both — `e2e.cir`

`op` + `tran`, `.options savecurrents`, `.temp 27`, `.save all`, two node saves, two
`.save @m.xi1.m1[…]` device cards, the full `.control` block with `set appendwrite`, the
`$sim_status` guard after each analysis, `remzerovec`, one `write` per analysis, two
`print`s. Both binaries: **rc=0, 2 plots, `Transient Analysis` 11 vars, `Operating Point`
10 vars, identical `Variables:` blocks**, identical `v(dd) = 1.800000e+00` /
`v(gg) = 0.000000e+00`. No marker fired.

Corollaries measured on the way, all **identical on both**:

* the `$sim_status` guard works on apt 45.2 — a `.save` of a nonexistent node gives
  `rc=1`, `RUN-FAILED` on stdout, **no raw file**; the good run gives rc=0 and the raw.
  **`NO-SIM-STATUS` never printed**, i.e. `sim_status` exists in 45.2 and ASE-L's
  defence (b) is live there.
* `set appendwrite` appends plots to one raw on both.
* `remzerovec`, `set filetype=ascii`, `save @dev[param]` inside `.control`, and the
  `show all >` redirect all exist and behave the same on both.
* the save list is **sticky forward** on both — `save all @m1[id]`, `op`, then `save all`,
  `tran` still records `i(@m1[id])` in the transient plot. So `render_deck`'s 0964
  "operating point runs last" reorder is correct on stock too, for the same reason.
* an **empty netlist** through the full ASE-L control shape: rc=0 on both, raw written,
  only `Warning from checkvalid: vector nothing is not available or has zero length.`

### 4.1 `ce48f9630` — the `.op` abort (B1.5)

```
deck: "op only" / .op / .end          APT  -> rc=134
  ngspice: .../src/frontend/dotcards.c:225: ft_cktcoms:
           Assertion `plot_cur->pl_dvecs != NULL' failed.   [stdout EMPTY]
                                       FORK -> rc=1
  Error: incomplete or empty netlist / or no node to report an operating point for;
  no operating point printed!                                [stdout intact]
```
Same for a netlist whose only node is ground (`r1 0 0 1k` + `.op`). **A `.control` block
whose analysis is a bare `op` does NOT abort** — rc=0 on both. That is why ASE-L is immune.

### 4.2 `25e891ec3` — the phantom `v(all)` (B2.1)

Deck: `v1 in 0 dc 1` / `r1 in 0 1k` / `.save v(in)` / `.control` `op` `write` `.endc`.

```
APT   Variables:  0 v(in) voltage      FORK  Variables:  0 v(in) voltage
                  1 v(all) voltage
```

Trigger characterised exactly:

| plot contents | APT | FORK |
|---|---|---|
| op, 1 save | `v(in)` **`v(all)`** | `v(in)` |
| op, 2 saves | `v(in) v(mid)` | same |
| op, 3 saves | `v(in) v(mid) i(v1)` | same |
| tran, 1 save | `time v(in)` | same |

A bare `write` substitutes the token `all`, `ft_evaluate()` labels a single unchained
result with the parse node's own text, and only a match of exactly one is unchained. The
same happens to `print`/`write` of `allv`.

### 4.3 `ac1819ff8` — `unset` aborts (B1.1)

```
unset temp     (after set temp=27)  APT rc=134  stderr: it's a US_SIMVAR!
unset curplot                       APT rc=134  stderr: cp_remvar: Internal Error: var 99
unset plots                         APT rc=134  stderr: Error: plots is read-only.   <- prints, then dies
                                    FORK rc=0 for all three, with
                                      Error: curplot cannot be unset. / Error: plots is read-only.
```

### 4.4 / 4.5 `c214616d2`, `00446226e` — `define` (B1.2, B1.3)

```
define c(x) 5 ; print c(2) ; print c(2)   APT  rc=134 (SIGABRT), stdout destroyed
                                          FORK rc=0, c(2)=5 twice, undefine survives
define d(x,y) x ; print d(2,3)            APT  rc=139 (SIGSEGV)
                                          FORK rc=0, d(2,3)=2, twice
```
Default mode, no `casemode` anywhere.

### 4.6 `08451f50a` / `3330047d4` — **the de-risk**

The driver's highest-risk suspicion, measured in the **default fold mode**, both
directions:

```
deck spells MidNode, card says .save v(midnode)
  APT   v(midnode)=3.000000e+00, raw: v(midnode) [+ the v(all) phantom of §4.2]
  FORK  v(midnode)=3.000000e+00, raw: v(midnode)
deck spells midnode, card says .save v(MidNode)
  APT   raw: v(midnode) [+ v(all)]        FORK  raw: v(midnode)
```

**No `.save` resolution delta.** Both fixes are gated: `08451f50a` moves `preserve`
(`vec_name_eq()` is `cieq()` under fold and preserve alike — the mode that moves is the one
where the *reader* stopped folding), `3330047d4` is a `distinguish`-only diagnostic. ASE-L's
Outputs pane, which emits `.save` from user-picked names, is **safe on stock**. The only
delta the measurement showed is the phantom `v(all)`, which is B2.1 and unrelated to case.

### 4.7 `131779106` — the `gnd` rewrite in control text (B2.3)

```
APT                                    FORK
A4 quoted 0 here   <- from  echo A4 "quoted gnd here"      A4 quoted gnd here
A6 v( 0 )          <- from  echo A6 v(gnd)                 A6 v(gnd)
M7SH rail 0 here   <- from  shell echo "M7SH rail gnd here" M7SH rail gnd here
A1 /home/u/gnd/x.raw   (unchanged on both)
A2 tb_gnd_ase.raw      (unchanged on both)
A5 x-gnd-y             (unchanged on both)
A7 gnd  at end of line (unchanged on both)
```
So: **whitespace- and paren-delimited only**; `/`, `_`, `-`, `.` protect a token; a
trailing `gnd` with nothing after it survives. `write <path>` is therefore safe. Note the
capital `Gnd` is untouched on APT and on FORK — the upper-case half of this defect was
introduced by the fork's own `strstr`→`cistrstr` conversion and removed again by the
containment.

### 4.8 `62c6a707a` — `load` of a raw with `Option:` (B1.4)

```
Option: curplot=HAHA        APT rc=139 (SIGSEGV)   FORK rc=1, LOADED/DISPLAYED reached
Option: plots=x             APT rc=139             FORK ok
Option: curplotname=zz      APT rc=139             FORK ok
Option: casemode=preserve   APT ok                 FORK ok
Option: sourcepath=/tmp     APT ok                 FORK ok
```
The fault needs an `Option:` key that **collides with a computed variable name** — the
`curplot` family and `plots`. Anything else is fine.

**4.8b — and the fork does not produce one.** With `casemodewrite` unset (the default) the
fork's raw header carries **no `Option:` line at all** (MEASURED). With `casemodewrite`
set it carries `Option: casemode=fold`, which is in the safe column above. **A raw written
by our ngspice can be loaded by a stock ngspice.** That closes the fork→stock hand-off.

### 4.9 `5573790ee` — a data file reconfigures the reader (B2.2)

```
raw header: Option: no_auto_gnd
inner deck: v1 gnd 0 dc 0 / vx in 0 dc 1 / r1 in gnd 1k
outer: .control / load pol.raw / source pol.cir / echo POL-DONE / .endc

APT   rc=0   v(in) = 1.000000e+00   POL-DONE
FORK  rc=1   Fatal error: instance v1 is a shorted VSRC
```
On APT the loaded plot's `no_auto_gnd` reached the reader and kept `gnd` a distinct node,
so the deck ran. On FORK the guard held, `gnd`→`0`, and `v1 0 0` is correctly a shorted
source. The bug is real and the fix's direction is *stricter*, which is why nothing
ASE-L emits gets rejected by it.

### 4.10 `47c52c7dd` — `let`-created names on the write path (B2.4)

```
let MyVec = 5 ; print MyVec ; write f MyVec
APT   print -> myvec = 5.000000e+00   raw column: myvec
FORK  print -> myvec = 5.000000e+00   raw column: MyVec
```

### 4.11 The keyword census, in ASE-L's own shape (B3)

```
write f all @m1[id]     APT ok  FORK ok   -> v(dd) i(@m1[id]) v(gg) i(vdd) i(vg) i(@m1[id])
write f ALL @M1[ID]     APT: "Warning from checkvalid: vector ALL is not available or has
                             zero length." + "Error during 'write': no writable vector
                             found."   NO FILE, rc=0
                        FORK ok  -> ... i(@M1[ID])
```
Note `@M1[ID]` resolves on APT too when the wildcard word is lower case: the *device* name
goes through `findvec()`, which is `cieq` under fold on both. Only the **keyword** `ALL`
fails.

---

## 5. The reverse dependency — what *our* ngspice says that stock does not

Five commits add output in the **default** mode. On stock these lines are simply absent.
That direction is safe for correctness and dangerous for anything that *keys on* them.

| commit | new default-mode output |
|---|---|
| `4e738fc3e` | `Warning: node names 'In' and 'IN' differ only in case and name one node (casemode=fold)` — **MEASURED**: FORK prints it, APT is silent |
| `17e429993` | a report for a node reference that no card defines — fires in all three modes ("the first change in this series that moves the default mode on every deck") |
| `7b18264c4` | plumbing so six dot-card sites reach that report without defining the node. **MEASURED: no numeric or vector-table difference** — `.nodeset v(ghost)` gives the identical warning and the identical `v(out)` on both |
| `2d57025d4` | removes that report when the parse gave up early (mode-independent) |
| `2aa8ca1cc` | `Error: no vectors given; 'out' was taken as the output file name` — new output on a `pyplot` path that produced none |

**Rule for ASE-L:** never treat a `Warning:` line as a run verdict, and never require one.
`ase::backend::ngspice::result_probe` already parses only `<expr> = <float>` and the
`$sim_status` guard already decides pass/fail from the exit status — both are correct and
both must stay that way. A crew tempted to add "and if we see the two-spellings warning,
do X" would be building a fork-only feature into the schema, which D34–D37 forbids.

---

## 6. Where the existing machinery already handles the variant — and where it lies

### 6.1 The capability probe works unchanged on apt 45.2

`ase::backend::ngspice::capabilities`' three decks were run verbatim against both binaries:

| deck | question | APT | FORK |
|---|---|---|---|
| A | usable / hierarchy / `appendwrite` | 2 plots, op 3 vars, tran 4 vars | identical |
| B | blanket `save @dev[*]` | `Plotname: constants`, 12 vars → **blanket = 0** | identical |
| C | `set altshow` + `show all >` | file written, 131 lines | file written, 96 lines |

Decks A and B answer **identically**, which is what a probe should do when the capability
is the same. Deck C does not, and that is the interesting one.

### 6.2 `cap_altshow_verdict` correctly refuses tier `d` on apt 45.2

MEASURED by running `ase::cap_altshow_verdict`'s body over both dumps:

```
probe_c.APT.txt  -> 0
probe_c.FORK.txt -> 1
```

Because on APT a PWL source's `show all` block replays uninitialised values —

```
APT                     FORK
    pulse   = 0             pulse   =         -
    pulse   = 0             sin     =         -
    pulse   = 4.6e-310      exp     =         -
    sin     = 0             sffm    =         -
    ...   (18 numeric lines for pulse/sin/exp, 24 more for sffm/am/trnoise/trrandom)
```

**This is an upstream 45.2→46 difference, not a fork fix** — none of the fork's four
`device.c` commits touches `printvals`. It is the single best worked example in this batch
of V4's discipline paying off: an existing, shipped, run-based probe **already** withheld a
capability from an older binary that would have produced garbage, with no version number
anywhere. Whatever the stock ASE-L looks like, this is the shape it should be.

### 6.3 `$casemode` is a **false-positive** probe; `$curcasemode` is the real one

MEASURED, and this is the finding that most changes how the "hooks" should be built:

| invocation | binary | `$curcasemode` | `$casemode` | mode actually in force |
|---|---|---|---|---|
| (none) | APT | `Error: curcasemode: no such variable.` | `Error: casemode: no such variable.` | fold |
| (none) | FORK | `fold` | (unset) | fold |
| `-D casemode=preserve` | **APT** | `no such variable` | **`preserve`** | **fold** |
| `-D casemode=preserve` | FORK | `preserve` | `preserve` | preserve |

and, separately:

```
-D casemode=fold         APT rc=0, no warning     FORK rc=0, no warning
-D casemode=preserve     APT rc=0, no warning     FORK rc=0, no warning
-D casemode=distinguish  APT rc=0, NO WARNING     FORK rc=0 + the experimental-mode warning
```

**Stock ngspice does not refuse `-D casemode=`. It accepts it, says nothing, sets a
variable nobody reads, and folds.** So:

* A build that answers `$casemode preserve` has proven **nothing**. Any probe that reads
  it is measuring its own flag coming back.
* `$curcasemode` is the correct hook, and it is fork-only by construction — the commit
  (`6780b6a40`) exists precisely to separate "asked for" from "in force".
* ASE-L already has this right: `ase::sim_casemode_selectable` measures what the program
  *delivers* and `ase::run_casemode_flag` refuses to emit `-D casemode=` for a program not
  measured to deliver it (the rule recorded in `ase::ui::simdlg_case_*`'s own header).
  **This table is the measured justification for that rule** — without it, a user with apt
  ngspice who ticks "preserve" gets a folding run labelled preserve, silently, forever.

---

## 7. V6 tested: "gate capabilities up, apply mitigations down"

The principle holds for everything in this dossier **except one row**, and the exception is
instructive.

**Where it holds.** Every B1 and B2 row is a *warning or a refusal about user-supplied
text*, and warnings cost nothing on a fixed build except a line ASE-L chooses not to
print — so they can be applied unconditionally in the sense that the *check* is
unconditional even though the *message* is gated on the probe. Every B3 row is satisfied by
ASE-L's own emission already being lower case, which is free everywhere. Both B4 rows are
warnings about someone else's build step.

**Where it does not hold: B2.1, the phantom `v(all)`.** The mitigation is not free. Forcing
an operating-point plot to hold two vectors means emitting a `.save all` leader the user did
not ask for, and `render_deck`'s own comment records what that costs — the leader is
load-bearing for a different reason (it restores the implicit save-everything that any
explicit `save` cancels) and its absence was measured at "13 vectors, 6 device parameters,
5 node `v()`" with it against "7 vectors, 6 device parameters, **zero** node `v()`" without.
Turning it on unconditionally changes what a *correct* binary writes into the results file,
for every user, to work around a defect only some of them have. **So this one must be gated
on the probe**, or done on the reader side (drop a duplicate column literally named `all`),
which *is* free. Recommendation in the table: prefer the emission fix, gated.

**A second, softer exception.** "Refuse `ac lin 2`" and "never emit `option klu` with an AC
sens" are cheap because they cost the user nothing they wanted. "Refuse a `pre_command`
beginning with `unset`" is not in that class — the user wrote it on purpose, and on a fixed
binary it works. That one should **warn and proceed** on an unknown build and **refuse**
only on a build measured to lack the fix. The distinction the principle needs, and does not
currently make, is between *mitigations that change nothing the user asked for* and
*mitigations that take something away*.

---

## 8. What the stock ASE-L needs, expressed as hooks

Derived from the table, and deliberately small. Every one of these is **content**, so it
lives in `ase::backend::ngspice::…` per D34–D37, not in `ase.tcl`'s schema.

1. **One new probe key, `unset_safe`** — or, better, a single `frontend_lifetime` key that
   one probe deck answers for the whole `cp_remvar`/`define`/`load` family. A deck that
   does `set t=27` / `unset t` / `echo OK` and is judged by **whether `OK` came back**
   answers B1.1 in one run and costs nothing, because a crash there is total (rc=134, empty
   stdout) and therefore unambiguous. `define`/`load` can ride the same deck only if it is
   run in a **separate process** from anything whose answer matters — a probe deck that
   aborts tells you nothing about the lines after the abort.
2. **One new probe key, `one_vector_write`** — write a one-save operating point and count
   the `Variables:` block. `1` → clean; `2` with a column named `all` → B2.1 present. This
   is the only probe whose answer changes what ASE-L *emits*.
3. **A version-keyed table for nothing in this dossier.** Every row above is probeable or
   is a static file diff (B4). The unprobeable hazards stay where V3(d) put them.
4. **A pass-through linter** over `pre_commands` and any hand-edited `.control` text,
   which warns (never rewrites) on: a leading `unset`; a leading `define`/`undefine`; a
   leading `load`; a bare `gnd` token; an ngspice keyword spelled with capitals. Five
   patterns, one proc, and it is the only thing standing between a stock user and four of
   the five measured crashes. (The fifth, the `.op` abort, ASE-L is already immune to by
   construction.)
5. **Two file-diff checks for the co-simulation route**, run once when the user first asks
   for Verilog: `grep -c verilated_vcd_c <sharedir>/scripts/vlnggen` and
   `grep -c 'contextp.release' <sharedir>/scripts/src/verilator_shim.cpp`. Both are exact,
   both are cheap, and both give the user a one-line patch instead of a link error.
6. **Keep `op` a control command and keep the guard.** Neither is a hook; both are
   invariants this dossier now has a measured reason for.

---

## 9. The de-risked list — suspicions that turned out not to be risks

Recorded so nobody re-opens them.

| suspicion | verdict |
|---|---|
| `.save resolves a vector name the way every other site does` | **Not a stock risk.** `preserve`-only. §4.6 |
| `a .save name that misses by case names the twin` | **Not a stock risk.** `distinguish`-only diagnostic. |
| `a define's body reaches its own formal under preserve` | **Not a stock risk.** `preserve`-only, and ASE-L emits no `define`. The *other* three define commits are real (B1.2, B1.3) — the driver picked the one gated one. |
| `give constantplot one initialiser per member` | **Not a bug upstream.** The short member (`pl_fromfile`) is fork-added. Bucket (n). |
| `report an .op card with no netlist instead of aborting` | **Real crash, but ASE-L is immune** — it emits `op` inside `.control`, which does not abort. §4.1 |
| `withhold the wildcard rename from a one-vector match` | **Real, and the one row that reaches ASE-L's own emission.** B2.1 |
| `cp_remvar frees a node only when nothing points at it` | **Real crash**, pass-through only. B1.1 |
| `a computed variable is answered by its computation, not by a file` | **Real crash**, pass-through only, and the fork's own raw header is in the safe column. B1.4 / §4.8b |
| `a loaded plot does not answer the reader's policy questions` / `keep the reader's case mode off a loaded plot` | The first is real (B2.2), pass-through. The second is a fork-only feature (`casemodewrite`) and cannot exist upstream. |

---

## 10. Gaps — what I did not measure, and why

1. **Stock upstream 47 was not built.** Everything labelled "live upstream" is measured on
   **apt 45.2** and read from the fork's own commit messages for 46/47. The fork's base is
   `origin/pre-master-47` with **0 upstream-only commits** relative to `ver_50`, so every
   fix in §3 is by construction absent from 47 as well — but the *rest* of 45.2→47 is not
   measured, and §6.2 is a live example of upstream fixing something in that window that
   changes an ASE-L verdict. **Rebuild this dossier's §4 against a stock 47 before anyone
   ships a version table.**
2. **B1.6 (auto-bridge `family=""` / NULL `strcmp`) was not re-measured here.** It needs an
   XSPICE deck with a `.model … family=""` and a second family-bearing node, and apt's
   code-model `.cm` path had to be set up for it. The fork's commit carries its own RED
   evidence in the default mode, and ASE-L cannot reach the NULL arm, so I traded the
   measurement for the rows that ASE-L *can* reach. Flagged rather than claimed.
3. **B2.5 (`diff` pairing) and B2.6 (XSPICE event lookups) were classified from the
   commits, not measured.** Neither is on any ASE-L path today. B2.6 becomes load-bearing
   the day ASE-L moves to `libngspice`; measure it then.
4. **The `--with-ngshared` variant is entirely unmeasured** in this pass. `3d3e56e75` is a
   shared-build-only defect the fork introduced *and fixed*, which is a reminder that the
   shared route has its own class of state bugs (`ngSpice_Reset`, `shared_exit()`), none of
   which are covered here.
5. **I did not audit `op_annot.tcl`'s hierarchy walk against a stock binary.** Tier c's
   `.save @dev[param]` cards were measured working identically (§4.0), but the *walk* that
   produces the device names reads xschem's own database, not ngspice's, so it is out of
   scope for a fork-dependency question. The tier `d` alternative is correctly gated by
   §6.2.
6. **No claim is made about `casemode` being a good idea to expose in the stock ASE-L.**
   §6.3 says only that the probe must be `$curcasemode` and never `$casemode`. Whether the
   Case field should appear at all on a build that cannot deliver it is a UI ruling, not a
   measurement.

---

# 5. THE PROBEABILITY SURVEY — debt **M19**

**Written 2026-09-13 by the driver.** M19 recorded that *"the other ~33 category-(b) fork fixes
were never individually assessed for probeability"* — three had been found probeable in a deck that
was already running (`one_vector_write`, `gnd_literal`, `keyword_case`), and *"three probes is not
a survey"*.

⚠ **This section is a CLASSIFICATION, not a measurement.** Each row is judged from the symptom
§3 already measured; no probe below was written or run except the three that already exist. The
distinction matters because this batch's own rule is that accepted is not honoured — a probe that
looks obviously right still has to be run before it is believed.

The test M19 set is *"does this defect land in a file?"* — because a probe that needs its **own
process** to buy silence is not worth it, while one that is a line in a deck already running is
free.

## The answer, and the useful half of it is the NO column

| row | probeable in a deck that is already running? | why |
|---|---|---|
| B1.1 `unset` frees a live node | **NO** | the symptom is `SIGABRT rc=134` — a probe would kill the run it is riding in |
| B1.2 / B1.3 `define` bodies | **NO** | `SIGABRT` / `SIGSEGV`, same reason |
| B1.4 computed variable in a raw header | **NO** | `SIGSEGV` on the *next* command |
| B1.5 `.op` dot card with no netlist | **NO** | `SIGABRT`, and ASE-L is structurally immune anyway |
| B1.6 auto-bridge `family=""` | **UNKNOWN** | the symptom is a *silently different bridge*, which is observable — but it needs an XSPICE event circuit stood up, so it is not a free line. Not classified without a measurement |
| B1.7 subcircuit multiplier | **NO, and pointless** | needs a 10 000-parameter `.subckt` |
| B1.8 `undefine` leak | **NO** | a leak is invisible to a batch run that exits |
| **B2.1** phantom `v(all)` | ✅ **YES — already built** (`one_vector_write`) | a one-vector plot written and read back; the defect **lands in a file** |
| B2.2 loaded plot reconfigures the reader | **YES, but NOT FREE** | needs a crafted raw header **and** a `source` afterwards, and it changes reader policy for the rest of the process — it must not ride in a deck that is doing real work |
| **B2.3** bare `gnd` in control text | ✅ **YES — already built** (`gnd_literal`) | `echo M7MARK my gnd rail` and read the echo; one line, no file needed |
| **B2.4** `let MyVec` written lower case | ⭐ **YES, AND NOT YET BUILT** | `let MyVec = 5` / `write <f> MyVec` and read the `Variables:` block: **APT `myvec`, FORK `MyVec`** (§4.10, already measured). It lands in a file, and ASE-L already writes and reads raws. **The cheapest unclaimed probe in the table.** |
| **B2.5** `diff` pairs names byte-exactly | ⭐ **YES, AND NOT YET BUILT** | build two plots spelling one vector two ways and run `diff`: stock reports nothing, the fork reports the pair. Output only, no file. ⚠ **But it is worth almost nothing** — ASE-L emits no `diff`, so the probe would measure a capability nothing uses |
| B2.6 XSPICE event-node lookups | **NO, today** | reachable through `libngspice` or an `eprint` on an event circuit; ASE-L drives `ngspice -b`. Becomes live only on the `--with-ngshared` route (⚖ R1 Option B, not taken) |
| **B3** the 19-commit keyword census | ✅ **YES — already built** (`keyword_case`) | `write <file> ALL @M1[ID]` inside `.control`: stock writes **no file at rc 0**, the fork writes it (§4.11). One behaviour, one probe, nineteen commits |
| **B4.1 / B4.2** the Verilator shim | ⭐ **YES, AND BY A CHEAPER KIND OF PROBE** | neither is reachable from a deck at all — but both are **file inspections of the installed tree**, needing no simulator process whatsoever: `grep -c verilated_vcd_c <sharedir>/scripts/vlnggen` (0 on apt, 1 on the fork) and a `grep` for `contextp.release()` in `scripts/src/verilator_shim.cpp`. **Zero cost, and they answer before any run** |

## What the survey concludes

1. **The three existing probes cover the whole of what a running deck can see cheaply, minus one.**
   **B2.4** is the only unclaimed probe that is both free and useful. B2.5 is free and useless.
2. **The entire B1 family is unprobeable by construction**, because its symptom is the death of the
   process doing the probing. That is not a gap to be closed — it is the boundary between what
   Stage 16 can **measure** and what it must **warn** about, and it is worth stating in those words
   on the panel rather than leaving a reader to wonder why the crashes have no green tick.
3. ⚠ **B4 is probeable by a kind of probe this batch had not considered**: reading the installed
   tree. Two `grep`s, no process, an answer before the first simulation. If Stage 16 offers Verilog
   co-simulation at all, these two belong in it — and B4.2's use-after-free is precisely the defect
   a user cannot detect for themselves, because a run that *worked* is not evidence the memory was
   valid.
4. **So M19's blanket premise is confirmed and bounded**: *"the fork's fixes have no probe"* was
   already overturned by three; the survey adds **one more free deck probe and two free file
   probes**, and shows the remaining eight are unprobeable for a reason rather than by neglect.

**What is NOT done:** none of the three new probes has been written or run. Each is one line plus a
comparison, and each must be measured on **both** binaries before it is believed — this section is
a map, not a result.
