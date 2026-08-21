# seed_calc_regions.tcl — eyeball aid, NOT a test.
#
# Serves the two Calculator wheel look debts (batch item 13 Part A, and the
# wheel-FEEL debt from the item-13 review): "does the mouse wheel scroll all
# three regions, and does a notch move a sane amount?"
#
# WHY IT IS NEEDED.  Phase 1 ships the Stack and the Buffer EMPTY — Push, Pop
# and the whole keypad are calc::inert until plan phase 4 — so two of the three
# scrollable regions have nothing in them and cannot be judged as they stand.
# This fills both with throwaway rows so the wheel has something to move.
#
# HOW TO RUN.  Open the Calculator first (Tools > Calculator).  Then, in the
# schematic window:  Tools > Execute TCL command  (accelerator '=').  If the
# input box already holds text, press `Clear Input` first — the dialog reopens
# with whatever was last in it and a second line would run as well.  Enter
#
#     source /path/to/doc/claude/calculator_batch/eyeball/seed_calc_regions.tcl
#
# then press **Evaluate** (there is no OK button; Shift-Return in the input box
# does the same).  The result pane prints how many rows and lines it put in.
# Re-run it any time to reset the contents; close the Calculator window and
# reopen it to get the empty phase-1 state back.
#
# It writes NOTHING to disk and touches no tracked file: the rows live in the
# two widgets and die with the window.  The Calculator does not persist them.
#
# The steps this is meant to feel like, from calc::wheel_areas: 5 rows a notch
# in the Stack, 50 pixels in the Buffer, 3 canvas units in the function browser
# (it was 1 before the item-13 review).  Shift + wheel scrolls sideways.
#
# The FUNCTION browser needs no seeding — but it holds only one notch of travel
# in the default `Special Functions` category, so switch its category combobox
# to `All` (108 entries) before you judge that region.  Use the combobox, not
# the wheel: ttk comboboxes are deliberately excluded from the wheel walk.

if {![winfo exists .calc]} {
    return "seed_calc_regions: the Calculator window is not open.\
 Open it with Tools > Calculator, then run this again."
}
foreach w {.calc.stk.list .calc.buf} {
    if {![winfo exists $w]} {
        return "seed_calc_regions: expected widget $w does not exist in this\
 build — the Calculator layout has moved and this aid needs updating."
    }
}

# The Stack: 12 rows, more than the 4-row default height.
.calc.stk.list delete 0 end
for {set i 0} {$i < 12} {incr i} {
    .calc.stk.list insert end [format "stack %2d   %.6g" $i [expr {1.234e-3 * ($i + 1)}]]
}

# The Buffer: 12 lines, each wide enough to need a sideways scroll as well.
.calc.buf delete 1.0 end
for {set i 1} {$i <= 12} {incr i} {
    .calc.buf insert end "buffer line $i   VT(\"/out\") + VT(\"/in\") * 1.0e-3\
   ;# long enough to need a sideways scroll too\n"
}
# drop the trailing newline, so the count below is 12 lines and not 12 plus an
# empty one.
.calc.buf delete "end - 1 chars"
update

return "seeded: stack = [.calc.stk.list size] rows,\
 buffer = [.calc.buf count -displaylines 1.0 end] display lines.\
 Now put the pointer over each region and roll the wheel."
