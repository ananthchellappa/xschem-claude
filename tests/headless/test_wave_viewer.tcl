# Waveform Viewer window shell + working core (items 11+12 of
# doc/claude/ase_l_batch, spec doc/claude/specs/waveform_viewer.md —
# src/wave_viewer.tcl + the ase.tcl raw_file backend hook):
#   V1  render_deck emits exactly one `write <rundir>/<cell>_ase.raw` line
#       inside .control...endc, after the print line (fixture state, op on)
#   V2  no write line when ALL analyses are disabled
#   V3  ase::backend_hook ngspice raw_file resolves -> <rundir>/<cell>_ase.raw
#   V4  real ngspice dc sweep (spec schema shape) through ase::netlist +
#       ase::run_deck -> exit 0 AND the raw artifact exists non-empty
#       (guarded: SKIP without ngspice)
#   V5  xschem raw read of the artifact: sim_type dc, points == 181,
#       vars >= 2, `raw loaded` >= 0 (INDEX semantics — never a boolean)
#   V6  embedded-graph regression: shipped test_ne555.sch loads (readonly),
#       keeps its layer-2 graph rect + flags=graph, redraws rc 0
#   G1-G9 GUI legs (DISPLAY-guarded self-SKIP): open viewer from a session
#       token (toplevel, registry, readonly, untitled buffer); strip SWEEP
#       (G1s, fixup: user-rc binds installed on the main .drw pre-open —
#       cadence_style_rc:109 verbatim <Key-i> + a Windows-arm-shaped
#       <Alt-KeyPress> — are cloned by clone_canvas_bindings onto the viewer
#       canvas and MUST be cleared there, main canvas keeps its own; plus a
#       completeness check: no sequence outside the keep+filter set); editor
#       TOOLBAR stripped per-window (G1t, fixup r2: toolbar_visible defaults
#       1 so pack_widgets shows 37 armed editing/simulator buttons on the
#       viewer — forced to 1 for determinism, widget exists but is not
#       pack-managed/mapped, main-window packedness unchanged, fresh G9
#       reopen stripped too); viewer
#       menubar attached (File/View/Graph/Cursors; since item 12 every
#       Graph+Cursors entry is LIVE — the item-11 "all disabled" assertion
#       flipped with the item-12 core),
#       editor menubar NOT attached; exact title + with_edit clobber
#       regression; window number > 0; strip (i/Insert/w do nothing: no
#       instance, no wire, no modify, no readonly MODAL — recording
#       tk_messageBox stub — no new toplevel; `i` reaches the FILTER, not
#       the cloned create_instance bind); ESC does not close; display_raw
#       (1 graph rect, node prop, raw points in the viewer ctx, redraw,
#       modified 0 + readonly restored, no untitled*~.sch autosave backup);
#       re-open raises the SAME window (number unchanged); Ctrl-W closes
#       with no prompt, registry cleaned, reopen builds a fresh window.
#   H1-H6 item-12 pure model->rect-props procs (BOTH arms, no window, no
#       xschem calls): graph_props template/token/alias/range/log emission,
#       band_geometry viewport tiling (item 18; replaced graph_geometry),
#       next_color palette cycle, validate_rpn token rules (save.c RPN table;
#       D4 pre-validation)
#   item 18 (graph-fills-win): the graph FILLS the viewer window, not a fixed
#       800x400 rect on a grid canvas. RG0 no_grid getter/setter roundtrip;
#       RG1/RG2 normal-window grid+embedded-graph regression (grid-off is
#       VIEWER-ONLY); H-band1..4 pure band tiling (single-fills / equal halves /
#       n=3 contiguous / nonzero-origin verbatim); GF1-GF5 GUI (single graph
#       covers the viewport, grid off here / on elsewhere, resize refits,
#       two graphs each fill a half, regenerate never re-frames the canvas).
#   G10-G17 item-12 viewer core (GUI, self-SKIP): Add Graph stacking +
#       model/rect/graphbb agreement; Add Trace from the raw-vars listbox
#       (count == `raw vars`, palette-head color); expression trace via
#       `xschem raw add` (db20) + bad expression surfaces IN-DIALOG (D4:
#       error label, no phantom vector, model unchanged, no throw); Axes
#       dialog log toggle + exact ranges; Delete dialog (one trace, then a
#       whole graph — remaining graphs re-stack from y 0); cursors A/B via
#       menu checkbuttons + bottom-bar readout showing eng-formatted x and
#       INTERPOLATED per-trace y cross-checked against the engine's
#       cursor-B ground truth (`raw value <var> {}` after `set cursor2_x`)
#       and proven different from the nearest raw sample; View>Fit = engine
#       autozoom + model read-back; no Graph/Cursors entry left disabled.
#   item 19 (graph-interact): wheel / RMB / f / View-zoom act on the GRAPH,
#       never the canvas (IX*, GUI self-SKIP). IX-vpan-up/dn plain wheel =
#       vertical graph pan (y1/y2 shift, opposite signs, x fixed); IX-hpan
#       Shift+wheel = horizontal pan; IX-zoom-in/out Ctrl+wheel = graph zoom in
#       BOTH axes on the pointed strip + IX-zoom-strips X-on-every-strip /
#       Y-on-the-pointed-one-only (issue 0144);
#       IX-menu-zoomin/out the View menu commands zoom the graph the same way
#       (both axes on the pointed strip, issue 0145); IX-fit Fit
#       reframes the graph data range with NO canvas zoom_full; IX-rmb a
#       synthetic Button-3 press+release box narrows the graph rect x-range via
#       btn3_filter -> the C engine. EVERY IX leg also asserts the canvas
#       xorigin/yorigin/zoom == a once-captured baseline (the graph-not-canvas
#       teeth). Pure Tcl; the C engine and binding table are unchanged.
#   WB* (issue 0152): the wave-BOLD toggle (`hilight_wave`) is a plain LMB
#       CLICK on the plot body, not a Button3 press — on the press it also
#       fired at the start of every RMB box-zoom drag. Needs the real raw
#       (find_closest_wave bails without one, so a data-less run would be
#       hollow). Full Tk sequences via the shipped bindings, each event with an
#       explicit increasing -time (two identical presses close together are
#       collapsed by Tk into <Double-Button-N>, which the viewer swallows).
#       Legs: LMB click bolds/un-bolds; RMB click and RMB box-zoom leave it
#       alone (and the zoom still happens); an LMB drag-pan does not bold (and
#       the pan still happens); the per-trace LEGEND RMB is unchanged.
#       ISSUE 0174 made the pick PRECISE: a click bolds a trace only within
#       GRAPH_TRACE_PICK_TOL (10) SCREEN PIXELS of it, and re-clicking the same
#       trace is what un-bolds. So the click pixel is now SCANNED (the engine's
#       own graph_trace_at) instead of being a fixed fraction of the widget —
#       (0.50W, 0.50H) is about 0.30*H from this fixture's only trace, which is
#       precisely how the old leg passed against a pick with no threshold.
#       WB-precise* are the new legs: a plot-body click far from every trace
#       bolds NOTHING and CLEARS whatever was bold, while a click on the
#       already-bold trace KEEPS it (both settled by the user at review — a
#       plain click never deselects what it lands on; that is 0175's Ctrl+click).
#       This fixture has ONE trace, so the
#       multi-trace half — moving the selection from trace A to trace B in one
#       click — lives in test_wave_trace_menu.tcl's TB* block.
#   KM* (2026-11-21): Ctrl-Shift-M in the viewer flips the plot mode of the
#       TARGET subwindow, and no key that arrives at a viewer's canvas reaches
#       an editor verb of the engine (doc/claude/specs/waveform_viewer.md,
#       "What the key filter forwards"). DISPLAY, real keys sent with their
#       pixel; needs the real raw like WB*, for the marker keys.
#         KM1  the chord (filter saw it, no box, nothing forwarded, mode, status
#              bar, one log line, tooltip flag); its silence in the command
#              window, beside the menu entry's; the wrapper and the canvas it
#              is called for; the default under the Cadence profile; a binding
#              of the user's own against every sequence of the tag, in the
#              stock profile and in the Cadence one
#         KM2  the keys that stay: Shift-M, m, Ctrl-m, and d (a delta marker);
#              the marker keys and the cursor keys a and b in both profiles
#         KM3  two subwindows
#         KM6  two tabs: the chord, and the graph keys on the second tab
#         KM4, KM5  Caps Lock and Num Lock
#         KM7  the chord while both cursors show; the Cadence profile's plain
#              s, and a typed Control-s in both profiles: the engine's cursors
#              and the readout bar
#         KM8  Alt, Super, Control-Alt and Control-Super with every graph key
#         KM9  the pixels just inside a strip's edge (two pixels in, and the
#              deepest the engine takes for the canvas; stock profile, then
#              Cadence), the middle of both strips, the first pixel the gate
#              must accept, and the middle of every strip of a window of more
#              than two, of two subwindows side by side, and of a window made
#              taller and put back (there also a pixel no strip held before)
#         KM10 graph_use_ctrl_key
#         KM11 a user's row in the engine's binding table (a canvas row for
#              bare m, a graph.forward row for the viewer's own Control chords,
#              a row for Escape)
#         KM13 every chord the filter forwards, sent through the real engine in
#              the four profiles
#         KM15 two viewer windows open at once: each takes its own b and its
#              own chord
#         KM14 (restated 2026-11-22; until then a declared limit) a key typed
#              with the focus on another window's canvas and the pointer in
#              the viewer's plot is the viewer's: Ctrl-Shift-M by both doors
#              (the binding tag on the schematic canvas, the engine's event
#              entry), its release, the pointer the viewer's context stores,
#              a key that a tag behind the viewer's own binds (F10), an error
#              in a binding, and the pointer deciding
#         KM16 from that state the editor keys do nothing (w, y, i, Alt-b, the
#              Cadence profile's s and b, and the three that open something)
#         KM17 from that state the graph keys act on the graph, both profiles,
#              typed on the main canvas and handed to the engine's event entry
#         KM23 a key typed while the viewer's own toplevel holds the keyboard
#              (where an open leaves it) is the viewer's with the pointer over
#              the plot and nobody's otherwise
#         KM18 a viewer that has just opened, and one that an open only
#              raises: where the focus is left and by what calls, the keys
#              typed over the schematic after it, and the chord without a
#              click in the focus state the display gives and with the focus
#              forced onto the main canvas
#         KM19 parity with Tk: every sequence of the WaveViewer tag, and six of
#              the row's own, chosen the same with the focus on the plot and
#              with the focus elsewhere; three sequences of the row's own in
#              the six orders of binding
#         KM20 the control (a key over the schematic is the schematic's, with
#              one viewer and with two) and two viewers (the chord goes to the
#              one under the pointer)
#         KM21 the fence: an ordinary second schematic window is untouched;
#              and a key typed in that window with the pointer in the plot is
#              the viewer's
#         KM22 a key typed into the Signal Browser's search box stays there
#         KM12 the fence: over a graph embedded in a schematic the same chords
#              do what they did before
#         G1f  (with the G rows; until 2026-11-22 a declared limit, restated
#              that day by the build of item 03b and again by its repair)
#              after an open, and after an open that only raises the window,
#              the keyboard focus inside the viewer's toplevel is on the
#              toplevel, which carries the viewer's key tag
#         CG-mmb (its second check) the middle-button pan's press three pixels
#              inside a strip's edge leaves the canvas where it was
#       NOTHING DANGEROUS IS SENT. Several of these chords are a reload, a Save
#       form or a new window once the engine gets them, and a prompt nothing
#       dismisses stops the suite. KM8 to KM11 ask the filter what it would
#       forward and send a real key only when it refuses the chord. KM13, whose
#       population is what the filter forwards, asks a comparand fed from the
#       engine (wvkey_engine.tcl) and sends a real key only when that allows
#       the chord. KM9's first-pixel legs send bare b only at a pixel past the
#       engine's own border. KM7's typed Control-s (off a graph it is Save) is
#       sent only in the middle of a strip and only when the filter, asked
#       first, forwards it as typed.
#       RED FIRST, measured by the build on the product before the change:
#       every row it wrote but the fixtures and put-back legs, KM1's "reaches
#       the filter" and tooltip flag legs, KM2's tooltip leg and KM9's control.
#       KM12 is a fence and was green there by construction: its expected
#       values were taken there. The first repair measured red first KM11's
#       graph.forward leg and its Escape leg. The legs of the second repair
#       (KM1's walk of the tag, KM2's d, KM6, KM7's readout, KM9's first
#       pixel, KM13's question to the comparand, KM14) were written against a
#       product that was right; each is held by a break below. (KM14 was
#       then a declared limit of two checks: the first stated what the
#       unchanged engine did and no break held it, the second sent the chord
#       and went red with it. Item 03b restated the row on 2026-11-22 and both
#       checks are gone; the last section of this header has its breaks.)
#       The legs of the
#       third repair (KM1's tag walk in the Cadence profile and its
#       command-window leg, KM7's typed Control-s, KM9's window of more than
#       two strips, CG-mmb's press in the border, G1f) were written against a
#       product that was right as well; each is held by a break of the
#       second list below. (G1f was then a declared limit too, held by the
#       change it said had not been made. It has been restated since: the
#       last section.)
#       The legs of the fourth repair (KM2's two profiles, KM6's graph keys
#       on the second tab, KM7's chord with the cursors showing, KM9's two
#       subwindows and its window made taller, KM15) were written against a
#       product that was right too; each is held by a break of the third
#       list below.
#       SABOTAGES, test_wave_viewer on the display arm. Every line of this
#       first list was measured again in the third repair, with all the rows
#       above in place, and names EVERY row that went red:
#         no Ctrl-Shift-M default            -> KM1, KM3, KM4, KM5, KM6, KM10,
#                                               KM11, KM14
#         key_chord back to the keysym decision (every graph key but Ctrl-b,
#           Ctrl-d)                          -> KM1 to KM11, KM13, KM14
#         the filter made to forward Ctrl-Shift-M (the arm list gains the
#           pair, graphown loses the keysym) -> KM1 to KM6, KM9, KM10, KM11,
#                                               KM13, KM14
#         key_filter gated on the mouse mirror again -> KM9
#         graph_border_px answers 0          -> KM9
#         graph_border_px is int(5 * scaling) -> KM9
#         the pixel gate ten pixels wider than the border, or one pixel
#           wider                            -> KM9, each
#         the pixel gate skipped in the Cadence profile, for plain s or for
#           every graph key                  -> KM9, each
#         key_at_graph looks at the first strip only -> KM9
#         chord_state keeps Num Lock         -> KM5
#         case_pairs without m               -> KM4
#         the wrapper retargets a fixed strip first -> KM3
#         the wrapper without its foreign-canvas test -> KM1
#         the wrapper asks the mouse mirror where the pointer is -> KM1, KM14
#         the wrapper does nothing in a window with two tabs -> KM6
#         the default installed only outside the Cadence profile -> KM1
#         the default installed over whatever the tag holds; the same for
#           another default (Ctrl-G); the Caps Lock dispatch installed over
#           whatever the tag holds           -> KM1, each
#         no reroute of the Cadence profile's plain s -> KM7, KM9
#         key_filter forwards the state as typed, not key_chord's -> KM7, KM13
#         the cursor tail skipped for a key that goes out with another state
#           than typed; the tail skipped for b -> KM7, each
#         d forwarded without the edit bracket -> KM2
#         no graph_use_ctrl_key rule         -> KM10, KM13
#         a table row that is no graph row is ignored -> KM11
#         graphguards without Shift-M's pair -> KM2, KM9
#         key_chord without its refusal by name; graphown without M; graphown
#           without b                        -> KM11, each
#         Escape always forwarded; a row but no verb -> KM11, each
#         the border factor changed in the TEXT of src/callback.c, the binary
#           not rebuilt                      -> KM9
#       THE THIRD REPAIR's own breaks, each green in every viewer suite
#       before its leg existed:
#         the pixel gate knows the first two strips only -> KM9
#         the pixel gate knows every strip but the last -> KM9, CA8
#         in the Cadence profile the Ctrl-Shift-M default goes in over
#           whatever the tag holds           -> KM1
#         the wrapper echoes a line of its own, through ciw_echo or through
#           wviewer::echo                    -> KM1, each, and each again
#                                               with an action log open
#                                               (run_suites.sh --logdir, the
#                                               arm the full regression runs)
#         strip_at_pixel_inset hands the band test no inset -> CG-mmb; the
#           canvas is then panned for the rest of the suite and CG-shift-b1,
#           WB-click, WB-lmb-drag, WB-mmb-drag, SD4 and IX-fit follow it
#         the cursor tail skipped for a typed Control-s -> KM7
#         wviewer::open gives the focus to the plot canvas -> G1f (as G1f
#           stood then. The row has been restated twice since; the break,
#           built again against the rows as they stand, is in the last
#           section of this header.)
#       THE FOURTH REPAIR's breaks. This suite was green under each before
#       the repair (measured by the attack that found them). Each was built,
#       went red on the one row named and on no other row of this suite, on
#       the display arm and again with an action log open, and was put back:
#         the pixel gate keeps only the bands that share the first band's
#           left edge (the right-hand subwindow takes no graph key) -> KM9
#         the pixel gate says no on every tab but the first -> KM6
#         the pixel gate remembers a canvas's bands by its strip count
#           (the old geometry after a resize) -> KM9
#         the pixel gate says yes for the first viewer canvas of the
#           session only                     -> KM15
#         the wrapper flips the first viewer of the registry, whichever
#           canvas the key came from         -> KM15
#         the wrapper does nothing while a cursor shows -> KM7
#         in the Cadence profile m and d are forwarded without the edit
#           bracket                          -> KM2
#         in the Cadence profile the cursor tail is skipped for a and b
#                                            -> KM2
#       NOT caught in this suite: graph_border_px answering one constant
#       (the formula's own answer at the Tk scaling of the display this ran
#       on), and strip_at_pixel_inset using its own inset whatever the
#       caller gives. Row SWK25 of test_wave_subwindows catches both, on
#       both arms.
#       NOT measured again (the engine would have to be rebuilt):
#         ENGINE (src/callback.c, rebuilt): a graph guard put in front of the
#           Cadence arm of `case 's'`        -> KM12, measured by the build
#       A KEY THAT CAME THROUGH ANOTHER WINDOW (2026-11-22; rows KM14, KM16
#       to KM23 and G1f; the build of overnight item 03b, then its first
#       repair the same day).
#       RED FIRST on the product before the item, on the display arm: G1f;
#       every check of KM14 but "the pointer decides"; KM16 to KM20; of KM21
#       the tag check and the check for a key typed in the second window;
#       KM23. Green there by construction: KM14's "the pointer decides",
#       KM21's first check (a fence: its expected values were taken there),
#       KM22 (a control), the fixtures.
#       RED on the product of the build, before the repair, on the display arm
#       and again with an action log open: G1f, KM18, KM23 and the error check
#       of KM14. The repair's other new legs were right on that product,
#       each written for a break the attack built and no row caught (below):
#       KM14's F10 check, KM17's b by the engine's entry, KM21's check for
#       the second window. The open's calls of `focus`, which KM18 records,
#       were plain there too. KM19's order-of-binding leg was right there as
#       well; of the breaks below it sees those of tag_key_seq named "the
#       first match wins", "the newest binding first" and "modifiers equal",
#       which the row's first half sees too.
#       BREAKS of the product. Each was built on a scratch copy of the tree
#       (made the same as this tree before and after every break), run on the
#       display arm, and EVERY row that went red is named. All were built by
#       the repair, with the rows as they stand, except the two under "THE
#       BUILD'S MEASUREMENT" and the paragraph after them.
#       The rows of test_wave_subwindows that go red with the breaks of the
#       pure procs are in that suite's header.
#         src/wave_viewer.tcl:
#         foreign_key never takes the key   -> KM14 (every check but the
#           fixture and "the pointer decides"), KM16 to KM20, KM21 (the
#           second-window check), KM23
#         key_door never takes it (the engine's door alone)
#                                            -> KM14 (the chord, its release,
#                                               Caps Lock, the status bar,
#                                               F10), KM16, KM17, KM19, KM21
#                                               (the second-window check)
#         key_door answers for the main window's canvas only
#                                            -> KM21 (the second-window check)
#         the tag's KeyPress binding without its break
#                                            -> KM14 (the chord, its release,
#                                               Caps Lock, the status bar,
#                                               F10), KM16 to KM20, KM21 (the
#                                               second-window check)
#         the tag without its KeyRelease binding -> KM14 (the release)
#         the tag put last in a canvas's tag list -> KM14 (the fixture, the
#           chord, its release, Caps Lock, the status bar, F10), KM16 to
#           KM20, KM21 (the tag, the second-window check)
#         foreign_key does not ask where the pointer is
#                                            -> KM14 (the pointer decides)
#         foreign_key takes the key only with the pointer on the plot canvas
#                                            -> KM14 (the status bar)
#         foreign_key runs the WaveViewer tag only (no filter)
#                                            -> KM14 (every check but the
#                                               fixture and "the pointer
#                                               decides"), KM16, KM17, KM19,
#                                               KM21 (the second-window
#                                               check), KM23
#         foreign_key runs the canvas's own binding only (no tag)
#                                            -> KM14 (the chord, its release,
#                                               the engine's entry, Caps
#                                               Lock, the status bar), KM18,
#                                               KM19, KM20, KM21 (the
#                                               second-window check), KM23
#         foreign_key runs every tag of the viewer's canvas, the ones behind
#           WaveViewer too                   -> KM14 (F10)
#         an error in a binding does not stop the walk of the tags
#                                            -> KM14 (the error)
#         the filter is handed the pointer's place on the screen, not its
#           pixel in the canvas              -> KM14 (the chord, the engine's
#                                               entry), KM23
#         foreign_key gives the viewer's canvas the focus
#                                            -> KM14 (the chord, the engine's
#                                               entry, the status bar, F10),
#                                               KM23
#         foreign_key takes a press only     -> KM14 (the release, the
#                                               engine's entry, Caps Lock,
#                                               F10), KM16, KM19, KM21 (the
#                                               second-window check), KM23
#         a key with no keysym name handed on with an empty name
#                                            -> KM14 (that check)
#         the fields of a script without the keysym name
#                                            -> KM14 (the chord, the engine's
#                                               entry), KM23
#         tag_key_seq: the first match wins; it walks the newest binding
#           first; no rule that a keysym beats none; Lock read as no
#           modifier                         -> KM19, each
#         tag_key_seq wants the state's modifiers equal to the sequence's
#                                            -> KM14 (the chord, its release,
#                                               the engine's entry, Caps
#                                               Lock, the status bar), KM16,
#                                               KM19, KM23
#         key_seq_event reads a release as a press -> KM14 (the release, the
#           engine's entry, Caps Lock, F10), KM16, KM19, KM21 (the
#           second-window check), KM23
#         THE OPEN (the repair):
#         wviewer::open gives the plot canvas the focus, in its fresh arm or
#           in the arm that only raises (what the build had)
#                                            -> G1f, KM18, each
#         wviewer::open asks for the focus with -force, in its fresh arm or
#           in the arm that only raises      -> KM18, each
#         THE VIEWER WINDOW'S OWN DOOR (the repair):
#         top_key never takes the key        -> KM18, KM23
#         the open does not put the tag on the toplevel -> G1f, KM18, KM23
#         the tag put last in the toplevel's tag list -> G1f
#         top_key takes the key with the pointer anywhere in the viewer's
#           window; its KeyPress binding breaks; the tag without its
#           KeyRelease binding               -> KM23, each
#         the door bound on the toplevel's PATH, which is a tag of every
#           window inside it, not on a tag of its own -> G1f, KM22, and with
#           them CA5, KM2, KM4 to KM7, KM9 to KM11 and KM15: every key
#           typed on the plot canvas then reaches the filter twice
#         src/callback.c, rebuilt:
#         no guard                           -> KM14 (the engine's entry),
#                                               KM16, KM17
#         the guard for a press only         -> KM14 (the engine's entry),
#                                               KM16
#         the event's pixel written into the context above the guard; no
#           keysym name handed over          -> KM14 (the engine's entry),
#                                               each
#         the guard counted as a level of callback() (the semaphore up while
#           the viewer's side runs)          -> KM17
#         THE BUILD'S MEASUREMENT, not built again by the repair:
#         the canvas door's tag left on the viewer's own canvas -> KM1, KM3
#           to KM7, KM10, KM11, and the suite then stalls until its driver's
#           timeout
#         the guard also for a key from the context's own canvas -> the
#           suite stalls until its driver's timeout (row SWK34 of
#           test_wave_subwindows names it)
#       NOT caught in this suite (the build's measurement): the guard asking
#       under has_x 0, the guard asking for every context, key_subst without
#       its %% rule, and the three breaks of the middle-button pan's inset.
#       Rows SWK34, SWK33 and SWK35 of test_wave_subwindows catch them.
#
# Honest assertability (spec D8): headless/GUI legs can assert raw
# points/vars/sim_type, layer-2 rect count/props, redraw rc 0 and
# modified-still-0; the actual PIXEL rendering of the waves is eyeball-only
# and is NOT asserted anywhere.
#
# Runs via full_audit's DEFAULT arm (GUI legs self-SKIP without a usable
# display). Standalone repro from the repo ROOT:
#   ./src/xschem --nogui --pipe -q --nolog --script tests/headless/test_wave_viewer.tcl
# (drop --nogui and provide DISPLAY for the GUI legs)

set fail 0; set npass 0
proc check {name got exp} {
  global fail npass
  if {$got eq $exp} { puts "ok:   $name"; incr npass } \
  else { puts "FAIL: $name -> {$got} (exp {$exp}) : FAIL"; incr fail }
}
proc check_true {name cond} { check $name [expr {$cond ? 1 : 0}] 1 }

# recent-files gate (issue 0119): this script loads real cells
set no_recent_files 1

# --- locations (cwd-independent) --------------------------------------------
set here    [file normalize [file dirname [info script]]]      ;# tests/headless
set repo    [file normalize [file join $here .. ..]]           ;# repo root
source [file join $here scratch.tcl]
set scratch [test_scratch wviewer]

## ISOLATION FROM WHOEVER'S ~/.xschem/ase_simulators IS LIVE (issue 1377).
test_sim_registry_isolate     ;# issue 1377: the registry below is OURS, not ~/.xschem's
## V4 and everything below it run ngspice for real and read the raw back by
## vector name. MEASURED before this line: ALL PASS (401) under the developer's
## HOME and under a HOME with no registry, but under a registry naming a WORKING
## build with `-casemode distinguish` the ASE-L preflight REFUSES the run
## ("'-i(v1)' -- current 'v1' is not in the netlist") and the suite stops at
## 1 FAILED (6 passed): 395 rows never run and nothing says so but the count.
check "ISO1377 the suite runs against an empty simulator registry, not the one in ~/.xschem" \
  [test_sim_registry_state] {0 {} {} path}

set cellroot  [file join $repo sky130A xschem_libs sky130_tests test_nfet_final]
set statefile [file join $cellroot ngspice_state1 test_nfet_final.state]
set schfile   [file join $cellroot schematic test_nfet_final.sch]
set modelsdir [file join $repo sky130A models libs.tech combined]

# model resolution exactly as sky130A/cadence_style_rc sets it
set ::SKYWATER_MODELS $modelsdir

# scratch registry pointing at the REAL committed trees (test_ase_final
# pattern — never the pre-batch-dirty workarea library.defs)
set f [open [file join $scratch library.defs] w]
puts $f "DEFINE sky130_tests [file join $repo sky130A xschem_libs sky130_tests]"
puts $f "DEFINE sky130_fd_pr [file join $repo sky130A xschem_libs sky130_fd_pr]"
puts $f "DEFINE devices [file join $repo xschem_libs_newsym devices]"
close $f
set ::XSCHEM_LIBRARY_DEFS [file join $scratch library.defs]
set ::library_registry_defs_only 1
set ::XSCHEM_LIBRARY_PATH {}

set rundir  [file normalize [file join $scratch run]]
set rawpath [file join $rundir test_nfet_final_ase.raw]

if {[catch {

# --- fixture state: COPY of the committed .state, scratch rundir, dc sweep
# enabled per the spec schema shape (the committed fixture is never written)
set st [ase::state_load $statefile]
dict set st rundir $rundir
set an {}
foreach a [dict get $st analyses] {
  if {[dict get $a type] eq {dc}} {
    set a [dict create type dc enabled 1 source V2 start 0 stop 1.8 step 0.01]
  }
  lappend an $a
}
dict set st analyses $an

# --- V1: write emission (op enabled in the fixture) --------------------------
set render [ase::backend_hook ngspice render_deck]
set netlist_stub {* stub circuit
V1 D GND 1
.end
}
set deck [$render $st $netlist_stub]
set nwrite 0
foreach line [split $deck "\n"] {
  if {$line eq "write $rawpath"} { incr nwrite }
}
## ⚠ 0929: ONE `write` PER ENABLED ANALYSIS, not one per deck. ngspice's `write`
## writes the CURRENT plot and every analysis makes a new one, so the single
## trailing write this row used to pin stored ONLY the last analysis -- the
## reported defect being an op+tran bench where `6` answered "these are from a
## 'tran' run instead". This fixture enables op AND dc, so it is exactly the
## two-plot case: two writes, and `set appendwrite` so the second appends rather
## than truncating the first.
check "V1 0929 one write line per ENABLED analysis, with the exact raw path" \
  $nwrite 2
check "V1 0929 appendwrite is emitted once, ahead of them" \
  [regexp -all -line {^set appendwrite$} $deck] 1
set cidx [string first "\n.control\n" $deck]
set pidx [string first "\nprint -i(v1)\n" $deck]
set widx [string first "\nwrite $rawpath\n" $deck]
set aidx [string first "\nset appendwrite\n" $deck]
set eidx [string first "\n.endc\n" $deck]
## The Outputs pane's `print -i(v1)` used to sit below the writes. Since
## 2026-10-11 the deck carries no print for an output at all (the user ruled
## output expressions out of the netlist, ase_l.md R-OUT1), so the row asserts
## its absence.
check_true "V1 0929 appendwrite then writes, all inside .control and before\
 .endc, and no output print anywhere" \
  [expr {$cidx >= 0 && $aidx > $cidx && $widx > $aidx && $pidx < 0 &&
         $eidx > $widx}]

# --- V2: all analyses disabled -> NO write line ------------------------------
set st2 $st
set an2 {}
foreach a [dict get $st2 analyses] { lappend an2 [dict replace $a enabled 0] }
dict set st2 analyses $an2
set deck2 [$render $st2 $netlist_stub]
check_true "V2 no write line while every analysis is disabled" \
  [expr {![regexp -line {^write } $deck2]}]

# --- V3: the raw_file backend hook -------------------------------------------
set rfhook [ase::backend_hook ngspice raw_file]
check_true "V3 raw_file hook resolves to a command" \
  [expr {[info commands $rfhook] ne {}}]
check "V3 raw_file returns <rundir>/<cell>_ase.raw" [$rfhook $st] $rawpath

# --- V4/V5: real ngspice dc sweep -> raw artifact -> raw read (guarded) ------
set have_raw 0
if {[auto_execok ngspice] eq {}} {
  puts "SKIPPED: V4/V5 run legs (ngspice not found)"
} else {
  # make the design the CURRENT schematic so ase::netlist works both headless
  # and under has_x (its GUI arm refuses when another schematic is current)
  xschem load $schfile
  set nl [ase::netlist $st]
  set id [ase::run_deck $st $nl]
  set ec [ase::wait $id]
  check "V4 ngspice exit code 0" $ec 0
  check_true "V4 raw artifact produced, non-empty" \
    [expr {[file isfile $rawpath] && [file size $rawpath] > 0}]
  if {[file isfile $rawpath] && [file size $rawpath] > 0} { set have_raw 1 }

  # error-guarded query: `xschem raw sim_type/points/...` THROW when nothing
  # is loaded — a missing artifact must FAIL these checks, not abort the test
  proc rawq {script} {
    if {[catch {uplevel 1 $script} r]} { return "ERR:$r" }
    return $r
  }
  set rc [rawq {xschem raw read $rawpath dc}]
  check "V5 raw read returns 1" $rc 1
  check "V5 sim_type is dc" [rawq {xschem raw sim_type}] dc
  check "V5 points == 181 (dc 0..1.8 step 0.01)" [rawq {xschem raw points}] 181
  check_true "V5 vars >= 2" \
    [expr {[string is integer -strict [rawq {xschem raw vars}]] &&
           [rawq {xschem raw vars}] >= 2}]
  check_true "V5 raw loaded index >= 0 (INDEX semantics, never boolean)" \
    [expr {[string is integer -strict [rawq {xschem raw loaded}]] &&
           [rawq {xschem raw loaded}] >= 0}]
  catch {xschem raw clear}
}

# --- RG0: no_grid getter/setter roundtrip (item 18; per-window flag, default 0)
# Ends at 0 so the RG1 (normal window keeps its grid) assertion below holds.
check "RG0 no_grid defaults 0 on a normal ctx" [xschem get no_grid] 0
xschem set no_grid 1
check "RG0 no_grid reads back 1 after set" [xschem get no_grid] 1
xschem set no_grid 0
check "RG0 no_grid cleared back to 0" [xschem get no_grid] 0

# --- V6: embedded-graph regression (shipped file, readonly) ------------------
xschem load [file join $repo xschem_library examples test_ne555.sch]
xschem set readonly 1
check_true "V6 shipped schematic keeps its layer-2 graph rect(s)" \
  [expr {[xschem get rects 2] > 0}]
check "V6 first layer-2 rect keeps flags=graph" \
  [xschem getprop rect 2 0 flags] graph
check "V6 redraw rc 0 on the readonly graph schematic" [catch {xschem redraw}] 0

# --- RG1/RG2: normal-window grid + embedded-graph regression (item 18, D7) ----
# The grid-off + fill behavior is VIEWER-WINDOW-ONLY: a plain file load never
# enters wviewer::, so no_grid stays 0 (grid draws) and the embedded graph rect
# is geometrically untouched.
check "RG1 normal window keeps no_grid 0 (grid still draws)" \
  [xschem get no_grid] 0
check_true "RG2 embedded graph rect present on the normal window" \
  [expr {[xschem get rects 2] >= 1}]
check "RG2 redraw rc 0 on the normal graph window" [catch {xschem redraw}] 0

# --- H1-H6: item-12 pure model->props procs (both arms; no window) -----------

# H1: single plain trace -> add_graph-template props with node/color filled
set Gh [dict create traces [list [dict create expr {v(d)} name {} vec {v(d)} \
        color 4]] logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
set ph [wviewer::graph_props $Gh]
check_true "H1 props carry flags=graph" \
  [expr {[string first "flags=graph" $ph] >= 0}]
check_true "H1 props carry node=\"v(d)\"" \
  [expr {[string first "node=\"v(d)\"" $ph] >= 0}]
check_true "H1 props carry color=\"4\"" \
  [expr {[string first "color=\"4\"" $ph] >= 0}]
check_true "H1 logx=0 line" [regexp -line {^logx=0$} $ph]
check_true "H1 logy=0 line" [regexp -line {^logy=0$} $ph]

# H2: alias + multi-trace -> quoted "alias;vec" token (backslash-escaped in
# the in-memory prop form) AND the plain token; color count == trace count
set Gh2 [dict create traces [list \
  [dict create expr {v(d)} name drain vec {v(d)} color 4] \
  [dict create expr {v(g)} name {} vec {v(g)} color 5]] \
  logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
set ph2 [wviewer::graph_props $Gh2]
check_true "H2 alias token \\\"drain;v(d)\\\" present" \
  [expr {[string first "\\\"drain;v(d)\\\"" $ph2] >= 0}]
check_true "H2 plain second token v(g) closes the node attr" \
  [expr {[string first "\nv(g)\"" $ph2] >= 0}]
regexp {color="([^"]*)"} $ph2 -> ph2c
check "H2 color has exactly 2 entries" [llength $ph2c] 2

# H3: explicit ranges + logy override the template defaults
set Gh3 [dict create traces [list [dict create expr {v(d)} name {} vec {v(d)} \
        color 4]] logx 0 logy 1 x1 0 x2 1.8 y1 {} y2 {}]
set ph3 [wviewer::graph_props $Gh3]
check_true "H3 x1=0 line" [regexp -line {^x1=0$} $ph3]
check_true "H3 x2=1.8 line" [regexp -line {^x2=1.8$} $ph3]
check_true "H3 logy=1 line" [regexp -line {^logy=1$} $ph3]

# H-band: viewport-relative equal vertical bands (item 18 replaces the old
# fixed 800x400 / i*450 graph_geometry slots — geometry is now viewport-
# relative, so a graph always FILLS its band of the live window).
# H-band1: single graph fills the whole viewport
check "H-band1 single graph fills the whole viewport" \
  [wviewer::band_geometry 0 1 0 0 1000 800] {0 0 1000 800}
# H-band2: two equal full-width bands, top then bottom
check "H-band2 top half" \
  [wviewer::band_geometry 0 2 0 0 1000 800] {0 0 1000 400}
check "H-band2 bottom half" \
  [wviewer::band_geometry 1 2 0 0 1000 800] {0 400 1000 800}
# H-band3: n=3 tiling — contiguous (band i+1 top == band i bottom), the union
# spans [vy1,vy2], all three share the full width [vx1,vx2]
set hb0 [wviewer::band_geometry 0 3 0 0 1000 800]
set hb1 [wviewer::band_geometry 1 3 0 0 1000 800]
set hb2 [wviewer::band_geometry 2 3 0 0 1000 800]
check_true "H-band3 band1 top == band0 bottom (contiguous)" \
  [expr {[lindex $hb1 1] == [lindex $hb0 3]}]
check_true "H-band3 band2 top == band1 bottom (contiguous)" \
  [expr {[lindex $hb2 1] == [lindex $hb1 3]}]
check_true "H-band3 union spans the full viewport height" \
  [expr {[lindex $hb0 1] == 0 && [lindex $hb2 3] == 800}]
check_true "H-band3 all three bands share the full width" \
  [expr {[lindex $hb0 0] == 0 && [lindex $hb0 2] == 1000 &&
         [lindex $hb1 0] == 0 && [lindex $hb1 2] == 1000 &&
         [lindex $hb2 0] == 0 && [lindex $hb2 2] == 1000}]
# H-band4: a nonzero-origin viewport is used VERBATIM (proves the geometry is
# viewport-relative, not hardcoded 0/800)
check "H-band4 nonzero-origin viewport used verbatim" \
  [wviewer::band_geometry 1 2 -100 -50 900 550] {-100 250 900 550}

# H5: color auto-cycle (palette 4 5 7 8 9 12 14 15 10 11)
set Gh5a [dict create traces {} logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
check "H5 fresh graph -> palette head 4" [wviewer::next_color $Gh5a] 4
set Gh5b [dict create traces [list [dict create vec a color 4] \
          [dict create vec b color 5]] logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
check "H5 graph using {4 5} -> 7" [wviewer::next_color $Gh5b] 7
set trs {}
foreach c {4 5 7 8 9 12 14 15 10 11} {
  lappend trs [dict create vec v$c color $c]
}
set Gh5c [dict create traces $trs logx 0 logy 0 x1 {} x2 {} y1 {} y2 {}]
check "H5 full palette wraps deterministically (10 % 10 -> head)" \
  [wviewer::next_color $Gh5c] 4

# H6: RPN pre-validation (D4) against the save.c token table
check "H6 valid expr {v(d) db20()} ok" \
  [wviewer::validate_rpn {v(d) db20()} {v(d)}] {}
set e6a [wviewer::validate_rpn {v(d) bogus()} {v(d)}]
check_true "H6 bogus() rejected + named" [string match {*bogus()*} $e6a]
set e6b [wviewer::validate_rpn {v(nosuch) db20()} {v(d)}]
check_true "H6 v(nosuch) rejected + named" [string match {*v(nosuch)*} $e6b]
check "H6 bare net d accepted via the v() wrap rule" \
  [wviewer::validate_rpn {d db20()} {v(d)}] {}
check "H6 number tokens accepted (1k 2.5 -3)" \
  [wviewer::validate_rpn {1k 2.5 -3 + +} {v(d)}] {}

# --- X1-X9: issue 0187, wviewer::ctx_verdict (BOTH arms) ---------------------
# `wviewer::open`'s "did the context follow?" guard was
#   `if {[xschem get current_win_path] ne $wp}`
# and `wp` had just been READ from current_win_path, with no update and no event
# loop in between -- a value compared with itself, which can never fire. The five
# per-context brands below it (readonly / no_grid / no_snap / graph_snap_cursor /
# wave_viewer) could therefore land on a user's live schematic. The decision now
# lives in the pure proc `wviewer::ctx_verdict`, which is why X1-X7 need no
# window at all and run in the true-headless arm too.
set X_ok0 {ok .x2}
check "X1 ctx_verdict ok on a toplevel this call created" \
  [wviewer::ctx_verdict .x2.drw {.drw .menubar .x1} {.drw .menubar .x1 .x2} 0 0] \
  $X_ok0
check "X2 ctx_verdict refuses the ROOT window" \
  [wviewer::ctx_verdict .drw {} {.drw} 0 0] \
  {err {could not give the waveform viewer its own window}}
# 0187 trigger A: all MAX_NEW_WINDOWS slots used, create_new_window() returns
# before creating anything, rc 0 and no Tcl error -> no new toplevel, context
# never moved. This is the shape the old guard sailed straight through.
set X3v [wviewer::ctx_verdict .x19.drw {.drw .x19} {.drw .x19} 0 0]
check "X3 ctx_verdict refuses when NO new toplevel appeared (0187 trigger A)" \
  $X3v {err {the waveform window did not take the context, refusing}}
# the semaphore-lag shape: a new toplevel DID appear, but the context stayed on
# a pre-existing one (measured: the switch no-ops, and can even land backwards)
check "X4 ctx_verdict refuses a PRE-EXISTING toplevel even when a new one appeared" \
  [wviewer::ctx_verdict .x5.drw {.x1 .x5} {.x1 .x5 .x9} 0 0] \
  {err {the waveform window did not take the context, refusing}}
check "X5 ctx_verdict refuses a context holding instances" \
  [wviewer::ctx_verdict .x2.drw {.x1} {.x1 .x2} 6 0] \
  {err {refusing to brand a window that holds a schematic}}
check "X6 ctx_verdict refuses a context holding wires" \
  [wviewer::ctx_verdict .x2.drw {.x1} {.x1 .x2} 0 10] \
  {err {refusing to brand a window that holds a schematic}}
check "X7 ctx_verdict messages carry no wviewer: prefix (open owns it)" \
  [string match {wviewer:*} [lindex $X3v 1]] 0

# X8: the C precondition behind trigger A -- create_new_window() is SILENT when
# the slots run out (no Tcl error, rc 0, context unmoved). DISPLAY arm skips it:
# it costs ~57s and 19 real toplevels there versus ~65ms true-headless, and it
# would also eat every free slot for anything that ran after it. It asserts C
# behaviour this Tcl fix does not change, so the cheap arm is enough.
if {![info exists ::has_x]} {
  set X8prev [xschem get current_win_path]
  set X8rc 1; set X8err {}; set X8stuck 0; set X8n 0
  for {set i 1} {$i <= 25} {incr i} {
    set X8rc [catch {xschem load_new_window -window {}} X8err]
    set X8now [xschem get current_win_path]
    if {$X8now eq $X8prev} { set X8stuck 1; set X8n $i; break }
    set X8prev $X8now
  }
  check_true "X8 0187 trigger A precondition: create_new_window is silent when slots are full" \
    [expr {$X8stuck && $X8rc == 0 && $X8err eq {}}]
} else {
  puts "SKIPPED: X8 slot-exhaustion probe (DISPLAY arm; ~57s + 19 toplevels)"
}

# X9 is a SOURCE-SHAPE PIN, deliberately brittle: it is the only check that can
# catch a reintroduction of the circular guard, which by construction changes no
# behaviour and so cannot be caught by any behavioural check. A later refactor
# that merely re-wraps that line will trip it for the wrong reason -- if that
# happens, confirm the comparison is really gone and update the regexp.
set X9body [info body ::wviewer::open]
check "X9 wviewer::open no longer compares current_win_path with itself" \
  [regexp {xschem get current_win_path\] ne \$wp} $X9body] 0

# --- GUI legs (DISPLAY-guarded self-SKIP) ------------------------------------
if {[info exists ::has_x] && [info commands winfo] ne {}} {

  # deliver a REAL generated key event $ev to $w, WSLg-robustly (the
  # send_key helper pattern from test_ase_dialogs.tcl: Tk redirects GENERATED
  # KeyPress events to the display's focus window and the WSLg focus
  # round-trip is asynchronous — gate every generate on Tk reporting $w as
  # the focus owner and retry until $done, an expr evaluated in the CALLER's
  # scope, turns true). Returns 1 on proven delivery, 0 on ~10s timeout.
  # ⚠ `gargs` (issue 1617) is NOT cosmetic. A graph-context chord is routed by the
  # POINTER, not by the keystroke: callback() recomputes xctx->mousex/mousey from
  # the event's own %x/%y for EVERY event type, KeyPress included (src/callback.c,
  # `xctx->mousex=X_TO_XSCHEM(mx)`), and waves_selected() then asks whether THAT
  # point is inside a graph rect. A key generated with no -x/-y therefore decides
  # the graph context from whatever Tk defaults those fields to, which for the
  # over-graph chords is the difference between reaching waves_callback and
  # falling through to the schematic canvas verb. Every caller that cares passes
  # the pixel explicitly; the existing callers pass nothing and are unaffected.
  proc send_key {w ev done {gargs {}}} {
    for {set i 0} {$i < 200} {incr i} {
      update
      if {[uplevel 1 [list expr $done]]} { return 1 }
      if {[winfo exists $w]} {
        focus -force $w
        update
        if {[uplevel 1 [list expr $done]]} { return 1 }
        if {[winfo exists $w] && [focus -displayof $w] eq $w} {
          eval [list event generate $w $ev] $gargs
          update
          if {[uplevel 1 [list expr $done]]} { return 1 }
        }
      }
      after 50
    }
    puts "  send_key: $ev delivery to $w never confirmed (WSLg focus stall)"
    return 0
  }

  # THE REAL POINTER, PARKED where no window of this application is (a corner
  # of the screen), and put back. A window that is mapped, re-mapped or raised
  # under the pointer gets an Enter from the server, and the engine answers an
  # Enter that switches the context by giving that canvas the keyboard focus:
  # a row that asks where an OPEN leaves the focus has to keep the pointer out
  # of it. ptr_park answers 1 when the pointer rests over no window of this
  # application afterwards.
  proc ptr_park {} {
    set ::ptr_park_was [winfo pointerxy .]
    set sw [winfo screenwidth .] ; set sh [winfo screenheight .]
    foreach {x y} [list [expr {$sw - 3}] [expr {$sh - 3}] 2 [expr {$sh - 3}] [expr {$sw - 3}] 2 2 2] {
      if {[winfo containing $x $y] ne {}} { continue }
      event generate . <Motion> -warp 1 -x [expr {$x - [winfo rootx .]}] -y [expr {$y - [winfo rooty .]}]
      for {set i 0} {$i < 6} {incr i} { update ; after 15 }
      if {[winfo containing {*}[winfo pointerxy .]] eq {}} { return 1 }
    }
    return 0
  }
  proc ptr_back {} {
    event generate . <Motion> -warp 1 -x [expr {[lindex $::ptr_park_was 0] - [winfo rootx .]}] \
                                      -y [expr {[lindex $::ptr_park_was 1] - [winfo rooty .]}]
    for {set i 0} {$i < 6} {incr i} { update ; after 15 }
  }

  proc toplevel_count {} {
    set n 0
    foreach c [winfo children .] {
      if {[winfo class $c] eq {Toplevel}} { incr n }
    }
    return $n
  }

  # wait for the viewer canvas to be mapped (WSLg can be slow); 0 -> the
  # key-event legs SKIP rather than FAIL on a never-mapped window
  proc viewer_ready {top} {
    for {set i 0} {$i < 300} {incr i} {
      update
      if {[winfo exists $top.drw] && [winfo ismapped $top.drw]} { return 1 }
      after 20
    }
    return 0
  }

  # recording stub for tk_messageBox: a readonly_block MODAL would hang the
  # test — the stub records the request and answers ok (restored at the end)
  rename ::tk_messageBox ::wvtest_real_messageBox
  set ::mb_hits 0
  proc ::tk_messageBox {args} { incr ::mb_hits; return ok }

  # instrument wviewer::key_filter with an invocation counter WITHOUT
  # changing behavior: a swallowed key changes no product state, so the
  # counter is the only honest delivery witness send_key can gate on.
  # The original is renamed WITHIN its namespace — renaming a namespaced
  # proc into :: breaks its `variable` resolution and the filter then
  # errors instead of filtering (a swallow-by-error looks exactly like a
  # swallow-by-design: hollow-green). kf_errs guards that class: the
  # product filter must never throw.
  # kf_last (issue 1617) records the LAST (type, keysym, modifier-state) triple the
  # filter was handed. It is the only witness that a chord generated with
  # `event generate` arrived AS THAT CHORD: a `<Control-Key-a>` that lost its
  # Control bit somewhere in the Tk/WSLg round trip is indistinguishable, from the
  # product state alone, from a Ctrl-A the code declined to act on.
  rename ::wviewer::key_filter ::wviewer::key_filter_orig
  set ::kf_calls 0
  set ::kf_errs 0
  set ::kf_last {}
  # kf_at (2026-11-22): the canvas, the pixel and the keysym name of the last
  # call. A key that came through another window carries the pointer's pixel,
  # computed by the viewer's side, and a name the engine supplied.
  set ::kf_at {}
  proc ::wviewer::key_filter {W T x y N K s} {
    incr ::kf_calls
    set ::kf_last [list $T $N $s]
    set ::kf_at [list $W $x $y $K]
    if {[catch {::wviewer::key_filter_orig $W $T $x $y $N $K $s} e]} {
      incr ::kf_errs
      puts "  key_filter ERROR: $e"
    }
  }

  # user-rc canvas binds that clone_canvas_bindings (xinit.c
  # create_new_window) copies onto every new window's canvas BEFORE
  # wviewer::strip_bindings runs — the strip-sweep fixup target.
  # cadence_style_rc:109 VERBATIM + a per-widget bind shaped like
  # set_bindings' Windows-only Alt arm (the latent class). Unbound again
  # after the GUI legs.
  bind .drw <Key-i> {xschem create_instance; break}
  bind .drw <Alt-KeyPress> {wvtest_alt_arm_probe}

  # --- G1: session registered headless -> wviewer::open ----------------------
  check "G1 unknown token -> 0, no throw" [wviewer::open no/such/token] 0
  set sstate [file join $scratch session.state]
  ase::state_save $sstate $st
  set tok [ase::session_key sky130_tests test_nfet_final ngspice_state1]
  ase::session_open $tok $sstate
  # toolbar-strip determinism (fixup r2): pack_widgets packs $top.toolbar on
  # every new window while the GLOBAL toolbar_visible is 1 — force the
  # shipping default so the G1t leg is deterministic under any rc profile
  # (without the strip the viewer showed 37 armed editing/simulator buttons,
  # verifier probe). Restored right after G1t; main-window packedness is
  # asserted UNCHANGED, not absolute, so an rc with toolbar off cannot flip
  # that check.
  set save_tbv 1
  if {[info exists ::toolbar_visible]} { set save_tbv $::toolbar_visible }
  set ::toolbar_visible 1
  set main_tb_packed [expr {![catch {pack info .toolbar}]}]
  check "G1 wviewer::open returns 1" [wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  check_true "G1 viewer toplevel exists" \
    [expr {$vtop ne {} && [winfo exists $vtop]}]
  set vdrw $vtop.drw
  check_true "G1 viewer canvas exists" [winfo exists $vdrw]

  # --- OB1-OB4: A FRESHLY OPENED VIEWER STARTS WITH ONE BLANK STRIP ----------
  # issue 1616, wish_list.txt new-list item 15: "WV: Always start with one blank
  # graph element". This is the FIRST `wviewer::open` in the suite, so the token
  # has never had a layout -- which is the only state that exercises the seed in
  # `wviewer::open`, because the seed is guarded by `if {![dict exists $layouts
  # $token]}`.
  #
  # ⚠ THE INVARIANT EXISTED ONLY REACTIVELY BEFORE THIS ISSUE, WHICH IS WHY NO
  # ROW CAUGHT IT. `wviewer::display_raw` and `wviewer::add_trace` each carry
  # `if {![llength $gs]} { set gs [list [wviewer::empty_graph]] }`, and
  # `clear_all` / `new_tab` always leave exactly one -- so every path that PUTS
  # CONTENT IN a viewer repaired the empty list on the way past, and only a bare
  # open with nothing added could show the defect. `wviewer::regenerate` iterates
  # `foreach G_ $gs`, so with an empty list it places ZERO rects: the window came
  # up with no strip at all, not one blank strip.
  #
  # ⚠ OB4 IS NOT A DUPLICATE OF OB1. OB1 could pass on a leftover layout from an
  # earlier window; OB4 forgets the token first and reopens, so it proves the
  # SEED fires rather than that something survived. `wviewer::forget` unsets
  # `layouts($token)` (its own comment says a fresh open starts from an empty
  # layout -- a sentence issue 1616 makes stale, and which is corrected there).
  # ⚠ EVERY ROW HERE MUST *FAIL* ON THE BROKEN TREE, NEVER *THROW*. Measured
  # while writing them: the first cut of OB2 read
  # `dict get [lindex ... 0] traces` directly, and on the zero-graph tree
  # `lindex {} 0` is the empty string, so `dict get {} traces` raised
  # `key "traces" not known in dictionary`. That error hit the file-scope catch,
  # printed one `UNEXPECTED ERROR:` and ABORTED THE SUITE at 62 of 402 checks --
  # so a band written to expose one defect hid 340 unrelated checks instead. A
  # row that throws is strictly worse than a row that fails: it destroys the
  # coverage around it and reports one opaque line. Hence the explicit catches.
  set _obg [dict get [wviewer::layout_for $tok] graphs]
  check "OB1 a virgin open seeds exactly one graph" [llength $_obg] 1
  if {[catch {llength [dict get [lindex $_obg 0] traces]} _ob2]} {
    set _ob2 "no-graph-to-inspect ($_ob2)"
  }
  check "OB2 ...and that one graph is BLANK (no traces)" $_ob2 0
  # ⚠ OB3 IS THE ROW THAT REFUTED A ONE-LINE FIX, AND IT HAS TO PUMP THE EVENT
  # LOOP TO BE HONEST. The model is not the deliverable -- the user has to SEE a
  # strip -- and seeding the layout alone draws NOTHING: `wviewer::open` never
  # calls `wviewer::regenerate`, and rects are placed only by `regenerate`. The
  # only route from `open` to a drawn strip is
  # `<Configure>` -> `wviewer::on_configure` -> `after idle
  # wviewer::configure_apply` -> `regenerate`, which needs an event-loop turn,
  # and `configure_apply` additionally returns early while `winfo width` is <= 1.
  # Measured: with the seed in place and NO pump, this row read 0 rects.
  #
  # The pump is not a weakening. In a live session the idle handler runs within a
  # frame of the window mapping, so no user can perceive the gap, and nothing
  # between `open`'s return and the first idle turn puts anything in front of
  # them. What the row must assert is what the user experiences -- a mapped,
  # sized window showing one strip -- so it settles the map-time <Configure>
  # first, exactly as the GF and IX bands do for the same reason.
  #
  # `in_ctx` takes the value out through the RETURN, never a variable set inside
  # the body: that proc runs its script at uplevel #0, so a `set` in there makes a
  # global and leaves this proc's local untouched (wave_viewer.tcl's own warning).
  if {![viewer_ready $vtop]} {
    puts "skip: OB3 needs a mapped viewer canvas (the rect count is a drawn artifact)"
  } else {
    for {set i 0} {$i < 60} {incr i} { update; after 20 }
    if {[catch {wviewer::in_ctx $tok {xschem get rects 2}} _ob3]} {
      set _ob3 "in_ctx threw ($_ob3)"
    }
    check "OB3 ...and it is DRAWN as one layer-2 graph rect" $_ob3 1
  }
  # OB4: the SEED fired, not a leftover. `forget` unsets layouts($token), so the
  # reopen below re-enters the `![dict exists ...]` arm that OB1 tests.
  wviewer::forget $tok
  set _ob4open [wviewer::open $tok]
  check "OB4 reopen after forget returns 1" $_ob4open 1
  check "OB4 ...and re-seeds one graph (the seed, not a leftover)" \
    [llength [dict get [wviewer::layout_for $tok] graphs]] 1
  # re-establish the handles the rest of the G1 band uses: the forget+reopen
  # above built a NEW toplevel, so the old $vtop/$vdrw are stale.
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw

  # --- G1f: where the keyboard focus is after an open -------------------------
  # doc/claude/specs/waveform_viewer.md, "A key that came through another
  # window". wviewer::open leaves the keyboard focus inside the viewer on the
  # viewer's TOPLEVEL, in both of its arms (a fresh window, and one it only
  # raises). Until 2026-11-22 this row held that as a declared limit: no key
  # is bound on a toplevel, so right after an open no viewer key worked until
  # a click in the plot. The first build of overnight item 03b had the open
  # put the focus on the plot canvas instead. While this application holds
  # the keyboard that sends the next keys to the viewer wherever the pointer
  # is, and the repair of the same day took it back: the open is as it was,
  # and a key Tk hands the toplevel is the viewer's while the pointer is over
  # the plot (wviewer::top_key, behind a binding tag the toplevel carries
  # first; row KM23 sends the keys, row KM18 the keys after an open).
  # What is read is Tk's own record of where the focus goes inside the
  # toplevel (focus -lastfor), which does not wait for the window manager to
  # hand this application the focus. Legs: straight after the open of the row
  # above, nothing served in between; the tag, first on the toplevel and on
  # no window inside it (every descendant is walked); then, with the canvas
  # mapped, the focus put on the PLOT CANVAS by command (where a click leaves
  # it) and the same token opened again, which only raises the window and
  # takes the focus back to the toplevel, as it did before the item; and an
  # Enter on the plot from the main window's context still switches the
  # context to the viewer and puts the focus on its canvas.
  # The real pointer is parked off every window for the raise (ptr_park): the
  # raise re-maps the viewer, a re-map under the pointer brings an Enter, and
  # the engine's answer to an Enter that switches the context is to put the
  # focus on the canvas whatever the open did.
  set g1f [list [expr {[xschem get current_win_path] eq $vdrw}] [expr {[focus -lastfor $vtop] eq $vtop}]]
  set g1f_tag no-such-tag
  catch {set g1f_tag [wviewer::top_key_tag]}
  set g1f_kids {}
  set g1f_todo [list $vtop]
  while {[llength $g1f_todo]} {
    set g1f_w [lindex $g1f_todo 0]
    set g1f_todo [lrange $g1f_todo 1 end]
    foreach g1f_c [winfo children $g1f_w] { lappend g1f_kids $g1f_c ; lappend g1f_todo $g1f_c }
  }
  set g1f_car 0
  foreach g1f_c $g1f_kids { if {[lsearch -exact [bindtags $g1f_c] $g1f_tag] >= 0} { incr g1f_car } }
  lappend g1f [expr {[lindex [bindtags $vtop] 0] eq $g1f_tag}] [expr {[llength $g1f_kids] > 0}] $g1f_car
  if {![viewer_ready $vtop]} {
    puts "skip: G1f's raise and Enter legs need a mapped viewer canvas"
    check "G1f straight after wviewer::open the viewer's context is the current one and the focus inside its toplevel is on the toplevel, where the open has always left it; the toplevel carries the viewer's key tag first and no window inside it carries it (context the viewer's, focus on the toplevel, the tag first on the toplevel, windows inside it more than none, how many of them carry the tag)" \
      $g1f {1 1 1 1 0}
  } else {
    for {set i 0} {$i < 10} {incr i} { update; after 20 }
    set g1f_parked [ptr_park]
    catch {focus $vdrw}
    update
    lappend g1f $g1f_parked [expr {[focus -lastfor $vtop] eq $vdrw}] [wviewer::open $tok] \
                [expr {[wviewer::window_for $tok] eq $vtop}]
    for {set i 0} {$i < 20} {incr i} { update; after 20 }
    lappend g1f [expr {[focus -lastfor $vtop] eq $vtop}]
    ptr_back
    xschem new_schematic switch .drw
    event generate $vdrw <Enter> -x 40 -y 40
    update
    lappend g1f [list [expr {[xschem get current_win_path] eq $vdrw}] [expr {[focus -lastfor $vtop] eq $vdrw}]]
    check "G1f straight after wviewer::open the viewer's context is the current one and the focus inside its toplevel is on the toplevel, where the open has always left it; the toplevel carries the viewer's key tag first and no window inside it carries it; an open of the same token, which only raises the window, takes the focus from the plot canvas back to the toplevel; an Enter that switches the context to the viewer puts it on the plot canvas (after the open: context the viewer's, focus on the toplevel, the tag first on the toplevel, windows inside it more than none, how many of them carry the tag; the raise: the pointer parked off every window, the focus was put on the plot canvas, the open's answer, the same window, the focus on the toplevel after it; after an Enter from the main window's context: context the viewer's, focus on the canvas)" \
      $g1f {1 1 1 1 0 1 1 1 1 1 {1 1}}
    xschem new_schematic switch $vdrw
  }

  # --- G1c: THE VIEWER RECORDS ITS OWN ARRIVAL -------------------------------
  # ⚠ THIS IS INSTRUMENTATION, AND INSTRUMENTATION DIES SILENTLY. Issue 0840's
  # anti-congruence shove shipped dead for days and nobody noticed, because nothing
  # recorded whether it had fired. The unconditional `window_report viewer-open`
  # census at the end of wviewer::open is what closes that loop -- and it would rot
  # exactly the same way if no row watched it. The WVDIAG-gated trace beside it is
  # NOT a substitute: it was switched off on every field run that reproduced anything.
  set _wvlog {}
  catch {set _wvlog [xschem get actionlog_filename]}
  if {$_wvlog ne {} && [file isfile $_wvlog]} {
    set _fd [open $_wvlog r] ; set _b [read $_fd] ; close $_fd
    set _ll [split [string trimright $_b \n] \n]
    check_true "G1c the viewer logs a window census on open" \
      [expr {[llength [lsearch -all -inline -glob $_ll {#= window_report viewer-open*}]] >= 1}]
    # the census must name the VIEWER's own toplevel -- a census that lists everything
    # except the window that just appeared answers nothing.
    set _vt [file tail $vtop]
    check_true "G1c ... and the census lists the viewer toplevel it just made" \
      [expr {[llength [lsearch -all -inline -glob $_ll "#=*$vtop *"]] >= 1}]
    check_true "G1c ... as a NON-replayable comment (the log stays source-able)" \
      [expr {[llength [lsearch -all -inline -glob $_ll {window_report *}]] == 0}]
  } else {
    puts "SKIP: G1c needs --logdir (the census is a log artifact)"
  }

  # --- G1t: editor toolbar stripped from the viewer, per-window --------------
  # the widget EXISTS (build_widgets made the surface — the strip is not
  # trivially green) but is neither pack-managed nor mapped; pack info is the
  # mapping-independent witness (`pack forget` -> `pack info` throws even
  # before WSLg ever maps the toplevel)
  check "G1t editor toolbar widget exists on the viewer toplevel" \
    [winfo exists $vtop.toolbar] 1
  check "G1t viewer toolbar NOT pack-managed (pack info throws)" \
    [catch {pack info $vtop.toolbar}] 1
  check "G1t viewer toolbar not mapped" [winfo ismapped $vtop.toolbar] 0
  check "G1t main window toolbar packedness UNCHANGED (per-window strip)" \
    [expr {![catch {pack info .toolbar}]}] $main_tb_packed
  set ::toolbar_visible $save_tbv
  xschem new_schematic switch $vdrw
  check "G1 viewer buffer is readonly" [xschem get readonly] 1
  check_true "G1 viewer buffer is untitled-class" \
    [string match {*untitled*} [file tail [xschem get schname]]]

  # --- G1s: strip SWEEP — cloned user-rc / Windows-arm binds cleared ---------
  # (more-specific Tk binds fire INSTEAD of the generic key_filter, so any
  # survivor is a live editing-verb hole)
  check "G1s cloned <Key-i> cleared from the viewer canvas" \
    [bind $vdrw <Key-i>] {}
  check "G1s cloned <Alt-KeyPress> cleared from the viewer canvas" \
    [bind $vdrw <Alt-KeyPress>] {}
  check "G1s main canvas keeps its own <Key-i> bind (per-widget strip)" \
    [bind .drw <Key-i>] {xschem create_instance; break}
  # completeness: NOTHING outside keep-set + installed filters survives.
  # The allowed list is hardcoded (independent witness, canonical Tk
  # spellings) — reading wviewer::keepseqs back would go hollow if a verb
  # sequence ever crept into it.
  set allowed {
    <Expose> <Configure> <Visibility> <Enter> <Leave> <Motion> <Unmap>
    <MouseWheel> <Button> <ButtonRelease>
    <Key> <KeyRelease> <Button-3> <ButtonRelease-3>
    <Double-Button-1> <Double-Button-2> <Double-Button-3>
    <Button-4> <Button-5> <Shift-Button-4> <Shift-Button-5>
    <Control-Button-4> <Control-Button-5>
    <Shift-MouseWheel> <Control-MouseWheel>
    <Button-2> <ButtonRelease-2> <B2-Motion>
    <Shift-Button-1> <Shift-ButtonRelease-1> <Shift-B1-Motion>
    <Alt-Button-1> <Alt-ButtonRelease-1> <Alt-B1-Motion>
    <Button-1> <B1-Motion> <ButtonRelease-1>
  }
  set stray {}
  foreach seq [bind $vdrw] {
    if {[lsearch -exact $allowed $seq] < 0} { lappend stray $seq }
  }
  check "G1s no canvas sequence outside the keep+filter set" $stray {}

  # --- G2: viewer menubar replaces the editor menubar ------------------------
  set mb [$vtop cget -menu]
  check "G2 attached menu is the viewer menubar" $mb $vtop.wvmenubar
  check_true "G2 editor menubar is NOT the attached menu" \
    [expr {$mb ne "$vtop.menubar"}]
  set labels {}
  for {set i 0} {$i <= [$mb index end]} {incr i} {
    lappend labels [$mb entrycget $i -label]
  }
  # Options joined the fixed cascade list with the plot modes (issue 0151);
  # its contents are asserted in tests/headless/test_wave_modes.tcl (MG4)
  check "G2 cascade labels exactly File View Graph Cursors Options" $labels \
    {File View Graph Cursors Options}
  # item 12 flipped this leg: the item-11 placeholders were disabled, the
  # live core must leave NO Graph/Cursors entry disabled (also G17)
  set anydis 0
  foreach m [list $mb.graph $mb.cursors] {
    for {set i 0} {$i <= [$m index end]} {incr i} {
      if {[$m entrycget $i -state] eq {disabled}} { set anydis 1 }
    }
  }
  check "G2 no Graph/Cursors entry disabled (item-12: menus live)" $anydis 0

  # --- G3: exact title + with_edit clobber regression ------------------------
  set exp_title "Waveforms test_nfet_final (ngspice_state1)"
  check "G3 title exact" [wm title $vtop] $exp_title
  wviewer::with_edit $tok {}
  check "G3 title STILL exact after a with_edit cycle" [wm title $vtop] \
    $exp_title

  # --- G4: window number ------------------------------------------------------
  xschem new_schematic switch $vdrw
  set wnum [xschem get window_number]
  check_true "G4 viewer window number > 0" [expr {$wnum > 0}]

  if {![viewer_ready $vtop]} {
    puts "SKIPPED: G5/G6/G9 key-event legs (viewer window never mapped)"
    wviewer::close $tok
    update
  } else {
    # --- G5: strip — editing keys do NOTHING, silently -----------------------
    set tls_before [toplevel_count]
    set mbh_before $::mb_hits
    xschem new_schematic switch $vdrw
    set ::kf_calls 0
    set d1 [send_key $vdrw <Key-Insert> {$::kf_calls > 0}]
    set ::kf_calls 0
    set d2 [send_key $vdrw <Key-w> {$::kf_calls > 0}]
    check "G5 Insert + w delivered to the viewer filter" [list $d1 $d2] {1 1}
    # `i`: the cloned create_instance bind would fire INSTEAD of the filter
    # (and `break`) — kf_calls can only move if the sweep cleared it, so
    # delivery-to-filter IS the strip witness for the fixed hole
    set ::kf_calls 0
    set d2i [send_key $vdrw <Key-i> {$::kf_calls > 0}]
    check "G5 i reaches the FILTER (cloned bind swept)" $d2i 1
    update
    xschem new_schematic switch $vdrw
    check "G5 instances still 0" [xschem get instances] 0
    check "G5 wires still 0" [xschem get wires] 0
    check "G5 modified still 0" [xschem get modified] 0
    check "G5 no readonly modal (messageBox stub unhit)" \
      [expr {$::mb_hits - $mbh_before}] 0
    check "G5 no new toplevel appeared" [toplevel_count] $tls_before

    # --- G6: ESC never closes the viewer -------------------------------------
    set mbh_before $::mb_hits
    set ::kf_calls 0
    set d3 [send_key $vdrw <Key-Escape> {$::kf_calls > 0}]
    check "G6 Escape delivered" $d3 1
    update
    check_true "G6 viewer toplevel survives ESC" [winfo exists $vtop]
    check "G6 ESC popped no dialog" [expr {$::mb_hits - $mbh_before}] 0

    # --- G7: display_raw sanity leg ------------------------------------------
    set backups_before [lsort [glob -nocomplain *~.sch]]
    if {$have_raw} {
      check "G7 display_raw returns 1" \
        [wviewer::display_raw $tok $rawpath dc {i(v1)}] 1
    } else {
      puts "SKIPPED: G7 raw-load asserts (no rawfile from V4) - rect only"
      check "G7 display_raw (rect only) returns 1" \
        [wviewer::display_raw $tok {} dc {i(v1)}] 1
    }
    xschem new_schematic switch $vdrw
    check "G7 exactly one layer-2 graph rect" [xschem get rects 2] 1
    check "G7 rect carries flags=graph" [xschem getprop rect 2 0 flags] graph
    check_true "G7 rect node attr carries i(v1)" \
      [string match {*i(v1)*} [xschem getprop rect 2 0 node]]
    if {$have_raw} {
      check "G7 raw points 181 in the viewer ctx" [xschem raw points] 181
    }
    check "G7 redraw rc 0" [catch {xschem redraw}] 0
    check "G7 modified still 0 after display_raw" [xschem get modified] 0
    check "G7 readonly restored after display_raw" [xschem get readonly] 1
    check "G7 no untitled autosave backup appeared (D1 bracket)" \
      [lsort [glob -nocomplain *~.sch]] $backups_before

    # --- G8: re-open raises the SAME window ----------------------------------
    set tls_before [toplevel_count]
    check "G8 re-open returns 1" [wviewer::open $tok] 1
    check "G8 same toplevel" [wviewer::window_for $tok] $vtop
    check "G8 no second window" [toplevel_count] $tls_before
    xschem new_schematic switch $vdrw
    check "G8 window number unchanged" [xschem get window_number] $wnum

    # --- G9: closing the window, and Ctrl-W's NEW meaning --------------------
    #
    # ⚠ REWRITTEN 2026-08-03 for tabs (doc/claude/specs/waveform_viewer_tabs.md
    # D9a, user ruling). Ctrl-W used to close the WINDOW and this group asserted
    # it eight times. It now closes a TAB, and on a one-tab viewer it does
    # NOTHING but say so. Every property the old group guarded — no prompt, a
    # clean registry, a fresh re-open — still matters and is still asserted;
    # they simply hang off Ctrl-Q now, which is the key that closes a window.
    #
    # G9a first: the REFUSAL. This is the leg that would have passed vacuously
    # if Ctrl-W had merely stopped being delivered, so it checks the window is
    # still up AND that the key really arrived, by watching the CIW notice.
    set mbh_before $::mb_hits
    set ::g9_notice {}
    if {[info commands ::ciw_echo] ne {}} {
      rename ::ciw_echo ::g9_real_ciw_echo
      proc ::ciw_echo {msg args} {
        if {[string match {*only one tab*} $msg]} { set ::g9_notice $msg }
        uplevel 1 [list ::g9_real_ciw_echo $msg {*}$args]
      }
    }
    check "G9a one tab up before the refusal" [wviewer::tab_count $tok] 1
    set d4a [send_key $vdrw <Control-Key-w> {$::g9_notice ne {}}]
    check "G9a Ctrl-W was delivered (the CIW notice arrived)" $d4a 1
    check_true "G9a ...and it REFUSED: the window is still up" \
      [expr {[winfo exists $vtop]}]
    check "G9a ...and the registry still holds it" \
      [wviewer::window_for $tok] $vtop
    check "G9a ...and it is still one tab" [wviewer::tab_count $tok] 1
    check "G9a the refusal popped no dialog" [expr {$::mb_hits - $mbh_before}] 0
    if {[info commands ::g9_real_ciw_echo] ne {}} {
      rename ::ciw_echo {}
      rename ::g9_real_ciw_echo ::ciw_echo
    }
    # G9b: with TWO tabs the same key closes one and leaves the window alone.
    check_true "G9b a second tab opened" \
      [expr {[wviewer::new_tab $tok] ne {}}]
    check "G9b two tabs now" [wviewer::tab_count $tok] 2
    set d4b [send_key $vdrw <Control-Key-w> {[wviewer::tab_count $tok] == 1}]
    check "G9b Ctrl-W closed the TAB" $d4b 1
    check_true "G9b ...and the window survived" [expr {[winfo exists $vtop]}]
    # G9c: Ctrl-Q is what closes the window — the old G9 properties, moved.
    set mbh_before $::mb_hits
    set d4 [send_key $vdrw <Control-Key-q> {![winfo exists $vtop]}]
    check "G9 Ctrl-Q closed the viewer" $d4 1
    check_true "G9 toplevel destroyed" [expr {![winfo exists $vtop]}]
    check "G9 close popped no dialog/prompt" \
      [expr {$::mb_hits - $mbh_before}] 0
    check "G9 registry cleaned" [wviewer::window_for $tok] {}
    check "G9 reopen after close returns 1" [wviewer::open $tok] 1
    set vtop2 [wviewer::window_for $tok]
    check_true "G9 fresh viewer window created" \
      [expr {$vtop2 ne {} && [winfo exists $vtop2]}]
    check "G9 fresh viewer toolbar also stripped" \
      [catch {pack info $vtop2.toolbar}] 1
    wviewer::close $tok
    update
    check "G9 closed via the API, registry clean" [wviewer::window_for $tok] {}
  }

  # ===== item 12: viewer core (G10-G17, fresh viewer window) =================
  check "G10 core-legs reopen returns 1" [wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  set mb $vtop.wvmenubar
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: G10-G17 core legs (viewer window never mapped)"
    wviewer::close $tok
    update
  } else {

    # --- G10: Add Graph (menu live; model -> rects -> graphbb agree) ---------
    set gmenu $mb.graph
    check_true "G10 Add Graph entry enabled" \
      [expr {[$gmenu entrycget [$gmenu index {Add Graph}] -state] ne {disabled}}]
    # ⚠ ONE INVOKE, NOT TWO, SINCE ISSUE 1616. `wviewer::open` now seeds one blank
    # strip, so one `Add Graph` reaches the two-graph state this whole band is
    # about. Before 1616 the seed was an EMPTY list and this band clicked twice
    # from a base of ZERO -- which is why `G10 model has 2 graphs` was, all along,
    # a recording of the defect 1616 fixes rather than an assertion about
    # stacking. Repaired this way ON PURPOSE rather than by renumbering every
    # literal to 3: the alternative shifts 27 expected values across G10-G14 and
    # GF1-GF4, changes the Add Trace dialog's default target strip from index 1 to
    # 2 (it defaults to the LAST), and leaves three rows whose own names assert a
    # geometry that no longer exists ("a single graph fills the whole viewport",
    # "two graphs each fill a half"). Adding one fewer strip keeps every literal,
    # every index and every stated invariant exactly as measured.
    $gmenu invoke [$gmenu index {Add Graph}]
    update                                 ;# flush any pending <Configure> refit
    check "G10 model has 2 graphs" \
      [llength [dict get [wviewer::layout_for $tok] graphs]] 2
    xschem new_schematic switch $vdrw
    check "G10 two layer-2 graph rects" [xschem get rects 2] 2
    set bbs [dict get $::wviewer::graphbb $vdrw]
    check "G10 graphbb has 2 bands" [llength $bbs] 2
    # item 18: the two graphs split the live viewport into equal full-width
    # halves (viewport-relative, replacing the old fixed i*450 slot). graphbb is
    # built from band_geometry, so each row equals the band of the live viewport;
    # row 1 is the BOTTOM half.
    set vp10 [wviewer::viewport_rect $vdrw]
    lassign $vp10 v10x1 v10y1 v10x2 v10y2
    check "G10 graphbb row 0 == band 0 of 2 (top half)" \
      [lindex $bbs 0] [wviewer::band_geometry 0 2 $v10x1 $v10y1 $v10x2 $v10y2]
    check "G10 graphbb row 1 == band 1 of 2 (bottom half)" \
      [lindex $bbs 1] [wviewer::band_geometry 1 2 $v10x1 $v10y1 $v10x2 $v10y2]
    check_true "G10 rows are contiguous (row1 top == row0 bottom)" \
      [expr {[lindex [lindex $bbs 1] 1] == [lindex [lindex $bbs 0] 3]}]
    check_true "G10 both rows span the full viewport width" \
      [expr {[lindex [lindex $bbs 0] 0] == $v10x1 &&
             [lindex [lindex $bbs 0] 2] == $v10x2 &&
             [lindex [lindex $bbs 1] 0] == $v10x1 &&
             [lindex [lindex $bbs 1] 2] == $v10x2}]

    set names {}
    if {$have_raw} {
      # raw goes into the (fresh) viewer ctx: per-context xctx->raw
      xschem new_schematic switch $vdrw
      check "G11 raw read into the viewer ctx" [rawq {xschem raw read $rawpath dc}] 1
      set names [split [xschem raw list] "\n"]
      set var1 [lindex $names 1]                     ;# first non-sweep var

      # --- G11: Add Trace picked from the raw-vars listbox -------------------
      set w [wviewer::add_trace_dialog $tok]
      check_true "G11 Add Trace dialog exists" [winfo exists $w]
      check "G11 listbox count == raw vars" [$w.vars size] [xschem raw vars]
      $w.vars selection clear 0 end
      $w.vars selection set 1
      $w.expr delete 0 end                           ;# empty -> listbox pick
      wviewer::add_trace_ok $tok
      check_true "G11 dialog closed on OK" [expr {![winfo exists $w]}]
      xschem new_schematic switch $vdrw
      check_true "G11 rect 1 node carries the picked var verbatim" \
        [expr {[string first $var1 [xschem getprop rect 2 1 node]] >= 0}]
      check "G11 rect 1 color == palette head" [xschem getprop rect 2 1 color] 4
      set g1 [lindex [dict get [wviewer::layout_for $tok] graphs] 1]
      check "G11 model records 1 trace on the LAST (default) graph" \
        [llength [dict get $g1 traces]] 1
      set t0 [lindex [dict get $g1 traces] 0]
      check "G11 model trace vec == picked var" [dict get $t0 vec] $var1
      check "G11 model trace color 4" [dict get $t0 color] 4

      # --- G12: expression trace (RPN via `xschem raw add`) ------------------
      set w [wviewer::add_trace_dialog $tok]
      $w.expr delete 0 end
      $w.expr insert 0 "$var1 db20()"
      $w.name delete 0 end
      $w.name insert 0 db1
      wviewer::add_trace_ok $tok
      check_true "G12 dialog closed on OK" [expr {![winfo exists $w]}]
      xschem new_schematic switch $vdrw
      check_true "G12 raw vector db1 exists (raw index >= 0)" \
        [expr {[rawq {xschem raw index db1}] >= 0}]
      check_true "G12 rect 1 node carries db1" \
        [expr {[string first db1 [xschem getprop rect 2 1 node]] >= 0}]
      check "G12 redraw rc 0" [catch {xschem redraw}] 0
      set g1 [lindex [dict get [wviewer::layout_for $tok] graphs] 1]
      set t1 [lindex [dict get $g1 traces] 1]
      check "G12 model stores the original RPN expr" [dict get $t1 expr] \
        "$var1 db20()"
      check "G12 model stores the vector name" [dict get $t1 vec] db1

      # --- G12b: bad expression surfaces in-dialog (D4), no phantom ----------
      set before_g [dict get [wviewer::layout_for $tok] graphs]
      set w [wviewer::add_trace_dialog $tok]
      $w.expr delete 0 end
      $w.expr insert 0 "v(nosuchnet) db20()"
      $w.name delete 0 end
      $w.name insert 0 db2
      check "G12b OK path does not throw" [catch {wviewer::add_trace_ok $tok}] 0
      check_true "G12b dialog still up" [winfo exists $w]
      set errtxt {}
      catch {set errtxt [$w.err cget -text]}
      check_true "G12b error label non-empty" [expr {$errtxt ne {}}]
      xschem new_schematic switch $vdrw
      check "G12b no phantom raw vector db2" [rawq {xschem raw index db2}] -1
      check_true "G12b model unchanged" \
        [expr {[dict get [wviewer::layout_for $tok] graphs] eq $before_g}]
      catch {$w.btns.cancel invoke}                  ;# ESC-equivalent path
      check_true "G12b dialog dismissed via cancel" [expr {![winfo exists $w]}]
    } else {
      puts "SKIPPED: G11/G12 raw-driven legs (no rawfile from V4)"
    }

    # --- G13: Axes dialog log toggle + explicit ranges -----------------------
    set w [wviewer::axes_dialog $tok]
    check_true "G13 Axes dialog exists" [winfo exists $w]
    $w.graph set 0
    wviewer::axes_load $tok
    $w.x1 delete 0 end
    $w.x1 insert 0 0
    $w.x2 delete 0 end
    $w.x2 insert 0 1.8
    set ::wviewer::axl($tok,y) 1
    wviewer::axes_ok $tok
    check_true "G13 dialog closed on OK" [expr {![winfo exists $w]}]
    xschem new_schematic switch $vdrw
    check "G13 rect 0 logy == 1" [xschem getprop rect 2 0 logy] 1
    check_true "G13 rect 0 x1 exact 0" \
      [expr {[xschem getprop rect 2 0 x1] == 0}]
    check_true "G13 rect 0 x2 exact 1.8" \
      [expr {[xschem getprop rect 2 0 x2] == 1.8}]
    set g0 [lindex [dict get [wviewer::layout_for $tok] graphs] 0]
    check "G13 model logy" [dict get $g0 logy] 1
    check "G13 model x1" [dict get $g0 x1] 0
    check "G13 model x2" [dict get $g0 x2] 1.8

    if {$have_raw} {
      # --- G14: Delete dialog — one trace, then a whole graph ----------------
      set var1 [lindex $names 1]
      set w [wviewer::delete_dialog $tok]
      set rows {}
      for {set i 0} {$i < [$w.items size]} {incr i} {
        lappend rows [$w.items get $i]
      }
      # the picked-var trace row is exactly "graph 1: <var> (<var>)" — the
      # db1 row also CONTAINS $var1 (inside its expr), so match the full row
      set want "graph 1: $var1 ($var1)"
      set ri [lsearch -exact $rows $want]
      check_true "G14 trace row found in the Delete listbox" [expr {$ri >= 0}]
      # --- G14b: the dialog is UNDOABLE and REPLAYABLE (issue 0176) ---------
      # It was neither until 0176: `delete_ok` had no push_undo and no
      # log_action, so a dialog delete could not be taken back and could not be
      # replayed. That was a PRE-EXISTING defect, repaired by routing the
      # dialog through `wviewer::delete_items` — the same proc the DEL key
      # uses. These legs are what stop it regressing to a bare model write.
      set ::g14log {}
      rename wviewer::log_action wviewer::__g14_real_log
      proc wviewer::log_action {line} { lappend ::g14log $line }
      wviewer::clear_history $tok
      # the MODEL trace index behind that listbox ROW — the log line names the
      # model, not the widget, which is exactly what makes it replayable
      set g14ent [lindex $wviewer::delmap($tok) $ri]
      set ri1 [lindex $g14ent 2]
      check "G14b the picked row decodes to a trace of graph 1" \
        [lrange $g14ent 0 1] {trace 1}
      $w.items selection clear 0 end
      $w.items selection set $ri
      set g14n [wviewer::delete_ok $tok]
      xschem new_schematic switch $vdrw
      check "G14b OK reports the one thing it deleted" $g14n 1
      check_true "G14 deleted trace gone from the node attr" \
        [expr {[string first $var1 [xschem getprop rect 2 1 node]] < 0}]
      set g1 [lindex [dict get [wviewer::layout_for $tok] graphs] 1]
      check "G14 model graph 1 keeps exactly the surviving trace" \
        [llength [dict get $g1 traces]] 1
      check "G14 surviving trace is db1" \
        [dict get [lindex [dict get $g1 traces] 0] vec] db1
      check "G14b the dialog delete pushed exactly ONE undo point" \
        [wviewer::history_depth $tok] {1 0}
      check "G14b ... and logged exactly one line, with EXPLICIT model indices" \
        [list [llength $::g14log] [lindex $::g14log 0]] \
        [list 1 "wviewer::delete_items {} {{1 $ri1}} {} $tok"]
      check "G14b `u` puts the trace back" \
        [list [wviewer::undo $tok] \
              [llength [dict get [lindex [dict get [wviewer::layout_for $tok] graphs] 1] traces]]] \
        {1 2}
      check "G14b ... and `U` takes it away again" \
        [list [wviewer::redo $tok] \
              [llength [dict get [lindex [dict get [wviewer::layout_for $tok] graphs] 1] traces]]] \
        {1 1}
      # an OK with nothing selected is a no-op: no undo point, no log line
      set ::g14log {}
      wviewer::clear_history $tok
      set w2 [wviewer::delete_dialog $tok]
      $w2.items selection clear 0 end
      check "G14b OK with an empty selection deletes nothing" \
        [wviewer::delete_ok $tok] 0
      check "G14b ... and pushes no undo point and logs nothing" \
        [list [wviewer::history_depth $tok] [llength $::g14log]] {{0 0} 0}
      rename wviewer::log_action {}
      rename wviewer::__g14_real_log wviewer::log_action
      xschem new_schematic switch $vdrw
      # whole-graph delete: graph 1 disappears, graph 0 re-stacks from y 0
      set w [wviewer::delete_dialog $tok]
      set rows {}
      for {set i 0} {$i < [$w.items size]} {incr i} {
        lappend rows [$w.items get $i]
      }
      set ri [lsearch -exact $rows {graph 1}]
      check_true "G14 graph row found" [expr {$ri >= 0}]
      $w.items selection clear 0 end
      $w.items selection set $ri
      wviewer::delete_ok $tok
      xschem new_schematic switch $vdrw
      check "G14 rects drop to 1" [xschem get rects 2] 1
      check "G14 model drops to 1 graph" \
        [llength [dict get [wviewer::layout_for $tok] graphs]] 1
      # item 18: the sole surviving graph re-FILLS the WHOLE viewport (n=1),
      # not a fixed 800x400 slot — compute the expected full-viewport band
      update
      set vp14 [wviewer::viewport_rect $vdrw]
      lassign $vp14 v14x1 v14y1 v14x2 v14y2
      check "G14 remaining graph fills the whole viewport" \
        [lindex [dict get $::wviewer::graphbb $vdrw] 0] \
        [wviewer::band_geometry 0 1 $v14x1 $v14y1 $v14x2 $v14y2]

      # --- G15: cursors + readout (menu-driven; interpolation honest) --------
      set sweepv [lindex $names 0]
      set cx 0.905                       ;# strictly between two sweep samples
      xschem new_schematic switch $vdrw
      set pos [xschem raw pos_at $sweepv $cx]
      check_true "G15 pos_at finds the bracketing sample" [expr {$pos >= 0}]
      set slopevar {}
      foreach v [lrange $names 1 end] {
        set va [xschem raw value $v $pos]
        set vb [xschem raw value $v [expr {$pos + 1}]]
        if {$va != $vb} { set slopevar $v; break }
      }
      check_true "G15 found a nonzero-slope var" [expr {$slopevar ne {}}]
      check "G15 add slope trace to graph 0" \
        [wviewer::add_trace $tok 0 $slopevar {}] {}
      set cmenu $mb.cursors
      $cmenu invoke [$cmenu index {Cursor A}]
      $cmenu invoke [$cmenu index {Cursor B}]
      check "G15 cursor mirrors both on" \
        [list $::wviewer::cva($tok) $::wviewer::cvb($tok)] {1 1}
      check_true "G15 readout bar auto-shown (pack-managed)" \
        [expr {![catch {pack info $vtop.wvreadout}]}]
      xschem new_schematic switch $vdrw
      xschem redraw                      ;# engine graph ctx follows the rects
      xschem set cursor1_x $cx
      xschem set cursor2_x $cx           ;# fires the engine backannotate (B)
      wviewer::readout_refresh $tok
      set ta [$vtop.wvreadout.a cget -text]
      set tb [$vtop.wvreadout.b cget -text]
      set fx [ase::format_value $cx]
      check_true "G15a A line shows x=$fx" \
        [expr {[string first "x=$fx" $ta] >= 0}]
      check_true "G15a B line shows x=$fx" \
        [expr {[string first "x=$fx" $tb] >= 0}]
      set yh [wviewer::interp_value $slopevar $cx]
      set ye [xschem raw value $slopevar {}]  ;# engine cursor-B ground truth
      set denom [expr {abs($ye) > 1e-30 ? abs($ye) : 1e-30}]
      check_true "G15b Tcl interpolation == engine cursor_b_val (rel 1e-6)" \
        [expr {abs($yh - $ye) / $denom < 1e-6}]
      set ynear [xschem raw value $slopevar $pos]
      check_true "G15c interpolated y differs from the nearest sample" \
        [expr {abs($yh - $ynear) > 0}]
      set fy [ase::format_value $yh]
      check_true "G15d A line carries $slopevar=$fy (same helper, cursor A)" \
        [expr {[string first "$slopevar=$fy" $ta] >= 0}]
      check_true "G15d B line carries $slopevar=$fy" \
        [expr {[string first "$slopevar=$fy" $tb] >= 0}]

      # --- G16: View > Fit = engine autozoom + model read-back ---------------
      set gs [dict get [wviewer::layout_for $tok] graphs]
      set g0 [dict replace [lindex $gs 0] x1 0.5 x2 1.0]
      wviewer::set_graphs $tok [lreplace $gs 0 0 $g0]
      wviewer::regenerate $tok
      xschem new_schematic switch $vdrw
      check_true "G16 rect shows the subrange (x1 0.5)" \
        [expr {[xschem getprop rect 2 0 x1] == 0.5}]
      $mb.view invoke [$mb.view index Fit]
      xschem new_schematic switch $vdrw
      set rx1 [xschem getprop rect 2 0 x1]
      set rx2 [xschem getprop rect 2 0 x2]
      set np   [xschem raw points]
      set smin [xschem raw value $sweepv 0]
      set smax [xschem raw value $sweepv [expr {$np - 1}]]
      if {$smin > $smax} { foreach {smin smax} [list $smax $smin] break }
      set ftol [expr {1e-6 * (abs($smax) + 1.0)}]
      check_true "G16 fit x1 == sweep min ($smin)" \
        [expr {abs($rx1 - $smin) <= $ftol}]
      check_true "G16 fit x2 == sweep max ($smax)" \
        [expr {abs($rx2 - $smax) <= $ftol}]
      set g0 [lindex [dict get [wviewer::layout_for $tok] graphs] 0]
      check "G16 model x1 read back from the rect" [dict get $g0 x1] $rx1
      check "G16 model x2 read back from the rect" [dict get $g0 x2] $rx2
    } else {
      puts "SKIPPED: G14/G15/G16 raw-driven legs (no rawfile from V4)"
    }

    # --- G17: every Graph + Cursors entry live -------------------------------
    set anydis17 0
    foreach m [list $mb.graph $mb.cursors] {
      for {set i 0} {$i <= [$m index end]} {incr i} {
        if {[$m entrycget $i -state] eq {disabled}} { set anydis17 1 }
      }
    }
    check "G17 no Graph/Cursors entry left disabled" $anydis17 0

    wviewer::close $tok
    update
  }

  # ===== item 18: the graph FILLS the viewer window (GF1-GF5) ================
  # A fresh viewer: assert the graph rect covers ~the full canvas viewport,
  # refits on resize, splits into equal bands for multi-graph, and regenerate
  # never re-frames (shrinks) the canvas.
  check "GF item-18 reopen returns 1" [wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  set mb $vtop.wvmenubar
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: GF1-GF5 fill legs (viewer window never mapped)"
    wviewer::close $tok
    update
  } else {
    # let the map-time <Configure> refit + any pending_fullzoom settle
    for {set i 0} {$i < 60} {incr i} { update; after 20 }

    # the live viewport-covering rect in schematic coords (mirrors
    # wviewer::viewport_rect, computed independently as the test's witness)
    proc gf_viewport {vdrw} {
      xschem new_schematic switch $vdrw
      set W [winfo width $vdrw]; set H [winfo height $vdrw]
      set z [xschem get zoom]
      set xo [xschem get xorigin]; set yo [xschem get yorigin]
      return [list [expr {-$xo}] [expr {-$yo}] \
                   [expr {$W * $z - $xo}] [expr {$H * $z - $yo}]]
    }
    proc gf_near {a b tol} { expr {abs($a - $b) <= $tol} }

    # --- GF1: a single graph fills the whole viewport ------------------------
    # ⚠ NO `Add Graph` HERE SINCE ISSUE 1616: `wviewer::open` seeds exactly one
    # blank strip, so the SEEDED strip is the single graph this block measures --
    # a strictly better fence than clicking one in, because it now proves the
    # window a user actually gets on open fills the viewport, not one they had to
    # build first. Adding a strip here would make it two and turn every "fills the
    # whole viewport" row into a statement about halves.
    update
    xschem new_schematic switch $vdrw
    check "GF1 exactly one graph rect" [xschem get rects 2] 1
    set bb0 [lindex [dict get $::wviewer::graphbb $vdrw] 0]
    lassign [gf_viewport $vdrw] vx1 vy1 vx2 vy2
    set tol [expr {(abs($vx2 - $vx1) + abs($vy2 - $vy1)) * 0.02 + 2}]
    check_true "GF1 graph left edge ~ viewport left" \
      [gf_near [lindex $bb0 0] $vx1 $tol]
    check_true "GF1 graph right edge ~ viewport right" \
      [gf_near [lindex $bb0 2] $vx2 $tol]
    check_true "GF1 graph top edge ~ viewport top" \
      [gf_near [lindex $bb0 1] $vy1 $tol]
    check_true "GF1 graph bottom edge ~ viewport bottom" \
      [gf_near [lindex $bb0 3] $vy2 $tol]

    # --- GF2: grid OFF in the viewer, ON in a normal window ------------------
    xschem new_schematic switch $vdrw
    check "GF2 viewer no_grid == 1" [xschem get no_grid] 1
    check "GF2 viewer redraw rc 0 (no_grid draw path runs clean)" \
      [catch {xschem redraw}] 0
    xschem new_schematic switch .drw
    check "GF2 design/main canvas no_grid == 0" [xschem get no_grid] 0
    xschem new_schematic switch $vdrw

    # --- GF3: resize -> refit ran (graph still fills, and it grew) -----------
    xschem new_schematic switch $vdrw
    set bb_before [lindex [dict get $::wviewer::graphbb $vdrw] 0]
    set w_before [winfo width $vdrw]
    set h_before [winfo height $vdrw]
    wm geometry $vtop 1200x900
    update
    for {set i 0} {$i < 120} {incr i} {
      update
      if {[winfo width $vdrw] != $w_before || \
          [winfo height $vdrw] != $h_before} break
      after 20
    }
    update; after 150; update            ;# let on_configure's after-idle fire
    if {[winfo width $vdrw] == $w_before && [winfo height $vdrw] == $h_before} {
      puts "SKIPPED: GF3 resize refit (WM refused the resize)"
    } else {
      xschem new_schematic switch $vdrw
      set bb_after [lindex [dict get $::wviewer::graphbb $vdrw] 0]
      lassign [gf_viewport $vdrw] vx1 vy1 vx2 vy2
      set tol [expr {(abs($vx2 - $vx1) + abs($vy2 - $vy1)) * 0.02 + 2}]
      check_true "GF3 graph still covers the new viewport (right edge)" \
        [gf_near [lindex $bb_after 2] $vx2 $tol]
      check_true "GF3 graph still covers the new viewport (bottom edge)" \
        [gf_near [lindex $bb_after 3] $vy2 $tol]
      set wb [expr {[lindex $bb_before 2] - [lindex $bb_before 0]}]
      set wa [expr {[lindex $bb_after 2] - [lindex $bb_after 0]}]
      set hb [expr {[lindex $bb_before 3] - [lindex $bb_before 1]}]
      set ha [expr {[lindex $bb_after 3] - [lindex $bb_after 1]}]
      check_true "GF3 graph grew vs the pre-resize bbox (refit ran)" \
        [expr {$wa > $wb || $ha > $hb}]
    }

    # --- GF4: two graphs each fill a half ------------------------------------
    $mb.graph invoke [$mb.graph index {Add Graph}]
    update
    xschem new_schematic switch $vdrw
    check "GF4 two graph rects" [xschem get rects 2] 2
    set bbs [dict get $::wviewer::graphbb $vdrw]
    check "GF4 graphbb has 2 entries" [llength $bbs] 2
    set gtop [lindex $bbs 0]; set gbot [lindex $bbs 1]
    lassign [gf_viewport $vdrw] vx1 vy1 vx2 vy2
    set mid [expr {($vy1 + $vy2) / 2.0}]
    set tol [expr {(abs($vx2 - $vx1) + abs($vy2 - $vy1)) * 0.03 + 2}]
    check_true "GF4 top graph starts at the viewport top" \
      [gf_near [lindex $gtop 1] $vy1 $tol]
    check_true "GF4 top graph ends at the midpoint" \
      [gf_near [lindex $gtop 3] $mid $tol]
    check_true "GF4 bottom graph starts at the midpoint" \
      [gf_near [lindex $gbot 1] $mid $tol]
    check_true "GF4 bottom graph ends at the viewport bottom" \
      [gf_near [lindex $gbot 3] $vy2 $tol]
    check_true "GF4 both graphs span the full viewport width" \
      [expr {[gf_near [lindex $gtop 0] $vx1 $tol] &&
             [gf_near [lindex $gtop 2] $vx2 $tol] &&
             [gf_near [lindex $gbot 0] $vx1 $tol] &&
             [gf_near [lindex $gbot 2] $vx2 $tol]}]
    check_true "GF4 bands contiguous (bottom top == top bottom)" \
      [expr {[lindex $gbot 1] == [lindex $gtop 3]}]

    # --- GF5: regenerate does NOT re-frame the canvas (kill the shrink) -------
    xschem new_schematic switch $vdrw
    set zoom0 [xschem get zoom]
    set xo0 [xschem get xorigin]
    set yo0 [xschem get yorigin]
    wviewer::regenerate $tok
    xschem new_schematic switch $vdrw
    check "GF5 zoom unchanged across regenerate" [xschem get zoom] $zoom0
    check "GF5 xorigin unchanged across regenerate" [xschem get xorigin] $xo0
    check "GF5 yorigin unchanged across regenerate" [xschem get yorigin] $yo0
    set bb0 [lindex [dict get $::wviewer::graphbb $vdrw] 0]
    lassign [gf_viewport $vdrw] vx1 vy1 vx2 vy2
    set tol [expr {(abs($vx2 - $vx1) + abs($vy2 - $vy1)) * 0.02 + 2}]
    check_true "GF5 graph still fills after regenerate (full width)" \
      [expr {[gf_near [lindex $bb0 0] $vx1 $tol] &&
             [gf_near [lindex $bb0 2] $vx2 $tol]}]

    rename gf_viewport {}
    rename gf_near {}
    wviewer::close $tok
    update
  }

  # ===== item 19: wheel / RMB / f / View-zoom act on the GRAPH (IX) ==========
  # Deterministic: every leg drives a wviewer:: proc (or a synthetic C callback)
  # and witnesses a SYNCHRONOUS state write (graph rect range tokens) — never a
  # gesture/stacking/timing race (item-17 de-flake lesson). The graph-not-canvas
  # TEETH: after every op the canvas xorigin/yorigin/zoom must equal the baseline
  # captured once (item-18 pinned them; only the graph axes may change).
  check "IX item-19 reopen returns 1" [wviewer::open $tok] 1
  set vtop [wviewer::window_for $tok]
  set vdrw $vtop.drw
  set mb $vtop.wvmenubar
  if {![viewer_ready $vtop]} {
    puts "SKIPPED: IX interaction legs (viewer window never mapped)"
    wviewer::close $tok
    update
  } else {
    # let the map-time <Configure> refit settle so the canvas viewport is stable
    for {set i 0} {$i < 40} {incr i} { update; after 20 }

    # ONE graph with KNOWN concrete ranges. No trace / no raw needed: the wheel,
    # zoom and RMB x-box all operate on the graph rect's range tokens, which exist
    # regardless of loaded data — this keeps the whole IX block ngspice-independent
    # and deterministic.
    proc ix_setrange {tok x1 x2 y1 y2} {
      set gs [dict get [wviewer::layout_for $tok] graphs]
      set G [dict replace [lindex $gs 0] x1 $x1 x2 $x2 y1 $y1 y2 $y2]
      wviewer::set_graphs $tok [lreplace $gs 0 0 $G]
      wviewer::regenerate $tok
    }
    proc ix_canvas_ok {vdrw cx0 cy0 cz0} {
      xschem new_schematic switch $vdrw
      expr {[xschem get xorigin] == $cx0 && [xschem get yorigin] == $cy0 &&
            [xschem get zoom] == $cz0}
    }
    # ⚠ NO `add_graph` HERE SINCE ISSUE 1616 -- the reopen above already seeds one
    # empty graph that fills the window, which is exactly the precondition this
    # whole band rests on. Adding one would make it TWO, and that is not an
    # off-by-one: `wviewer::graph_at_pointer` opens with
    # `if {$n <= 1} { return 0 }`, and the IX legs depend on that short circuit --
    # this band's own header says it drives `wheel_zoom` with an explicit index
    # because "a 2-strip pointer position is not reproducible headlessly". A second
    # strip would make 33 rows depend on the pointer mirror's position instead of
    # on that guarantee, i.e. non-deterministic rather than merely wrong.
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    check_true "IX-setup rect x1/x2/y1/y2 == 0/10/-1/1" \
      [expr {[xschem getprop rect 2 0 x1] == 0 && [xschem getprop rect 2 0 x2] == 10 &&
             [xschem getprop rect 2 0 y1] == -1 && [xschem getprop rect 2 0 y2] == 1}]
    # baseline canvas AFTER the setup regenerate (stable henceforth: regenerate,
    # wheel, zoom and fit all leave the canvas pinned — the invariant under test)
    set cx0 [xschem get xorigin]
    set cy0 [xschem get yorigin]
    set cz0 [xschem get zoom]

    # --- IX-vpan-up / IX-vpan-dn: plain wheel = GRAPH vertical pan ------------
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set y1a [xschem getprop rect 2 0 y1]; set y2a [xschem getprop rect 2 0 y2]
    set x1a [xschem getprop rect 2 0 x1]; set x2a [xschem getprop rect 2 0 x2]
    wviewer::wheel $tok $vdrw up 0
    xschem new_schematic switch $vdrw
    set dyu1 [expr {[xschem getprop rect 2 0 y1] - $y1a}]
    set dyu2 [expr {[xschem getprop rect 2 0 y2] - $y2a}]
    check_true "IX-vpan-up y1,y2 shift by the same nonzero delta" \
      [expr {abs($dyu1 - $dyu2) < 1e-9 && abs($dyu1) > 1e-9}]
    check_true "IX-vpan-up x range unchanged" \
      [expr {[xschem getprop rect 2 0 x1] == $x1a &&
             [xschem getprop rect 2 0 x2] == $x2a}]
    check_true "IX-vpan-up canvas == baseline (graph-not-canvas)" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set y1a [xschem getprop rect 2 0 y1]; set y2a [xschem getprop rect 2 0 y2]
    wviewer::wheel $tok $vdrw down 0
    xschem new_schematic switch $vdrw
    set dyd1 [expr {[xschem getprop rect 2 0 y1] - $y1a}]
    set dyd2 [expr {[xschem getprop rect 2 0 y2] - $y2a}]
    check_true "IX-vpan-dn y1,y2 shift by the same nonzero delta" \
      [expr {abs($dyd1 - $dyd2) < 1e-9 && abs($dyd1) > 1e-9}]
    check_true "IX-vpan-dn is opposite in sign to IX-vpan-up" \
      [expr {$dyd1 * $dyu1 < 0}]
    check_true "IX-vpan-dn canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-hpan: Shift+wheel = GRAPH horizontal pan -------------------------
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set x1a [xschem getprop rect 2 0 x1]; set x2a [xschem getprop rect 2 0 x2]
    set y1a [xschem getprop rect 2 0 y1]; set y2a [xschem getprop rect 2 0 y2]
    wviewer::wheel $tok $vdrw up shift
    xschem new_schematic switch $vdrw
    set dxh1 [expr {[xschem getprop rect 2 0 x1] - $x1a}]
    set dxh2 [expr {[xschem getprop rect 2 0 x2] - $x2a}]
    check_true "IX-hpan x1,x2 shift by the same nonzero delta" \
      [expr {abs($dxh1 - $dxh2) < 1e-9 && abs($dxh1) > 1e-9}]
    check_true "IX-hpan y range unchanged" \
      [expr {[xschem getprop rect 2 0 y1] == $y1a &&
             [xschem getprop rect 2 0 y2] == $y2a}]
    check_true "IX-hpan canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-anchor-pure (issue 0146): wviewer::zoom_about keeps the anchor at
    # the same relative position; empty anchor = centre; outside anchor clamps.
    # Pure math, no display needed. --------------------------------------------
    lassign [wviewer::zoom_about 0 10 2 0.8] _zl _zh
    check_true {IX-anchor-pure anchor 2 in 0..10 f=0.8 -> 0.4 8.4} \
      [expr {abs($_zl - 0.4) < 1e-12 && abs($_zh - 8.4) < 1e-12}]
    check {IX-anchor-pure empty anchor == centre -> {1.0 9.0}} \
      [wviewer::zoom_about 0 10 {} 0.8] {1.0 9.0}
    check {IX-anchor-pure anchor past hi clamps to hi -> {2.0 10.0}} \
      [wviewer::zoom_about 0 10 20 0.8] {2.0 10.0}
    set _za [wviewer::zoom_about 0 10 2 0.8]
    check_true "IX-anchor-pure span scales by f (8 == 10*0.8)" \
      [expr {abs(([lindex $_za 1] - [lindex $_za 0]) - 8.0) < 1e-12}]
    check_true "IX-anchor-pure anchor fraction preserved (0.2)" \
      [expr {abs((2.0 - [lindex $_za 0]) / 8.0 - 0.2) < 1e-12}]

    # --- IX-zoom-in / IX-zoom-out: Ctrl+wheel = GRAPH zoom, BOTH axes on the
    # strip under the cursor (issue 0144; the y-span legs are RED pre-fix, when
    # ctrl-wheel was X-only) -------------------------------------------------
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set span0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspan0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    wviewer::wheel $tok $vdrw up ctrl
    xschem new_schematic switch $vdrw
    set spani [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspani [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-zoom-in x-span strictly smaller" [expr {$spani < $span0 - 1e-9}]
    check_true "IX-zoom-in y-span strictly smaller (both axes)" \
      [expr {$yspani < $yspan0 - 1e-9}]
    check_true "IX-zoom-in canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set span0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspan0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    wviewer::wheel $tok $vdrw down ctrl
    xschem new_schematic switch $vdrw
    set spano [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspano [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-zoom-out x-span strictly larger" [expr {$spano > $span0 + 1e-9}]
    check_true "IX-zoom-out y-span strictly larger (both axes)" \
      [expr {$yspano > $yspan0 + 1e-9}]
    check_true "IX-zoom-out canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-anchor (issue 0146): THE teeth — Ctrl+wheel must zoom AT the mouse
    # pointer, like the schematic's view_zoom. The invariant: the data point under
    # a given canvas pixel is the SAME before and after the zoom. Uses a pixel
    # well OFF-centre (30% of the canvas, inside the plot body: 14%..95% x,
    # 14%..86% y) so a centre-anchored zoom visibly moves it -> RED pre-fix. Also
    # validates the new C verb `xschem graph_coord`. -------------------------
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set apx [expr {int(0.30 * [winfo width $vdrw])}]
    set apy [expr {int(0.30 * [winfo height $vdrw])}]
    set a0 [xschem graph_coord 0 $apx $apy]
    check_true "IX-anchor graph_coord returns two numbers" \
      [expr {[llength $a0] == 2 && [string is double -strict [lindex $a0 0]] &&
             [string is double -strict [lindex $a0 1]]}]
    set xs0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set ys0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-anchor probe pixel is off-centre in the data window" \
      [expr {abs([lindex $a0 0] - 5.0) > 0.5 && abs([lindex $a0 1] - 0.0) > 0.05}]
    wviewer::wheel $tok $vdrw up ctrl $apx $apy
    xschem new_schematic switch $vdrw
    set a1 [xschem graph_coord 0 $apx $apy]
    set xs1 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set ys1 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-anchor it really zoomed in (both spans shrank)" \
      [expr {$xs1 < $xs0 - 1e-9 && $ys1 < $ys0 - 1e-9}]
    check_true "IX-anchor X under the pointer did not move" \
      [expr {abs([lindex $a1 0] - [lindex $a0 0]) < 1e-6 * $xs0}]
    check_true "IX-anchor Y under the pointer did not move" \
      [expr {abs([lindex $a1 1] - [lindex $a0 1]) < 1e-6 * $ys0}]
    # zoom back OUT at the same pixel: still pinned
    wviewer::wheel $tok $vdrw down ctrl $apx $apy
    xschem new_schematic switch $vdrw
    set a2 [xschem graph_coord 0 $apx $apy]
    check_true "IX-anchor zoom-out at the same pixel stays pinned" \
      [expr {abs([lindex $a2 0] - [lindex $a0 0]) < 1e-6 * $xs0 &&
             abs([lindex $a2 1] - [lindex $a0 1]) < 1e-6 * $ys0}]
    check_true "IX-anchor canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-menu-zoomin / IX-menu-zoomout: View menu commands. Like Ctrl+wheel
    # they zoom BOTH axes on the pointed strip (issue 0145; the y-span legs are
    # RED pre-fix, when the menu zoom was X-only) --------------------------
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set span0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspan0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    $mb.view invoke [$mb.view index {Zoom In}]
    xschem new_schematic switch $vdrw
    set spani [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspani [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-menu-zoomin x-span shrinks on the graph" \
      [expr {$spani < $span0 - 1e-9}]
    check_true "IX-menu-zoomin y-span shrinks too (both axes)" \
      [expr {$yspani < $yspan0 - 1e-9}]
    check_true "IX-menu-zoomin canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set span0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspan0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    $mb.view invoke [$mb.view index {Zoom Out}]
    xschem new_schematic switch $vdrw
    set spano [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set yspano [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    check_true "IX-menu-zoomout x-span grows on the graph" \
      [expr {$spano > $span0 + 1e-9}]
    check_true "IX-menu-zoomout y-span grows too (both axes)" \
      [expr {$yspano > $yspan0 + 1e-9}]
    check_true "IX-menu-zoomout canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-rmb: right-drag = GRAPH x-zoom-to-box via the C engine -----------
    # Drive wviewer::btn3_filter (the forwarder S3 sabotages) with a synthetic
    # ButtonPress then ButtonRelease at two body x pixels (30% / 70% of width,
    # mid-height): well inside the plot body (horizontally 14%..95%, vertically
    # 14%..86% of the full-window graph rect), so graph_left/graph_top are 0 and
    # the C GRAPHPAN x-zoom-to-box path fires (callback.c:1000/:1454). The box
    # narrows the graph rect x-range; the canvas stays pinned. The rect-x state
    # change also proves btn3_filter forwarded (S3's unconditional swallow leaves
    # it unchanged).
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set rx1_0 [xschem getprop rect 2 0 x1]
    set rx2_0 [xschem getprop rect 2 0 x2]
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    set px1 [expr {int(0.30 * $W)}]
    set px2 [expr {int(0.70 * $W)}]
    set py  [expr {int(0.50 * $H)}]
    wviewer::btn3_filter $vdrw 4 $px1 $py 3 0        ;# ButtonPress   -> GRAPHPAN
    wviewer::btn3_filter $vdrw 5 $px2 $py 3 0        ;# ButtonRelease -> zoom box
    xschem new_schematic switch $vdrw
    set rx1_1 [xschem getprop rect 2 0 x1]
    set rx2_1 [xschem getprop rect 2 0 x2]
    check_true "IX-rmb graph x1 narrowed inward (x1 grew)" \
      [expr {$rx1_1 > $rx1_0 + 1e-9}]
    check_true "IX-rmb graph x2 narrowed inward (x2 shrank)" \
      [expr {$rx2_1 < $rx2_0 - 1e-9}]
    check_true "IX-rmb graph x-span narrowed toward the box" \
      [expr {($rx2_1 - $rx1_1) < ($rx2_0 - $rx1_0) - 1e-9}]
    check_true "IX-rmb canvas == baseline (graph zoom, not canvas)" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # --- IX-zoom-strips (issue 0144): Ctrl+wheel zooms X on EVERY strip but Y
    # ONLY on the strip under the cursor. Drives the synchronous write seam
    # wviewer::wheel_zoom with an EXPLICIT target index (the gesture path's own
    # pointer resolution, graph_at_pointer, is covered by the single-graph legs
    # above — a 2-strip pointer position is not reproducible headlessly).
    # Restores ONE strip at the end so IX-fit below still sees the 1-graph
    # layout. -----------------------------------------------------------------
    wviewer::add_graph $tok                                  ;# now 2 strips
    set gs2 [dict get [wviewer::layout_for $tok] graphs]
    set sg0 [dict replace [lindex $gs2 0] x1 0 x2 10 y1 -1 y2 1]
    set sg1 [dict replace [lindex $gs2 1] x1 0 x2 10 y1 -2 y2 2]
    wviewer::set_graphs $tok [list $sg0 $sg1]
    wviewer::regenerate $tok
    xschem new_schematic switch $vdrw
    set ax0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set ay0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    set bx0 [expr {[xschem getprop rect 2 1 x2] - [xschem getprop rect 2 1 x1]}]
    set by0 [expr {[xschem getprop rect 2 1 y2] - [xschem getprop rect 2 1 y1]}]
    check_true "IX-zoom-strips setup: 2 strips with concrete x+y ranges" \
      [expr {$ax0 > 0 && $ay0 > 0 && $bx0 > 0 && $by0 > 0}]
    wviewer::wheel_zoom $tok up 1                            ;# cursor on strip 1
    xschem new_schematic switch $vdrw
    set ax1 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set ay1 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    set bx1 [expr {[xschem getprop rect 2 1 x2] - [xschem getprop rect 2 1 x1]}]
    set by1 [expr {[xschem getprop rect 2 1 y2] - [xschem getprop rect 2 1 y1]}]
    check_true "IX-zoom-strips pointed strip 1 zooms X" [expr {$bx1 < $bx0 - 1e-9}]
    check_true "IX-zoom-strips pointed strip 1 zooms Y" [expr {$by1 < $by0 - 1e-9}]
    check_true "IX-zoom-strips other strip 0 MATCHES the X zoom" \
      [expr {abs($ax1 - $bx1) < 1e-9 && $ax1 < $ax0 - 1e-9}]
    check_true "IX-zoom-strips other strip 0 keeps its Y (X-only)" \
      [expr {abs($ay1 - $ay0) < 1e-9}]
    check_true "IX-zoom-strips canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # same contract through graph_zoom — the View-menu / Z / Ctrl-z path (issue
    # 0145) — here with an EXPLICIT target strip 0 and the opposite direction
    wviewer::set_graphs $tok [list $sg0 $sg1]
    wviewer::regenerate $tok
    xschem new_schematic switch $vdrw
    set mx0 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set my0 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    set nx0 [expr {[xschem getprop rect 2 1 x2] - [xschem getprop rect 2 1 x1]}]
    set ny0 [expr {[xschem getprop rect 2 1 y2] - [xschem getprop rect 2 1 y1]}]
    wviewer::graph_zoom $tok out 0                           ;# target strip 0
    xschem new_schematic switch $vdrw
    set mx1 [expr {[xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]}]
    set my1 [expr {[xschem getprop rect 2 0 y2] - [xschem getprop rect 2 0 y1]}]
    set nx1 [expr {[xschem getprop rect 2 1 x2] - [xschem getprop rect 2 1 x1]}]
    set ny1 [expr {[xschem getprop rect 2 1 y2] - [xschem getprop rect 2 1 y1]}]
    check_true "IX-zoom-strips graph_zoom target strip 0 zooms X out" \
      [expr {$mx1 > $mx0 + 1e-9}]
    check_true "IX-zoom-strips graph_zoom target strip 0 zooms Y out" \
      [expr {$my1 > $my0 + 1e-9}]
    check_true "IX-zoom-strips graph_zoom other strip 1 MATCHES the X zoom" \
      [expr {abs($nx1 - $mx1) < 1e-9 && $nx1 > $nx0 + 1e-9}]
    check_true "IX-zoom-strips graph_zoom other strip 1 keeps its Y (X-only)" \
      [expr {abs($ny1 - $ny0) < 1e-9}]

    wviewer::set_graphs $tok [list $sg0]                     ;# back to 1 strip
    wviewer::regenerate $tok

    # === CG (issue 0149): the graphs OWN the viewer window ====================
    # No gesture in the viewer may scroll/pan the CANVAS — that slides the tiled
    # graph stack around a bigger canvas and exposes blank space. Teeth for both
    # reported holes: the arrow keys (bare = graph pan, modified = swallowed;
    # previously forwarded and reaching view.scroll_* / the hard-coded origin pan
    # / prev_tab-next_tab) and the middle button (the C canvas PAN gesture, which
    # waves_selected explicitly refuses to graph-route). Every leg re-asserts the
    # canvas baseline.

    # CG-arrow-right / -left: bare Left/Right pan the graph X, through the
    # PRODUCTION key_filter (KeyPress, T==2), not a helper shortcut.
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set ax1 [xschem getprop rect 2 0 x1]; set ax2 [xschem getprop rect 2 0 x2]
    set ay1 [xschem getprop rect 2 0 y1]; set ay2 [xschem getprop rect 2 0 y2]
    wviewer::key_filter $vdrw 2 10 10 65363 Right 0
    xschem new_schematic switch $vdrw
    set dx1 [expr {[xschem getprop rect 2 0 x1] - $ax1}]
    set dx2 [expr {[xschem getprop rect 2 0 x2] - $ax2}]
    check_true "CG-arrow-right pans graph x by one positive delta" \
      [expr {abs($dx1 - $dx2) < 1e-9 && $dx1 > 1e-9}]
    check_true "CG-arrow-right leaves y alone" \
      [expr {[xschem getprop rect 2 0 y1] == $ay1 &&
             [xschem getprop rect 2 0 y2] == $ay2}]
    check_true "CG-arrow-right canvas == baseline (no canvas scroll)" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set ax1 [xschem getprop rect 2 0 x1]; set ax2 [xschem getprop rect 2 0 x2]
    wviewer::key_filter $vdrw 2 10 10 65361 Left 0
    xschem new_schematic switch $vdrw
    set dx1 [expr {[xschem getprop rect 2 0 x1] - $ax1}]
    set dx2 [expr {[xschem getprop rect 2 0 x2] - $ax2}]
    check_true "CG-arrow-left pans graph x by one negative delta" \
      [expr {abs($dx1 - $dx2) < 1e-9 && $dx1 < -1e-9}]
    check_true "CG-arrow-left canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # CG-arrow-up / -down: bare Up/Down pan the graph Y
    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set ay1 [xschem getprop rect 2 0 y1]; set ay2 [xschem getprop rect 2 0 y2]
    set ax1 [xschem getprop rect 2 0 x1]; set ax2 [xschem getprop rect 2 0 x2]
    wviewer::key_filter $vdrw 2 10 10 65362 Up 0
    xschem new_schematic switch $vdrw
    set dy1 [expr {[xschem getprop rect 2 0 y1] - $ay1}]
    set dy2 [expr {[xschem getprop rect 2 0 y2] - $ay2}]
    check_true "CG-arrow-up pans graph y by one positive delta" \
      [expr {abs($dy1 - $dy2) < 1e-9 && $dy1 > 1e-9}]
    check_true "CG-arrow-up leaves x alone" \
      [expr {[xschem getprop rect 2 0 x1] == $ax1 &&
             [xschem getprop rect 2 0 x2] == $ax2}]
    check_true "CG-arrow-up canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    ix_setrange $tok 0 10 -1 1
    xschem new_schematic switch $vdrw
    set ay1 [xschem getprop rect 2 0 y1]; set ay2 [xschem getprop rect 2 0 y2]
    wviewer::key_filter $vdrw 2 10 10 65364 Down 0
    xschem new_schematic switch $vdrw
    set dy1 [expr {[xschem getprop rect 2 0 y1] - $ay1}]
    set dy2 [expr {[xschem getprop rect 2 0 y2] - $ay2}]
    check_true "CG-arrow-down pans graph y by one negative delta" \
      [expr {abs($dy1 - $dy2) < 1e-9 && $dy1 < -1e-9}]
    check_true "CG-arrow-down canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # CG-arrow-mod: Shift(1) / Ctrl(4) / Alt(8) + arrow are SWALLOWED — neither
    # the graph NOR the canvas may move. Ctrl+Left/Right used to switch TABS and
    # Alt+arrow used to pan the canvas origin outright.
    foreach {mname mask} {shift 1 ctrl 4 alt 8} {
      ix_setrange $tok 0 10 -1 1
      xschem new_schematic switch $vdrw
      set bx1 [xschem getprop rect 2 0 x1]; set bx2 [xschem getprop rect 2 0 x2]
      set by1 [xschem getprop rect 2 0 y1]; set by2 [xschem getprop rect 2 0 y2]
      foreach ks {65361 65362 65363 65364} {
        wviewer::key_filter $vdrw 2 10 10 $ks Arrow $mask
      }
      xschem new_schematic switch $vdrw
      check_true "CG-arrow-$mname graph range unchanged (swallowed)" \
        [expr {[xschem getprop rect 2 0 x1] == $bx1 &&
               [xschem getprop rect 2 0 x2] == $bx2 &&
               [xschem getprop rect 2 0 y1] == $by1 &&
               [xschem getprop rect 2 0 y2] == $by2}]
      check_true "CG-arrow-$mname canvas == baseline" \
        [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]
    }

    # === CG-panx (issue 0150): X pans the WHOLE stack, Y stays per-strip ======
    # Two strips, SAME x range, DIFFERENT y ranges. Shift+wheel (and the Left/
    # Right arrows, which delegate to it) used to pan x on the pointed strip
    # only, sliding one strip out of time-alignment with the rest. Y must stay
    # independent: a vertical pan moves exactly ONE strip's y.
    wviewer::add_graph $tok                                  ;# 2 strips again
    proc cg_setpair {tok} {
      set gs [dict get [wviewer::layout_for $tok] graphs]
      set a [dict replace [lindex $gs 0] x1 0 x2 10 y1 -1 y2 1]
      set b [dict replace [lindex $gs 1] x1 0 x2 10 y1 -2 y2 2]
      wviewer::set_graphs $tok [list $a $b]
      wviewer::regenerate $tok
    }
    proc cg_ranges {vdrw gi} {
      xschem new_schematic switch $vdrw
      list [xschem getprop rect 2 $gi x1] [xschem getprop rect 2 $gi x2] \
           [xschem getprop rect 2 $gi y1] [xschem getprop rect 2 $gi y2]
    }
    cg_setpair $tok
    lassign [cg_ranges $vdrw 0] p0x1 p0x2 p0y1 p0y2
    lassign [cg_ranges $vdrw 1] p1x1 p1x2 p1y1 p1y2
    check_true "CG-panx setup: 2 strips, same x, different y" \
      [expr {$p0x1 == $p1x1 && $p0x2 == $p1x2 && $p0y2 != $p1y2}]
    wviewer::wheel $tok $vdrw up shift
    lassign [cg_ranges $vdrw 0] q0x1 q0x2 q0y1 q0y2
    lassign [cg_ranges $vdrw 1] q1x1 q1x2 q1y1 q1y2
    check_true "CG-panx shift+wheel moved strip 0 x by a positive delta" \
      [expr {($q0x1 - $p0x1) > 1e-9 && abs(($q0x1 - $p0x1) - ($q0x2 - $p0x2)) < 1e-9}]
    check_true "CG-panx strip 1 moved by the SAME x delta (stack stays aligned)" \
      [expr {abs(($q1x1 - $p1x1) - ($q0x1 - $p0x1)) < 1e-9 &&
             abs(($q1x2 - $p1x2) - ($q0x2 - $p0x2)) < 1e-9}]
    check_true "CG-panx both strips still share one x window" \
      [expr {abs($q0x1 - $q1x1) < 1e-9 && abs($q0x2 - $q1x2) < 1e-9}]
    check_true "CG-panx y untouched on BOTH strips" \
      [expr {$q0y1 == $p0y1 && $q0y2 == $p0y2 &&
             $q1y1 == $p1y1 && $q1y2 == $p1y2}]
    check_true "CG-panx canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # the Left/Right arrows go through the same seam (production key_filter)
    cg_setpair $tok
    lassign [cg_ranges $vdrw 0] p0x1 p0x2 p0y1 p0y2
    lassign [cg_ranges $vdrw 1] p1x1 p1x2 p1y1 p1y2
    wviewer::key_filter $vdrw 2 10 10 65361 Left 0
    lassign [cg_ranges $vdrw 0] q0x1 q0x2 q0y1 q0y2
    lassign [cg_ranges $vdrw 1] q1x1 q1x2 q1y1 q1y2
    check_true "CG-panx Left arrow moved strip 0 x negative" \
      [expr {($q0x1 - $p0x1) < -1e-9}]
    check_true "CG-panx Left arrow moved strip 1 by the SAME delta" \
      [expr {abs(($q1x1 - $p1x1) - ($q0x1 - $p0x1)) < 1e-9 &&
             abs(($q1x2 - $p1x2) - ($q0x2 - $p0x2)) < 1e-9}]

    # Y independence: a vertical pan moves exactly ONE strip's y (whichever the
    # pointer resolves to — the count is what matters), and no strip's x.
    cg_setpair $tok
    lassign [cg_ranges $vdrw 0] p0x1 p0x2 p0y1 p0y2
    lassign [cg_ranges $vdrw 1] p1x1 p1x2 p1y1 p1y2
    wviewer::wheel $tok $vdrw up 0
    lassign [cg_ranges $vdrw 0] q0x1 q0x2 q0y1 q0y2
    lassign [cg_ranges $vdrw 1] q1x1 q1x2 q1y1 q1y2
    set moved 0
    if {$q0y1 != $p0y1 || $q0y2 != $p0y2} { incr moved }
    if {$q1y1 != $p1y1 || $q1y2 != $p1y2} { incr moved }
    check "CG-panx vertical pan moved exactly ONE strip's y" $moved 1
    check_true "CG-panx vertical pan left every x alone" \
      [expr {$q0x1 == $p0x1 && $q0x2 == $p0x2 &&
             $q1x1 == $p1x1 && $q1x2 == $p1x2}]
    check_true "CG-panx vertical pan canvas == baseline" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    rename cg_setpair {}
    rename cg_ranges {}
    set gs1 [dict get [wviewer::layout_for $tok] graphs]
    wviewer::set_graphs $tok [list [lindex $gs1 0]]           ;# back to 1 strip
    wviewer::regenerate $tok

    # CG-binds: the canvas-only mouse gestures are bound to a swallow on THIS
    # canvas (per-widget; other windows keep theirs). Button-2 LEFT this set when
    # the graph pan moved off LMB (strip drag-reorder): it is now forwarded
    # through btn2_filter, which is what CG-mmb2 below exercises. What must still
    # hold for MMB is the OUTCOME, not the swallow — the canvas never moves.
    foreach seq {<Shift-ButtonPress-1> <Shift-ButtonRelease-1> <Shift-B1-Motion>
                 <Alt-ButtonPress-1> <Alt-ButtonRelease-1> <Alt-B1-Motion>} {
      check "CG-binds $seq swallowed" [string trim [bind $vdrw $seq]] break
    }
    foreach seq {<ButtonPress-2> <ButtonRelease-2> <B2-Motion>} {
      check_true "CG-binds $seq routed through btn2_filter" \
        [string match {*wviewer::btn2_filter*} [bind $vdrw $seq]]
    }

    # CG-mmb: a full synthetic MIDDLE-button press -> drag -> release. It must
    # never move the CANVAS: pre-0149 the press reached handle_button_press ->
    # start_pan_logged and the Button2Mask motion panned the canvas origin. It is
    # now the GRAPH pan instead (btn2_filter forwards it, callback.c pans data
    # ranges), so the canvas stays pinned for the opposite reason — assert the
    # canvas invariant here, the data-range effect in CG-mmb2. 0x200 = Button2Mask.
    set W [winfo width $vdrw]; set H [winfo height $vdrw]
    set mpx1 [expr {int(0.30 * $W)}]; set mpx2 [expr {int(0.70 * $W)}]
    set mpy  [expr {int(0.50 * $H)}]
    event generate $vdrw <ButtonPress-2>   -x $mpx1 -y $mpy
    event generate $vdrw <Motion>          -x $mpx2 -y $mpy -state 0x200
    event generate $vdrw <ButtonRelease-2> -x $mpx2 -y $mpy -state 0x200
    update
    check_true "CG-mmb middle-drag left the canvas at baseline (no pan)" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]
    # ...and the same gesture STARTED IN THE ENGINE'S BORDER, three pixels
    # inside the top edge of the strip. The engine's graph test does not take
    # that pixel for the graph, so a press forwarded there is the schematic
    # canvas pan, the gesture issue 0149 took out of this window. btn2_filter
    # refuses such a press (wviewer::strip_at_pixel_inset) and the motion and
    # the release follow the press: the canvas view stays where it was. The
    # band is the canvas' own (wviewer::strip_bands_px).
    set mmb_b [lindex [wviewer::strip_bands_px $vdrw] 0]
    set mmb_in no-band
    if {[llength $mmb_b] == 4} {
      set mby [expr {int(ceil([lindex $mmb_b 1])) + 3}]
      set mmb_in [expr {$mpx1 > [lindex $mmb_b 0] && $mpx1 < [lindex $mmb_b 2] &&
                        $mby > [lindex $mmb_b 1] && $mby < [lindex $mmb_b 3]}]
      event generate $vdrw <ButtonPress-2>   -x $mpx1 -y $mby
      event generate $vdrw <Motion>          -x $mpx2 -y [expr {$mby + 60}] -state 0x200
      event generate $vdrw <ButtonRelease-2> -x $mpx2 -y [expr {$mby + 60}] -state 0x200
      update
    }
    check "CG-mmb a middle-button press, drag and release that starts three pixels inside the top edge of the strip leaves the canvas view where it was (the press pixel is inside the strip's band, the canvas is at its baseline)" \
      [list $mmb_in [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]] {1 1}

    # CG-shift-b1: Shift+drag is the schematic rubber-band/copy gesture and
    # Alt+B1 the unselect-at-pointer click — both canvas-only (waves_selected
    # refuses to graph-route them). The swallow itself is witnessed by the
    # CG-binds checks above; here we only assert the gesture is inert and, in
    # particular, cannot move the canvas. (A selection witness would be HOLLOW:
    # neither a shift rubber-band nor a shift-click inside the full-window graph
    # rect selects it — probe-verified with the binds sabotaged, lastsel stayed
    # 0 — so `lastsel == 0` would pass with the fix reverted.)
    catch {xschem unselect_all}
    event generate $vdrw <Shift-ButtonPress-1>   -x $mpx1 -y $mpy -state 1
    event generate $vdrw <Motion>                -x $mpx2 -y $mpy -state 0x101
    event generate $vdrw <Shift-ButtonRelease-1> -x $mpx2 -y $mpy -state 0x101
    event generate $vdrw <Alt-ButtonPress-1>     -x $mpx1 -y $mpy -state 8
    event generate $vdrw <Alt-ButtonRelease-1>   -x $mpx1 -y $mpy -state 0x108
    update
    xschem new_schematic switch $vdrw
    check_true "CG-shift-b1 canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    # === WB (issue 0152): wave bold is an LMB CLICK, never an RMB press ======
    # Reported: RMB near a plotted trace makes it thick, and the RMB press-drag
    # box-zoom (issue 0142) does it too. The bold is the `hilight_wave` prop
    # token (draw.c setup_graph_data / draw_graph); it used to be toggled on
    # Button3 PRESS in waves_callback, so every RMB gesture bolted whatever
    # trace was nearest the press point. It is now the RELEASE of a Button1
    # press that did not travel.
    #
    # Needs REAL data: find_closest_wave() bails on a NULL xctx->raw, so with no
    # raw every click would write hilight_wave=-1 and nothing is witnessable
    # (the green-but-hollow trap). Full Tk event sequences through the
    # PRODUCTION bindings (<ButtonPress-1> forward, kept generic <ButtonRelease>,
    # btn3_filter), never a lone synthetic callback.
    if {$have_raw} {
      xschem new_schematic switch $vdrw
      check "WB raw read into the IX viewer ctx" [rawq {xschem raw read $rawpath dc}] 1
      check "WB add one trace to strip 0" [wviewer::add_trace $tok 0 {i(v1)}] {}
      wviewer::fit $tok                 ;# data inside the plot box -> wcnt >= 0
      proc wb_bold {vdrw} {
        xschem new_schematic switch $vdrw
        set v [xschem getprop rect 2 0 hilight_wave]
        if {$v eq {}} { return -1 }
        return $v
      }
      # the viewer buffer is readonly, so the reset goes through with_edit like
      # every other viewer mutation (landmine 17)
      proc wb_reset {tok} {
        wviewer::with_edit $tok {xschem setprop rect 2 0 hilight_wave -1}
      }
      # Every synthetic event carries an explicitly INCREASING %t. Without it Tk
      # collapses two identical presses that fall inside its double-click window
      # into <Double-Button-N>, which the viewer binds to {break} -- the second
      # press then vanishes entirely (probe-verified: no `xschem callback` at all,
      # and the leg failed for a reason that had nothing to do with the code under
      # test). Explicit times make the pairing independent of the wall clock.
      set ::wbt 100000
      proc wb_ev {w seq args} {
        set ::wbt [expr {$::wbt + 1000}]
        eval [list event generate $w $seq -time $::wbt] $args
      }
      set W [winfo width $vdrw]; set H [winfo height $vdrw]
      set bpx  [expr {int(0.50 * $W)}]      ;# well inside the plot body
      set bpx2 [expr {int(0.70 * $W)}]      ;# a drag away from it
      set bpy  [expr {int(0.50 * $H)}]

      # issue 0174: the pick is a real SCREEN-PIXEL distance to the trace
      # (GRAPH_TRACE_PICK_TOL, 10), so the click pixel can no longer be a fixed
      # fraction of the widget. Scan for one the ENGINE agrees is on the trace,
      # and one inside the PLOT BOX that is far from every trace. Both scanned
      # rather than assumed: the strip geometry follows the WM's window size,
      # and a hard-coded fraction is exactly what let the pre-0174 WB-click leg
      # pass against a pick with no threshold at all — measured, (0.50W, 0.50H)
      # on this fixture sits about 0.30*H away from the only trace.
      # plotbox_at keeps the far pixel out of the legend/label margin, which is
      # Button3's territory (WB-legend below).
      proc wb_at {vdrw gi px py {tol 10}} {
        xschem new_schematic switch $vdrw
        set r -1
        catch {set r [xschem get graph_trace_at $gi $px $py $tol]}
        if {![string is integer -strict $r]} { return -1 }
        return $r
      }
      # ⚠ RESCAN, do not reuse: the legs between here and the end of the WB block
      # ZOOM (WB-rmb-drag) and PAN (WB-mmb-drag) the graph, so a row that was
      # trace-free when the block started can have a trace on it later. A stale
      # "far" pixel silently becomes an ON-trace pixel and the leg using it
      # asserts the opposite of what it means to.
      proc wb_far_row {vdrw gi px H} {
        for {set y 2} {$y < $H} {incr y 1} {
          if {![wviewer::plotbox_at $vdrw $gi $px $y]} { continue }
          if {[wb_at $vdrw $gi $px $y] >= 0} { continue }
          if {[wb_at $vdrw $gi $px $y 1e30] >= 0} { return $y }
        }
        return {}
      }
      set wbony {}       ;# a row ON the trace
      set wboffy {}      ;# a row inside the box but > 10 px from every trace
      for {set y 2} {$y < $H} {incr y 1} {
        if {![wviewer::plotbox_at $vdrw 0 $bpx $y]} { continue }
        if {[wb_at $vdrw 0 $bpx $y] >= 0} {
          if {$wbony eq {}} { set wbony $y }
        } elseif {$wboffy eq {} && [wb_at $vdrw 0 $bpx $y 1e30] >= 0} {
          set wboffy $y
        }
      }
      check_true "WB-precise a pixel ON the trace was found" [expr {$wbony ne {}}]
      check_true "WB-precise a plot-box pixel FAR from every trace was found" \
        [expr {$wboffy ne {}}]
      if {$wbony eq {}} { set wbony $bpy }
      if {$wboffy eq {}} { set wboffy $bpy }

      wb_reset $tok
      check "WB-setup nothing bold to start" [wb_bold $vdrw] -1

      # WB-click: press+release at the SAME pixel, ON the trace, bolds it; a
      # second click on the SAME trace leaves it bold (D3, settled at review:
      # a plain click never deselects what it lands on — Cadence behaviour, and
      # de-selecting one trace becomes 0175's Ctrl+click).
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbony
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbony -state 0x100
      update
      check "WB-click LMB click ON a trace bolds it (trace 0)" [wb_bold $vdrw] 0
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbony
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbony -state 0x100
      update
      check "WB-click a second click on the same trace KEEPS it bold" [wb_bold $vdrw] 0
      check_true "WB-click canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]
      wb_reset $tok

      # WB-precise (issue 0174): THE leg that fails on the pre-fix code. A click
      # inside the plot body but more than the pick tolerance from every trace
      # must select NOTHING — the old pick had no threshold and bolted the
      # nearest trace however far away, so "in the vicinity of a trace" was
      # really "anywhere in the plot body".
      # Teeth: the same pixel with an enormous tolerance DOES find a trace, so
      # -1 at the shipping tolerance means "far", not "this strip has no data".
      check_true "WB-precise the far pixel is FAR, not data-less (huge tol hits)" \
        [expr {[wb_at $vdrw 0 $bpx $wboffy 1e30] >= 0}]
      check "WB-precise ... and the shipping tolerance calls it empty" \
        [wb_at $vdrw 0 $bpx $wboffy] -1
      wb_reset $tok
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wboffy
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wboffy -state 0x100
      update
      check "WB-precise a click far from every trace bolds NOTHING" [wb_bold $vdrw] -1
      # ... and it CLEARS an existing selection (D2, settled at review). It does
      # not collide with the strip drag-reorder that also owns empty body space:
      # the two are separated by the TRAVEL test, not by this arm — a real
      # reorder drag travels well past GRAPH_CLICK_TOL and its release never
      # reaches the arm at all. WB-lmb-drag below is that half.
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbony
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbony -state 0x100
      update
      check "WB-precise a trace is bold before the far click" [wb_bold $vdrw] 0
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wboffy
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wboffy -state 0x100
      update
      check "WB-precise a far click CLEARS the selection" [wb_bold $vdrw] -1
      wb_reset $tok

      # WB-rmb-click: THE reported defect, minimal form. An RMB press+release in
      # the plot body must leave the bold alone (it is box-zoom only now).
      # RED pre-fix: the press toggled it to 0.
      wb_reset $tok
      wb_ev $vdrw <ButtonPress-3>   -x $bpx -y $bpy
      wb_ev $vdrw <ButtonRelease-3> -x $bpx -y $bpy -state 0x400
      update
      check "WB-rmb-click RMB click leaves the bold alone" [wb_bold $vdrw] -1
      # that click posts a context menu on this one-trace strip since issue
      # 1662, and a posted menu holds the grab: take it down before the drag
      catch {wviewer::trace_menu_unpost $tok}
      catch {wviewer::strip_menu_unpost $tok}
      update

      # WB-rmb-drag: the reported defect in its real form — an RMB press-drag
      # box-zoom must not bold. Asserts the zoom STILL happened, so this cannot
      # pass by the gesture silently dying. RED pre-fix.
      wb_reset $tok
      wviewer::fit $tok
      xschem new_schematic switch $vdrw
      set wbx1 [xschem getprop rect 2 0 x1]
      set wbx2 [xschem getprop rect 2 0 x2]
      wb_ev $vdrw <ButtonPress-3>   -x [expr {int(0.30 * $W)}] -y $bpy
      wb_ev $vdrw <ButtonRelease-3> -x [expr {int(0.70 * $W)}] -y $bpy -state 0x400
      update
      check "WB-rmb-drag box-zoom leaves the bold alone" [wb_bold $vdrw] -1
      xschem new_schematic switch $vdrw
      check_true "WB-rmb-drag really did zoom (x-span narrowed)" \
        [expr {([xschem getprop rect 2 0 x2] - [xschem getprop rect 2 0 x1]) <
               ($wbx2 - $wbx1) - 1e-9}]

      # WB-lmb-drag: the SAME hazard on the new trigger — a Button1 drag must not
      # have its release read as a click. The teeth for using dedicated
      # graph_press_x/y instead of mx/my_double_save (which the pan re-seeded on
      # every motion step, waves_callback save_mouse_at_end).
      # CONTRACT CHANGE (strip drag-reorder): LMB no longer pans the graph — the
      # pan moved to MMB so LMB can own precise interaction and strip reordering.
      # So this leg now asserts the pan did NOT happen, and WB-mmb-drag below
      # asserts that MMB does it instead. Both together are the teeth: without the
      # second one "no pan" would also pass with the gesture silently dead.
      wb_reset $tok
      wviewer::fit $tok
      xschem new_schematic switch $vdrw
      set wbp1 [xschem getprop rect 2 0 x1]
      wb_ev $vdrw <ButtonPress-1> -x $bpx -y $bpy
      foreach fx {0.55 0.60 0.65 0.70} {
        wb_ev $vdrw <Motion> -x [expr {int($fx * $W)}] -y $bpy -state 0x100
      }
      wb_ev $vdrw <ButtonRelease-1> -x $bpx2 -y $bpy -state 0x100
      update
      check "WB-lmb-drag LMB drag does NOT bold" [wb_bold $vdrw] -1
      xschem new_schematic switch $vdrw
      check_true "WB-lmb-drag LMB no longer pans the graph range" \
        [expr {abs([xschem getprop rect 2 0 x1] - $wbp1) <= 1e-12}]
      check_true "WB-lmb-drag canvas == baseline" [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

      # WB-mmb-drag: the pan, on its new button. A plain MMB press-drag-release
      # inside the strip must move the graph's x range and leave the CANVAS put
      # (the issue-0149 invariant: no gesture in this window scrolls the canvas).
      wb_reset $tok
      wviewer::fit $tok
      xschem new_schematic switch $vdrw
      set wbp2 [xschem getprop rect 2 0 x1]
      wb_ev $vdrw <ButtonPress-2> -x $bpx -y $bpy
      foreach fx {0.55 0.60 0.65 0.70} {
        wb_ev $vdrw <B2-Motion> -x [expr {int($fx * $W)}] -y $bpy -state 0x200
      }
      wb_ev $vdrw <ButtonRelease-2> -x $bpx2 -y $bpy -state 0x200
      update
      xschem new_schematic switch $vdrw
      check_true "WB-mmb-drag MMB really pans the graph range (x1 moved)" \
        [expr {abs([xschem getprop rect 2 0 x1] - $wbp2) > 1e-12}]
      check_true "WB-mmb-drag canvas == baseline (graph pan, not canvas pan)" \
        [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]
      check "WB-mmb-drag MMB drag does not bold" [wb_bold $vdrw] -1

      # WB-legend: what the two buttons do on a legend entry.
      # ⚠ ISSUE 0175 CHANGED THE LMB HALF. The last leg of this block used to
      # assert that an LMB click on the legend does NOTHING ("body-only"); a
      # legend click now SELECTS that trace, which is the feature 0175 was asked
      # for, so the leg asserts the new answer. The 0152 `WB-legend` row is
      # superseded accordingly.
      # ⚠ ISSUE 0178 CHANGED THE RMB HALF, and these two legs asserted the exact
      # behaviour that was REPORTED AS WRONG at the 0177 eyeball: "RMB click on
      # legend name is selecting a trace and RMB click legend of selected trace
      # is deselecting it". Button3 outside the plot body still reaches
      # edit_wave_attributes(2,...) in the C engine — that is how graphs EMBEDDED
      # IN A SCHEMATIC still work — but the ASE viewer no longer forwards such a
      # press: wviewer::btn3_filter swallows it and posts the TRACE CONTEXT MENU
      # on the release instead, so RMB means "context menu" everywhere on this
      # canvas. Selection on the legend is LMB's and Ctrl+LMB's alone.
      # These legs now assert the NEW contract; the menu side of it is covered in
      # test_wave_trace_menu.tcl TR1-TR5, which is where that feature lives.
      wb_reset $tok
      set wbly [expr {int(0.03 * $H)}]      ;# above the plot box (14% top margin)
      wb_ev $vdrw <ButtonPress-3>   -x $bpx -y $wbly
      wb_ev $vdrw <ButtonRelease-3> -x $bpx -y $wbly -state 0x400
      update
      catch {wviewer::trace_menu_unpost $tok} ; update
      check "WB-legend RMB on the legend does NOT bold (0178)" [wb_bold $vdrw] -1
      # ...and it does not toggle one that IS bold, either: select with LMB (the
      # button that owns selection now), then RMB the same entry twice.
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbly
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbly -state 0x100
      update
      check "WB-legend (control) LMB DOES bold it, so the pixel is a legend entry" \
        [wb_bold $vdrw] 0
      foreach _wbi {1 2} {
        wb_ev $vdrw <ButtonPress-3>   -x $bpx -y $wbly
        wb_ev $vdrw <ButtonRelease-3> -x $bpx -y $wbly -state 0x400
        update
        catch {wviewer::trace_menu_unpost $tok} ; update
      }
      check "WB-legend two legend RMBs leave the selection alone (0178)" \
        [wb_bold $vdrw] 0
      wb_reset $tok
      # issue 0175: an LMB click on a legend entry SELECTS that trace. Teeth: the
      # pixel is the same one the RMB legs above just proved is a legend entry, so
      # a leg that passed because "nothing is there" is not available.
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbly
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbly -state 0x100
      update
      check "WB-legend LMB on the legend SELECTS that trace (0175)" [wb_bold $vdrw] 0
      # ... and it REPLACES rather than toggles, exactly like a body click (D3):
      # a second plain click on the same entry keeps it selected
      wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbly
      wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbly -state 0x100
      update
      check "WB-legend a second plain legend click KEEPS it selected" [wb_bold $vdrw] 0
      # ... while a plain click on the plot body FAR from every trace still
      # clears, so the legend arm did not swallow the body arm. The far row is
      # RE-SCANNED here: the RMB zoom and the MMB pan above have moved the data
      # since the block's opening scan.
      set wbfar2 [wb_far_row $vdrw 0 $bpx $H]
      check_true "WB-legend a far body row was re-scanned after the zoom/pan" \
        [expr {$wbfar2 ne {}}]
      if {$wbfar2 ne {}} {
        wb_ev $vdrw <ButtonPress-1>   -x $bpx -y $wbfar2
        wb_ev $vdrw <ButtonRelease-1> -x $bpx -y $wbfar2 -state 0x100
        update
        check "WB-legend the body arm still clears after a legend select" [wb_bold $vdrw] -1
      }

      # === SD: the LMB SEAM between the C engine and strip drag-reorder =======
      # doc/claude/specs/waveform_viewer_modes.md §12. Empty waveform space
      # belongs to strip reordering; a fixed screen-pixel band around every trace
      # — and any press that grabbed a cursor — stays with the C engine. These
      # legs need REAL data (the exclusion is answered by the engine off the raw)
      # and a two-strip stack (a reorder needs somewhere to go).
      # each strip carries an INERT identity key, so "which strip is at index k"
      # can be witnessed independently of "which trace is in strip k" — on a
      # two-strip stack a trace move and a strip reorder produce the same
      # sd_order, and only sd_ids tells them apart (the model dict is free-form;
      # regenerate/graph_props read known keys only, so `sdid` changes nothing)
      set sd_save [dict get [wviewer::layout_for $tok] graphs]
      wviewer::set_graphs $tok [list \
        [dict replace [lindex $sd_save 0] sdid A] \
        [dict replace [wviewer::empty_graph] sdid B]]
      wviewer::regenerate $tok
      wviewer::fit $tok
      xschem new_schematic switch $vdrw
      proc sd_order {tok} {
        set out {}
        foreach G [dict get [wviewer::layout_for $tok] graphs] {
          set tr [dict get $G traces]
          lappend out [expr {[llength $tr] ? [dict get [lindex $tr 0] vec] : {-}}]
        }
        return $out
      }
      proc sd_ids {tok} {
        set out {}
        foreach G [dict get [wviewer::layout_for $tok] graphs] {
          lappend out [wviewer::dget $G sdid ?]
        }
        return $out
      }
      proc sd_near {vdrw gi px py tol} {
        xschem new_schematic switch $vdrw
        return [xschem get graph_near_wave $gi $px $py $tol]
      }
      set W [winfo width $vdrw]; set H [winfo height $vdrw]
      set sdx [expr {int(0.5 * $W)}]
      # scan strip 0's band for a pixel row that sits ON the trace
      set sdy {}
      for {set y 2} {$y < $H / 2} {incr y 2} {
        if {[sd_near $vdrw 0 $sdx $y 3]} { set sdy $y; break }
      }
      check_true "SD1 a pixel ON the trace was found in strip 0" [expr {$sdy ne {}}]
      if {$sdy ne {}} {
        # the query is a real SCREEN-PIXEL distance: a row 12 px away answers 1
        # for a 16 px tolerance and 0 for a 4 px one. That is what makes the
        # exclusion zone independent of canvas zoom and of the data ranges —
        # nothing here is derived from the strip's geometry.
        set sdfar [expr {$sdy + 12}]
        check "SD1 12 px off the trace, tol 16 -> near" [sd_near $vdrw 0 $sdx $sdfar 16] 1
        check "SD1 12 px off the trace, tol 4  -> not near" [sd_near $vdrw 0 $sdx $sdfar 4] 0
        check "SD1 a row far above the trace is empty space" \
          [sd_near $vdrw 0 $sdx 2 10] 0

        # SD2: a near-trace LMB CLICK still reaches C and bolds (the press seam
        # forwards every press verbatim, whatever it decides about arming)
        wb_reset $tok
        wb_ev $vdrw <ButtonPress-1>   -x $sdx -y $sdy
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y $sdy -state 0x100
        update
        check "SD2 near-trace LMB click still bolds (C got press+release)" \
          [wb_bold $vdrw] 0
        wb_reset $tok

        # === TD: dragging a TRACE from one strip to another ==================
        # doc/claude/specs/waveform_viewer_modes.md §13. The seam SD3 used to
        # merely RESERVE ("a near-trace press is not a reorder") now carries a
        # gesture of its own: press ON the trace, drag onto another strip,
        # release -> the trace moves there. Both witnesses are needed and they
        # are independent: sd_order says WHICH TRACE is in each strip, sd_ids
        # says WHICH STRIP is at each index. A trace move changes the first and
        # never the second; a strip reorder does the opposite. On a two-strip
        # stack sd_order alone cannot tell them apart.
        set ::td_log {}
        rename wviewer::log_action wviewer::__td_real_log
        proc wviewer::log_action {line} { lappend ::td_log $line }

        set tdids [sd_ids $tok]
        check "TD fixture: the traced strip is on top, ids A B" \
          [list [sd_order $tok] $tdids] {{i(v1) -} {A B}}
        wviewer::set_target_strip 0 $tok    ;# so the press itself logs nothing
        set ::td_log {}
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        check "TD1 the press over a trace shows the GRAB HAND pointer" \
          [$vdrw cget -cursor] hand2
        check_true "TD1 the press armed a TRACE drag and NOT a strip reorder" \
          [expr {$::wviewer::tdrag_gi($tok) == 0 && $::wviewer::tdrag_ti($tok) == 0 &&
                 $::wviewer::drag_from($tok) == -1}]
        foreach fy {0.55 0.65 0.80} {
          wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int($fy * $H)}] -state 0x100
        }
        update
        xschem new_schematic switch $vdrw
        check "TD1 the destination strip is framed as the drop target" \
          [xschem getprop rect 2 1 reorder_handle] 4
        check "TD1 the source strip keeps the plain grip" \
          [xschem getprop rect 2 0 reorder_handle] 1
        check "TD1 the model is NOT mutated during the drag" \
          [sd_order $tok] {i(v1) -}
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        check "TD1 the trace moved to the strip it was dropped on" \
          [sd_order $tok] {- i(v1)}
        check "TD1 the STRIPS themselves did not reorder" [sd_ids $tok] $tdids
        check "TD1 the drop-target frame is gone" \
          [list [xschem getprop rect 2 0 reorder_handle] \
                [xschem getprop rect 2 1 reorder_handle]] {1 1}
        check "TD1 the pointer is restored on release" [$vdrw cget -cursor] {}
        check "TD1 exactly ONE log line, fully resolved" \
          [list [llength $::td_log] [lindex $::td_log end]] \
          [list 1 "wviewer::move_trace 0 0 1 $tok"]
        check "TD1 the DESTINATION strip became the target" \
          [wviewer::target_strip $tok] 1
        check "TD1 no drag state survived the drop" \
          [list $::wviewer::tdrag_gi($tok) $::wviewer::tdrag_active($tok)] {-1 0}
        check "TD1 viewer buffer still readonly + unmodified" \
          [list [xschem get readonly] [xschem get modified]] {1 0}

        # TD2: the same gesture upward, which also puts the fixture back. The
        # press pixel is found by scanning the LOWER band for the trace, so this
        # leg cannot pass by accident on a stale coordinate.
        set sdy2 {}
        for {set y [expr {int(0.55 * $H)}]} {$y < $H - 2} {incr y 2} {
          if {[sd_near $vdrw 1 $sdx $y 3]} { set sdy2 $y; break }
        }
        check_true "TD2 a pixel ON the moved trace was found in the lower strip" \
          [expr {$sdy2 ne {}}]
        if {$sdy2 ne {}} {
          set ::td_log {}
          wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy2
          foreach fy {0.40 0.25 0.15} {
            wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int($fy * $H)}] -state 0x100
          }
          wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.15 * $H)}] -state 0x100
          update
          check "TD2 the trace moved back up" [sd_order $tok] {i(v1) -}
          check "TD2 the strips still did not reorder" [sd_ids $tok] $tdids
          check "TD2 one log line for the upward move" \
            [list [llength $::td_log] [lindex $::td_log end]] \
            [list 1 "wviewer::move_trace 1 0 0 $tok"]
        }

        # TD3: the trace's own attributes ride along. Written into the model
        # first (a name + a non-default color), then dragged for real.
        set tdgs [dict get [wviewer::layout_for $tok] graphs]
        set tdtr [dict replace [lindex [dict get [lindex $tdgs 0] traces] 0] \
                    name plotme color 12]
        wviewer::set_graphs $tok \
          [lreplace $tdgs 0 0 [dict replace [lindex $tdgs 0] traces [list $tdtr]]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        set ::td_log {}
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        foreach fy {0.60 0.80} {
          wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int($fy * $H)}] -state 0x100
        }
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        set tdland [lindex [dict get [lindex [dict get \
          [wviewer::layout_for $tok] graphs] 1] traces] 0]
        check "TD3 the moved trace dict is byte-identical" $tdland $tdtr
        xschem new_schematic switch $vdrw
        check "TD3 the destination RECT carries the alias and the color" \
          [list [string map {\" {}} [xschem getprop rect 2 1 node]] \
                [string map {\" {}} [xschem getprop rect 2 1 color]]] \
          [list "plotme;i(v1)" 12]
        # put it back and drop the decoration again
        wviewer::set_graphs $tok [list \
          [dict replace [wviewer::empty_graph] sdid A traces [list \
            [dict replace $tdtr name {} color 4]]] \
          [dict replace [wviewer::empty_graph] sdid B]]
        wviewer::regenerate $tok
        wviewer::fit $tok

        # TD4: a press-release that does NOT travel is still the wave-bold
        # CLICK — the gesture must not steal it (issue 0152 stays intact).
        wviewer::set_target_strip 0 $tok    ;# the press must add no target line
        set ::td_log {}
        wb_reset $tok
        wb_ev $vdrw <ButtonPress-1>   -x $sdx -y $sdy
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y $sdy -state 0x100
        update
        check "TD4 a sub-threshold click still bolds the trace" [wb_bold $vdrw] 0
        check "TD4 ... and moved nothing" [sd_order $tok] {i(v1) -}
        check "TD4 ... and logged nothing" [llength $::td_log] 0
        check "TD4 ... and restored the pointer" [$vdrw cget -cursor] {}
        wb_reset $tok

        # TD5: ESC mid-drag abandons the move and restores everything.
        set ::td_log {}
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        check_true "TD5 a trace drag is active before ESC" \
          [expr {$::wviewer::tdrag_active($tok) == 1}]
        # focus first: a generated KeyPress goes to the FOCUS window, and under
        # WSLg the viewer can lose focus between legs — without this the ESC leg
        # silently never reaches key_filter (the MG14 lesson)
        focus -force $vdrw
        update
        event generate $vdrw <KeyPress> -keysym Escape
        update
        check "TD5 ESC cleared the drag state" \
          [list $::wviewer::tdrag_gi($tok) $::wviewer::tdrag_to($tok) \
                $::wviewer::tdrag_active($tok)] {-1 -1 0}
        check "TD5 ESC restored the pointer" [$vdrw cget -cursor] {}
        xschem new_schematic switch $vdrw
        check "TD5 ESC cleared the drop-target frame" \
          [xschem getprop rect 2 1 reorder_handle] 1
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        check "TD5 the cancelled drag moved nothing" [sd_order $tok] {i(v1) -}
        check "TD5 the cancelled drag logged nothing" [llength $::td_log] 0

        # TD6: the BOLD marker follows its trace across the strips. The engine
        # writes hilight_wave straight into the rect, so this is also the
        # capture_live_graph_state leg of the gesture.
        wb_reset $tok
        wb_ev $vdrw <ButtonPress-1>   -x $sdx -y $sdy
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y $sdy -state 0x100
        update
        check "TD6 the trace is bold before the drag" [wb_bold $vdrw] 0
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        foreach fy {0.60 0.80} {
          wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int($fy * $H)}] -state 0x100
        }
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        xschem new_schematic switch $vdrw
        check "TD6 the destination strip carries the bold marker" \
          [xschem getprop rect 2 1 hilight_wave] 0
        check "TD6 the emptied source has no bold marker left" \
          [xschem getprop rect 2 0 hilight_wave] {}

        # TD7: the whole user story — drag the trace, then press `u`. The key is
        # on the WaveViewer bindtag and the undo restores the MODEL snapshot the
        # drag pushed, so this is the gesture and the history wired together
        # (MG16 drives the history through the commands, this drives it through
        # the real gesture and the real key).
        # gather the traces from WHEREVER the last leg left them (the strip they
        # sit in depends on how many undos ran) and put the fixture back
        set tdall {}
        foreach G [dict get [wviewer::layout_for $tok] graphs] {
          foreach tr [wviewer::dget $G traces {}] { lappend tdall $tr }
        }
        wviewer::set_graphs $tok [list \
          [dict replace [wviewer::empty_graph] sdid A traces $tdall] \
          [dict replace [wviewer::empty_graph] sdid B]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        wviewer::clear_history $tok
        check "TD7 fixture back: the trace is on the top strip" \
          [sd_order $tok] {i(v1) -}
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        foreach fy {0.60 0.80} {
          wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int($fy * $H)}] -state 0x100
        }
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.80 * $H)}] -state 0x100
        update
        check "TD7 the drag moved the trace" [sd_order $tok] {- i(v1)}
        check "TD7 the drag pushed one undo point" \
          [lindex [wviewer::history_depth $tok] 0] 1
        focus -force $vdrw
        update
        event generate $vdrw <KeyPress> -keysym u
        update
        check "TD7 `u` undid the trace drag" [sd_order $tok] {i(v1) -}
        check "TD7 the strips were never reordered by any of it" [sd_ids $tok] {A B}
        event generate $vdrw <KeyPress> -keysym U -state 1
        update
        check "TD7 Shift-u redid it" [sd_order $tok] {- i(v1)}
        event generate $vdrw <KeyPress> -keysym u
        update
        check "TD7 ... and `u` again undoes it once more" [sd_order $tok] {i(v1) -}

        # TD8: the GRAB HAND must survive the SUB-THRESHOLD DEAD ZONE. Every
        # other leg looks at the cursor at the press or PAST the threshold; the
        # motions in between — the ones a real mouse delivers within ~25 ms of
        # the press — were unmeasured, and they are exactly the ones the seam
        # declines, so the binding forwards them and waves_selected() writes
        # `tcross` (src/callback.c:201) over the hand trace_drag_arm just set.
        wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdy
        update
        check "TD8 the press shows the grab hand" [$vdrw cget -cursor] hand2
        # asserted DIRECTLY, so this leg can never pass by having quietly
        # crossed the threshold and taken the shipped past-threshold write
        check "TD8 a 2-px motion is NOT consumed by the seam (it is C's)" \
          [wviewer::trace_drag_motion $vdrw $sdx [expr {$sdy + 2}] 0x100] 0
        foreach dy {1 2 3} {
          wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {$sdy + $dy}] -state 0x100
        }
        update
        check "TD8 the drag is STILL in the dead zone (not past threshold)" \
          [list [expr {$::wviewer::tdrag_gi($tok) >= 0}] \
                $::wviewer::tdrag_active($tok)] {1 0}
        check "TD8 the grab hand survived the fall-through to C" \
          [$vdrw cget -cursor] hand2

        # TD9: ...and it must survive LEAVING THE CANVAS mid-drag. `<Leave>` is
        # in keepseqs, so it still reaches C, and callback.c:8637 writes
        # `-cursor {}` unconditionally. During the implicit button grab the
        # pointer is still showing THIS widget's cursor, so before the re-assert
        # a drag that crossed the canvas edge lost its hand for good — the write
        # was a one-shot inside `if {!$active}` and nothing put it back.
        wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int(0.60 * $H)}] -state 0x100
        update
        check "TD9 past the threshold the hand is there" [$vdrw cget -cursor] hand2
        event generate $vdrw <Leave>
        update
        check "TD9 the C LeaveNotify arm really does wipe the pointer" \
          [$vdrw cget -cursor] {}
        event generate $vdrw <Enter>
        wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int(0.62 * $H)}] -state 0x100
        update
        check "TD9 the next motion takes the grab hand back" [$vdrw cget -cursor] hand2
        # NEGATIVE: the pointer must NOT be stolen from a C-owned gesture. ESC
        # disarms both Tcl gestures, so the following motion is purely C's — this
        # is the leg a blanket re-assert (or deleting the C write) breaks.
        focus -force $vdrw
        update
        event generate $vdrw <KeyPress> -keysym Escape
        update
        check "TD9 ESC disarmed both gestures (the helper owns nothing)" \
          [wviewer::drag_cursor_reassert $vdrw] {}
        wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {int(0.64 * $H)}] -state 0x100
        update
        # NOT `eq tcross`: which of tcross / {} C leaves behind depends on
        # graph_use_ctrl_key and on where the pixel landed. The property under
        # test is that the VIEWER did not re-assert a drag pointer it no longer owns.
        check_true "TD9 with nothing armed the drag pointer is not re-asserted" \
          [expr {[$vdrw cget -cursor] ne "hand2"}]
        wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {int(0.64 * $H)}] -state 0x100
        update
        check "TD9 the cancelled drag moved nothing" [sd_order $tok] {i(v1) -}

        # back to the SD fixture shape
        # gather the traces from WHEREVER the last leg left them (the strip they
        # sit in depends on how many undos ran) and put the fixture back
        set tdall {}
        foreach G [dict get [wviewer::layout_for $tok] graphs] {
          foreach tr [wviewer::dget $G traces {}] { lappend tdall $tr }
        }
        wviewer::set_graphs $tok [list \
          [dict replace [wviewer::empty_graph] sdid A traces $tdall] \
          [dict replace [wviewer::empty_graph] sdid B]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        rename wviewer::log_action {}
        rename wviewer::__td_real_log wviewer::log_action
        unset ::td_log
      } else {
        # loud, because everything from SD2 to TD6 lives inside this guard: a
        # broken hit-test makes SD1 fail and the rest VANISH rather than fail
        puts "SKIPPED: SD2/SD3/TD* (no pixel on the trace was found)"
      }

      # SD4: the SAME gesture from EMPTY waveform space DOES reorder. Strip 1 is
      # traceless, so every pixel in it is empty space. Without this leg SD3
      # would pass with reordering broken outright.
      set sdb [wviewer::strip_bands_px $vdrw]
      set sdm0 [expr {int(([lindex [lindex $sdb 0] 1] + [lindex [lindex $sdb 0] 3]) / 2.0)}]
      set sdm1 [expr {int(([lindex [lindex $sdb 1] 1] + [lindex [lindex $sdb 1] 3]) / 2.0)}]
      check "SD4 fixture: the data strip is on top" [sd_order $tok] {i(v1) -}
      wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdm1
      wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {$sdm0 - 3}] -state 0x100
      wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {$sdm0 - 3}] -state 0x100
      update
      check "SD4 an empty-space drag reordered the stack" [sd_order $tok] {- i(v1)}
      check "SD4 the STRIPS moved (not their traces) — the TD counterpart" \
        [sd_ids $tok] {B A}
      check_true "SD4 canvas == baseline (the drag never scrolled it)" \
        [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]
      # put it back
      wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdm0
      wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {$sdm1 + 3}] -state 0x100
      wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {$sdm1 + 3}] -state 0x100
      update
      check "SD4 and back again" [sd_order $tok] {i(v1) -}
      check "SD4 ... strips back in their original order too" [sd_ids $tok] {A B}

      # SD6: the reorder half of the cursor contract. Deliberately the SECOND
      # arm of drag_cursor_reassert, which no shipped path can reach through a
      # gesture (every past-threshold reorder motion is CONSUMED, so nothing
      # forwards to C and nothing clobbers) — so it is driven by a direct call
      # and labelled as such rather than dressed up as a gesture leg. It also
      # pins the deliberate asymmetry with the trace drag: an empty-space press
      # is not yet a reorder, so it owns NO cursor until the threshold.
      wb_ev $vdrw <ButtonPress-1> -x $sdx -y $sdm1
      update
      check "SD6 an empty-space press arms the reorder and owns NO cursor yet" \
        [list [expr {$::wviewer::drag_from($tok) >= 0}] \
              [wviewer::drag_cursor_reassert $vdrw]] {1 {}}
      wb_ev $vdrw <B1-Motion> -x $sdx -y [expr {$sdm0 - 3}] -state 0x100
      update
      check "SD6 past the threshold the reorder owns the vertical-move arrow" \
        [list $::wviewer::drag_active($tok) \
              [wviewer::drag_cursor_reassert $vdrw] [$vdrw cget -cursor]] \
        {1 sb_v_double_arrow sb_v_double_arrow}
      focus -force $vdrw
      update
      event generate $vdrw <KeyPress> -keysym Escape
      update
      wb_ev $vdrw <ButtonRelease-1> -x $sdx -y [expr {$sdm0 - 3}] -state 0x100
      update
      check "SD6 the cancelled reorder left the stack alone" [sd_order $tok] {i(v1) -}
      check "SD6 ... and the strips too" [sd_ids $tok] {A B}

      # SD5: a press that GRABBED A CURSOR keeps the whole drag, even though the
      # pointer is nowhere near a trace. A cursor can be parked anywhere in the
      # strip, so the trace-proximity gate alone would steal cursor dragging —
      # the press seam also asks the engine whether it just armed a cursor move
      # (`xschem get graph_flags`). Park cursor A exactly under the press pixel
      # so the grab is certain, then drag DIAGONALLY: enough vertical travel to
      # pass the reorder threshold, enough horizontal travel to move the cursor.
      set sdcx [expr {int(0.35 * $W)}]
      set sdcy [expr {int(0.10 * $H)}]        ;# high in strip 0, off the trace
      check "SD5 the press pixel is empty space as far as traces go" \
        [sd_near $vdrw 0 $sdcx $sdcy 10] 0
      xschem new_schematic switch $vdrw
      set sdc [xschem graph_coord 0 $sdcx $sdcy]
      if {[llength $sdc] == 2} {
        set ::wviewer::cva($tok) 1
        wviewer::cursor_toggle $tok 1
        xschem new_schematic switch $vdrw
        xschem set cursor1_x [lindex $sdc 0]
        xschem redraw
        set sdc0 [xschem get cursor1_x]
        set sdorder [sd_order $tok]
        wb_ev $vdrw <ButtonPress-1> -x $sdcx -y $sdcy
        foreach f {0.2 0.3 0.4} {
          wb_ev $vdrw <B1-Motion> -x [expr {int(($sdcx + $f * $W))}] \
            -y [expr {int($sdcy + $f * $H)}] -state 0x100
        }
        wb_ev $vdrw <ButtonRelease-1> -x [expr {int($sdcx + 0.4 * $W)}] \
          -y [expr {int($sdcy + 0.4 * $H)}] -state 0x100
        update
        xschem new_schematic switch $vdrw
        check_true "SD5 the cursor drag moved cursor A" \
          [expr {abs([xschem get cursor1_x] - $sdc0) > 1e-15}]
        check "SD5 a cursor drag never reorders the stack" [sd_order $tok] $sdorder
        set ::wviewer::cva($tok) 0
        wviewer::cursor_toggle $tok 1
      } else {
        puts "SKIPPED: SD5 (graph_coord unavailable)"
      }

      # === CA (issue 1617): CTRL-A OVER A GRAPH SELECTS EVERY DRAWN TRACE =====
      # wish_list.txt new-list item 13: "WV: CTRL-A to select all traces. Select
      # and delete traces." The select-and-delete half already ships (issues
      # 0175/0176); the chord did not.
      #
      # ⚠ THIS CHORD WAS OCCUPIED, WHICH IS WHY THE CURSOR ROWS BELOW ARE NOT
      # DECORATION. Before this issue, Ctrl-A over a graph reached waves_callback
      # and toggled x-cursor A (measured: graph_flags 2 -> 0 -> 2 across presses
      # while the selection tokens never moved). So the band has to assert BOTH
      # halves of the swap -- the selection now happens, and cursor A now does
      # not -- and the second half is where the trap lives: wviewer::key_filter's
      # tail calls wviewer::key_cursor_tail for keysym 97 with NO modifier test,
      # so with only the C side changed the Cursors > Cursor A CHECKBUTTON flips
      # on every Ctrl-A while the engine's cursor stays off. That desync is
      # invisible to any row that looks only at the selection.
      #
      # ⚠ SCOPE IS WINDOW-WIDE, NOT THE POINTED STRIP (DECISIONS D8). Two strips
      # with traces, the pointer in strip 0, and strip 1 must come out selected
      # too -- otherwise "select all" and "delete the selection" (which is
      # window-wide via wviewer::selection_pairs) would disagree about what "all"
      # covers, and the disagreement would be discovered by destroying something.
      #
      # ⚠ THE PIXEL IS PART OF THE GESTURE. waves_selected() answers from
      # xctx->mousex/mousey, which callback() recomputes from the EVENT's %x/%y on
      # a KeyPress too -- so the chord is sent with explicit -x/-y inside strip 0's
      # band, and a <Motion> to the same pixel first so the Tcl-side over_graph
      # gate (which reads the mousex_snap MIRROR, not the event) agrees.
      #
      # ⚠ EVERY ROW HERE MUST FAIL, NOT THROW (the brief's rule, and the OB-band
      # lesson from issue 1616): on the unfixed tree the selection readers answer
      # {} and the strip_bands_px / graph dicts are all well formed, but anything
      # that indexes a possibly-empty answer is wrapped.
      proc ca_sel {vdrw gi} {
        if {[catch {wviewer::selected_waves $vdrw $gi} v]} { return "threw ($v)" }
        return $v
      }
      proc ca_tok {vdrw gi t} {
        xschem new_schematic switch $vdrw
        if {[catch {xschem getprop rect 2 $gi $t} v]} { return "threw ($v)" }
        return $v
      }
      # the Cursors > Cursor A checkbutton state and the ENGINE's cursor-A bit,
      # as ONE value: the pair is the desync, and either alone is blind to it
      # (build_menubar binds that checkbutton to ::wviewer::cva($token), and
      # graph_flags bit 2 is what draws the cursor).
      proc ca_cursorA {vdrw tok} {
        xschem new_schematic switch $vdrw
        set bit 0
        catch {set bit [expr {([xschem get graph_flags] & 2) ? 1 : 0}]}
        set mir 0
        catch {set mir [expr {$::wviewer::cva($tok) ? 1 : 0}]}
        return [list $mir $bit]
      }
      # RECOMPUTED before every gesture, never cached: the readout bar the cursor
      # rows below make visible can repack the canvas, and a stale mid-of-band row
      # silently becomes a pixel in a different strip -- the same "rescan, do not
      # reuse" rule wb_far_row carries a few hundred lines up. {} when the strip
      # has no band -- it falls back to a fraction of the canvas rather than {} so
      # a missing band cannot make a gesture THROW (the brief's fail-not-throw
      # rule); CA-fixture asserts the band was really there, so the fallback can
      # never pass for the real thing silently.
      proc ca_bands {vdrw} {
        set bb {}
        catch {set bb [wviewer::strip_bands_px $vdrw]}
        return $bb
      }
      proc ca_row {vdrw gi} {
        set bb [ca_bands $vdrw]
        if {$gi < [llength $bb]} {
          set b [lindex $bb $gi]
          if {[llength $b] == 4} {
            return [expr {int(([lindex $b 1] + [lindex $b 3]) / 2.0)}]
          }
        }
        return [expr {int(0.25 * [winfo height $vdrw])}]
      }
      # ONE gesture, so no row can differ from another in how it sends the chord:
      # a <Motion> to the pixel (so the Tcl-side over_graph gate, which reads the
      # mousex_snap MIRROR, agrees) and then the chord AT that pixel (so C's
      # waves_selected, which reads the mirror callback() recomputes from the
      # event's own %x/%y, agrees too). Returns 1 on proven delivery.
      proc ca_send {vdrw ev px py} {
        wb_ev $vdrw <Motion> -x $px -y $py
        update
        set k0 $::kf_calls
        set d [send_key $vdrw $ev {$::kf_calls > $k0} [list -x $px -y $py]]
        update
        return $d
      }
      # a FRESH two-strip fixture, built from a real trace dict rather than from
      # add_trace: strip 0 carries TWO traces (so `sel_waves` is exercised -- the
      # token is written only for a selection of two or more, so a one-trace strip
      # cannot tell a both-tokens writer from a hilight_wave-only one) and strip 1
      # carries ONE (so the window-wide row cannot be satisfied by the pointed
      # strip alone, and so the 1-element `sel_waves`-is-REMOVED invariant is
      # asserted at the same time).
      set ca_save [dict get [wviewer::layout_for $tok] graphs]
      set ca_tr {}
      foreach G $ca_save {
        foreach tr [wviewer::dget $G traces {}] {
          if {[wviewer::dget $tr vec {}] ne {}} { lappend ca_tr $tr }
        }
      }
      check_true "CA fixture: a real trace dict was recovered from the model" \
        [expr {[llength $ca_tr] >= 1}]
      if {[llength $ca_tr] >= 1} {
        set ca_t0 [lindex $ca_tr 0]
        wviewer::set_graphs $tok [list \
          [dict replace [wviewer::empty_graph] traces [list $ca_t0 $ca_t0]] \
          [dict replace [wviewer::empty_graph] traces [list $ca_t0]]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        xschem new_schematic switch $vdrw
        set ca_gs [dict get [wviewer::layout_for $tok] graphs]
        check "CA fixture: node spaces are 2 and 1" \
          [list [wviewer::node_count [lindex $ca_gs 0]] \
                [wviewer::node_count [lindex $ca_gs 1]]] {2 1}
        # the pointer pixel: the middle of strip 0's band
        set cax [expr {int(0.5 * [winfo width $vdrw])}]
        check "CA fixture: both strips report a pixel band" \
          [llength [ca_bands $vdrw]] 2

        # nothing selected, cursor A off, no modal so far -- the baseline every
        # row below is measured against
        set ::wviewer::cva($tok) 0
        wviewer::cursor_toggle $tok 1
        wviewer::with_edit $tok {
          xschem setprop rect 2 0 hilight_wave -1
          xschem setprop rect 2 1 hilight_wave -1
        }
        check "CA-setup nothing is selected on either strip" \
          [list [ca_sel $vdrw 0] [ca_sel $vdrw 1]] {{} {}}
        check "CA-setup cursor A is off, mirror and engine agree" \
          [ca_cursorA $vdrw $tok] {0 0}
        set ca_mb0 $::mb_hits

        # THE GESTURE
        set ca_del [ca_send $vdrw <Control-Key-a> $cax [ca_row $vdrw 0]]
        check "CA0 the Ctrl-A reached the viewer's key filter" $ca_del 1
        check_true "CA0 ...and arrived AS Ctrl+keysym-97 (Control bit set)" \
          [expr {[llength $::kf_last] == 3 && [lindex $::kf_last 1] == 97 &&
                 ([lindex $::kf_last 2] & 4) != 0}]
        # recon could not settle this one and asked for it: nothing may claim
        # <Control-Key-a> ahead of the generic <KeyPress> the filter is bound to.
        # Tk canonicalises <Control-a>/<Control-KeyPress-a> to <Control-Key-a>, so
        # one spelling covers them, and both the canvas's tags and the toplevel's
        # are swept (a toplevel binding would also fire for the browser's search
        # entry -- the hazard rdw::popup_menu names).
        set ca_steal {}
        foreach ca_tag [concat [bindtags $vdrw] [bindtags $vtop]] {
          foreach ca_seq [bind $ca_tag] {
            if {$ca_seq eq {<Control-Key-a>}} { lappend ca_steal [list $ca_tag $ca_seq] }
          }
        }
        check "CA0 nothing binds <Control-Key-a> ahead of the key filter" $ca_steal {}

        # --- the selection, read three ways -------------------------------
        check "CA1 every trace of the POINTED strip is selected" [ca_sel $vdrw 0] {0 1}
        check "CA1 ...and of the OTHER strip too (window-wide, D8)" [ca_sel $vdrw 1] {0}
        # the raw tokens, because `selected_waves` composes them and would report
        # {0} for a strip whose sel_waves was never written -- the single most
        # plausible wrong implementation
        check "CA2 strip 0 wrote BOTH tokens (sel_waves is the set)" \
          [list [ca_tok $vdrw 0 hilight_wave] [ca_tok $vdrw 0 sel_waves]] {0 {0 1}}
        check "CA2 strip 1's 1-element selection leaves sel_waves ABSENT" \
          [list [ca_tok $vdrw 1 hilight_wave] [ca_tok $vdrw 1 sel_waves]] {0 {}}
        # the shape the shipped Delete path consumes, in MODEL space, through the
        # one fold both Delete and the multi-trace drag use. This is the row that
        # says "the existing delete path can act on it" without touching it.
        check "CA3 selection_pairs gives the Delete path every trace, as {gi ti}" \
          [wviewer::selection_pairs $vdrw] {{0 0} {0 1} {1 0}}

        # --- the chord's OLD meaning is gone, on both sides of the mirror ---
        check "CA4 Ctrl-A no longer toggles cursor A (engine AND menu mirror)" \
          [ca_cursorA $vdrw $tok] {0 0}
        check "CA4 ...and it popped no read-only modal (selection is view state)" \
          $::mb_hits $ca_mb0

        # --- BARE `a` still toggles cursor A (the shipping profile keeps it) ---
        ca_send $vdrw <Key-a> $cax [ca_row $vdrw 0]
        check "CA5 bare `a` still toggles cursor A, mirror and engine together" \
          [ca_cursorA $vdrw $tok] {1 1}
        ca_send $vdrw <Key-a> $cax [ca_row $vdrw 0]
        check "CA5 ...and off again" [ca_cursorA $vdrw $tok] {0 0}

        # --- IDEMPOTENT: a second Ctrl-A selects the same set, not a toggle ---
        ca_send $vdrw <Control-Key-a> $cax [ca_row $vdrw 0]
        # ⚠ the second element is `0`, NOT `{0}`: `list` braces an element only
        # when it has to, so [list {0 1} {0}] is the STRING "{0 1} 0". Written
        # `{{0 1} {0}}` this row failed on the FIXED tree reporting
        # `-> {{0 1} 0} (exp {{0 1} {0}})`, i.e. a green product and a red row.
        # Do not "restore the symmetry" with CA1's braces -- CA1 asserts the two
        # strips separately and has no such composition.
        check "CA6 a second Ctrl-A leaves the same set selected (not a toggle)" \
          [list [ca_sel $vdrw 0] [ca_sel $vdrw 1]] {{0 1} 0}

        # --- THE OTHER PROFILE, which is where the whole price lands ----------
        # `graph_use_ctrl_key 1` makes Ctrl the graph ACCESS modifier, and in it
        # Ctrl+A was the ONLY cursor-A chord (bare `a` there makes
        # waves_selected() skip and falls through to the schematic `case 'a'`, the
        # make-symbol dialog). So this is the profile where taking the chord
        # actually costs a function, and the recon receipt called it "the third
        # direction the PLAN is missing" for exactly that reason: without a row,
        # a future change to `access_cond` or to the branch order would move the
        # behaviour of that profile invisibly.
        #
        # ⚠ ONLY the Ctrl half is driven. Bare `a` in this profile reaches the
        # schematic make-symbol dialog, which tk_messageBox's stub does not cover
        # -- driving it would pop a real dialog on the dev display and stall the
        # suite rather than measure anything.
        set ca_guck 0
        if {[info exists ::graph_use_ctrl_key]} { set ca_guck $::graph_use_ctrl_key }
        check "CA9 the shipping profile really is graph_use_ctrl_key 0" $ca_guck 0
        set ::graph_use_ctrl_key 1
        wviewer::with_edit $tok {
          xschem setprop rect 2 0 hilight_wave -1
          xschem setprop rect 2 0 sel_waves {}
          xschem setprop rect 2 1 hilight_wave -1
        }
        check "CA9 fixture: the selection was cleared before the profile switch" \
          [list [ca_sel $vdrw 0] [ca_sel $vdrw 1]] {{} {}}
        ca_send $vdrw <Control-Key-a> $cax [ca_row $vdrw 0]
        check "CA9 Ctrl-A selects all in the graph_use_ctrl_key 1 profile too" \
          [list [ca_sel $vdrw 0] [ca_sel $vdrw 1]] {{0 1} 0}
        check "CA9 ...and cursor A stays put there as well (D9's declared price)" \
          [ca_cursorA $vdrw $tok] {0 0}
        set ::graph_use_ctrl_key $ca_guck
        check "CA9 the profile was put back" $::graph_use_ctrl_key 0

        # --- THE EMPTY CASE: no traces anywhere -> nothing selected, no modal --
        wviewer::set_graphs $tok [list [wviewer::empty_graph] [wviewer::empty_graph]]
        wviewer::regenerate $tok
        xschem new_schematic switch $vdrw
        set ca_gs [dict get [wviewer::layout_for $tok] graphs]
        check "CA7 fixture: both strips are now traceless" \
          [list [wviewer::node_count [lindex $ca_gs 0]] \
                [wviewer::node_count [lindex $ca_gs 1]]] {0 0}
        set ca_mb1 $::mb_hits
        # ⚠ RESET, do not inherit. MEASURED while writing this band: with CA9
        # inserted above it, CA7's cursor row started passing on the UNFIXED tree
        # -- CA9's Ctrl-A had toggled cursor A on there and CA7's toggled it off
        # again, so the row was reading a PARITY rather than an invariant. A row
        # whose verdict depends on how many gestures ran before it is not a fence.
        set ::wviewer::cva($tok) 0
        wviewer::cursor_toggle $tok 1
        check "CA7 fixture: cursor A is off before the gesture" \
          [ca_cursorA $vdrw $tok] {0 0}
        ca_send $vdrw <Control-Key-a> $cax [ca_row $vdrw 0]
        check "CA7 Ctrl-A on empty strips selects nothing" \
          [list [ca_sel $vdrw 0] [ca_sel $vdrw 1]] {{} {}}
        check "CA7 ...and pops no modal" $::mb_hits $ca_mb1
        check "CA7 ...and still leaves cursor A alone" [ca_cursorA $vdrw $tok] {0 0}

        # --- THE CAP IS A DECLARED LIMIT, AND IT IS MEASURED ------------------
        # GRAPH_MAX_SEL_WAVES is 64 and graph_sel_waves_set() CLAMPS rather than
        # refusing, so a strip drawing more than 64 traces gets its first 64
        # selected -- and a Delete would then delete 64 of them. That is stated
        # here as a row rather than in a comment, because a comment quoting 64
        # is a number nothing re-checks. 65 copies of one real trace dict is the
        # cheap way to reach it (one set_graphs + one regenerate, no ngspice).
        set ca_many {}
        for {set ca_k 0} {$ca_k < 65} {incr ca_k} { lappend ca_many $ca_t0 }
        wviewer::set_graphs $tok \
          [list [dict replace [wviewer::empty_graph] traces $ca_many]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        xschem new_schematic switch $vdrw
        check "CA8 fixture: the strip really draws 65 traces" \
          [wviewer::node_count [lindex [dict get [wviewer::layout_for $tok] graphs] 0]] 65
        ca_send $vdrw <Control-Key-a> $cax [ca_row $vdrw 0]
        set ca_big [ca_sel $vdrw 0]
        check "CA8 the cap holds at 64, the first 64 node indices" \
          [list [llength $ca_big] [lindex $ca_big 0] [lindex $ca_big end]] {64 0 63}

        # === KM: Ctrl-Shift-M in the viewer, and the keys that are not the viewer's ===
        # Two claims (doc/claude/specs/waveform_viewer_subwindows.md, rule SW22 and
        # the keys section; doc/claude/specs/waveform_viewer.md, what the key filter
        # forwards):
        #   1. Ctrl-Shift-M in a viewer flips the plot mode of the TARGET subwindow,
        #      as Options > Plot Mode does.
        #   2. No key pressed in a viewer reaches an editor verb of the engine. The
        #      filter forwards a graph key only as a chord the engine itself hands to
        #      the graph, at a pixel the engine's own graph test accepts.
        #
        # HOW A KEY IS SENT (km_key): a Motion to the pixel, then a KeyPress with
        # -keysym and -state AT that pixel. The state is a number because Tk's Alt
        # pattern modifier does not set Mod1, and Caps Lock and Num Lock have no
        # pattern modifier.
        #
        # THE WITNESSES. ::km_fwd lists every KeyPress the engine is handed, as
        # keysym and state, while the wrapper passes each call on unchanged;
        # ::km_via lists the same calls with the canvas each came through, and
        # ::km_rel the KeyRelease calls the same way (2026-11-22).
        # ::km_log lists the viewer's action-log lines. km_snap is the state a
        # refused key must leave alone.
        #
        # THE PRE-FLIGHT (km_decides). Several of these chords are a reload, a Save
        # form or a new window once they reach the engine. So a row first asks the
        # filter what it WOULD forward, with the forward swallowed, and sends the
        # real key only when the answer is nothing. On a product that forwards the
        # chord the row fails at the pre-flight and the engine never sees the key.
        set ::km_fwd {}
        set ::km_via {}
        set ::km_rel {}
        set ::km_would {}
        set ::km_swallow 0
        set ::km_esc 0
        rename ::xschem ::km_real_xschem
        proc ::xschem {args} {
          if {[lindex $args 0] eq {callback} && [lindex $args 2] == 2} {
            set kmrec [list [lindex $args 5] [lindex $args 8]]
            if {$::km_swallow} { lappend ::km_would $kmrec ; return {} }
            lappend ::km_fwd $kmrec
            lappend ::km_via [list [lindex $args 1] [lindex $args 5] [lindex $args 8]]
          }
          if {[lindex $args 0] eq {callback} && [lindex $args 2] == 3} {
            lappend ::km_rel [list [lindex $args 1] [lindex $args 5] [lindex $args 8]]
          }
          if {$args eq {escape}} { incr ::km_esc }
          return [uplevel 1 [list ::km_real_xschem {*}$args]]
        }
        set ::km_log {}
        rename ::wviewer::log_action ::wviewer::__km_real_log
        proc ::wviewer::log_action {line} { lappend ::km_log $line ; ::wviewer::__km_real_log $line }
        set ::km_sacd 0
        set km_had_sacd [expr {[info commands ::save_as_cellview_dialog] ne {}}]
        if {$km_had_sacd} { rename ::save_as_cellview_dialog ::km_real_sacd }
        proc ::save_as_cellview_dialog {args} { incr ::km_sacd ; return {} }
        proc km_key {vdrw ks st px py} {
          wb_ev $vdrw <Motion> -x $px -y $py
          update
          set k0 $::kf_calls
          set d [send_key $vdrw <KeyPress> {$::kf_calls > $k0} \
                   [list -keysym $ks -state $st -x $px -y $py]]
          update
          return $d
        }
        proc km_decides {vdrw N s px py} {
          wb_ev $vdrw <Motion> -x $px -y $py
          update
          set ::km_would {}
          set ::km_swallow 1
          set rc [catch {wviewer::key_filter $vdrw 2 $px $py $N [format %c $N] $s} e]
          set ::km_swallow 0
          if {$rc} { return "threw ($e)" }
          return $::km_would
        }
        proc km_snap {vdrw tok} {
          if {[catch {
            xschem new_schematic switch $vdrw
            set v [list mode [wviewer::plot_mode $tok] gf [xschem get graph_flags] \
              ui [xschem get ui_state] ro [xschem get readonly] hs $::hide_symbols \
              win [llength [xschem windows]] rects [xschem get rects 2] \
              mk [llength [xschem graph_marker list]] \
              cur [list [xschem get cursor1_x] [xschem get cursor2_x]] \
              view [list [xschem get zoom] [xschem get xorigin] [xschem get yorigin]] \
              ow $::orthogonal_wiring]
          } e]} { return "threw ($e)" }
          return $v
        }
        proc km_gf {vdrw} {
          xschem new_schematic switch $vdrw
          set f -1
          catch {set f [xschem get graph_flags]}
          return $f
        }
        proc km_mk {vdrw} {
          xschem new_schematic switch $vdrw
          set n -1
          catch {set n [llength [xschem graph_marker list]]}
          return $n
        }
        proc km_cur {vdrw} {
          xschem new_schematic switch $vdrw
          set c {? ?}
          catch {set c [list [xschem get cursor1_x] [xschem get cursor2_x]]}
          return $c
        }
        proc km_status {vtop} {
          set t {}
          catch {set t [lindex [$vtop.wvstatus.l cget -text] 1]}
          return $t
        }
        # what the readout bar reads as the x of cursor A and of cursor B: the
        # text after `x=` of its two labels, {} for a label that shows none
        proc km_readout {vtop} {
          set r {}
          foreach l {a b} {
            set t {}
            catch {set t [$vtop.wvreadout.$l cget -text]}
            set x {}
            regexp {x=(\S+)} $t -> x
            lappend r $x
          }
          return $r
        }
        # centre pixel of strip gi, from the canvas' own bands; a fraction of the
        # canvas when the strip has no band, so a gesture cannot throw
        proc km_mid {vdrw gi} {
          set b [lindex [ca_bands $vdrw] $gi]
          if {[llength $b] == 4} {
            return [list [expr {int(([lindex $b 0] + [lindex $b 2]) / 2.0)}] \
                         [expr {int(([lindex $b 1] + [lindex $b 3]) / 2.0)}]]
          }
          return [list [expr {int(0.5 * [winfo width $vdrw])}] [expr {int(0.25 * [winfo height $vdrw])}]]
        }
        # every graph key as the filter gets it with no Control: an upper-case
        # keysym carries Shift
        proc km_plain {N} { return [expr {$N >= 65 && $N <= 90 ? 1 : 0}] }

        # the fixture: one subwindow, two strips, one trace each, single mode,
        # cursors off, no marker
        wviewer::set_graphs $tok [list \
          [dict replace [wviewer::empty_graph] traces [list $ca_t0]] \
          [dict replace [wviewer::empty_graph] traces [list $ca_t0]]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        wviewer::set_plot_mode single $tok
        set ::wviewer::cva($tok) 0
        wviewer::cursor_toggle $tok 1
        set ::wviewer::cvb($tok) 0
        wviewer::cursor_toggle $tok 2
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        xschem new_schematic switch $vdrw
        lassign [km_mid $vdrw 0] kmx kmy
        # two pixels of strip 0 that the engine agrees are ON the trace, for the
        # marker keys
        set km_on {}
        set km_b0 [lindex [ca_bands $vdrw] 0]
        if {[llength $km_b0] == 4} {
          foreach km_px [list $kmx [expr {$kmx + 90}]] {
            for {set y [expr {int([lindex $km_b0 1]) + 14}]} {$y < int([lindex $km_b0 3]) - 14} {incr y} {
              if {[wb_at $vdrw 0 $km_px $y 3] >= 0} { lappend km_on [list $km_px $y] ; break }
            }
          }
        }
        check "KM0 fixture: two strips with a band each, single mode, cursors and tooltip off, no marker, two on-trace pixels" \
          [list [llength [ca_bands $vdrw]] [wviewer::plot_mode $tok] [km_status $vtop] \
                [expr {[km_gf $vdrw] & 70}] [km_mk $vdrw] [llength $km_on]] \
          {2 single single 0 0 2}
        if {[llength $km_on] < 2} { set km_on [list [list $kmx $kmy] [list [expr {$kmx + 90}] $kmy]] }
        set km_nkeys [llength $::wviewer::graphkeys]
        check_true "KM0 fixture: the product's graph-key list is not empty" [expr {$km_nkeys > 0}]

        # --- KM1: the chord itself --------------------------------------------
        set km_mb0 $::mb_hits
        set ::km_fwd {} ; set ::km_log {}
        set km_d [km_key $vdrw M 5 $kmx $kmy]
        check "KM1 a real Ctrl-Shift-M reaches the viewer's key filter as keysym M with Control and Shift" \
          [list $km_d $::kf_last] {1 {2 77 5}}
        check "KM1 ...it pops no message box" [expr {$::mb_hits - $km_mb0}] 0
        check "KM1 ...the filter hands the engine nothing" $::km_fwd {}
        check "KM1 ...the plot mode flips" [wviewer::plot_mode $tok] multi
        check "KM1 ...the status bar follows" [km_status $vtop] multi
        check "KM1 ...one action-log line, set_plot_mode with the resolved mode and the token" \
          $::km_log [list [list wviewer::set_plot_mode multi $tok]]
        check "KM1 ...the measurement-tooltip flag does not move" [expr {[km_gf $vdrw] & 64}] 0
        set ::km_fwd {} ; set ::km_log {}
        km_key $vdrw M 5 $kmx $kmy
        check "KM1 a second press flips back: mode, status bar, one line, no box, nothing forwarded" \
          [list [wviewer::plot_mode $tok] [km_status $vtop] $::km_log \
                [expr {$::mb_hits - $km_mb0}] $::km_fwd] \
          [list single single [list [list wviewer::set_plot_mode single $tok]] 0 {}]

        # the chord is as quiet in the command window as the menu entry (the
        # status bar shows the mode). Both doors a line can go through are
        # recorded while the real chord is pressed and while Options > Plot
        # Mode is invoked after it: ciw_echo and the viewer's own
        # wviewer::echo. With an action log open the engine mirrors each
        # action-log line into the command window through ciw_echo; that
        # mirror is the action's own line (the one ::km_log holds) and is not
        # counted. The entry is found by its command, not by its label (the
        # label changes with the mode).
        proc km_own_lines {} {
          set own {}
          foreach km_l $::km_echo { if {[lsearch -exact $::km_log $km_l] < 0} { lappend own $km_l } }
          return $own
        }
        set ::km_echo {}
        set km_echo_had {}
        foreach km_p {::ciw_echo ::wviewer::echo} {
          if {[info commands $km_p] eq {}} continue
          lappend km_echo_had $km_p
          rename $km_p ${km_p}__km_real
          proc $km_p {args} [string map [list @P@ $km_p] {
            lappend ::km_echo [lindex $args 0]
            return [uplevel 1 [list @P@__km_real {*}$args]]
          }]
        }
        wviewer::set_plot_mode single $tok
        set ::km_echo {} ; set ::km_log {}
        km_key $vdrw M 5 $kmx $kmy
        set km_q1 [list [wviewer::plot_mode $tok] [llength $::km_log] [km_own_lines]]
        set km_pm $vtop.wvmenubar.options.plotmode
        set km_pmi {}
        catch {
          for {set i 0} {$i <= [$km_pm index end]} {incr i} {
            if {[$km_pm type $i] eq {command} &&
                [$km_pm entrycget $i -command] eq [list wviewer::set_plot_mode invert $tok]} { set km_pmi $i ; break }
          }
        }
        set ::km_echo {} ; set ::km_log {}
        set km_q2 no-such-entry
        if {$km_pmi ne {}} {
          $km_pm invoke $km_pmi
          set km_q2 [list [wviewer::plot_mode $tok] [llength $::km_log] [km_own_lines]]
        }
        foreach km_p $km_echo_had {
          rename $km_p {}
          rename ${km_p}__km_real $km_p
        }
        rename km_own_lines {}
        check "KM1 the chord is as quiet in the command window as the menu entry: with ciw_echo and wviewer::echo recorded, a real Ctrl-Shift-M flips the mode, writes its one action-log line and echoes no line of its own, and Options > Plot Mode invoked after it flips the mode back the same way (the doors recorded; for the chord and for the entry: the mode it left, its action-log lines, the lines echoed that are not the mirror of one)" \
          [list $km_echo_had $km_q1 $km_q2] [list {::ciw_echo ::wviewer::echo} {multi 1 {}} {single 1 {}}]
        wviewer::set_plot_mode single $tok

        # the wrapper acts on the canvas the key came from, not on whichever
        # context is current: called for the main window's canvas while this
        # viewer's context is the current one, it does nothing
        xschem new_schematic switch $vdrw
        set ::km_log {}
        set km_w [list [catch {wviewer::plot_mode_toggle_at .drw} km_we] $km_we]
        check "KM1 the wrapper, called for a canvas that is no viewer's while this viewer's context is current, does nothing: answer {}, mode and log unmoved" \
          [list $km_w [wviewer::plot_mode $tok] $::km_log] {{0 {}} single {}}

        # ...and it does not need the viewer's context to be the current one
        # (the context follows the pointer, the keyboard focus does not): called
        # for this viewer's canvas while the main window's context is current,
        # the wrapper flips this viewer's mode
        xschem new_schematic switch .drw
        set ::km_log {}
        set km_w2 [list [catch {wviewer::plot_mode_toggle_at $vdrw} km_we] $km_we]
        check "KM1 the wrapper, called for this viewer's canvas while the main window's context is the current one, flips this viewer's mode (answer, mode, one line)" \
          [list $km_w2 [wviewer::plot_mode $tok] $::km_log] \
          [list {0 multi} multi [list [list wviewer::set_plot_mode multi $tok]]]
        xschem new_schematic switch $vdrw
        wviewer::set_plot_mode single $tok

        # the chord goes by the focus, not by where the pointer or the key's
        # pixel is: pressed two pixels inside the strip's top edge, where no
        # graph key is forwarded, and with both of the filter's graph gates
        # answering no, it flips the mode all the same
        set km_gates {}
        foreach km_p {over_graph key_at_graph} {
          rename ::wviewer::$km_p ::wviewer::__km_gate_$km_p
          proc ::wviewer::$km_p {args} { return 0 }
          lappend km_gates $km_p
        }
        wviewer::set_plot_mode single $tok
        set ::km_fwd {} ; set ::km_log {}
        km_key $vdrw M 5 $kmx [expr {int([lindex [lindex [ca_bands $vdrw] 0] 1]) + 2}]
        set km_1b [list [wviewer::plot_mode $tok] $::km_log $::km_fwd]
        foreach km_p $km_gates {
          rename ::wviewer::$km_p {}
          rename ::wviewer::__km_gate_$km_p ::wviewer::$km_p
        }
        check "KM1 the chord goes by the focus, not by the pointer: pressed two pixels inside the strip's edge, with both graph gates of the filter answering no, it flips the mode all the same (one line, nothing forwarded)" \
          $km_1b [list multi [list [list wviewer::set_plot_mode multi $tok]] {}]
        wviewer::set_plot_mode single $tok

        # the default is installed whatever the profile. Every suite opens its
        # first viewer in the stock profile and the defaults go in once per
        # session, so the binding is taken off the tag here, the Cadence profile
        # switched on, and the installer run again.
        set km_seq <Control-Shift-Key-M>
        set km_old [bind WaveViewer $km_seq]
        set km_cad0 $::cadence_compat
        set km_at0 $::autotrim_wires
        bind WaveViewer $km_seq {}
        set km_gone [bind WaveViewer $km_seq]
        set ::cadence_compat 1
        set ::wviewer::tagbinds 0
        set km_inst [list [catch {wviewer::install_default_binds} km_ie] $km_ie]
        set km_new [bind WaveViewer $km_seq]
        set ::km_fwd {} ; set km_mb3 $::mb_hits
        km_key $vdrw M 5 $kmx $kmy
        set km_x2 [list [wviewer::plot_mode $tok] $::km_fwd [expr {$::mb_hits - $km_mb3}]]
        set ::cadence_compat $km_cad0
        set ::autotrim_wires $km_at0
        if {[bind WaveViewer $km_seq] eq {}} { bind WaveViewer $km_seq $km_old }
        set ::wviewer::tagbinds 1
        check "KM1 the default goes in under the Cadence profile too: with the tag's binding taken off and cadence_compat on, install_default_binds puts the same script back and a real Ctrl-Shift-M flips the mode (nothing forwarded, no box); the profile is back" \
          [list $km_gone $km_inst [expr {$km_old ne {} && $km_new eq $km_old}] $km_x2 \
                [list $::cadence_compat $::autotrim_wires]] \
          [list {} {0 1} 1 {multi {} 0} [list $km_cad0 $km_at0]]
        wviewer::set_plot_mode single $tok

        # a binding the user made first WINS: install_default_binds installs a
        # default only for a sequence nothing has bound. The population is every
        # sequence the WaveViewer tag holds at this point (the defaults and the
        # Caps Lock dispatch went in at the first viewer open): each is bound to
        # a bare break, the installer is run again as at a first open, and none
        # may come back overwritten. That the population is the installer's is
        # held by a second reading: every sequence a bind statement of the proc
        # names (its body as the interpreter holds it, comment lines out) has a
        # binding on the tag, the chord of this item among them.
        set km_ib {}
        catch {set km_ib [info body ::wviewer::install_default_binds]}
        regsub -all -line {^\s*#.*$} $km_ib {} km_ib
        set km_named {}
        foreach {km_all km_sq} [regexp -all -inline {bind WaveViewer (<[^>\s]+>) \{} $km_ib] {
          if {[lsearch -exact $km_named $km_sq] < 0} { lappend km_named $km_sq }
        }
        set km_tagseqs [bind WaveViewer]
        set km_unbound {}
        foreach km_sq $km_named { if {[bind WaveViewer $km_sq] eq {}} { lappend km_unbound $km_sq } }
        set km_tag0 {}
        foreach km_sq $km_tagseqs { lappend km_tag0 [bind WaveViewer $km_sq] }
        # The walk is taken in BOTH profiles, stock and then Cadence. The
        # Cadence profile is the one whose rc carries the remap recipe for this
        # chord (src/cadence_style_rc: the user's own binding goes on the tag
        # before the first viewer opens), so it is there that a default going
        # in over a binding would undo the remap.
        set km_cad0 $::cadence_compat
        set km_at0 $::autotrim_wires
        set km_walk {}
        foreach km_prof {0 1} {
          set ::cadence_compat $km_prof
          foreach km_sq $km_tagseqs { bind WaveViewer $km_sq {break} }
          set ::wviewer::tagbinds 0
          set km_inst [list [catch {wviewer::install_default_binds} km_ie] $km_ie]
          set ::wviewer::tagbinds 1
          set km_lost {}
          foreach km_sq $km_tagseqs { if {[bind WaveViewer $km_sq] ne {break}} { lappend km_lost $km_sq } }
          lappend km_walk [list $km_prof [expr {$::cadence_compat ? 1 : 0}] $km_inst $km_lost]
          foreach km_sq $km_tagseqs km_scr $km_tag0 { bind WaveViewer $km_sq $km_scr }
        }
        set ::cadence_compat $km_cad0
        set ::autotrim_wires $km_at0
        set km_tag1 {}
        foreach km_sq $km_tagseqs { lappend km_tag1 [bind WaveViewer $km_sq] }
        check "KM1 a binding of the user's own wins over every default, in the stock profile and in the Cadence one: with each sequence of the WaveViewer tag bound to a bare break, install_default_binds run again overwrites none (the tag holds sequences, the installer's bind statements name some and Ctrl-Shift-M among them, the named ones with no binding; per profile: cadence_compat as the leg set it and as it reads while the installer runs, the installer's answer, the sequences it overwrote); the tag and the profile are put back as they were" \
          [list [expr {[llength $km_tagseqs] > 0}] \
                [expr {[llength $km_named] > 0 && [lsearch -exact $km_named <Control-Shift-Key-M>] >= 0}] \
                $km_unbound $km_walk [expr {$km_tag1 eq $km_tag0}] \
                [list $::cadence_compat $::autotrim_wires]] \
          [list 1 1 {} {{0 0 {0 1} {}} {1 1 {0 1} {}}} 1 [list $km_cad0 $km_at0]]

        # --- KM2: what must stay as it is ---------------------------------------
        wviewer::set_plot_mode single $tok
        set ::km_fwd {}
        km_key $vdrw M 1 $kmx $kmy
        set km_t1 [list [expr {[km_gf $vdrw] & 64}] [wviewer::plot_mode $tok] $::km_fwd]
        set ::km_fwd {}
        km_key $vdrw M 1 $kmx $kmy
        check "KM2 Shift-M still toggles the measurement tooltip (on, then off) and leaves the mode alone" \
          [list $km_t1 [list [expr {[km_gf $vdrw] & 64}] [wviewer::plot_mode $tok] $::km_fwd]] \
          {{64 single {{77 1}}} {0 single {{77 1}}}}
        set km_m0 [km_mk $vdrw]
        km_key $vdrw m 0 {*}[lindex $km_on 0]
        set km_m1 [km_mk $vdrw]
        km_key $vdrw m 4 {*}[lindex $km_on 1]
        check "KM2 bare m and Ctrl-m over a trace still create one marker each, and no box" \
          [list [expr {$km_m1 - $km_m0}] [expr {[km_mk $vdrw] - $km_m1}] [expr {$::mb_hits - $km_mb0}]] {1 1 0}
        # d, the delta marker, is the other key that reaches the engine with the
        # read-only flag lifted. With one marker in place a bare d over a trace
        # makes a second one, measured from the first: the `prev` field of its
        # record (the eighth of `xschem graph_marker list`) holds the first
        # marker's number, and the first marker's own holds 0.
        catch {wviewer::delete_all_markers_at $vdrw}
        km_key $vdrw m 0 {*}[lindex $km_on 0]
        xschem new_schematic switch $vdrw
        set km_dl0 [xschem graph_marker list]
        set ::km_fwd {}
        km_key $vdrw d 0 {*}[lindex $km_on 1]
        xschem new_schematic switch $vdrw
        set km_dl1 [xschem graph_marker list]
        check "KM2 with one marker in place a bare d over a trace makes a second, a delta marker measured from the first: forwarded as typed, the markers before and after, the first marker's prev field, whether the new one's holds the first one's number, no box" \
          [list $::km_fwd [llength $km_dl0] [llength $km_dl1] [lindex $km_dl0 0 7] \
                [expr {[llength $km_dl1] == 2 && [lindex $km_dl0 0 0] > 0 &&
                       [lindex $km_dl1 1 7] == [lindex $km_dl0 0 0]}] \
                [expr {$::mb_hits - $km_mb0}]] \
          {{{100 0}} 1 2 0 1 0}

        # ...and the marker keys and the two cursor keys in BOTH profiles, the
        # stock one and then the Cadence one (the one src/cadence_style_rc
        # sets). The rows above run in the stock profile only. Per profile
        # (km_profile_keys):
        #   * the readout bar is taken down the way its checkbutton does it and
        #     the on-trace pixels are scanned again (the bar changes the height
        #     of the canvas);
        #   * bare m, Control-m and bare d on the trace: each is handed to the
        #     engine as typed and each makes one marker. These are the keys that
        #     reach the engine with the read-only flag lifted;
        #   * bare a, then bare b 60 pixels to its right: each is handed on as
        #     typed, the engine's cursor comes on and the checkbutton of the
        #     Cursors menu with it (the pair ca_cursorA reads, and km_curB for
        #     B), the readout bar is shown again and reads an x under that
        #     cursor;
        #   * a and b once more: both pairs off, both lines of the bar empty.
        # Afterwards the bar is put back as it was, and the canvas must be as
        # tall as it was before the leg: the pixels the later rows use were
        # taken at that height.
        proc km_curB {vdrw tok} {
          xschem new_schematic switch $vdrw
          set bit 0
          catch {set bit [expr {([xschem get graph_flags] & 4) ? 1 : 0}]}
          set mir 0
          catch {set mir [expr {$::wviewer::cvb($tok) ? 1 : 0}]}
          return [list $mir $bit]
        }
        proc km_bar {vtop} {
          set m 0
          catch {set m [winfo ismapped $vtop.wvreadout]}
          return $m
        }
        # two pixels of strip 0 that the engine agrees are on the trace, at the
        # middle of the strip and 90 pixels to its right; fewer when it finds
        # fewer
        proc km_scan_on {vdrw} {
          set on {}
          set b0 [lindex [ca_bands $vdrw] 0]
          if {[llength $b0] != 4} { return $on }
          lassign [km_mid $vdrw 0] mx my
          foreach px [list $mx [expr {$mx + 90}]] {
            for {set y [expr {int([lindex $b0 1]) + 14}]} {$y < int([lindex $b0 3]) - 14} {incr y} {
              if {[wb_at $vdrw 0 $px $y 3] >= 0} { lappend on [list $px $y] ; break }
            }
          }
          return $on
        }
        proc km_profile_keys {vdrw vtop tok} {
          set ::wviewer::cvr($tok) 0
          wviewer::readout_show $tok
          for {set i 0} {$i < 10} {incr i} { update; after 20 }
          xschem new_schematic switch $vdrw
          catch {wviewer::delete_all_markers_at $vdrw}
          set on [km_scan_on $vdrw]
          if {[llength $on] < 2} { return [list no-two-pixels-on-the-trace $on] }
          set mk {}
          foreach {ks st p} [list m 0 [lindex $on 0] m 4 [lindex $on 1] d 0 [lindex $on 0]] {
            set m0 [km_mk $vdrw]
            set ::km_fwd {}
            km_key $vdrw $ks $st {*}$p
            lappend mk [list $::km_fwd [expr {[km_mk $vdrw] - $m0}]]
          }
          catch {wviewer::delete_all_markers_at $vdrw}
          set r [list $mk]
          set bar0 [km_bar $vtop]
          lassign [km_mid $vdrw 0] mx my
          set ::km_fwd {}
          km_key $vdrw a 0 $mx $my
          for {set i 0} {$i < 5} {incr i} { update; after 20 }
          lappend r [list $bar0 $::km_fwd [ca_cursorA $vdrw $tok] [km_bar $vtop] \
                          [expr {[lindex [km_readout $vtop] 0] ne {}}]]
          lassign [km_mid $vdrw 0] mx my
          set ::km_fwd {}
          km_key $vdrw b 0 [expr {$mx + 60}] $my
          lappend r [list $::km_fwd [km_curB $vdrw $tok] [expr {[lindex [km_readout $vtop] 1] ne {}}]]
          km_key $vdrw a 0 $mx $my
          km_key $vdrw b 0 [expr {$mx + 60}] $my
          lappend r [list [ca_cursorA $vdrw $tok] [km_curB $vdrw $tok] [km_readout $vtop]]
          return $r
        }
        set km_cad0 $::cadence_compat
        set km_at0 $::autotrim_wires
        set km_cvr0 0
        catch {set km_cvr0 $::wviewer::cvr($tok)}
        set km_h0 [winfo height $vdrw]
        set km2p {}
        foreach km_prof {0 1} {
          set ::cadence_compat $km_prof
          lappend km2p [list $km_prof [expr {$::cadence_compat ? 1 : 0}] [km_profile_keys $vdrw $vtop $tok]]
        }
        set ::cadence_compat $km_cad0
        set ::autotrim_wires $km_at0
        # whatever a leg left behind: both cursors off on both sides, no marker,
        # the bar as it was
        set ::wviewer::cva($tok) 0
        wviewer::cursor_toggle $tok 1
        set ::wviewer::cvb($tok) 0
        wviewer::cursor_toggle $tok 2
        catch {wviewer::delete_all_markers_at $vdrw}
        set ::wviewer::cvr($tok) $km_cvr0
        wviewer::readout_show $tok
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        xschem new_schematic switch $vdrw
        set km_p1 {{{{109 0}} 1} {{{109 4}} 1} {{{100 0}} 1}}
        set km_p2 {0 {{97 0}} {1 1} 1 1}
        set km_p3 {{{98 0}} {1 1} 1}
        set km_p4 {{0 0} {0 0} {{} {}}}
        check "KM2 the marker keys and the cursor keys in both profiles, stock and then Cadence (per profile: cadence_compat as the leg set it and as it reads; bare m, Control-m and bare d on a trace, each with what the engine was handed and the markers it made; bare a with the readout bar down before it, what the engine was handed, the Cursor A checkbutton and the engine's cursor A, the bar shown, an x read under A; bare b the same for B; a and b again, both pairs and both lines of the bar)" \
          $km2p [list [list 0 0 [list $km_p1 $km_p2 $km_p3 $km_p4]] [list 1 1 [list $km_p1 $km_p2 $km_p3 $km_p4]]]
        check "KM2 fixture: the profile is back, the cursors are off on both sides, no marker is left, and the canvas is as tall as it was before the leg" \
          [list $::cadence_compat $::autotrim_wires [ca_cursorA $vdrw $tok] [km_curB $vdrw $tok] [km_mk $vdrw] \
                [expr {[winfo height $vdrw] == $km_h0}]] \
          [list $km_cad0 $km_at0 {0 0} {0 0} 0 1]
        rename km_profile_keys {}
        rename km_scan_on {}

        # --- KM4: Caps Lock (the case as typed decides, ruling 2026-10-16) ------
        # Each row from here on sets the mode it starts from: a row that read
        # the mode the row before left would pass or fail with that row.
        wviewer::set_plot_mode single $tok
        set ::km_fwd {} ; set ::km_log {}
        km_key $vdrw M 6 $kmx $kmy
        check "KM4 Caps Lock + Ctrl-m is the same chord: the mode flips, one line, no box, nothing forwarded" \
          [list [wviewer::plot_mode $tok] $::km_log [expr {$::mb_hits - $km_mb0}] $::km_fwd] \
          [list multi [list [list wviewer::set_plot_mode multi $tok]] 0 {}]
        wviewer::set_plot_mode multi $tok
        set km_m2 [km_mk $vdrw]
        set ::km_fwd {} ; set ::km_log {}
        km_key $vdrw m 7 {*}[lindex $km_on 0]
        check "KM4 Caps Lock + Ctrl-Shift-M is typed lower: it stays the engine's Ctrl-m (a marker), and the mode stays" \
          [list [wviewer::plot_mode $tok] $::km_log [expr {[km_mk $vdrw] - $km_m2}] \
                [expr {$::mb_hits - $km_mb0}] [lindex $::km_fwd 0 0]] \
          {multi {} 1 0 109}
        # Num Lock on top: the chord still flips, and a bare graph key still works
        wviewer::set_plot_mode multi $tok
        set ::km_fwd {} ; set ::km_log {}
        km_key $vdrw M 21 $kmx $kmy
        set km_n1 [list [wviewer::plot_mode $tok] $::km_fwd [expr {$::mb_hits - $km_mb0}]]
        set ::km_fwd {}
        km_key $vdrw a 16 $kmx $kmy
        set km_n2 [list [ca_cursorA $vdrw $tok] $::km_fwd]
        km_key $vdrw a 16 $kmx $kmy
        check "KM5 with Num Lock on Ctrl-Shift-M flips the mode (multi to single), and bare a still toggles cursor A (on, off)" \
          [list $km_n1 $km_n2 [ca_cursorA $vdrw $tok]] \
          {{single {} 0} {{1 1} {{97 16}}} {0 0}}
        catch {wviewer::delete_all_markers_at $vdrw}
        check "KM5 fixture: the markers of the rows above are gone again" [km_mk $vdrw] 0

        # --- KM3: two subwindows, the TARGET one flips --------------------------
        # The pointer stays over subwindow 1 for every press: the chord follows
        # the target, not the pointer.
        wviewer::set_plot_mode single $tok
        wviewer::new_subwin $tok
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        lassign [km_mid $vdrw 0] km3x km3y
        lassign [km_mid $vdrw 2] km3x2 km3y2
        check "KM3 fixture: two subwindows, the new one the target, both single" \
          [list [wviewer::sw_count [dict get [wviewer::layout_for $tok] graphs]] \
                [wviewer::target_index $tok] [wviewer::plot_mode $tok] [wviewer::base_mode $tok]] \
          {2 2 single single}
        set ::km_fwd {}
        km_key $vdrw M 5 $km3x $km3y
        set km3a [list [wviewer::plot_mode $tok] [km_status $vtop]]
        wviewer::click_target $vdrw $km3x $km3y
        set km3b [list [wviewer::target_index $tok] [wviewer::plot_mode $tok] [km_status $vtop]]
        check "KM3 the chord flips the TARGET subwindow only: it reads multi, the one under the pointer still single" \
          [list $km3a $km3b] {{multi multi} {0 single single}}
        km_key $vdrw M 5 $km3x $km3y
        set km3c [list [wviewer::plot_mode $tok] [km_status $vtop]]
        km_key $vdrw M 5 $km3x $km3y
        set km3d [wviewer::plot_mode $tok]
        wviewer::click_target $vdrw $km3x2 $km3y2
        check "KM3 after a click in the other subwindow the chord flips that one (multi, back to single); the first keeps its multi; no box, nothing forwarded" \
          [list $km3c $km3d [wviewer::target_index $tok] [wviewer::plot_mode $tok] \
                [expr {$::mb_hits - $km_mb0}] $::km_fwd] \
          {{multi multi} single 2 multi 0 {}}
        wviewer::close_subwin $tok
        wviewer::set_plot_mode single $tok
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        lassign [km_mid $vdrw 0] kmx kmy
        check "KM3 fixture: back to one subwindow, single" \
          [list [wviewer::sw_count [dict get [wviewer::layout_for $tok] graphs]] [wviewer::plot_mode $tok]] {1 single}

        # --- KM7: plain s in the Cadence profile swaps the cursors -------------
        # Writing cadence_compat turns autotrim_wires on through a write trace:
        # both are saved and put back.
        km_key $vdrw a 0 $kmx $kmy
        km_key $vdrw b 0 [expr {$kmx + 60}] $kmy
        set km_c0 [km_cur $vdrw]
        check_true "KM7 fixture: cursors A and B are on, at two different x" \
          [expr {([km_gf $vdrw] & 6) == 6 && [lindex $km_c0 0] != [lindex $km_c0 1]}]
        # the readout bar came up with the cursors; what it reads under A and
        # under B is taken before and after each swap
        update
        set km_r0 [km_readout $vtop]
        set km_rm 0
        catch {set km_rm [winfo ismapped $vtop.wvreadout]}
        check_true "KM7 fixture: the readout bar is shown and reads cursor A and cursor B at two different x" \
          [expr {$km_rm && [lindex $km_r0 0] ne {} && [lindex $km_r0 1] ne {} &&
                 [lindex $km_r0 0] ne [lindex $km_r0 1]}]
        # the chord of this item WHILE THE CURSORS SHOW, the state of a user who
        # is measuring (the other rows press it with the cursors off). A
        # real Ctrl-Shift-M flips the mode and the status bar follows, with one
        # action-log line, nothing handed to the engine and no box; the engine's
        # two cursors stay on where they were and the readout bar reads what it
        # read. A second press flips back.
        wviewer::set_plot_mode single $tok
        set ::km_fwd {} ; set ::km_log {} ; set km_mb7c $::mb_hits
        km_key $vdrw M 5 $kmx $kmy
        set km7c [list [wviewer::plot_mode $tok] [km_status $vtop] $::km_log $::km_fwd \
                       [expr {$::mb_hits - $km_mb7c}] [expr {[km_gf $vdrw] & 6}] \
                       [expr {[km_cur $vdrw] eq $km_c0}] [km_bar $vtop] [expr {[km_readout $vtop] eq $km_r0}]]
        set ::km_log {}
        km_key $vdrw M 5 $kmx $kmy
        lappend km7c [wviewer::plot_mode $tok] $::km_log
        check "KM7 with cursors A and B showing, a real Ctrl-Shift-M flips the mode all the same: multi, the status bar with it, one action-log line, nothing handed to the engine, no box, both cursors still on in the engine and at the x they had, the readout bar still shown and reading what it read; a second press gives single with its one line" \
          $km7c [list multi multi [list [list wviewer::set_plot_mode multi $tok]] {} 0 6 1 1 1 \
                      single [list [list wviewer::set_plot_mode single $tok]]]
        wviewer::set_plot_mode single $tok
        set km_cad0 $::cadence_compat
        set km_at0 $::autotrim_wires
        set ::cadence_compat 1
        set km_mb1 $::mb_hits
        set ::km_fwd {}
        km_key $vdrw s 0 $kmx $kmy
        set km_r1 [km_readout $vtop]
        check "KM7 Cadence profile: plain s over a strip swaps the cursors, pops nothing, and reaches the engine as its Control-s graph chord" \
          [list [km_cur $vdrw] [expr {$::mb_hits - $km_mb1}] $::km_fwd] \
          [list [list [lindex $km_c0 1] [lindex $km_c0 0]] 0 {{115 4}}]
        set ::cadence_compat $km_cad0
        set ::autotrim_wires $km_at0
        set ::km_fwd {}
        km_key $vdrw s 0 $kmx $kmy
        set km_r2 [km_readout $vtop]
        check "KM7 stock profile: plain s swaps them back, forwarded as it is typed" \
          [list [km_cur $vdrw] [expr {$::mb_hits - $km_mb1}] $::km_fwd] [list $km_c0 0 {{115 0}}]
        check "KM7 the readout bar follows both swaps: the x it reads under A and the x it reads under B change places after the Cadence profile's s, and again after the stock profile's" \
          [list $km_r1 $km_r2] [list [lreverse $km_r0] $km_r0]
        # ...and the third way the cursors swap: a TYPED Control-s, which the
        # engine hands to the graph in both profiles. Stock profile, then
        # Cadence. The filter is asked first and the key is sent only when it
        # forwards the chord as typed (off a graph Control-s is Save). After
        # each press the engine's two cursor x have changed places, and so
        # have the two x the readout bar reads.
        set km7s {}
        foreach km_prof {0 1} {
          set ::cadence_compat $km_prof
          set km_cb [km_cur $vdrw]
          set km_rb [km_readout $vtop]
          set km_w [km_decides $vdrw 115 4 $kmx $kmy]
          if {$km_w ne {{115 4}}} { lappend km7s [list $km_prof not-sent-the-filter-would-forward $km_w] ; continue }
          set ::km_fwd {} ; set km_mb7 $::mb_hits ; set km_sa7 $::km_sacd
          km_key $vdrw s 4 $kmx $kmy
          lappend km7s [list $km_prof $::km_fwd \
            [expr {[lindex $km_cb 0] != [lindex $km_cb 1] && [km_cur $vdrw] eq [lreverse $km_cb]}] \
            [expr {[lindex $km_rb 0] ne [lindex $km_rb 1] && [km_readout $vtop] eq [lreverse $km_rb]}] \
            [expr {$::mb_hits - $km_mb7}] [expr {$::km_sacd - $km_sa7}]]
        }
        set ::cadence_compat $km_cad0
        set ::autotrim_wires $km_at0
        check "KM7 a typed Control-s swaps the cursors too, stock profile then Cadence: the filter forwards it as typed, the engine's two cursor x change places and so do the two x the readout bar reads, no box, no Save form (per profile: cadence_compat, what the engine was handed, the cursors swapped, the readout swapped, boxes, forms)" \
          $km7s {{0 {{115 4}} 1 1 0 0} {1 {{115 4}} 1 1 0 0}}
        check "KM7 the profile was put back" \
          [list $::cadence_compat $::autotrim_wires] [list $km_cad0 $km_at0]
        km_key $vdrw a 0 $kmx $kmy
        km_key $vdrw b 0 [expr {$kmx + 60}] $kmy
        set ::wviewer::cva($tok) 0
        wviewer::cursor_toggle $tok 1
        set ::wviewer::cvb($tok) 0
        wviewer::cursor_toggle $tok 2

        # --- KM8: Alt, Super, Control-Alt and Control-Super with a graph key ----
        # The population is the product's graph-key list times four modifier sets.
        # The family of the report is inside it: Alt-s and Super-s (a reload
        # prompt), Control-Alt-s (the Save-as-symbol form), Control-Alt-t (a new
        # schematic), Alt-b and Super-b (hide-symbols), Alt-m and Super-m (a move).
        # Every chord goes through the pre-flight. The real key is not sent for a
        # chord whose Control half is a shortcut of the viewer's own (km_tagged):
        # Tk runs a binding when the event carries more modifiers than the binding
        # names, so Control-Alt-d is still Clear All.
        proc km_tagged {N s} {
          if {!($s & 4)} { return 0 }
          set c [format %c $N]
          set seqs [list <Control-Key-$c>]
          if {$s & 1} { lappend seqs <Control-Shift-Key-$c> }
          foreach seq $seqs { if {[bind WaveViewer $seq] ne {}} { return 1 } }
          return 0
        }
        set km_bad {} ; set km_n 0 ; set km_sent 0
        foreach N $::wviewer::graphkeys {
          foreach km_mod {8 64 12 68} {
            incr km_n
            set s [expr {$km_mod | [km_plain $N]}]
            set nm "[format %c $N]/$s"
            set w [km_decides $vdrw $N $s $kmx $kmy]
            if {$w ne {}} { lappend km_bad [list $nm the-filter-would-forward $w] ; continue }
            if {[km_tagged $N $s]} continue
            incr km_sent
            set s0 [km_snap $vdrw $tok]
            set mb0 $::mb_hits ; set sa0 $::km_sacd ; set ::km_fwd {}
            set d [km_key $vdrw [format %c $N] $s $kmx $kmy]
            set s1 [km_snap $vdrw $tok]
            if {!$d} { lappend km_bad [list $nm not-delivered] ; continue }
            if {$::kf_last ne [list 2 $N $s]} { lappend km_bad [list $nm arrived-as $::kf_last] }
            if {$::km_fwd ne {}} { lappend km_bad [list $nm forwarded $::km_fwd] }
            if {$::mb_hits != $mb0} { lappend km_bad [list $nm message-box] }
            if {$::km_sacd != $sa0} { lappend km_bad [list $nm save-form] }
            if {$s1 ne $s0} { lappend km_bad [list $nm state-moved $s0 $s1] }
          }
        }
        check "KM8 every graph key with Alt, Super, Control-Alt or Control-Super: the filter forwards none, and a real press changes nothing (chords walked, offenders)" \
          [list $km_n $km_bad] [list [expr {4 * $km_nkeys}] {}]
        check_true "KM8 ...and the real key was sent for every Alt and Super chord at least" \
          [expr {$km_sent >= 2 * $km_nkeys}]
        rename km_tagged {}

        # --- KM9: the few pixels just inside a strip's edge ---------------------
        # The engine's graph test leaves a border inside each graph rect, and there
        # a forwarded graph key runs the canvas arm. The population is every graph
        # key, plain and with Control, that the filter forwards in the middle of
        # the strip (the pre-flight says which). Each is tried at two pixels of the
        # top edge: two pixels in, and the deepest whole pixel the engine still
        # takes for the canvas (its border is a factor, read out of waves_selected
        # here, times the Tk scaling). Bare b is tried at the three other edges as
        # well. Then the same walk of the top edge in the Cadence profile, where
        # plain s goes out as Control-s: off a graph that is Save.
        set km_bf {}
        if {![catch {set km_fd [open [file join $repo src callback.c] r]}]} {
          set km_c [read $km_fd]
          close $km_fd
          set km_a [string first "\nstatic int waves_selected(" $km_c]
          if {$km_a >= 0} {
            set km_c [string range $km_c $km_a [string first "\n\x7d\n" $km_c $km_a]]
            regsub -all {/\*.*?\*/} $km_c {} km_c
            regexp {\mborder\s*=\s*([0-9.]+)\s*\*\s*tk_scaling\s*\*\s*xctx->zoom\s*;} $km_c -> km_bf
          }
          unset km_c
        }
        check_true "KM9 fixture: waves_selected in src/callback.c gave up the factor of its border" \
          [string is double -strict $km_bf]
        if {![string is double -strict $km_bf]} { set km_bf 5.0 }
        set km_b0 [lindex [ca_bands $vdrw] 0]
        set km_edge {}
        set km_deep -1
        if {[llength $km_b0] == 4} {
          lassign $km_b0 ex1 ey1 ex2 ey2
          set km_deep [expr {int(ceil($ey1 + $km_bf * [tk scaling])) - 1}]
          set km_edge [list top [list $kmx [expr {int($ey1) + 2}]] \
                            top-deep [list $kmx $km_deep] \
                            bottom [list $kmx [expr {int($ey2) - 2}]] \
                            left [list [expr {int($ex1) + 2}] $kmy] \
                            right [list [expr {int($ex2) - 3}] $kmy]]
        }
        # the engine's own word on the deep pixel and on the next one in, asked
        # with Shift-M sent to it directly: the read-only box is the canvas arm,
        # the tooltip flag is the graph
        set km_e {}
        if {$km_deep >= 0} {
          foreach km_y [list $km_deep [expr {$km_deep + 1}]] {
            set mb0 $::mb_hits
            set km_g0 [expr {[km_gf $vdrw] & 64}]
            ::km_real_xschem callback $vdrw 6 $kmx $km_y 0 0 0 0
            ::km_real_xschem callback $vdrw 2 $kmx $km_y 77 0 0 1
            set km_g1 [expr {[km_gf $vdrw] & 64}]
            lappend km_e [list [expr {$::mb_hits - $mb0}] [expr {$km_g1 != $km_g0}]]
            if {$km_g1 != $km_g0} { ::km_real_xschem callback $vdrw 2 $kmx $km_y 77 0 0 1 }
          }
        }
        check "KM9 fixture: the engine itself takes the deep pixel for the canvas (Shift-M sent to it there stops at the read-only box and leaves the tooltip flag) and the next pixel in for the graph (the flag moves, no box)" \
          $km_e {{1 0} {0 1}}
        # the keys the filter forwards in the middle of the strip, by pre-flight
        proc km_members {vdrw px py} {
          set mem {}
          foreach N $::wviewer::graphkeys {
            foreach ctl {0 4} {
              set s [expr {$ctl | [km_plain $N]}]
              if {[km_decides $vdrw $N $s $px $py] ne {}} { lappend mem [list $N $s] }
            }
          }
          return $mem
        }
        # every member at the two top-edge pixels, bare b at the other edges:
        # the pre-flight first, the real key only when the filter refuses it.
        # Answers the number of keys walked and the offenders.
        proc km_walk {vdrw tok edge mem} {
          set bad {}
          set n 0
          foreach {side p} $edge {
            lassign $p ex ey
            foreach ch $mem {
              lassign $ch N s
              if {![string match top* $side] && !($N == 98 && $s == 0)} continue
              incr n
              set nm "$side [format %c $N]/$s"
              set w [km_decides $vdrw $N $s $ex $ey]
              if {$w ne {}} { lappend bad [list $nm the-filter-would-forward $w] ; continue }
              set s0 [km_snap $vdrw $tok]
              set mb0 $::mb_hits ; set sa0 $::km_sacd ; set ::km_fwd {}
              set d [km_key $vdrw [format %c $N] $s $ex $ey]
              set s1 [km_snap $vdrw $tok]
              if {!$d} { lappend bad [list $nm not-delivered] ; continue }
              if {$::km_fwd ne {}} { lappend bad [list $nm forwarded $::km_fwd] }
              if {$::mb_hits != $mb0} { lappend bad [list $nm message-box] }
              if {$::km_sacd != $sa0} { lappend bad [list $nm save-form] }
              if {$s1 ne $s0} { lappend bad [list $nm state-moved $s0 $s1] }
            }
          }
          return [list $n $bad]
        }
        set km_mem [km_members $vdrw $kmx $kmy]
        check_true "KM9 fixture: in the middle of the strip the filter forwards every bare graph key at least" \
          [expr {[llength $km_mem] >= $km_nkeys}]
        check "KM9 a graph key at the two top-edge pixels (two pixels in, and the deepest the engine still takes for the canvas), bare b at the other three edges: the filter forwards none, and a real press changes nothing (keys walked, offenders)" \
          [km_walk $vdrw $tok $km_edge $km_mem] [list [expr {2 * [llength $km_mem] + 3}] {}]
        set km_cad0 $::cadence_compat
        set km_at0 $::autotrim_wires
        set ::cadence_compat 1
        set km_memc [km_members $vdrw $kmx $kmy]
        set km_wc [km_walk $vdrw $tok [lrange $km_edge 0 3] $km_memc]
        set ::cadence_compat $km_cad0
        set ::autotrim_wires $km_at0
        check_true "KM9 fixture, Cadence profile: in the middle of the strip the filter forwards plain s and every other bare graph key" \
          [expr {[lsearch -exact $km_memc {115 0}] >= 0 && [llength $km_memc] >= $km_nkeys}]
        check "KM9 Cadence profile: a graph key at the two top-edge pixels, plain s among them: the filter forwards none, and a real press changes nothing, no Save form either (keys walked, offenders); the profile is back" \
          [list $km_wc [list $::cadence_compat $::autotrim_wires]] \
          [list [list [expr {2 * [llength $km_memc]}] {}] [list $km_cad0 $km_at0]]
        rename km_members {}
        rename km_walk {}
        set ::km_fwd {}
        km_key $vdrw b 0 $kmx $kmy
        set km9c [list [expr {[km_gf $vdrw] & 4}] $::km_fwd]
        km_key $vdrw b 0 $kmx $kmy
        check "KM9 control: in the middle of the strip bare b is forwarded and toggles cursor B (on, off)" \
          [list $km9c [expr {[km_gf $vdrw] & 4}]] {{4 {{98 0}}} 0}
        # ...and in the middle of the SECOND strip: the pixel gate knows every
        # strip of the window, not the first alone
        lassign [km_mid $vdrw 1] km_x1 km_y1
        set ::km_fwd {}
        km_key $vdrw b 0 $km_x1 $km_y1
        set km9d [list [expr {[km_gf $vdrw] & 4}] $::km_fwd]
        km_key $vdrw b 0 $km_x1 $km_y1
        set ::km_fwd {}
        km_key $vdrw M 1 $km_x1 $km_y1
        set km9e [list [expr {[km_gf $vdrw] & 64}] $::km_fwd]
        km_key $vdrw M 1 $km_x1 $km_y1
        check "KM9 control: in the middle of the second strip bare b is forwarded and toggles cursor B, and Shift-M the tooltip (each on, then off again)" \
          [list $km9d $km9e [expr {[km_gf $vdrw] & 68}]] {{4 {{98 0}}} {64 {{77 1}}} 0}
        # ...and where the gate BEGINS. The walks above hold it from outside (the
        # pixels it must refuse); these two legs hold it from inside: the first
        # pixel it must accept, the width of the border the product states
        # (wviewer::graph_border_px) inside the top edge of strip 0, and inside
        # its left edge. Bare b is forwarded there and toggles cursor B. The key
        # is sent only at a pixel past the engine's own border (the factor read
        # above), where the engine takes it for the graph whatever the filter
        # does; at any other pixel the leg says so and sends nothing.
        set km_gbp {}
        catch {set km_gbp [wviewer::graph_border_px]}
        set km9f {}
        if {[llength $km_b0] == 4 && [string is integer -strict $km_gbp]} {
          lassign $km_b0 ex1 ey1 ex2 ey2
          set km_eb [expr {$km_bf * [tk scaling]}]
          foreach {side fx fy at lo} [list \
              top  $kmx [expr {int(ceil($ey1 + $km_gbp))}] [expr {int(ceil($ey1 + $km_gbp))}] [expr {int(ceil($ey1 + $km_eb))}] \
              left [expr {int(ceil($ex1 + $km_gbp))}] $kmy [expr {int(ceil($ex1 + $km_gbp))}] [expr {int(ceil($ex1 + $km_eb))}]] {
            if {$at < $lo} { lappend km9f $side the-engine-takes-that-pixel-for-the-canvas ; continue }
            set ::km_fwd {}
            km_key $vdrw b 0 $fx $fy
            set km_on1 [expr {[km_gf $vdrw] & 4}]
            set km_f1 $::km_fwd
            if {$km_on1} { km_key $vdrw b 0 $fx $fy }
            lappend km9f $side [list $km_f1 $km_on1 [expr {[km_gf $vdrw] & 4}]]
          }
        }
        check "KM9 where the gate begins: at the first pixel the border's width (graph_border_px) inside the top edge of the strip, and inside its left edge, bare b is forwarded and toggles cursor B (per edge: what the engine was handed, B on, B off again)" \
          $km9f {top {{{98 0}} 4 0} left {{{98 0}} 4 0}}
        # ...and in a window of MORE than two strips. In multi-plot mode every
        # signal has a strip of its own, so three strips and more is the
        # ordinary window. The fixture gets two strips more for this leg. The
        # strips walked are the canvas' own bands (wviewer::strip_bands_px),
        # every one of them: a real bare b in the middle of each is forwarded
        # and toggles cursor B (on, then off again). Then the fixture is put
        # back to its two strips.
        set km_gs9 [dict get [wviewer::layout_for $tok] graphs]
        wviewer::set_graphs $tok [concat $km_gs9 [list \
          [dict replace [wviewer::empty_graph] traces [list $ca_t0]] \
          [dict replace [wviewer::empty_graph] traces [list $ca_t0]]]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        xschem new_schematic switch $vdrw
        set km_nb9 [llength [ca_bands $vdrw]]
        set km9g {} ; set km9w {}
        for {set km_gi 0} {$km_gi < $km_nb9} {incr km_gi} {
          lassign [km_mid $vdrw $km_gi] km_gx km_gy
          set ::km_fwd {}
          km_key $vdrw b 0 $km_gx $km_gy
          set km_on1 [expr {[km_gf $vdrw] & 4}]
          set km_f1 $::km_fwd
          if {$km_on1} { km_key $vdrw b 0 $km_gx $km_gy }
          lappend km9g [list $km_f1 $km_on1 [expr {[km_gf $vdrw] & 4}]]
          lappend km9w {{{98 0}} 4 0}
        }
        check "KM9 control, a window of more than two strips: in the middle of every strip, the last like the first, bare b is forwarded and toggles cursor B (the canvas has more than two bands; per band: what the engine was handed, B on, B off again)" \
          [list [expr {$km_nb9 > 2}] $km9g] [list 1 $km9w]
        wviewer::set_graphs $tok $km_gs9
        wviewer::regenerate $tok
        wviewer::fit $tok
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        xschem new_schematic switch $vdrw
        lassign [km_mid $vdrw 0] kmx kmy
        check "KM9 fixture: back to two strips with a band each" [llength [ca_bands $vdrw]] 2
        # MORE CONTROLS, each a window the legs above do not have: here two
        # subwindows and a window whose size changed, in KM6 and KM15 below a
        # second tab and a second viewer window. In each the gate must go on
        # saying yes in the middle of a strip.
        # km_bwalk: a real bare b in the middle of every band the canvas holds
        # (wviewer::strip_bands_px). Per band: what the engine was handed,
        # cursor B on after the press, off again after a second one.
        # km_bwant: what that walk gives for n bands when every b arrives.
        proc km_bwalk {vdrw} {
          set r {}
          set n [llength [ca_bands $vdrw]]
          for {set gi 0} {$gi < $n} {incr gi} {
            lassign [km_mid $vdrw $gi] x y
            set ::km_fwd {}
            km_key $vdrw b 0 $x $y
            set on [expr {[km_gf $vdrw] & 4}]
            set f $::km_fwd
            if {$on} { km_key $vdrw b 0 $x $y }
            lappend r [list $f $on [expr {[km_gf $vdrw] & 4}]]
          }
          return $r
        }
        proc km_bwant {n} {
          set r {}
          for {set i 0} {$i < $n} {incr i} { lappend r {{{98 0}} 4 0} }
          return $r
        }
        # 1 when pixel (px,py) lies inside one of `bands` by at least `inset`
        proc km_inband {bands px py inset} {
          foreach b $bands {
            lassign $b x1 y1 x2 y2
            if {$px >= $x1 + $inset && $px <= $x2 - $inset &&
                $py >= $y1 + $inset && $py <= $y2 - $inset} { return 1 }
          }
          return 0
        }
        # TWO SUBWINDOWS. They sit side by side, so the bands of the canvas no
        # longer share one left edge: the row counts the distinct left edges and
        # wants more than one, then walks every band.
        wviewer::set_plot_mode single $tok
        wviewer::new_subwin $tok
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        xschem new_schematic switch $vdrw
        set km_bb9 [ca_bands $vdrw]
        set km_cols9 [llength [lsort -unique [lmap km_b $km_bb9 {expr {int([lindex $km_b 0])}}]]]
        set km9h [km_bwalk $vdrw]
        check "KM9 control, two subwindows side by side: in the middle of every strip of both, bare b is forwarded and toggles cursor B (subwindows; the bands of the canvas have more than one left edge; per band: what the engine was handed, B on, B off again)" \
          [list [wviewer::sw_count [dict get [wviewer::layout_for $tok] graphs]] [expr {$km_cols9 > 1}] $km9h] \
          [list 2 1 [km_bwant [llength $km_bb9]]]
        wviewer::close_subwin $tok
        wviewer::set_plot_mode single $tok
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        xschem new_schematic switch $vdrw
        check "KM9 fixture: back to one subwindow of two strips, single" \
          [list [wviewer::sw_count [dict get [wviewer::layout_for $tok] graphs]] [llength [ca_bands $vdrw]] \
                [wviewer::plot_mode $tok]] {1 2 single}
        # THE WINDOW CHANGES ITS SIZE, the strips kept. The viewer is made
        # taller (wm geometry; the canvas is waited for, then the re-tile). The
        # pixel pressed first is one no strip held before: in the lower strip
        # as it is now, the border's width and more inside it, and below the
        # bottom of every band the canvas had at the old size. Bare b there is
        # forwarded and toggles cursor B; so it is in the middle of every band
        # at the new size, and again in the middle of every band once the
        # window is back at its old size.
        set km_geo0 [wm geometry $vtop]
        set km_bb0 [ca_bands $vdrw]
        set km_ch0 [winfo height $vdrw]
        set km_grown 0
        if {[regexp {^(\d+)x(\d+)} $km_geo0 -> km_gw km_gh]} {
          wm geometry $vtop ${km_gw}x[expr {$km_gh + 200}]+0+0
          for {set i 0} {$i < 150} {incr i} {
            update
            if {[winfo height $vdrw] >= $km_ch0 + 150} { set km_grown 1 ; break }
            after 30
          }
          for {set i 0} {$i < 15} {incr i} { update; after 20 }
        }
        xschem new_schematic switch $vdrw
        set km_bb1 [ca_bands $vdrw]
        set km_ob 0
        foreach km_b $km_bb0 { if {[lindex $km_b 3] > $km_ob} { set km_ob [lindex $km_b 3] } }
        set km_lb [lindex $km_bb1 end]
        set km9r not-pressed
        set km_fresh 0
        if {[llength $km_lb] == 4} {
          set km_fx [expr {int(([lindex $km_lb 0] + [lindex $km_lb 2]) / 2.0)}]
          set km_fy [expr {int(($km_ob + [lindex $km_lb 3]) / 2.0)}]
          set km_fresh [expr {[km_inband $km_bb1 $km_fx $km_fy [expr {2 * [wviewer::graph_border_px]}]] &&
                              ![km_inband $km_bb0 $km_fx $km_fy 0]}]
          if {$km_fresh} {
            set ::km_fwd {}
            km_key $vdrw b 0 $km_fx $km_fy
            set km_on1 [expr {[km_gf $vdrw] & 4}]
            set km_f1 $::km_fwd
            if {$km_on1} { km_key $vdrw b 0 $km_fx $km_fy }
            set km9r [list $km_f1 $km_on1 [expr {[km_gf $vdrw] & 4}]]
          }
        }
        set km9s [km_bwalk $vdrw]
        check "KM9 control, the window made taller with its strips kept: at a pixel that lies well inside the lower strip now and below every band the canvas had before, bare b is forwarded and toggles cursor B, and so it is in the middle of every band at the new size (the canvas grew; the bands kept their number and the lower one reaches further down; the pixel is inside a band now and was in none; at that pixel: what the engine was handed, B on, B off again; per band the same)" \
          [list $km_grown [expr {[llength $km_bb1] == [llength $km_bb0] && [llength $km_lb] == 4 && [lindex $km_lb 3] > $km_ob}] \
                $km_fresh $km9r $km9s] \
          [list 1 1 1 {{{98 0}} 4 0} [km_bwant [llength $km_bb0]]]
        wm geometry $vtop $km_geo0
        for {set i 0} {$i < 150} {incr i} {
          update
          if {[winfo height $vdrw] == $km_ch0} break
          after 30
        }
        for {set i 0} {$i < 15} {incr i} { update; after 20 }
        xschem new_schematic switch $vdrw
        lassign [km_mid $vdrw 0] kmx kmy
        check "KM9 control, the window back at its old size: the canvas is as tall as it was, the bands are the ones it had, and in the middle of each bare b is forwarded and toggles cursor B" \
          [list [expr {[winfo height $vdrw] == $km_ch0}] [expr {[ca_bands $vdrw] eq $km_bb0}] [km_bwalk $vdrw]] \
          [list 1 1 [km_bwant [llength $km_bb0]]]
        set ::wviewer::cvb($tok) 0
        wviewer::cursor_toggle $tok 2

        # --- KM10: graph_use_ctrl_key set ---------------------------------------
        # There the engine's graph test needs Control, so a bare graph key runs
        # the canvas arm. Every graph key bare, then the chord of this item.
        set km_g0 0
        if {[info exists ::graph_use_ctrl_key]} { set km_g0 $::graph_use_ctrl_key }
        set ::graph_use_ctrl_key 1
        set km_bad {} ; set km_n 0
        foreach N $::wviewer::graphkeys {
          incr km_n
          set s [km_plain $N]
          set nm "[format %c $N]/$s"
          set w [km_decides $vdrw $N $s $kmx $kmy]
          if {$w ne {}} { lappend km_bad [list $nm the-filter-would-forward $w] ; continue }
          set s0 [km_snap $vdrw $tok]
          set mb0 $::mb_hits ; set ::km_fwd {}
          set d [km_key $vdrw [format %c $N] $s $kmx $kmy]
          if {!$d} { lappend km_bad [list $nm not-delivered] ; continue }
          if {$::km_fwd ne {}} { lappend km_bad [list $nm forwarded $::km_fwd] }
          if {$::mb_hits != $mb0} { lappend km_bad [list $nm message-box] }
          if {[km_snap $vdrw $tok] ne $s0} { lappend km_bad [list $nm state-moved] }
        }
        check "KM10 graph_use_ctrl_key set: a bare graph key is not forwarded and a real press changes nothing (keys walked, offenders)" \
          [list $km_n $km_bad] [list $km_nkeys {}]
        wviewer::set_plot_mode single $tok
        set ::km_fwd {} ; set km_mb2 $::mb_hits
        km_key $vdrw M 5 $kmx $kmy
        set km10 [list [wviewer::plot_mode $tok] $::km_fwd [expr {$::mb_hits - $km_mb2}]]
        km_key $vdrw M 5 $kmx $kmy
        check "KM10 ...and Ctrl-Shift-M is the plot mode there too (multi, back to single), no box, nothing forwarded" \
          [list $km10 [wviewer::plot_mode $tok]] {{multi {} 0} single}
        # the graph functions whose Control chord means something else in a
        # viewer, and which that option therefore leaves without a key there (the
        # guide's section on the graph keys names them): cursor A, cursor B, the
        # delta marker, the measurement tooltip. Ctrl-a is sent for real; the
        # other three are asked of the filter.
        set ::km_fwd {}
        km_key $vdrw a 4 $kmx $kmy
        set km10a [list $::km_fwd [expr {[km_gf $vdrw] & 2}]]
        set km10b {}
        foreach {N s} {98 4 100 4 77 5} { lappend km10b [km_decides $vdrw $N $s $kmx $kmy] }
        check "KM10 ...Ctrl-a goes to the engine and leaves cursor A off; Ctrl-b, Ctrl-d and Ctrl-Shift-M are not forwarded, so cursor B, the delta marker and the tooltip have no key there" \
          [list $km10a $km10b] {{{{97 4}} 0} {{} {} {}}}
        set ::graph_use_ctrl_key $km_g0
        check "KM10 the profile was put back" $::graph_use_ctrl_key $km_g0

        # --- KM11: a row of the user's own in the engine's binding table --------
        # A canvas row for a chord the filter forwards would run from the viewer:
        # the engine consults its table before its graph test. The row is bound
        # only after the pre-flight on the stock table said the key is forwarded
        # (so the refusal that follows is the row's doing), and the real key is
        # sent only when the filter refuses it with the row in place.
        set km_ow0 $::orthogonal_wiring
        set km_u0 [km_decides $vdrw 109 0 {*}[lindex $km_on 0]]
        catch {xschem bind key 109 0 canvas edit.toggle_orthogonal_wiring}
        set km_u1 [km_decides $vdrw 109 0 {*}[lindex $km_on 0]]
        set km_u2 not-sent
        if {$km_u1 eq {}} {
          set km_m3 [km_mk $vdrw] ; set ::km_fwd {}
          km_key $vdrw m 0 {*}[lindex $km_on 0]
          set km_u2 [list $::orthogonal_wiring [expr {[km_mk $vdrw] - $km_m3}] $::km_fwd]
        }
        catch {xschem unbind key 109 0 canvas}
        set km_m4 [km_mk $vdrw] ; set ::km_fwd {}
        km_key $vdrw m 0 {*}[lindex $km_on 0]
        check "KM11 a user's canvas row for bare m: forwarded before the row, refused with it (the row's action does not run, no marker), forwarded again without it (one marker)" \
          [list $km_u0 $km_u1 $km_u2 [list $::orthogonal_wiring [expr {[km_mk $vdrw] - $km_m4}] $::km_fwd]] \
          [list {{109 0}} {} [list $km_ow0 0 {}] [list $km_ow0 1 {{109 0}}]]
        catch {xschem set orthogonal_wiring $km_ow0}
        catch {wviewer::delete_all_markers_at $vdrw}

        # A graph.forward row of the user's for a Control chord that is a
        # shortcut of the viewer's own (the stock table has none; a keybindings
        # file from before the Signal Browser took Ctrl-B, or an rc line, puts
        # one back). Forwarded, one key press would run the shortcut and reach
        # the graph as well. All three are asked of the filter; the real key is
        # sent for Ctrl-Shift-M only (Ctrl-d would empty the fixture), and only
        # when the filter refuses it.
        set km_o {}
        foreach {N s} {98 4 100 4 77 5} {
          catch {xschem bind key $N ctrl graph graph.forward}
          lappend km_o [km_decides $vdrw $N $s $kmx $kmy]
        }
        wviewer::set_plot_mode single $tok
        set km_o2 not-sent
        if {[lindex $km_o 2] eq {}} {
          set ::km_fwd {} ; set ::km_log {}
          km_key $vdrw M 5 $kmx $kmy
          set km_o2 [list [wviewer::plot_mode $tok] [expr {[km_gf $vdrw] & 64}] $::km_fwd [llength $::km_log]]
        }
        foreach N {98 100 77} { catch {xschem unbind key $N ctrl graph} }
        check "KM11 a user's graph.forward row for Control with b, d or M: the filter forwards none of the three chords, and a real Ctrl-Shift-M with its row in place flips the mode once, leaves the tooltip flag and reaches the engine not at all" \
          [list $km_o $km_o2] [list {{} {} {}} {multi 0 {} 1}]
        if {[km_gf $vdrw] & 64} { ::km_real_xschem callback $vdrw 2 $kmx $kmy 77 0 0 1 }
        wviewer::set_plot_mode single $tok
        check "KM11 fixture: the three rows are unbound again" \
          [lsearch -all -inline -regexp [xschem bindings dump] {^key (98|100|77) ctrl graph}] {}

        # A row of the user's for Escape. The engine asks its table before its
        # Escape arm, so a forwarded Escape would run the row's action here. With
        # a row for the chord the key stays in the viewer and the abort is done
        # by the verb.
        set km_ow1 $::orthogonal_wiring
        set km_es {}
        set ::km_fwd {} ; set ::km_esc 0
        km_key $vdrw Escape 0 $kmx $kmy
        lappend km_es [list $::orthogonal_wiring $::km_fwd $::km_esc]
        catch {xschem bind key 65307 0 canvas edit.toggle_orthogonal_wiring}
        catch {xschem bind key 65307 shift canvas edit.toggle_orthogonal_wiring}
        set ::km_fwd {} ; set ::km_esc 0
        km_key $vdrw Escape 0 $kmx $kmy
        lappend km_es [list $::orthogonal_wiring $::km_fwd $::km_esc]
        set ::km_fwd {} ; set ::km_esc 0
        km_key $vdrw Escape 1 $kmx $kmy
        lappend km_es [list $::orthogonal_wiring $::km_fwd $::km_esc]
        catch {xschem unbind key 65307 0 canvas}
        catch {xschem unbind key 65307 shift canvas}
        set ::km_fwd {} ; set ::km_esc 0
        km_key $vdrw Escape 0 $kmx $kmy
        lappend km_es [list $::orthogonal_wiring $::km_fwd $::km_esc]
        check "KM11 a user's row for Escape and one for Shift-Escape: without them a real Escape is forwarded as typed; with them neither key reaches the engine, the row's action does not run and the escape verb runs once; without them again it is forwarded" \
          $km_es [list [list $km_ow1 {{65307 0}} 0] [list $km_ow1 {} 1] [list $km_ow1 {} 1] [list $km_ow1 {{65307 0}} 0]]
        catch {xschem set orthogonal_wiring $km_ow1}
        set ::orthogonal_wiring $km_ow1
        check "KM11 fixture: the Escape rows are unbound again" \
          [lsearch -all -inline -regexp [xschem bindings dump] {^key 65307 }] {}

        # --- KM13: every chord the filter forwards, through the real engine -----
        # The population is what the filter itself forwards in the middle of a
        # strip (the pre-flight), every graph key plain and with Control, in the
        # four profiles (Cadence or stock, graph_use_ctrl_key set or not).
        #
        # BEFORE a chord is sent it is asked of a comparand fed from the engine
        # (wvkey_engine.tcl: the live binding table, the arms of the key switch
        # that open with the graph test and the masks callback() strips, the last
        # two read out of src/callback.c): is this a chord the engine hands to
        # the graph in this profile, with the state the filter gives it? A chord
        # the comparand does not allow is an offender and is NOT sent: in the
        # engine it is an editor verb, and several of those are a prompt or a
        # form that nothing here dismisses.
        #
        # Each chord the comparand allows is then sent as a real key and must
        # change nothing outside the graph: no message box, no Save form, no new
        # window, and hide-symbols, ui_state, read-only, the layer-2 rect count,
        # orthogonal wiring and the plot mode as they were. A chord that moved a
        # graph flag is pressed again, so cursors and tooltip end as they began;
        # the markers the marker keys made are deleted.
        proc km_editor {vdrw tok} {
          xschem new_schematic switch $vdrw
          return [list mb $::mb_hits sacd $::km_sacd win [llength [xschem windows]] hs $::hide_symbols \
            ui [xschem get ui_state] ro [xschem get readonly] rects [xschem get rects 2] \
            ow $::orthogonal_wiring mode [wviewer::plot_mode $tok]]
        }
        source [file join $here wvkey_engine.tcl]
        set km_csrc {} ; set km_hsrc {}
        catch {set km_fd [open [file join $repo src callback.c] r] ; set km_csrc [read $km_fd] ; close $km_fd}
        catch {set km_fd [open [file join $repo src xschem.h] r] ; set km_hsrc [read $km_fd] ; close $km_fd}
        set km_msk [kc_masks [kc_cfacts $km_csrc $km_hsrc]]
        set km_guards [kc_guards $km_csrc]
        unset km_csrc km_hsrc
        check_true "KM13 fixture: src/callback.c gave up the masks callback() strips off a key's state, the bit count it keeps, and the arms of its key switch that open with the graph test, bare m among them" \
          [expr {[dict get $km_msk strip_ok] && [dict get $km_msk strip] != 0 && [dict get $km_msk range] != 0 &&
                 [lsearch -exact $km_guards {109 0 {}}] >= 0}]
        set km_cad0 $::cadence_compat
        set km_at0 $::autotrim_wires
        set km_g0 0
        if {[info exists ::graph_use_ctrl_key]} { set km_g0 $::graph_use_ctrl_key }
        wviewer::set_plot_mode single $tok
        set km_13 {}
        foreach {km_cad km_guck} {0 0 1 0 0 1 1 1} {
          set ::cadence_compat $km_cad
          set ::graph_use_ctrl_key $km_guck
          set km_n 0 ; set km_bad {}
          foreach N $::wviewer::graphkeys {
            foreach km_ctl {0 4} {
              set s [expr {$km_ctl | [km_plain $N]}]
              set km_w [km_decides $vdrw $N $s $kmx $kmy]
              if {$km_w eq {}} continue
              incr km_n
              set nm "[format %c $N]/$s"
              set km_x [kc_expect $N $s $km_cad $km_guck [::km_real_xschem bindings dump] $km_guards \
                          [dict get $km_msk strip] [dict get $km_msk range]]
              if {$km_x eq {} || $km_w ne [list [list $N $km_x]]} {
                lappend km_bad [list $nm not-a-chord-the-engine-hands-to-the-graph-so-not-sent the-filter-forwards $km_w the-engine-takes $km_x]
                continue
              }
              set km_e0 [km_editor $vdrw $tok]
              set km_f0 [km_gf $vdrw]
              set ::km_fwd {}
              set d [km_key $vdrw [format %c $N] $s $kmx $kmy]
              set km_e1 [km_editor $vdrw $tok]
              if {!$d} { lappend km_bad [list $nm not-delivered] ; continue }
              if {$::km_fwd eq {}} { lappend km_bad [list $nm not-forwarded] }
              if {$km_e1 ne $km_e0} { lappend km_bad [list $nm moved $km_e0 $km_e1] }
              if {[km_gf $vdrw] != $km_f0} { km_key $vdrw [format %c $N] $s $kmx $kmy }
            }
          }
          lappend km_13 [list $km_cad $km_guck [expr {$km_n > 0}] $km_bad]
          catch {wviewer::delete_all_markers_at $vdrw}
        }
        set ::cadence_compat $km_cad0
        set ::autotrim_wires $km_at0
        set ::graph_use_ctrl_key $km_g0
        check "KM13 every chord the filter forwards in the middle of a strip, in the four profiles: a comparand fed from the engine allows it, asked before the key is sent, and sent as a real key it reaches the engine and nothing outside the graph moves (per profile: Cadence, graph_use_ctrl_key, some chords walked, offenders)" \
          $km_13 {{0 0 1 {}} {1 0 1 {}} {0 1 1 {}} {1 1 1 {}}}
        check "KM13 the profile is back, and so are the graph flags of the cursors and the tooltip, and the markers" \
          [list $::cadence_compat $::autotrim_wires $::graph_use_ctrl_key [expr {[km_gf $vdrw] & 454}] [km_mk $vdrw]] \
          [list $km_cad0 $km_at0 $km_g0 0 0]
        rename km_editor {}
        foreach km_p {kc_cfacts kc_masks kc_guards kc_expect} { rename $km_p {} }
        set ::wviewer::cva($tok) 0
        wviewer::cursor_toggle $tok 1
        set ::wviewer::cvb($tok) 0
        wviewer::cursor_toggle $tok 2

        # --- KM6: two tabs, the ACTIVE tab's mode flips -------------------------
        # The plot mode is kept per tab. A second tab is opened (it becomes the
        # active one and starts in the mode of the tab it was opened from), the
        # real chord is sent there, and the first tab is looked at again.
        wviewer::set_plot_mode single $tok
        set km6_id0 [wviewer::tab_id $tok]
        set km6_n0 [wviewer::tab_count $tok]
        set km6_id1 [wviewer::new_tab $tok]
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        lassign [km_mid $vdrw 0] km6x km6y
        check "KM6 fixture: a second tab is open and active, in single mode like the first" \
          [list [expr {[wviewer::tab_count $tok] - $km6_n0}] \
                [expr {$km6_id1 ne {} && $km6_id1 ne $km6_id0 && [wviewer::tab_id $tok] eq $km6_id1}] \
                [wviewer::plot_mode $tok]] {1 1 single}
        set ::km_fwd {} ; set ::km_log {} ; set km_mb6 $::mb_hits
        km_key $vdrw M 5 $km6x $km6y
        set km6a [list [wviewer::plot_mode $tok] [km_status $vtop] $::km_log $::km_fwd [expr {$::mb_hits - $km_mb6}]]
        wviewer::select_tab $km6_id0 $tok
        for {set i 0} {$i < 5} {incr i} { update; after 20 }
        set km6b [list [expr {[wviewer::tab_id $tok] eq $km6_id0}] [wviewer::plot_mode $tok] [km_status $vtop]]
        wviewer::select_tab $km6_id1 $tok
        for {set i 0} {$i < 5} {incr i} { update; after 20 }
        set km6c [list [expr {[wviewer::tab_id $tok] eq $km6_id1}] [wviewer::plot_mode $tok] [km_status $vtop]]
        km_key $vdrw M 5 $km6x $km6y
        lappend km6c [wviewer::plot_mode $tok]
        check "KM6 with two tabs the chord flips the mode of the active tab: there it reads multi, the status bar follows, one line, nothing forwarded, no box; the first tab, looked at again, is still single; back in the second it is still multi, and a second press there gives single" \
          [list $km6a $km6b $km6c] \
          [list [list multi multi [list [list wviewer::set_plot_mode multi $tok]] {} 0] {1 single single} {1 multi multi single}]
        # ...and the GRAPH KEYS on the second tab (the other rows press them on
        # the first). The tab gets one strip with the fixture's trace. A real
        # bare b in the middle of every band is forwarded and toggles cursor B
        # (km_bwalk), and a real bare m on the trace, at a pixel scanned for on
        # this tab, is forwarded and makes one marker.
        wviewer::set_graphs $tok [list [dict replace [wviewer::empty_graph] traces [list $ca_t0]]]
        wviewer::regenerate $tok
        wviewer::fit $tok
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        xschem new_schematic switch $vdrw
        set km6_bb [ca_bands $vdrw]
        set km6_bw [km_bwalk $vdrw]
        lassign [km_mid $vdrw 0] km6x km6y
        set km6_on {}
        set km6_b0 [lindex $km6_bb 0]
        if {[llength $km6_b0] == 4} {
          for {set y [expr {int([lindex $km6_b0 1]) + 14}]} {$y < int([lindex $km6_b0 3]) - 14} {incr y} {
            if {[wb_at $vdrw 0 $km6x $y 3] >= 0} { set km6_on [list $km6x $y] ; break }
          }
        }
        set km6_m no-pixel-on-the-trace-so-not-pressed
        if {[llength $km6_on] == 2} {
          catch {wviewer::delete_all_markers_at $vdrw}
          set km6_m0 [km_mk $vdrw]
          set ::km_fwd {} ; set km_mb6m $::mb_hits
          km_key $vdrw m 0 {*}$km6_on
          set km6_m [list $::km_fwd [expr {[km_mk $vdrw] - $km6_m0}] [expr {$::mb_hits - $km_mb6m}]]
          catch {wviewer::delete_all_markers_at $vdrw}
        }
        check "KM6 the graph keys on the second tab: in the middle of every band bare b is forwarded and toggles cursor B, and bare m on the trace is forwarded and makes one marker (the second tab is the active one and not the first of the window; it has a band; per band: what the engine was handed, B on, B off again; for m: what the engine was handed, markers made, boxes; markers left)" \
          [list [expr {[wviewer::tab_id $tok] eq $km6_id1}] [expr {[wviewer::tab_index $tok] > 0}] \
                [expr {[llength $km6_bb] > 0}] $km6_bw $km6_m [km_mk $vdrw]] \
          [list 1 1 1 [km_bwant [llength $km6_bb]] {{{109 0}} 1 0} 0]
        catch {wviewer::close_tab $km6_id1 $tok}
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        wviewer::set_plot_mode single $tok
        lassign [km_mid $vdrw 0] kmx kmy
        check "KM6 fixture: the second tab is closed again, the first is the active one, single" \
          [list [expr {[wviewer::tab_count $tok] - $km6_n0}] [expr {[wviewer::tab_id $tok] eq $km6_id0}] [wviewer::plot_mode $tok]] \
          {0 1 single}

        # --- KM15: TWO VIEWER WINDOWS open at once ------------------------------
        # The other rows have one viewer. A second session is opened (the same
        # state under another view name) and its viewer with it: a second
        # toplevel, a second canvas, a second entry in the viewer's registry.
        # Both start in single mode. Then, in the first viewer and in the
        # second, each in its own canvas:
        #   * a real bare b in the middle of strip 0 goes to the engine through
        #     THAT canvas and toggles cursor B there (on, off again);
        #   * a real Ctrl-Shift-M flips the mode of THAT viewer: its mode and
        #     its status bar read multi, the other viewer's still single, one
        #     action-log line that names that viewer's token, nothing handed
        #     to the engine, no box. A second press flips it back.
        # The second viewer and its session are closed again afterwards.
        wviewer::set_plot_mode single $tok
        set km_tok2 [ase::session_key sky130_tests test_nfet_final km_second_viewer]
        set km_ss2 [file join $scratch km_session2.state]
        ase::state_save $km_ss2 $st
        ase::session_open $km_tok2 $km_ss2
        set km_win0 [llength [xschem windows]]
        set km_open2 [wviewer::open $km_tok2]
        set km_vtop2 [wviewer::window_for $km_tok2]
        set km_vdrw2 $km_vtop2.drw
        set km_rdy2 0
        if {$km_vtop2 ne {}} { set km_rdy2 [viewer_ready $km_vtop2] }
        for {set i 0} {$i < 15} {incr i} { update; after 20 }
        catch {wviewer::set_plot_mode single $km_tok2}
        check "KM15 fixture: a second viewer is open beside the first: its own toplevel and canvas, both canvases in the viewer's registry, each with a band, both in single mode" \
          [list $km_open2 $km_rdy2 [expr {$km_vtop2 ne {} && $km_vtop2 ne $vtop}] \
                [wviewer::token_for_canvas $vdrw] [wviewer::token_for_canvas $km_vdrw2] \
                [expr {[llength [ca_bands $vdrw]] > 0}] [expr {[llength [ca_bands $km_vdrw2]] > 0}] \
                [wviewer::plot_mode $tok] [wviewer::plot_mode $km_tok2]] \
          [list 1 1 1 $tok $km_tok2 1 1 single single]
        set km15 {}
        if {$km_rdy2} {
          foreach {km_w km_t} [list $vdrw $tok $km_vdrw2 $km_tok2] {
            lassign [km_mid $km_w 0] km_x15 km_y15
            set ::km_via {}
            km_key $km_w b 0 $km_x15 $km_y15
            set km_on1 [expr {[km_gf $km_w] & 4}]
            set km_v1 $::km_via
            if {$km_on1} { km_key $km_w b 0 $km_x15 $km_y15 }
            set km_b15 [list $km_v1 $km_on1 [expr {[km_gf $km_w] & 4}]]
            set ::km_fwd {} ; set ::km_log {} ; set km_mb15b $::mb_hits
            km_key $km_w M 5 $km_x15 $km_y15
            set km_c15 [list [wviewer::plot_mode $tok] [wviewer::plot_mode $km_tok2] \
                             [km_status $vtop] [km_status $km_vtop2] $::km_log $::km_fwd \
                             [expr {$::mb_hits - $km_mb15b}]]
            set ::km_log {}
            km_key $km_w M 5 $km_x15 $km_y15
            lappend km_c15 [wviewer::plot_mode $tok] [wviewer::plot_mode $km_tok2] $::km_log
            lappend km15 [list $km_b15 $km_c15]
          }
        }
        check "KM15 with two viewers open each takes its own keys: bare b in the middle of a strip goes to the engine through the canvas it was typed in and toggles cursor B there, and Ctrl-Shift-M flips the mode of the viewer it was typed in and of no other (per viewer, the first and then the second; for b: the canvas, keysym and state the engine was handed, B on, B off again; for the chord: the modes of the first and of the second viewer, their two status bars, the action-log lines, what the engine was handed, boxes; after a second press: the two modes, the lines)" \
          $km15 [list \
            [list [list [list [list $vdrw 98 0]] 4 0] \
                  [list multi single multi single [list [list wviewer::set_plot_mode multi $tok]] {} 0 \
                        single single [list [list wviewer::set_plot_mode single $tok]]]] \
            [list [list [list [list $km_vdrw2 98 0]] 4 0] \
                  [list single multi single multi [list [list wviewer::set_plot_mode multi $km_tok2]] {} 0 \
                        single single [list [list wviewer::set_plot_mode single $km_tok2]]]]]
        catch {wviewer::close $km_tok2}
        catch {ase::session_close $km_tok2}
        for {set i 0} {$i < 10} {incr i} { update; after 20 }
        xschem new_schematic switch $vdrw
        wviewer::set_plot_mode single $tok
        lassign [km_mid $vdrw 0] kmx kmy
        check "KM15 fixture: the second viewer is closed again: as many windows as before it, no toplevel of its own, its canvas out of the registry, the first viewer's context current, single" \
          [list [expr {[llength [xschem windows]] - $km_win0}] [wviewer::window_for $km_tok2] \
                [wviewer::token_for_canvas $km_vdrw2] [xschem get current_win_path] [wviewer::plot_mode $tok]] \
          [list 0 {} {} $vdrw single]

        # --- KM14, KM16 to KM22: A KEY THAT CAME THROUGH ANOTHER WINDOW (2026-11-22) --
        # doc/claude/specs/waveform_viewer.md, "A key that came through another
        # window". The engine runs a key in the CURRENT context, and the context
        # follows the pointer while the keyboard focus need not: with the focus
        # in a schematic window and the pointer resting in a viewer, a key used
        # to run in the viewer as the schematic command it is. KM14 held that as
        # a declared limit until this date; it now holds the opposite. Such a key
        # is the viewer's: its canvas's own bindings run for it (the filter, then
        # the WaveViewer tag), the focus and the context stay where they are, and
        # no editor verb runs. Two doors lead there from a schematic canvas and
        # both are pressed:
        #   * a key Tk delivers to the schematic canvas meets a binding tag that
        #     stands before the canvas's own bindings (wviewer::key_door);
        #   * the engine's event entry, called with the schematic canvas as the
        #     key's window, asks the same proc (callback(), src/callback.c).
        # A third door is the viewer's own toplevel, where an open leaves the
        # keyboard (wviewer::top_key): rows KM23 and KM18.
        #
        # HOW THE STATE IS BUILT (km_far). The pointer is MOVED FOR REAL, by a
        # warp: the server itself sends the crossing and motion events. It goes
        # out to the main window's canvas (the engine makes that window's
        # context current) and then into the viewer's plot (the engine makes the
        # viewer's context current and hands its canvas the focus). The keyboard
        # focus is then forced back onto the main window's canvas, which is what
        # Alt-Tab does with no pointer move. Nothing switches the context by
        # command. km_far answers the state it got (the focus window, the
        # current context, the window under the pointer, the pointer's pixel)
        # and every row puts the first three into what it checks, for each key
        # it sends. Where a row moves the pointer once more after km_far (the
        # status-bar legs) it reads the state again after that move and checks
        # that; the pre-flight of KM16 checks what its key did instead. (The
        # window the pointer is sent into is raised first, so that it is the
        # one there.)
        # HOW A KEY IS SENT (km_type). The key is GENERATED on the main window's
        # canvas, which has the focus; Tk delivers a generated key to the focus
        # window and runs that window's bindings. No suite can make the server
        # type a key, so these are Tk's events, not the server's: a probe with
        # real server-side keys measured the same on the day of the change.
        # KM14 and KM16 do not type a chord with Alt: this suite's main canvas
        # carries a probe binding for every Alt key (the G1s leg's), which on a
        # product without the canvas door answers in the key's place. Those
        # chords go to the engine's event entry with the main canvas as their
        # window (km_eng), the second door. KM19 does type its events with Alt
        # on the main canvas, once it has seen the canvas door take a key
        # there, and counts the runs of that probe binding, which must be none.
        proc km_pump {n} { for {set i 0} {$i < $n} {incr i} { update ; after 15 } }
        proc km_warp {w px py} {
          event generate $w <Motion> -warp 1 -x $px -y $py
          km_pump 6
        }
        proc km_far {fw vdrw px py} {
          raise . ; update
          km_warp .drw 60 60
          raise [winfo toplevel $vdrw] ; update
          km_warp $vdrw $px $py
          for {set i 0} {$i < 100} {incr i} {
            focus -force $fw ; update
            if {[focus -displayof $fw] eq $fw} { break }
            after 50
          }
          km_pump 2
          return [list [focus -displayof $fw] [::km_real_xschem get current_win_path] \
                       [winfo containing -displayof $vdrw {*}[winfo pointerxy $vdrw]] \
                       [list [expr {[winfo pointerx $vdrw] - [winfo rootx $vdrw]}] \
                             [expr {[winfo pointery $vdrw] - [winfo rooty $vdrw]}]]]
        }
        proc km_type {fw ks st {type KeyPress}} {
          event generate $fw <$type> -keysym $ks -state $st -x 40 -y 40
          update
        }
        proc km_eng {N st} {
          xschem callback .drw 2 40 40 $N 0 0 $st
          update
          xschem callback .drw 3 40 40 $N 0 0 $st
          update
        }
        # the pointer the current context stores (schematic units)
        proc km_stored {} { return [list [::km_real_xschem get mousex] [::km_real_xschem get mousey]] }
        # where the real pointer was before the band moved it; it is put back
        set km_ptr0 [winfo pointerxy .]

        # The main canvas of this suite carries a probe binding for every Alt
        # key (the G1s leg's). Its command exists for this band as a counter:
        # in the state of these rows the canvas door stands before it, and it
        # must not run.
        set ::km_altprobe 0
        proc ::wvtest_alt_arm_probe {} { incr ::km_altprobe }

        # --- KM14: the chord, by both doors, and its release ---------------------
        set km_tag no-such-tag
        catch {set km_tag [wviewer::key_door_tag]}
        check "KM14 fixture: the main window's canvas carries the key-door tag first in its tag list; the viewer's canvas does not carry it, and its own tag is still followed by WaveViewer" \
          [list [expr {[lindex [bindtags .drw] 0] eq $km_tag}] [lsearch -exact [bindtags $vdrw] $km_tag] \
                [lindex [bindtags $vdrw] [expr {[lsearch -exact [bindtags $vdrw] $vdrw] + 1}]]] \
          {1 -1 WaveViewer}
        wviewer::set_plot_mode single $tok
        set km14s [km_far .drw $vdrw $kmx $kmy]
        set km14p0 [km_stored]
        set ::km_via {} ; set ::km_log {} ; set km_mb14 $::mb_hits ; set km_k14 $::kf_calls ; set ::kf_at {}
        km_type .drw M 5
        set km14 [list $km14s $::km_via [expr {$::kf_calls - $km_k14}] $::kf_last $::kf_at \
                       [expr {$::mb_hits - $km_mb14}] [wviewer::plot_mode $tok] [km_status $vtop] $::km_log \
                       [::km_real_xschem get current_win_path] [focus -displayof .drw] \
                       [expr {[km_stored] eq $km14p0}]]
        check "KM14 with the keyboard focus on the main window's canvas and the pointer in the viewer's plot, a Ctrl-Shift-M typed there is the viewer's: its key filter gets it at the pointer's pixel, the plot mode flips, the status bar follows, one action-log line, no message box, and the engine is handed nothing; the focus, the context and the pointer the viewer's context stores stay as they were (the state: focus window, current context, window under the pointer, the pointer's pixel in the plot; what the engine was handed; calls of the filter, the event it got, its canvas, pixel and keysym name; boxes; the mode; the status bar; the log lines; the context and the focus after; the stored pointer unmoved)" \
          $km14 [list [list .drw $vdrw $vdrw [list $kmx $kmy]] {} 1 {2 77 5} [list $vdrw $kmx $kmy M] \
                      0 multi multi [list [list wviewer::set_plot_mode multi $tok]] $vdrw .drw 1]
        set km_k14 $::kf_calls ; set ::km_log {} ; set ::km_via {} ; set ::km_rel {}
        km_type .drw M 5 KeyRelease
        check "KM14 ...the release follows its press: the filter gets it as a release, nothing more happens, and the engine is not handed it at all (calls of the filter, the event it got, the mode, log lines, boxes since the press, the presses and the releases the engine was handed, the stored pointer unmoved)" \
          [list [expr {$::kf_calls - $km_k14}] $::kf_last [wviewer::plot_mode $tok] $::km_log \
                [expr {$::mb_hits - $km_mb14}] $::km_via $::km_rel [expr {[km_stored] eq $km14p0}]] \
          [list 1 {3 77 5} multi {} 0 {} {} 1]
        # the engine's door: its event entry called with the main canvas as the
        # key's window, press then release, in the same state built again
        wviewer::set_plot_mode single $tok
        set km14s [km_far .drw $vdrw $kmx $kmy]
        set km14p0 [km_stored]
        set ::km_via {} ; set ::km_log {} ; set km_mb14 $::mb_hits ; set km_k14 $::kf_calls ; set ::kf_at {}
        xschem callback .drw 2 40 40 77 0 0 5
        update
        set km14e [list $km14s $::km_via [expr {$::kf_calls - $km_k14}] $::kf_last $::kf_at \
                        [expr {$::mb_hits - $km_mb14}] [wviewer::plot_mode $tok] [km_status $vtop] $::km_log]
        xschem callback .drw 3 40 40 77 0 0 5
        update
        lappend km14e [expr {$::kf_calls - $km_k14}] $::kf_last [wviewer::plot_mode $tok] \
                      [::km_real_xschem get current_win_path] [focus -displayof .drw] [expr {[km_stored] eq $km14p0}]
        check "KM14 ...and the engine's own event entry, called with the main canvas as the key's window while the viewer's context is current and the pointer is in the plot, hands the key to the viewer the same way: press, then release (the state; what the entry was called with; calls of the filter after the press, the event it got, its canvas, pixel and keysym name; boxes; the mode; the status bar; the log lines; after the release: calls of the filter, the event it got, the mode; the context, the focus, the stored pointer unmoved)" \
          $km14e [list [list .drw $vdrw $vdrw [list $kmx $kmy]] {{.drw 77 5}} 1 {2 77 5} [list $vdrw $kmx $kmy M] \
                       0 multi multi [list [list wviewer::set_plot_mode multi $tok]] \
                       2 {3 77 5} multi $vdrw .drw 1]
        # Caps Lock: with it on, Control-m is the chord (the tag's Caps Lock
        # dispatch, which is handed the event's keysym name and state)
        wviewer::set_plot_mode single $tok
        set km14s [km_far .drw $vdrw $kmx $kmy]
        set ::km_via {} ; set ::km_log {} ; set km_mb14 $::mb_hits
        km_type .drw m 6
        km_type .drw m 6 KeyRelease
        check "KM14 ...with Caps Lock on, a Control-m typed there is the chord as well: the tag's Caps Lock dispatch runs and the mode flips (the state, the last event the filter got, the mode, the log lines, what the engine was handed, boxes)" \
          [list [lrange $km14s 0 2] $::kf_last [wviewer::plot_mode $tok] $::km_log $::km_via [expr {$::mb_hits - $km_mb14}]] \
          [list [list .drw $vdrw $vdrw] {3 77 6} multi [list [list wviewer::set_plot_mode multi $tok]] {} 0]
        # a key with no keysym name (the engine hands over an empty name for
        # one): Tk gives a binding ?? for it, and so does the viewer's side. The
        # proc is called as the engine calls it; a background error is recorded
        # for the leg instead of raised.
        set km14s [km_far .drw $vdrw $kmx $kmy]
        set ::km_bg {}
        set km_bg0 [interp bgerror {}]
        proc ::km_bgerr {msg opts} { lappend ::km_bg $msg }
        interp bgerror {} ::km_bgerr
        set ::kf_at {} ; set km_k14 $::kf_calls ; set km_e14 $::kf_errs
        set km_fk [list [catch {wviewer::foreign_key $vdrw 2 99999999 {} 0} km_r] $km_r]
        km_pump 4
        interp bgerror {} $km_bg0
        rename ::km_bgerr {}
        check "KM14 ...a key the engine has no keysym name for is handed to the filter with ?? for the name, as Tk hands it to a binding, and raises nothing (the state, the proc's answer, calls of the filter, the name it got, filter errors, background errors)" \
          [list [lrange $km14s 0 2] $km_fk [expr {$::kf_calls - $km_k14}] [lindex $::kf_at 3] \
                [expr {$::kf_errs - $km_e14}] $::km_bg] \
          [list [list .drw $vdrw $vdrw] {0 1} 1 ?? 0 {}]
        # the pointer anywhere in the viewer's window: on its status bar, below
        # the plot, with the viewer's context still the current one
        wviewer::set_plot_mode single $tok
        km_far .drw $vdrw $kmx $kmy
        set km_sb $vtop.wvstatus.l
        km_warp $km_sb 20 4
        set km14s [list [focus -displayof .drw] [::km_real_xschem get current_win_path] \
                        [winfo containing -displayof $vdrw {*}[winfo pointerxy $vdrw]]]
        set ::km_via {} ; set ::km_log {} ; set km_mb14 $::mb_hits ; set ::kf_at {}
        km_type .drw M 5
        km_type .drw M 5 KeyRelease
        check "KM14 ...and with the pointer on the viewer's status bar, below the plot, the chord typed on the main canvas flips the mode the same way; the filter is handed a pixel below the plot (the state, the mode, the log lines, what the engine was handed, boxes, the filter's pixel at or below the canvas's height)" \
          [list $km14s [wviewer::plot_mode $tok] $::km_log $::km_via [expr {$::mb_hits - $km_mb14}] \
                [expr {[llength $::kf_at] == 4 && [lindex $::kf_at 2] >= [winfo height $vdrw]}]] \
          [list [list .drw $vdrw $km_sb] multi [list [list wviewer::set_plot_mode multi $tok]] {} 0 1]
        wviewer::set_plot_mode single $tok
        # THE TAGS BEHIND WaveViewer are not run for the viewer. The viewer's
        # canvas carries `all` behind its own tags, and `all` binds F10: it
        # posts the first menu of the window's menubar and takes a grab. Typed
        # on the main canvas in the state of this row, F10 reaches the filter
        # and goes no further: nothing holds a grab, the focus stays. A menu a
        # product has posted all the same is taken down again (the posted menu
        # is the window that has the focus then).
        set km14s [km_far .drw $vdrw $kmx $kmy]
        set ::km_via {} ; set km_k14 $::kf_calls
        km_type .drw F10 0
        km_type .drw F10 0 KeyRelease
        km_pump 4
        set km_f10 [list [lrange $km14s 0 2] [expr {$::kf_calls - $km_k14}] $::km_via [grab current] \
                         [focus -displayof .drw] [expr {[bind all <Key-F10>] ne {}}]]
        set km_g10 [grab current]
        if {$km_g10 ne {}} {
          set km_m10 [focus -displayof .drw]
          if {$km_m10 ne {} && [winfo class $km_m10] eq {Menu}} { catch {tk::MenuUnpost $km_m10} }
          catch {$km_g10 postcascade none}
          catch {grab release $km_g10}
          update
        }
        focus -force .drw
        update
        check "KM14 ...a key that a tag behind WaveViewer binds goes no further than the viewer's own tags: F10, which `all` binds to post a menubar's first menu, typed on the main canvas in that state reaches the filter and posts nothing in either window (the state, calls of the filter for press and release, what the engine was handed, the window holding a grab, the focus after, and that `all` binds the key)" \
          $km_f10 [list [list .drw $vdrw $vdrw] 2 {} {} .drw 1]
        # AN ERROR IN A BINDING STOPS THE KEY, as it does when Tk delivers it.
        # A binding of the row's own on the first tag of the viewer's canvas,
        # which stands before the canvas's own tag and its filter, raises an
        # error for F7. Tk is asked first, with the focus on the viewer's
        # canvas: the filter is not called and the error goes to the
        # background handler. Then the viewer's side, called as the engine
        # calls it in the state of this row: the same two answers.
        set km_etag [lindex [bindtags $vdrw] 0]
        set km_ebind [bind $km_etag <Key-F7>]
        bind $km_etag <Key-F7> {error km-boom}
        set ::km_bg {}
        set km_bg0 [interp bgerror {}]
        proc ::km_bgerr {msg opts} { lappend ::km_bg $msg }
        interp bgerror {} ::km_bgerr
        for {set i 0} {$i < 100} {incr i} {
          focus -force $vdrw ; update
          if {[focus -displayof $vdrw] eq $vdrw} { break }
          after 50
        }
        set km_k14 $::kf_calls
        event generate $vdrw <KeyPress> -keysym F7 -x $kmx -y $kmy
        update
        km_pump 4
        set km_err [list [expr {$km_etag ne $vdrw}] [focus -displayof $vdrw] [expr {$::kf_calls - $km_k14}] $::km_bg]
        set km14s [km_far .drw $vdrw $kmx $kmy]
        set ::km_bg {} ; set km_k14 $::kf_calls
        lappend km_err [lrange $km14s 0 2] [list [catch {wviewer::foreign_key $vdrw 2 65476 F7 0} km_r] $km_r] \
                       [expr {$::kf_calls - $km_k14}]
        km_pump 4
        lappend km_err $::km_bg
        interp bgerror {} $km_bg0
        rename ::km_bgerr {}
        bind $km_etag <Key-F7> $km_ebind
        check "KM14 ...an error in a binding stops the key there, by the viewer's side as by Tk: with a binding of the row's own that raises an error on the first tag of the viewer's canvas, the filter behind it is not called and the error goes to the background handler once (the tag is not the canvas's own; Tk's half: the focus on the viewer's canvas, calls of the filter, background errors; the viewer's side: the state, the proc's answer, calls of the filter, background errors)" \
          $km_err [list 1 $vdrw 0 {km-boom} [list .drw $vdrw $vdrw] {0 1} 0 {km-boom}]
        # THE POINTER DECIDES. The viewer's context current (made so by command:
        # a viewer that has just opened leaves it so without the pointer in it),
        # the focus on the main canvas and the pointer over the main canvas: the
        # key is not the viewer's. Both doors ask, the viewer declines, and the
        # engine gets the key as it always did. The key is the left Shift key,
        # which the engine has no use for.
        raise . ; update
        km_warp .drw 60 60
        for {set i 0} {$i < 100} {incr i} {
          focus -force .drw ; update
          if {[focus -displayof .drw] eq {.drw}} { break }
          after 50
        }
        xschem new_schematic switch $vdrw
        set ::km_via {} ; set km_k14 $::kf_calls
        km_type .drw Shift_L 0
        km_type .drw Shift_L 1 KeyRelease
        check "KM14 ...the pointer decides: with the viewer's context current, the focus on the main canvas and the pointer over the main canvas, a key typed there is not the viewer's: its filter is not called and the engine gets the key through the main canvas (the context, the window under the pointer, calls of the filter, what the engine was handed)" \
          [list [::km_real_xschem get current_win_path] [winfo containing {*}[winfo pointerxy .]] \
                [expr {$::kf_calls - $km_k14}] $::km_via] \
          [list $vdrw .drw 0 {{.drw 65505 0}}]

        # --- KM16: the editor keys do nothing --------------------------------------
        # The keys that ran an editor verb in a viewer from this state, stock
        # profile then Cadence. Typed on the main canvas: w (the wire), y (it
        # flips enable_stretch, a global), i (the canvas's own binding for it,
        # cadence_style_rc's line, which this suite puts on the main canvas: it
        # places an instance and never calls the engine), and in the Cadence
        # profile s (the snapped wire) and bare b. Through the engine's entry:
        # Alt-b (it steps hide-symbols). Each is sent with the pointer in the
        # middle of strip 0, s and b two pixels inside the strip's top edge,
        # where they are no graph key either (in the middle they are the
        # graph's: row KM17). Each press and its release must reach the viewer's
        # filter and nothing else: no message box, no Save form, no window, no
        # wire, no instance, the two globals and the engine's state unmoved.
        # Then the three that open something once the engine runs them: Alt-s
        # (a reload prompt), Control-Alt-s (the Save-as-symbol form) and
        # Control-Alt-t (a new schematic), through the engine's entry. They are
        # sent only when a key the engine has no use for (the left Shift key),
        # sent the same way, was seen to reach the viewer's filter in this state.
        # On a product that still runs such a key in the viewer they are not
        # sent, and the row says so and fails.
        proc km_edstate {vdrw tok} {
          return [list [km_snap $vdrw $tok] [::km_real_xschem get wires] [::km_real_xschem get instances] \
                       [toplevel_count] $::km_sacd $::enable_stretch]
        }
        set km16 {}
        set km16_want {}
        set km_cad0 $::cadence_compat
        set km_at0 $::autotrim_wires
        set km_hs16 $::hide_symbols
        set km_es16 $::enable_stretch
        set km_ring [list $kmx [expr {int([lindex [lindex [ca_bands $vdrw] 0] 1]) + 2}]]
        foreach km_prof {0 1} {
          set ::cadence_compat $km_prof
          set km_fam {w w 0 mid tk y y 0 mid tk i i 0 mid tk Alt-b 98 8 mid eng}
          if {$km_prof} { lappend km_fam s s 0 ring tk b b 0 ring tk }
          set km_dng {Alt-s 115 8 mid eng Ctrl-Alt-s 115 12 mid eng Ctrl-Alt-t 116 12 mid eng}
          foreach {km_nm km_ks km_st km_at km_door} [concat $km_fam $km_dng] {
            lappend km16_want [list $km_prof $km_nm [list .drw $vdrw $vdrw] 2 0 \
                                    [expr {$km_door eq {eng} ? [list [list .drw $km_ks $km_st]] : {}}] 1]
          }
          # the pre-flight for the three that open something
          km_far .drw $vdrw $kmx $kmy
          set km_k16 $::kf_calls
          km_eng 65505 0
          if {$::kf_calls - $km_k16 == 2} {
            set km_fam [concat $km_fam $km_dng]
          } else {
            lappend km16 [list $km_prof not-sent {Alt-s Ctrl-Alt-s Ctrl-Alt-t}]
          }
          foreach {km_nm km_ks km_st km_at km_door} $km_fam {
            if {$km_at eq {ring}} { set km_s16 [km_far .drw $vdrw {*}$km_ring] } else { set km_s16 [km_far .drw $vdrw $kmx $kmy] }
            set km_e0 [km_edstate $vdrw $tok]
            set ::km_via {} ; set km_mb16 $::mb_hits ; set km_k16 $::kf_calls
            if {$km_door eq {eng}} {
              km_eng $km_ks $km_st
            } else {
              km_type .drw $km_ks $km_st
              km_type .drw $km_ks $km_st KeyRelease
            }
            lappend km16 [list $km_prof $km_nm [lrange $km_s16 0 2] [expr {$::kf_calls - $km_k16}] \
                               [expr {$::mb_hits - $km_mb16}] $::km_via [expr {[km_edstate $vdrw $tok] eq $km_e0}]]
            # put back whatever a product that ran the key has moved
            catch {::km_real_xschem abort_operation}
            catch {::km_real_xschem set hide_symbols $km_hs16}
            set ::hide_symbols $km_hs16
            set ::enable_stretch $km_es16
          }
        }
        set ::cadence_compat $km_cad0
        set ::autotrim_wires $km_at0
        rename km_edstate {}
        check "KM16 from the same state the editor keys do nothing in the viewer, stock profile then Cadence: typed on the main canvas w, y and i (a binding of the main canvas itself) and in the Cadence profile s and b two pixels inside the strip's edge; through the engine's entry Alt-b, and then Alt-s, Control-Alt-s and Control-Alt-t, which are sent only once a key was seen to reach the viewer's filter that way (per key: the profile, the key, the state it was sent in, calls of the filter for press and release, boxes, what the engine's entry was called with, and whether mode, graph flags, engine state, read-only flag, hide-symbols, windows, rects, markers, cursors, view, wires, instances, toplevels, Save forms and enable_stretch are all as before); the profile is back" \
          [list $km16 [list $::cadence_compat $::autotrim_wires]] [list $km16_want [list $km_cad0 $km_at0]]

        # --- KM17: the graph keys act on the graph --------------------------------
        # From the same state, stock profile then Cadence: a bare b in the middle
        # of strip 0 is handed to the engine through the VIEWER's canvas and
        # toggles cursor B (on, and off again); a bare m on a trace makes one
        # marker; no message box. In the Cadence profile plain s goes to the
        # engine as Control-s (the cursor swap), as it does with the focus on
        # the plot.
        # And the same b by the ENGINE's door: the engine's event entry is
        # called with the main canvas as the key's window, hands the key to
        # the viewer's side, and the filter hands it back to the engine with
        # the viewer's canvas as its window. That second call is made from
        # inside the first, and the engine runs a graph key only when it is not
        # already busy with another event: cursor B must toggle all the same,
        # on and off again.
        # The state each key was sent in is part of the row: a key sent with
        # the focus anywhere but on the main canvas would reach the viewer by
        # plain delivery and prove nothing about the doors.
        set km17_on {}
        set km17_b0 [lindex [ca_bands $vdrw] 0]
        if {[llength $km17_b0] == 4} {
          for {set y [expr {int([lindex $km17_b0 1]) + 14}]} {$y < int([lindex $km17_b0 3]) - 14} {incr y} {
            if {[wb_at $vdrw 0 $kmx $y 3] >= 0} { set km17_on [list $kmx $y] ; break }
          }
        }
        set km17 {}
        set km17_want {}
        foreach km_prof {0 1} {
          set ::cadence_compat $km_prof
          set km_mb17 $::mb_hits
          set km_st17 {}
          set km_sw17 {}
          lappend km_st17 [lrange [km_far .drw $vdrw $kmx $kmy] 0 2] ; lappend km_sw17 [list .drw $vdrw $vdrw]
          set ::km_via {}
          km_type .drw b 0 ; km_type .drw b 0 KeyRelease
          set km_v1 $::km_via
          set km_on1 [expr {[km_gf $vdrw] & 4}]
          lappend km_st17 [lrange [km_far .drw $vdrw $kmx $kmy] 0 2] ; lappend km_sw17 [list .drw $vdrw $vdrw]
          km_type .drw b 0 ; km_type .drw b 0 KeyRelease
          set km_on2 [expr {[km_gf $vdrw] & 4}]
          # the engine's door
          lappend km_st17 [lrange [km_far .drw $vdrw $kmx $kmy] 0 2] ; lappend km_sw17 [list .drw $vdrw $vdrw]
          set ::km_via {}
          km_eng 98 0
          set km_e17 [list $::km_via [expr {[km_gf $vdrw] & 4}]]
          lappend km_st17 [lrange [km_far .drw $vdrw $kmx $kmy] 0 2] ; lappend km_sw17 [list .drw $vdrw $vdrw]
          km_eng 98 0
          lappend km_e17 [expr {[km_gf $vdrw] & 4}]
          set km_m17 no-pixel-on-the-trace-so-not-typed
          if {[llength $km17_on] == 2} {
            catch {wviewer::delete_all_markers_at $vdrw}
            set km_mk0 [km_mk $vdrw]
            lappend km_st17 [lrange [km_far .drw $vdrw {*}$km17_on] 0 2] ; lappend km_sw17 [list .drw $vdrw $vdrw]
            set ::km_via {}
            km_type .drw m 0 ; km_type .drw m 0 KeyRelease
            set km_m17 [list $::km_via [expr {[km_mk $vdrw] - $km_mk0}]]
            catch {wviewer::delete_all_markers_at $vdrw}
          }
          set km_s17 {}
          if {$km_prof} {
            lappend km_st17 [lrange [km_far .drw $vdrw $kmx $kmy] 0 2] ; lappend km_sw17 [list .drw $vdrw $vdrw]
            set ::km_via {}
            km_type .drw s 0 ; km_type .drw s 0 KeyRelease
            set km_s17 $::km_via
          }
          lappend km17 [list $km_prof $km_st17 $km_v1 $km_on1 $km_on2 $km_e17 $km_m17 $km_s17 [expr {$::mb_hits - $km_mb17}]]
          lappend km17_want [list $km_prof $km_sw17 [list [list $vdrw 98 0]] 4 0 \
                                  [list [list [list .drw 98 0] [list $vdrw 98 0]] 4 0] \
                                  [list [list [list $vdrw 109 0]] 1] \
                                  [expr {$km_prof ? [list [list $vdrw 115 4]] : {}}] 0]
        }
        set ::cadence_compat $km_cad0
        set ::autotrim_wires $km_at0
        check "KM17 from the same state the graph keys act on the graph, stock profile then Cadence: a bare b in the middle of strip 0 goes to the engine through the viewer's canvas and toggles cursor B; the same b handed to the engine's own event entry with the main canvas as its window comes back through the viewer's canvas and toggles it as well; a bare m on the trace makes one marker; and in the Cadence profile plain s goes to the engine as Control-s (per profile: the state each key was sent in, focus window, context and window under the pointer; what the engine was handed for the typed b, B on, B off again; for the b by the engine's entry: what the engine was handed, B on, B off again; for m: what the engine was handed and the markers made; what it was handed for s; boxes); the profile is back and no marker is left" \
          [list $km17 [list $::cadence_compat $::autotrim_wires] [km_mk $vdrw]] [list $km17_want [list $km_cad0 $km_at0] 0]

        # --- KM23: the viewer window's OWN door (2026-11-22, the repair) ---------
        # wviewer::open leaves the keyboard focus inside a viewer on the viewer's
        # TOPLEVEL (row G1f), where no key is bound: until this date a key typed
        # then did nothing. Such a key is now the viewer's while the pointer is
        # over the plot (wviewer::top_key, behind a binding tag the toplevel
        # carries first), and nobody's otherwise, as before. The state is built
        # as in the rows above, with the focus forced onto the viewer's
        # toplevel instead of the main canvas; the keys are generated on the
        # toplevel, which has the focus. Legs:
        #   * Ctrl-Shift-M: the filter gets it at the pointer's pixel, the mode
        #     flips, one log line, no box, the engine is handed nothing; the
        #     focus stays on the toplevel and the context where it was. Its
        #     release reaches the filter as a release.
        #   * a bare b in the middle of strip 0 goes to the engine through the
        #     viewer's canvas and toggles cursor B, on and off again.
        #   * F10, which `all` binds: the filter gets it, and Tk then goes on
        #     with the toplevel's own tags as it did before there was a door,
        #     so the viewer's own menubar takes the grab. (From a schematic
        #     canvas the same key posts nothing: row KM14.) The menu is taken
        #     down again.
        #   * the pointer on the viewer's status bar, inside the window but not
        #     over the plot: the chord does nothing. This door is narrower than
        #     the canvas door on purpose (the comment on wviewer::top_key).
        #   * the pointer over the main canvas: e, u and Control-d, which are
        #     shortcuts of the viewer's tag (Delete Empty Strips, Undo, Clear
        #     All), do nothing: the filter is not called, no log line, the
        #     viewer's layout as it was. These are the keys a user types on
        #     into the schematic after an open or a raise took the keyboard.
        wviewer::set_plot_mode single $tok
        set km23 {}
        set km23s [km_far $vtop $vdrw $kmx $kmy]
        set ::km_via {} ; set ::km_log {} ; set km_mb23 $::mb_hits ; set km_k23 $::kf_calls ; set ::kf_at {}
        km_type $vtop M 5
        lappend km23 [list [lrange $km23s 0 2] $::km_via [expr {$::kf_calls - $km_k23}] $::kf_last $::kf_at \
                           [expr {$::mb_hits - $km_mb23}] [wviewer::plot_mode $tok] [km_status $vtop] $::km_log \
                           [::km_real_xschem get current_win_path] [focus -displayof $vtop]]
        set km_k23 $::kf_calls ; set ::km_log {} ; set ::km_rel {}
        km_type $vtop M 5 KeyRelease
        lappend km23 [list [expr {$::kf_calls - $km_k23}] $::kf_last [wviewer::plot_mode $tok] $::km_log $::km_via $::km_rel]
        wviewer::set_plot_mode single $tok
        set km23b {}
        foreach km_leg {on off} {
          set km23s [km_far $vtop $vdrw $kmx $kmy]
          set ::km_via {}
          km_type $vtop b 0 ; km_type $vtop b 0 KeyRelease
          lappend km23b [list [lrange $km23s 0 2] $::km_via [expr {[km_gf $vdrw] & 4}]]
        }
        lappend km23 $km23b
        set km23s [km_far $vtop $vdrw $kmx $kmy]
        set km_k23 $::kf_calls
        km_type $vtop F10 0
        km_pump 4
        set km_g23 [grab current]
        lappend km23 [list [lrange $km23s 0 2] [expr {$::kf_calls - $km_k23}] \
                           [expr {$km_g23 ne {} && [winfo class $km_g23] eq {Menu} && [winfo toplevel $km_g23] eq $vtop}]]
        if {$km_g23 ne {}} {
          set km_m23 [focus -displayof $vtop]
          if {$km_m23 ne {} && [winfo class $km_m23] eq {Menu}} { catch {tk::MenuUnpost $km_m23} }
          catch {$km_g23 postcascade none}
          catch {grab release $km_g23}
          update
        }
        km_type $vtop F10 0 KeyRelease
        km_far $vtop $vdrw $kmx $kmy
        km_warp $vtop.wvstatus.l 20 4
        set km23s [list [focus -displayof $vtop] [::km_real_xschem get current_win_path] \
                        [winfo containing -displayof $vdrw {*}[winfo pointerxy $vdrw]]]
        set ::km_via {} ; set ::km_log {} ; set km_k23 $::kf_calls
        km_type $vtop M 5 ; km_type $vtop M 5 KeyRelease
        lappend km23 [list $km23s [expr {$::kf_calls - $km_k23}] [wviewer::plot_mode $tok] $::km_log $::km_via]
        wviewer::set_plot_mode single $tok
        raise . ; update
        km_warp .drw 60 60
        for {set i 0} {$i < 100} {incr i} {
          focus -force $vtop ; update
          if {[focus -displayof $vtop] eq $vtop} { break }
          after 50
        }
        km_pump 2
        set km23s [list [focus -displayof $vtop] [::km_real_xschem get current_win_path] \
                        [winfo containing -displayof $vdrw {*}[winfo pointerxy $vdrw]]]
        set km_l23 [wviewer::layout_for $tok]
        set ::km_via {} ; set ::km_log {} ; set km_k23 $::kf_calls ; set km_mb23 $::mb_hits
        foreach {km_ks km_st} {e 0 u 0 d 4} {
          km_type $vtop $km_ks $km_st ; km_type $vtop $km_ks $km_st KeyRelease
        }
        lappend km23 [list $km23s [expr {$::kf_calls - $km_k23}] $::km_log $::km_via [expr {$::mb_hits - $km_mb23}] \
                           [expr {[wviewer::layout_for $tok] eq $km_l23}]]
        check "KM23 a key typed while the viewer's own toplevel holds the keyboard, which is where an open leaves it, is the viewer's while the pointer is over the plot and nobody's otherwise: Ctrl-Shift-M reaches the filter at the pointer's pixel and flips the mode, its release follows, a bare b toggles cursor B through the viewer's canvas, and F10 reaches the filter and then posts the viewer's own menu, as it did before there was a door; with the pointer on the viewer's status bar the chord does nothing; with the pointer over the main canvas e, u and Control-d do nothing (the chord: the state, focus window, context and window under the pointer; what the engine was handed; calls of the filter, the event it got, its canvas, pixel and keysym name; boxes; the mode; the status bar; the log lines; the context and the focus after. The release: calls of the filter, the event it got, the mode, log lines, presses and releases the engine was handed. b twice: the state, what the engine was handed, cursor B. F10: the state, calls of the filter, a menu of the viewer's own window holds the grab. The status bar: the state, calls of the filter, the mode, log lines, what the engine was handed. Over the main canvas: the state, calls of the filter, log lines, what the engine was handed, boxes, the viewer's layout as before)" \
          $km23 [list [list [list $vtop $vdrw $vdrw] {} 1 {2 77 5} [list $vdrw $kmx $kmy M] 0 multi multi \
                            [list [list wviewer::set_plot_mode multi $tok]] $vdrw $vtop] \
                      [list 1 {3 77 5} multi {} {} {}] \
                      [list [list [list $vtop $vdrw $vdrw] [list [list $vdrw 98 0]] 4] \
                            [list [list $vtop $vdrw $vdrw] [list [list $vdrw 98 0]] 0]] \
                      [list [list $vtop $vdrw $vdrw] 1 1] \
                      [list [list $vtop $vdrw $vtop.wvstatus.l] 0 single {} {}] \
                      [list [list $vtop .drw .drw] 0 {} {} 0 1]]
        # back to the state the rows below start from
        raise $vtop ; update
        km_warp $vdrw $kmx $kmy

        # --- KM18, KM20: a viewer that has just opened; two viewers -------------
        # A second viewer is opened (a second session, as in KM15) while the
        # focus is on the main window's canvas, and nothing clicks in it.
        #   KM18 The open leaves the focus inside the viewer on its toplevel
        #        (Tk's own record, which does not wait for the window manager)
        #        and asks for it plainly: every call of `focus` made during
        #        the open is recorded, and the calls that name the viewer's
        #        toplevel are one, without -force. With the pointer still over
        #        the main canvas, u, e and Control-d (shortcuts of the viewer's
        #        tag) typed where the display left the keyboard do nothing in
        #        the viewer: the filter is not called, no log line, the layout
        #        as it was. They are sent only when the display gave the
        #        keyboard to the new viewer; left in the main canvas they
        #        would run in the viewer's context as editor keys, which is
        #        the limit the spec declares, and the row prints a skip line.
        #        The pointer is then moved into the new plot, and Ctrl-Shift-M
        #        is typed in the window that has the keyboard, whichever one
        #        this display gave it to: the new viewer's mode flips. Then
        #        the other focus state: the focus forced onto the main canvas,
        #        the same chord flips it back. Then the open that only raises
        #        a viewer, as auto-plot asks for it after a run: the viewer's
        #        own focus put on its plot canvas (where a click leaves it),
        #        the pointer and the keyboard on the main canvas, a second
        #        open of the same token. It takes the viewer's focus back to
        #        the toplevel, by one plain call, and the same three keys typed
        #        where the display left the keyboard do nothing in the viewer.
        #   KM20 With both viewers open and the focus on the main canvas, the
        #        chord goes to the viewer the pointer is in, the first and then
        #        the second, and to no other. And the control: with the pointer
        #        over the main canvas and the focus there, y flips
        #        enable_stretch as it always did, through the main canvas, with
        #        one viewer open (asked first) and with two.
        proc km_ctl {} {
          # pointer and focus on the main canvas; y; the context, what the
          # engine was handed, whether enable_stretch flipped, calls of the
          # viewer's filter
          raise . ; update
          km_warp .drw 60 60
          for {set i 0} {$i < 100} {incr i} {
            focus -force .drw ; update
            if {[focus -displayof .drw] eq {.drw}} { break }
            after 50
          }
          set es0 $::enable_stretch
          set ::km_via {} ; set k0 $::kf_calls
          km_type .drw y 0 ; km_type .drw y 0 KeyRelease
          set r [list [::km_real_xschem get current_win_path] $::km_via \
                      [expr {$::enable_stretch != $es0}] [expr {$::kf_calls - $k0}]]
          set ::enable_stretch $es0
          return $r
        }
        set km20_one [km_ctl]
        wviewer::set_plot_mode single $tok
        set km_tok3 [ase::session_key sky130_tests test_nfet_final km_third_viewer]
        set km_ss3 [file join $scratch km_session3.state]
        ase::state_save $km_ss3 $st
        ase::session_open $km_tok3 $km_ss3
        set km_win18 [llength [xschem windows]]
        raise . ; update
        km_warp .drw 60 60
        focus -force .drw ; update
        # every call of `focus` while an open runs, for the row
        proc km_open_rec {tk} {
          set ::km_focus {}
          rename ::focus ::km_real_focus
          proc ::focus {args} { lappend ::km_focus $args ; return [uplevel 1 [list ::km_real_focus {*}$args]] }
          set c [catch {wviewer::open $tk} r]
          rename ::focus {}
          rename ::km_real_focus ::focus
          if {$c} { return "threw ($r)" }
          return $r
        }
        # the calls among them that ask for the focus on window `w`: a query
        # (-displayof, -lastfor) is not one
        proc km_asks {w} {
          set r {}
          foreach c $::km_focus {
            if {[lindex $c end] eq $w && [lindex $c 0] ne {-displayof} && [lindex $c 0] ne {-lastfor}} { lappend r $c }
          }
          return $r
        }
        # u, e and Control-d typed on window `fw`: the window under the
        # pointer, calls of the viewer's filter, log lines, what the engine was
        # handed, boxes, and whether the layout of viewer `tk` is as before
        proc km_three {fw tk} {
          set l0 [wviewer::layout_for $tk]
          set ::km_via {} ; set ::km_log {} ; set k0 $::kf_calls ; set mb0 $::mb_hits
          foreach {ks st} {u 0 e 0 d 4} {
            event generate $fw <KeyPress> -keysym $ks -state $st -x 40 -y 40
            update
            event generate $fw <KeyRelease> -keysym $ks -state $st -x 40 -y 40
            update
          }
          return [list [winfo containing {*}[winfo pointerxy .]] [expr {$::kf_calls - $k0}] $::km_log $::km_via \
                       [expr {$::mb_hits - $mb0}] [expr {[wviewer::layout_for $tk] eq $l0}]]
        }
        set km_open3 [km_open_rec $km_tok3]
        set km_vtop3 [wviewer::window_for $km_tok3]
        set km_vdrw3 $km_vtop3.drw
        set km_rdy3 0
        if {$km_vtop3 ne {}} { set km_rdy3 [viewer_ready $km_vtop3] }
        km_pump 15
        set km18 [list $km_open3 $km_rdy3]
        set km18_want {1 1}
        if {$km_rdy3} {
          catch {wviewer::set_plot_mode single $km_tok3}
          lappend km18 [expr {[focus -lastfor $km_vtop3] eq $km_vtop3}] [km_asks $km_vtop3]
          lappend km18_want 1 [list [list $km_vtop3]]
          lassign [km_mid $km_vdrw3 0] km_x18 km_y18
          # the pointer has not moved since the open: it is over the main canvas
          set km_f18 {}
          for {set i 0} {$i < 60} {incr i} {
            update
            set km_f18 [focus -displayof .]
            if {$km_f18 ne {}} { break }
            after 50
          }
          if {$km_f18 eq $km_vtop3 || $km_f18 eq $km_vdrw3} {
            lappend km18 [km_three $km_f18 $km_tok3]
            lappend km18_want [list .drw 0 {} {} 0 1]
          } else {
            puts "skip: KM18's keys typed over the schematic right after the open -- this display left the keyboard on '$km_f18', not in the new viewer"
          }
          # the pointer comes in from where it was when the viewer opened (over
          # the main canvas); no click
          raise $km_vtop3 ; update
          km_warp $km_vdrw3 $km_x18 $km_y18
          set km_f18 {}
          for {set i 0} {$i < 60} {incr i} {
            update
            set km_f18 [focus -displayof .]
            if {$km_f18 ne {}} { break }
            after 50
          }
          if {$km_f18 eq {}} {
            puts "skip: KM18's first chord (typed where the display left the keyboard after the open) -- this application has no keyboard focus on this display"
          } else {
            puts "note: KM18 after the open and the pointer's move into the new plot the keyboard focus is on [expr {$km_f18 eq $km_vdrw3 ? {the new viewer's plot canvas} : ($km_f18 eq $km_vtop3 ? {the new viewer's toplevel} : ($km_f18 eq {.drw} ? {the main window's canvas} : $km_f18))}]"
            set km_mb18 $::mb_hits
            event generate $km_f18 <KeyPress> -keysym M -state 5 -x 40 -y 40
            update
            event generate $km_f18 <KeyRelease> -keysym M -state 5 -x 40 -y 40
            update
            lappend km18 [list [wviewer::plot_mode $km_tok3] [km_status $km_vtop3] [wviewer::plot_mode $tok] \
                               [expr {$::mb_hits - $km_mb18}]]
            lappend km18_want {multi multi single 0}
          }
          catch {wviewer::set_plot_mode single $km_tok3}
          # the other focus state
          set km_s18 [km_far .drw $km_vdrw3 $km_x18 $km_y18]
          set km_mb18 $::mb_hits
          km_type .drw M 5 ; km_type .drw M 5 KeyRelease
          lappend km18 [list [lrange $km_s18 0 2] [wviewer::plot_mode $km_tok3] [km_status $km_vtop3] \
                             [wviewer::plot_mode $tok] [expr {$::mb_hits - $km_mb18}]]
          lappend km18_want [list [list .drw $km_vdrw3 $km_vdrw3] multi multi single 0]
          catch {wviewer::set_plot_mode single $km_tok3}
          # the open that only raises, as auto-plot asks for it after a run:
          # the viewer's own focus on its plot canvas, the pointer and the
          # keyboard on the main canvas
          catch {focus $km_vdrw3}
          update
          raise . ; update
          km_warp .drw 60 60
          for {set i 0} {$i < 100} {incr i} {
            focus -force .drw ; update
            if {[focus -displayof .drw] eq {.drw}} { break }
            after 50
          }
          km_pump 2
          set km_r18 [list [list [focus -displayof .] [::km_real_xschem get current_win_path] \
                                 [winfo containing {*}[winfo pointerxy .]] \
                                 [expr {[focus -lastfor $km_vtop3] eq $km_vdrw3}]]]
          lappend km_r18 [km_open_rec $km_tok3]
          km_pump 20
          lappend km_r18 [expr {[focus -lastfor $km_vtop3] eq $km_vtop3}] [km_asks $km_vtop3] \
                         [expr {[llength [xschem windows]] - $km_win18}]
          set km_f18 [focus -displayof .]
          if {$km_f18 eq $km_vtop3 || $km_f18 eq $km_vdrw3} {
            lappend km_r18 [km_three $km_f18 $km_tok3]
          } else {
            puts "skip: KM18's keys typed over the schematic right after the raise -- this display left the keyboard on '$km_f18', not in the raised viewer"
            lappend km_r18 [list .drw 0 {} {} 0 1]
          }
          lappend km18 $km_r18
          lappend km18_want [list [list .drw .drw .drw 1] 1 1 [list [list $km_vtop3]] 1 [list .drw 0 {} {} 0 1]]
          # the pointer out of every window and back over the main canvas: the
          # rows below start from the main window's context whatever a
          # product did with the keys above
          ptr_park
          ptr_back
          focus -force .drw ; update
        }
        rename km_open_rec {}
        rename km_asks {}
        rename km_three {}
        check "KM18 a viewer that has just opened takes its keys without a click and takes none that are typed over the schematic: the open leaves the focus inside the viewer on its toplevel and asks for it by one plain call; with the pointer still over the main canvas u, e and Control-d typed where the display left the keyboard do nothing in the viewer; with the pointer moved into the new plot, Ctrl-Shift-M typed in the window the display gave the keyboard to flips the new viewer's mode; with the focus forced onto the main canvas it does the same; and an open that only raises the viewer, the pointer and the keyboard on the main canvas, takes the viewer's own focus from its plot canvas back to the toplevel by one plain call, after which the same three keys do nothing in the viewer (the open's answer, the canvas mapped, the focus inside the toplevel on the toplevel, the calls of focus that name the toplevel; the three keys: the window under the pointer, calls of the filter, log lines, what the engine was handed, boxes, the layout as before; after the first chord: the new viewer's mode and status bar, the first viewer's mode, boxes; after the second: the state it was typed in, the same four; the raise: the state before it, focus window, context, window under the pointer and the viewer's own focus on its plot canvas; the open's answer; the focus inside the toplevel on the toplevel after it; the calls of focus that name the toplevel; one window more than before the open; the three keys as above)" \
          $km18 $km18_want
        set km20 {}
        set km20_want {}
        if {$km_rdy3} {
          lappend km20 [km_ctl]
          lappend km20_want [list .drw {{.drw 121 0}} 1 0]
          foreach {km_w km_t km_wx km_wy} [list $vdrw $tok $kmx $kmy $km_vdrw3 $km_tok3 $km_x18 $km_y18] {
            wviewer::set_plot_mode single $tok
            catch {wviewer::set_plot_mode single $km_tok3}
            set km_s20 [km_far .drw $km_w $km_wx $km_wy]
            set ::km_log {} ; set km_mb20 $::mb_hits
            km_type .drw M 5 ; km_type .drw M 5 KeyRelease
            lappend km20 [list [lrange $km_s20 0 2] [wviewer::plot_mode $tok] [wviewer::plot_mode $km_tok3] \
                               $::km_log [expr {$::mb_hits - $km_mb20}]]
          }
          lappend km20_want \
            [list [list .drw $vdrw $vdrw] multi single [list [list wviewer::set_plot_mode multi $tok]] 0] \
            [list [list .drw $km_vdrw3 $km_vdrw3] single multi [list [list wviewer::set_plot_mode multi $km_tok3]] 0]
        }
        check "KM20 the control and two viewers: with the pointer over the main canvas and the focus there, y flips enable_stretch through the main canvas and the viewer's filter is not called, with one viewer open and with two; with two viewers open and the focus on the main canvas, Ctrl-Shift-M goes to the viewer the pointer is in and to no other (with one viewer: the context, what the engine was handed, enable_stretch flipped, calls of the filter; with two: the same four, then per viewer, the first and then the second: the state the chord was typed in, the first viewer's mode, the second's, the log lines, boxes)" \
          [list $km20_one $km20] [list [list .drw {{.drw 121 0}} 1 0] $km20_want]
        catch {wviewer::close $km_tok3}
        catch {ase::session_close $km_tok3}
        km_pump 10
        raise $vtop ; update
        km_warp $vdrw $kmx $kmy
        xschem new_schematic switch $vdrw
        wviewer::set_plot_mode single $tok
        check "KM18 fixture: the second viewer is closed again: as many windows as before it, no toplevel of its own, the first viewer's context current, single" \
          [list [expr {[llength [xschem windows]] - $km_win18}] [wviewer::window_for $km_tok3] \
                [xschem get current_win_path] [wviewer::plot_mode $tok]] \
          [list 0 {} $vdrw single]
        rename km_ctl {}

        # --- KM19: PARITY with what Tk does --------------------------------------
        # The viewer's side chooses, from what `bind WaveViewer` lists, the
        # binding Tk would run. Here Tk is asked itself, on the live tag. Every
        # sequence of the tag (the defaults, the Caps Lock dispatch, and six
        # bindings of the row's own of the kinds an rc can add: a new chord, a
        # named key, Alt, a chord that competes with a Caps Lock sequence, a
        # release, a sequence with no keysym) is made to record its own name
        # and break. For every sequence that names a keysym the event it names
        # is generated, as it stands and with Num Lock, with Caps Lock and with
        # Alt on top, twice: with the focus on the viewer's canvas (Tk chooses)
        # and with the focus on the main canvas and the pointer in the plot (the
        # viewer's side chooses). The two recordings must be the same list, and
        # some binding must have run. The pointer rests two pixels inside the
        # strip's edge, where the filter forwards no graph key. The main canvas's
        # own binding for Alt keys must not have run in the second half.
        # THE ORDER OF BINDING. Tk's choice is not transitive: of two sequences
        # that ask for different modifiers the later bound wins, so three of
        # them can answer by the order they were bound in. The live tag holds
        # no such three, so the row brings its own: three sequences for F8 on a
        # tag of its own, put first on the viewer's canvas, bound in each of
        # the six orders. For each order Tk is asked which one runs for the
        # event that matches all three (the focus on the viewer's canvas), and
        # the chooser is asked the same of what `bind` lists for that tag. The
        # six pairs must agree, and the six answers must not all be one
        # sequence, or the order was not what the leg moved.
        set km19_save {}
        foreach km_seq [bind WaveViewer] { lappend km19_save $km_seq [bind WaveViewer $km_seq] }
        set km19_own {<Control-Key-r> <Key-F5> <Alt-Key-j> <Control-Alt-Key-D> <KeyRelease-u> <Control-Key>}
        foreach km_seq $km19_own { bind WaveViewer $km_seq break }
        set km19_all [bind WaveViewer]
        set ::km19_hit {}
        foreach km_seq $km19_all { bind WaveViewer $km_seq "[list set ::km19_hit $km_seq]\nbreak" }
        set km19_ev {}
        set km19_unread {}
        foreach km_seq $km19_all {
          set km_e {}
          catch {set km_e [wviewer::key_seq_event $km_seq]}
          if {[llength $km_e] != 4 || ![string is integer -strict [lindex $km_e 3]]} { lappend km19_unread $km_seq ; continue }
          lassign $km_e km_T km_N km_K km_m
          if {$km_K eq {}} {
            if {$km_N eq {}} { continue }
            set km_K [format %c $km_N]
          }
          foreach km_s [lsort -unique -integer [list $km_m [expr {$km_m | 16}] [expr {$km_m | 2}] [expr {$km_m | 8}]]] {
            lappend km19_ev [list [expr {$km_T == 3 ? {KeyRelease} : {KeyPress}}] $km_K $km_s]
          }
        }
        set km19_tk {} ; set km19_vw {}
        for {set i 0} {$i < 100} {incr i} {
          focus -force $vdrw ; update
          if {[focus -displayof $vdrw] eq $vdrw} { break }
          after 50
        }
        set km19_f1 [focus -displayof $vdrw]
        foreach km_e $km19_ev {
          lassign $km_e km_ty km_K km_s
          set ::km19_hit {}
          event generate $vdrw <$km_ty> -keysym $km_K -state $km_s -x [lindex $km_ring 0] -y [lindex $km_ring 1]
          update
          lappend km19_tk $::km19_hit
        }
        # the order of binding: Tk first, then the chooser, per order
        set km19_ptag KM19OrderTag
        set km19_three {<Control-Mod2-Key-F8> <Shift-Mod2-Key-F8> <Control-Key-F8>}
        set km19_pairs {}
        set km19_tags0 [bindtags $vdrw]
        bindtags $vdrw [linsert $km19_tags0 0 $km19_ptag]
        foreach km_ord {{0 1 2} {0 2 1} {1 0 2} {1 2 0} {2 0 1} {2 1 0}} {
          foreach km_seq [bind $km19_ptag] { bind $km19_ptag $km_seq {} }
          foreach km_i $km_ord {
            set km_seq [lindex $km19_three $km_i]
            bind $km19_ptag $km_seq "[list set ::km19_hit $km_seq]\nbreak"
          }
          set ::km19_hit {}
          event generate $vdrw <KeyPress> -keysym F8 -state 21 -x [lindex $km_ring 0] -y [lindex $km_ring 1]
          update
          set km_c {}
          catch {set km_c [wviewer::tag_key_seq [bind $km19_ptag] 2 65477 F8 21]}
          lappend km19_pairs [list $::km19_hit $km_c]
        }
        foreach km_seq [bind $km19_ptag] { bind $km19_ptag $km_seq {} }
        bindtags $vdrw $km19_tags0
        set km19_pdiff {}
        set km19_pran {}
        foreach km_pr $km19_pairs {
          if {[lindex $km_pr 0] ne [lindex $km_pr 1] || [lindex $km_pr 0] eq {}} { lappend km19_pdiff $km_pr }
          lappend km19_pran [lindex $km_pr 0]
        }
        set km19_s2 [km_far .drw $vdrw {*}$km_ring]
        # Several of these chords are an editor verb once the main canvas or the
        # engine runs them in the viewer (Control-q quits). They are typed on
        # the main canvas only when a key neither has a use for (the left Shift
        # key) was seen to go to the viewer's filter there and NOT to the
        # engine: the canvas door took it. Otherwise the half is not sent.
        set ::km_via {} ; set km_k19 $::kf_calls ; set km_ap19 $::km_altprobe
        km_type .drw Shift_L 0
        km_type .drw Shift_L 1 KeyRelease
        if {$::kf_calls - $km_k19 == 2 && $::km_via eq {}} {
          foreach km_e $km19_ev {
            lassign $km_e km_ty km_K km_s
            set ::km19_hit {}
            event generate .drw <$km_ty> -keysym $km_K -state $km_s -x 40 -y 40
            update
            lappend km19_vw $::km19_hit
          }
          set km19_diff {}
          foreach km_e $km19_ev km_a $km19_tk km_b $km19_vw {
            if {$km_a ne $km_b} { lappend km19_diff [list $km_e $km_a $km_b] }
          }
        } else {
          set km19_diff not-sent
        }
        set km_ap19 [expr {$::km_altprobe - $km_ap19}]
        # the tag as it was: the row's own sequences off, every script back
        foreach km_seq $km19_own { bind WaveViewer $km_seq {} }
        foreach {km_seq km_scr} $km19_save { bind WaveViewer $km_seq $km_scr }
        set km19_back {}
        foreach km_seq [bind WaveViewer] { lappend km19_back $km_seq [bind WaveViewer $km_seq] }
        check "KM19 for every sequence of the WaveViewer tag, the Caps Lock dispatch and six bindings of the row's own included, the binding that runs for a key typed with the focus on the main canvas and the pointer in the plot is the one Tk runs for the same key with the focus on the viewer's canvas; and for three sequences of the row's own, bound on a tag of its own in each of the six orders, the chooser answers what Tk ran (the focus for Tk's half, the state for the other; sequences of the tag the viewer's side does not read; events for which the two differ; the events walked are no fewer than the tag's sequences, which are more than none, and some binding ran in Tk's half; runs of the main canvas's own binding for Alt keys; the tag is back as it was; the orders of binding: how many were asked, those where the two differ or Tk ran nothing, the answers are more than one sequence, the canvas's tags back as they were)" \
          [list $km19_f1 [lrange $km19_s2 0 2] $km19_unread $km19_diff \
                [expr {[llength $km19_ev] >= [llength $km19_all] && [llength $km19_save] > 0}] \
                [expr {[llength [lsearch -all -not -exact $km19_tk {}]] > 0}] $km_ap19 \
                [expr {$km19_back eq $km19_save}] \
                [llength $km19_pairs] $km19_pdiff [expr {[llength [lsort -unique $km19_pran]] > 1}] \
                [expr {[bindtags $vdrw] eq $km19_tags0}]] \
          [list $vdrw [list .drw $vdrw $vdrw] {} {} 1 1 0 1 6 {} 1 1]

        # --- KM21: an ordinary second schematic window: nothing changes -------------
        # The fence for "viewer contexts only". A second window is opened the
        # way a viewer's is and left an ordinary empty schematic. With the focus
        # on the main canvas and the pointer in that window (its context is the
        # current one), each key runs in the second window as the editor key it
        # is, as before this item: typed on the main canvas, the schematic's
        # move with nothing selected does nothing, w starts a wire, y flips
        # enable_stretch, and in the Cadence profile s starts the snapped wire;
        # through the engine's entry Alt-b steps hide-symbols. The expected
        # values were taken on the product before the change. The message box
        # answers cancel for the row.
        set km21 {}
        set km21_want {}
        set km21_tag no-window
        set km21b no-window
        xschem new_schematic switch .drw
        set km21_w0 [llength [xschem windows]]
        xschem load_new_window -window {}
        set km_ow [xschem get current_win_path]
        set km21_ok [expr {$km_ow ne {.drw} && $km_ow ne $vdrw && [winfo exists $km_ow]}]
        if {$km21_ok} {
          for {set i 0} {$i < 300} {incr i} {
            update
            if {[winfo ismapped $km_ow]} { break }
            after 20
          }
          km_pump 10
          rename ::tk_messageBox ::km21_suite_mb
          proc ::tk_messageBox {args} { incr ::mb_hits ; return cancel }
          foreach km_prof {0 1} {
            set ::cadence_compat $km_prof
            set km_fam {Ctrl-Shift-M M 5 tk w w 0 tk y y 0 tk Alt-b 98 8 eng}
            if {$km_prof} { lappend km_fam s s 0 tk }
            foreach {km_nm km_ks km_st km_door} $km_fam {
              set km_s21 [km_far .drw $km_ow 120 120]
              set km_ui0 [::km_real_xschem get ui_state]
              set km_hs0 $::hide_symbols
              set km_es0 $::enable_stretch
              set ::km_via {} ; set km_mb21 $::mb_hits ; set km_k21 $::kf_calls
              if {$km_door eq {eng}} {
                xschem callback .drw 2 40 40 $km_ks 0 0 $km_st
                update
              } else {
                km_type .drw $km_ks $km_st
              }
              lappend km21 [list $km_prof $km_nm [lrange $km_s21 0 2] $::km_via \
                                 [expr {[::km_real_xschem get ui_state] != $km_ui0}] \
                                 [expr {($::hide_symbols - $km_hs0 + 3) % 3}] \
                                 [expr {$::enable_stretch != $km_es0}] \
                                 [expr {$::mb_hits - $km_mb21}] [expr {$::kf_calls - $km_k21}] \
                                 [::km_real_xschem get wave_viewer]]
              if {$km_door eq {eng}} {
                xschem callback .drw 3 40 40 $km_ks 0 0 $km_st
                update
              } else {
                km_type .drw $km_ks $km_st KeyRelease
              }
              catch {::km_real_xschem abort_operation}
              catch {::km_real_xschem set hide_symbols $km_hs0}
              set ::hide_symbols $km_hs0
              set ::enable_stretch $km_es0
            }
          }
          set ::cadence_compat $km_cad0
          set ::autotrim_wires $km_at0
          rename ::tk_messageBox {}
          rename ::km21_suite_mb ::tk_messageBox
          foreach km_prof {0 1} {
            foreach {km_nm km_ks km_st km_ui km_hs km_es} [list Ctrl-Shift-M 77 5 0 0 0 w 119 0 1 0 0 y 121 0 0 0 1 \
                                                      Alt-b 98 8 0 1 0 {*}[expr {$km_prof ? {s 115 0 1 0 0} : {}}]] {
              lappend km21_want [list $km_prof $km_nm [list .drw $km_ow $km_ow] [list [list .drw $km_ks $km_st]] \
                                      $km_ui $km_hs $km_es 0 0 0]
            }
          }
          set km21_tag [expr {[lindex [bindtags $km_ow] 0] eq $km_tag}]
          # THE OTHER WAY ROUND: the keyboard on the SECOND window's canvas and
          # the pointer in the viewer's plot. The canvas door is a tag of every
          # schematic canvas, not of the main one only, so a key typed there is
          # the viewer's as well. In the Cadence profile: i, which is a binding
          # of the canvas itself (this suite's line on the main canvas, cloned
          # onto the new window's canvas) and never calls the engine; then
          # Ctrl-Shift-M.
          set ::cadence_compat 1
          set km21b [list [expr {[bind $km_ow <Key-i>] ne {}}]]
          set km_s21 [km_far $km_ow $vdrw $kmx $kmy]
          set km_e21 [list [::km_real_xschem get instances] [::km_real_xschem get ui_state] [toplevel_count]]
          set ::km_via {} ; set km_mb21 $::mb_hits ; set km_k21 $::kf_calls
          km_type $km_ow i 0 ; km_type $km_ow i 0 KeyRelease
          lappend km21b [list [lrange $km_s21 0 2] [expr {$::kf_calls - $km_k21}] [expr {$::mb_hits - $km_mb21}] $::km_via \
                              [expr {[list [::km_real_xschem get instances] [::km_real_xschem get ui_state] [toplevel_count]] eq $km_e21}]]
          catch {::km_real_xschem abort_operation}
          wviewer::set_plot_mode single $tok
          set km_s21 [km_far $km_ow $vdrw $kmx $kmy]
          set ::km_via {} ; set ::km_log {} ; set km_mb21 $::mb_hits
          km_type $km_ow M 5 ; km_type $km_ow M 5 KeyRelease
          lappend km21b [list [lrange $km_s21 0 2] [wviewer::plot_mode $tok] $::km_log $::km_via [expr {$::mb_hits - $km_mb21}]]
          wviewer::set_plot_mode single $tok
          set ::cadence_compat $km_cad0
          set ::autotrim_wires $km_at0
          xschem new_schematic switch $km_ow
          catch {xschem set_modify 0}
          xschem new_schematic destroy $km_ow {}
          km_pump 10
        }
        raise $vtop ; update
        km_warp $vdrw $kmx $kmy
        xschem new_schematic switch $vdrw
        check "KM21 an ordinary second schematic window is not a viewer's business: with the focus on the main canvas and the pointer in that window, each key goes to the engine through the main canvas and runs in the second window as it did before this item, stock profile then Cadence: typed, Ctrl-Shift-M, w, y and the Cadence profile's s; through the engine's entry, Alt-b (the window opened; per key: the profile, the key, the state it was sent in, what the engine was handed, the engine's state moved, the step of hide-symbols, enable_stretch flipped, boxes, calls of the viewer's filter, the window's viewer flag; the windows left behind; the profile back)" \
          [list $km21_ok $km21 [expr {[llength [xschem windows]] - $km21_w0}] [list $::cadence_compat $::autotrim_wires]] \
          [list 1 $km21_want 0 [list $km_cad0 $km_at0]]
        check "KM21 ...and that window's canvas carried the key-door tag first in its tag list, as every schematic canvas does" \
          $km21_tag 1
        check "KM21 ...and the other way round, the keyboard on that second window's canvas and the pointer in the viewer's plot, a key typed there is the viewer's as it is from the main canvas, in the Cadence profile: i, a binding of that canvas itself, reaches the viewer's filter and brings up no box, and Ctrl-Shift-M flips the viewer's mode (the canvas has the binding for i; for i: the state, focus window, context and window under the pointer, calls of the filter for press and release, boxes, what the engine was handed, instances, engine state and toplevels as before; for the chord: the state, the mode, the log lines, what the engine was handed, boxes)" \
          $km21b [list 1 [list [list $km_ow $vdrw $vdrw] 2 0 {} 1] \
                         [list [list $km_ow $vdrw $vdrw] multi [list [list wviewer::set_plot_mode multi $tok]] {} 0]]

        # --- KM22: a key typed into the Signal Browser's search box stays there ----
        # A window that is no xschem drawing window keeps its keys. The Signal
        # Browser is shown, its search entry is given the focus, the pointer is
        # in the plot: a typed b goes into the entry, the viewer's filter is not
        # called, the engine is handed nothing and cursor B does not move.
        wviewer::set_plot_mode single $tok
        set km22 {}
        set km_be $vtop.wvbrowser.wvsearch.pat
        set km_bw0 [wviewer::browser_shown $tok]
        catch {wviewer::browser_toggle 1 $tok}
        km_pump 10
        if {![winfo exists $km_be] || ![winfo ismapped $km_be]} {
          set km22 no-search-entry
        } else {
          lassign [km_mid $vdrw 0] km_x22 km_y22
          raise $vtop ; update
          km_warp $vdrw $km_x22 $km_y22
          $km_be delete 0 end
          for {set i 0} {$i < 100} {incr i} {
            focus -force $km_be ; update
            if {[focus -displayof $km_be] eq $km_be} { break }
            after 50
          }
          set km_gf22 [expr {[km_gf $vdrw] & 4}]
          set ::km_via {} ; set km_k22 $::kf_calls
          event generate $km_be <KeyPress> -keysym b -x 5 -y 5
          update
          event generate $km_be <KeyRelease> -keysym b -x 5 -y 5
          update
          set km22 [list [expr {[focus -displayof $km_be] eq $km_be}] \
                         [winfo containing -displayof $vdrw {*}[winfo pointerxy $vdrw]] \
                         [$km_be get] [expr {$::kf_calls - $km_k22}] $::km_via \
                         [expr {([km_gf $vdrw] & 4) == $km_gf22}]]
          $km_be delete 0 end
          event generate $km_be <KeyRelease> -keysym space
          update
        }
        if {!$km_bw0} { catch {wviewer::browser_toggle 0 $tok} }
        km_pump 10
        check "KM22 a key typed into the Signal Browser's search box stays there: with the focus in the entry and the pointer in the plot, a typed b goes into the entry, the viewer's key filter is not called, the engine is handed nothing and cursor B does not move (the focus on the entry, the window under the pointer, the entry's text, calls of the filter, what the engine was handed, cursor B as before); the browser is hidden again as it was" \
          [list $km22 [wviewer::browser_shown $tok]] [list [list 1 $vdrw b 0 {} 1] $km_bw0]

        # the pointer back where the band found it, the focus on the plot canvas
        # and the viewer's context current, as the rows after this band expect
        event generate . <Motion> -warp 1 -x [expr {[lindex $km_ptr0 0] - [winfo rootx .]}] \
                                          -y [expr {[lindex $km_ptr0 1] - [winfo rooty .]}]
        km_pump 6
        focus -force $vdrw
        update
        xschem new_schematic switch $vdrw
        wviewer::set_plot_mode single $tok
        lassign [km_mid $vdrw 0] kmx kmy
        foreach km_p {km_pump km_warp km_far km_type km_eng km_stored} { rename $km_p {} }
        rename ::wvtest_alt_arm_probe {}

        # --- KM12: nothing changes outside a viewer -----------------------------
        # The fence for the decision that this item changes no key over a graph
        # embedded in an ordinary schematic. The main window holds the shipped
        # example with one graph rect; each chord of the family goes straight to
        # the engine at the centre of that rect, in the stock profile and in the
        # Cadence one, and the outcome is compared with the one taken on the
        # product before the change. The message box answers cancel for this row
        # (the suite's recorder answers ok, which would let Alt-s reload).
        set km_sch [file join $repo xschem_library examples test_ne555.sch]
        set km_rect {}
        if {![catch {set km_fd [open $km_sch r]}]} {
          regexp -line {^B 2 (\S+) (\S+) (\S+) (\S+) \{flags=graph} [read $km_fd] -> gx1 gy1 gx2 gy2
          close $km_fd
          if {[info exists gx1]} { set km_rect [list $gx1 $gy1 $gx2 $gy2] }
        }
        check "KM12 fixture: the main window's schematic file names one graph rect" [llength $km_rect] 4
        if {[llength $km_rect] == 4} {
          xschem new_schematic switch .drw
          set km_ro [xschem get readonly]
          xschem set readonly 0
          set ::km_mbs {}
          rename ::tk_messageBox ::km_suite_mb
          proc ::tk_messageBox {args} {
            set m {}
            catch {set m [dict get $args -message]}
            lappend ::km_mbs [lindex [split $m "\n"] 0]
            return cancel
          }
          proc km_sch_px {r} {
            lassign $r x1 y1 x2 y2
            set z [xschem get zoom]
            return [list [expr {int((($x1 + $x2) / 2.0 + [xschem get xorigin]) / $z)}] \
                         [expr {int((($y1 + $y2) / 2.0 + [xschem get yorigin]) / $z)}]]
          }
          proc km_sch_state {w0} {
            return [list gf [expr {[xschem get graph_flags] & 70}] ui [xschem get ui_state] \
              hs $::hide_symbols newwin [expr {[llength [xschem windows]] - [llength $w0]}] \
              wires [xschem get wires] sacd $::km_sacd mb $::km_mbs]
          }
          set km_out {}
          set km_cad0 $::cadence_compat
          set km_at0 $::autotrim_wires
          set km_hs0 $::hide_symbols
          set km_wires [xschem get wires]
          foreach km_prof {0 1} {
            set ::cadence_compat $km_prof
            foreach {nm N s} {Ctrl-Shift-M 77 5 s 115 0 Alt-s 115 8 Ctrl-Alt-s 115 12
                              Ctrl-Alt-t 116 12 Alt-b 98 8 Alt-m 109 8} {
              xschem new_schematic switch .drw
              set km_w0 [xschem windows]
              set ::km_mbs {} ; set ::km_sacd 0
              lassign [km_sch_px $km_rect] spx spy
              # the two move chords show only with something to move
              if {$N == 77 || $N == 109} { xschem select_all }
              ::km_real_xschem callback .drw 6 $spx $spy 0 0 0 0
              ::km_real_xschem callback .drw 2 $spx $spy $N 0 0 $s
              update
              xschem new_schematic switch .drw
              lappend km_out $km_prof/$nm [km_sch_state $km_w0]
              # put the window back: leave any armed command, close a tab the key
              # made (a tab is destroyed from inside it)
              ::km_real_xschem callback .drw 2 $spx $spy 65307 0 0 0
              catch {xschem abort_operation}
              foreach km_w [xschem windows] {
                if {[lsearch -exact $km_w0 $km_w] < 0} {
                  catch {xschem new_schematic switch [lindex $km_w 0]}
                  catch {xschem new_schematic destroy [lindex $km_w 0] {}}
                }
              }
              xschem new_schematic switch .drw
              catch {xschem unselect_all}
              catch {xschem set hide_symbols $km_hs0}
              set ::hide_symbols $km_hs0
            }
          }
          lappend km_out left-behind [expr {[llength [xschem windows]] - [llength $km_w0]}]
          set ::cadence_compat $km_cad0
          set ::autotrim_wires $km_at0
          rename ::tk_messageBox {}
          rename ::km_suite_mb ::tk_messageBox
          rename km_sch_px {}
          rename km_sch_state {}
          xschem new_schematic switch .drw
          xschem set readonly $km_ro
          # What each chord did on the product before this item, as the
          # difference from a window where nothing happened: the schematic's move
          # picks the selection up (ui_state 40), plain s is the graph's cursor
          # swap in the stock profile and the snapped wire in the Cadence one
          # (ui_state 1), Alt-s asks about a reload, Control-Alt-s opens the Save
          # form, Control-Alt-t makes a schematic, Alt-b steps hide-symbols.
          set km_want {}
          foreach km_prof {0 1} {
            foreach {nm km_d} {Ctrl-Shift-M {ui 40} s {}
                               Alt-s {mb {{Are you sure you want to reload from disk?}}}
                               Ctrl-Alt-s {sacd 1} Ctrl-Alt-t {newwin 1} Alt-b {hs +1} Alt-m {ui 40}} {
              set km_v [list gf 0 ui 0 hs $km_hs0 newwin 0 wires $km_wires sacd 0 mb {}]
              foreach {k val} $km_d {
                if {$val eq {+1}} { set val [expr {($km_hs0 + 1) % 3}] }
                dict set km_v $k $val
              }
              if {$km_prof == 1 && $nm eq {s}} { dict set km_v ui 1 }
              lappend km_want $km_prof/$nm $km_v
            }
          }
          lappend km_want left-behind 0
          check "KM12 over a graph embedded in a schematic each chord of the family does what it did before this item, stock profile then Cadence" \
            $km_out $km_want
          xschem new_schematic switch $vdrw
        }

        # take the band's instruments out again
        rename ::save_as_cellview_dialog {}
        if {$km_had_sacd} { rename ::km_real_sacd ::save_as_cellview_dialog }
        rename ::wviewer::log_action {}
        rename ::wviewer::__km_real_log ::wviewer::log_action
        rename ::xschem {}
        rename ::km_real_xschem ::xschem
        foreach km_p {km_key km_decides km_snap km_gf km_mk km_cur km_status km_readout km_mid km_plain
                      km_curB km_bar km_bwalk km_bwant km_inband} { rename $km_p {} }

        # put the WB/SD fixture back for whatever runs after this band
        wviewer::set_graphs $tok $ca_save
        wviewer::regenerate $tok
        wviewer::fit $tok
      } else {
        puts "SKIPPED: CA1-CA8 (no trace dict in the model to build a fixture from)"
        puts "skip: the KM rows (Ctrl-Shift-M and the key filter, real keys) did not run: no trace in the model to build their fixture from"
      }
      rename ca_sel {}
      rename ca_tok {}
      rename ca_cursorA {}
      rename ca_row {}
      rename ca_bands {}
      rename ca_send {}

      rename sd_order {}
      rename sd_ids {}
      rename sd_near {}
      wviewer::set_graphs $tok $sd_save
      wviewer::regenerate $tok

      rename wb_bold {}
      rename wb_reset {}
      rename wb_ev {}
      rename wb_at {}
      unset ::wbt
      # leave strip 0 trace-free again so IX-fit sees the same shape as before
      set wbgs [dict get [wviewer::layout_for $tok] graphs]
      wviewer::set_graphs $tok \
        [lreplace $wbgs 0 0 [dict replace [lindex $wbgs 0] traces {}]]
      wviewer::regenerate $tok
    } else {
      puts "SKIPPED: WB wave-bold legs (no raw artifact)"
      puts "skip: the KM rows (Ctrl-Shift-M and the key filter, real keys) did not run: no raw artifact (ngspice not found, or its run left none)"
    }

    # --- IX-fit: Fit reframes the GRAPH data range, never the canvas ---------
    # PRIMARY teeth (the removed zoom_full): perturb the data range, Fit, and the
    # CANVAS must be unchanged. Holds with or without a raw loaded. Runs LAST
    # among the IX legs: the S2 sabotage (re-inserting `xschem zoom_full`) moves
    # the canvas, and running Fit last keeps that drift from leaking a canvas ==
    # baseline failure into a later leg — the real code never moves the canvas,
    # so the single baseline still holds for every leg above.
    ix_setrange $tok 0 10 -1 1
    ix_setrange $tok 0.5 1.0 -1 1
    xschem new_schematic switch $vdrw
    check_true "IX-fit perturbed data range (x1==0.5)" \
      [expr {[xschem getprop rect 2 0 x1] == 0.5}]
    wviewer::fit $tok
    check_true "IX-fit canvas == baseline (no zoom_full reframe)" \
      [ix_canvas_ok $vdrw $cx0 $cy0 $cz0]

    rename ix_setrange {}
    rename ix_canvas_ok {}
    wviewer::close $tok
    update
  }

  # the strip filter must never throw: a filter error swallows keys by
  # ACCIDENT and every strip assertion above turns hollow (found live: the
  # instrumentation itself once induced exactly this)
  check "G* key_filter ran error-free" $::kf_errs 0

  # restore the instrumented procs + drop the user-rc probe binds
  rename ::wviewer::key_filter {}
  rename ::wviewer::key_filter_orig ::wviewer::key_filter
  rename ::tk_messageBox {}
  rename ::wvtest_real_messageBox ::tk_messageBox
  bind .drw <Key-i> {}
  bind .drw <Alt-KeyPress> {}
} else {
  puts "SKIPPED: G1-G9 GUI legs (no usable DISPLAY)"
}

} bigerr]} {
  puts "UNEXPECTED ERROR: $bigerr"
  incr fail
}

# --- cleanup + verdict -------------------------------------------------------
if {$fail == 0} {
  # ⚠ `OVERALL: ok` IS THE ONLY SENTINEL T1 CAN SCORE, AND WITHOUT IT THIS SUITE
  # COULD NOT BE REGISTERED AT ALL (issue 1616). `banner_complete` in
  # tests/banner_rule.tcl — the only Tcl reader, and the one run_regression.tcl
  # sources — is `^OVERALL: ok([ \t]+\([^)]*\))?[ \t]*$`, and that file's header
  # says it implements no `RESULT: ALL PASS` spelling at all. So this suite, added
  # to `dcases` while printing only the `RESULT:` line below, would have been
  # scored `HARNESS: … did not complete cleanly (exit=0, OVERALL_ok=0, died=0)`
  # with all 402 of its own checks PASSING — the exact red measured at 809c03d1
  # for the wvbs family. `run_suites.sh` and `full_audit.sh` carry their own EREs
  # which DO accept `RESULT: ALL PASS`, which is why every standalone run of this
  # suite had always looked clean: the two readers that could see it were the two
  # that are not the gate.
  #
  # ⚠ ADDITIVE ON PURPOSE, exactly as `wvbs_finish` in wvbs_common.tcl is. The
  # `RESULT:` line is KEPT because `summarize_all` publishes a case's LAST
  # `RESULT:` line into the verdict and `run_suites.sh` displays it; dropping it
  # would blank both. The order of the two lines is not load-bearing —
  # `banner_complete` uses `regexp -line` over the whole body — and this comment
  # does not claim it is.
  #
  # This is the THIRD site in this family: wvbs_common.tcl (fourteen suites, issue
  # 1615), this file, and tests/headless/test_results_select.tcl, which is still
  # unregistered and still prints no sentinel.
  puts "OVERALL: ok ($npass checks)"
  puts "RESULT: ALL PASS ($npass checks)"
} else {
  puts "RESULT: $fail FAILED ($npass passed)"
}
flush stdout
exit [expr {$fail == 0 ? 0 : 1}]
