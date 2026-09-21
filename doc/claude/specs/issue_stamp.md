# The issue stamp — making a tracker file say what it was measured against

**Implementation** `tests/headless/issue_stamp.tcl` (checker),
`tests/headless/test_issue_stamp.tcl` (its red-first suite),
`tests/headless/issue_stamp_baseline.txt` (the grandfather set).
**Designed by** task `BC1` of the issue-tracker batch, 2026-09-17.
**Measured basis** `doc/claude/issue_tracker_batch/receipts/A1.md`–`A4.md`, a
pre-registered random sample of 40 of the 1047 numbered issue files.

---

## 1. The problem, as measured rather than as assumed

Four crews classified 40 files drawn at random with a recorded seed, committed to
`SAMPLE.txt` before anyone read one. The aggregate:

| verdict | count of 40 |
|---|---|
| `ROTTED-CITE` — cites a file/line/symbol that does not say what it claims | **27** |
| `STALE-FIXED` — says open, but the tree already fixed it | **7** |
| `BAD-FIX` — a stored fix that would not work or would break something | **1** |
| `STALE-OPEN` — says fixed, but the defect is live | **0** |

The batch was scoped around the last two. **The sample says the first one is the
disease**, and the shape is sharper than the count: *in every rotted citation the
named symbol still existed and still behaved as the file described. Only the
coordinates died.* Three independent measurements agree —

* bare `file:line` citations: **5 of 5 rotted** (A3);
* `file:line` **plus a named revision**: **4 of 4 reproduced** via
  `git show fadb226d:` (A3, issue 0818 — the only such file in the sample);
* citations by **symbol name only**: **3 of 3 held** (A3), and 2016 backticked
  `foo()` citations across 509 files are **98.4% still present** (driver).

**Coordinates rot. Identity holds.** Shipped source already knew this:
`src/op_annot.tcl`, in the comment above `_netlisted`, reads *"Cited by function
name, not by line number, on purpose: the line numbers this paragraph used to
carry moved by about eleven hundred lines and silently sent every later reader to
the wrong place."* So does the tracker: **issue 0229** is this defect's own
write-up, it prescribes *"cite symbols, not offsets"*, it ships a ready-made
pre-commit grep — and it is still OPEN, and has since rotted by exactly the
defect it files. The corpus diagnosed itself, prescribed the cure, and nobody
applied it. **This spec is that prescription with something mechanical behind
it.**

### Why a retrospective rot-checker is impossible

Three were tried and all three failed, each producing a plausible wrong number:

* *does the cited line exist?* — 3751 citations resolved, **PAST-EOF = 0**.
  Nothing points past an end of file; the rot always resolves to a real line
  whose text moved.
* *is the cited symbol still there?* — 98.4% are. Symbols do not rot.
* *does the quoted line match?* — a "nearest filename above" heuristic called 17
  of 20 rotted; **16 were SPICE decks and log excerpts** that happen to carry
  line numbers inside fenced blocks.

You cannot compute today what a sentence meant when it was written. You *can*
make every sentence written from now on say what it was measured against. That
is a ratchet, not an audit, and it is the whole of this design.

---

## 2. The stamp

One physical line, anchored at column 0, inside the first **12** lines of the
file:

```
**STAMP:** `v1 claim=open tree=d64686a1 stamped=2026-09-17 fix=none open=3`
```

### ⚠ One physical line is a measured requirement, not a style preference

The nearest thing the corpus already has is the prose that 1473/1477/1478/1479
open with — *"measured in the tree at `aa0e2213`"* — and a census of it **missed
all four**, because markdown hard-wraps the phrase across a newline and a
line-oriented grep cannot match it. The driver published *"only 1 file in 1047
states its tree"* having **read those four files in the same session**. A
convention a grep cannot see is a convention that does not exist. Never wrap a
stamp.

### The fields

| key | values | why it exists |
|---|---|---|
| `v1` | the schema version, always first | lets the shape change later without a silent misread |
| `claim=` | `open` `fixed` `partial` `latent` `duplicate` `wontfix` | **a one-bit status cannot express this corpus** — see below |
| `tree=` | a revision, 7–40 hex, **at least one `a`–`f`** | the load-bearing field; it is what makes every coordinate in the file recoverable |
| `stamped=` | `YYYY-MM-DD` | the age of the claim, readable without git |
| `fix=` | `none` `untried` `taken` `superseded` `partial` | **a stored fix is an unverified hypothesis until marked otherwise** |
| `open=` | a non-negative integer | how many items the file itself says are still outstanding |
| `super=` | *(optional; required when `fix=superseded` or `claim=duplicate`)* an issue number `NNNN`, a revision, or `self` | what replaced the prescribed shape |
| `scope=` | *(optional)* one token naming an arm, path or door | for the defect closed on **one route** and live on another |
| `by=` | *(optional)* who stamped it | a task id, so a stamp is attributable |

`scope=` exists because two measured files cannot be expressed without it, and
both would be closed **wrongly** by whoever tidies next — which is the
`STALE-OPEN` direction, the dangerous one:

* **0216** is fixed for the Location bar and for `wviewer::restore`, and **not**
  for the ASE re-run path — `wviewer::attach_raw`'s body has no `rawhist_push`,
  and `src/results.tcl` says so in its own voice: *"Converting that path is NOT
  this item."*
* **0650**'s general channel landed (`5dd68128`); its **titular** session-window
  sink did not, and 0655 carries the remainder as *"OPEN (deferred out of issue
  0650 deliberately)"*.

#### ⚠ `scope=` and `super=` answer different questions: *is there somewhere else to look?*

The two files above are deliberately **not** stamped the same way, and this is the
rule that says which is which. It is written down because a field used
inconsistently for a month gets read as noise and then dropped.

* **`super=` names a successor that CARRIES the remainder.** 0650 deferred its
  titular session-window sink into **0655** — a file that exists and says so in
  its own header. A reader who follows a `super=` **arrives somewhere**.
* **`scope=` names a route this claim does not cover, and which nothing else
  carries.** 0216's ASE re-run path has no issue of its own: 0216 names no
  successor, and `src/results.tcl` simply says *"Converting that path is NOT this
  item."* A reader who meets a `scope=` is being told where **not to trust the
  claim**.

They are independent rather than alternatives, and a file may carry both when it
is scoped *and* its remainder is filed. Stamping a deferral as a scope tells a
reader to distrust a route while hiding the number that would have told them what
to do about it; stamping a scope restriction as a supersession sends them to a
file that does not exist.

### Why three numbers and not one verdict

This is copied deliberately from `T1-RUN-END`, which states `cases=`, `blocks=`
and `counted_failures=` rather than a pass/fail word. A one-bit status **cannot
express the files that matter most**:

* **0905** needs four answers at once — its subject is genuinely fixed, its §1 is
  stale, its §2 is stale *and inverted* (it records as "considered and
  deliberately NOT taken" the exact shape the tree now runs), and its §3 is half
  done. A header forcing FIXED-or-OPEN rounds all four wrong.
* **0891** needs *"2 of 3 follow-ups landed"* → `claim=partial open=1`.
* **0890** and **1219** need *"claims latent, is actually live"* → `claim=latent`.
  This was the schema cell A3 found missing, and it is the direction a reader
  never re-checks, because a file admitting weakness reads as honest.

### ⚠ `tree=` is a statement about the PAST, and that is why it never rots

`tree=` does **not** mean "current". It means *"the claims in this file were last
checked against this revision"*. That sentence is true forever; it only becomes
**older**, which is information rather than error.

This is the single most important thing to understand before "improving" the
checker. A rule that required `tree=HEAD` would redden the entire corpus the
moment anybody committed — which is exactly how this batch's own `PLAN.md:3`
rotted **within the hour**, because the driver committed twice while crews were
reading it. Requirement "cheap to re-stamp" is met by **not needing to
re-stamp**: you stamp when you re-verify, and re-verifying is work you were
doing anyway.

*(Measured while this spec was being written: `HEAD` moved three times in one
task — `d64686a1` → `0e985165` → `01cef414`. Nothing already stamped broke.)*

### Supersession, and the rule that a stamp is the file's newest word

510 of 1047 files contain **both** fixed-words and open-words in their first ten
lines. That is not sloppiness: it is what a file looks like after somebody
appends a correction without touching the header, and **append-without-touching-
the-top is this corpus's default editing motion** (3 of A2's 10 carry their own
refutation 100+ lines below the wrong text; 0665 says OPEN on line 3 and FIXED on
line 59).

So the convention does not fight the habit. It adds one rule:

> **The stamp is the file's single newest word. Any prose that disagrees with it,
> above or below, is history.**

Keep appending corrections. Update the one line. Exactly one stamp per file —
two would be the both-words defect in miniature, and the checker refuses it.

---

## 3. The citation rule

1. **Cite by identity first.** `` `proc rdw::push` in `src/rdw.tcl` `` — never a
   bare `src/rdw.tcl:1885` on its own.
2. **A coordinate is legitimate inside a stamped file**, because `tree=`
   retro-qualifies every one of them at once. `src/scheduler.c:851` in a file
   stamped `tree=fadb226d` is recoverable forever by
   `git show fadb226d:src/scheduler.c`. That is measured: 0818 was the only
   sampled file that named a revision, and all four of its dead coordinates came
   back exactly.
3. **A count is prose; only a pointer is a citation.** Three of A1's ten state a
   number that was true when written and has since drifted — "11 checks" (80
   today), "12 call sites" (13), "~3500 mentions" (5210). *Ruled, by BC1, on A1's
   recommendation:* these are **not** defects and are **not** checked. The
   alternative is a checker that cries wolf over the entire corpus on day two,
   and a checker nobody believes is a checker nobody runs.
4. **Do not mirror another file's status — link to it.** An umbrella issue that
   restates its children's statuses is a hand-maintained mirror, and *"a
   hand-maintained mirror of another module's rules is wrong by construction and
   had already drifted twice"* — which is a comment in **`src/op_annot.tcl`**,
   above the seven-class truth table, written about code and true verbatim of
   prose. ⚠ **This rule cited that sentence as "issue 0442's own header" until
   `BC2` checked it. It is not in 0442 at all** — measured at `d09ebece`,
   `/usr/bin/grep -c 'hand-maintained mirror'` over 0442 answers **0**, and the
   only copies in the tree are `src/op_annot.tcl` and this checker's own comment.
   The point being made was sound; it was quoted from the wrong document, by a
   spec whose subject is quoting from the wrong document. Found by `D1`
   (receipt F4). Issue **0071** is the proof: its
   header is correct while its §3 lists 0063 as an unresolved HIGH (0063 reads
   `✅ REPLAYABLE`), its §4 calls 0003 "pre-existing" (0003 reads CLOSED), and
   its "next mutators" list of six is five done.

---

## 4. Marked fenced blocks

The info string after the language word takes the same `key=value` grammar.

**A fence is *marked* only by a key of a block: `quote=`, `assert=`, `path=`,
`pat=` or `state=`.** Any other fence is an ordinary code sample and its info string
is not read, whatever it holds. That includes an mkdocs title
(```` ```python title="example.py" ````), a build line (```` ```sh cc=gcc make ````,
```` ```sh make prefix=/usr install ````), `hl_lines=` and a lone `fix=` label. Until
S1-fix8 a fence was marked by *any* `key=value` word, and those three fences were each
named as malformed in a stamped file: false reds on honest content (measured by
S1-fix7's refuter, red-first by S1-fix8). S1-fix8 then marked by `quote=` and
`assert=` alone, and that lost every block whose marking key was **misspelled**:
`asert=`, `assertion=` or `asserts=` on a false assertion, and `qoute=` or `quotes=`
on a rotted quote, each passed `ok (0 problems)` where the checker before it named the
unknown key (measured by S1-fix8's refuter, red-first by S1-fix9). The other three
keys only ever appear on a block, so they mark a fence too, and the misspelled key is
a named problem. A fence marked only by `path=`, `pat=` or `state=` and otherwise
well-formed has nothing to evaluate and is no problem (```` ```sh path=src/foo.c ````).
A near-miss of `quote=` or `assert=` in another case or spacing (`ASSERT=`,
`QUOTE=`, `assert = absent`, `Assert= absent`) is named **once** (§5).

**A misspelled marking key is named wherever it sits, whatever the fences around
it do.** Marking by the other three keys names a misspelling only where the fence
pairs up into a block the checker reads — and both pairing rules have a hole on the
side the other one closes. Before S1-fix9 a Slack-style ```` ```make install```
fails ```` line opened a fence, so a ```` ```sh asert=absent pat=… ```` fence below
it was swallowed as text and nothing named the typo: `ok (0 problems)`. With that
line read correctly as inline code, the bare ```` ``` ```` meant to *close* a
```` ```sh `make` output ```` line opens a fence instead, and swallows the fence
below **that** — the same silence, one line further down (both measured red-first,
issue **1489**). So the key is now tested on the fence line's own info string, by
the stray-attribute check, with nothing asked about the fences around it: a word
shaped `key=` whose key is one edit from `quote` or `assert` — a letter left out
(`asert`), typed twice, typed wrong, typed the wrong way round (`qoute`), or a
truncation or extension (`quot`, `quotes`, `assertion`) — is a named problem, and
the fence it sits on is not read. It is named **once**: a fence the checker *does*
read has had its whole info string named already, and the stray-attribute check is
silent for that line.

**One letter separates `assert=` from `asset=`, so the fence must say what it is a
second way.** A misspelling counts only where the info string also carries a key of
the grammar (`pat=`, `path=`, `state=`, `fix=`, or a marking key spelled right), or
where the misspelled key's own value is the one that key takes — `absent` or
`present` for `assert=`, a revision token for `quote=`. So ```` ```sh asert=absent
````, ```` ```c qoute=d64686a1 ```` and ```` ```sh asert=absent pat=SABOTAGE
path=src state=holds ```` are named, while ```` ```js asset=x ````,
```` ```sh quota=10 ````, ```` ```text assent=y ```` and ```` ```c quoted=true ````
are ordinary code samples. The residue is in §6.

**Both halves of that test ignore case.** `ASERT=absent` and `asert=Absent` are the
same mistake and are named alike, as are `qoute=A1314271` and `qoute=a1314271`. The
key was folded and the value was not for one round, so a single capital letter
turned the whole check off while its lowercase twin was named — measured, and
fixed, by item D's fix round. A check a capital letter disarms is a silent pass,
which is the one direction this checker may not fail in.

**Which lines are fences.** A fence is a run of three or more backticks, or of three
or more tildes, indented at most three spaces, and it closes on a run of the same
character at least as long, as CommonMark has it. So a fence in a list item indented
three spaces or fewer is a fence. A backtick fence's info string holds no backtick:
```` ```make install``` fails here ```` is inline code in a paragraph, the way
Slack-style writing uses it, and opens nothing. Until S1-fix9 it opened a fence that
ran to the next bare ```` ``` ```` line, and a real `assert=` fence after it was
swallowed as text: named, never evaluated, so a true assertion went red and a false
one was never called false (read by S1-fix8's refuter, red-first by S1-fix9 and
S1-fix10). The same rule has two consequences, stated in §6.
Only a **column-0 backtick** fence is *read* as a block. Any other fence (`~~~`, or
indented one to three spaces) is a fence whose contents are text. A fence indented
four or more spaces, as under a nested list item, or inside a `>` blockquote, is not a
fence to the block reader at all. A `quote=` or `assert=` on any fence that is not
read is a named problem (§5), never a silent pass.

**A marked fence's info string is read in full.** It must be exactly: at most one
leading language word (no `=` in it), then `key=value` words only, each key one of
`quote path fix assert pat state` and each given once. Any other word, a title
included, is a named problem and the block is **not evaluated**. The checker used to
keep the key=value words and drop the rest, so `assert=absent pat="static int"
path=src state=holds` was checked as a search for the literal `"static` and passed,
while the phrase is on 463 lines of `src` (measured by S1-fix6's refuter;
outsider-fixes DECISIONS D19). The problem names the first five such words and
counts the rest.

### `quote=` — a block that claims to reproduce tree text

````
```c quote=fadb226d path=src/scheduler.c
regsub {^~/} {%s} {%s/}
```
````

The checker verifies the block against `git show fadb226d:src/scheduler.c`,
whitespace-normalised so re-indentation is not a failure.

**This is the class nothing else catches.** A stale line number *looks* stale the
moment you follow it. A stale quoted block still looks like valid C and reads as
authoritative. Issues **0296** and **0435** both quote C that no longer exists —
A1's phrase for 0435 is *"correct by reference, damaging by paste"* — and
**neither was scored `BAD-FIX`**, which means the count of dangerous stored fixes
in this tracker is an undercount.

### `fix=` — a prescription's state

````
```tcl fix=superseded
op_annot::_netlisted {i}   ;# the ONE-ARGUMENT symbol-attribute probe 0442
                           ;# prescribed. The SHAPE is gone; the proc is not.
```
````

**`fix=` exists because of 0442, the sharpest defect in the sample.** Its
numbered item 1 was *accurate when written*. The tree then fixed the defect by
the unnumbered alternative buried at the end of the same section — *derive the
device set FROM `xschem netlist` output* — which that paragraph justifies by
noting that the hand-written Tcl filter had already drifted twice. **Pasting item
1 today re-introduces what was deliberately deleted.** No status field catches
that — the status was never wrong. Only *which option was taken* catches it. Note
0442 is also why `super=` accepts `self`: what superseded item 1 was not another
issue, it was a paragraph in the same file.

⚠ **"The tree deleted it" was the wrong word, and the right one is the whole
point of this field.** This example read *"the shape 0442 prescribed, and the
tree deleted"*, and the sentence *"the file's own header records why the
prescribed shape was abandoned"* stood beneath it. Both are wrong, measured at
`d09ebece`:

* `proc op_annot::_netlisted` is **live** in `src/op_annot.tcl`, with the
  signature `{i idx {block {}}}`. What the tree deleted is its **shape** — the
  one-argument probe that mirrored symbol attributes (`cell::format`,
  `cell::spice_sym_def`, `cell::spice_stop`, `cell::default_schematic`) is gone,
  and the live body asks the deck index instead.
* 0442's header records no such thing; it reads `STATUS: **OPEN.**`. What records
  why is the **unnumbered alternative at the end of its own fix section**, which
  is exactly why `super=self` is the right stamp for it.

The distinction is not pedantry, it is the reason `fix=superseded` exists: the
**name survived and the option did not**, which is precisely the case no status
field can express — and a reader who checks *"the tree deleted `foo`"* against a
live symbol stops believing the document. A spec about citation rot asserting a
deletion that did not happen is the defect demonstrating itself. Found by `D1`
(receipt F4), corrected by `BC2`.

### `assert=` — a claim about the tree that a machine can settle

````
```sh assert=absent pat=SABOTAGE path=src state=broken
the literal text SABOTAGE on no line of any file under src/ (the sabotage protocol's closing check)
```
````

Vocabulary: `assert=absent|present`, `pat=` one whitespace-free token, `path=` a
repo-relative path, `state=holds|broken`. **`pat=` is a literal string**, never a
regular expression or a glob: it is matched byte for byte (its UTF-8 bytes
against each file's bytes), every character in it — `.` `*` `[` `^` `$` `\`
`|` `>` — stands for itself, and a hit is counted once per line that contains
it, as `grep -rnF` counts. The block's body is prose for the reader; only the
info string is read. There is no shell and no
interpolation — a document that can run arbitrary commands when you validate it
is a document you cannot validate.

**All the `assert=` scans of one gate run share one budget: 60 s of scanning
time**, on top of each scan's own 60 s. Only time spent scanning is charged to it. A
block reached after it is spent is a named problem, never evaluated and never
passed. Per-scan bounds alone did not bound how many scans a corpus asks for: 100
two-line blocks over `path=.` held the gate for 211–253 s (measured by S1-fix6's
refuter and by S1-fix7). The real corpus's one block costs about 70 ms. Until
S1-fix8 this budget was a wall clock that started with the gate, so git work done
*before* an assertion spent it. 240 valid `quote=` blocks in 0056 made the gate
report 1219's 70 ms assertion as having run past the scanning budget: a false red
with a false reason (measured by S1-fix7's refuter, red-first by S1-fix8).

**A whole gate run also has a wall-clock budget, 600 s**, for everything it does:
every git question a `tree=` or a `quote=` asks, and every scan. Once it is spent,
each `tree=`, `quote=` and `assert=` the gate reaches is a named problem saying that
the gate's time ran out. It is never passed, and never blamed on the assertion that
came next. 600 s is under T1's 900 s per-case cap, so a corpus that asks for more is
named rather than killed. The real corpus's whole gate takes well under a second.

`state=` is the interesting half, and it is what makes the tracker close its own
issues:

* `state=holds` and the predicate is false → **the file's claim is stale**.
* `state=broken` and the predicate is true → **the defect appears fixed and
  nobody closed the issue.**

That second arm is the mechanical `STALE-FIXED` detector. 7 of 40 sampled files
report finished work as outstanding; one defect was filed **five times across
seven weeks and attempted zero times** (0384, 0867, 0955, 0905, 0990) because
each arrival read the previous filing and believed it. An issue whose defect is
greppable can now declare it, and the checker flags the file the day someone
fixes it — without anybody remembering the issue exists.

---

## 5. What the checker enforces

`tests/headless/issue_stamp.tcl`:

```sh
tclsh tests/headless/issue_stamp.tcl gate       # the verdict, exit 0 or 1
tclsh tests/headless/issue_stamp.tcl report     # advisory census, always exit 0
tclsh tests/headless/issue_stamp.tcl selftest   # the parser fixtures alone
tests/headless/run_suites.sh test_issue_stamp   # the full suite, gated
```

It needs no display, no simulator, no built binary and no T1 run. It runs under
plain `tclsh` **and** under `xschem --nogui --pipe -q --script`, so
`full_audit.sh` (which discovers `tests/headless/test_*.tcl` by `ls`) and
`run_suites.sh` both pick the suite up with no registration.

**Enforcement is forward only.**

* A file **carrying** a stamp is validated: grammar, closed vocabularies, `tree=`
  resolves, one stamp only, inside the header window, plus every marked block.
* A file **without** one is grandfathered **by its exact file name** in
  `issue_stamp_baseline.txt`. An issue file whose name is *not* in that list and
  which carries no stamp is a failure.
* A name in `doc/claude/issues/` that **looks like** an issue file (it begins
  with a digit and ends in `.md`, in any case) and misses the canonical
  `NNNN-<slug>.md` is a failure too: the gate would otherwise never read it, so
  an unstamped `1601_x.md`, `1601.md` or `1601-x.MD` passed unseen (measured
  red-first by S1-fix7). Attachments such as `NNNN-<slug>.patch` are not issue
  files and are not matched. The real directory has none of these (1059 entries,
  1047 canonical, measured at `aa5cece0`).
* A line anywhere in an issue file that carries a stamp's **body** (a backtick,
  `v1`, then `claim=`) and is not the stamp line the parser reads is a failure. A
  stamp that lost its colon (`**STAMP** `, `**Stamp** `, `**STAMP;**`) was prose
  to the stray-stamp detector, which needs the word and a colon, so its bogus
  `tree=` was never checked (measured by S1-fix6's refuter). The only lines in the
  real corpus that carry a body are its real stamps (ten when this was written, 17
  at `32b6a9cd`, measured by S1-fix10). **There is no exception
  for a body inside a fence**, although markdown renders it as code: an example of
  the format written in an issue file is named like any other body. That is a
  documented limit, with its workaround, in §6.
* Near-misses of a marked fence are named too: a `quote=` or `assert=` written in a
  `~~~` fence, an indented fence, a blockquote, a list item, a fence never closed, a
  file with no stamp, a ```` ``` ```` line whose info string holds a backtick, or as
  `ASSERT=`, `QUOTE=`, `assert =` or `Assert= absent`. Each is **one** problem: a
  case or spacing near-miss of `quote=`/`assert=` is named by the stray-attribute
  check alone, and the marked-fence reader leaves that word to it, unless the key is
  also written correctly in the same info string, where the near-miss is a bad word
  of the fence instead. A misspelled marking key on a block (`asert=`, `qoute=`) is named
  as a key the grammar does not know (§4) where the fence is read, and by the
  stray-attribute check where it is not — so it is named wherever it sits, on a fence
  swallowed by a phantom one, on a backtick-info line, or alone, and never twice
  (issue **1489**, §4). It counts as a misspelling only where the fence is visibly a
  block: another key of the grammar beside it, or the key's own value (`absent`,
  `present`, a revision).
* **No problem line is unbounded.** A problem quotes corpus words, and one marked
  fence of 200k stray words once printed a single 5.8–6.9 MB line (measured by
  S1-fix7's refuter and red-first by S1-fix8). A quoted word is clipped with its real
  length, as in `ZZZZ…...(1000000 characters)`. A fence names its first five stray
  words and counts the rest. Any line still longer than 2000 characters is cut, and
  says so.

So the unconverted set can shrink and never grow, and **the gate is green on the
corpus as it stands** — which is the hard constraint (`D9`): T1's baseline is
zero counted failures, a standing red is a defect rather than furniture, and a
checker that failed 1047 files on day one would be quietly disabled, which is
precisely how a cleanup rots.

### ⚠ The baseline is a list of file names: not a count, and not numbers

A count-based non-regression gate passes when one grandfathered file is deleted
and one unstamped file is added — net zero, defect through. **Match by identity,
never by counting.** This is the harness batch's `W12b` lesson, and this batch
re-learned it twice in one evening: a `pgrep -af run_regression` that answered
four hits for one run *because the pattern matched the process typing it*, and a
`grep -lieE` that swallowed its own pattern and "measured" 1050 files in a corpus
of 1047.

**A number is not an identity here either.** This project's clones mint colliding
issue numbers (CLAUDE.md records 1349–1353 naming two different defects each).
While the baseline listed numbers, a new unstamped file filed under a
grandfathered number inherited the exemption:
`1349-a-second-defect-under-a-colliding-number.md` passed `ok (0 problems)` on
every arm (measured by S1-fix6's refuter; outsider-fixes DECISIONS D19). So each
line is one whole `NNNN-<slug>.md`, and any other line that is not a `#` comment
(a bare number included) makes the checker refuse the whole baseline by name. The
conversion was one to one: each of the 1037 numbers named exactly one unstamped
file, so the grandfathered set of files did not change.

### What the checker runs, and what it reads

The only program it ever runs is **git**. `assert=` is a Tcl scan (§4), and
`report`'s citation census is a Tcl scan too: it used to run `grep -r`, which
follows a symbolic link named on its command line, so with `doc/claude/issues` or
`src` committed as a link out of the checkout the census counted thousands of
lines outside it (measured by S1-fix6's refuter). Every reader of the corpus
(the gate, `report`, and the suite's own B1, B4 and D9 census) first asks
whether `doc/claude/issues` leads out of the checkout, and reads nothing if it
does. Every git call runs with `GIT_NO_LAZY_FETCH=1`, so no text in an issue
file can make a partial clone fetch from its remote: a `tree=` naming a blob the
clone did not hold used to start `git fetch` and `git-upload-pack` and write a new
pack into `.git`. In a partial clone, a `quote=` whose file is in the revision
but whose content is not in the checkout is NOT VERIFIED by name; a path the
revision does not have is still a failure.

### ⚠ A vacuous green is a broken checker wearing a pass

There are zero stamped files today, so every forward check has an empty input
set and would report success while doing nothing — the exact family that produced
**five** wrong driver measurements in one evening, every one a command returning a
plausible number without doing what was meant. So `gate` **self-tests against
known-answer fixtures first and reports nothing if it fails them**, and the suite
carries 34 checks of which 8 are red-observed. A green here means the parser was
exercised.

---

## 6. What this cannot see — stated, because an undocumented blind spot is worse than none

* **Prose below the fold is not validated.** The highest-consequence rot in the
  whole sample was 0071's child tables, and 0071's *header is correct*. Rule 4 of
  §3 (do not mirror; link) is the answer, and it is a convention, not a check:
  the `super=` coherence check can only compare two stamps, so it is blind until
  both files are stamped.
* **Cross-reference presence is not duplicate detection.** Issue 1458 names 1397
  in its own `Related:` line and duplicates it anyway.
* **Closure cannot be inferred from prose, and must be declared.** This is the
  best-measured rule in the spec, because the attempt was made and audited on the
  same day. The driver's `closescan.py` greps for *"fixes / closes / supersedes
  issue N"* and reported **7** issues closed-but-still-marked-open. Verified
  against the tree, **4 of the 7 were false** and the real class is **1 in 165**.
  The regex was blind three ways, none of which a pattern over English can fix:
  **negation** (*"FILED, **not** closed: issue 0516"* — the negation sits inside
  the pattern's own 40-character gap), **attribution** (*"CLOSED 2026-07-14
  (issue 0071 atom 6)"* closes 0003 and merely *credits* 0071), and
  **prescription** (*"…and fixes 0947 at the same time"* is an unimplemented
  option 3; a proposal is not an event). Acting on that table would have marked
  **two genuinely open defects closed, one carrying a live user ruling.**
  It also flagged **issue 0818 as claimed-closed by
  `tests/headless/issue_stamp.tcl`** — the file implementing this spec — from the
  sentence *"3 of 3 still **resolved**; and exactly one — **issue 0818** —"*. A
  citation *resolving* is not an issue being *resolved*, and a file written
  twenty minutes earlier silently moved a corpus-wide census. **That is why
  closure lives in `super=`, a declared field, and never in a regex over
  English**, and why `N1` locks it against a future improver.
* **Three independent sightings now say the truth is in the file, just not where
  anyone looks.** 0071's child tables; 1436's refutation living in
  `test_ase_dialogs.tcl` and 1395's in `src/ase_window.tcl`; and 0249's own
  `# RESOLUTION — FIXED` sitting **306 lines below** a header that still says
  OPEN.
* **Deliberate disguise is out of scope.** A stamp or an assertion hidden from
  the parser on purpose — behind an invisible character such as NBSP or ZWSP, in
  HTML with attributes, or inside a table, a link or a task list — is not
  detected, because the checker is a hygiene tool against honest error and not
  a gate against its own authors: whoever can write the file can simply leave
  the stamp out (outsider-fixes DECISIONS D18).
* **A checkout whose own path is not valid UTF-8 is unsupported.** A clone under a
  directory such as `lat\xe9/` (a Latin-1 byte) is falsely red in both locales,
  measured by S1-fix6's refuter. Under `LANG=C.UTF-8` the path does not round-trip
  through Tcl, so the history probe cannot find `.git` and reads the clone as an
  export, and the baseline reads as missing. Under `LANG=C` this box's `timeout`,
  uutils coreutils 0.8.0, refuses any command line that is not valid UTF-8
  (*"invalid UTF-8 was detected in one or more arguments"*). Every git call is
  wrapped in it, so each one fails and every revision reads as unresolved. Paths
  in UTF-8 (`café`, `日本`, an emoji) are green in both locales. This is recorded
  rather than fixed (outsider-fixes DECISIONS D19). Rename the directory or clone
  elsewhere.
* **A stamp body inside a fence is named, as anywhere else** (outsider-fixes
  DECISIONS D21). ``see `v1 claim=open …` `` in a ```` ```text ```` fence is an
  example to a reader and to markdown, and the checker names it: every line holding
  a body — a backtick, `v1`, blanks, then `claim=` — that is not the stamp line is a
  problem, in a fence or not, at any indentation or blockquote depth. S1-fix8
  exempted closed fences and S1-fix9 found them through blockquotes and lists, and
  each round's refuter then measured new regressions **in that exemption** from
  nested markdown: a fence shown inside a fence, a blockquoted or four-indented fence
  inside an example, a docstring example. One of them failed **open**: a colon-less
  stamp in prose after such an example passed. A line-based scanner cannot settle
  which fence a nested container's ```` ``` ```` line belongs to, and a real
  CommonMark parser is out of scope, so the exemption was withdrawn. The limit is
  fail-closed and loud, and the real corpus has no such line. **The workaround:**
  show a stamp example outside `doc/claude/issues/` (a spec such as this one is not
  scanned), or break the body so it is no longer one — write `` `v1 …` `` without
  `claim=`, or leave out the backtick before `v1`. Rows Q19 and Q22 hold the limit.
* **A stamp written in a fence is still read as one.** A canonical `**STAMP:**` line
  at column 0 inside a fence is read as a stamp, because the stamp reader does not
  look at fences. So is `STAMP:` followed by a body, in any emphasis, which is named
  as a stamp the parser does not read. Both are fail-closed (red), as they were at
  `aa5cece0`. The real corpus has neither.
* **Which fences the block reader sees, exactly.** This section said until S1-fix9
  that *"a fence inside a blockquote or a list item is not seen as a fence"*, which
  was wrong for a list item: a list-item fence indented three spaces or fewer **is**
  seen (measured by S1-fix8's refuter). The block reader (`quote=`, `assert=`) sees
  a fence indented three spaces or fewer, a list item's included, and reads only a
  column-0 backtick one. It does not see a fence indented four or more spaces (a
  nested list item's), one inside a `>` blockquote, or one with a list-item marker
  on its own line (`- ```text`). A `quote=` or `assert=` on any fence it does not
  read is named, never passed. A block inside a container is therefore never
  *verified*; write it at column 0.
* **A backtick in a backtick fence's info string makes it no fence** (§4), as
  CommonMark has it, and markdown-it agrees on both consequences. **A `pat=` cannot
  hold a backtick:** ```` ```sh assert=absent pat=`x` … ```` is inline code, not a
  block, and is named as such, where the checker before S1-fix9 read it. And **a
  ```` ```sh `make` output ```` line opens nothing**, so the bare ```` ``` ```` meant
  to close it opens a fence instead, and a real `quote=` or `assert=` fence after it
  is text inside that one: named as not read, never passed — and since issue **1489**
  so is a *misspelled* marking key there, which used to be the one thing this
  swallowing hid (§4). Search for the text
  without its backticks, and write example output under a plain ```` ```text ````.
  **That rule moves two verdicts against the older checker, in opposite
  directions, and both are stated here because a reader will meet them.**
  *One:* a **true** `assert=` or a holding `quote=` written after such a line is
  now RED where the older checker passed it. It is not a false alarm — markdown-it
  (commonmark) renders that line as a paragraph and the ```` ``` ```` under it as a
  fence whose content is the block, so nothing evaluates the claim, and passing an
  unevaluated claim is the one thing this checker may not do. The same honest
  assertion is named in **every** other position the parser does not read —
  indented, `~~~`, never closed — by this checker and by the older one alike
  (measured, all three, both). What the older checker had there was an accidental
  green from a parse the reference rejects. The message names three line numbers:
  the block's own line, the line that opened the block that swallowed it, and the
  backtick-info line whose ```` ``` ```` closer became that opener.
  *Two, and it is a limit rather than a defect:* a `key=value` word on such a
  swallowed fence whose key is neither of the grammar nor a near miss of `quote=`
  or `assert=` — ```` ```sh insert=absent pat=… path=… state=holds ```` — is
  **silent**, where the older checker named it. The older checker named it only
  because it *read* that fence; in every other unread position — indented, `~~~`,
  never closed, inside another fence — the older checker is silent on the identical
  text too (measured, all four, both checkers). Closing it would mean naming every
  unknown word on every unread marked fence, which false-reds the ordinary code
  samples this checker was just taught to leave alone (```` ```sh path=/tmp ls ````
  in an example block), so it is recorded rather than fixed. Nothing evaluable is
  lost: the key is not `assert=` or `quote=`, so no claim passes — there is no
  claim. Row Q26 holds both halves.
* **An ordinary word one letter from a marking key is named if it also looks like a
  block.** `asset=` is `assert=` with a letter left out and `quota=` is `quote=` with
  one typed wrong, so ```` ```js asset=absent path=x ```` and ```` ```sh
  quota=d64686a1 ```` are named as misspellings, and the author must rename the word
  or move the sample out of `doc/claude/issues/`. A fence carrying such a word on its
  own — ```` ```js asset=x ````, ```` ```sh quota=10 ````, and the same words in any
  case (```` ```js asset=X ````) — is an ordinary code sample and is not named (§4).
  The real corpus has neither, and the fail-closed
  direction was chosen deliberately: a silent pass on a misspelled `assert=` hides a
  claim about the tree, while this costs one rename.
  **The boundary is that both the key and the value must be outside the grammar.**
  ```` ```sh asert=absnet ```` — a misspelled key *and* a misspelled value, with no
  other key of the grammar beside it — is silent, where the checker before issue
  **1489** named it as a key it did not know. It carries no claim anything could
  pass on: nothing there says `absent`, `present` or a revision, so there is nothing
  to evaluate and nothing to leave unevaluated. Adding any grammar key back
  (```` ```sh asert=absnet pat=… path=… state=holds ````) re-arms the check.
* **A block that lost its marking key entirely is not named.** A fence carrying
  `pat=`, `path=` and `state=` but no `assert=` at all, or `path=` alone, is read and
  has nothing to evaluate. Naming it would false-red ordinary code samples that
  carry a `path=` word. The converse cost of marking by those three keys is stated
  too: an ordinary code sample whose info string holds one of them **and** a word
  that is not `key=value` (```` ```sh path=/tmp ls ````) is named as a malformed
  fence. The real corpus has neither.
* **The gate's 600 s wall-clock budget depends on the box.** On a machine slow
  enough that the gate takes longer than that, whatever it reaches afterwards is
  red, and the problem says why: the gate's time ran out. The real corpus takes well
  under a second here. The budget is asked **before** a file's fences are scanned,
  not after: scanning a file is the one pass whose cost the corpus's own text sets,
  so a run past its budget names the file and reads no further. Measured on a 90 MB
  corpus of misspelled-key fences with the budget set to 2 s: 9.6 s when the
  question came after the scan, 2.5 s when it comes before, with the same verdict.
* **In a partial clone, a `quote=` whose content was never fetched is NOT VERIFIED.**
  The checker never fetches (every git call runs with `GIT_NO_LAZY_FETCH=1`), so
  the content of an old revision's file is not there to compare against. It is
  named on a `NOT VERIFIED` line, as a shallow clone's revisions are, and a full
  clone checks it. A path the revision does not have is still a failure, because
  that can be read from the revision's trees, which a `blob:none` clone holds.
* **A green T1 does not mean every suite arm is green.** Do not add a rule of the
  form *"no open issue may claim a red row while T1 is green"*: issue **1436**
  legitimately claims a red display-arm row, because `test_ase_dialogs` sits in
  `hcases` and **not** in `dcases`, so T1 never runs that arm. Such a rule would
  false-red the most careful file in the sample.

## 7. Designs considered and rejected

| shape | why not |
|---|---|
| `tree=` must equal `HEAD` | reddens the corpus on every commit; it *is* the `PLAN.md:3` defect, mechanised |
| a non-regression **count** of unstamped files | delete-one-add-one passes; identity, never counting |
| infer closure from *"fixes issue N"* prose | **4 of 7 flagged issues were false** when audited; blind to negation, attribution and prescription; and it false-positived on this spec's own implementation file within the hour |
| a self-test that asserts only a known **positive** | proves the check fires, never that it does not **over**-fire; that is exactly how the 4-of-7 above survived. Every check here carries a known negative too |
| validate only the first ten lines | scores 0071 — the worst file in the sample — green |
| check every `file:line` in `src/` and `tests/` | 937 across 27 `src/` files and 1190 in `tests/`; green-field rot, and reddening it on day one gets the checker disabled. **Report it; do not gate it.** |
| rewrite the 1047 files into a house style | not achievable by anyone, and it would become the seventh prescribed fix that damaged something |

## 8. Worked examples — proposed here, and APPLIED by D1

These are what the stamp says for real files. They were written as proposals and
`D1` adopted every one on 2026-09-17, so the ten files now carry `tree=61af3692
by=D1` rather than the `tree=8608c7ef` and `by=` values proposed below. The rows
are kept in their proposed form as the record of what was designed — except for
two numbers, which were simply **wrong**.

⚠ **Two `open=` counts in this table were wrong, and a count is the one field a
reader cannot sanity-check by eye.** Re-measured by `D1`, and again independently
by `BC2`; the applied stamps carry the corrected numbers and the table below has
been corrected to match.

* **0442 is `open=1`, not `open=0`.** Its "Still open" list has three items and
  **two of them are fixed**. Item 1 (the four unfiltered classes):
  `op_annot::_netlisted` no longer mirrors symbol attributes at all — it asks the
  deck index — and the seven-class truth table is in the file. Item 3 (the
  `spiceprefix` card prefix): `op_annot::_element` builds the deck identity from
  `xschem translate {@spiceprefix@name}`, under a comment forbidding `getprop`.
  Item 2 (the `netlist_type` divergence) stands, now as a **declared
  constraint** — `op_annot::_force_netlist_env` forces `netlist_type spice`.
* **0650 is `open=5`, not `open=1`.** Its own closing section names six
  follow-ups and only **0658** has moved to FIXED; **0654**, **0655**, **0659**,
  **0660** and **0661** all still read OPEN in their own headers. `open=1` counted
  the titular half alone and rounded four live follow-ups away.

**That error shape is the argument for `open=` being a count rather than a flag,
and also its warning label:** a wrong count still parses, still reads plausibly,
and is believed. Re-derive it from the file's own list when you re-stamp; never
carry it forward.

| file | proposed stamp | what it fixes about today's header |
|---|---|---|
| **0442** | `` `v1 claim=fixed tree=8608c7ef stamped=2026-09-17 fix=superseded open=1 super=self by=A2` `` | says `STATUS: **OPEN.**` while the tree fixed it by 0442's own unnumbered alternative; `fix=superseded super=self` is what stops a reader pasting item 1. **`open=1`, corrected from `open=0`** — two of its three "Still open" items are fixed, the `netlist_type` divergence is not |
| **0891** | `` `v1 claim=partial tree=8608c7ef stamped=2026-09-17 fix=partial open=1 by=A3` `` | says three follow-ups are outstanding; **two landed**, one (drop `test_annot_stale_0684` from `dcases`) genuinely has not |
| **0905** | `` `v1 claim=fixed tree=8608c7ef stamped=2026-09-17 fix=superseded open=2 super=32dff39a by=A3` `` | closed against a design that lived hours; its §2 records as *deliberately rejected* the shape `32dff39a` shipped |
| **1219** | `` `v1 claim=latent tree=8608c7ef stamped=2026-09-17 fix=untried open=1 by=A3` `` + an `assert=absent pat=SABOTAGE path=src state=broken` block | its own numbers understate it (60 lines/28 files → **118/44**), and the `assert` block makes the tree close it automatically |
| **1438** | `` `v1 claim=fixed tree=8608c7ef stamped=2026-09-17 fix=taken open=0 super=1439 by=A4` `` | says *"Filed by the driver, not fixed"*; 1439 fixed it and 1439's header says so |
| **1458** | `` `v1 claim=duplicate tree=8608c7ef stamped=2026-09-17 fix=none open=0 super=1397 by=A4` `` | duplicates 1397 while citing it in `Related:` |
| **0216** | `` `v1 claim=partial tree=8608c7ef stamped=2026-09-17 fix=taken open=1 scope=ase-rerun-path by=D0` `` | fixed for the Location bar and `wviewer::restore`, **not** for the ASE re-run path; a binary schema closes it wrongly |
| **0650** | `` `v1 claim=partial tree=8608c7ef stamped=2026-09-17 fix=taken open=5 super=0655 by=D0` `` | the general channel landed at `5dd68128`; the **titular** session-window sink did not, and 0655 carries the remainder. **`open=5`, corrected from `open=1`** — 0655 plus 0654, 0659, 0660, 0661 all still read OPEN; only 0658 moved |
