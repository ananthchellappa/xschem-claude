# How to build the tip-of-the-day quiz in another XSCHEM tree

**This file:** `/home/analog/dev/xschem-claude/doc/claude/suggestions/howto_startup_quiz_in_another_tree.md`

Written 2026-11-21 for the session that works in `~/private/xschem-private` (branch
`assembler`) and wants the quiz this repository asks at startup. You do the work and
commit it in your own flow. Nothing described here was applied to your tree.

What the text was read from:

- this repository, `/home/analog/dev/xschem-claude`, branch `fluid-editing`, as of commit
  `7c77f3594`. The commit that added this file also corrected one sentence of the spec
  (its section 4, what band `L` of the suite measured); it touched no other quiz file;
- your tree at commit `a464b7f6b`, read only.

Both move. A statement about either tree says what was the case that day. A figure, or
a statement that something was the case, stands beside the command that showed it: run
the command, and believe what it prints over what this file says. Three kinds of
statement have no command of their own, and say so:

- one that was measured by breaking this repository's wiring on purpose says what was
  taken out and which of this file's commands were then run;
- one that comes from reading alone says "read" and names the step that checks it again
  in your tree;
- what a row of the suite checks is read from the row itself, in your copy of the suite
  (`/usr/bin/grep -n '"F5 ' tests/headless/test_startup_quiz.tcl` finds row `F5`).

How to read the commands:

- `S` is this repository and `W` a scratch directory for a reading aid, two captures and
  a frozen copy of this repository's `src/`. Commands are typed at the root of your tree
  unless they say otherwise. Later commands use `$S` and `$W` without setting them: if
  every command you type runs in a fresh shell, put the two lines below at the head of
  each.
- A path that starts with `$S/` or `/home/analog/dev/xschem-claude/` is in this
  repository. `$W/ref/src/` is this repository's `src/` as it was at the commit you copy
  from; step 4.1 makes it, and the comparisons of sections 4 and 6 read it, not this
  repository's working files, where another session may be in the middle of an edit.
  Any other relative path (`src/...`, `tests/...`) is in your tree.
- Rows of the suite are named by their id (`F4`, `A15`), procs and C functions by name,
  places in a file by the text that stands there. No line numbers.

```sh
S=/home/analog/dev/xschem-claude
W=${TMPDIR:-/tmp}/quiz_howto ; mkdir -p $W
```

## 1. What you are building, and what done looks like

When an interactive session starts, XSCHEM opens a small window titled "Tip of the day"
over the main window and asks one question about itself: true or false, or pick one of a
few options. The person clicks an answer, is told whether it was right, and reads two or
three lines on how the thing really works. The window is not modal and nothing waits on
it. A box in the window, a Help-menu entry and a command-palette row turn it off for
good, and Help > "Tip of the day (quiz)..." asks a question whenever the person likes.

The route is **port and extend**. You copy the engine, the suite, the spec and the
question bank from this repository, wire them into your tree, let the suite re-prove
every question against YOUR product, and then add questions for what only your tree has.
Do not rebuild it from the spec: the spec does not carry the entry validation, the proof
helpers or the launch harness, and a second engine would have to be kept in step with
this one from then on.

Done is four things:

1. The quiz suite is green on both arms in your tree (section 5), with every question
   reviewed for your tree (section 6).
2. A census over one full regression run shows that no other suite's launch is asked a
   question (section 8).
3. Your full regression is at zero counted failures, taken in a clone at a short path
   (section 9).
4. The dialog is recorded as something the user has to look at. No suite can see fonts,
   wrapping, colours or placement on the real screen (section 10).

The sections are in the order you act, with one exception. Section 8 explains the
census and is read where it stands; the census is run inside section 9, whose steps are
the last stretch in order: capture, register, correct two inherited sentences, commit,
build in the gate clone, census, your own sentences in the spec, gate.

## 2. Read these first

| read | what it gives you |
|---|---|
| `/home/analog/dev/xschem-claude/doc/claude/specs/startup_quiz.md`, sections 4, 5 and 7 | when a question is asked, the switch, and the rules of the bank |
| the header comment of `/home/analog/dev/xschem-claude/src/startup_quiz_bank.tcl` | the entry format, key by key, and the list of proof helpers |
| the header of `/home/analog/dev/xschem-claude/tests/headless/test_startup_quiz.tcl` | the suite's bands and what each one fences |

Two things a reader gets wrong without them:

- **The engine stores a question's `proof` and never evaluates it.**
  `startup_quiz::validate` only checks that the key is there and not empty. A proof is
  evaluated by band `A` of the suite and by nothing else, so a question is checked when
  the suite runs and at no other time.
- **The proof helpers live in the suite.** `P_has`, `P_proc`, `P_bind` and the others are
  procs of `tests/headless/test_startup_quiz.tcl`. They do not exist in a running
  XSCHEM, and a new helper is written there, not in the engine.

## 3. Before you start: check that your tree still has what the engine leans on

The block only reads. Run it at the root of your tree.

```sh
S=/home/analog/dev/xschem-claude

# 1. Files the engine and the suite lean on. "same" and "DIFFERS" are both fine
#    (a file may have moved on in either tree); "ABSENT" is not.
for f in src/action_registry.tcl src/ciw.tcl src/keybindings.csv src/callback.c \
         src/options.c tests/banner_rule.tcl tests/headless/scratch.tcl \
         tests/headless/run_suites.sh tests/headless/gated_xschem.sh \
         tests/headless/test_home_isolation.tcl \
         tests/headless/test_suite_watchdog_1403.tcl \
         tests/headless/test_registered_banner_1626.tcl; do
  if [ ! -e "$f" ]; then echo "ABSENT  $f"
  elif cmp -s "$S/$f" "$f"; then echo "same    $f"
  else echo "DIFFERS $f"; fi
done

# 2. Anchors. want <lines> <file> <text>: the text must stand on exactly that many
#    lines of the file ("1+" = at least one). Every line must start with "ok".
want() {
  n=$(/usr/bin/grep -cF -- "$3" "$2" 2>/dev/null); s='!!'
  if [ "$1" = "1+" ]; then [ "${n:-0}" -ge 1 ] && s=ok; else [ "$n" = "$1" ] && s=ok; fi
  printf '%s  %-28s %s line(s), want %s: %s\n' "$s" "$2" "${n:-?}" "$1" "$3"
}
want 1  src/xinit.c 'tclsetvar("cli_opt_nolog"'
want 1  src/xinit.c 'source_tcl_file(cli_opt_tcl_script)'
want 1  src/xinit.c 'tcleval(cli_opt_tcl_post_command)'
want 1  src/xinit.c '"exit %d", exit_code'
want 1  src/xinit.c 'END PROCESSING USER OPTIONS'
want 1  src/globals.c 'int cli_opt_pipe'
want 1  src/xschem.tcl 'if {[catch {source $XSCHEM_SHAREDIR/ciw.tcl} ciw_source_err]} {'
want 1  src/xschem.tcl 'proc xschem::notify_degraded_once'
want 1  src/xschem.tcl '$topwin.menubar.help add command -label "Command palette" -command "command_palette $topwin"'
want 1  src/xschem.tcl '$topwin.menubar.help add command -label "About XSCHEM" -command "about"'
want 1  src/xschem.tcl 'set_ne raw_history_max 20'
want 1  src/xschem.tcl 'wviewer::rawhist_load'
want 1  src/xschem.tcl 'set_ne XSCHEM_START_WINDOW {}'
want 1  src/xschem.tcl 'proc fuzzy_subseq_score'
want 1  src/actions.csv 'id,type,menu,label,accel,command,submenu,hook,help,idle,nolog'
want 1  src/actions.csv 'help.keybindings_cheatsheet,command,help,'
want 1  src/actions.csv 'help.about_xschem,command,help,About XSCHEM,'
want 1  src/keybindings.csv 'key,50,alt,canvas,view.toggle_view_type,'
want 1  src/Makefile.in 'put /local/install_shares {'
want 1  src/xschemrc '# set wviewer_text_size 14'
want 1  src/xschemrc '#### redefine some variables to emulate Cadence UI / bindkeys'
want 1  src/scheduler.c 'strcmp(argv[1], "bindings")'
want 1  src/action_registry.tcl 'proc load_action_table'
want 1  src/action_registry.tcl 'proc command_palette'
want 1  src/action_registry.tcl 'proc palette_refilter'
want 1  src/action_registry.tcl 'proc palette_run'
want 1+ src/ciw.tcl 'notify_last'
want 1  tests/headless/scratch.tcl 'proc test_scratch {tag}'
want 1  tests/run_regression.tcl 'set hcases [list'
want 1  tests/run_regression.tcl 'set dcases [list'

# 3. Nothing of the quiz is there yet. Every line must start with "ok".
want 0  src/xinit.c 'startup_quiz'
want 0  src/xinit.c 'tclsetvar("cli_opt_pipe"'
want 0  src/xschem.tcl 'startup_quiz'
want 0  src/actions.csv 'startup_quiz'
want 0  src/Makefile.in 'startup_quiz'
want 0  src/xschemrc 'startup_quiz'
want 0  tests/run_regression.tcl 'test_startup_quiz'
for f in src/startup_quiz.tcl src/startup_quiz_bank.tcl \
         tests/headless/test_startup_quiz.tcl doc/claude/specs/startup_quiz.md; do
  [ -e "$f" ] && echo "!!  $f is already there"
done
/usr/bin/grep -n 'USER_CONF_DIR' config.h      # where the two saved files will live
```

What it answered on 2026-11-21, your tree at `a464b7f6b`: every `want` line started with
`ok`; the first loop printed `same` for every file except `tests/headless/scratch.tcl`,
which printed `DIFFERS` and still has the proc the suite needs; no file was already
there; `config.h` said `"~/.xschem"`, the same directory as in this repository (section
10 is about that).

When a line starts with `!!`:

- **An anchor of part 2 is missing or stands more than once.** The wiring step that uses
  it (section 4) names the row that checks the result. Read that row in the suite before
  you choose another place, because several rows compare positions in the file as text.
- **`ABSENT`.** Find what replaced the file in your tree before you go on. What leans on
  each one:
  - `src/ciw.tcl`: the engine reports through `xschem::notify`, and the suite reads
    back what it said;
  - `src/action_registry.tcl`: the action table and the palette, which the two rows of
    step 4.5 go through and the suite drives;
  - `src/keybindings.csv`: the binding table that `P_bind` and row `A13` read;
  - `src/callback.c` and `src/options.c`: files that proofs of the bank read
    (`/usr/bin/grep -n -E 'src/(callback|options)\.c' $S/src/startup_quiz_bank.tcl`
    prints the lines);
  - `tests/headless/scratch.tcl`: the suite sources it;
  - `tests/headless/run_suites.sh` and `tests/headless/gated_xschem.sh`: the launchers
    of sections 5 and 9;
  - `tests/banner_rule.tcl`: the regression's rule for a case that finished, used in
    section 9;
  - the three `tests/headless/test_*.tcl` files: the guard suites of section 9.
- **Part 3.** Somebody started this work already. Read what is there and continue from
  it; do not copy over it.

The same day the proofs of the bank were read against the SOURCE TEXT of both trees, by
a script that is not printed here: every helper call was evaluated against each tree's
files (a proc's body read from the file that defines it, the action table and the
binding table from their CSV files), and the procs that proofs call directly were
compared as text. The only calls that answered differently belonged to the two
questions about the quiz itself (`quiz-switch` and `quiz-close`), which become true
with the wiring. That was read, not run, and no command in this file shows it. It is
why this file recommends the port, and nothing below leans on it: band `A` evaluates
every proof in your tree's own binary (section 5), and section 6 says what to do with
each row that is red there.

## 4. Wiring, in the order it must be done, each step with its check

**Before the first edit: the tree you work in may be the program the user runs.** The
launcher of the design workarea starts the `src/xschem` of an XSCHEM source tree, and
on 2026-11-21 that tree was `/home/analog/private/xschem-private` itself:

```sh
/usr/bin/grep -n 'HDO_EDA' /home/analog/dev/hdo-design/xschemrc /home/analog/dev/hdo-design/run.tcl
```

(the first file sets the tree, the second builds the path of the binary from it, unless
`XSCHEM` is set in the environment). If you do this work in that tree, the quiz goes
live for the user in the middle of it, not at hand-over: once the files of step 4.1,
the build of step 4.3 and place 1 of step 4.4 are all there, the next design session
the user starts is asked a question, out of the bank as it stands at that minute, before
sections 6 and 7 have made the bank true for your tree. (The default of place 3 is not
needed for that: the engine counts an unset switch as on, row `B9`.) Sessions that are
already open are not touched: the hook runs once, at startup. Choose one:

- tell the user before step 4.3 that new sessions will show a "Tip of the day" window
  from now on and that its questions are still being checked; or
- do sections 4 to 7 in a clone or a worktree of your tree, with its own `./configure`
  and `make`, and bring the finished work into the tree the launcher runs.

### 4.1 Copy the four files

```sh
git -C "${S:?set S and W first, as at the head of this file}" log --oneline -- \
    src/startup_quiz.tcl src/startup_quiz_bank.tcl \
    tests/headless/test_startup_quiz.tcl doc/claude/specs/startup_quiz.md
QC=$(git -C "${S:?}" rev-parse --short fluid-editing)      # the commit you copy from
echo $QC > "${W:?}/copied_from" ; echo "copying from $QC"
for f in src/startup_quiz.tcl src/startup_quiz_bank.tcl \
         tests/headless/test_startup_quiz.tcl doc/claude/specs/startup_quiz.md; do
  git -C "${S:?}" show $QC:$f > $f
done
# this repository's src/ at that commit, for the comparisons of sections 4 and 6
rm -rf "${W:?}/ref" ; mkdir -p $W/ref
git -C "${S:?}" archive $QC src | tar -x -C $W/ref
```

Check:

```sh
QC=$(cat $W/copied_from)
for f in src/startup_quiz.tcl src/startup_quiz_bank.tcl \
         tests/headless/test_startup_quiz.tcl doc/claude/specs/startup_quiz.md; do
  [ -s $f ] && git -C $S show $QC:$f | cmp -s - $f && echo "copied  $f" || echo "!!      $f"
done
cmp -s $W/ref/src/startup_quiz.tcl src/startup_quiz.tcl && echo "ref ok" || echo "!!      $W/ref"
```

- `${S:?...}` stops a command when `S` is not set in the shell you typed it in. Without
  it, a fresh shell would write four empty files; the `[ -s ... ]` of the check catches a
  file that is empty for any other reason.
- The files come from one commit of the branch, not from the working files, so half-done
  work in this repository's checkout does not come along and all four files belong
  together. `$W/ref/src/` is the rest of `src/` at the same commit. Put the hash it
  printed into your commit message: it says which bank you took.
- Take the files as the branch has them when you read this. Do not apply commit
  `d36cb429e` (the one that introduced the quiz) for the bank: a later commit reworded
  questions, and more may follow. The `log` line above shows what moved each file.
- Do not edit the engine. Leave the suite as it is too; a proof helper of your own is the
  one reason to touch it later (section 7.4). The bank you will edit (sections 6 and 7).
  The spec you will correct in a few sentences once you have your own measurements
  (section 9).

### 4.2 `src/Makefile.in`, and the `./configure` it obliges

Inside the block `put /local/install_shares { ... }`, add a line of its own before the
closing `}`:

```
 startup_quiz.tcl startup_quiz_bank.tcl
```

Then, from the root of your tree:

```sh
./configure
/usr/bin/grep -cF 'startup_quiz.tcl' src/Makefile        # 2: an install line, an uninstall line
/usr/bin/grep -cF 'startup_quiz_bank.tcl' src/Makefile   # 2
```

- Rows: `F3` reads `src/Makefile.in` (one row per file); `F4` reads the generated
  `src/Makefile` (one row per file) and goes red when `./configure` was not re-run. `F4`
  prints an upper-case `SKIPPED:` line instead when there is no generated `src/Makefile`
  at all.
- The next `make` recompiles everything. That is expected: every object depends on
  `config.h` and on `src/Makefile` (`/usr/bin/grep -n '^$(OBJ):' src/Makefile` prints
  the rule), and `./configure` writes both again.
- What a skipped `./configure` costs. Run from the source tree nothing shows, because
  the share directory is `src/`. An installed copy then lacks both files and starts
  **without the quiz and without a crash**, because the `source` of the engine is caught
  (step 4.4). Measured in this repository on 2026-11-21 by moving the files out of
  `src/` and starting a session:
  - both files gone, a `--nogui --pipe -q` session: it started, defined no
    `startup_quiz::` proc, exited with code 0, and said once, on stderr and in its
    action log, a line that begins
    `NOTICE CHANNEL FAULT: src/startup_quiz.tcl failed to source`;
  - only the bank gone, a session with a display: `startup_quiz::launch_decision`
    answered `0 no-questions`, with one line in `startup_quiz::bank_errors` and none on
    stderr.

  Your `CLAUDE.md` describes a segfault (exit 139) for a file that is sourced but not
  installed; that is the older behaviour of issues 0423 and 0424. Since issue 0663 a
  failed BARE `source` is an announced abort with exit 1 (`xschem_startup_announce` in
  `src/xinit.c`, in both trees), and this source is not bare. Silent absence is the
  failure to look for.
- Nothing else needs the two names. One other install list exists, the Windows
  installer's manifest `XSchemWin/XSchemWix/Product.wxs`, and two Visual Studio project
  files beside it name `xschem.tcl`. They carry upstream's helpers and none of the
  files this fork added, in both trees:

  ```sh
  /usr/bin/grep -rho 'src[/\\][a-z_0-9]*\.tcl' XSchemWin | sort -u       # upstream's helpers
  /usr/bin/grep -rl -E 'ciw\.tcl|action_registry\.tcl|wave_viewer\.tcl' XSchemWin   # prints nothing
  /usr/bin/grep -c '\.tcl' doc/manpages/xschem.1.in CMakeLists.txt       # 0 for each file
  ```

  The quiz files stay out of that list like the fork's other helpers. The manual page
  and `CMakeLists.txt` name no Tcl file at all.

### A shortcut for steps 4.3 to 4.6, where it still applies

Steps 4.3 to 4.6 edit four files. On 2026-11-21 the loop below, typed in your tree at
`a464b7f6b`, said "applies" for those four and "by hand" for `src/Makefile.in` and
`tests/run_regression.tcl`, which is why steps 4.2 and 4.8 are edits by hand. This is
for the four wiring files only, never for the bank (step 4.1). Ask first, apply only
what answers "applies":

```sh
for f in src/xinit.c src/xschem.tcl src/actions.csv src/xschemrc \
         src/Makefile.in tests/run_regression.tcl; do
  git -C $S show d36cb429e -- $f | git apply --check - 2>/dev/null \
    && echo "applies  $f" || echo "by hand  $f"
done
# then, for each of the first four files that said "applies":
git -C $S show d36cb429e -- src/xinit.c | git apply -
```

Whether you applied a hunk or typed it, do each step's check below, and step 4.7 after
the last one. For a file that said "by hand", the text to type is in its step, complete.
Your tree moves: the day the hunk for `src/xschem.tcl` no longer applies, step 4.4 is
typed by hand, and it is written for that.

### 4.3 `Tcl_AppInit` in `src/xinit.c`: two edits, then build

**Edit 1, the mirror of `--pipe`.** Directly after the line

```c
 tclsetvar("cli_opt_nolog", cli_opt_nolog ? "1" : "0");
```

add

```c
 /* mirror --pipe: a session a script is driving through stdin, not a person. Read by
  * startup_quiz::automation (src/startup_quiz.tcl), which must NOT use no_recent_files for
  * this: that one is also set by --norecent, an option a person passes (the PDK launcher
  * has a checkbox for it). */
 tclsetvar("cli_opt_pipe", cli_opt_pipe ? "1" : "0");
```

The C variable `cli_opt_pipe` is already in your tree (`src/globals.c`, set in
`src/options.c`). Only the Tcl mirror is new.

**Edit 2, the launch hook.** After the block that ends the `-q` session,

```c
 if(cli_opt_quit) {
   char s[40];
   my_snprintf(s, S(s), "exit %d", exit_code);
   tcleval(s);
 }
```

and the empty line under it, above the comment `/*  END PROCESSING USER OPTIONS */`,
add this block and one empty line after it

```c
 /* Tip of the day, asked as a quiz (doc/claude/specs/startup_quiz.md). Asked HERE, after the
  * rc files, the --script file and --command have all run, so a `set startup_quiz 0` in any of
  * them decides for this launch; and after the -q exit above, so only a session that stays
  * open gets this far. The Tcl side decides the rest (a --pipe or --nolog launch, the saved
  * on/off choice) and only schedules the window, it never waits on it. Guarded because
  * xschem.tcl's `source` of startup_quiz.tcl is caught: without the file there is no proc. */
 if(has_x) {
   tcleval("if {[info commands ::startup_quiz::at_launch] ne {}} {catch {startup_quiz::at_launch}}");
 }
```

Then build:

```sh
timeout 540 make -C src
```

Check, and the rows:

```sh
/usr/bin/grep -cF 'tclsetvar("cli_opt_pipe"' src/xinit.c      # 1
/usr/bin/grep -cF 'startup_quiz::at_launch]' src/xinit.c      # 1
```

- **The mirror.** Without it the engine still loads, `startup_quiz::automation` answers
  0 for every session, and a `--pipe` session that stays open with a display is asked
  like a person. Measured in this repository on 2026-11-21, with the line taken out and
  the program rebuilt, by the commands of sections 5 and 9: rows `B11` and `B12` went
  red on either arm; `Z4` and `L5` as well on the display arm; and `Z5` too when the
  display arm ran with the regression's flags (the second capture of step 9.1, which
  passes `--logdir` where `run_suites.sh` passes `--nolog`), because the decision then
  goes as far as reading the bank.
- **The hook.** Rows `F5` and `F6` read `src/xinit.c` as text. `F5` takes the FIRST
  place in the file where the hook proc's name stands and wants it after the `--script`
  call, after the `--command` call and after the `-q` exit, in that order. `F6` wants
  the name followed by `]` exactly once. So do not name that proc in a comment anywhere
  above the hook. The comment of the mirror names `startup_quiz::automation`, and the
  hook's own comment names no proc: copy both as they are. Measured the same way as the
  mirror, with the three lines of the hook taken out: `F5` and `F6` went red on either
  arm, and on the display arm so did rows `L2` to `L12`, all but `L4`: the child
  sessions report that the hook never ran.
- **Why `--pipe` and not `no_recent_files`.** `--norecent` sets that flag too, and
  `--norecent` is an option a person passes. Rows `B14` and `L6` hold that a
  `--norecent` session is asked.

### 4.4 Four places in `src/xschem.tcl`

Each block below is the text as this repository has it, with the comment that stands
above it. Type the comment lines too: they tell the next reader of that file why the
`source` is caught and why each use is guarded, and step 4.7 compares them along with
the code.

**Place 1, the caught `source`.** After the block that sources `ciw.tcl` under a
`catch`, which ends with the line
`xschem::notify_degraded_once "src/ciw.tcl failed to source: $ciw_source_err"` and a
closing brace. Keep the empty line under that brace, add the block, and leave one empty
line after it:

```tcl
# Tip of the day, asked as a quiz (doc/claude/specs/startup_quiz.md). Proc
# definitions only at source time; the question bank beside it is read the first
# time a question is needed. CAUGHT, like ciw.tcl above and for the same reason:
# nothing else depends on this file, so a session without it is a session
# without the quiz, announced once, and not an aborted startup. Every later use
# of a startup_quiz:: proc in this file is behind an `info commands` test.
# Both files are also listed in src/Makefile.in's /local/install_shares.
if {[catch {source $XSCHEM_SHAREDIR/startup_quiz.tcl} startup_quiz_source_err]} {
  xschem::notify_degraded_once "src/startup_quiz.tcl failed to source: $startup_quiz_source_err"
}
```

Rows: `Z1` goes red when the engine's procs do not exist in the session. The suite then
stops on a Tcl error a few rows later, before it reaches band `F`, so `run_suites.sh`
prints `NORESULT` on both arms and no `FAIL` line at all (measured in this repository on
2026-11-21 with the three lines of the `if` taken out; the raw command of section 5
shows `Z1` and the error). `F1` matches the opening text of the `if` line: it is the
row that speaks when the engine was sourced by a line typed differently.

The source is caught on purpose: nothing else depends on the file. Every later use of a
`startup_quiz::` proc in `xschem.tcl` therefore sits behind an `info commands` test, and
so must any you add.

**Place 2, the Help menu.** In `proc build_widgets`, directly before the line
`$topwin.menubar.help add command -label "About XSCHEM" -command "about"`. The entry
above it, "Command palette", is one command on two lines (the second is
`-accelerator {Ctrl+Shift+P}`); the block goes after both, with its two leading blanks:

```tcl
  # Tip of the day, asked as a quiz (doc/claude/specs/startup_quiz.md). The
  # checkbutton is the same switch (::startup_quiz) as the dialog's "Don't show
  # anymore" box and the command palette's toggle.
  if {[info commands ::startup_quiz::show] ne {}} {
    $topwin.menubar.help add command -label "Tip of the day (quiz)..." -command {startup_quiz::show}
    $topwin.menubar.help add checkbutton -label "Tip of the day at startup" -variable startup_quiz \
       -selectcolor $selectcolor -command {startup_quiz::pref_changed}
  }
```

Rows: `F12` and `F13` read the two `add` lines as text, on either arm; `D25` to `D28`
drive the live menu on the display arm. Row `A15` goes red with them for the bank's
`quiz-switch` question, whose proof reads the checkbutton line. `$selectcolor` is set
earlier in the same proc.

**Place 3, the two defaults.** Among the top-level defaults, directly after the line
`set_ne raw_history_max 20`:

```tcl
# Tip of the day, asked as a quiz at launch (doc/claude/specs/startup_quiz.md).
# startup_quiz: 1 = ask one question when an interactive session starts, 0 = do
# not. The same switch as the dialog's "Don't show anymore" box, Help > Tip of
# the day at startup and the command palette's toggle, each of which saves it to
# USER_CONF_DIR/startup_quiz -- read back by startup_quiz::load_conf below, AFTER
# an xschemrc line, so the last choice made in the program wins over the rc. Read
# when the launch has finished, so a --script rc or `--command {set startup_quiz
# 0}` decides for that launch.
# startup_quiz_done: the ids already answered (USER_CONF_DIR/startup_quiz_done).
set_ne startup_quiz 1
set_ne startup_quiz_done {}
```

Rows: `Z6` wants the line `set_ne startup_quiz 1` exactly as written, starting in the
first column. Rows `A13` and `A15` (for `quiz-switch`) read the same default through
`P_default` and go red with it. No row reads the last line: the engine tolerates the
variable being unset, and the line is there so that it always exists.

**Place 4, reading the saved files.** Near the end of the file, after the line
`wviewer::rawhist_load` and before `set_ne XSCHEM_START_WINDOW {}`:

```tcl
# Tip-of-the-day quiz: the saved on/off choice and the answered list
# (USER_CONF_DIR/startup_quiz, USER_CONF_DIR/startup_quiz_done). Guarded because
# the `source` of startup_quiz.tcl is caught: without the file there is no proc.
if {[info commands ::startup_quiz::load_conf] ne {}} { startup_quiz::load_conf }
```

Rows: `L8` and `L12`, and **only on the display arm**. The counted arm cannot see this
line: rows `E4` and `E20` call `startup_quiz::load_conf` themselves, so they test the
proc and not this call. If the line stands above place 1 in the file, the guard is false
when it runs and the saved choice is never read, with no error.

### 4.5 Two rows in `src/actions.csv`

After the row that starts `help.keybindings_cheatsheet,` and before the row that starts
`help.about_xschem,`:

```
help.tip_of_the_day,command,help,Tip of the day (quiz)...,,startup_quiz::show,,,Ask one quiz question about what this XSCHEM can do,
help.tip_of_the_day_startup,command,help,Toggle tip of the day at startup,,startup_quiz::toggle,,,Turn the tip-of-the-day quiz asked at launch on or off (saved for later sessions),
```

Rows: `F7` to `F11` on either arm, with `A15` for `quiz-switch`; `D29` and `D30` on the
display arm. The label `Toggle tip of the day at startup` stands word for word in three
places that rows `F9` and `F11` compare: this row, `startup_quiz::hint_text` and
`startup_quiz::pref_notice`. Reword one and you reword all three.

Other suites read the action table too, and two more rows could redden one that pins
its contents. That was measured in this repository, and before the edit two commands
say whether the measurement holds for your tree:

```sh
QC=$(cat $W/copied_from)
diff $W/ref/src/actions.csv src/actions.csv
git -C $S grep -l -E 'actions\.csv|load_action_table' $QC -- 'tests/*.tcl' 'tests/*.sh' |
sed "s/^$QC://" | while read f; do
  case $f in tests/run_regression.tcl|tests/headless/test_startup_quiz.tcl) continue ;; esac
  if [ ! -e $f ]; then echo "ABSENT  $f"
  elif git -C $S show $QC:$f | cmp -s - $f; then echo "same    $f"; else echo "DIFFERS $f"; fi
done
```

The loop walks the test scripts of this repository that name the action table, at the
commit you copied from, and compares each with yours. On 2026-11-21 the `diff` printed
these two rows and nothing else, and every line of the loop said `same`: the suites that
read the table were the same files in both trees. The same day each suite the loop
names was run in this repository through `run_suites.sh`, on both arms, once with the
two rows in the table and once with them taken out. Every suite gave the same verdict
line and the same failing rows both times, so the two rows change none of them. (Some
of them are red or print `NORESULT` on one arm either way; most are in no regression
list, and none of that is the quiz's.) A line that says `DIFFERS` or `ABSENT` when you
run the loop names a suite to run in your tree before and after the edit.

### 4.6 The commented block in `src/xschemrc`

After the line `# set wviewer_text_size 14` and its blank line, before the line
`#### redefine some variables to emulate Cadence UI / bindkeys`:

```
###########################################################################
#### TIP OF THE DAY
###########################################################################
#### Ask one quiz question about XSCHEM when an interactive session starts.
#### Default: enabled (1). This is the same switch as the quiz window's
#### "Don't show anymore" box, Help > Tip of the day at startup and the
#### command palette's "Toggle tip of the day at startup"; a choice made
#### there is saved in ~/.xschem/startup_quiz and wins over this line.
# set startup_quiz 0

```

Row: `F14` wants the line `# set startup_quiz 0` exactly once in the file.

### 4.7 The whole wiring against this repository

```sh
for f in src/xinit.c src/xschem.tcl src/actions.csv src/xschemrc src/Makefile.in; do
  if diff <(/usr/bin/grep -E 'startup_quiz|tclsetvar\("cli_opt_pipe"' $W/ref/$f) \
          <(/usr/bin/grep -E 'startup_quiz|tclsetvar\("cli_opt_pipe"' $f)
  then echo "same quiz lines       $f"; else echo "DIFFERENT quiz lines  $f"; fi
done
```

A file that says `same quiz lines` has the lines that name the quiz as this repository
had them at the commit you copied from, in the same order. For a file that says
`DIFFERENT` the loop prints the lines above the verdict: `<` is this repository's, `>`
is yours. Read them:

- **a comment line of `src/xschem.tcl` that you left out or worded yourself.** No row
  reads a comment of that file, so the wiring works. Bring the comment in line, or keep
  yours knowingly;
- **any other line of a file you typed by hand.** A step was typed differently from its
  block. Correct it;
- **a file whose hunk of `d36cb429e` you applied and did not touch.** This repository
  changed its wiring after that commit. Follow the `<` lines.

The order of the places inside each file is checked by rows, not by this loop: `F5` for
the hook, `L8` and `L12` for the saved files.

### 4.8 The two registrations (not now: they are step 9.2)

This step is described here because it is wiring. You make it at step 9.2, after the
bank is true for your tree and both arms were captured (step 9.1).

In `tests/run_regression.tcl`, add the entry to BOTH lists, `set hcases [list ...]` and
`set dcases [list ...]`, each time as a line of its own before the list's last line (the
one that ends in `]`):

```tcl
                  "headless/test_startup_quiz" \
```

and write one `##` note after each list saying what that arm runs. Write the notes from
your own capture (step 9.1). Do not copy this repository's notes: one of them says that
both arms were captured and scored before the entries went in, and that sentence is only
true for the tree that did it.

Check:

```sh
/usr/bin/grep -c '"headless/test_startup_quiz"' tests/run_regression.tcl     # 2
```

Both lists, because the two arms run different rows (section 5), and a suite that is in
the counted list alone would gate none of the dialog.

## 5. Run it

One arm at a time, on a private display, never beside another suite run or a full
regression:

```sh
env -u DISPLAY AUDIT_DISPLAY=private tests/headless/run_suites.sh --nogui test_startup_quiz
env -u DISPLAY AUDIT_DISPLAY=private tests/headless/run_suites.sh test_startup_quiz
```

A green arm prints one line that starts with `PASS` and ends in
`RESULT: ALL PASS (<n> checks)`, then `RESULT: 1/1 runs passed`. A red arm prints `FAIL`
and under it every failing row. `run_suites.sh` gives the run a throwaway HOME and a
private display, and stops it after `SUITE_TIMEOUT` seconds. Two other lines are
results too:

- `NORESULT` means the suite stopped on a Tcl error before its last line, and no row is
  listed. The usual cause is that the engine was not sourced (place 1 of step 4.4). The
  raw command below, without its `grep`, ends in the error;
- `TIMEOUT`: read which arm, and raise the bound by name
  (`SUITE_TIMEOUT=600 env -u DISPLAY ...`) only after you know the suite was still
  working.

What each arm runs:

- **The first command is the counted arm** (`--nogui`). It runs bands `Z B V C N O G E
  A F` and row `L1`: the decision layer, the bank's rules, EVERY proof, the wiring.
- **The second is the display arm.** It adds `L2` to `L14`, which start child XSCHEM
  processes, one per command line, each with a HOME of its own, and measure which
  command lines are asked; and `D1` to `D43`, the dialog driven through its widgets,
  including every question of the bank shown, answered and measured against the screen.
- On the counted arm the suite prints an upper-case `SKIPPED:` line for the rows of band
  `L` that need a display and another for band `D`. They are not failures.

To see every row, or the full text of a failure, run the same session yourself.
`gated_xschem.sh` has no time bound of its own, so the command carries one:

```sh
timeout 600 env -u DISPLAY AUDIT_DISPLAY=private tests/headless/gated_xschem.sh --pipe -q --nolog --nogui \
    --script tests/headless/test_startup_quiz.tcl < /dev/null 2>&1 \
  | /usr/bin/grep -E '^(FAIL|SKIPPED|RESULT|OVERALL)'
```

(drop `--nogui` for the display arm; drop the `grep` for every row).

What a red row asks of you depends on its band:

- bands `F` and `Z`, and rows `B11` and `B12`: the wiring. Section 4 names rows beside
  the step they check; look the row up there first. Row `A15` for `quiz-switch`, the
  bank's question about the quiz's own switch, is wiring as well, and so is `A13`
  beside a red `Z6`;
- band `A` otherwise: the bank. Section 6;
- band `L` or `D`, with the wiring rows green: your tree does something at startup, or
  in its windows, that this repository does not. The row's name says what it measured
  and the failure line what it got. Find what your tree does differently, and report
  it. Do not weaken the row and do not edit the engine to get past it: section 4.1 keeps
  both as they are so that a difference between the trees stays visible.

**Do not type `./src/xschem --script tests/headless/test_startup_quiz.tcl`.** The suite's
own session and the child sessions of band `L` then open their windows on the display
your shell has, which here is the user's real screen. The session has no `--pipe`, so
rows `B11` and `B12` fail for a reason that is not your wiring. And it runs with the
real HOME, so the user's own key bindings are in the table the proofs read (section 7).

For scale: on 2026-11-21 the two `run_suites.sh` commands at the head of this section,
typed at the root of a built clone of this repository with the bank as commit
`7c77f3594` left it, printed `RESULT: ALL PASS (256 checks)` and
`RESULT: ALL PASS (316 checks)`. Those figures are not a baseline: row `A15` runs once
per question, so both move with the bank. Read your own from your own output.

## 6. Make the bank true for your tree

This is the section the document exists for. Every question is a statement about the
program, shown to a user. The bank was written against this repository. Your tree has
features this one lacks, and will lose or rename things this one keeps.

### 6.1 A red proof row names a question that is false in your tree

Row `A15` runs once per question and prints the id, the kind and the proof:

```
FAIL: A15 <id> (<kind>): its proof holds -- <proof> -> {0} (exp {1}) : FAIL
```

`{RAISED(...)}` in place of `{0}` means the proof could not be evaluated, for instance
because it calls a proc your tree does not have. That is a failure too.

Find the clause that is false by reading. A proof is a chain of calls joined by `&&`.
For a call that reads a file, ask the file: `[P_has src/xschem.tcl {some text}]` is
`/usr/bin/grep -cF 'some text' src/xschem.tcl`. For a call that asks the running program
(`P_proc`, `P_body`, a proc called by name), read that proc in your source.

Then one of these, and nothing else:

| what you find | what you do |
|---|---|
| the feature is there, but the label, key, menu or proc differs | Rewrite the QUESTION (`q`, `a`, `why`) so that it says what your tree does. Then make the proof name the new thing. |
| the feature is not in your tree | Delete the entry. Its id is never used again for another question. If the feature reaches your tree later, the same question comes back under the same id. |
| an `upcoming` question is red | The feature was built in your tree. See 6.3. |
| the proof raised | Read what the call was for, then one of the three above. |

The second line of the table is also what a red row means for a question this
repository added after the date of this file, about a feature your tree has not received
yet.

**Do not weaken a proof to make the row green.** A proof edited until it passes, under a
text that still says the old thing, puts a false statement in front of the user with a
green suite behind it. The proof changes only as a consequence of the question changing.

Deleting entries can break a rule of the bank (enough questions, enough of each kind,
enough that apply in a plain launch: section 7.3). The suite says so in rows `A3` to
`A11` and `A19`. Add questions of your own rather than loosening a rule.

### 6.2 What NO row checks

A green band `A` says that every proof holds. It does not say that every sentence shown
to the user is true. Three things are checked by nothing, in either tree:

1. **The wrong options of every multiple-choice question.** A proof speaks for the right
   answer. Nothing re-checks that each wrong option is still wrong.
2. **Any clause of `why` that the proof does not name.** `why` often tells more than the
   proof asserts, such as what the other keys do or where else the command is found.
3. **Whether a proof is the right proof.** Row `A17` only checks that a proof calls
   something. The standard is: **the proof must fail if the feature were removed or
   renamed.**

So read the whole bank once against your tree, by hand. This is how.

First list what your tree has that this repository lacks. These print it (`$W/ref/src`
is this repository's `src/` at the commit you copied from, step 4.1):

```sh
R=$W/ref/src
# 1. Tcl files only your tree has
diff <(cd $R && ls *.tcl) <(cd src && ls *.tcl) | /usr/bin/grep '^>'
# 2. the Tcl files both trees have, most different first
for f in $(cd $R && ls *.tcl); do
  [ -e src/$f ] || continue
  n=$(diff $R/$f src/$f | /usr/bin/grep -c '^[<>]')
  p=$(diff <(/usr/bin/grep -o -E '^proc [^ ]+' $R/$f | sort -u) \
           <(/usr/bin/grep -o -E '^proc [^ ]+' src/$f | sort -u) | /usr/bin/grep -c '^>')
  [ "$n" -gt 0 ] && printf '%6d lines differ, %3d procs only yours  %s\n' $n $p $f
done | sort -rn
# 3. the procs only your tree has, for one file of that list (repeat per file)
f=ase_window.tcl
diff <(/usr/bin/grep -o -E '^proc [^ ]+' $R/$f | sort -u) \
     <(/usr/bin/grep -o -E '^proc [^ ]+' src/$f | sort -u) | /usr/bin/grep '^>'
# 4. menu and button labels only your tree has
diff <(/usr/bin/grep -ho -E -- '-label +("[^"]*"|\{[^}]*\}|\[[^]]*\])' $R/*.tcl | sort -u) \
     <(/usr/bin/grep -ho -E -- '-label +("[^"]*"|\{[^}]*\}|\[[^]]*\])' src/*.tcl | sort -u) | /usr/bin/grep '^>'
# 5. palette rows, key bindings, xschem subcommands
diff $R/actions.csv src/actions.csv
diff $R/keybindings.csv src/keybindings.csv
diff <(/usr/bin/grep -o 'strcmp(argv\[1\], "[a-z_0-9]*")' $R/scheduler.c | sort -u) \
     <(/usr/bin/grep -o 'strcmp(argv\[1\], "[a-z_0-9]*")' src/scheduler.c | sort -u)
```

Then, with that list beside you, go through the bank entry by entry:

- **Each wrong option of each `mc` entry.** Ask: in MY tree, does this option also do
  the thing the question asks for? If it does, the question has two right answers and a
  user who picks the second is told "Not quite". Replace the option. A wrong option is
  usually one of four shapes: a real command that does something else; the right label
  under the wrong menu; an invented name; a common misconception. For an invented name,
  check that your tree did not since build something of that name.
- **Each sentence of each `why`.** Where it says more than the proof ("Ctrl+P places an
  input port", "also on the Symbol menu"), check that sentence against your source.
- **Each proof against the standard.** Imagine the feature removed from your tree. Would
  this proof go false? A proof that only shows that some file contains a common word
  would not.
- **An `mc` question of kind `upcoming`** ("which of these is not built yet?"): every
  wrong option must be something that works in your tree, because a wrong pick is told
  "Not quite: that one already works."

Where to look first is the top of what command 2 prints. On 2026-11-21 (this repository
at `7c77f3594`, your tree at `a464b7f6b`) it began:

```
  3640 lines differ,  23 procs only yours  ase.tcl
  1233 lines differ,  31 procs only yours  wave_viewer.tcl
  1152 lines differ,  38 procs only yours  ase_window.tcl
   441 lines differ,  15 procs only yours  calculator.tcl
```

So ASE-L is where the trees differ most, then the waveform viewer, then the Calculator.
`ASE-L`, `Waveform viewer` and `Calculator` are also three of the topics that hold as
many questions as row `A8` allows (section 7.3), and the proofs of `direct-plot` and
`calc-pick` read procs of `src/ase_window.tcl`. What the five commands showed only in
your tree that day:

- ASE-L, in files of its own (command 1): `ase_integ_*.tcl` (ASE-Integrator),
  `ase_mc.tcl` and `ase_mc_bridge.tcl` (Monte Carlo), `ase_stb*.tcl` (the stb analysis);
- ASE-L, in the files both trees have (command 3): `ase::preflight_*`, `ase::wcpoint_*`
  and `ase::analysis_pin` with its siblings in `src/ase.tcl`; `ase::ui::hist_*`,
  `ase::ui::repair_*`, `ase::ui::wcpoint_*` and `ase::ui::vc_*` in `src/ase_window.tcl`;
- the waveform viewer: histogram plots (`wviewer::hist_*`, `wviewer::plan_hist_plot`)
  and where a trace moved by hand lands (`wviewer::hand_plan`,
  `wviewer::hand_move_apply`);
- the Calculator: variables (`calc::var_*`) and `calc::dcsweep`;
- `layout_xl.tcl`, with Tools > "Launch xlay";
- menus (command 4): a cascade labelled by `ase::stb::ui::lbl_menu`, which returns
  `Direct Plot stb`, added to the ASE-L window's Results menu directly under the
  "Direct Plot" entry that the `direct-plot` question describes; Tools > the entry
  labelled by `annot_lbl_launch_integ`; and the entry labelled by
  `ase::ui::lbl_launch_integ` on the ASE-L window's Launch menu;
- one `xschem` subcommand (command 5): `hilight_colors`. The palette rows differed by
  the two rows of step 4.5 and nothing else, and the key bindings not at all.

Those are the features that have no question yet, and the places where a wrong option
or an unproved clause of `why` can be false in your tree while every row is green.
Nobody has read the bank against them. That reading is this section, and it is yours.

### 6.3 `upcoming` questions

An `upcoming` question says that something is planned and not built, and its proof says
the thing is still absent. Two duties:

- **Once, now:** for each one, find where YOUR tree writes the plan down (search
  `doc/claude/specs` and `doc/claude/suggestions` for the feature's words). In this
  repository four of them (Combine Strips, eyeDiagram, the marker re-snap, voice
  control) are written down in `$S/doc/claude/specs/wish_list.txt`,
  `$S/doc/claude/specs/calculator.md`, `$S/doc/claude/specs/graph_markers.md` and
  `$S/doc/claude/suggestions/voice_control_atomic_plan.md`
  (`/usr/bin/grep -il 'combine strips' $S/doc/claude/specs/wish_list.txt` prints the
  file's name, and so do `eyediagram` and `re-snap` in the next two). A feature your
  tree does not plan is not `upcoming` there: it is a `myth`, which gets no "Stay
  tuned", or it goes.
  Also read each proof of absence for what it guesses. Such a proof looks for names the
  feature would probably use, so a feature built under another name leaves a false
  question green, and an innocent comment that contains the word turns a true question
  red.
- **The day the feature is built:** the row goes red. For a true/false entry set
  `kind shipped` and `ok true`, rewrite `why` to teach how the thing works, and turn the
  proof round so that it says the thing is there. For an `mc` entry the option that was
  "not built yet" now works, so the question needs another such option or becomes a
  `howto`.

The ids of the `upcoming` entries are printed by the reading aid of section 7.3.

## 7. Adding your tree's own questions

### 7.1 One entry, field by field

```tcl
startup_quiz::add <id> {
  type   tf | mc
  kind   shipped | upcoming | myth        (tf)      howto | upcoming        (mc)
  topic  {...}
  q      {...}
  a      {{...} {...} {...} {...}}         (mc only)
  ok     true | false                      (tf)      <index, from 0>         (mc)
  last   <index>                           (mc, optional)
  why    {...}
  proof  {...}
  only   {...}                             (optional)
}
```

What `startup_quiz::validate` enforces. An entry that breaks a rule is left out, named in
`startup_quiz::bank_errors`, and row `A1` goes red with the reason.

| field | rule |
|---|---|
| id | lower-case letters, digits, `-` and `_`, starting with a letter or digit; used once in the file |
| body | a list of key and value pairs; only the ten keys above; `type kind topic q ok why proof` are required |
| `topic`, `q`, `why` | not empty; runs of white space become one blank, so text can be wrapped in the file |
| `tf` | no `a`, no `last`; `kind` is `shipped`, `upcoming` or `myth`; `ok` is `true` or `false`; `shipped` goes with `true`, the other two with `false` |
| `mc` | `a` holds 3 to 5 options, none empty, none twice; `kind` is `howto` or `upcoming`; `ok` is the index of the right option; `last`, if given, is the index of an option that stays at the bottom |
| `proof` | not empty. Stored as written, never evaluated by the engine |
| `only` | optional. An expression evaluated at global scope when a question is chosen; one that raises or is not a boolean means "does not apply", silently |

The id is what the answered list remembers. Choose ids that name your feature, and never
reuse the id of a question you removed for a different question.

### 7.2 Kinds, and the line each one produces

| type | kind | answered right | answered wrong |
|---|---|---|---|
| `tf` | `shipped` | `You nailed it!` | `Not quite: this one is true.` |
| `tf` | `myth` | `You nailed it!` | `Not quite: this one is false.` |
| `tf` | `upcoming` | `You nailed it. This is an upcoming feature! Stay tuned!` | `Not yet! This is an upcoming feature. Stay tuned!` |
| `mc` | `howto` | `You nailed it!` | `Not quite.` |
| `mc` | `upcoming` | `You nailed it. This is an upcoming feature! Stay tuned!` | `Not quite: that one already works.` |

The lines come from `startup_quiz::grade`; rows `G1` to `G10` hold each of them.

### 7.3 The rules the suite holds the bank to

The thresholds are in the names of the rows. Print them from your copy of the suite:

```sh
/usr/bin/grep -o -E '^check(_true)? "A(3|5|6|7|8|11|19) [^"]*' tests/headless/test_startup_quiz.tcl
/usr/bin/grep -n 'set budget' tests/headless/test_startup_quiz.tcl
```

| row | rule |
|---|---|
| `A1`, `A2` | the file loads with nothing refused, and every `startup_quiz::add` at the start of a line became a question |
| `A3` | a minimum number of questions |
| `A4` | the engine and the bank are plain ASCII |
| `A5`, `A6` | a minimum of each type, and of each of the three true/false kinds |
| `A7`, `A8` | a minimum number of topics, and a cap on the questions under one topic |
| `A9` | every question, explanation, topic and option is inside its length budget (the `set budget` line) |
| `A10` | no question text twice |
| `A11` | a minimum share of true/false answers is "false" |
| `A17` | every proof calls something |
| `A18` | every `only` evaluates to a clean yes or no in a plain launch |
| `A19`, `A20` | a minimum number of questions apply in a plain launch, with no profile and no PDK |
| `D41` to `D43` | display arm: every question is shown and answered, and none makes the window taller or wider than the row allows |

To read where the bank stands against those rules without starting XSCHEM, save this
reading aid in the scratch directory and run it. It loads the bank through the engine's own
loader and takes the budgets out of the suite's text.

```sh
cat > $W/bankstat.tcl <<'EOF'
# usage: tclsh bankstat.tcl <repository root>
# Reads the bank through the engine's own loader. Starts no xschem.
set root [file normalize [lindex $argv 0]]
source [file join $root src startup_quiz.tcl]
set n [startup_quiz::load_bank [file join $root src startup_quiz_bank.tcl]]
puts "questions: $n   refused: [llength $::startup_quiz::bank_errors]"
foreach e $::startup_quiz::bank_errors { puts "  REFUSED $e" }
# the length budgets, read out of the suite that enforces them
set fd [open [file join $root tests headless test_startup_quiz.tcl] r]
set suite [read $fd] ; close $fd
if {![regexp {set budget \{([^\}]*)\}} $suite -> budget]} { error "no budget line in the suite" }
puts "length budgets, in characters: $budget"
set kinds [dict create] ; set topics [dict create]
set cond {} ; set upcoming {} ; set tight {} ; set tf 0 ; set tffalse 0
foreach id $::startup_quiz::order {
  set e [startup_quiz::get $id]
  set type [dict get $e type]
  dict incr kinds "$type/[dict get $e kind]"
  dict incr topics [dict get $e topic]
  if {[dict get $e only] ne {}} { lappend cond $id }
  if {[dict get $e kind] eq {upcoming}} { lappend upcoming $id }
  if {$type eq {tf}} { incr tf ; if {[dict get $e ok] == 1} { incr tffalse } }
  set len [dict create q [string length [dict get $e q]] why [string length [dict get $e why]] \
                       topic [string length [dict get $e topic]] opt 0]
  foreach o [dict get $e a] {
    if {[string length $o] > [dict get $len opt]} { dict set len opt [string length $o] }
  }
  dict for {k v} $len {
    set b [dict get $budget $k]
    if {$v * 10 >= $b * 9} { lappend tight "$id.$k: $v of $b" }
  }
}
puts "by type/kind:"
foreach k [lsort [dict keys $kinds]] { puts [format "  %-12s %d" $k [dict get $kinds $k]] }
puts "true/false answered false: $tffalse of $tf"
puts "topics: [dict size $topics]"
foreach t [lsort [dict keys $topics]] { puts [format "  %-22s %d" $t [dict get $topics $t]] }
puts "upcoming: $upcoming"
puts "conditional (they carry `only`): $cond"
puts "texts that use nine tenths or more of their budget:"
foreach l $tight { puts "  $l" }
EOF
tclsh $W/bankstat.tcl .          # your tree; "tclsh $W/bankstat.tcl $S" reads this repository's
```

What it answered for this repository on 2026-11-21 (commit `7c77f3594`), in part:

```
questions: 82   refused: 0
topics: 26
upcoming: log-undo fly-freeze ase-xyce wv-divider wv-strips wv-resnap calc-table calc-memories calc-eye voice
conditional (they carry `only`): cad-hilight cad-annot cad-rdw cad-find sky-pin-voltages sky-res-series
texts that use nine tenths or more of their budget:
  direct-plot.why: 414 of 420
  calc-pick.why: 394 of 420
```

Two things to take from that output when you read your own:

- **Topics at the cap.** That day `ASE-L`, `CIW and action log`, `Calculator` and
  `Waveform viewer` each held as many questions as row `A8` allows. One more question
  under any of them reddens the row. Questions about your simulation features need topic
  names of their own, inside the topic's length budget.
- **Texts near their budget.** The explanation of `direct-plot` had a few characters
  left. Rewording it for your tree can redden row `A9`. Check the last lines of the
  output after every edit of a text.

The aid is for reading. The fence is the suite.

### 7.4 Which helper proves which kind of claim

| the claim | the proof | example in the bank |
|---|---|---|
| a menu entry with this label is on this menu | `P_has` on enough of the `add` line to tie the label to the menu and the command | `calc-open` |
| a label that a proc returns | call the proc and compare, plus `P_has` on the line that uses it | `ase-open` |
| the palette can run this command | `P_palette <action id>`; its exact label: `P_label <action id> {...}` | `palette-scope`, `pin-stubs` |
| a key of the binding table does this | `P_bind key <keysym number> <mods> <context> <action id>` | `rotate-in-place` |
| a key bound in Tcl (the viewer, the Cadence profile) | `P_has` or `P_hasre` on the `bind` line | `wv-undo`, `cad-annot` |
| a variable's shipped default | `P_default <variable> <value>` | `fluid-grab` |
| `xschem <name>` is a subcommand | `P_sub <name>` | `sel-same-net` |
| a command-line option exists | `P_has src/options.c {...}` on its `strcmp` | `rc-norecent` |
| how a proc behaves | `P_body` or `P_bodyre` on the text that makes it so; `P_proc` only says the proc exists | `keys-unbind` |
| one thing happens before another at startup | `P_order src/xinit.c {first} {second}` | `rc-script` |
| a thing is absent (an `upcoming` question, an invented wrong option) | `![P_has ...]`, or `![regexp ... [P_text <file>]]` | `tabs-off`, `wv-strips` |

Any Tcl command that exists in a `--nogui` session may be used beside the helpers. If
you need a helper the suite lacks, add it beside the others in the suite and give it one
anchor in row `A12` (something that is not there) and one in row `A13` (something that
is), so that it is known to answer both ways. Four limits:

- **`P_bind` proves only keys that are rows of the binding table.** Find the row first:
  `/usr/bin/grep -n '<action id>' src/keybindings.csv`. Many keys are not in that table.
  They still live in the key switch (`switch (key)`) of `handle_key_press()` in
  `src/callback.c`, the function that `callback()` hands a key press to. The bank proves
  some of those by the accelerator TEXT of a menu entry or of an `actions.csv` row
  (`wire-label`, `make-editable`), although the bank's own `keys-menu-text` question says
  that text binds nothing. For such a key the honest proof is a literal of its arm in
  `handle_key_press()`; an example follows this list.
- **`P_bind` reads the LIVE table**, which is the shipped `src/keybindings.csv` plus the
  user's own `keybindings.csv` in the configuration directory, loaded when the session
  starts and before the suite points that directory at its scratch. Under the throwaway
  HOME of `run_suites.sh` there is none. Under the real HOME a remap by the user can
  redden a proof for a reason that is not the bank.
- **A proof is evaluated in a plain launch whatever `only` says.** Row `A15` evaluates
  every question's proof, also of a question that applies only in a PDK workarea. So such
  a proof has to hold from file text (as the sky130 questions do, with `P_has` on the
  symbol file).
- **Text inside a proof must have balanced braces**, and the whole bank is plain ASCII.

The example for the first limit. This clause says that Ctrl+E goes back up one level,
from the arm of that key in `handle_key_press()`:

```tcl
[P_hasre src/callback.c {case 'e':[^:]*?rstate == ControlMask\)[^;]*;\s*go_back\(1\);}]
```

`P_hasre` is a `regexp` over the file's text, so a pattern can be tried without starting
XSCHEM:

```sh
tclsh <<'EOF'
set fd [open src/callback.c r] ; set t [read $fd] ; close $fd
puts [regexp -- {case 'e':[^:]*?rstate == ControlMask\)[^;]*;\s*go_back\(1\);} $t]
EOF
```

On 2026-11-21 that printed 1 in both trees, and 0 with `'e'` changed to `'x'` or
`go_back` changed to `go_forward` in the pattern: the proof fails when the key or the
function is another one, which is the standard of section 6.2.

A control that costs nothing: this repository is a tree WITHOUT your feature. A proof
for a feature only your tree has must not hold here. Check its file-reading clauses with
`/usr/bin/grep -cF` against `$S`. If every clause also holds in this repository, the
proof does not name your feature.

### 7.5 Wrong options, and `only`

- A wrong option **must not be a second way of doing the thing**. Search your menus,
  `src/actions.csv` and the key tables for other routes to the same command before you
  write the options.
- Give a wrong option a reason to be there: a real command that does something else
  (say in `why` what it does, and prove that too where you can, as `palette-open` does
  for Alt+F5); the right label under the wrong menu; an invented name whose absence the
  proof asserts (`tabs-off`, `sel-look`); a common misconception.
- The order of the options in the file does not matter: they are shuffled on screen,
  except one named by `last` (an "Any of these"), which stays at the bottom.
- **`only`** is for anything tied to a profile or a PDK: a key that exists only in the
  Cadence profile, a symbol of one workarea. The bank's conditions on 2026-11-21 were
  `[namespace exists ::cadence]` and `[llength [info commands ::sky130_fet_limits]] > 0`
  (`/usr/bin/grep -n -E '^\s*only\s+\{' src/startup_quiz_bank.tcl` prints each use).
  A question whose condition is false in a plain launch does not count toward row
  `A19`, so keep enough questions without one.

### 7.6 After each question you add

```sh
tclsh $W/bankstat.tcl .
env -u DISPLAY AUDIT_DISPLAY=private tests/headless/run_suites.sh --nogui test_startup_quiz
env -u DISPLAY AUDIT_DISPLAY=private tests/headless/run_suites.sh test_startup_quiz
```

The display arm is what shows that the new texts fit the window (`D43`).

## 8. The trap for a whole tree: a startup window in other suites' launches

Read this section now. You run its census at step 9.5, in the gate clone, after the
suite is registered and committed; the steps of section 9 say when.

The quiz opens a window in every session that looks like a person's. A test suite that
starts XSCHEM in a way that looks like a person's gets one too: a toplevel
`.startup_quiz`, a moment after startup. It takes no grab and nothing waits on it, so it
cannot hang a suite. It does change the list of windows, the stacking, the focus and any
screenshot of that launch.

What keeps a launch from being asked:

| the launch | why it is not asked | row |
|---|---|---|
| `--nogui`, or no display at all | `Tcl_AppInit` calls the hook only when there is a display | `L1` |
| `-q` | the session exits before the hook | `L13` |
| `--pipe` | decision `0 automation` | `L5` |
| `--nolog` | decision `0 nolog` | `L7` |
| `--command {set startup_quiz 0}` | the hook reads the switch as off: decision `0 off` | `L10` |
| a `--script` file that ends in `exit` | the process leaves before the hook | none; read in `Tcl_AppInit` |
| a saved "off" in that launch's HOME | decision `0 off` | `L8` |

What does NOT keep it away:

- **The throwaway test HOME.** It has no saved switch, so the default there is ON.
- `--norecent` (`L6`), and `--script` together with `--logdir` (`L2`: every child of
  band `L` that has no `--nolog` is started with both).
- `--rcfile`. Read, not measured: `startup_quiz::launch_decision` looks at the display,
  `--pipe`, `--nolog`, the switch and the bank, and at nothing else. An rc file keeps
  the quiz away only by setting the switch.

The drivers pass the flags: the regression's counted arm starts each suite with
`--nogui --pipe -q --script`, its display arm with `--pipe -q --logdir <dir> --script`,
and `run_suites.sh` with `--pipe -q --nolog` or `--pipe -q --logdir`:

```sh
/usr/bin/grep -n -E 'xschem_cmd .*--script' tests/run_regression.tcl
/usr/bin/grep -n -E 'XSCHEM" .*--script' tests/headless/run_suites.sh
```

So a suite's own session is never asked. The launches to worry about are the CHILD
processes a suite starts itself, and your tree has more suites than this one
(`ls tests/headless/test_*.tcl | wc -l`, in each tree).

### How to run the census

**It is a required step, and nothing replaces it.** It needs a tree where the wiring is
built and the suite is registered, and it runs one full regression: that is the gate
clone at step 9.5.

1. In the gate clone's `src/startup_quiz.tcl`, proc `startup_quiz::at_launch`, add these
   lines directly after the line `set launch $d`. They are temporary and are never
   committed.

   ```tcl
     catch {
       set c {}
       catch { set fd [open /proc/[pid]/cmdline r] ; set c [string map [list \0 { }] [read $fd]] ; close $fd }
       set fd [open /tmp/quiz_census.txt a] ; puts $fd [list [pid] $d $c] ; close $fd
     }
   ```

2. `rm -f /tmp/quiz_census.txt`, then run one full regression in that clone (step 9.7
   has the command and says how to know that it finished). The file is outside every
   test HOME, so it survives the run.

3. Read it:

   ```sh
   /usr/bin/grep -c '_startup_quiz_' /tmp/quiz_census.txt     # must NOT be 0
   /usr/bin/grep -F '{1 show}' /tmp/quiz_census.txt | /usr/bin/grep -v '_startup_quiz_'
   ```

   Each line is one launch that reached the hook: process id, decision, command line.
   The quiz suite's own child launches carry `_startup_quiz_` in the path of their
   `--script` file. The first command proves the census worked at all: with the suite
   registered, its display-arm children must be in the file. **The second command must
   print nothing.** Every line it prints is a launch of another suite that was asked a
   question.

4. Take the lines out again, in the gate clone, and remove the file:

   ```sh
   git diff -- src/startup_quiz.tcl       # the temporary lines and nothing else
   git checkout -- src/startup_quiz.tcl
   git status --short | /usr/bin/grep -v '^??'      # prints nothing
   rm /tmp/quiz_census.txt
   ```

   The gate of step 9.7 is a run WITHOUT the lines.

If your tree leans on `tests/headless/full_audit.sh` for the suites that are in no
regression list, leave the lines in for one audit as well: those suites start children
too, and a regression run does not reach them.

The census is one run on one day. Nothing fences a suite that is written afterwards and
starts a child XSCHEM that looks like a person's session, in your tree or in this one.
Say so beside the census in your spec (step 9.6), and run the census again when such a
suite is added.

### What to do with a hit

The command line names the script, and the script's path names the suite. Then, in that
suite's launch and nowhere else:

- a launch that a script drives gets `--pipe`, or `-q` if it only runs a script and
  leaves;
- a launch that must look like a person's gets `--command {set startup_quiz 0}` (row
  `L10` measures that), or a line `set ::startup_quiz 0` in its own `--script` file,
  which runs before the hook for the same reason.

Never change the default for the sake of a test, and never teach the engine to look at
the HOME or at an environment variable to hide from tests.

### How to read one launch

Take the one a text scan of your suites pointed at on 2026-11-21:
`tests/headless/test_asemc_u5.tcl` starts a second XSCHEM with `--rcfile` and `--script`
and none of the flags above (`/usr/bin/grep -n -B2 -A2 -e '--rcfile' tests/headless/test_asemc_u5.tcl`
shows the launch, and just above it the line `exit 0` that ends the script the child is
given). Read through, that child leaves inside the `--script` phase, before the hook:
it is not asked. That is how a launch is read: what does the process do before
`Tcl_AppInit` reaches the hook? A text scan cannot answer it, and launches assembled in
pieces or through helpers escape a scan altogether. Hence the census.

## 9. Register and gate

Your `CLAUDE.md` has the rules; this section puts them in order for this piece of work.
The names in quotes are sections of your file. The steps are in the order you act:
9.1 to 9.4 in the tree where you did sections 4 to 7, 9.5 and 9.7 in the gate clone,
9.6 in both. Two full regressions are run, one for the census and one for the gate.

### 9.1 Capture both arms in the regression's own flags, and score the captures

"Harness rules": check a suite's epilogue against `banner_complete`, not against
`run_suites.sh`. The wiring is built and the bank is as you will commit it. One command
at a time; each carries its own time bound, because `gated_xschem.sh` has none, and
each leaves its exit code beside its output:

```sh
mkdir -p $W/log
timeout 600 env -u DISPLAY AUDIT_DISPLAY=private tests/headless/gated_xschem.sh --nogui --pipe -q \
    --script tests/headless/test_startup_quiz.tcl > $W/quiz.counted.out 2>&1 < /dev/null
echo $? > $W/quiz.counted.rc
timeout 600 env -u DISPLAY AUDIT_DISPLAY=private tests/headless/gated_xschem.sh --pipe -q --logdir $W/log \
    --script tests/headless/test_startup_quiz.tcl > $W/quiz.display.out 2>&1 < /dev/null
echo $? > $W/quiz.display.rc
```

Score them with the regression's own predicate, which wants exit code 0 and the
completion banner and no death marker:

```sh
cat > $W/score.tcl <<'EOF'
# usage: tclsh score.tcl <capture>.out ...     (typed at the root of your tree)
# Scores each capture with the regression's own predicate. The exit code of a
# capture is read from <capture>.rc beside it.
source tests/banner_rule.tcl
foreach f $argv {
  set fd [open $f r] ; set body [read $fd] ; close $fd
  set fd [open [file rootname $f].rc r] ; set rc [string trim [read $fd]] ; close $fd
  puts $f
  puts "  exit code                  $rc   (want 0; 124 is the time bound)"
  puts "  banner_complete            [banner_complete $body]   (want 1)"
  puts "  regression_case_failed     [regression_case_failed $rc $body]   (want 0)"
  puts "  lower-case skip: lines     [regexp -all -line {^skip:} $body]"
  puts "  last RESULT line           [lindex [regexp -all -inline -line {^RESULT:.*$} $body] end]"
}
EOF
tclsh $W/score.tcl $W/quiz.counted.out $W/quiz.display.out
```

Both captures must say exit code 0, `banner_complete` 1 and `regression_case_failed` 0.
Keep the count of lower-case `skip:` lines for step 9.5. In this repository on
2026-11-21 the same commands gave exactly that on both arms, with no lower-case `skip:`
line on either.

### 9.2 Register

Step 4.8, with the two notes written from that capture.

Three guard suites of the regression look at a newly registered suite:
`test_registered_banner_1626` (its completion banner), `test_home_isolation` row `G2`
(a script that starts XSCHEM must be armed) and `test_suite_watchdog_1403` row `W20h`
(a suite that reaches the event loop must carry a stall bound). This repository
registered the quiz suite with no entry for it in any of the three:

```sh
/usr/bin/grep -c startup_quiz $S/tests/headless/test_home_isolation.tcl \
    $S/tests/headless/test_suite_watchdog_1403.tcl $S/tests/headless/test_registered_banner_1626.tcl
```

prints 0 three times. On 2026-11-21 the three files were the same in both trees; the
first loop of section 3 says whether they still are.

### 9.3 Correct two sentences your tree inherits from this one

`tests/headless/test_startup_guard_0663.tcl` (its header, and the name of row `SG0`)
and the header of `tests/headless/sharefarm.tcl` call `ciw.tcl` the one caught `source`
of `xschem.tcl`. With the quiz there are two. Row `SG0` still passes, since it tests
`ciw.tcl` only: on 2026-11-21 the suite passed in this repository on both arms with the
quiz wired in (`tests/headless/run_suites.sh [--nogui] test_startup_guard_0663`, with
the `env` prefix of section 5). Correct the sentences in the commit that adds the second
caught source.
This repository has not corrected them yet, and on 2026-11-21 that suite was in neither
regression list in either tree
(`/usr/bin/grep -c test_startup_guard_0663 tests/run_regression.tcl` prints 0).

### 9.4 Commit, and bring the commit into the gate clone

"Harness rules": a suite you add a fence to, you write and register in the same commit.
So the suite, its registration, the wiring and the bank are one commit. Stage an
explicit list. These are the tracked files this work touches:

```
src/startup_quiz.tcl  src/startup_quiz_bank.tcl  tests/headless/test_startup_quiz.tcl
doc/claude/specs/startup_quiz.md
src/Makefile.in  src/xinit.c  src/xschem.tcl  src/actions.csv  src/xschemrc
tests/run_regression.tcl
tests/headless/test_startup_guard_0663.tcl  tests/headless/sharefarm.tcl
```

Before you stage, look at what else is modified:

```sh
git status --short | /usr/bin/grep -v '^??'
```

A modified file that is not on the list is not yours. A file on the list may also carry
someone else's uncommitted lines, an applied port that was not committed yet, for
instance: read `git diff` of each file before you stage it, because a whole-file
`git add` takes those lines with yours.

Then the gate clone. "Harness rules" says where your branch is gated (a clone at a
short, all-lower-case path; `/usr/bin/grep -n 'whose origin is this repo' CLAUDE.md`
prints the sentence, which named `~/gcp0` on 2026-11-21). Bring your commit into that
clone the way you always do, and build it there: `src/Makefile.in` changed, and "Build
& run" says that `src/Makefile` is generated and does not regenerate itself.

```sh
# in the gate clone
./configure && timeout 540 make -C src
/usr/bin/grep -cF 'startup_quiz.tcl' src/Makefile                          # 2
/usr/bin/grep -c '"headless/test_startup_quiz"' tests/run_regression.tcl   # 2
```

### 9.5 The census, in the gate clone

First derive what the registration adds to the trailer ("Reading `results.log`": derive
your delta before launch). It is two entries, one in each list. The suite announces its
self-skips with upper-case `SKIPPED:` lines, and step 9.1 counted its lower-case `skip:`
lines.

Then run the census as section 8 describes it: the temporary lines, one full regression
(the command of step 9.7), the two `grep`s. It is also the first full regression with
the suite registered, so read its trailer like a gate's: a red here is cheaper than a
red at step 9.7.

### 9.6 Take the lines out, and write your census into your spec

Take the temporary lines out of the gate clone (section 8, step 4 of the census).

Then, in the tree where you work, correct the sentences of your copy of the spec that
are true only for this repository:

- section 4 ends with a paragraph that begins "No other test is ever asked" and reports
  a census of this repository's regression with its date. Replace it with yours: the
  date, the commit, what the two `grep`s printed, and that it is one run (section 8);
- section 6 says how many questions carry a condition, and which. Make it agree with
  your bank (`tclsh $W/bankstat.tcl .` prints them, section 7.3).

Commit that, and bring it into the gate clone. It changes a document only, so nothing is
rebuilt there.

### 9.7 Gate

From the gate clone's `tests/` directory ("Harness rules": run a gate detached and poll
it in the foreground):

```sh
setsid nohup env -u DISPLAY T1_DISPLAY=private tclsh run_regression.tcl > "${W:?}/t1.out" 2>&1 &
```

(the progress output goes to the scratch directory, so that the run leaves no file of
yours in the clone). The answer is the newest `tests/results.<pid>.log` whose first line
carries your start time, and only once its last line starts with `T1-RUN-END`. Done means
`counted_failures=0` there, the case and block counts you derived at step 9.5, and each
`skip:` line read.

### 9.8 Hand over, and clean up

Section 10 is what you say to the user. Then remove the scratch directory:

```sh
rm -rf "${W:?}"
```

## 10. What the user sees, and is owed

Say these to the user when you hand over. None of them is yours to decide.

- **Every interactive launch asks a question until the box is ticked.** That includes
  the launcher of the design workarea: `build_cmd` in
  `/home/analog/dev/hdo-design/run.tcl` starts XSCHEM with `--rcfile` and `--script` and
  none of the flags of section 8. The default is ON in your tree as it is here. If you
  worked in the tree that launcher runs, the user has been asked since the wiring was
  built (the head of section 4).
- **Once per launch means once per PROCESS.** File > "Start new Xschem process" and the
  other callers of `new_xschem_process` (`src/actions.c`) start another XSCHEM with none
  of those flags, so each such process asks again. New windows and tabs inside one
  process do not: `Tcl_AppInit` runs once. This is read, not measured:
  `/usr/bin/grep -n 'execl(xschem_executable' src/actions.c` prints the options the new
  process is given, and `/usr/bin/grep -n 'new_xschem_process(' src/*.c` its callers.
- **The two programs share two files.** Both trees keep the switch in
  `~/.xschem/startup_quiz` and the answered list in `~/.xschem/startup_quiz_done`
  (`USER_CONF_DIR` in `config.h`, and `startup_quiz::conf_path`). So:
  - there is ONE switch for both programs. "Don't show anymore" in either turns the quiz
    off in both;
  - the answered list is rewritten, each time an answer is clicked, with only the ids
    that the RUNNING program's bank holds (`startup_quiz::done_ids`, called by
    `startup_quiz::mark_done` and `startup_quiz::write_done`; rows `C8` and `E19` hold
    that an id the bank does not know is dropped). While both banks hold the
    same ids nothing is lost. Once your bank has questions of its own, an answer given in
    this repository's program forgets your program's own ids, and those questions come
    round again sooner. The reverse loses nothing as long as your bank keeps every id of
    this one;
  - on 2026-11-21 the user's `~/.xschem/startup_quiz_done` already held answered ids and
    there was no `~/.xschem/startup_quiz` (`cat ~/.xschem/startup_quiz_done` and
    `ls ~/.xschem/startup_quiz` show it). So the first interactive launch of your program
    after the port WILL ask a question, and what the user answered here stays answered
    there.

  Neither tree changes any of this today. One switch or two, one answered list or two:
  that is the user's call. Do not invent a fix.
- **The precedence of the switch.** These are the places where `Tcl_AppInit` evaluates
  text that the user wrote on the command line or in an rc file, in the order it reaches
  them. Later wins, for that launch:
  1. `--preinit` text;
  2. the rc files (`xschemrc`, `--rcfile`);
  3. `--tcl` text. It runs before `xschem.tcl` is sourced, so it behaves like an rc line;
  4. `xschem.tcl`: the default (`set_ne`, only if the variable is still unset), then
     `startup_quiz::load_conf`, which reads the saved choice. **A saved choice therefore
     wins over 1 to 3**;
  5. the files an rc names in `tcl_files`, then the rc variable `postinit_commands`;
  6. the rc variable `user_startup_commands`, evaluated at global scope by
     `eval_user_startup_commands` once the schematic is loaded;
  7. the `--script` file;
  8. `--command` text;
  9. the hook reads the switch.

  So anything in 5 to 8 decides for that launch over a saved choice. A
  `set startup_quiz 1` in the `--script` rc of a PDK launcher, or in a
  `postinit_commands` or `user_startup_commands` of an rc file, would defeat the user's
  box: do not put one there. `user_startup_commands` is also run again by
  `create_new_window()` for every new window, after the hook: there it changes the
  variable for the rest of the session and saves nothing. Rows `L8` to `L12` measure the
  saved choice against `--preinit` and `--command`. The rest of the order was read in
  `Tcl_AppInit` itself on 2026-11-21, in both trees. Of what it calls, only
  `source_user_tcl_files`, `eval_postinit_commands` and `eval_user_startup_commands`
  were followed. This prints the calls in the order your tree runs them:

  ```sh
  awk '/^int Tcl_AppInit/{p=1} p' src/xinit.c | /usr/bin/grep -o -E 'tcleval\(cli_opt_preinit_command\)|SOURCE xschemrc file|tcleval\(cli_opt_tcl_command\)|source_tcl_file\(name\) != TCL_OK|"source_user_tcl_files"|"eval_postinit_commands"|eval_user_startup_commands|source_tcl_file\(cli_opt_tcl_script\)|tcleval\(cli_opt_tcl_post_command\)|"exit %d", exit_code|startup_quiz::at_launch\]'
  ```

  (`source_tcl_file(name) != TCL_OK` is the source of `xschem.tcl`.)
- **A look is owed, and one ruling.** The owed ledger is one for every clone (your
  `CLAUDE.md`, "The owed ledger"), so look before you file:

  ```sh
  ls ~/.claude/xschem_owed/rule ~/.claude/xschem_owed/look | /usr/bin/grep -i quiz
  /usr/bin/grep -il quiz ~/.claude/xschem_owed/rule/* ~/.claude/xschem_owed/look/*
  ```

  - The window was only ever seen by suites on a virtual display. Its fonts, wrapping,
    the colours of the right and wrong marks and its placement over the main window on
    the user's real screen are unratified. On 2026-11-21 the commands above showed one
    entry, this repository's own `look` for its window (`startup_quiz_dialog`), still
    open. File a `look` of your own for your program, and report "suites green, please
    look", not "done".
  - The shared files are one question about both programs, so they are one `rule`, not
    one per tree. When this file was written, that question was handed over to be filed
    from this repository's side. If the commands above show a `rule` about the quiz's
    files under `~/.xschem`, do not file a second one: tell the user that it stands for
    your program too. If they show none, file it from your tree and say that it stands
    for both.

## 11. Keeping two banks honest afterwards

- **A feature carried between the trees takes its questions with it.** A change that
  renames a menu entry or moves a key rewords the questions that mention it, in the
  commit that makes the change. When that change is ported, the bank's hunks are part of
  the port, in either direction. To see what this repository's bank did since you copied
  it:

  ```sh
  git -C $S log --oneline <the commit you copied from>..fluid-editing -- src/startup_quiz_bank.tcl
  ```

  (the hash is the one in your commit message).

- **Keep this repository's ids for the questions you share**, so the shared answered
  list keeps meaning the same thing in both programs. A question that stands in the two
  banks under two ids is asked again in the other program after it was answered in one.
- **The port tool of issue 1724 is written on the premise that your tree has no quiz.**
  Once it has one, these files under `/home/analog/port_1724/` say something false, and
  the next run of the tool stops on it
  (`/usr/bin/grep -rn -i quiz /home/analog/port_1724/tool /home/analog/port_1724/README.md`
  prints the lines):
  - `tool/adapt/not_in_target.txt` lists `src/startup_quiz_bank.tcl` as a file the
    target does not have;
  - `tool/adapt/issue_port_note.md` says the quiz entries were not ported because the
    target has no startup quiz;
  - `tool/make_port.sh` leaves a listed file out only while the target lacks it, and
    then checks that the bank WAS left out; with the bank present it dies with a message
    that ends "edit the note";
  - `tool/lib/register_suites.py` (its header) and `tool/lib/port_report.tmpl` explain
    the registration and the report in the same terms, and `README.md` lists the quiz
    entries under "Not ported".

  Tell whoever runs that tool next. The two questions it left out (`direct-plot` and
  `calc-pick`, reworded for issue 1724) reach your tree with the bank you copy in step
  4.1, so nothing of that port is missing afterwards.
