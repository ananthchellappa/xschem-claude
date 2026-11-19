# Tip of the day, asked as a quiz

Status: built. Engine `src/startup_quiz.tcl`, questions `src/startup_quiz_bank.tcl`,
suite `tests/headless/test_startup_quiz.tcl` (registered in `hcases` and `dcases`).

## 1. What it is for

This XSCHEM has grown a long way past the upstream program: a command palette,
remappable keys, an action log, ASE-L, a waveform viewer, a calculator, a library
manager. A person who learned the upstream program has no way to find out, and a
person who uses one corner of the fork does not know about the others.

So when an interactive session starts, XSCHEM asks one question about itself. The
person answers, is told whether they were right, and reads two or three lines on
how the thing actually works. The answer is the point; the question is the hook.

## 2. What the person sees

A small window titled **Tip of the day**, placed over the main window, not modal:
the editor underneath stays usable and the window can simply be ignored.

- top line: the title, and the question's topic on the right;
- `True or false?` or `Pick one:`, then the statement or question;
- the answers as radio buttons. Multiple choice is lettered A to E and shuffled
  each time it is shown, except an "any of these" option, which stays last;
- after a click: the options lock, the right one is marked `(correct)` and a
  wrong pick `(your answer)`, a verdict line appears, and under it the explanation;
- `Don't show anymore`, `Next question`, `Close`. Escape closes too;
- a last line saying where the switch can be found again.

The verdict line is one of:

| situation | line |
|---|---|
| right | `You nailed it!` |
| right, and the feature is a planned one | `You nailed it. This is an upcoming feature! Stay tuned!` |
| true/false about a planned feature, answered True | `Not yet! This is an upcoming feature. Stay tuned!` |
| "which of these is not built yet", wrong pick | `Not quite: that one already works.` |
| true/false, wrong | `Not quite: this one is true.` / `Not quite: this one is false.` |
| multiple choice, wrong | `Not quite.` |

## 3. Kinds of question

| type | kind | answer | example |
|---|---|---|---|
| true/false | `shipped` | True | "A schematic tab can be pulled out into a window of its own." |
| true/false | `upcoming` | False | "The Calculator's Table button lists the X and Y values..." |
| true/false | `myth` | False | "You have to select a wire before you can drag its end." |
| multiple choice | `howto` | one option | "To change the key binding of your most-used command, you would:" |
| multiple choice | `upcoming` | one option | "Which of these waveform viewer commands is not built yet?" |

`upcoming` is only for a feature this repository has written down as planned.
A statement that is merely false is a `myth`, and gets no "stay tuned".

## 4. When it is asked

`Tcl_AppInit` (`src/xinit.c`) calls `startup_quiz::at_launch` once, at its very
end: after the rc files, after the `--script` file, after `--command`, and after
the `-q` exit. Only a session with a display that is staying open gets that far.
The Tcl side (`startup_quiz::decide`, a pure function) then says no when:

| gate | reason word | why |
|---|---|---|
| no Tk | `no-display` | nothing to show it on |
| `--pipe` | `automation` | a script is driving the session, not a person |
| `--nolog` | `nolog` | the option that already means "no auxiliary windows": it suppresses the CIW too |
| the switch is off | `off` | the person said so |
| no question applies | `no-questions` | bank missing, broken, or all conditional |

`--norecent` is deliberately **not** a gate. It is an option a person passes (the
PDK launcher has a checkbox for it), and the flag C derives from it,
`no_recent_files`, is therefore the wrong thing to read; C mirrors `--pipe` on its
own as `::cli_opt_pipe`.

When the answer is yes the window is scheduled with `after`, never waited on. It
appears once the main window is on screen and no other dialog holds a grab, and
is shown anyway after a few seconds of waiting.

The decision is kept in `startup_quiz::launch` as `{show reason}`.

Measured, with one child process per row (band `L` of the suite): a bare launch
and a `--script` launch are asked; `--pipe`, `--nolog`, `-q`, a saved "off" and
`--command {set startup_quiz 0}` are not; `--nogui` never reaches the hook and
never opens the question bank.

No other test is ever asked. A census taken over one full regression run
(2026-11-18, a line appended by `at_launch` for the duration of that run) found
the hook reached only by this suite's own child launches: every other case
starts xschem with `-q`, with `--pipe`, or with no display.

## 5. The switch

One Tcl variable, `startup_quiz` (1 = ask at launch, the default). Four doors,
all the same switch:

- the window's `Don't show anymore` box;
- Help > `Tip of the day at startup` (a checkbutton);
- the command palette: `Toggle tip of the day at startup`;
- an rc line: `set startup_quiz 0`.

The first three save the choice to `~/.xschem/startup_quiz` the moment it is
made, and say so through `xschem::notify` (CIW line plus status field). The file
is read back at startup by `startup_quiz::load_conf`, after `xschemrc`. So:

- a choice made in the program wins over an `xschemrc` line;
- a `--script` rc and `--command` run later still and decide for that one
  launch. A `set startup_quiz 1` in the rc of a PDK launcher would therefore
  defeat the box; do not put one there.

Asking for a question by hand, Help > `Tip of the day (quiz)...` or the palette's
`Tip of the day (quiz)...`, works whatever the switch says.

## 6. Which question

Random, without repeats:

1. a question never answered, and not yet shown in this session;
2. else one never answered;
3. else every question has been answered: the round starts again.

The question on screen is never handed straight back. "Answered" is remembered
across sessions in `~/.xschem/startup_quiz_done`, written when an answer is
clicked and at no other time, so a person who closes the window without answering
writes nothing. Nothing is written in a `--pipe` session.

A question may carry a condition (`only`), an expression evaluated in the running
session: the four Cadence-profile questions are asked only where the `cadence`
namespace exists, the two sky130 ones only in the sky130 workarea. Asked for by
id, a question is shown regardless.

## 7. The question bank

`src/startup_quiz_bank.tcl` is a list of `startup_quiz::add <id> {...}` calls; its
header documents every key. It is read the first time a question is needed, never
at startup, and never in a session that is not going to ask.

An entry that does not validate is left out, named in
`startup_quiz::bank_errors`, and costs nobody else their place. A file that is
missing or breaks part way down gives the questions read so far. Neither raises.

### 7.1 Every question carries a proof

A question is a statement about this program, shown to a user, and the program
changes every week. So every entry has a `proof`: an expression that is true
while the entry is still right. The engine stores it and never evaluates it; band
`A` of the suite evaluates all of them on every run.

- a shipped feature's proof says the thing is there: the proc exists, the menu
  label is in the source, the key is in the live binding table, the default is
  what the explanation says;
- an upcoming feature's proof says the thing is still absent: the stub line is
  still in the proc, the subcommand does not exist.

Consequences, all intended:

- rename a menu entry or move a key, and the questions that mention it go red in
  the gate instead of going stale in front of a user;
- **build a planned feature, and its `upcoming` question goes red.** Move it to
  `shipped`, rewrite the explanation, and write the proof the other way round;
- a proof that cannot be evaluated is a failure, not a pass.

What a proof does not cover: the wrong options of a multiple-choice question.
Those were checked by hand against the source when the bank was written (a wrong
option must not be a second way of doing the thing), and nothing re-checks them.

### 7.2 Rules the suite holds the bank to

At least 60 questions, at least 60 that apply in a plain launch, both types, all
three true/false kinds, at least 12 topics with no more than 6 questions each,
at least a third of true/false answers false, no question twice, plain ASCII, and
every text inside its length budget (which is what keeps the window small; the
display arm also shows every question, answers it, and measures the window).

### 7.3 Adding a question

Add it when you ship the feature. Pick an id that was never used (the answered
list remembers ids), write the explanation as the thing you would tell a
colleague, and give it a proof that would fail if the feature were removed.

## 8. Files

| file | what |
|---|---|
| `src/startup_quiz.tcl` | engine; proc definitions only at source time |
| `src/startup_quiz_bank.tcl` | the questions |
| `src/xschem.tcl` | the caught `source`, the two defaults, `load_conf`, the Help entries |
| `src/actions.csv` | `help.tip_of_the_day`, `help.tip_of_the_day_startup` |
| `src/xinit.c` | the launch hook; the `cli_opt_pipe` mirror |
| `src/Makefile.in` | both files on the install list (re-run `./configure`) |
| `~/.xschem/startup_quiz` | the saved switch |
| `~/.xschem/startup_quiz_done` | ids already answered; delete it to start the round again |

The `source` in `xschem.tcl` is caught, like `ciw.tcl`'s: nothing depends on this
file, so a session without it is a session without the quiz, announced once.

## 9. Not built

- a score, a streak, or any record of right and wrong answers;
- re-asking a question that was answered wrong sooner than the others;
- a user's or a PDK's own question file beside the shipped one;
- a "show me" button that runs the command a question is about;
- keys for the answers (A to E, T and F).
