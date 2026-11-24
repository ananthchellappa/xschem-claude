# 1739 — The tip-of-the-day window hides its buttons after an answer; and its typeface

**STAMP:** `v1 claim=fixed tree=f012408d2 stamped=2026-11-24 fix=taken open=2 by=driver-1739`

Reported by the user on 2026-11-24 and repaired the same day, on a private Xvfb with
openbox. Two things are open, listed under "Open" below: the user's own look at it on
their screen, and a ruling on the builder's choices.

## What the user wrote

> In the startup quiz, when user responds to the question by choosing an answer, and you
> then respond to that response, ensure that the window grows appropriately so that the
> Next Question and Close buttons are visible!! Current look is very amateurish - user
> has to resize window so often. Also, can you choose a nicer font for the quiz? What
> would Apple do?

## What was measured

A probe put up every question of the shipped bank and answered it, and read whether the
window had the room its widgets asked for.

- **In a window nobody had sized: no question lost its buttons.** Tk makes a toplevel
  follow its widgets, and openbox applied every size.
- **After the window had once been given a size from outside** (`wm geometry` with a
  size 10 pixels taller than the first question needed, which leaves Tk in the state a
  drag of the border does): **46 of the 88 questions** asked for more height than the
  window had once answered, by up to 92 pixels. The window never grew again.
- **What was cut was the button row.** `startup_quiz::window` packed the hint and the
  button row last, and the packer gives room in packing order.

So one resize, by hand or by a window manager, was enough to make every later answer in
that window a candidate for another resize. That is the state the user described.

**Not measured:** the user's own screen. Their X server runs under Windows and is not
this one; no xschem was started on it. Whether the first loss of the buttons there came
from a drag of the border or from the server's own sizing of a new window is not known.
The repair does not depend on which.

## The repair

Rules R-QW1 to R-QW7 and R-QF1 to R-QF4 of `doc/claude/specs/startup_quiz.md`, sections
2.1 and 2.2.

- `startup_quiz::fit`, called at the end of `startup_quiz::display` and of
  `startup_quiz::answer`: it reads what the window's widgets ask for and sets that as the
  window's size and as its minimum size. The size the window has is kept when it is
  larger. A window that would pass the right or the bottom edge of the screen is moved
  back.
- `startup_quiz::window` packs the hint and the button row before the text, so they are
  the last thing a short window cuts. The first placement moved into `fit`, where the
  full size is known.
- `startup_quiz::family` and `startup_quiz::fonts`: one family from a list, four private
  named fonts.

The same probe after the repair: no question loses its buttons, in a window nobody sized
and in one sized from outside.

## The builder's choices, for a ruling

The user's words settle that an answer must not hide the buttons and that the typeface
should be a nicer one. These are not the user's:

1. **The window only grows.** After a long explanation the window keeps its height for
   the next, shorter question, with empty room above the buttons. The other way is a
   window that fits every question exactly and so moves its buttons at every press of
   `Next question`.
2. **The window is moved back onto the screen** when growing takes it past the right or
   the bottom edge, with 48 pixels kept free there.
3. **The family.** The list is Apple's own families, then Inter, Helvetica Neue, Segoe
   UI, Roboto, Noto Sans, Open Sans, Source Sans, Lato, Ubuntu Sans, Ubuntu, Cantarell,
   Liberation Sans, Nimbus Sans, Helvetica, Arial. On this machine the first one present
   is **Lato**; Ubuntu Sans and Nimbus Sans were also drawn and looked at, and Lato was
   kept for its open letters and its line spacing.
4. **The sizes**: the question three steps above the labels' size, the options and the
   explanation one step above, the topic and the hint at the labels' size.
5. **The page**: wider margins, a hairline above the button row, wider buttons.
6. **A drag cannot make the window smaller than its content** (the minimum size).

## What was found on the way

- The first form of the "only grows" rule was held twice: by a remembered largest size
  and by keeping the size the window has. Taking either out left every row green. The
  remembered size was removed.
- The first form of row D51 read the place of the button row without asking whether the
  row was mapped. A widget the packer finds no room for is unmapped and keeps the place
  it had, so the row passed with the buttons gone.
- openbox moves a window back onto the screen when it grows by Tk's own following, and
  does not when its size is set with `wm geometry`. So the old window passes row D54 for
  the window manager's reason, and the repair needed its own move (R-QW6).
- `font actual` reports the size of a font made in pixels as points, so the faces of a
  session whose labels are sized in pixels step in points.

Both test lessons are in `doc/claude/TEST_LESSONS.md`, sections 1 and 3.

## What was measured after

`tests/headless/test_startup_quiz.tcl`, rows D44 to D59 (display arm). Its header lists,
for the window as it was and for each of ten deliberate breaks of the repair, the rows
that go red.

## Open

1. **The user's look** on their own screen: the typeface, the window growing at an
   answer, and whether the buttons stay in the window there. Everything above ran on a
   hidden display.
2. **The six choices above** wait for a ruling.

## Not built

- Return for `Next question`, and keys for the answers.
- A window that gets smaller again for a shorter question.
- A menu or rc entry for the family. `startup_quiz::font_prefs` is a variable.
