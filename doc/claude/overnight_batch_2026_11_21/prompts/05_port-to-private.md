# Work order 05 — carry tonight's product changes to `~/private/xschem-private`

Prepared 2026-11-21. Runs last. Commits nothing in any repository.

## Why

The user's design workarea (`~/dev/hdo-design`) starts the xschem of
`~/private/xschem-private`. A change made in `~/dev/xschem-claude` is not in front of the
user until it is carried over. The user applies patches to that tree and commits there
themselves. On 2026-11-21 the user asked how to commit the files of a fix in that tree and
said the hand-overs so far always left that part out. So this item is finished only when
the commands to COMMIT are in the hand-over and were run in a replica.

## What to carry

The product commits this batch landed in the main tree, and nothing else:

    git -C /home/analog/dev/xschem-claude log --oneline 7c77f3594..HEAD

The ledger in `PLAN.md` says which of items 02, 03 and 04 landed (`[x]` or `[E]`); their
receipts name the commit and the files. Not carried: the commit of the batch directory, the
how-to of item 01 (the other session reads it where it is), `CLAUDE.md`, and any item marked
`[F]` or `[D]`. If no product item landed, write a README that says so and stop.

## What the user must be able to type tomorrow

`/home/analog/port_ob21/README.md` opens with these, in this order, each one tried by you:

1. apply the patch (working tree only): `cd ~/private/xschem-private` and
   `git apply /home/analog/port_ob21/port.patch`
2. build: `make -C src` (with `./configure` first if the patch touches `src/Makefile.in`,
   and then the README says so)
3. "restart any open xschem" (xschem reads its Tcl files once at startup; a session opened
   before the patch keeps the old behaviour)
4. commit, one commit per item, in the order the items landed. For each item:
   `git apply --cached --whitespace=nowarn /home/analog/port_ob21/commit/NN/commit.patch`
   then `git commit -F /home/analog/port_ob21/commit/NN/message.txt`

Then, in plain sentences: what each commit holds (file count, new and modified); that the
commit step writes the index only, so nothing is rebuilt or restarted for it; what is still
uncommitted in that tree afterwards and that it was there before; the one-line check after
each commit (`git show --stat --format='%h %s' HEAD | tail -1`); what to do when the private
tree has moved since the patch was made (the command that makes patch and kits again); what
was tested, with the numbers, and what was not.

If the items cannot be separated into one commit each by the kit tool, hand over ONE commit
for all of them and say why. Do not hand over commands you did not run.

## How

The private tree is READ ONLY for you. Every trial is in a scratch copy at a short path:

| path | what | at the end |
|------|------|-----------|
| `/home/analog/os21` | scratch clone of the main tree, where tonight's product commits are made to look like uncommitted work (below) | remove |
| `/home/analog/pp21` | `cp -a` of the private tree with the patch applied | leave, and say so |
| `/home/analog/pp21b` | unpatched copy, for telling "red without the patch too" | remove |
| `/home/analog/pr21` | replica for the commit commands | remove |

Tools that exist, built and used for the port of issue 1724 on 2026-11-20:

- `/home/analog/port_1724/tool/make_port.sh` and its `lib/` and `adapt/`. Read its header:
  it lists the steps (snapshot, copy, three-way merge of every tracked file both trees have,
  the registration of suites replayed in the target's own lists, the issue numbers written
  into the target's `NUMBERING.md`, issue stamps made valid in the target, doc hunks that do
  not fit left out by name, apply, build, text checks, suites on both arms, each red re-run
  in an unpatched copy, tables). It reads the SOURCE's UNCOMMITTED work, and its head names
  issue 1724: the number, the pattern of new files, the scratch paths and the notes under
  `adapt/` are that port's.
- `/home/analog/port_1724/tool/make_commit_kit.sh <patch> <target> <outdir>`: writes
  `commit.patch` for `git apply --cached`, which stages a port alone even where a file
  holds other uncommitted work; it names a file it cannot separate and takes a hand-made
  version from `<outdir>/resolved/<path>`.
- `/home/analog/port_1724/README.md`: the hand-over that was accepted, as a model.

Do NOT edit anything under `/home/analog/port_1724`. Copy the tool
(`cp -a /home/analog/port_1724/tool /home/analog/port_ob21/tool`) and adapt the copy: its
head, its `adapt/` notes (the 1724 ones do not apply and some of its checks refuse to go on
when they do not hold), its suite list. To give it uncommitted work to read:

    git clone -q /home/analog/dev/xschem-claude /home/analog/os21
    git -C /home/analog/os21 reset -q --mixed 7c77f3594

after which `git -C /home/analog/os21 status` shows tonight's changes as modified and
untracked files. Leave out of the manifest what is not carried (above).

If adapting the tool costs more than doing its steps by hand for a change this size, do
them by hand and say so. What counts is the contract:

1. `git -C ~/private/xschem-private apply --check /home/analog/port_ob21/port.patch`
   accepts the patch on that tree as it stands when you finish (its HEAD plus whatever is
   uncommitted there). Record that HEAD and the time in the README.
2. The patched copy builds.
3. In the patched copy: `tclsh tests/headless/issue_stamp.tcl` answers ok; every suite the
   items registered here is registered in the target's `tests/run_regression.tcl`, in the
   same lists; an issue number minted tonight is in the target's `NUMBERING.md` with its
   pointer moved past it.
4. Every suite the items added or touched passes in the patched copy on both arms, through
   `run_suites.sh` with `AUDIT_DISPLAY=private`, one at a time. Add the neighbours the
   receipts name. Each red is run again in the unpatched copy: red there too means not
   this port's, and the README says which rows.
5. One full regression of the patched copy (`T1_DISPLAY=private`, detached, polled in
   bounded steps). Report its trailer line. A counted failure is run as a single suite in
   the unpatched copy to class it. If the unpatched tree is not at zero itself, say so and
   name the cases; that is the other session's, not yours to repair.
6. The commit commands, typed as the README gives them, in the replica: each `git apply
   --cached` and `git commit -F` ends rc 0, each commit holds its item's files and no other,
   and afterwards `git status --short` shows only what was uncommitted in the private tree
   before.
7. Each `message.txt` is the item's commit message from the main tree with one opening
   line added that says it is a port, from which commit, made for which target commit; it
   keeps the two trailer lines.

## Traps the last port met

- The private tree is committed to every day by another session. A patch goes stale within
  a day; make it last, state the HEAD it was made for, and give the command that makes it
  again.
- `tests/run_regression.tcl`, `doc/claude/issues/NUMBERING.md` and long specs differ between
  the trees. A registration is replayed in the target's list, not patched in by context.
- A stamp line's `tree=` must be a commit the TARGET has, and an ancestor of its HEAD.
- A file the target lacks is left out by name (`src/startup_quiz_bank.tcl` did not exist
  there on 2026-11-21; item 01's how-to may change that).
- Whitespace: `git apply --cached --whitespace=nowarn` keeps a "new blank line at EOF" note
  from looking like a failure.
- A scratch copy holds the user's uncommitted files of the private tree. Do not publish,
  move or quote them anywhere; remove the copies named "remove" above.

## Done means

`/home/analog/port_ob21/` holds `README.md`, `port.patch`, `commit/NN/commit.patch` and
`commit/NN/message.txt` per carried item, the table of suite results, and your copy of the
tool as you ran it. The replayer of the next stage will type the README's commands in a
fresh replica; whatever does not go as the README says comes back to you.
