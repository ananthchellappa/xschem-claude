# Decisions — stranger reds batch

# D1 — The audit's remaining findings are one batch, dispatched one item at a time (driver)

Issues 1483-1487 and 1489 were filed rather than fixed when the outsider-fixes batch
closed. They share one subject: what someone who is not this developer meets on first
contact with the branch we publish. They are dispatched in the order of PLAN.md's table,
one crew at a time, each returning a receipt.

# D2 — Rounds are capped at three, and the cap is part of the brief (driver)

The previous batch ran eleven implement-and-refute rounds on one item; the last three
shipped nothing. Each item here gets one implement round, one adversarial verify and at
most one fix round, with the acceptance criteria written before the first round rather
than after the fifth.

# D3 — A corpus list is an enumeration question, not a trackedness question (driver)

Issue 1485's nine suites all asked git the same thing: "the `.state` files of this
checkout". Git was the cheapest enumerator, not the subject. So the fix enumerates the
same files from the filesystem when git cannot answer, and coverage does not move: an
export carries exactly the tracked files, and all nine keep every check (1284 across the
nine, in an export, in a clone with `.git` removed, and in a normal clone).

Skipping was rejected as the default. A stranger's run would have gone green by measuring
less, which is the failure this batch exists to remove rather than a fix for it. A row
that genuinely needs git — trackedness itself, a revision, a diff — reads the helper's
`source`/`reason` and prints its own `skip:` line naming what is missing. None of the nine
needed to.

Three consequences the verifiers measured, all now in the code:

* **The filesystem arm is a superset of the index**, so a row that reads it must assert a
  floor, not an equality. Four rows asserted "exactly 104 files" and went red the moment
  somebody saved their own bench — ordinary first use. They are floors now; their shape
  halves stay exact, so a 105th file must still round-trip.
* **"Git answered nothing" is not the same as "git cannot answer here."** Falling back on
  an empty list hid a real defect: in a clone where the corpus had stopped being tracked,
  all nine passed by measuring untracked files instead. The helper now asks which
  repository git is answering about, which also catches an export unpacked inside someone
  else's checkout (measured: 50 of 104 files, at exit 0, with nothing saying so).
* **A corpus read must never raise.** `glob -nocomplain` suppresses "no matches", not
  "permission denied", so one unreadable directory killed three suites outright — the
  very shape 1485 is about. Unreadable and symlinked directories are counted and named in
  the run's `note:` line instead.

# D4 — Two findings from item A's verifiers are filed, not fixed (driver)

A checkout path containing a space reds 71 rows across five suites, and a read-only
checkout fails `test_scratch` and `state_roundtrip.tcl`'s temporary file. Both are
stranger-facing and neither is issue 1485. They are filed as **1490** (a space in the
checkout path reds 71 rows across five suites) and **1491** (a read-only checkout dies in
`test_scratch` and in `state_roundtrip.tcl`'s temporary file), per PLAN.md criterion 4, and
will be scheduled on their own.

1490 is knowingly incomplete: the crew that measured the 71 rows deleted its scratch before
the rows were written down, so re-measuring and naming them is step 1 of that issue's own
fix direction. That is the cost of the delete-your-scratch rule, and it is the right trade
against 192 GB — but a receipt must carry the row names, not only the count.

# D5 — Item B's crash is one statement, and the fix reports absence rather than a number (driver)

All four suites die at the same place: `xschem globals` asks Xlib for `XMaxRequestSize`,
and `display` is only ever assigned inside `if(has_x)`. With no `DISPLAY` it is NULL, and
with `--nogui` and a `DISPLAY` set it is a pointer `xserver_ok()` has already closed — that
second mode printed a fabricated `XMaxRequestSize=4` against a true 65535, which is why
the fatal first mode survived: every arm anyone ran had a display.

Three of the four reach it through the product's own `op_annot.tcl`, inside a `catch` that
a signal ignores. So this is a product defect: a headless user annotating operating points
crashes, with or without our tests.

The guard reports the absence (`<no X server connection>`) rather than zero or a silent
omission, in the idiom the codebase already uses for "no X" (`gc_line_style` answers -1).
The keys stay present so a reader still finds them, and a reader scanning for digits comes
away with none rather than with a fabricated figure.

**The relation 1483 inferred to issues 0227, 0834 and 0467 is refuted as a cause.** Those
are a different site (`XGetKeyboardControl` in `callback.c`, reached through `xschem
callback`) and they still crash on the fixed binary. They are right about the class and
wrong about the statement.

# D6 — Item B's out-of-scope findings are filed, not fixed (driver)

The verifiers measured five things outside issue 1483, all on the fixed binary:

* four more suites crash headless at `callback.c`'s `XGetKeyboardControl` — the 0227/0834
  family, none of them a T1 case, and 0467 is a duplicate of 0227 rather than a teardown
  crash as its file says;
* four `xschem` verbs (`fill_reset`, `fullscreen`, `copy_hilights`, `compare_schematics`)
  kill the process headless;
* `xserver_ok()` closes the display without setting the pointer to NULL, which is what
  makes the freed-pointer mode silent rather than fatal;
* `run_suites.sh` reports a crashed suite as `NORESULT` and discards the crash text the
  bare command prints — the same family as issue 1487;
* a checkout path longer than about 73 characters reds `test_op_annot` and
  `test_annot_hier_0911`, because `statusmsg_text` is `char[256]` and the golden carries
  an absolute path. This is issue 1484/1490's shape with length as the trigger, and it
  made item B's own gate unrunnable inside the scratch root its crew was assigned.

Each is filed on its own. None is fixed here (PLAN.md criterion 4).

# D7 — Item C: one defect, two faces, and the obvious fix was itself a defect (driver)

Traced, not inferred, on two ngspice builds and confirmed against `inp_readall` in
ngspice's own `inpcom.c`: a control line splits an unquoted path at the first space, and a
line whose command is not on ngspice's whitelist is lowercased in full. `wrs2p`, `set`,
`meas`, `wrnodev` and `show` are on neither list; `write`, `wrdata` and `echo` are. So
1484's guess (lowercasing) was right for its face, 1490's (word splitting) was right for
its face, and they are the same word reaching the same parser.

**Quoting the path does not work.** `wrs2p "<path>"` keeps the quotes as part of the
filename and writes nothing. What works on both binaries is `setcs v = '<path>'` followed
by `$v`, because `setcs` is whitelisted and `$v` expands after folding. Four characters
survive no encoding at all (`$`, backquote, `{`, `}`) and are now refused by name rather
than silently losing the file; measured that none of them ever worked bare either.

**The product consequence, measured outside the suites.** One bench writing six artifacts:
an ordinary path wrote 6, a path with a capital wrote 3 (three landed in a lowercase
sibling directory), a path with a space wrote 1 — every artifact collapsed onto one file,
each clobbering the last, at rc 0 with nothing on stderr. After the fix, 6 of 6 in all
three. A cell NAME with a capital does it too, in an all-lowercase directory.

**What the adversarial round added, and it was the larger half:** the restore side of the
saved operating point emits `.include <path>` and was still bare, so a space made the run
fail outright (`Could not find include file`, rc 1, no output); a path carrying a newline,
tab or carriage return lost its artifacts silently and is now refused by name; and the
first round's attribution of one failing row to the user's PDK was wrong — it was ASE-L's
own `.include`, shown by reverting that one change.

# D8 — Item C's leftovers (driver)

* `.include` and `.lib` cards written by the user's own PDK setup still fail on a path with
  a space, loudly (rc 1). No quoting fixes `.lib`; it needs its own item.
* **Issue 1334 is this defect, found earlier and worked around by refusing a feature and
  asking the user to rename their folder.** With a general escape that refusal may be
  liftable. That is user-visible product behaviour, so it is the user's call, not the
  batch's: filed as a ruling rather than changed.
