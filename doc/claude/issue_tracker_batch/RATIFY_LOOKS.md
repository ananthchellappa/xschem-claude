# Look at these 27 things

## 27 looks, five sittings. About two and a half hours.

Your queue currently shows **71 separate items** that all say some version of the same thing:
*"a suite cannot judge pixels — please look at this with your own eyes."* They were filed
one at a time, over two weeks, as each piece of work finished.

**They are 27 looks, not 71** — and **ten of the 71 ask for nothing at all.**

A person reviews a *screen*, then moves to the next screen. Sorted that way, the 71 items
land on five surfaces, and most of them are several questions about one window that you can
answer in a single sitting without setting anything up twice.

---

## How long this takes

| Sitting | Looks | Queue items | Time |
|---|---|---|---|
| **A. The Results window** | 7 | 27 | ~50 min |
| **B. The schematic window** | 3 | 3 | ~15 min |
| **C. ASE-L** | 12 | 20 | ~70 min |
| **D. File > Open Recent** | 1 | 1 | ~2 min |
| **E. The hierarchical PDF** *(a different copy of the program — see the note)* | 4 | 10 | ~25 min |
| **Ten that need nothing** | — | 10 | — |
| **All of it** | **27** | **71** | **~2 h 40** |

**These are estimates, not measurements.** Sittings A and C are the ones worth booking time
for; D takes two minutes and is the only one where something of yours is actually damaged
right now.

**Do all of this on your own screen.** Every one of these was measured on an invisible test
display whose fonts, window manager and event timing are not yours — which is exactly why
they are on your queue and not closed by a green test.

---

## Ten of the seventy-one ask for nothing

Recommended to retire. Each was either **asked twice** — the queue has no way to say
"this replaces that", so a re-filed entry lands beside the one it replaces — or **already
answered by a change in the program since it was filed**.

| What it asked | Why it needs nothing |
|---|---|
| Keyboard after a dump | The newer entry on the same gesture says outright it answers this one too |
| The window not coming forward on your server | Same gesture, same code, as the raise question in sitting A |
| "Did not converge" printed for numbers that were fine | Repaired — the program now asks whether a number is finite instead of guessing from a blank |
| The Delete sentence cut off at the window's edge | The one-line strip it measured no longer exists; it is a wrapping panel with a scrollbar now |
| Can you read the clause after a multi-row Delete | Its own question was measured by the entry above, then answered by the rebuild |
| Status-line wrapping | The newer entry says in its own first line that it replaces this one, and that two of its checks are now void |
| Copy on your own X server | A one-line placeholder filed before the fix existed; the full version is in sitting A |
| Window and sheet disagreeing after a reorder | Two of its four findings shipped as fixes; the other two are already on your *decisions* queue, not your eyes |
| The PDF link highlight | Filed twice on the same day; the second filing supersedes the first |
| Save State overwrite popup | Filed twice; the second asks everything the first did and three things more |

I checked the five code claims behind these against the program as it stands today, not
against the note that made them. All five hold.

**Clearing them is still yours and nobody else's** — but it is one decision, not ten.

---

# The 27 looks

## A. The Results window — 7 looks, ~50 min

This is the pane that shows a device's operating-point numbers. Open it the way you
normally would: annotate the sheet (press **6**), then press **1** over a FET. Everything in
this sitting happens in that one window, so set it up once.

### L1 — The window as it opens

**Open:** annotate, press **1** over a FET. Leave it at its default size.

**Look at:** the newest block on top with older ones pushed below · the full-width line above
the pane naming which list the buttons edit · the window title · the strip of seven controls
down the right — Up, Down, Delete, Add, Save, a gap, **aA**, a gap, Close · the grey band
across the row your text cursor is in · the two dark-orange notice lines on every block.
Then press **2** and watch the window get about 78 px wider, and shrink back on **1**.

**Wrong:** the orange notices read as errors rather than notes · the control strip pulls your
eye off the numbers, or reads as crowded · Close looks tucked under Save rather than sitting
at the foot · you cannot find the grey band without hunting, **or** it is strong enough that
you take it for a selection and expect Ctrl-C to copy that row · the default pane is too
narrow for the blocks you paste into a design review · the window visibly jumping every time
you flip between 1 and 2 is more annoying than the extra sentence is worth.

### L2 — The text of one block

**Open:** the same window, one FET dumped. Put it next to the annotated device on the sheet.

**Look at:** the two-line header — a bold `M18:/x1/x1` over a dimmer raw device path · the
caveat sentence about where the numbers came from · the "not everything the device has" line
· the narrowing line, `6 of 88 columns` · and the numbers themselves in engineering form
(`11.1u`, `1m`, `1.2G`) beside the same numbers drawn on the schematic.

**Wrong:** the window and the sheet print different digits or different suffixes for the same
value, so you have to convert one to compare them · the ragged right-hand edge of the value
column looks untidy once pasted into a document · three lines of preamble out-talk the six
numbers they introduce · the caveat reads as an error rather than a note · `(no value
reported)` and `(did not converge)` are indistinguishable at a glance, which is the one
distinction those words were minted to make.

### L3 — Copying out of the window

**This one needs your own screen and your own clipboard, and no test can stand in for it.**

**Open:** the same window. First, in another application, copy a sentence you care about —
that is the clipboard that has to survive.

**Look at:** drag a selection, press Ctrl-C, paste it somewhere · right-click for the new
Copy / Select All menu · double-click a word, let go, then press and drag — the word should
stay whole while the selection grows · Select All + Copy in an **empty** window · select the
settings-file path in the bottom line and press Ctrl-C · then drag across several rows, press
Delete, accept the defaults, and read the long verdict that appears in the bottom line.

**Wrong:** the sentence you cared about is gone from your clipboard after the empty-window
copy · what you paste stops short, or carries a `...` · the bottom line still claims a copy
that is no longer what the clipboard holds · two selection-coloured regions on screen at once
with no way to tell which one Ctrl-C will take · the highlight that survives another program
taking the selection is a different colour, or cannot be put down by clicking elsewhere · a
three-pixel drag of the window edge destroys a selection you were in the middle of.

### L4 — Editing a list with the buttons

**Open:** the same window. Click a parameter row, then press Up, Down, Delete and Add.

**Look at:** whether the row you clicked is findable at all — there is no highlight, only a
text cursor and that grey band · the row visibly moving one line, with the band landing on
its new line and not on the one it left · the scope pop-up, which asks *this device flavor
only* versus *every device of this class* · the greying as you switch 1/2/3, and whether the
column shifts under the pointer · what Save writes, named in the bottom line.

**Wrong:** a highlight you were mid-copy of is thrown away by a Delete that redrew identical
text · pressing Add re-sorts the rows under you while the title still names the other list,
with nothing said about the re-sort · the control column changes width or reorders as the
greying changes · the older block above still shows the row you deleted, and that reads as
"the delete did not work" even though it is a past-tense record.

### L5 — Does the window come forward, and who gets the keyboard

**Your own screen only.** The test display cannot reproduce either half: it has a window
manager that answers a polite request to come forward, and yours does not.

**Open:** annotate, press **1** over a FET, click back on the schematic so the window goes
behind it, then press **1** over another device.

**Look at:** does the window actually come to the front · does it walk up-and-left a little on
each dump · then click **in the results pane** as if to copy, click back on the schematic,
select another device and press **1** — does that device's information arrive on the **first**
click · and then, **without clicking the schematic**, press 1, 2, 3, 4 and Escape.

**Wrong:** it stays buried · it creeps about 32 px up-and-left every time · it lands on top of
the device you were about to click · two clicks per device instead of one, which was your
original report · the digits and Escape are dead until you click the canvas — that is the
half you forbade in the same sentence as the request.

### L6 — The pick mode on the canvas

⚠ **The queue entry for this says "nothing to look at yet". That is out of date.** It was
written when the work had been reverted; it has since landed, and pressing 1, 2 or 3 on the
canvas reaches this window today. The entry's list of what to judge is still the right list.

**Open:** on the canvas with nothing selected, press **1**, then **2**, then **3**.

**Look at:** the single line announcing the mode — is one line enough to tell you the mode is
live, or does it need a standing prompt on the canvas · press, wiggle one pixel, release —
nothing may get selected · click just off a grid point on a device body — the block must be
headed with the device **under the cursor**, not the one the grid snapped to · press a key the
mode refuses, and nothing on screen may change.

**Wrong:** you forget the mode is live and a click you meant as an ordinary selection dumps a
block instead · a one-pixel wiggle selects objects and the rubber band survives Escape · the
block is headed R1 when you clicked M1.

### L7 — Text size, and the aA button

**Open:** the same window. Press **aA** up six times, then down six.

**Look at:** do the value columns stay lined up at both ends of the range — your screen may
substitute a different typeface for the fixed-width one this was measured with · does the
window stay roughly the size it was · does the unscaled bottom line look absurd under a very
large pane · where does the aA tooltip land at the window's usual position.

**Wrong:** values that no longer line up in columns · the window jumping to fill or overflow
the screen on the way up · a tooltip that lands off the window, or never appears.

---

## B. The schematic window — 3 looks, ~15 min

### L8 — The status-bar hint, and its tooltip

**Open:** on the canvas with nothing selected, press **1** (then 2, then 3). **Move the mouse
around the canvas while you read the status bar.** Press Escape.

**Look at:** the green slot that normally says DRAW WIRE! now carries a prompt about clicking
an instance · whether it sits rock-still while you move the mouse · that the sentence costs
the coordinate readout beside it some room · narrow the main window below about 815 px until
the sentence is clipped, then hover it — the whole sentence should appear after one second.

**Wrong:** any flicker or twitch at all as you move the mouse — that is a real finding · the
green reads as an alarm next to DRAW WIRE! rather than as information · losing that much of
the coordinate readout is not worth the sentence · the one-second wait is too long here, when
the aA button uses a third of a second on your own instruction.

### L9 — Tooltips near the edge of your screen

**Open:** drag the main window down and right until its status strip sits hard against the
bottom-right corner of the screen. Hover things there.

**Look at:** every tip should appear once, whole, sliding sideways or flipping above its
control as needed, and stay put while you hover.

**Wrong:** a tip that flickers on and off forever · one still cut off by the screen edge · one
that jumps to the far side of the display.

### L10 — Descend, run, and come back — without a flicker

**Open:** the bandgap bench, Session > Design Window, descend into `x1` and then `x1` again —
the exact gesture from your report — and press **Netlist and Run**.

**Look at:** the button now climbs to the top sheet, netlists it, and puts you back. The
question is whether you *see* that happen: any flash of the top-level sheet, any blink, any
zoom or pan wobble, any window flicker between the press and the run starting.

**Wrong:** anything moves. It must look like nothing happened. Also watch that the schematic
window does not disappear or take the keyboard.

---

## C. ASE-L — 12 looks, ~70 min

Open a bench and launch it once — Tools > Launch ASE-L — and stay in it for the whole
sitting.

### L11 — Choose Analyses

**Open:** Analyses > Choose…

**Look at:** eleven cells wrapping four to a row at the dialog's default width — grid, or
wall? · the state marks: warning sign for caution, circled slash for blocked, middle dot for
absent, and **nothing** for OK · click a blocked cell and read its reason in the status line
· the precondition banner under the form, in its cold, warm and stale wordings · the TRAN
form's closed **Advanced** triangle, opening to three more fields and a checkbox · the AC
picker rewriting its neighbour's label when you change it · every label now carrying its unit
· the lengthened picker words — Voltage, Current, PZ, Poles, Zeroes, DC AC — in fixed-width
boxes, with dec/oct/lin deliberately still lowercase beside them · and the second entry,
Analyses > List, which opens a read-only dump of every row.

**Wrong:** labels truncated at the form's width · a longer picker word clipping, or resizing
the dialog · the triangle not rendering in your typeface · an unmarked OK cell reading as
*unexamined* rather than as *fine* · the banner crowding the form it sits under.

### L12 — Simulation > Options…

**Open:** Simulation > Options… on a bench.

**Look at:** the default view is this bench's own changed rows · the Find box narrowing live
over name, group and help · **Show all** opening about 240 more rows in 14 groups, each naming
its count · the Scope filter · the Results column badge, which has three states: CHANGES
RESULTS on the nine measured rows, nothing on the three measured *not* to, and MAY CHANGE
RESULTS — UNVERIFIED on the ten nobody has measured · the deck preview pane showing the exact
lines this bench will emit and where, with a *not delivered* block for those that will not
arrive. Then open Options… on an analysis row **you have given a name to**: the free-text
pair list should be empty where it used to hold two bogus rows, and OK should commit rather
than refuse. Then run, and read the "what the simulator actually used" lines in the log.

**Wrong:** the pane does not read as one surface at your real font size · the three-valued
badge reads as noise rather than as three distinct states.

### L13 — Measurements

**Open:** Outputs > Measurements…

**Look at:** a whole new sub-dialog, a template picker, and a Value column.

**Wrong:** anything that reads as cramped, mislabelled or unfinished at its default size.

### L14 — S-parameter ports, and the result matrix

**Open:** an S-parameter bench. The ports table, **Add from Schematic**, and the matrix
picker. Then set a row to three ports with the noise box ticked.

**Look at:** the four formats offered · and at three ports, a fourth 3×3 block below S, Y and
Z, with no scalar strip — 36 cells where it used to show 27. Nobody has looked at that
layout.

**Wrong:** 36 cells read as a wall · the fourth block looks like an error rather than an
addition.

### L15 — Campaigns

**Open:** Simulation > Campaign…

**Look at:** the histogram with mean, sigma and yield beside it — **this is the first drawing
ASE-L has ever made; nothing else in it draws one** — and the k/N progress readout, in both
the Campaign dialog and the Campaign Results window.

**Wrong:** the histogram is unreadable at the dialog's size, or the progress readout is lost
beside it.

### L16 — The TRAN form's noise section

**Open:** the TRAN form, noise section.

**Look at:** the refusal sentence shown **twice** — once as a section note and once as a form
banner — and a third time on a refused OK, which also widens the dialog from 667 to 839 px ·
the dialog at 814 px tall when unfolded, and taller with Advanced open · the Values column
showing a random source's *distribution* as its number · the estimates line · the footer's
seed and kill sentences.

**Wrong:** the same sentence three times reads as shouting · the dialog is too tall for your
screen · a distribution sitting in a column of numbers reads as a mistake.

### L17 — The digital strip at the run's end

**Open:** a mixed-signal run.

**Look at:** a held value is now drawn all the way to the analog run's end rather than
stopping at the last edge. Two before-and-after pictures of this are already saved in the
repository if you would rather compare than re-run.

**Wrong:** the held value's line looks like data rather than like a hold.

### L18 — Convergence, and the starred nodes lit on your own schematic

**Open:** a run that struggles to converge, then Results > Highlight Non-Converged Nodes.

**Look at:** the nodes the simulator complained about, lit on **your own schematic** · the
four-rung Convergence pane with its checkboxes and the line beneath it · the one-line
run-health strip in the status bar.

**Wrong:** the lit nodes are hard to pick out on a busy sheet, or the highlight collides with
something you already use.

### L19 — Setup > Simulators: what the program can do

**Open:** Setup > Simulators… > Edit… > **Detect**, on your PATH ngspice and on the fork, side
by side.

**Look at:** the new line saying what that program can do. Two pictures of it — before Detect
and after — are saved in the repository.

**Wrong:** the sentence wraps to six lines in the 420 px available, which is what it did when
measured.

### L20 — Save State, over a name that already exists

**Open:** Session > Save State, type the name of a state that already exists, press OK.

**Look at:** is the sentence readable, and is it obvious **which file is about to die** ·
**where the confirm lands** — measured about 1100 px away at the far left screen edge, because
no ASE-L dialog is tied to the window that raised it, and your window manager is not the one
that was measured · the focus deliberately rests on **Cancel**, so Return dismisses rather
than writes — right, or merely awkward? · and the older read-only sentence beside the new one.

**Wrong:** the confirm appears somewhere you will not look for it · Return does the dangerous
thing · you cannot tell which file is being overwritten.

### L21 — ASE-L tooltips

**Open:** hover the eight glyphs of the action strip, and the temperature box.

**Look at:** first, whether a tip appears at all — no automated check can prove one ever did ·
then hover **down** the strip: each tip is anchored to the bottom edge of its button, and the
strip is a vertical column, so every tip sits over the next button down, covering about four
fifths of it · then hover the X button, click it, and watch whether a tip that is still on
screen when the window repopulates loses its yellow ground, its fixed typeface and its border.

**Wrong:** hovering down the strip feels wrong · a click ever seems to miss · a tip turns into
an unbordered panel-coloured label floating over a panel-coloured window.

### L22 — The log window rises, but who has the keyboard

**Open:** start a run, and while it is running press Netlist and Run again.

**Look at:** (1) does the log window come to the front? (2) does your typing still go to
ASE-L, or has the log window taken it?

**Wrong:** the log window takes the keyboard. On your screen there is no window manager
answering the polite request to come forward, so the only way to raise that window is to
re-map it — and a re-map takes the keyboard with it. **If it does take it, say whether you
would rather the window not rise at all on your screen.** That is a one-line change and it is
yours to make; a gentler nudge and a focus restore were both tried and both do nothing on the
servers that need them.

---

## D. File > Open Recent — 1 look, ~2 min

### L23 — Your own recent-files list, and it is still damaged

⚠ **Measured today, not inherited:** your list still holds **ten dead simulation probe decks
and nothing of yours**.

**Open:** File > Open Recent.

**What to do:** the cause is fixed and will not happen again. **The list itself is yours to
repair, and nothing in this tree may touch it** — clearing or rebuilding it is the whole of
this item. There is nothing to judge.

---

## E. The hierarchical PDF — 4 looks, ~25 min

⚠ **Read the note below before booking time for this sitting.** This work is in a **different
copy of the program**, on a branch that is not currently checked out anywhere, so none of it
can be opened as things stand.

### L24 — Do the links still go where a reviewer expects

**Open:** export a real design hierarchically and open the PDF in a viewer. Click through it.

**Look at:** dead links were dropped and new ones added; twenty-three clicks that did nothing
are gone, primitives that had no link now have one, and very small instances became
clickable.

**Wrong:** something a reviewer relied on stopped being clickable. That is the only question
here, and only clicking can answer it.

### L25 — The blue box on clickable symbols: how much ink

**Open:** the same export. About one symbol in six now carries a thin blue box, on cells that
have real hierarchy and are not from a PDK.

**Look at:** is that the right amount of ink on a real review sheet — too much, too little, or
right?

**Wrong:** the sheet reads as busier than it is useful. Two other settings exist — box
everything, or box nothing, which is what shipped before — but **neither is reachable from any
menu**: exercising them means editing your own start-up file by hand.

### L26 — Pages that used to come out corrupted

**Open:** the four-panel picture this item produced. Eleven sheets in three hundred did not
convert at all, and the pages that did come out carried a solid grey block over half of one.

**Look at:** the before-and-after of that grey block · two pin rectangles that were solid
blobs and are now small open squares — is that what those devices should look like? · a
schematic whose text really does contain a backslash, which is now shown rather than swallowed
· and one sheet that asks for an oblique serif typeface and now gets one where it used to get
a plain sans.

**Wrong:** the *after* page is not the sheet you expect.

### L27 — The Back button and the parent list on every page

**Open:** any hierarchical export. This puts new ink on **every page**, and nobody has seen a
rendered page of it.

**Look at:** the top page, which has Back only; a page with one parent; and a page with two.
A picture of all three exists — on the branch named in the note below.

**Wrong:** the strip crowds the sheet, or the parent list is illegible at print size.

---

# The note on sitting E

**These ten items are in a second copy of the program**, and the work they describe lives on
a branch that neither copy currently has checked out. Measured today: the setting that draws
the blue box does not exist in either working tree, and the batch's own folder — including
the two pictures items L26 and L27 point you at — is not on disk in either place. It is all
present on that branch; nothing is lost.

**So sitting E costs a checkout before it costs a look**, and until someone does that, I
cannot tell you whether those ten are still current. They are the only ten of the 71 whose
staleness I could not check. They may all be fine; I am not guessing either way.

---

# What already existed, and why it did not help

**A collected page for these debts was built on 7 September and it is still in the
repository.** It covers **46** of them, sorted by what answering each would cost, with a
one-sentence question, a description of right and wrong, and either a picture or a short
recipe for each. It is good work and this document leans on it.

Three things went wrong with it, and they are worth a sentence each because the same thing
will happen again otherwise:

* **It was never acted on.** It recommended retiring ten entries. **Eight of those ten are
  still sitting in your queue today**, ten days later.
* **It was never kept up.** The queue was 46 when it was written and is 71 now. Twenty-five
  items filed since are not in it — including everything in sittings C and E.
* **It cannot be rebuilt.** Its eight photographs were never saved into the repository, so
  the page that referenced them can no longer be produced.

This document is the same idea, current as of today, and with the pictures replaced by
instructions you can follow on your own screen — which is what these items were always
asking for.

---

# Nothing here is invented

Every "what to open" above came from the queue entry itself, from the collected page, or from
reading the code that draws the thing. Where an entry's own text has gone out of date I said
so on the spot rather than passing it on: **L6**'s entry claims there is nothing to look at,
and there is.

**No item is listed as unanswerable.** The only thing I could not determine is the one named
in the note on sitting E — whether those ten PDF items are still current — and that is a
checkout away from being known, not a mystery.

---

# Reference

For whoever implements the answers. Nothing in this column needs to mean anything to you.

| Look | Queue entries it settles |
|---|---|
| L1 | `the_Results_Display_Window_itself__item_B3_`, `rdw_1355_chrome_and_dialog`, `rdw_1361_chrome_width_measured`, `rdw_close_button_column`, `the_RDW_line_cursor_shade`, `the_RDW_cursor_under_an_INACTIVE_selection` |
| L2 | `the_RDW_engineering_notation`, `the_RDW_dump_header_spelling__spec_op_param_lists.md_Q6_`, `rdw_1374_preamble`, `rdw_1300_narrowed_pane`, `the_RDW_s_five_new_sentences__item_B2d_`, `DD-5_analysis_sentence_in_the_Results_Display_Window` |
| L3 | `1339_R3_select_and_copy`, `1339_R3_selection_you_cannot_put_down`, `1344_rdw_copy_after_repair`, `1344_the_status_line_receipt_goes_stale`, `1344_two_highlights_after_a_status_line_drag`, `rdw_1365_status_scroll` |
| L4 | `the_B5_button_column_and_the_two_scope_dialogs`, `1338_R2__the_row_moves_under_your_eyes`, `1349_Delete_and_Add_now_wipe_the_pane_selection`, `1349_the_pane_order_flips_between_lists_on_Add`, `rdw_1358_keys_in_the_window` |
| L5 | `the_RDW_raise_behaviour`, `1369_the_keyboard_after_a_dump_on_your_own_server` |
| L6 | `rdw_keys_B4` *(entry text stale — keys landed)* |
| L7 | `the_RDW_at_text_size_20_and_at_6__and_the_aA_glyph_and_its_toolt` |
| L8 | `the RDW status-bar hint and its tooltip` |
| L9 | `balloon tooltips near a screen edge, tree-wide` |
| L10 | `descend_run_batch_no_flicker_on_the_ascend_re_descend_round_trip` |
| L11 | `chana_type_grid_1411`, `chana_typed_form_1417`, `ase_precheck_banner_1435`, `choose_analyses_handle_grid_1448`, `ase-picker-words-a2` |
| L12 | `ase_options_sheet_1441`, `ase-options-subdialog-1450`, `ase_effective_1442` |
| L13 | `ase_measurements_dialog_1451` |
| L14 | `ase_sp_ports_matrix_1454`, `sp-matrix-picker-3port` |
| L15 | `ase-campaign-histogram-and-progress-1464` |
| L16 | `ase-trnoise-section-1467` |
| L17 | `ase-digital-pane-run-end-1465` |
| L18 | `the_nodes_CKTncDump_starred__LIT_on_the_user_s_own_schematic__is` *(issue 1460)* |
| L19 | `the_Simulators_row_editor_s_new_line_saying_what_the_program_can` *(issue 1471)* |
| L20 | `ase_l_1396_overwrite_confirm` |
| L21 | `ASE-L action strip tooltips`, `ASE-L tooltips: two pixel effects no headless row can see` |
| L22 | `ASE-L refusal: the CIW rises but the keyboard stays in ASE-L` |
| L23 | `open_recent_1453` |
| L24 | `hier_pdf_links_1333`, `hier_pdf_links_1333_H1a`, `hier_pdf_links_1334_H1b`, `hier_pdf_links_route4`, `hier_pdf_links_1336_1337_H2` |
| L25 | `hier_pdf_links_1338_1339_H3`, `hier_pdf_links_1338_1339_H3_menu`, `hier_pdf_links_1338_H4` |
| L26 | `hier_pdf_links_1343_H5` |
| L27 | `hier_pdf_nav_1357_H6` |
| **Retire (10)** | `1340_R4_adversary_the_keyboard_after_a_dump`, `1343_rdw_raise_on_your_own_server`, `1341_R5_the_window_says_did_not_converge_when_the_formatter_fails`, `rdw_1356_note_cut_off_measured`, `rdw_1356_selection_note`, `rdw_1362_status_wrap`, `the_RDW_select_and_copy_on_VcXsrv`, `1338_R2_window_vs_sheet_disagree`, `hier_pdf_links_1338_H4` *(the earlier of two files)*, `ASE-L_Save_State_overwrite_confirm_popup` |

**The collected page** this document builds on: `doc/claude/lookdebt_batch/` (`debts.json`,
`build_page.py`, `page_shell.html`, `poses/`), built 2026-09-07 at `4ac6f182`. The PDF work of
sitting E is on branch **`op-wcard`** of the clone at `~/dev/xschem-op-wcard` (commits
`5866270d`, `24e09c65`, `e451892b`, `8e3f0e16`), together with
`doc/claude/hier_pdf_links_batch/H5_look.png` and `H6_look.png`.

**Read against** the ledger at `~/.claude/xschem_owed/look/` (71 files, 70 unique ids) and
`src/rdw.tcl`, `src/ase_window.tcl`, `src/cadence_style_rc`, `src/xschem.tcl` at revision
`420801f9`.
