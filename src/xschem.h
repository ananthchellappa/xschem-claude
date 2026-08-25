/* File: xschem.h
 *
 * This file is part of XSCHEM,
 * a schematic capture and Spice/Vhdl/Verilog netlisting tool for circuit
 * simulation.
 * Copyright (C) 1998-2024 Stefan Frederik Schippers
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
 */

#ifndef CADGLOBALS
#define CADGLOBALS

#define XSCHEM_VERSION "3.4.8RC"
#define XSCHEM_FILE_VERSION "1.3" /* 1.3 introduces F {..} field for global Spectre attribute */

#if HAS_PIPE == 1
/* fdopen() */
#define _POSIX_C_SOURCE 200112L
#endif

#if  HAS_POPEN==1
/* popen() , pclose(), */
#define _POSIX_C_SOURCE 200112L
#endif

#define TCL_WIDE_INT_TYPE long


#if (defined(__APPLE__) && defined(__MACH__))
#define __unix__
#endif

/* stringification: STRINGIFY(xxxx) --> "xxxx" */
#define STRINGIFY2(x) #x
#define STRINGIFY(x) STRINGIFY2(x)

/*  approximate PI definition */
#define XSCH_PI 3.14159265358979323846264338327950288419716939937

#ifdef __unix__
#ifndef NO_SCCONFIG
#include "../config.h"
#endif
#else
#include "../XSchemWin/config.h"
#endif
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <string.h>
#include <ctype.h>
#include <limits.h> /* PATH_MAX */

#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

#ifdef __unix__
#include <unistd.h>
#include <regex.h>
#else
#include <windows.h>
#include "tkWin.h"
#endif
#include <sys/types.h>
#include <sys/stat.h>


#include <fcntl.h>
#include <time.h>

/* #include <sys/time.h>  for gettimeofday(). use time() instead */
#include <signal.h>
#ifdef __unix__
#include <X11/Xlib.h>
#include <X11/Xutil.h>
#include <X11/keysymdef.h>
#include <X11/keysym.h>
#include <X11/Xatom.h>
#include <X11/xpm.h>

#define xunlink unlink
#define xfseek fseek
#define xftell ftell
#define popen popen
#define pclose pclose
#else
#include <tkWinInt.h>
#define xunlink _unlink
#define MOUSE_WHEEL_UP 38
extern int XSetClipRectangles(register Display* dpy, GC gc, int clip_x_origin, 
            int clip_y_origin, XRectangle* rectangles, int n, int ordering);
extern int XSetTile(Display* display, GC gctiled, Pixmap s_pixmap);
extern void change_to_unix_fn(char* fn);
extern char win_temp_dir[PATH_MAX];
#define xfseek _fseeki64
#define xftell _ftelli64
#define popen _popen
#define pclose _pclose
#endif

#undef HAS_XCB
#ifdef  HAS_XCB
#include <xcb/render.h>
#include <X11/Xlib-xcb.h>
#endif

#if HAS_CAIRO==1
#define DRAW_ALL_CAIRO 0 /* use cairo for all graphics. Work in progress! */

/* Uncomment below #define if your graphic adapter shows garbage on screen or there are missing objects
 * while doing edit/copy/move operations with xschem. */
/* #define FIX_BROKEN_TILED_FILL 1 */

#include <cairo.h>
#if defined(HAS_LIBJPEG)
#include "cairo_jpg.h"
#endif
#ifdef __unix__
#include <cairo-xlib.h>
#include "cairo-xlib-xrender.h"
#else
#include <cairo-win32.h>
#endif
#endif

#include <tcl.h>
#include <tk.h>

/* Tcl 9 changed the count out-parameter of the list/string APIs (Tcl_SplitList,
 * Tcl_ListObjGetElements, Tcl_GetStringFromObj, ...) from `int *` to `Tcl_Size *`
 * (ptrdiff_t, 8 bytes on LP64). Passing the address of a plain `int` then makes the
 * library write 8 bytes into a 4-byte slot, corrupting an adjacent variable -> crash
 * (issue 0041: net_hilight_style parse SIGSEGV on Tcl 9). Tcl 8.6 has no Tcl_Size, so
 * shim it to int there. Guard on TCL_SIZE_MAX (a macro Tcl 9 defines) -- Tcl_Size itself
 * is a typedef, not a macro, so it cannot be tested with #ifndef. */
#ifndef TCL_SIZE_MAX
typedef int Tcl_Size;
#endif

#define _ALLOC_ID_ 0 /* to be replaced with unique IDs in my_*() allocations for memory tracking
                      * see create_alloc_ids.awk */

/* max number of windows (including main) a single xschem process can handle */
#define MAX_NEW_WINDOWS 20
#define WINDOW_PATH_SIZE 30

#define BACKLAYER 0
#define WIRELAYER 1
#define GRIDLAYER 2
#define SELLAYER 2
#define PROPERTYLAYER 1
#define TEXTLAYER 3
#define TEXTWIRELAYER 1 /*  color for wire name labels / pins */
#define SYMLAYER 4
#define PINLAYER 5
#define GENERICLAYER 3

#define CADSNAP 10.0
#define CADGRID 20.0
#define CADGRIDTHRESHOLD 10.0
#define CADGRIDMULTIPLY 2.0
#define CADINITIALZOOM 1
#define CADINITIALX 10
#define CADINITIALY -870
#define CADZOOMSTEP 1.2
#define CADMOVESTEP 200
#define CADMAXZOOM 10000.0
#define CADMINZOOM 0.005
#define CADHALFDOTSIZE 3.7
#define CADNULLNODE -1      /*  no valid node number */
#define CADWIREMINDIST 12.0
#define CADMAXWIRES 200
#define CADMAXTEXT 100
#define CADMAXOBJECTS 100  /*  (initial) max # of lines, rects (for each layer!!) */
#define MAXGROUP 100       /*  (initial) max # of objects that can be drawn while moving */
#define ELEMINST 100       /*  (initial) max # of placed elements,   was 600 20102004 */
#define ELEMDEF 50         /*  (initial) max # of defined elements */
#define EMBEDDED 1   /* used for embedded symbols marking in Symbol.flags */
#define PIN_OR_LABEL 2 /* symbol represents a pin or a label */
#define HILIGHT_CONN 4 /* used to hilight instances if connected wire is hilighted */
#define HIDE_INST 8    /*  will only show a bounding box for specific symbol instance */
#define SPICE_IGNORE 16
#define VERILOG_IGNORE 32
#define VHDL_IGNORE 64
#define TEDAX_IGNORE 128
#define IGNORE_INST 256
#define HIDE_SYMBOL_TEXTS 512
#define LVS_IGNORE_SHORT 1024 /* flag set if inst/symbol has lvs_ignore=short */
#define LVS_IGNORE_OPEN 2048  /* flag set if inst/symbol has lvs_ignore=open */
#define SPICE_SHORT 4096
#define VERILOG_SHORT 8192
#define VHDL_SHORT 16384
#define TEDAX_SHORT 32768
#define SPECTRE_SHORT 65536
#define SPECTRE_IGNORE 131072
#define LVS_IGNORE (LVS_IGNORE_SHORT | LVS_IGNORE_OPEN)
#define CADMAXGRIDPOINTS 512
#define CADMAXHIER 40
#define CADCHUNKALLOC 512 /*  was 256  20102004 */
#define CADDRAWBUFFERSIZE 512

/*  when x-width of drawing area s below this threshold use spatial */
/*  hash table for drawing wires and instances (for faster lookup) instead of */
/*  looping through the whole wire[] and inst[] arrays */
/*  when drawing area is very big using spatial hash table may take longer than */
/*  a simple for() loop through the big arrays + clip check. */
#define ITERATOR_THRESHOLD  42000.0

#define SCHEMATIC 1
#define SYMBOL 2
#define CAD_SPICE_NETLIST 1
#define CAD_VHDL_NETLIST 2
#define CAD_VERILOG_NETLIST 3
#define CAD_TEDAX_NETLIST 4
#define CAD_SYMBOL_ATTRS 5
#define CAD_SPECTRE_NETLIST 6

/*  possible states, encoded in global 'ui_state' */
#define STARTWIRE 1U
#define STARTRECT 2U
#define STARTLINE 4U
#define SELECTION 8U        /*  signals that some objects are selected. */
#define STARTSELECT 16U     /*  used for drawing a selection rectangle */
#define STARTMOVE 32U       /*  used for move/copy  operations */
#define STARTCOPY 64U       /*  used for move/copy  operations */
#define STARTZOOM 128U      /*  used for move/copy  operations */
#define STARTMERGE 256U     /*  used fpr merge schematic/symbol */
#define STARTPAN 512U       /*  new pan method with mouse button3 */
#define PLACE_TEXT 1024U
#define STARTPOLYGON 2048U
#define STARTARC 4096U
#define PLACE_SYMBOL 8192U  /* used in move_objects after place_symbol to avoid storing intermediate undo state */
#define START_SYMPIN 16384U
#define GRAPHPAN 32768U     /* bit 15 */
#define MENUSTART 65536U    /* bit 16 */
#define GRABSCREEN 131072U  /* bit 17 */
/* bit 18 (was DESEL_CLICK) is free: the old single-shot 'd' deselect was replaced by
 * the persistent DESEL_MODE below (doc/claude/specs/deselect_one_mode.md) */
#define DESEL_AREA 524288U  /* bit 19 */
#define NET_HILIGHT 1048576U   /* bit 20: interactive net-highlight mode (click to hilight) */
#define NET_UNHILIGHT 2097152U /* bit 21: interactive net-unhighlight mode (click to remove) */
#define DESEL_MODE 4194304U    /* bit 22: persistent deselect-one-at-a-time mode (click to deselect, ESC to end) */

#define SELECTED 1U         /*  used in the .sel field for selected objs. */
#define SELECTED1 2U        /*  first point selected... */
#define SELECTED2 4U        /*  second point selected... */
#define SELECTED3 8U
#define SELECTED4 16U

/* sub states encoded in global ui_state2 to reduce ui_state bits usage */
/* also used when infix_interface=0 */
#define MENUSTARTWIRE 1U /*  start wire invoked from menu */
#define MENUSTARTLINE 2U /*  start line invoked from menu */
#define MENUSTARTRECT 4U /*  start rect invoked from menu */
#define MENUSTARTZOOM 8U /*  start zoom box invoked from menu */
#define MENUSTARTSNAPWIRE 16U  /*  start wire invoked from menu, snap to pin variant 20171022 */
#define MENUSTARTPOLYGON 32U
#define MENUSTARTARC 64U
#define MENUSTARTCIRCLE 128U
#define MENUSTARTMOVE 256U
#define MENUSTARTWIRECUT 512U 
#define MENUSTARTWIRECUT2 1024U /* do not align cut point to snap */
#define MENUSTARTCOPY 2048U
#define MENUSTARTDESEL 4096U
#define MENUSTARTSTRETCH 8192U /* a pending MENUSTARTMOVE is a connected stretch (cadence 'm').
                                * Only ever set together with MENUSTARTMOVE.
                                * see doc/claude/specs/cadence_stretch_move_keys.md */
#define MENUSTARTROTATE 16384U /* a pending prompt-for-object rotate/flip (Cases 1 & 3): a
                                * rotate/flip verb fired with nothing selected arms this, so the
                                * next canvas click SELECTS the object under the cursor and applies
                                * xctx->menu_pending_transform to it (plain: no attached-net grab,
                                * wires are NOT kept connected).
                                * see doc/claude/specs/rotate_keep_connected_stretch.md */
#define MENUSTARTDESCEND 32768U /* a pending verb-noun descend: the descend verb (`E` /
                                * hi_descend) fired with nothing selected arms this, so the
                                * next canvas click PICKS the instance under the cursor and
                                * hands its name to the Tcl chooser. Unlike every other
                                * MENUSTART* arm the click does NOT select the picked object:
                                * the pick is an argument to one command, not a selection
                                * change. Non-mutating, so it is deliberately absent from the
                                * read-only backstop mask in check_menu_start_commands().
                                * see doc/claude/issues/0200-descend-has-no-verb-noun-pick.md */

/* The SHAPE sub-mask of ui_state2: the menu-armed half of the shape-draw family, i.e. the
 * `infix_interface 0` (cadence) branch where the verb only arms MENUSTART and the FIRST CANVAS
 * CLICK sets STARTRECT/STARTPOLYGON/STARTARC/STARTZOOM. abort_shape_draw() (callback.c) must test
 * BOTH halves: a gate that looks only at ui_state is a no-op for every cadence user (plan
 * landmine 5, doc/claude/suggestions/plan_modal_gesture_exclusion.md). Circle has no ui_state bit
 * of its own -- it is new_arc(PLACE, 360.), so it lands on STARTARC. */
#define MENUSTARTSHAPE (MENUSTARTRECT | MENUSTARTZOOM | MENUSTARTPOLYGON | MENUSTARTARC | \
                        MENUSTARTCIRCLE)

/* xctx->menu_pending_transform codes: which transform a pending MENUSTARTROTATE applies */
#define PENDING_TR_NONE      0
#define PENDING_TR_ROTATE    1  /* rotate about click point            (Shift-R / xschem rotate) */
#define PENDING_TR_ROTATE_IP 2  /* rotate about each object's anchor   (Alt-R   / rotate_in_place) */
#define PENDING_TR_FLIP      3  /* flip horizontally about click point (Shift-F / xschem flip) */
#define PENDING_TR_FLIP_IP   4  /* flip about each object's anchor     (Alt-F   / flip_in_place) */
#define PENDING_TR_FLIPV     5  /* flip vertically about click point   (V       / xschem flipv) */
#define PENDING_TR_FLIPV_IP  6  /* flip vertically about each anchor   (Alt-V   / flipv_in_place) */

#define WIRE 1              /*  types of defined objects */
#define xRECT  2
#define LINE 4
#define ELEMENT 8
#define xTEXT 16
#define POLYGON 32
#define ARC 64
#define INST_PIN 128 /* sel_array pseudo-type: a single pin of a placed instance.
                      * Carried as Selected.type=INST_PIN, Selected.n=instance index,
                      * Selected.col=pin index (index into the symbol's PINLAYER rects).
                      * Pin selection is transient + INERT: it never lives in
                      * xInstance.sel and never participates in edits; only the
                      * per-instance pin_sel[] array (below) and this sel_array entry
                      * carry it. See doc/claude/specs/pin_selection.md */
/* half-size (user units) of the selected-pin marker; ~constant on screen because it
 * scales with zoom. Used by select_pin/draw_selection/unselect_all so the draw and
 * erase always agree. Needs xctx + tk_scaling in scope. */
#define PIN_SEL_HANDLE_H (0.6 * CADWIREMINDIST * xctx->zoom * tk_scaling)

/*  for netlist.c */
#define BOXSIZE 400
#define NBOXES 50

#define MAX_UNDO 80

/* viewers xschem can generate plot commands for */
#define NGSPICE 1
#define GAW 2
#define BESPICE 3
#define XSCHEM_GRAPH 4

/*    some useful primes */
/*    109, 163, 251, 367, 557, 823, 1237, 1861, 2777, 4177, 6247, 9371, 14057 */
/*    21089, 31627, 47431, 71143, 106721, 160073, 240101, 360163, 540217, 810343 */
/*    1215497, 1823231, 2734867, 4102283, 6153409, 9230113, 13845163 */

#define HASHSIZE 31627
                   /*  parameters passed to action functions, see actions.c */
#define END      1 /*  endop */
#define START    2 /*  begin placing something */
#define PLACE    4 /*  place something */
#define ADD      8 /*  add something */
#define RUBBER  16 /*  used for drawing rubber objects while placing them */
#define NOW     32 /*  used for immediate (unbuffered) graphic operations */
#define ROTATE  64
#define FLIP   128
#define SET    256 /*  currently used in bbox() function (sets clip rect) */
#define ABORT  512 /*  used in move/copy_objects for aborting without unselecting */
#define THICK 1024 /*  used to draw thick lines (buses) */
#define ROTATELOCAL 2048 /*  rotate each selected object around its own anchor point 20171208 */
#define CLEAR 4096 /* used in new_wire to clear previous rubber when switching xctx->manhattan_lines */
#define SET_INSIDE 8192 /* used in bbox() to set clipping rectangle inside, not adding line width */
/* #define DRAW 8192 */  /* was used in bbox() to draw things by using XCopyArea after setting clip rectangle */
#define HILIGHT 8192  /* used when calling draw_*symbol_outline() for hilighting instead of normal draw */
#define FONTWIDTH 20
#define FONTOFFSET 40
#define FONTHEIGHT 40
#define FONTDESCENT 15
#define FONTWHITESPACE 10

/* hash operations */
#define XINSERT 0
#define XLOOKUP 1
#define XDELETE 2
#define XINSERT_NOREPLACE 3 /* do not replace token value in hash if already present */

/* Cairo text flags (.flags field) */
#define TEXT_BOLD 1
#define TEXT_OBLIQUE 2
#define TEXT_ITALIC 4
/* flag (.flags field) to hide text in symbols when displaying instances */
#define HIDE_TEXT 8
#define TEXT_FLOATER 16
#define HIDE_TEXT_INSTANTIATED 32
/* ANNOTATION CLASSES (S7, doc/claude/specs/op_annotation.md). A text whose hide=
 * token names a class is shown iff the matching bit of the annot_show mask is set,
 * and ignores show_hidden_texts entirely (decision D3: the two shipped "Annotate
 * Operating Point" menu items already do `set show_hidden_texts 1`, so letting it
 * override would make the annotation off-switch a no-op exactly when it is needed).
 * These are a DIFFERENT namespace from HIDE_TEXT / HIDE_TEXT_INSTANTIATED, whose
 * semantics are unchanged for every existing symbol (invariant I7). */
#define HIDE_TEXT_OP 64        /* hide=op      : device operating-point info */
#define HIDE_TEXT_VOLTAGE 128  /* hide=voltage : node voltages */
/* THE IMPLICIT ANNOTATION CLASS (issues 0614/0615). set_text_flags() classifies a
 * text by its CONTENT -- a whole-string `@spice_get_voltage` /
 * `@#<pin>:spice_get_voltage` / `@spice_get_diff_voltage` /
 * `@spice_get_current[_<param>]`, with or without a trailing (...) argument -- and
 * sets one of these two bits, so the annot_show mask owns the node voltages and
 * branch currents XSCHEM's native OP back-annotation paints. Before 0614 bit1 gated
 * `hide=voltage` and NOTHING ELSE (that token appears in zero shipped .sym/.sch), so
 * `6` and `Alt-6` rendered byte-identically and `Ctrl-6` still painted every voltage.
 *
 * THEY ARE A SECOND NAMESPACE, NOT A REUSE OF HIDE_TEXT_VOLTAGE, and that is
 * load-bearing twice over:
 *   - text_hidden() exempts a SCHEMATIC-OWN NON-FLOATER from the implicit class only
 *     (invariant I7: measured, `T {@spice_get_voltage} ... {layer=15}` renders the
 *     LITERAL token today and must keep doing so), while an author's explicit
 *     `hide=voltage` on the same record must still follow bit1;
 *   - the COLOUR override (0615) applies to TEXT_ANNOT_VOLTAGE only: a text whose
 *     author typed `hide=voltage` chose its own `layer=` and keeps it.
 * TEXT_ANNOT_CURRENT follows bit0, ANNOT_SHOW_OP (`6`), and takes NO colour override
 * -- layer 17 `#00ffcc` in both palettes, 84 shipped records. ⚠ THAT IS ISSUE 0678
 * REVERSING HALF OF DECISION D4. 0614 read 0613's "surviving Ctrl-6" list, saw branch
 * currents in it beside the node voltages, and put both classes on bit1 -- grouping
 * them by where the number comes from in the raw. The user drove a real sky130 bench
 * on 2026-08-24 and grouped them by what the number is ABOUT: a source's branch
 * current is that DEVICE's terminal current, device OP info like a FET's id, so it
 * belongs to `6`. `Ctrl-6 -> nothing` still holds -- mask 0 clears both bits. The
 * COLOUR half of D4 was not reversed. The one place the grouping is written down is
 * annot_class_mask in actions.c; see doc/claude/issues/0678-*.md.
 * The implicit class is set ONLY when the `hide=` chain set no bit at all, so the
 * nine tracked records carrying BOTH hide=true and a bare token keep answering
 * show_hidden_texts alone (invariant I7). */
#define TEXT_ANNOT_VOLTAGE 256 /* content-classified node voltage  (visibility + colour) */
#define TEXT_ANNOT_CURRENT 512 /* content-classified branch current (visibility only)   */
/* the annot_show mask bits (xctx->annot_show, MIRRORED IN TCL as ::annot_show) */
#define ANNOT_SHOW_OP 1
#define ANNOT_SHOW_VOLTAGE 2
/* S9: the font the draw-time OP-annotation overlay renders in, needed by all three
 * back ends. Lifted verbatim from the shipped carrier xschem_library/devices/
 * annotate_params.sym (font=Monospace) so carrier and overlay look identical side
 * by side. Its size/layer siblings travel through get_annot_overlay() instead. */
#define ANNOT_OVERLAY_FONT "Monospace"
/* text_hidden() context. The ten former copy-pasted visibility tests were not ten
 * copies of one test but TWO tests: the six iterating a SYMBOL's text masked
 * (HIDE_TEXT | HIDE_TEXT_INSTANTIATED), the four iterating the schematic's own text
 * masked HIDE_TEXT alone. That difference IS the meaning of hide=instance -- hidden
 * through an instance, visible while editing the symbol itself -- so the predicate
 * takes the context rather than folding both into one mask. */
#define TEXT_CTX_SCHEMATIC 0   /* iterating xctx->text[]: the schematic's own texts */
#define TEXT_CTX_INSTANCE 1    /* iterating symptr->text[]: a symbol drawn as an instance */

#define S(a) (sizeof(a)/sizeof(a[0]))
#define BUS_WIDTH 4
#define POINTINSIDE(xa,ya,x1,y1,x2,y2)  \
 (xa>=x1 && xa<=x2 && ya>=y1 && ya<=y2 )

#define RECT_INSIDE(xa,ya,xb,yb,x1,y1,x2,y2)  \
 (xa>=x1 && xa<=x2 && xb>=x1 && xb<=x2 && ya>=y1 && ya<=y2 && yb>=y1 && yb<=y2 )

#define RECT_OUTSIDE(xa,ya,xb,yb,x1,y1,x2,y2)  \
( (xa) > (x2) || (xb) < (x1) || (ya) > (y2) || (yb) < (y1) )

#define RECT_TOUCH(xa,ya,xb,yb,x1,y1,x2,y2)  (!(xa > x2 || xb < x1 || ya > y2 || yb < y1))

/* ASE waveform-viewer strip drag-reorder affordance, in SCREEN PIXELS (fixed
 * regardless of canvas zoom, so the target stays usable at any zoom level).
 * GRAPH_REORDER_HANDLE_W is the width of the grab zone at the strip's right
 * edge; GRAPH_REORDER_DROPBAR_H the thickness of the transient drop-destination
 * bar. MIRRORED IN TCL: wviewer::strip_handle_at_pixel / the drag feedback in
 * src/wave_viewer.tcl -- change both or the drawn grip and the hit-test drift
 * apart. doc/claude/specs/waveform_viewer_modes.md */
#define GRAPH_REORDER_HANDLE_W  14
#define GRAPH_REORDER_DROPBAR_H  4
/* thickness of the frame that marks the strip a dragged TRACE would land in
 * (`reorder_handle=4`, transient drag feedback like the drop bar above) */
#define GRAPH_TRACE_DROP_W       3

/* How close, in SCREEN PIXELS, a canvas pixel has to be to a drawn trace for
 * that trace to be PICKED -- the one number every trace-picking surface on a
 * strip shares (issue 0174). Point-to-segment distance through the engine's own
 * transform (graph_wave_at, draw.c), so it is a real distance and NOT scaled by
 * canvas zoom: the distance itself already carries xctx->mooz.
 *
 * Four surfaces answer with it and MUST keep agreeing -- three picking surfaces
 * on one strip disagreeing about "close enough" is the next bug report:
 *   - the LMB wave-bold click            (callback.c, the waves_callback arm)
 *   - the RMB trace context menu         (wviewer::trace_menu_pick)
 *   - the LMB trace drag between strips  (wviewer::strip_drag_press)
 *   - the RMB strip menu's negative gate (wviewer::strip_menu_pick)
 * MIRRORED IN TCL as the `{tol 10}` proc defaults of wviewer::trace_at and
 * wviewer::near_wave_at (src/wave_viewer.tcl) and as the documented default of
 * `xschem get graph_trace_at` / `graph_near_wave` -- change all of them together.
 *
 * ⚠ NOT GRAPH_CLICK_TOL (callback.c, 3.0). That one is the click-vs-drag TRAVEL
 * test and is compared in WORLD units (`* xctx->zoom`); it is a different
 * question and the double-click interlock depends on it unchanged. */
#define GRAPH_TRACE_PICK_TOL  10.0

/* How many traces of ONE strip can be selected at once (issue 0175, Ctrl+click
 * multi-select). The cap is on the SELECTED COUNT, not on the node index: the
 * selection lives in a fixed-size array inside Graph_ctx, so node 200 of a strip
 * can be selected while only 64 traces can be selected together.
 *
 * ⚠ Fixed array, deliberately NOT a malloc'ed pointer. SIX call sites build a
 * LOCAL Graph_ctx and let it die on return (graph_plotbox_at, graph_point_at,
 * graph_marker_at, graph_marker_create, graph_marker_drag_to in draw.c/callback.c
 * and raw_read's gr_ctx in save.c); a pointer field would leak on every one of
 * them, once per hover motion event. 64 ints is 256 bytes on a struct that has
 * one global instance and a handful of stack ones.
 *
 * A bitmask (the option not taken) would have capped the node INDEX at 32 and
 * silently mis-rendered node 40 -- see doc/claude/issues/0175-*.md D1. */
#define GRAPH_MAX_SEL_WAVES     64

/* Waveform markers (doc/claude/specs/graph_markers.md). GRAPH_MARKER_TOL is
 * SCREEN PIXELS, fixed regardless of canvas zoom, like the reorder handle
 * above. It lives in the header (not draw.c) because graph_marker_press() in
 * callback.c needs it -- callback.c's own GRAPH_CLICK_TOL is file-private.
 * MIRRORED in tests/headless/test_wave_markers.tcl.
 *
 * ⚠ There is NO creation tolerance here, deliberately (issue 0188). What gates
 * `m` / `d` is the strip's PLOT BOX -- graph_plotbox_at() in draw.c, the same
 * gate the item-9 diamond snap cursor uses -- and the sample is then picked
 * with graph_point_at(..., 1e30, ...), i.e. the nearest trace however far. A
 * proximity threshold here would put the key and the diamond back in
 * disagreement about where a marker can be created. */
#define GRAPH_MARKERS_MAX      512  /* max marker records per graph rect */
#define GRAPH_MARKER_TOL       8.0  /* anchor/label grab radius on a press */

/* The marker SELECTION is a SET (issue 0189). Bound it in the header because
 * draw.c holds the array and callback.c copies it. 8 is headroom: the
 * double-click builds one or two, and the cap exists so the field can be a
 * FIXED array -- xctx is reset, never freed, at clear_drawing() and
 * alloc_xschem_data(), and a pointer would add a free path for nothing.
 * NOT mirrored in Tcl: Tcl reads the list from `xschem get
 * graph_marker_sel_set` and never needs the cap. */
#define GRAPH_MARKER_MAX_SEL     8

/* How many traces one MULTI-TRACE drag can PREVIEW at once (issue 0192,
 * doc/claude/specs/waveform_viewer_modes.md 19). Matches GRAPH_MAX_SEL_WAVES
 * because the set is derived from the trace selection.
 * FIXED arrays in xctx, never pointers: xctx is reset, not freed, at
 * clear_drawing() and alloc_xschem_data(), and a pointer would add a free path
 * for nothing (the GRAPH_MARKER_MAX_SEL reasoning above).
 * The cap bounds the PREVIEW only -- the move itself is uncapped, so the worst
 * case of an over-long selection is that the 65th carried trace is drawn full
 * size while it travels. Refusing the gesture over a cosmetic limit would be a
 * functional regression.
 * NOT mirrored in Tcl: Tcl reads the list back from `xschem get
 * graph_preview_set` and never needs the cap (the GRAPH_MARKER_MAX_SEL rule). */
#define GRAPH_MAX_PREVIEW_WAVES  64

/* NET-HIGHLIGHT STYLES ON WAVEFORM TRACES
 * (doc/claude/specs/wave_trace_hilight.md). How many traces of a window can
 * carry a highlight style at once. A trace is a polyline with no junctions and
 * no direction, so the whole net-highlight vocabulary -- colour, width, dash,
 * blink, marching ants -- applies to it unchanged; the SET of highlighted
 * traces lives in xctx as three parallel FIXED arrays (the
 * GRAPH_MARKER_MAX_SEL rule: xctx is reset, never freed, at clear_drawing()
 * and alloc_xschem_data(), and a pointer would add a free path for nothing).
 * 16 is the user-facing cap the viewer refuses past, with one CIW line.
 * MIRRORED IN TCL: tests/headless/test_wave_hilight.tcl asserts the refusal at
 * exactly this number, and reads it out of this header rather than freezing a
 * copy (landmine 45(a): a value copied to a second seam drifts silently). */
#define GRAPH_MAX_HILIGHT_WAVES  16

/* Axis-region drag zoom (issue 0190,
 * doc/claude/specs/waveform_viewer_modes.md §17). Which axis-number margin of a
 * strip a canvas pixel is in -- the BOTTOM margin owns X, the LEFT margin owns
 * Y. Not a bitmask: a pixel is in at most one of them (the bottom-left corner
 * answers Y, matching the shipped RMB left-margin arm, which tests graph_left
 * first and never consults graph_bottom). */
#define GRAPH_AXIS_NONE 0
#define GRAPH_AXIS_X    1
#define GRAPH_AXIS_Y    2
/* Upper bound on the ZOOM-OUT factor of one drag. A reverse drag scales the
 * window by 1/|s| where s is the drag span as a fraction of the plot extent, so
 * s -> 0 is 1/0. The 3-px click threshold normally binds first (max factor ~
 * plot_width/3); this is the backstop that keeps an inf out of the x1/x2 tokens,
 * where it would be permanent. NOT mirrored in Tcl -- no Tcl code computes the
 * map (that is the whole point of graph_axis_map). */
#define GRAPH_AXIS_ZOOM_MAX_FACTOR 1000.0

/* Range MULTIPLIER of one CTRL+wheel click in an axis-number margin (issue
 * 0191, doc/claude/specs/waveform_viewer_modes.md §18). Wheel-up multiplies the
 * axis window by this; wheel-down divides by it, so N clicks in followed by N
 * clicks out restore the window EXACTLY -- unlike the shipped Shift+wheel arms
 * (callback.c), whose 0.2-of-the-range step is x0.8 in / x1.2 out and loses 4%
 * per round trip.
 * ⚠ MIRRORED IN TCL: wviewer::wheel_zoom's `f` (src/wave_viewer.tcl) carries the
 * same literal because the viewer's BODY zoom still computes its own window with
 * wviewer::zoom_about. Change BOTH -- tests/headless/test_wave_axis_zoom.tcl CS2
 * reads the two out of source and asserts they are equal. */
#define GRAPH_AXIS_WHEEL_FACTOR 0.8

/* xctx->graph_marker_dragmode -- the EFFECTIVE mode of an armed gesture,
 * latched at PRESS TIME from the selection state and never re-read afterwards.
 * xctx->graph_marker_drag keeps its original meaning, "what was GRABBED"
 * (0/1/2), because `xschem get graph_marker_drag`, wviewer::marker_grabbed and
 * wviewer::strip_drag_release all read it; THIS says what the gesture DOES,
 * which since the selected-text drag is no longer the same question. */
#define GRAPH_MARKER_MODE_NONE   0
#define GRAPH_MARKER_MODE_ANCHOR 1  /* slide the anchor along its own trace */
#define GRAPH_MARKER_MODE_LABEL  2  /* move the callout; the anchor stays put */
#define GRAPH_MARKER_MODE_RIGID  3  /* SELECTED + text drag: translate the whole
                                     * marker; the label offset is frozen */

#define ROTATION(rot, flip, x0, y0, x, y, rx, ry) \
{ \
  double xxtmp = (flip ? 2 * x0 -x : x); \
  if(rot==0)      {rx = xxtmp;  ry = y;} \
  else if(rot==1) {rx = x0 - y + y0; ry = y0 + xxtmp - x0;} \
  else if(rot==2) {rx = 2 * x0 - xxtmp; ry = 2 * y0 - y;} \
  else            {rx = x0 + y - y0; ry = y0 - xxtmp + x0;} \
}

#define ORDER(x1,y1,x2,y2) {\
  double xxtmp; \
  if(x2 < x1) {xxtmp=x1;x1=x2;x2=xxtmp;xxtmp=y1;y1=y2;y2=xxtmp;} \
  else if(x2 == x1 && y2 < y1) {xxtmp=y1;y1=y2;y2=xxtmp;} \
}

#define RECTORDER(x1,y1,x2,y2) { \
  double xxtmp; \
  if(x2 < x1) {xxtmp = x1; x1 = x2; x2 = xxtmp;} \
  if(y2 < y1) {xxtmp = y1; y1 = y2; y2 = xxtmp;} \
}

#define INT_RECTORDER(x1,y1,x2,y2) { \
  int xxtmp; \
  if(x2 < x1) {xxtmp = x1; x1 = x2; x2 = xxtmp;} \
  if(y2 < y1) {xxtmp = y1; y1 = y2; y2 = xxtmp;} \
}


#define LINE_OUTSIDE(xa,ya,xb,yb,x1,y1,x2,y2) \
 (xa>=x2 || xb<=x1 ||  ( (ya<yb)? (ya>=y2 || yb<=y1) : (yb>=y2 || ya<=y1) ) )

#define CLIP(x,a,b) (((x) < (a)) ? (a) : ((x) > (b)) ? (b) : (x))

#define MINOR(a,b) ( (a) <= (b) ? (a) : (b) )
#define MAJOR(a,b) ( (a) >= (b) ? (a) : (b) )

/* "show_label" type symbols are used for any type of symbol that
 * must be automatically highlighted by attached nets 
 * show_label also used on metal option type symbols (pass-through symbols) 
 * to optionally short two nets (using *_ignore=[true|false] attribute) */
#define IS_LABEL_SH_OR_PIN(type) (!(strcmp(type,"label") && strcmp(type,"ipin") && strcmp(type,"opin") && \
      strcmp(type,"scope") && strcmp(type,"show_label") && strcmp(type,"iopin") && strcmp(type,"bus_tap")))
#define IS_LABEL_OR_PIN(type) (!(strcmp(type,"label") && strcmp(type,"ipin") && \
                                 strcmp(type,"opin") && strcmp(type,"iopin")))
#define IS_PIN(type) (!(strcmp(type,"ipin") && strcmp(type,"opin") && strcmp(type,"iopin")))
/* issue 0498: instance n has no resolved symbol (xctx->inst[n].ptr < 0), which happens
 * whenever a load_schematic() with load_symbols=0 (the *_stop=true arm of the netlisters)
 * or a remove_symbols() leaves the instance array pointing at nothing. Dereferencing
 * xctx->sym[xctx->inst[n].ptr] then reads xctx->sym[-1] and SEGFAULTS -- measured at
 * hilight.c draw_hilight_net(). Test the flag BEFORE the deref, never after.
 * See doc/claude/issues/0498-leaked-keep-symbols-across-a-load-segfaults-the-c-core.md */
#define INST_UNBOUND(n) (xctx->inst[n].ptr < 0)
#define XSIGN(x) ( (x) < 0 ? -1 : 1)
#define XSIGN0(x) ( (x) < 0 ? -1 : (x) > 0 ? 1 : 0)

/* floor not needed? screen coordinates always positive <<<< */
/* #define X_TO_SCREEN(x) ( floor(((x)+xctx->xorigin)* xctx->mooz) ) */
/* #define Y_TO_SCREEN(y) ( floor(((y)+xctx->yorigin)* xctx->mooz) ) */
#define X_TO_SCREEN(x) ( ((x) + xctx->xorigin) * xctx->mooz )
#define Y_TO_SCREEN(y) ( ((y) + xctx->yorigin) * xctx->mooz )
#define X_TO_XSCHEM(x) ( (x) * xctx->zoom - xctx->xorigin )
#define Y_TO_XSCHEM(y) ( (y) * xctx->zoom - xctx->yorigin )

/* coordinate transformations graph to xschem */
#define W_X(x) (gr->cx * (x) + gr->dx)
#define W_Y(y) (gr->cy * (y) + gr->dy)
/* for digital waves */
#define DW_Y(y) (gr->dcy * (y) + gr->ddy)

/* coordinate transformations graph to screen */
#define S_X(x) (gr->scx * (x) + gr->sdx)
#define S_Y(y) (gr->scy * (y) + gr->sdy)
/* for digital waves */
#define DS_Y(y) (gr->dscy * (y) + gr->dsdy)

/* inverse graph transforms */
#define G_X(x) (((x) - gr->dx) / gr->cx)
#define G_Y(y) (((y) - gr->dy) / gr->cy)
/* inverse SCREEN transforms (screen pixel -> graph value). Still log-space when
 * gr->logx/logy: pow(10, ...) is the caller's job, exactly as mylog10() is on
 * the way in -- landmine 35 (a stored value is never log-mapped). */
#define GS_X(x) (((x) - gr->sdx) / gr->scx)
#define GS_Y(y) (((y) - gr->sdy) / gr->scy)
/* for digital graphs (gr->ypos1, gr->ypos2 instead of gr->gy1, gr->gy2) */
#define DG_Y(y) (((y) - gr->ddy) / gr->dcy)


/* given a dest_string of size 'size', allocate space to make sure it can
 * hold 'add' characters */
#define  STR_ALLOC(dest_string, add, size) \
do { \
  register size_t __str_alloc_tmp__ = add; \
  if( __str_alloc_tmp__ >= *size) { \
    *size = __str_alloc_tmp__ + CADCHUNKALLOC; \
    my_realloc(_ALLOC_ID_, dest_string, *size); \
  } \
} while(0)

#define SWAP(a,b, tmp) do { tmp = a; a = b; b = tmp; } while(0)

#define XLINEWIDTH(x) MAJOR((xctx->change_lw ? \
   ((int)(x) == 0 ? 1 : (int)(x)) : \
   (int)(x)), xctx->min_lw)
#define INT_LINE_W(x) MAJOR(((int)(x) == 0 ? 1 : (int)(x)), xctx->min_lw)
#define INT_BUS_WIDTH(x) MAJOR((xctx->change_lw ? \
   ((int)( (BUS_WIDTH) * (x) ) == 0 ? 1 : (int)((BUS_WIDTH) * (x))) : \
   (int)((BUS_WIDTH) * (x)) ), xctx->min_lw)

/* set do double if you need more precision at the expense of memory */
#define SPICE_DATA double
#define SPICE_DATA_TYPE 1 /* Use 1 for float, 2 for double */
#define DIG_NWAVES 0.1  /* inverse number: by default 10 digital traces per graph */
#define DIG_SPACE 0.07 /* trace extends from 0 to DIG_SPACE, so we have DIG_WAVES-DIG_SPACE
                        * spacing between traces */
#define LINECAP CapRound /* CapNotLast, CapButt, CapRound, or CapProjecting */
#define LINEJOIN JoinRound /* JoinMiter, JoinRound, or JoinBevel */
typedef struct
{
  unsigned short type;
  int n;
  unsigned int col;
} Selected;

/* One member of the object set a modal cursor PLACEMENT is made of (issue 0241). `type` is the
 * sel_array type constant (ELEMENT / WIRE / xTEXT / xRECT / LINE / POLYGON / ARC), `id` the
 * matching session-stable object id. Deliberately NOT a Selected: array indexes are meaningless
 * across the arbitrary edits the MODELESS Add-Pin / Add-Wire-Label forms allow between the arm
 * and the cancel, while ids survive them (and survive an undo, xschem.h id fields / select.c
 * selection-across-undo). Resolved back through the *_index_from_id() family in store.c. */
typedef struct
{
  unsigned short type;
  unsigned int id;
} PlacePreview;

/* Hover fly-line query result (doc/claude/specs/hover_flylines.md). One geometry member on a
 * queried net: a wire (kind 0) or an instance pin (kind 1). idx = wire/instance index, pin =
 * pin index (-1 for a wire), (x,y) = wire midpoint or pin coord. */
typedef struct { int kind; int idx; int pin; double x, y; } FlyMember;

/* Computed fly-line set for one net, produced by flyline_compute() (flyline.c) and consumed by
 * both the `xschem flylines` query (scheduler.c) and the on-screen overlay (draw_flylines).
 * Pure read-only product (invariant C1): describes geometry, never mutates it. Release with
 * flyline_result_free(). */
typedef struct {
  char *net;                      /* net name (my_strdup'd), NULL when no net resolved */
  int is_global;                  /* net is a global/bang net (vdd!/gnd!/0) */
  int capped;                     /* star truncated to flylines_cap nearest clusters */
  FlyMember *mem;                 /* member geometry, build order */
  int nmem;
  int *clu;                       /* nmem entries: cluster ordinal per member */
  int nclu;                       /* number of physical clusters */
  double *cx, *cy;                /* nclu entries: per-cluster anchor coords */
  int hub;                        /* hub cluster ordinal (hovered cluster, else 0) */
  double *sx1, *sy1, *sx2, *sy2;  /* nseg entries: star segment endpoints (world coords) */
  int nseg;
} FlyResult;

typedef struct
{
  double x1;
  double x2;
  double y1;
  double y2;
  short  end1;
  short  end2;
  short sel;
  char  *node;
  char *prop_ptr;
  double bus; /*  20171201 cache here wire "bus" property, to avoid too many get_tok_value() calls */
  int flags; /* stores the *_ignore flags, see xInstance */
  unsigned int id; /* session-stable identity, stamped at birth in store.c (wire_store /
                    * wire_store_split), never reused within a context's lifetime.
                    * Not persisted in .sch files. 0 = never stamped (no live wire has 0). */
} xWire;

typedef struct
{
  double x1;
  double x2;
  double y1;
  double y2;
  unsigned short sel;
  char *prop_ptr;
  short dash;
  double bus;
  unsigned int id; /* session-stable identity, stamped at birth (gfx_register),
                    * never reused within a context's lifetime, not persisted.
                    * Shared id space with rect/poly/arc. 0 = never stamped. */
} xLine;

#if HAS_CAIRO==1

typedef struct
{
        unsigned char* buffer;
        size_t pos;
        size_t size;
} png_to_byte_closure_t;

typedef struct
{
  cairo_surface_t *image;
} xEmb_image;
#endif

typedef struct
{
  double x1;
  double x2;
  double y1;
  double y2;
  unsigned short sel;
  char *prop_ptr;
  void *extraptr; /* generic data pointer (images) */
  short fill; /* 0: no fill, 1: stippled fill, 2: solid fill */
  short dash;
  double bus;
  int ellipse_a, ellipse_b;
  /* bit0=1 for graph function, bit1=1 for unlocked x axis
   * bit10: image embedding (png)
   */
  unsigned short flags;
  unsigned int id; /* session-stable identity, stamped at birth (gfx_register),
                    * never reused within a context's lifetime, not persisted.
                    * Shared id space with line/poly/arc. 0 = never stamped. */
} xRect;

typedef struct
{
  /*  last point coincident to first, added by program if needed. */
  /*  XDrawLines needs first and last point to close the polygon */
  int points;
  double *x;
  double *y;
  unsigned short *selected_point;
  unsigned short sel;
  char *prop_ptr;
  short fill;
  short dash;
  double bus;
  unsigned int id; /* session-stable identity, stamped at birth (gfx_register),
                    * never reused within a context's lifetime, not persisted.
                    * Shared id space with rect/line/arc. 0 = never stamped. */
} xPoly;

typedef struct
{
  double x;
  double y;
  double r;
  double a; /* start angle */
  double b; /* arc angle */
  unsigned short sel;
  char *prop_ptr;
  short fill;
  short dash;
  double bus;
  unsigned int id; /* session-stable identity, stamped at birth (gfx_register),
                    * never reused within a context's lifetime, not persisted.
                    * Shared id space with rect/line/poly. 0 = never stamped. */
} xArc;

typedef struct
{
  char *txt_ptr;
  char *floater_ptr; /* cached value of translated text for floaters (avoid calls to translate() */
  double x0,y0;
  short rot;
  short flip;
  short sel;
  double xscale;
  double yscale;
  char *prop_ptr;
  char *floater_instname; /* cached value of floater=... attribute in prop_ptr */
  int layer; /*  20171201 for cairo  */
  short hcenter, vcenter;
  char *font; /*  20171201 for cairo */
  int flags; /* bit 0 : TEXT_BOLD
              * bit 1 : TEXT_OBLIQUE
              * bit 2 : TEXT_ITALIC
              * bit 3 : HIDE_TEXT
              * bit 4 : TEXT_FLOATER
              * bit 5 : HIDE_TEXT_INSTANTIATED
              * bit 6 : HIDE_TEXT_OP        (annotation class, gated by annot_show)
              * bit 7 : HIDE_TEXT_VOLTAGE   (annotation class, gated by annot_show)
              * bit 8 : TEXT_ANNOT_VOLTAGE  (implicit content class: node voltage,
              *                              gated by annot_show, painted in
              *                              annot_voltage_layer -- issues 0614/0615)
              * bit 9 : TEXT_ANNOT_CURRENT  (implicit content class: branch current,
              *                              gated by annot_show BIT0 -- device OP
              *                              info, issue 0678 -- keeps its own layer)
              * recomputed by set_text_flags() from prop_ptr AND from txt_ptr (bits 8/9
              * carry the implicit content class, issues 0614/0678), never serialised */
  unsigned int id; /* session-stable identity, stamped at birth in store.c
                    * (text_register), never reused within a context's lifetime,
                    * not persisted in .sch files. 0 = never stamped. text is
                    * pure annotation — the id is only a handle, no role change. */
  unsigned int owner_pin_id; /* 0 = ordinary text. !=0 => this is a SYNTHESIZED, transient
                    * "pin name view": an editable in-memory text materialized from a
                    * symbol PINLAYER pin's name + name_* layout tokens (Option B; see
                    * doc/claude/specs/cadence_pin_name_text.md). Value = the owning pin's
                    * xRect.id. NOT persisted (save_text() skips it) and regenerated on
                    * load by synth_pin_views(); rides struct-copy through undo/copy. */
} xText;

typedef struct
{
  char *name;
  const char *base_name; /* points to the base symbol name this symbol is inherited from
                          * (schematic attribute set on instances, create "virtual" symbol) */
  double minx;
  double maxx;
  double miny;
  double maxy;
  xLine **line;  /*  array of [cadlayers] pointers to Line */
  xRect  **rect;
  xPoly **poly;
  xArc **arc;
  xText  *text;
  int *lines;     /*  array of [cadlayers] integers */
  int *rects;
  int *polygons;
  int *arcs;
  int texts;
  char *prop_ptr;
  char *type;
  char *templ;
  char *parent_prop_ptr;
  int flags;   /* bit 0: embedded flag 
                * bit 1: **free**
                * bit 2: HILIGHT_CONN, highlight if connected net/label is highlighted
                * bit 3: HIDE_INST, hidden instance, show only bounding box (hide=true attribute)
                * bit 4: SPICE_IGNORE, spice_ignore=true
                * bit 5: VERILOG_IGNORE, verilog_ignore=true
                * bit 6: VHDL_IGNORE, vhdl_ignore=true
                * bit 7: TEDAX_IGNORE, tedax_ignore=true
                * bit 8: IGNORE_INST, instance must be ignored based on *_ignore=true and netlisting mode.
                *        used in draw.c
                * bit 9: HIDE_SYMBOL_TEXTS, hide_texts=true on instance (not used in symbol, but keep free)
                * bit 10: LVS_IGNORE_SHORT: short together all nets connected to symbol if lvs_ignore tcl var set
                * bit 11: LVS_IGNORE_OPEN: remove symbol leaving all connected nets open if lvs_ignore tcl var set
                */

} xSymbol;

typedef struct
{
  char *name;/*  symbol name (ex: devices/lab_pin)  */
  int ptr;   /*  was a pointer formerly... */
  double x0;  /* symbol origin / anchor point */
  double y0;
  double x1;  /* symbol bounding box */
  double y1;
  double x2;
  double y2;
  double xx1; /* bounding box without texts */
  double yy1;
  double xx2;
  double yy2;
  short rot;
  short flip;
  short sel;
  unsigned char *pin_sel; /* NULL, or a lazily-allocated array of length pin_sel_size:
                           * pin_sel[j]!=0 => pin j of this instance is selected.
                           * Transient selection state, NOT saved, NOT in .sch. Mirrors
                           * xPoly.selected_point but is deliberately INDEPENDENT of the
                           * .sel field (pins are inert in edits). See
                           * doc/claude/specs/pin_selection.md */
  int pin_sel_size;       /* allocated length of pin_sel (== symbol PINLAYER pin count
                           * at alloc time). Lets every consumer bound its scan so a
                           * later symbol pin-count change can never OOB-read pin_sel. */
  short embed; /* cache embed=true|false attribute in prop_ptr */
  int color; /* hilight color */
  int buried_hilight; /* style index of a highlighted net buried in this instance's
                       * subtree (a net not exposed at this instance's pins), -1 = none.
                       * Derived state: recomputed from xctx->hilight_table in
                       * propagate_hilights(); read-only at draw time. Stamped to -1 at
                       * birth in inst_register(). See doc/claude/specs/buried_net_hilight.md */
  int flags;   /* bit 0: skip field, set to 1 while drawing layer 0 if symbol is outside bbox
                *        to avoid doing the evaluation again.
                * bit 1: flag for different textlayer for pin/labels,
                *        1: ordinary symbol, 0: label/pin/show 
                * bit 2: HILIGHT_CONN, highlight if connected net/label is highlighted
                * bit 3: HIDE_INST, hidden instance, show only bounding box (hide=true attribute)
                * bit 4: SPICE_IGNORE, spice_ignore=true
                * bit 5: VERILOG_IGNORE, verilog_ignore=true
                * bit 6: VHDL_IGNORE, vhdl_ignore=true
                * bit 7: TEDAX_IGNORE, tedax_ignore=true
	        * bit 8: IGNORE_INST, instance must be ignored based on *_ignore=true and netlisting mode.
                *        used in draw.c
	        * bit 9: HIDE_SYMBOL_TEXTS, hide_texts=true (hide_texts=true attribute on instance)
                * bit 10: LVS_IGNORE_SHORT: short together all nets connected to symbol if lvs_ignore tcl var set
                * bit 11: LVS_IGNORE_OPEN: remove symbol leaving all connected nets open if lvs_ignore tcl var set
                */
  char *prop_ptr;
  char **node;
  char *lab;      /*  lab attribute if any (pin/label) */
  char *instname; /*  20150409 instance name (example: I23)  */
  unsigned int id; /* session-stable identity, stamped at birth in store.c
                    * (inst_register), never reused within a context's lifetime.
                    * The canonical durable session handle (the name is the
                    * human / cross-session form, reusable+renamable — see
                    * doc/claude/code_analysis/instance_identity_decision.md). Not persisted
                    * in .sch files. 0 = never stamped (no live instance has 0). */
} xInstance;

typedef struct
{
  double x;
  double y;
  double zoom;
} Zoom;

typedef struct /* used to sort schematic pins (if no asssociated symbol exists) */
{ 
  int n;
  int pinnumber;
} Sch_pin_record;


typedef struct
{
  char *function;
  char *go_to;
  int value;
  short clock;
} Simdata_pin;
 
typedef struct
{
  Simdata_pin *pin;
  int npin;
} Simdata;

typedef struct
{
  char     *gptr;
  char     *vptr;
  char     *sptr;
  char     *fptr; /* spectre global attr */
  char     *kptr;
  char     *eptr;
  int *lines;
  int *rects;
  int *polygons;
  int *arcs;
  int wires;
  int texts;
  int instances;
  int symbols;
  xLine     **lptr;
  xRect      **bptr;
  xPoly  **pptr;
  xArc      **aptr;
  xWire     *wptr;
  xText     *tptr;
  xInstance *iptr;
  xSymbol *symptr;
} Undo_slot;

/* Side-channel snapshot of the session-stable object ids for ONE disk-undo slot.
 * Disk undo serializes via write_xschem_file / read_xschem_file, and the store
 * funnels re-stamp FRESH ids on the read -- which would silently break the
 * net-hilight apply-scope overlay and every live `xschem object` handle (issue
 * 0043; the in-memory undo path preserves ids because it struct-copies .id).
 * push_undo captures the live ids here in canonical save-order; pop_undo re-stamps
 * them onto the restored objects, so ids survive the disk round-trip. Ids are NOT
 * baked into the .sch/.sym format (that would bump XSCHEM_FILE_VERSION and touch
 * every reader). Positional: the k-th object written to a slot is the k-th read
 * back (read_xschem_file appends verbatim, no merge/reorder). */
typedef struct {
  unsigned int *wire_id;  int n_wire;
  unsigned int *inst_id;  int n_inst;
  unsigned int *text_id;  int n_text;   /* non-synthesized texts only, in save-order */
  unsigned int *gfx_id;   int n_gfx;    /* rect+line+poly+arc, canonical type/layer/index order */
  int valid;                            /* 1 once captured by push_undo */
} Undo_ids;

typedef struct
{ /* used for symbols containing schematics as instances (LCC, Local Custom Cell) */
  double x0;
  double y0;
  short rot;
  short flip;
  FILE *fd;
  char *prop_ptr;
  char *templ;
  char *symname;
  char *sym_extra;
} Lcc;

typedef struct {
  int in;
  int out;
  int inout;
  int port;
} Drivers;


/* generic string hash table */

typedef struct str_hashentry Str_hashentry;
struct str_hashentry
{
  struct str_hashentry *next;
  unsigned int hash;
  char *token;
  char *value;
};

typedef struct {
  Str_hashentry **table;
  int size;
} Str_hashtable;

/* generic int hash table */
typedef struct int_hashentry Int_hashentry;
struct int_hashentry
{
  struct int_hashentry *next;
  unsigned int hash;
  char *token;
  int value;
};

typedef struct {
  Int_hashentry **table;
  int size;
} Int_hashtable;

/* generic pointer hash table */
typedef struct ptr_hashentry Ptr_hashentry;
struct ptr_hashentry
{
  struct ptr_hashentry *next;
  unsigned int hash;
  char *token;
  void *value;
};

typedef struct {
  Ptr_hashentry **table;
  int size;
} Ptr_hashtable;

typedef struct node_hashentry Node_hashentry;
struct node_hashentry
{
  struct node_hashentry *next;
  unsigned int hash;
  char *token;
  char *sig_type;
  char *verilog_type;
  char *value;
  char *class;
  char *orig_tok;
  Drivers d;
};


typedef struct hilight_hashentry Hilight_hashentry;
struct hilight_hashentry
{
  struct hilight_hashentry *next;
  unsigned int hash;
  char *token;
  char *path; /* hierarchy path */
  int oldvalue;  /* used for FF simulation */
  int value;  /* >=0: net highlight style index (see NetHilightStyle); <0: sim logic level */
  int time; /*delta-time for sims */
  unsigned int seq; /* monotonic apply-order stamp, bumped each time this entry's highlight
                     * is (re)applied. Used by compute_buried_hilights() to pick the MOST
                     * RECENTLY applied buried net's style for the ancestor-instance cue.
                     * See doc/claude/specs/buried_net_hilight.md */
};

/* A user-customizable net highlight style (Cadence display.drf-like "packet").
 * The per-net hilight value (Hilight_hashentry.value / xInstance.color), when >= 0,
 * is a style index (taken modulo n_net_hilight_styles) into the style table.
 * Wires render color (color_layer or custom pixel) + width + dash; stripe angle is
 * clamped/stored but rendered flat until Pass 1.5; blink_ms/anim/rate_persec are
 * reserved for Pass 2 animation (parsed/stored but inert). The on-screen draw uses the
 * shared xctx->gc_hilight scratch GC. See doc/claude/specs/net_hilight_styles.md. */
typedef struct {
  int index;             /* style id (table order) */
  int color_layer;       /* layer index used as the draw color, or < 0 for a custom pixel */
  unsigned int color;    /* resolved X pixel, used when color_layer < 0 */
  unsigned short cr, cg, cb; /* custom color (color_layer<0) as 16-bit RGB for the cairo */
  char rgb_resolved;     /* stripe path; resolved once from .color, reset on table rebuild */
  int width;             /* thickness in wire-width units; 1 = thinnest wire */
  int dash_len;          /* number of entries in dash_arr (0 = solid) */
  char dash_arr[16];     /* compiled dash pattern for XSetDashes */
  int angle;             /* stripe tilt 0..45 deg (rendered Pass 1.5; flat for now) */
  int blink_ms;          /* blink period ms, 0 = steady (Pass 2) */
  int anim;              /* 0 none, 1 march_fwd, 2 march_rev (Pass 2) */
  int rate_persec;       /* animation rate (Pass 2) */
  double period;         /* cached dash repeat period (sum(dash_arr), odd-len doubled); computed
                          * once at build time so the ~30fps marching tick reads it O(1) instead of
                          * re-walking dash_arr per wire per frame. Read via net_hilight_dash_period. */
} NetHilightStyle;

typedef struct {
  /* spice raw file specific data */
  char **names;
  char *rawfile;
  SPICE_DATA **values;
  int nvars;
  int *npoints;
  int allpoints; /* all points of all datasets combined */
  int datasets;
  Int_hashtable table;
  char *sim_type; /* type of sim, "tran", "dc", "ac", "op", ... */
  int annot_p; /* point in raw file to use for annotating schematic voltages/currents/etc
                * this is the closest available simulated point *before* the point
                * calculated from mouse in graph */
  double annot_x; /* X point to backannotate as calculated from mouse position.
                   * need to interpolate the Y value between annot_p and annot_p + 1 */
  int annot_sweep_idx; /* index of sweep variable where cursor annotation has occurred */
  double *cursor_b_val;
  /* when descending hierarchy xctx->current_name changes, xctx->raw_schname
   * holds the name of the top schematic from which the raw file was loaded */
  char *schname;
  int level;  /* hierarchy level where raw file has been read */
  double sweep1, sweep2;
} Raw;

/*  for netlist.c */
typedef struct instpinentry Instpinentry;
struct instpinentry
{
  struct instpinentry *next;
  double x0,y0;
  int n;
  int pin;
};

typedef struct wireentry Wireentry;
struct wireentry
{
  struct wireentry *next;
  int n;
};

typedef struct instentry Instentry;
struct instentry
{
  struct instentry *next;
  int n;
};


typedef struct objectentry Objectentry;
struct objectentry
{ 
  struct objectentry *next;
  int type;
  int n;
  int c;
};
  

typedef struct 
{
  int x1a, x2a;
  int y1a, y2a;
  int i, j, counti, countj;
  int tmpi, tmpj;
  Instentry *instanceptr;
  Wireentry *wireptr;
  Objectentry *objectptr;
  unsigned short *instflag;
  unsigned short *wireflag;
  unsigned short *objectflag;
} Iterator_ctx;


/* context struct for waveform graphs */
typedef struct {
  int digital;
  int legend; /* display graph legend */
  int vlegend; /* vertical legend */
  double rx1, ry1, rx2, ry2, rw, rh; /* container rectangle, xschem coordinates */
  double sx1, sy1, sx2, sy2; /* screen coordinates of above */
  /* graph box (smaller than rect container due to margins) in xschem coordinates*/
  double x1, y1, x2, y2, w, h;
  /* the following are the x1, x2, y1, y2 rectangle attributes */
  double gx1, gy1, gx2, gy2, gw, gh;
  double master_gx1, master_gx2, master_gw, master_cx;
  /* y area range for digital graphs */
  double ypos1, ypos2, posh;
  double marginx; /* will be recalculated later */
  double marginy; /* will be recalculated later */
  /* coefficients for graph to container coordinate transformations W_X() and W_Y()*/
  double cx, dx, cy, dy;
  /* y-axis transform for digital graphs */
  double dcy, ddy;
  /* direct graph->screen transform */
  double scx, sdx, scy, sdy;
  double dscy, dsdy;
  int divx, divy;
  int subdivx, subdivy;
  double magx, magy, maglegend;
  double unitx, unity;
  int unitx_suffix; /* 'n' or 'u' or 'M' or 'k' ... */
  int unity_suffix;
  int mode; /* default:0   0:Line, 1:HistoV, 2:HistoH */
  double txtsizelab, digtxtsizelab, txtsizey, txtsizex, txtsizelegend;
  int dataset;
  int hilight_wave; /* NODE index of the FIRST selected wave, -1 = none. Prop token
                     * `hilight_wave`. Since issue 0175 this is the head of a
                     * possibly longer selection (sel_wave[] below) and NOT the
                     * whole of it -- read it through wave_is_hilighted(), never
                     * with a bare `== wcnt`, or a Ctrl-selected second trace
                     * renders thin. Its grammar and its -1 sentinel are
                     * UNCHANGED, which is what keeps every existing .sch and
                     * every older build reading this rect correctly. */
  int sel_wave[GRAPH_MAX_SEL_WAVES]; /* issue 0175: the WHOLE selection, NODE indices,
                     * ascending, no duplicates. Prop token `sel_waves` ("0 2"),
                     * written ONLY when two or more traces are selected -- a 0- or
                     * 1-element selection is expressed entirely by hilight_wave, so
                     * a strip that was never Ctrl-clicked serialises byte-identically
                     * to pre-0175 (the `active`/`markers` absent-means-absent rule).
                     * n_sel_waves == 0 means "no list": fall back to hilight_wave. */
  int n_sel_waves;
  int logx, logy;
  int rainbow; /* draw multiple datasets with incrementing colors */
  double linewidth_mult; /* multiply factor for waveforms line width */
  double hcursor1_y, hcursor2_y; /* hcursor positions */
  int active; /* issue 0151: this graph is the ASE viewer's TARGET strip (prop token
               * `active=1`) -> draw_graph paints the dull-yellow right-edge marker.
               * Only the waveform viewer ever writes the token, so ordinary
               * schematic graphs are unaffected. */
  int reorder_handle; /* strip drag-reorder affordance (prop token `reorder_handle`),
                       * written by the ASE viewer only:
                       *   1 = draw the grip in the right margin (every viewer strip)
                       *   2 = grip + a drop bar along the strip's TOP edge
                       *   3 = grip + a drop bar along the strip's BOTTOM edge
                       * 2/3 are TRANSIENT drag feedback (prospective destination).
                       * Like `active`, on-screen only (draw_graph flags bit 16).
                       * doc/claude/specs/waveform_viewer_modes.md */
  int grid;       /* viewer plan item 3: 0 = do not draw this graph's dashed
                   * GRID LINES. Prop token `grid`, written by the ASE viewer
                   * only (Ctrl-G). The axes, the box, the tick marks, the axis
                   * NUMBERS and the zero lines are NOT part of this -- turning
                   * the grid off must leave the plot readable, so only the
                   * dashed interior lines go. Defaults to 1, and like the
                   * tokens below it must be set before the RECT_OUTSIDE early
                   * return (shared xctx->graph_struct). */
  int griddash;   /* viewer plan item 2 / decision D-B: the OFF run of the graph
                   * grid's dash pattern, in pixels, against a 1-pixel ON run.
                   * 0 = the shipped 2-on/2-off (50% duty); 3 = 1-on/3-off,
                   * which halves the lit pixels WITHOUT removing a grid line or
                   * changing its colour. Prop token `griddash`, written by the
                   * ASE viewer only -- draw_graph_grid is shared with every
                   * embedded schematic graph, so this must not be a global
                   * (same reasoning as legendbold below). */
  int legendbold; /* viewer plan item 1: draw EVERY legend entry in the bold face
                   * (prop token `legendbold=1`), written by the ASE viewer only —
                   * draw_graph_variables is shared with every embedded schematic
                   * graph in the tree, so this must not be a global. The bolded
                   * wave (issue 0152) then needs a different cue, since bold is
                   * no longer distinctive: it is drawn bold ITALIC.
                   * Unlike `active`/`reorder_handle` this is durable CONTENT,
                   * not chrome — it belongs in exports. */
  int preview_gi;   /* viewer plan item 6, widened by issue 0192: the rect index
                     * THIS draw may preview, or -1. It is NOT a node index any
                     * more -- a multi-trace drag carries a SET, so the per-trace
                     * question ("is this node being carried") moved into
                     * graph_preview_has(), leaving this field to answer only the
                     * per-graph one ("is this graph chrome-enabled at all"), so
                     * draw_graph_points does no set walk when nothing is armed.
                     * Unlike every field above it does NOT come from a prop
                     * token -- it is written by draw_graph, and only when
                     * flags & 16 (on-screen chrome), so it can never reach an
                     * export. Defaulted to -1 in setup_graph_data BEFORE the
                     * RECT_OUTSIDE early return, and that is still load-bearing
                     * (landmine 11: gr is the shared xctx->graph_struct). */
} Graph_ctx;

/* ONE CACHED TRACE ENVELOPE (doc/claude/specs/wave_trace_hilight.md §5.2).
 *
 * The whole point of the trace-highlight feature is that an ANIMATED frame
 * costs the same on a 200-sample trace and on a 200 000-sample one. That is
 * only true if the frame never walks samples, so the overlay does not stroke
 * the real polyline: it strokes a MIN/MAX ENVELOPE at one screen column per
 * pixel of the plot box, built once and cached. On a dense trace that
 * reproduces the same solid band the real draw produces; on a sparse one
 * (fewer samples than columns) it degenerates to the samples themselves and is
 * exact. Either way it is <= 2 * plotbox_width_px points.
 *
 * `pt` is the ONLY malloc in this feature. It is freed by
 * wave_hilight_cache_free(), called from clear_drawing() (actions.c) and from
 * free_xschem_data() (xinit.c). Losing the cache is a REBUILD, never a
 * behaviour change -- which is why the key can be conservative.
 *
 * THE KEY is everything a rebuild would depend on: the trace identity, the
 * data window, the plot box in screen pixels, the raw's identity+shape (a
 * `raw clear` + reload can change nvars/npoints under an unchanged (gi, ni),
 * and neither reset site fires for that) -- and THE RECT'S WHOLE `prop_ptr`.
 * That last one is not laziness: `node`, `sweep`, `%N`, `rawfile`, `sim_type`,
 * `digital`, `logx`, `logy` and `dataset` all steer the walk, they are all in
 * that one string, and it is rewritten IN PLACE by paths that never touch this
 * cache (`graph_add_nodes_from_list`, `edit_wave_attributes`, `setprop rect`).
 * One strdup per cached envelope buys immunity to the whole class instead of a
 * field-by-field list that the next token added to a graph would silently
 * outgrow. A marching frame changes NONE of it, so a tick costs zero rebuilds.
 *
 * An envelope with npt == 0 is a NEGATIVE cache entry -- "walked, found nothing
 * in this window" -- and it is a real answer, kept for the same reason the
 * positive ones are: without it a trace zoomed off-screen would re-walk every
 * sample on every animation tick, which is precisely the cost being avoided. */
typedef struct {
  int valid;                  /* 0 = empty slot (the my_calloc default) */
  int gi, ni;                 /* rect index + NODE index this envelope is of */
  double gx1, gx2, gy1, gy2;  /* KEY: the data window */
  double bx1, by1, bx2, by2;  /* KEY: the plot box, SCREEN pixels */
  char *prop;                 /* KEY: a copy of the rect's whole prop_ptr */
  int digital, dataset;       /* decoded, for the painter (not part of the key) */
  const void *raw;            /* KEY: raw identity ... */
  int rawpoints, rawsets, rawvars; /* ... and its shape (the generation surrogate) */
  XPoint *pt;                 /* the envelope, screen pixels; my_malloc'd */
  int npt;                    /* points in use */
  int alloc;                  /* points allocated */
  int painted;                /* 1 while the overlay's pixels are on the window */
  int px1, py1, px2, py2;     /* and the bbox they occupy, for the copy-back erase */
} WaveHilightEnv;

/* One waveform marker (doc/claude/specs/graph_markers.md). Persisted in the
 * graph rect's `markers` prop token, one record per line, fields in this order.
 * x/y are the UNSCALED sample values -- never mylog10()'ed even on a log axis,
 * see landmine 35 -- and are guaranteed FINITE by the create/move ops, so the
 * token alphabet stays numeric and cannot be broken by a "nan"/"inf" spelling.
 * ldx/ldy are the label offset as a FRACTION of gr->w / gr->h: the only space
 * stable under canvas zoom, strip resize AND axis autozoom. */
typedef struct {
  int num;         /* window-wide marker number, >= 1 (the N in "M<N>") */
  int wave;        /* NODE index in the owning graph's `node` token (landmine 34) */
  int dataset;     /* REAL raw dataset index, NOT find_closest_wave's sweepvar_wrap */
  int point;       /* ABSOLUTE index into raw->values[*][] */
  double x, y;     /* the sample, unscaled, finite */
  int prev;        /* partner marker NUMBER for the delta block, 0 = none */
  double ldx, ldy; /* label offset, fraction of gr->w / gr->h */
} GraphMarker;

/* Full identity of ONE sample picked by graph_point_at(). */
typedef struct {
  int wave;        /* node index (the hilight_wave / graph_trace_at index space) */
  int dataset;     /* REAL raw dataset index */
  int point;       /* ABSOLUTE index into raw->values[*][] */
  int idx;         /* raw column actually read (== raw->nvars for an expression) */
  int expression;  /* 1 when the trace is an RPN expression (scratch column) */
  int sweep_idx;   /* raw column of this trace's sweep variable */
  double x, y;     /* UNSCALED sample values, captured INSIDE the sample loop */
  double sx, sy;   /* screen pixels of the sample (log-space mapped, S_X/S_Y) */
  double dist;     /* point distance in pixels from the query pixel */
  double seg_dist; /* point-to-SEGMENT distance -- the metric traces are RANKED on */
  /* THE POINT ON THE CURVE (issue 0193), which is NOT the sample above. A trace
   * is a polyline: between two samples there are infinitely many points on it
   * and, once the zoom is tighter than the sample spacing, NONE of them is a
   * sample. These four are the foot of the perpendicular from the query pixel
   * onto the winning segment -- what "snap to the trace" means visually, and
   * the only answer that exists at high zoom.
   * A MARKER USES THESE TOO (issue 0193): "add a marker at the point the
   * diamond has snapped to" (issue 0188) is only true if both read the same
   * answer, and below the sample spacing the nearest sample is off-screen --
   * marking it would put the marker outside the view the user is looking at.
   * `seg_point`/`seg_dataset` stay as the record's ANCHOR (the segment's left
   * sample), so a marker is still addressable by sample index; x/y are the
   * interpolated position. See doc/claude/specs/graph_markers.md 3.1. */
  double seg_x, seg_y;   /* UNSCALED values at that point (interpolated) */
  double seg_sx, seg_sy; /* its screen pixels */
  int seg_point;         /* LEFT sample of the winning segment (raw->values[] index) */
  int seg_dataset;       /* its dataset */
} GraphPointHit;

typedef struct {
  int savew, saveh;
  double savexor, saveyor, savezoom, savelw;
} Zoom_info;

/* doc/claude/specs/wire_label_ride.md §5.3: one entry of the per-gesture net-label RIDER SET --
 * "which copper was this label sitting on when the drag started, and where was its anchor".
 * The set exists only between move START and move END/ABORT, is never in sel_array, never in
 * inst[].sel and never on disk; no xWire / xInstance / xSymbol field changes.
 * S1 implements LEASH (the LABEL is the object being dragged; an anchor that lands off copper is
 * projected back onto the owner span). S3 adds RIDE (the WIRE moves and the label follows,
 * orientation included). The two arms split on xctx->inst[].sel -- SET means LEASH, CLEAR means
 * RIDE -- and getting that predicate backwards is silent.
 * NO START ORIGIN FIELD, in either mode, and that is a result rather than an omission: LEASH
 * corrects the origin the ELEMENT commit already wrote, and RIDE solves for a new one from the
 * TARGET PIN by reading get_inst_pin_coord() back after baking rot/flip (spec §11 hazard D, §16.1).
 * Neither ever needs to know where the instance started, so the field the spec reserved for S3 is
 * not carried -- WIRING.md §7.9's rule about unread per-gesture scratch. */
#define LABEL_RIDE_LEASH 1
#define LABEL_RIDE_RIDE  2
typedef struct {
  unsigned int lid;            /* label instance id (session-stable id, NOT an array index) */
  unsigned int wid;            /* owner WIRE id at capture; 0 => the owner is a bare PIN ANCHOR
                                * (the gnd/vdd-on-a-device-pin idiom: 36% of shipped labels sit
                                * on a device pin with no wire under them, spec §5.8) */
  double ax, ay;               /* label pin anchor, START coordinates. Also the owner-resolution
                                * key: the captured owner must still contain this point. */
  double sx1, sy1, sx2, sy2;   /* owner SPAN at capture -- the collinearity key for the geometric
                                * re-find (§11 hazard B). Degenerate (== the anchor) for wid==0. */
  int mode;                    /* LABEL_RIDE_LEASH | LABEL_RIDE_RIDE */
} Label_ride;

typedef struct {
  xWire *wire;
  xText *text;
  xRect **rect;
  xLine **line;
  xPoly **poly;
  xArc **arc;
  xInstance *inst;
  xSymbol *sym;
  int sym_txt;
  int wires;
  int instances;
  int symbols;
  int texts;
  int *rects;
  int *polygons;
  int *arcs;
  int *lines;
  int *maxr;
  int *maxp;
  int *maxa;
  int *maxl;
  int maxt;
  int maxw;
  int maxi;
  int maxs;
  unsigned int wire_id_counter; /* store.c: last wire id stamped; monotonic per context,
                                 * survives clear_drawing/load so ids are never reused
                                 * within a window/tab session */
  unsigned int inst_id_counter; /* store.c: last instance id stamped at inst_register;
                                 * monotonic per context, survives clear_drawing/load
                                 * so ids are never reused within a window/tab session */
  unsigned int gfx_id_counter;  /* store.c: last graphical-object id stamped at
                                 * gfx_register; ONE shared counter for all four
                                 * graphical types, monotonic per context, survives
                                 * clear_drawing/load so ids are never reused */
  unsigned int text_id_counter; /* store.c: last text id stamped at text_register;
                                 * monotonic per context, survives clear_drawing/load
                                 * so ids are never reused within a window/tab session */
  char *schprop;
  char *schtedaxprop;
  char *schvhdlprop;
  char *schsymbolprop;
  char *schverilogprop;
  char *schspectreprop;
  char *sch[CADMAXHIER];
  int currsch;
  char *version_string;
  char *header_text; /* header text (license info) placed in the 'v' record after xschem/file version */
  char current_name[PATH_MAX];
  char file_version[100];
  char *sch_path[CADMAXHIER];
  Str_hashtable portmap[CADMAXHIER];
  int sch_path_hash[CADMAXHIER]; /* cached hash of hierarchic schematic path for speed */
  int sch_inst_number[CADMAXHIER]; /* inst number descended into in case of vector instances X1[5:0] */
  int previous_instance[CADMAXHIER]; /* to remember the instance we came from when going up the hier. */
  Zoom zoom_array[CADMAXHIER];
  double xorigin,yorigin;
  double zoom;
  double mooz;
  double lw;
  int min_lw; /* minimum allowed line width (for UHD displays) */
  unsigned int ui_state;   /* this signals that we are doing a net place,panning etc.
                           * used to prevent nesting of some commands */
  unsigned int ui_state2; /* sub states of ui_state MENUSTART bit */ 
  int constr_mv;          /* constrained move (vertical (2) / horizontal (1) )  */
  double mousex,mousey; /* mouse coord. */
  double mousex_snap,mousey_snap; /* mouse coord. snapped to grid */
  double mx_double_save, my_double_save;
  int areax1,areay1,areax2,areay2,areaw,areah; /* window corners / size, line width beyond screen edges */
  int need_reb_sel_arr;
  int lastsel;
  int maxsel;
  /* Cadence double-click incremental connected-select escalation state.
   * doc/claude/specs/dblclick_connected_select.md. Keyed on a seed (type + session-
   * stable id): dblgrow_level is how many grow steps have run on this seed
   * (0 -> next does ring1, 1 -> ring2, 2 -> whole-net flood, 3 -> saturated/no-op).
   * A different seed, or a selection count that no longer matches dblgrow_sel_sig
   * (an external selection change between double-clicks), resets the level to 0.
   * Zero-init is correct: seed_type 0 never matches a real WIRE/ELEMENT seed, so
   * the first call always resets. */
  int dblgrow_level;
  unsigned short dblgrow_seed_type;
  unsigned int dblgrow_seed_id;
  int dblgrow_sel_sig;
  double dblgrow_seed_x, dblgrow_seed_y;
  /* Any single click (or other non-double gesture) ends the escalation, so the next
   * double-click on the seed restarts at ring1. This can't be seen from the selection
   * (a click on the already-selected seed changes nothing) so it is driven by the event
   * stream: a button-1 RELEASE that is not the release of a double-click snapshots the
   * level into dblgrow_level_save and zeroes it (tentative reset); the following `-3`
   * double-click RESTORES the snapshot (proving that press/release was the first half of
   * a double, not a standalone click) before advancing. A standalone click's zero is
   * never restored, so it sticks. dblgrow_last_press_was_grow guards the double's own
   * release2 (whose preceding "press" was the `-3` grow) from tripping the reset. */
  int dblgrow_level_save;
  int dblgrow_last_press_was_grow;
  int pin_sel_active; /* hint: 1 once any instance pin has been selected (pin_selection.md).
                       * Lets unselect_all() clear stale pin selections even when lastsel/
                       * SELECTION were reset out from under them (e.g. after delete()).
                       * A false positive only costs one harmless instance scan. */
  int pin_pending;    /* pin_selection.md D3: a Button1 press landed on a pin and armed a
                       * wire; the release decides click(select pin) vs drag(draw wire).
                       * 0 = none. pin_pending_n/c hold the armed instance/pin index. */
  int pin_pending_add; /* pin_selection.md D6: the pending press was SHIFT+click on a pin
                       * (additive multi-select). Release: click -> add the pin (no
                       * unselect_all, no wire); drag -> ignore. Scalar, not heap. */
  int pin_pending_n;
  int pin_pending_c;
  int pin_press_x;    /* press-time screen coords of the armed pin gesture, used at
                       * release to measure click-vs-drag (mouse_moved is suppressed
                       * while STARTWIRE is active, so it cannot be relied on here). */
  int pin_press_y;
  int sympin_preview; /* cadence_pin_name_text.md item #3: the current START_SYMPIN move is a
                       * non-committal Add-Pin cursor PREVIEW. One undo baseline is pushed at
                       * the first arm; re-arms (per keystroke) drop the old preview with NO
                       * undo (so typing a name does not spam/corrupt the undo stack); the drop
                       * keeps the baseline; an aborted preview is removed undo-free. 0 = a
                       * normal placement (add_graph/add_image/scripted pin), undo as usual. */
  int wirelabel_preview; /* add_wire_label.md: the current sympin PREVIEW is a Cadence net-label
                       * (lab_pin) under the "must land on copper" drop constraint. Set together
                       * with sympin_preview at arm; cleared alongside it. When set, the drop gate
                       * (wire_label_try_commit) refuses a click that is not on a wire/inst pin. */
  PlacePreview *preview_sel; /* issue 0241: WHAT the live cursor placement is, as durable ids.
                       * Stamped at every arm by stamp_placement_preview() (the twelve
                       * `ui_state |= START_SYMPIN|PLACE_SYMBOL|PLACE_TEXT` sites), and read back
                       * by the two places that tear a preview down with delete():
                       * abort_placement_preview() and the modeless forms' per-keystroke re-arm
                       * drop. delete() is SELECTION-scoped, so without this the cancel removes
                       * whatever is selected AT THE CANCEL -- and a single Ctrl+A (or
                       * select_dangling_nets, or Edit>Select all) between the arm and the cancel
                       * turned it into a whole-document delete that set_modify(save) then
                       * reported as UNMODIFIED. The stamp is the SELECTION AT THE ARM, which is
                       * exactly the set move_objects(START) grabbed: one object for most arms,
                       * a PINLAYER rect + its owned name text for Add-Pin, and deliberately the
                       * user's pre-existing selection too for the two arms that ride along with
                       * it (draw.c screen grab, place_text). NULL until the first arm; freed with
                       * sel_array in xinit.c. */
  int preview_sel_n;   /* live entries in preview_sel. 0 = nothing stamped -> the teardown
                       * deletes NOTHING (backstop: a stray preview is cosmetic, a wiped
                       * schematic is not). */
  int preview_sel_size; /* allocated entries in preview_sel (high-water mark, never shrinks) */
  double statusmsg_hold_ms; /* issue 0248: wall-clock deadline (ms, net_hilight_now_ms() scale)
                       * until which the .statusbar.1 coordinate readout must NOT overwrite the
                       * message that is up. 0 = no hold. Armed by statusmsg_hold() (every gate /
                       * prompt line), tested by statusmsg_held() at the three readout sites, and
                       * released early by any ButtonPress. Without it a gate message lives for one
                       * mouse flick: the readout is guarded by `if(xctx->ui_state)`, and ui_state
                       * is non-zero for exactly the reason the message exists. */
  char statusmsg_text[256]; /* issue 0248: the last line statusmsg() actually put on .statusbar.1
                       * (dropped lines are not recorded). The field itself is a Tk label that only
                       * exists when has_x, so this is what makes the hold assertable headlessly --
                       * `xschem get statusmsg`. Fixed array on purpose: no allocation to free on
                       * context teardown. */
  char descend_err[192]; /* issues 0249/0251/0254: WHY the last descend attempt on THIS context
                       * refused. A reason token, never a sentence -- read as `xschem get
                       * descend_error`. Empty = the last attempt succeeded, or none has run.
                       * Written at EVERY refusal in descend_schematic()/descend_symbol() (record
                       * always) whether or not that refusal also SPEAKS (speak selectively): the
                       * annotation class -- 262 shipped lab_pin/gnd/title/launcher symbols the
                       * user never asked to descend -- must stay byte-silent, and that silence is
                       * locked by tests/headless/test_descend_inert_class.tcl. This is a SECOND
                       * channel: the "0"/"1" result of `xschem descend` is load-bearing in the
                       * PDK glue and must never be widened into a reason string.
                       * Per-context, not a file static: open_sub_schematic / hi_descend_newwin
                       * switch contexts mid-flight, so a static would be read in the wrong window.
                       * Fixed array on purpose: no allocation to free on context teardown.
                       * doc/claude/code_analysis/descend_silent_refusal_census.md */
  int gate_bypass;   /* TEST-ONLY seam (xschem test_gate_bypass, issue 0247): 1 disables all four
                       * modal-gesture gates (leave_wire_draw_for / leave_placement_for /
                       * leave_merge_for / leave_shape_draw_for) so a
                       * headless test can still CONSTRUCT the co-armed state (a live wire draw +
                       * a second modal gesture) that every production verb now refuses to build.
                       * abort_operation()'s co-armed teardown has no other constructor left --
                       * see tests/headless/test_add_wire_label.tcl G2. Never set by the GUI. */
  int sympin_drops;  /* issue 0122 E1: monotonic count of COMMITTED sympin drops (Add-Pin /
                       * Add-Wire-Label). Bumped only in end_move_copy_logged (the single commit
                       * funnel; aborts and off-copper label refusals never reach it). The Tcl
                       * form procs snapshot `xschem get sympin_drops` at arm and compare after a
                       * drop: an unchanged count means NO real drop happened (an external gesture
                       * aborted the preview), so the queue/name entry must NOT drain.
                       * KEPT as the total for existing callers (issue 0246 D2); the two parts
                       * below carry the OWNER and are what the forms actually compare now. */
  /* issue 0246: the SAME witness split by OWNER, so a form can never be credited with a sibling
   * form's drop (`::sympin_place`, the write-only Tcl owner latch these replace, was written
   * unconditionally after a `-place` that could be a no-op, was never cleared, and was read ABOVE
   * the E1 compare -- so a stale value suppressed the very pause E1 exists to deliver).
   * Bumped in the SAME funnel inside the SAME gate as the total, discriminated by
   * wirelabel_preview (1 = a net-label commit, 0 = a pin commit: both pin arms force it to 0
   * (scheduler.c), the label arm sets it, and wire_label_try_commit clears it only AFTER calling
   * end_move_copy_logged). Invariant asserted by the tests:
   *   sympin_drops == sympin_drops_pin + sympin_drops_label. */
  int sympin_drops_pin;
  int sympin_drops_label;
  Selected *sel_array;
  Selected first_sel; /* first selected instance (used as master when editing multiple objects) */
  int prep_net_structs;
  int prep_hi_structs;
  int prep_hash_inst;
  int prep_hash_object;
  int prep_hash_wires;
  Simdata *simdata;
  int simdata_ninst;
  int modified;
  int semaphore;
  int paste_from; /* pending-merge source (see paste.c merge_file):
                   *        0 named file (merge with explicit filename)
                   *        1 selection transfer (sel_file)
                   *        2 clipboard (clip_file)
                   *        3 user-picked file (merge dialog) */
  char merge_source[PATH_MAX]; /* paste.c: source file of the pending STARTMERGE, as merge_file()
                                * opened it -- read by the drop logger (callback.c
                                * end_move_copy_logged) to record `xschem paste ... -file {f}`
                                * for non-clipboard merges (issue 0069) */
  int pre_merge_modified; /* ISSUE 0244: xctx->modified as it was BEFORE the pending STARTMERGE,
                           * latched by merge_file() (paste.c) and read by abort_operation()'s two
                           * merge arms (callback.c) to decide whether cancelling the paste may
                           * clear the flag. It must be LATCHED and cannot be read at abort time:
                           * merge_file() ends with an unconditional set_modify(1), so by then the
                           * pre-merge value is already gone. Per-window, like merge_source. */
  unsigned int modify_seq;  /* ISSUE 0267: bumped by set_modify() (actions.c) every time something
                             * DECLARES this buffer dirty (mod 1/3, not suppressed by readonly).
                             * Not a change counter and not user-visible -- it exists so a latched
                             * "the flag before X" can tell whether anything else has claimed a
                             * modification since X was latched. Wraps harmlessly: only equality
                             * against a value latched in the same session is ever tested. */
  unsigned int merge_modify_seq; /* ISSUE 0267: modify_seq as it stood immediately after the
                             * pending STARTMERGE armed (latched at the bottom of merge_file(),
                             * paste.c, after its own set_modify(1)). The merge teardown
                             * (abort_pending_merge(), callback.c) restores pre_merge_modified only
                             * while this still matches: STARTMERGE has an unbounded lifetime on the
                             * ungated pure-commit surface (`xschem wire x1 y1 x2 y2`, `xschem text
                             * ...`), so real edits can happen between the arm and the ESC, and
                             * restoring a flag that predates them reported them saved. */
  size_t tok_size;
  char netlist_name[PATH_MAX];
  char current_dirname[PATH_MAX];
  int netlist_unconn_cnt; /* unique count of unconnected pins while netlisting */
  Instpinentry *instpin_spatial_table[NBOXES][NBOXES];
  Wireentry *wire_spatial_table[NBOXES][NBOXES];
  Instentry *inst_spatial_table[NBOXES][NBOXES];
  Objectentry *object_spatial_table[NBOXES][NBOXES]; /* spatial hash table for all objects (rect selection) */
  int n_hash_objects; /* total number of objects in object_spatial_table */
  Window window;
  Pixmap save_pixmap;
  XRectangle xrect[1];
  #if HAS_CAIRO==1
  cairo_surface_t *cairo_sfc, *cairo_save_sfc;
  cairo_t *cairo_ctx, *cairo_save_ctx;
  cairo_font_face_t *cairo_font;
  #endif
  GC gctiled;
  GC *gc;
  GC *gcstipple;
  GC gc_scope;          /* apply-scope highlight: dedicated white/high-contrast GC */
  int *scope_hi_type;   /* apply-scope highlight overlay: per-entry object type */
  unsigned int *scope_hi_id; /* per-entry STABLE id (resolved to index at draw time) */
  int scope_hi_n;       /* number of objects in the overlay (0 = inactive) */
  int scope_hi_alloc;   /* allocated capacity of the two arrays above */
  GC gc_hover;          /* hover (awareness) highlight: dashed thin colored GC */
  /* viewer plan item 9: the diamond SNAP CURSOR that sticks to the nearest
   * sample of the nearest trace while the pointer hovers a graph. Every field
   * is 0-at-rest on purpose -- xctx is one my_calloc, so a 0 default is free
   * and a non-zero sentinel would have to be written in three places
   * (alloc_xschem_data, clear_drawing, and the teardown).
   * NOT part of any export: the whole cadence draws with draw_pixmap = 0, so
   * the glyph exists only in the window and cannot reach a print/SVG at all --
   * a stronger guarantee than the flags-bit-16 rule it would otherwise need. */
  int graph_snap_on;        /* 1 = a diamond is currently PAINTED */
  int graph_snap_gi;        /* graph index it belongs to */
  int graph_snap_wave;      /* node index of the trace it snapped to */
  double graph_snap_sx, graph_snap_sy; /* screen px of the painted diamond */
  double graph_snap_x, graph_snap_y;   /* RAW sample values -- item 10's readout.
                                        * RAW, never mylog10()'d: landmine 35. */
  int graph_snap_prev_mx, graph_snap_prev_my; /* last mouse pixel QUERIED */
  int graph_snap_have_prev; /* prev_mx/my hold a real query */
  int hover_type;       /* hover highlight: currently-outlined object type (0 = none) */
  int hover_n;          /* hover highlight: its array index */
  int hover_col;        /* hover highlight: its layer (graphical types) */
  /* Hover fly-line overlay (doc/claude/specs/hover_flylines.md, Track B). Pure read-only
   * overlay state (invariant C1: draw_flylines writes ONLY the window + these fields, never
   * wire/inst/hilight/modified state). fly_shown_net = net whose star is currently on screen
   * (NULL/empty = none); fly_nseg = drawn segment count; fly_x1..y2 = world bbox of the star,
   * used for erase / regional redraw. `xschem flylines shown` reports fly_shown_net. */
  char *fly_shown_net;  /* net whose star is currently DRAWN (nseg>0); "" via NULL = none. `shown` */
  char *fly_last_net;   /* last net RESOLVED under the cursor (star or not) -- the change-detection
                         * cache key, so repeated motion over a starless net short-circuits too */
  int fly_nseg;
  double fly_x1, fly_y1, fly_x2, fly_y2;
  double *fly_seg;      /* 4*fly_nseg doubles (x1,y1,x2,y2 per drawn segment, world coords) so the
                         * draw() re-stamp can re-stroke the star after a full redraw with no recompute */
  int fly_seg_alloc;    /* allocated doubles in fly_seg */
  /* Member keys of the HUB CLUSTER that produced the drawn star (H2, flyline_hub_at_cursor_plan.md).
   * While the cursor stays within this cluster on the same net, the origin is re-projected and the
   * star's origins rebuilt in place (regional erase + re-stroke) WITHOUT re-clustering; moving to a
   * different cluster (or net) forces a full recompute. Each key is 3 ints {kind, idx, pin} (kind
   * 0=wire pin=-1, 1=inst pin=p) matching FlyMember. Valid only while fly_nseg > 0. */
  int *fly_hub_mem;
  int fly_hub_nmem;     /* number of member keys (fly_hub_mem holds 3*fly_hub_nmem ints) */
  int fly_hub_mem_alloc;/* allocated ints in fly_hub_mem */
  GC gc_flyline;        /* fly-line overlay: dashed thin colored GC (flylines_color/width/dash) */
  GC gc_hilight;        /* net highlight scratch GC: reconfigured per wire from the
                         * NetHilightStyle (color+width+dash) at draw time */
  GC gc_graph_active;   /* ASE waveform viewer active-strip marker: a solid dull-yellow
                         * bar at the right edge of the TARGET graph (issue 0151,
                         * doc/claude/specs/waveform_viewer_modes.md). Color from
                         * graph_active_strip_color, set in build_colors(). */
  char **color_array;
  unsigned int color_index[256];
  XColor xcolor_array[256];
  int *enable_layer;
  int n_active_layers;
  int *active_layer;
  NetHilightStyle *net_hilight_style; /* customizable net highlight style table */
  int n_net_hilight_styles;           /* number of styles (cursor wraps modulo this) */
  unsigned int net_hilight_anim_sig;  /* last-frame blink phase signature (Pass 2a change
                                       * detection); a stable sig means no blink edge -> the
                                       * animation tick can skip the regional redraw */
  int in_hilight_anim_frame;          /* set only around draw() inside draw_hilight_region:
                                       * the blink gate applies ONLY in an animation frame, so
                                       * ordinary/interactive redraws and hardcopy export keep
                                       * highlights steady (deterministic) */
  int net_hilight_test_active;        /* test hook (xschem net_hilight_test_now): forces the
                                       * blink gate + a fixed time so a render can sample a
                                       * specific phase. A C flag, never set in production. */
  double net_hilight_test_ms;         /* forced "now" (ms) when net_hilight_test_active */
  int crosshair_layer;
  char *undo_dirname;
  Undo_ids *undo_ids;    /* disk-undo id side-channel ring [MAX_UNDO], lazily allocated (issue 0043) */
  char *infowindow_text; /* ERC messages */
  int intuitive_interface;
  int cur_undo_ptr;
  int tail_undo_ptr;
  int head_undo_ptr;
  Int_hashtable inst_name_table;
  Int_hashtable floater_inst_table;
  Node_hashentry **node_table;
  Hilight_hashentry **hilight_table;
  int shape_point_selected;
  int drag_elements;
  int hilight_nets;
  int hilight_color;
  int hilight_replace; /* hilight_net(): re-style an already-hilighted net + always advance
                        * the style cursor (Cadence interactive 9/8); 0 = legacy no-replace */
  int hilight_time; /* timestamp for sims */
  unsigned int rectcolor; /* current layer */
  /* get_unnamed_node() */
  int new_node;
  int *node_mult;
  int node_mult_size;
  /* callback.c */
  int already_selected; /* when clicking on an object that is already selected this will be 1 */
  int mx_save, my_save, last_command;
  int onetime;
  int mouse_moved; /* set to 0 on button1 press, set to 1 if mouse moved */
  /* move.c */
  double rx1, rx2, ry1, ry2;
  short move_rot;
  double x1, y1, x2, y2, deltax, deltay;
  /* connect by kissing enable flag */
  int connect_by_kissing;
  /* redraw_w_a_l_r_p_z_rubbers() */
  double prev_rubberx, prev_rubbery;
  /* a wire was created while separating a component frm a net or another component */
  int kissing;
  /* set by select_attached_nets(): the in-progress move is a STRETCH move (attached
   * wires were rubber-banded). Consumed at move_objects(END) to run release-time
   * cleanup (trim_wires merge/dedup + move-scoped orphan removal) regardless of the
   * autotrim_wires preference (wire-editing Phase 5). Cleared at END/ABORT. */
  int stretch_select;
  /* endpoint coordinates (x,y pairs) of the wires grabbed by the in-progress stretch
   * move, captured in select_attached_nets() before the commit re-creates the wires
   * (which re-mints ids and resets sel). Scopes the Phase-5 move-orphan removal to
   * stubs that descend from a wire THIS move dragged, so a pre-existing wire the
   * moved pin merely landed on (a distinct net, TC11) is never deleted. Length is
   * 2*stretch_grabbed_n doubles (n points). */
  double *stretch_grabbed_xy;
  int stretch_grabbed_n;
  /* incremental_wire_reroute.md Phase I (ownership decoupling): number of wires the USER had
   * selected (ANY selection state -- full SELECTED or partial SELECTED1/2 from a stretch box-select),
   * captured at the TOP of select_attached_nets() BEFORE it grabs any follow-wire. Consumed at move
   * END: if 0, every selected wire at END is a tool-owned follow-wire and is deselected (transient,
   * not persistent user selection). Only meaningful under fluid_editing. */
  int fluid_startsel_wires;
  /* issue 0091: session-stable ids (xWire.id) of exactly the wires the USER had selected at drag
   * START, captured in select_attached_nets() alongside fluid_startsel_wires BEFORE follow-grab.
   * The END redundant-route cleanup (0088-0090) uses these to decline PER-COMPONENT: it floods each
   * user-selected wire's touch-component and never reshapes/deletes copper in a protected component,
   * so it cleans tool-grabbed follow copper on OTHER nets while leaving the user's own selected net
   * intact. Allocated in select_attached_nets, freed with the move (mirrors stretch_grabbed_xy). */
  unsigned int *fluid_startsel_id;
  int fluid_startsel_nid;
  /* doc/claude/specs/wire_label_ride.md §5.3 (S1): the per-gesture net-label rider set. Captured
   * at move START (label_ride_capture, move.c) BEFORE fluid_gesture_arm, consumed at the real
   * move END (label_ride_apply) and freed at END / ABORT / clear (label_ride_free) -- the
   * fluid_startsel_id lifecycle exactly. A live fluid RUBBER step (commit_now) must NOT free it:
   * the gesture is still open and END re-derives from the total delta. */
  Label_ride *label_ride;
  int label_ride_n;
  /* Cadence deferred-selection: a plain (no-modifier) press-drag-release of an object that was NOT
   * already selected must MOVE it without changing the selection membership -- if nothing was
   * selected it ends unselected, and a pre-existing selection is preserved untouched. A CLICK (no
   * motion) still selects normally. Snapshot the pre-press selection by session-stable id here
   * (BEFORE the transient select that the drag needs), then at the move-completion funnel
   * (end_move_copy_logged) restore it iff the gesture actually moved. Freed/reset each gesture.
   * doc/claude/specs/cadence_modifier_drag.md (deferred-selection). */
  int drag_sel_restore;           /* 1 => a transient drag-select is pending restore on a moved drag */
  int drag_sel_n;                 /* snapshot length (0 => pre-press selection was empty) */
  unsigned int *drag_sel_id;      /* session-stable ids of the pre-press selection */
  short *drag_sel_type;           /* parallel: object type (WIRE/ELEMENT/xTEXT/xRECT/LINE/POLYGON/ARC) */
  short *drag_sel_col;            /* parallel: layer col for per-layer types, else 0 */
  int place_click_committed;      /* issue 0113: a Button1 PRESS completed an in-flight move/copy
                                   * (verb-noun / keyboard 'm' placement). The matching RELEASE must
                                   * NOT run the cadence deselect-others or any click-select logic --
                                   * that would collapse the just-moved multi-selection. Latched at
                                   * the press (end_place_move_copy_zoom), consumed once at release. */
  /* incremental_wire_reroute.md Phase II (per-snap-step reroute, restore-and-reapply). A fluid
   * stretch drag snapshots the whole pristine (post-kiss, pre-delta) schematic here at move START;
   * each qualifying move_objects(RUBBER) step restores it and re-applies the current TOTAL drag
   * delta through the unchanged reroute pipeline, so the live route tracks the cursor and the
   * committed result on release is byte-identical to the release-only path. Uses the same
   * mem_serialize_slot/mem_restore_slot machinery as the undo stack but with an independent
   * lifetime (a scratch slot, NOT in uslot[]), so it is unaffected by the disk-vs-memory undo
   * backend. See doc/claude/suggestions/incremental_reroute_phase2_decision.md. */
  Undo_slot fluid_reroute_snap;   /* pristine geometry+selection snapshot for the active gesture */
  int fluid_reroute_active;       /* 1 while a fluid stretch gesture owns fluid_reroute_snap */
  int fluid_reroute_dirty;        /* 1 once a RUBBER step has committed geometry (END must restore) */
  int select_attached_nodraw;     /* 1 => select_attached_nets() re-derives the follow SET only, no
                                     highlight draw (between-legs regrab: the intermediate leg-A
                                     geometry must NOT be stroked into the pixmap -- issue 0117 ghost) */
  /* the four session-stable id counters at gesture START -- restored after every per-step
   * mem_restore_slot so tool-created wires re-stamp identical ids each step (determinism, P8). */
  unsigned int fluid_reroute_wid, fluid_reroute_iid, fluid_reroute_gid, fluid_reroute_tid;
  short move_flip;
  int manhattan_lines;
  int movelastsel;
  short rotatelocal;
  /* prompt-for-object rotate/flip (Cases 1 & 3): which transform a pending MENUSTARTROTATE
   * applies to the object clicked next (a PENDING_TR_* code). see
   * doc/claude/specs/rotate_keep_connected_stretch.md */
  short menu_pending_transform;
  /* new_wire, new_line, new_rect*/
  double nl_x1,nl_y1,nl_x2,nl_y2;
  double nl_xx1,nl_yy1,nl_xx2,nl_yy2;
  /* new_arc */
  double nl_x, nl_y, nl_r, nl_a, nl_b;
  double nl_x3, nl_y3;
  int nl_state;
  double nl_sweep_angle;
  /* new_polygon */
  double *nl_polyx, *nl_polyy;
  int nl_points, nl_maxpoints;
  /* select_rect */
  double nl_xr, nl_yr, nl_xr2, nl_yr2;
  int nl_sel, nl_sem; /* nl_sel is the select mode (select) the select_rect() was called with */
  int nl_dir; /* direction of the drag select_rect was called with: 0=to the right, 1=to the left */
  /* compare_schematics */
  char sch_to_compare[PATH_MAX];
  /* pan */
  double xpan,ypan,xpan2,ypan2;
  double p_xx1,p_xx2,p_yy1,p_yy2;
  /* draw_crosshair */
  double prev_crossx, prev_crossy; /* previous closest net/pin found by draw_crosshair() */
  double prev_m_crossx, prev_m_crossy; /* previous snap mouse position processed by draw_crosshair() */
  double prev_gridx, prev_gridy;
  double prev_snapx, prev_snapy;
  int closest_pin_found;
  int mouse_inside;
  /* set_modify */
  int prev_set_modify;
  int readonly; /* per-window read-only: file-protection (blocks save), set on non-writable load */
  /* pan */
  int mx_s, my_s;
  int mmx_s, mmy_s;
  double xorig_save, yorig_save;
  /* record_global_node() */
  int max_globals;
  int size_globals; 
  char **globals; 
  int *global_type; /* global_type[i]: 0:global, 1:ground and global (for Spectre) */
  /* load_schematic */
  int save_netlist_type;
  int loaded_symbol;
  /* *bus_hilight_hash_lookup */
  int some_nets_added; /* when hashing a bus net if at least one bit has been added set this to 1 */
  /* bbox */
  int bbx1, bbx2, bby1, bby2;
  int savew, saveh, savex1, savex2, savey1, savey2;
  int bbox_set; /* set to 1 if a clipping bbox is set (void bbox() ) */
  XRectangle savexrect;
  /* new_prop_string */
  /* edit_symbol_property, update_symbol */
  char *old_prop;
  int edit_sym_i;
  int netlist_commands;
  /* in_memory_undo */
  Undo_slot uslot[MAX_UNDO];
  int undo_initialized;
  int mem_undo_initialized;
  /* graph context struct */
  Graph_ctx graph_struct;

  Raw *raw; /* spice simulation data struct pointer */

  /* data for additional raw files */
  int extra_idx;                    /* current raw file */
  int extra_prev_idx;               /* previous current (to switch back) */
  Raw **extra_raw_arr;              /* array of pointers to Raw structure */
  int extra_raw_n;                  /* number of elements in array */
  int extra_raw_size;               /* size of raw_arr (will be incremented if needed) */

  int ev_precision; /* copied from TCL ev_precision var in draw() and draw_graph() */
  /*    */
  /* data related to all graphs, so not stored in per-graph graph_struct */
  double graph_cursor1_x, graph_cursor2_x;
  /* graph_flags:
   *  1: dnu, reserved, used in draw_graphs()
   *  2: draw x-cursor1
   *  4: draw x-cursor2
   *  8: dnu, reserved, used in draw_graphs()
   * 16: move cursor1
   * 32: move cursor2
   * 64: show measurement tooltip
   */
  int graph_flags;
  int graph_master; /* graph where mouse operations are started, used to lock x-axis */
  int graph_top; /* regions of graph where mouse events occur */
  int graph_bottom;
  int graph_left;
  int graph_rubber_active; /* RMB interior-drag zoom-rubber rectangle in progress */
  double graph_rubber_x, graph_rubber_y; /* last-drawn rubber moving corner (xschem coords) */
  /* Button1 press anchor for the wave-bold CLICK test (issue 0152). Deliberately NOT
   * mx/my_double_save: the Button1 graph drag-pan re-seeds those on every motion step
   * (waves_callback save_mouse_at_end), so at the end of a long pan they equal the
   * current pointer and a click test against them would fire. Set to the raw pointer
   * on every Button1 press over a graph, invalidated by a double-click. */
  double graph_press_x, graph_press_y;
  /* Waveform markers (doc/claude/specs/graph_markers.md). ALL TRANSIENT: the
   * durable state is the rect's `markers` prop token.
   * graph_marker_sel is a marker NUMBER (window-wide numbering) scoped by
   * graph_marker_selgraph, so a Delete pressed over another strip cannot eat it.
   * The drag is scratch-based: the record being dragged lives in
   * graph_marker_scratch and the renderer substitutes it, so a whole gesture is
   * ONE undo point, zero allocations per motion event, and ESC is a flag clear. */
  int graph_marker_sel;       /* selected marker number, -1 = none. THE HEAD of the
                               * set below, kept as a distinct field because the
                               * getter, the Delete scope gate and the repaint hint
                               * all read exactly it (issue 0189). */
  int graph_marker_sel_set[GRAPH_MARKER_MAX_SEL]; /* the WHOLE selection, marker
                              * NUMBERS, HEAD FIRST (selection order, not sorted).
                              * NEVER a prop token: selection is UI state and dies
                              * with the document (graph_markers.md 3.5). */
  int graph_marker_n_sel;     /* 0 <=> graph_marker_sel == -1 */
  int graph_marker_selgraph;  /* rect[GRIDLAYER] index owning the selection, -1 = none */
  int graph_marker_drag;      /* what was GRABBED: 0 none, 1 the ANCHOR, 2 the LABEL.
                               * This is the value `xschem get graph_marker_drag`
                               * exports; do NOT overload it -- see dragmode below. */
  int graph_marker_dragmode;  /* what the gesture DOES: GRAPH_MARKER_MODE_*, latched
                               * at press from the selection state (a text drag on a
                               * SELECTED marker is drag==2 but mode==RIGID) */
  int graph_marker_dragnum;   /* marker number being dragged */
  int graph_marker_draggraph; /* rect[GRIDLAYER] index the drag is bound to */
  int graph_marker_moved;     /* travel exceeded GRAPH_CLICK_TOL -> it is a drag, not a click */
  double graph_marker_press_x, graph_marker_press_y; /* press anchor, schematic units */
  double graph_marker_ldx0, graph_marker_ldy0;       /* label offset at press time */
  double graph_marker_x0, graph_marker_y0;           /* anchor SAMPLE at press time, the
                                                      * origin a RIGID drag translates from
                                                      * (the scratch's own x/y are rewritten
                                                      * on the first motion event) */
  GraphMarker graph_marker_scratch; /* live drag state, substituted by the renderer */
  /* Axis-region drag zoom (issue 0190). ALL TRANSIENT, like the marker block
   * above: the durable state is the rect's x1/x2/y1/y2 (or ypos1/ypos2) tokens,
   * written once on the release. graph_axis_press is in SCREEN PIXELS because
   * that is what graph_axis_map() takes -- the same space every other picking
   * query on a strip takes (landmine 43). Reset in graph_axis_drag_clear(),
   * clear_drawing() and alloc_xschem_data(). */
  int    graph_axis_drag;      /* GRAPH_AXIS_NONE | _X | _Y -- what is armed */
  int    graph_axis_draggraph; /* rect[GRIDLAYER] index the drag is bound to */
  double graph_axis_press;     /* press position on that axis, screen pixels */
  /* viewer plan item 6: the mid-drag SHRINK PREVIEW of the trace being dragged
   * to another strip. The marker-scratch idea applied to a polyline: the
   * renderer scales the previewed trace's y values on the fly, so a motion
   * event costs no allocation, no model write and no undo point.
   * `graph_preview_scale` is the ARM: 0.0 means off, which is the free calloc
   * default (a -1 sentinel would not be), so the other two are only meaningful
   * when it is non-zero. Transient CHROME — draw_graph applies it only for
   * flags & 16, so every export draws the trace unshrunk.
   * There is deliberately NO graph_preview_clear() function (an earlier version
   * of this comment named one): the disarm has ONE home, graph_preview_arm()
   * called with scale 0.0 or n <= 0, and the two document-lifetime resets are
   * inline in clear_drawing() (actions.c) and alloc_xschem_data() (xinit.c).
   * Issue 0192 made the arm a SET, in the graph_marker_sel shape above: the
   * three scalars below are the HEAD (element 0) and keep their exact meaning,
   * so `xschem get graph_preview` is byte-identical to the single-trace era;
   * the whole set is read through `xschem get graph_preview_set`. */
  double graph_preview_scale; /* 0.0 = no preview armed; else the y scale factor */
  int graph_preview_gi;       /* HEAD: rect[GRIDLAYER] index of set element 0 */
  int graph_preview_wave;     /* HEAD: NODE index within that graph (the wcnt space) */
  int graph_preview_set_gi[GRAPH_MAX_PREVIEW_WAVES];   /* the WHOLE carried set, as */
  int graph_preview_set_wave[GRAPH_MAX_PREVIEW_WAVES]; /* (gi, node) pairs, HEAD FIRST */
  int graph_preview_n;        /* 0 <=> graph_preview_scale == 0.0 */
  /* NET-HIGHLIGHT STYLES ON WAVEFORM TRACES
   * (doc/claude/specs/wave_trace_hilight.md §4.2). The SET of highlighted
   * traces of this window, as (rect index, NODE index, style index) triples --
   * three parallel FIXED arrays, never pointers, for exactly the reason
   * graph_marker_sel_set and graph_preview_set_* are (landmine 46(b)): xctx is
   * reset, not freed, so a pointer would add a free path to clear_drawing() for
   * nothing. `ni` is a NODE index, not a model trace index (landmine 34).
   *
   * SESSION-ONLY VIEW STATE (D4): no prop token, no undo point, not in a
   * snapshot. The AUTHORITY is a per-window Tcl array (wviewer's `wavehl`),
   * because wviewer::regenerate runs `xschem clear_drawing` -- and a plain
   * window RESIZE calls it (landmine 50) -- so a set held only here would
   * vanish on a resize. regenerate re-applies it to the fresh rects.
   *
   * ONE WRITER (wave_hilight_write, draw.c) and ONE draw-side predicate
   * (wave_hilight_style_of, draw.c). With a single highlighted trace a bare
   * `gi == ... && ni == ...` comparison and the predicate agree exactly, so a
   * missed call site is invisible to any behavioural leg -- which is why
   * test_wave_hilight.tcl asserts the call sites at SOURCE level (the LS5/MS13
   * idiom) and plants TWO highlighted traces wherever it can.
   * The two document-lifetime resets are inline in clear_drawing() (actions.c)
   * and alloc_xschem_data() (xinit.c), the gesture-state class above. */
  int wave_hilight_gi[GRAPH_MAX_HILIGHT_WAVES];    /* rect[GRIDLAYER] index */
  int wave_hilight_ni[GRAPH_MAX_HILIGHT_WAVES];    /* NODE index within it */
  int wave_hilight_style[GRAPH_MAX_HILIGHT_WAVES]; /* net_hilight_style index */
  int wave_hilight_n;         /* 0 = no trace in this window is highlighted */
  /* the envelope cache (§5.2). Slot k is NOT bound to set entry k: it is found
   * by (gi, ni) + the geometry key, and the whole cache is invalidated by any
   * set write -- a rebuild costs what a fresh highlight costs anyway, and an
   * ANIMATION frame never writes the set, which is the case that must be free. */
  WaveHilightEnv wave_hilight_env[GRAPH_MAX_HILIGHT_WAVES];
  int graph_lastsel; /* last graph that was clicked (selected) */
  /*    */
  XSegment *biggridpoint;
  XPoint *gridpoint;
  char plotfile[PATH_MAX];
  int enable_drill;
  int pending_fullzoom;
  char hiersep[20];
  int no_undo;
  int no_autosave; /* suppress the cellName~.sch autosave write (e.g. during load) */
  int draw_single_layer;
  int draw_dots;
  int only_probes;
  int graph_snap; /* viewer plan item 9: per-window arming of the diamond snap
                   * cursor. PER CONTEXT, not a global Tcl var, for the same
                   * reason no_grid is: draw_graph_variables/graph_point_at are
                   * shared with every embedded schematic graph in the tree, and
                   * the pick walks every sample of every trace -- arming it
                   * globally would put that cost on schematics that never asked
                   * for it. 0 for every context alloc_xschem_data creates; the
                   * ASE viewer sets it on its own window and never clears it. */
  int no_grid; /* per-window grid/origin suppression (Waveform Viewer: the window
                * reads as a graph, not a schematic). NOT mirrored in Tcl -- scoped
                * to this ctx only; see doc/claude/specs/waveform_viewer.md item 18 */
  int no_snap; /* THIS CANVAS HAS NO SCHEMATIC SNAP GRID (issue 0177). Per window,
                * exactly like no_grid above and for the same reason: `cadsnap` is a
                * GLOBAL Tcl var that the waveform viewer has no business sharing, and
                * the grid is a property of the SURFACE, not of the handler that
                * happens to be reading the pointer.
                *
                * Set it and three things become true for this context, at the source
                * and therefore for every present and future reader:
                *   - callback() computes mousex_snap/mousey_snap UNSNAPPED (they stay
                *     honest copies of mousex/mousey) instead of rounding to cadsnap;
                *   - draw_crosshair() is not drawn -- it paints AT mousex_snap
                *     (callback.c ~2646), so on a grid it IS the snap grid made visible,
                *     which is precisely what the 0177 reporter saw over the legend;
                *   - draw_snap_cursor() is not drawn -- it snaps to the nearest net or
                *     symbol pin, and a waveform canvas has neither.
                *
                * This REPLACES the per-handler override strategy issue 0143 started
                * (waves_callback still carries its own, because an ordinary SCHEMATIC
                * window can embed graphs and that context is NOT no_snap).
                * 0 for every context alloc_xschem_data creates; the ASE viewer sets it
                * on its own window and never clears it.
                * See doc/claude/issues/0177-viewer-has-no-snap-grid.md */
  int wave_viewer; /* THIS CONTEXT IS A WAVEFORM VIEWER, NOT A SCHEMATIC (issue 0172).
                * Per window, exactly like no_grid / no_snap above. The viewer is built
                * on an ordinary schematic window and is indistinguishable from a
                * pristine untitled scratch buffer by SHAPE: top level, named untitled,
                * no instances, no wires (its content is graph rects), and `modified`
                * permanently 0 because wviewer::with_edit (contract D1) ends every
                * mutation with `xschem set_modify 0`. is_pristine_untitled() therefore
                * offered a live viewer as a reuse target, and a real schematic was
                * loaded INTO it -- destroying its graph rects while the window kept its
                * WaveViewer bindtag and menubar, after which Ctrl-D wipes the document.
                * This flag is the honest oracle: a viewer is excluded because it IS
                * one, not because of what it happens to contain.
                * 0 for every context alloc_xschem_data creates; the ASE viewer sets it
                * on its own window and never clears it.
                * See doc/claude/issues/0172-viewer-buffer-hijacked-by-pristine-untitled-reuse.md */
  int menu_removed; /* fullscreen previous setting */
  double save_lw; /* used to save linewidth when selecting 'only_probes' view */
  int no_draw;
  int netlist_count; /* netlist counter incremented at any cell being netlisted */
  int hide_symbols; /* MIRRORED IN TCL */
  int netlist_type;
  char *format; /* "format", "verilog_format", "vhdl_format" or "tedax_format" */
  char *custom_format; /* user specified format string to use for spice netlist (xschem set format command) */
  char *top_path;
  /* top_path is the path prefix of drawing canvas (current_win_path):
   * top_path is always "" in tabbed interface 
   * current_win_path
   *    canvas           top_path
   *  ----------------------------
   *    ".drw"            ""
   *    ".x1.drw"         ".x1"
   */
  char *current_win_path; /* .drw or .x1.drw, .... ; always .drw in tabbed interface */
  int window_number; /* Cadence-style stable window number: CIW=1, LibMgr=2, editor
                      * contexts 3,4,5,...; monotonic, never reused; 0 = scratch/preview/
                      * compare ctx (doc/claude/specs/window_numbering.md) */
  int *fill_type; /* for every layer: 0: no fill, 1, solid fill, 2: stipple fill */
  int fill_pattern;
  int draw_pixmap; /* pixmap used as 2nd buffer */
  int draw_window;  /* MIRRORED IN TCL */
  int change_lw; /* cached valiue of TCL change_lw */
  int do_copy_area;
  double cadhalfdotsize;
  time_t time_last_modify;
  int undo_type; /* 0: on disk, 1: in memory */
  void (*push_undo)(void);
  void (*pop_undo)(int, int);
  void (*delete_undo)(void);
  void (*clear_undo)(void);
  int case_insensitive; /* for case insensitive compare where needed MIRRORED IN TCL*/
  int show_hidden_texts; /* force show texts that have hide=true attribute set MIRRORED IN TCL*/
  int annot_show; /* annotation-class visibility mask: bit0 device OP info (hide=op AND
                   * content-classified branch currents, issue 0678), bit1 node voltages
                   * (hide=voltage and content-classified node voltages). Independent of
                   * show_hidden_texts (decision D3). See text_hidden() in actions.c and
                   * the grouping in annot_class_mask beside it MIRRORED IN TCL*/
  int annot_voltage_layer; /* 0615: the layer a CONTENT-classified node voltage renders
                   * in, overriding the symbol text's own layer=. Default 9 (#ffffff on
                   * the default dark palette, which is what the user asked for; #00aaaa
                   * on the default light one -- a layer INDEX travels through the
                   * per-layer colour machinery, a hard #ffffff would not). Any index
                   * outside [1, cadlayers) means NO OVERRIDE: that is the documented,
                   * rebuild-free off switch AND it keeps 0 == BACKLAYER from painting
                   * the annotation in the background colour (decision D7).
                   * See annot_text_layer() in actions.c MIRRORED IN TCL*/
  int en_pin_select; /* enable selecting individual instance pins (click on pin) MIRRORED IN TCL*/
  int (*x_strcmp)(const char *, const char *);
  Lcc hier_attr[CADMAXHIER]; /* hierarchical recursive attribute substitution when descending */
} Xschem_ctx;

/* GLOBAL VARIABLES */

/*********** X11/system  specific globals ***********/
extern Colormap colormap;
extern unsigned char **pixdata;
extern unsigned char pixdata_init[22][32];
extern Display *display;
extern int _unix; /* set to 1 on unix systems */

#ifdef HAS_XCB
extern xcb_connection_t *xcb_conn;
#endif
extern int screen_number;
extern int screendepth;
extern Pixmap cad_icon_pixmap, cad_icon_mask, *pixmap;
extern Visual *visual;

/*********** These variables are mirrored in tcl code ***********/
extern int cadlayers; 
extern int has_x; 
extern int rainbow_colors; 
extern int color_ps; 
extern double nocairo_vert_correct;
extern double cairo_vert_correct;
extern int constrained_move;
extern double cairo_font_scale; /*  default: 1.0, allows to adjust font size */
extern double cairo_font_line_spacing;
extern int debug_var;
extern unsigned int draw_count; /* incremented on every full draw(); test/introspection seam */
extern int fix_broken_tiled_fill; /* if set to 1 work around some GPUs with rotten tiled fill operations */
/* this fix uses an alternative method for getting mouse coordinates on KeyPress/KeyRelease
 * events. Some remote connection softwares do not generate the correct coordinates
 * on such events */
extern int fix_mouse_coord;

/*********** These variables are NOT mirrored in tcl code ***********/
extern int help;
extern char *cad_icon[];
extern FILE *errfp;
extern FILE *actionlog_fp;
extern char actionlog_filename[PATH_MAX];
extern int actionlog_cmd_logged;    /* core self-log dedup flag (see globals.c) */
extern int actionlog_suppress_echo; /* skip CIW mirror while set (CIW-typed cmds) */
extern int actionlog_suppress;      /* full log no-op while set (replay guard) */
extern int select_at_suppress_log;  /* skip select_object()'s auto select_at log line */
extern int select_at_add;           /* funnel logs the ` add` (augment) marker while set */
extern char actionlog_pending[300]; /* held select_at line awaiting flush/absorb (action_log_absorb.md) */
extern int actionlog_pending_inst;  /* instance the held select_at selected, or -1 */
extern int exit_code;
extern const char *xschem_library_path[];
extern char home_dir[PATH_MAX]; /* home dir obtained via getpwuid */
extern char user_conf_dir[PATH_MAX]; /* usually ~/.xschem */
extern char sel_file[PATH_MAX];
extern char clip_file[PATH_MAX];
extern char pwd_dir[PATH_MAX]; /* obtained via getcwd() */
extern char xschem_web_dirname[PATH_MAX];
extern int tcp_port;
extern int text_svg;
extern int text_ps;
extern double cadhalfdotsize;
extern char bus_char[];
extern int yyparse_error;
extern int expandlabel_collapsed; /* issue 0182, defined in parselabel.l */
extern char *xschem_executable;
extern double tk_scaling;
extern Tcl_Interp *interp;
extern double *character[256];
extern char old_win_path[PATH_MAX]; /* previously switched window, used in callback() */
extern const char fopen_read_mode[]; /* "r" on unix, "rb" on windows */

/*********** Cmdline options  (used at xinit, and then not used anymore) ***********/
extern int cli_argc; /* copy of main argc */
extern int cli_opt_argc; /* arguments after stripping off options */
extern char **cli_opt_argv;
extern int cli_opt_netlist_type;
extern int cli_opt_flat_netlist;
extern char cli_opt_plotfile[PATH_MAX];
extern char cli_opt_diff[PATH_MAX];
extern char cli_opt_netlist_dir[PATH_MAX];
extern char cli_opt_logdir[PATH_MAX];
extern int cli_opt_nolog;
extern char cli_opt_filename[PATH_MAX];
extern int cli_opt_no_readline;
extern char *cli_opt_tcl_command;
extern char *cli_opt_preinit_command;
extern char *cli_opt_tcl_post_command;
extern int cli_opt_do_print;
extern int cli_opt_lastclosed;
extern int cli_opt_lastopened;
extern int cli_opt_do_netlist;
extern int cli_opt_do_simulation;
extern int cli_opt_do_waves;
extern int cli_opt_detach; /* no TCL console */
extern int cli_opt_quit;
extern int cli_opt_nogui; /* --nogui: true headless, never init Tk / map a window */
extern int cli_opt_pipe;  /* --pipe given: a scripted/automation session */
extern int cli_opt_norecent; /* --norecent: never create/rewrite the user's recent_files list */
extern char cli_opt_tcl_script[PATH_MAX];
extern char cli_opt_initial_netlist_name[PATH_MAX];
extern char cli_opt_rcfile[PATH_MAX];
extern int cli_opt_load_initfile;

/*********** Following data is relative to the current schematic ***********/
extern Xschem_ctx *xctx;

/*  FUNCTIONS */
extern int edit_image(int what, xRect *r);
extern int draw_image(int dr, xRect *r, double *x1, double *y1, double *x2, double *y2, int rot, int flip);
extern int filter_data(const char *din, const size_t ilen,
           char **dout, size_t *olen, const char *cmd);
extern int embed_rawfile(const char *rawfile);
extern int read_rawfile_from_attr(const char *b64s, size_t length, const char *type);
extern int raw_read_from_attr(Raw **rawptr, const char *type, double sweep1, double sweep2);
extern int raw_add_vector(const char *varname, const char *expr, int sweep_idx);
extern int raw_renamevar(const char *old_name, const char *new_name);
extern int raw_deletevar(const char *name);
extern int new_rawfile(const char *name, const char *type, const char *sweepvar,
                       double start, double end, double step);
extern char *base64_from_file(const char *f, size_t *length);
extern int set_rect_flags(xRect *r);
extern int set_text_flags(xText *t);
extern int set_wire_flags(xWire *wire);
extern int set_inst_flags(xInstance *inst);
extern int set_sym_flags(xSymbol *sym);
extern void reset_caches(void);
extern const char *get_text_floater(int i);
extern int set_rect_extraptr(int what, xRect *drptr);
extern unsigned char *base64_decode(const char *data, const size_t input_length, size_t *output_length);
extern char *base64_encode(const unsigned char *data, const size_t input_length, size_t *output_length, int brk);
extern unsigned char *ascii85_encode(const unsigned char *data, const size_t input_length, size_t *output_length);
extern int raw_get_pos(const char *node, double value, int dset, int from_start, int to_end);
extern int  get_raw_index(const char *node, Int_hashentry **entry_ret);
extern void free_rawfile(Raw **rawptr, int dr, int no_warning);
extern int update_op();
extern int extra_rawfile(int what, const char *f, const char *type, double sweep1, double sweep2);
extern int raw_read(const char *f, Raw **rawptr, const char *type, int no_warning, double sweep1, double sweep2);
extern int table_read(const char *f);
/* VCD (Value Change Dump) -> Raw. Same contract as table_read(): xctx->raw must be NULL
 * on entry, the caller sets raw->sim_type. See src/vcd_read.c and
 * doc/claude/specs/mixed_signal_signal_browser.md section C. */
extern int vcd_read(const char *f);
/* THE reader dispatch (issue 0290): `type` is the key that picks the parser --
 * "table" -> table_read(), "vcd" -> vcd_read(), anything else -> raw_read() -- and
 * raw->sim_type is stamped for the non-spice readers, which do not all do it
 * themselves. Every (file, type) -> database path goes through this, so the choice
 * exists exactly once; see the table above it in src/save.c. */
extern int read_rawfile_by_type(const char *f, Raw **rawptr, const char *type,
                                int no_warning, double sweep1, double sweep2);
extern int raw_type_is_non_spice(const char *type);
/* SPEC D5 -- the ONE place that answers "is this database logic levels rather
 * than analog values?", driven by the `digital` column of the reader table in
 * src/save.c. Every backannotation enforcement point asks these, and a new
 * database type inherits the ruling by filling in its row. Never re-derive the
 * answer with a strcmp against "vcd" at a call site (RULING D5-2). */
extern int raw_type_is_digital(const char *type);
extern int raw_is_digital(const Raw *raw);
/* ...and the same question asked of a FILE, for the request paths where the
 * caller did not spell a type at all (RULING D5-6). Content sniff, not
 * extension. */
extern int raw_file_is_digital(const char *f);
/* the single-sourced refusal sentence (RULING D5-4): emits it on the CIW and
 * the debug channel and returns it, so a caller with a Tcl result to set hands
 * the script the same words the user reads. */
extern const char *backannot_refuse_digital(const char *dbname);
extern double get_raw_value(int dataset, int idx, int point);
extern int plot_raw_custom_data(int sweep_idx, int first, int last, const char *ntok, const char *yname);
extern int calc_custom_data_yrange(int sweep_idx, const char *express, Graph_ctx *gr);
extern int sch_waves_loaded(void);
extern int edit_wave_attributes(int what, int i, Graph_ctx *gr);
extern void draw_graph(int i, int flags, Graph_ctx *gr, void *ct);
extern int find_closest_wave(int i, Graph_ctx *gr, int *node_number);
/* find_closest_wave() as a read-only query at a canvas pixel; `xschem get
 * graph_closest_wave` (batch F item 2, issue 0305) */
extern int graph_closest_wave(int i, double px, double py, int *node_number);
extern int graph_near_wave(int i, double px, double py, double tol);
extern int graph_wave_at(int i, double px, double py, double tol);
/* Trace SELECTION (issue 0175). The set lives in the graph rect's `hilight_wave`
 * + `sel_waves` prop tokens; these three are the ONLY sanctioned readers/writers
 * of that pair, so the two tokens can never drift apart.
 *   graph_sel_waves_get   parse rect `i`'s selection into `out` (up to `max`
 *                         entries); returns how many, 0 when nothing is selected.
 *   graph_sel_waves_set   write it back; n == 0 clears both tokens. Returns 1
 *                         when the rect's prop string actually changed.
 *   graph_sel_waves_toggle  Ctrl+click: add `wcnt` if absent, remove it if
 *                         present. Returns 1 when it changed something.
 * wave_is_hilighted() is the DRAW-side test and replaces every `gr->hilight_wave
 * == wcnt` comparison. */
extern int  graph_sel_waves_get(int i, int *out, int max);
extern int  graph_sel_waves_set(int i, const int *waves, int n);
extern int  graph_sel_waves_toggle(int i, int wcnt);
extern int  wave_is_hilighted(Graph_ctx *gr, int wcnt);
/* The mid-drag SHRINK PREVIEW as a SET (issue 0192,
 * doc/claude/specs/waveform_viewer_modes.md 19). Same one-writer/one-predicate
 * discipline wave_is_hilighted enforces for the selection, for the same reason:
 * a surviving bare comparison draws a carried trace at full size and NO leg that
 * drags a single trace can see it (with n == 1 the bare test and the predicate
 * agree exactly), so test_wave_drag_preview.tcl DM6 counts the sites at source
 * level.
 *   graph_preview_arm   THE ONE WRITER. Copies at most GRAPH_MAX_PREVIEW_WAVES
 *                       (gi, node) pairs, sets the count, sets the HEAD from
 *                       element 0 and sets the scale -- together, so the head can
 *                       never drift from the set. scale == 0.0 or n <= 0 zeroes
 *                       all five fields, so the DISARM has one home too.
 *   graph_preview_has   THE ONE DRAW-SIDE TEST. 0 immediately when nothing is
 *                       armed, so at rest it costs one compare. */
extern void graph_preview_arm(const int *gis, const int *waves, int n, double scale);
extern int  graph_preview_has(int gi, int wcnt);
/* NET-HIGHLIGHT STYLES ON WAVEFORM TRACES
 * (doc/claude/specs/wave_trace_hilight.md). Same one-writer/one-predicate
 * discipline as the two sets above, for the same measured reason: with ONE
 * highlighted trace a bare `gi == .. && ni == ..` and the predicate agree
 * exactly, so a missed site is invisible behaviourally.
 *   wave_hilight_write     THE ONE WRITER. Copies at most
 *                          GRAPH_MAX_HILIGHT_WAVES (gi, ni, style) triples,
 *                          drops negatives, dedupes on (gi, ni) keeping the LAST
 *                          style given, sets the count -- and invalidates the
 *                          envelope cache, so a stale envelope can never outlive
 *                          the entry it belonged to.
 *   wave_hilight_set       add / re-style / (style < 0) remove ONE trace.
 *                          Returns 1 when the set changed, 0 otherwise (an
 *                          unknown trace to remove, or the cap already full).
 *   wave_hilight_clear     drop every entry of graph `gi`, or ALL for gi < 0.
 *                          Returns how many entries went.
 *   wave_hilight_style_of  THE ONE DRAW/QUERY-SIDE TEST: the style index of
 *                          (gi, ni), or -1. 0 immediately when nothing is
 *                          highlighted, so at rest it costs one compare.
 *   wave_hilight_points    how many points the envelope of (gi, ni) holds, 0
 *                          when there is no envelope to have. The seam a
 *                          headless leg uses to assert that decimation really
 *                          happened -- so it BUILDS one when the cache has none
 *                          (the paint path that would fill it is has_x-gated,
 *                          and a pure cache read would answer 0 forever under
 *                          --nogui), and it goes through the SAME keyed lookup
 *                          the painter does, never a looser (gi, ni)-only one.
 *   wave_hilight_cache_free  free every cached envelope (clear_drawing,
 *                          free_xschem_data). Losing the cache is a rebuild.
 *   draw_wave_hilight      THE OVERLAY PAINTER, window-only chrome. `erase`
 *                          copies each entry's previous bbox back from
 *                          save_pixmap first -- that is the standalone
 *                          animation frame; a frame that went through draw()
 *                          passes 0, because the region was just repainted. */
extern int  wave_hilight_write(const int *gis, const int *nis, const int *styles, int n);
extern int  wave_hilight_set(int gi, int ni, int style);
extern int  wave_hilight_clear(int gi);
extern int  wave_hilight_style_of(int gi, int ni);
extern int  wave_hilight_points(int gi, int ni);
extern void wave_hilight_cache_free(void);
extern void draw_wave_hilight(int erase);
/* Which LEGEND entry of graph `i` is under the CANVAS PIXEL (px, py)? The NODE
 * index, or -1. Fails closed. doc/claude/issues/0175-*.md D5. */
extern int  graph_legend_at(int i, double px, double py);
/* --- waveform markers, doc/claude/specs/graph_markers.md --- */
extern int  graph_point_at(int i, double px, double py, double tol,
                           int restrict_wave, int restrict_dataset, GraphPointHit *hit);
extern int  graph_markers_parse(const char *prop_ptr, GraphMarker **arr, int *n);
extern void graph_markers_format(char **dest, const GraphMarker *arr, int n);
extern void graph_markers_store(xRect *r, const GraphMarker *arr, int n);
extern int  graph_marker_next_number(void);
extern int  graph_marker_max_number(void);
extern int  graph_marker_find(int num, int *graph_idx, GraphMarker *out);
extern int  graph_marker_text(int num, char *dest, int destsize);
extern int  graph_marker_at(int i, double px, double py, double tol, int *part);
extern int  graph_marker_create(int i, double px, double py, int delta);
extern int  graph_marker_create_at(int i, int wave, int dataset, int point, int delta,
                                   int have_xy, double xin, double yin);
extern int  graph_marker_delete(int num);
extern int  graph_marker_delete_all(int graph_idx);
extern int  graph_marker_delete_selected(void);
extern int  graph_marker_move(int num, double px, double py);
extern int  graph_marker_anchor_at(int num, int dataset, int point, int have_xy,
                                   double xin, double yin);
extern int  graph_marker_label_offset(int num, double ldx, double ldy);
extern int  graph_marker_select(int num, int graph_idx);
extern int  graph_marker_is_selected(int num);
extern int  graph_marker_select_set(const int *nums, int n, int graph_idx);
extern int  graph_marker_select_pair(int num, int graph_idx);
extern int  graph_marker_renumber_rect(xRect *r);
extern void graph_marker_notify(void);
extern void setup_graph_data(int i, int skip, Graph_ctx *gr);
extern int graph_fullyzoom(xRect *r,  Graph_ctx *gr, int graph_dataset);
extern int graph_fullxzoom(int i, Graph_ctx *gr, int dataset);
/* spec D4: the registry slots a cursor on graph rect `r` must resolve in.
 * Read-only; leaves both halves of the registry cursor where it found them.
 * See the D4 comment block in draw.c and
 * doc/claude/specs/mixed_signal_signal_browser.md row D4. */
extern int graph_cursor_dbs(xRect *r, int **slots);
extern void sleep_ms(int milliseconds);
extern double timer(int start);
extern void enable_layers(void);
extern void set_snap(double);
/* reference length the auto line width / junction-dot radius scale with; the live
 * cadsnap only when `linewidth_follows_snap` (MIRRORED IN TCL) is set. actions.c */
extern double linewidth_ref_snap(void);
extern void set_dotsize_from_snap(void);
extern void set_grid(double);
extern void create_plot_cmd(void);
extern int set_modify(int mod); /* return number of floaters */
extern int begin_edit(const char *op); /* read-only edit gate: 1 = refuse (issue 0041) */
extern int file_writable(const char *name); /* 1 if path is writable (or check unsupported) */
extern int there_are_floaters(void);
#include "util.h" /* memory/string/file/debug utilities (extracted from editprop.c) */
extern unsigned int hash_file(const char *f, int skip_path_lines);
extern void here(double i);
extern void print_version(void);
extern int set_netlist_dir(int what, const char *dir);
extern void netlist_options(int i);
extern int  check_lib(int what, const char *s);
extern int floaters_from_selected_inst();
extern void select_all(void);
extern void change_linewidth(double w);
extern int copy_hierarchy_data(const char *from_win_path, const char *to_win_path);
extern int schematic_in_new_window(int new_process, int dr, int force, int win);
/* issue 0258: 0 nothing done, 1 opened, 2 switched to the window already holding it, 3 refused */
extern int symbol_in_new_window(int new_process);
extern void new_xschem_process(const char *cell, int symbol);
extern void ask_new_file(int in_new_window, char *filename);
extern void saveas(const char *f, int type);
extern const char *get_file_path(char *f);
extern int save(int confirm, int fast);
extern void save_ascii_string(const char *ptr, FILE *fd, int newline);
extern Hilight_hashentry *bus_hilight_hash_lookup(const char *token, int value, int what) ;
/* wrapper function to hash highlighted instances, avoid clash with net names */
extern Hilight_hashentry *inst_hilight_hash_lookup(int i, int value, int what);
/* wrapper to bus_hilight_hash_lookup that provides a signal path instead of using xctx->sch_path */
extern Hilight_hashentry *hier_hilight_hash_lookup(const char *token, int value, const char *path, int what);
extern Hilight_hashentry *hilight_lookup(const char *token, int value, int what);
extern int search(const char *tok, const char *val, int sub, int sel, int match_case, int dr);
extern int process_options(int argc, char **argv);
extern void calc_drawing_bbox(xRect *boundbox, int selected);
extern int ps_draw(int what, int fullzoom, int eps);
extern void svg_draw(void);
extern void svg_embedded_graph(FILE *fd, int i, double rx1, double ry1, double rx2, double ry2);
extern void set_viewport_size(int w, int h, double lw);
extern void print_image();
extern int grabscreen(const char *win_path, int event, int mx, int my, KeySym key,
                 int button, int aux, int state);
extern int xserver_ok(void);
extern const char *get_trailing_path(const char *str, int no_of_dir, int skip_ext);
extern const char *get_cell(const char *str, int no_of_dir);
extern const char *get_cell_w_ext(const char *str, int no_of_dir);
extern const char *rel_sym_path(const char *s);
extern const char *abs_sym_path(const char *s, const char *ext);
extern const char *sanitized_abs_sym_path(const char *s, const char *ext);
extern const char *sanitize(const char *name);
extern const char *add_ext(const char *f, const char *ext);
extern void make_symbol(void);
/* sort based on pinnumber pin attribute if present */
extern void make_schematic_symbol_from_sel(void);
extern const char *get_sym_template(char *s, char *extra);
/* bit0: invoke change_linewidth(), bit1: centered zoom */
extern void zoom_full(int draw, int sel, int flags, double shrink);
extern void updatebbox(int count,xRect *boundbox,xRect *tmp);
extern void draw_selection(GC g, int interruptable);
extern void draw_scope_highlight(void);     /* apply-scope white-outline overlay */
extern void clear_scope_highlight(void);
extern void add_scope_highlight(int type, unsigned int id);
extern void draw_hover_shape(GC g, int type, int n, int c); /* hover outline for one object */
extern void draw_hover(int force);          /* hover (awareness) highlight, motion-driven */
extern void draw_flylines(int force);       /* hover fly-line overlay (hover_flylines.md, Track B) */
extern void flyline_restamp(void);          /* re-stroke the tracked fly-line star after a full redraw */
extern int delete_wires(int selected_flag);
extern void delete(int to_push_undo);
extern void delete_only_rect_line_arc_poly(void);
extern void polygon_bbox(double *x, double *y, int points, double *bx1, double *by1, double *bx2, double *by2);
extern void arc_bbox(double x, double y, double r, double a, double b,
                     double *bx1, double *by1, double *bx2, double *by2);
extern void bbox(int what,double x1,double y1, double x2, double y2);
extern int set_text_custom_font(xText *txt);
extern int text_bbox(const char * str,double xscale, double yscale,
            short rot, short flip, int hcenter, int vcenter, 
            double x1,double y1, double *rx1, double *ry1,
            double *rx2, double *ry2, int *cairo_lines, double *longest_line);
extern void create_memory_cairo_ctx(int what);
extern int hilight_graph_node(const char *node, int col);
extern int get_color(int value);
extern NetHilightStyle *get_hilight_style(int value);
extern unsigned int get_hilight_pixel(int value);
extern int hilight_custom_rgb8(int value, unsigned char *r, unsigned char *g, unsigned char *b);
extern void resolve_hilight_style_rgb(NetHilightStyle *st);
extern unsigned int find_best_color(char colorname[]);
extern void build_net_hilight_styles(void);
extern void net_hilight_invalidate_other_styles(void); /* force OTHER windows to rebuild their table */
extern void net_hilight_redraw_other_windows(void);    /* repaint OTHER detached windows after an edit */
/* Pass 2a net-highlight animation (blink). See doc/claude/specs/net_hilight_styles.md §2 (Pass 2). */
extern double net_hilight_now_ms(void);                 /* wall-clock ms (or test override) */
extern int net_hilight_style_on_now(NetHilightStyle *st, double now); /* blink ON/OFF gate */
extern double net_hilight_dash_period(NetHilightStyle *st); /* dash repeat (odd-len doubled) */
extern double net_hilight_march_offset(NetHilightStyle *st, double now); /* Pass 2b dash scroll */
extern Xschem_ctx *net_hilight_borrow_ctx(const char *win_path); /* repoint xctx at win (no GUI fx) */
extern void net_hilight_restore_ctx(Xschem_ctx *saved);  /* undo net_hilight_borrow_ctx() */
extern int net_hilight_win_known(const char *win_path);  /* is win an open window? (vs borrow NULL) */
extern int net_hilight_ctx_busy(void);                   /* current window busy (gesture OR semaphore)? */
extern int net_hilight_ctx_gesturing(void);              /* current window mid-GESTURE? (anim E1 guard) */
extern void net_hilight_sync_descend_windows(void);      /* push a highlight change into linked descend-new-window children (issue 0073) */
extern void net_hilight_sync_suspend(void);              /* bracket a bulk-highlight loop: suppress the per-net cross-window sync ... */
extern void net_hilight_sync_resume(void);               /* ... then run ONE sync at the end (issue 0073 §9d / review perf) */
extern void net_hilight_set_relay_enable(int v);         /* toggle the deep-gap relay (issue 0073 §9c fix); test/kill switch */
extern int  net_hilight_get_relay_enable(void);          /* read the deep-gap relay enable flag */
extern void net_hilight_set_sync_force_headless(int v);  /* TEST: run cross-window sync under --nogui (issue 0073 §8 Tier C) */
extern Xschem_ctx *alloc_scratch_xschem_ctx(void);       /* windowless scratch ctx for the deep-gap relay's transient loads */
extern void free_scratch_xschem_ctx(void);               /* tear down alloc_scratch_xschem_ctx()'s ctx (delete_schematic_data(0)) */
extern const char *get_drw_front_win(void);              /* win-path of the tab currently shown on the shared .drw canvas (issue 0073) */
/* Adaptive net-highlight tick bounds (ms): floor caps the wake rate near a blink edge; the
 * ceiling bounds reconcile lag after an external full draw; BUSY = paused-retry cadence. Shared
 * with scheduler.c's redraw_hilight_region busy path so the two retry cadences can't drift. */
#define NET_HILIGHT_TICK_MIN  16.0
#define NET_HILIGHT_TICK_MAX  250.0
#define NET_HILIGHT_TICK_BUSY 50.0
extern int net_hilight_has_animation(void);             /* window needs the animation tick? */
extern int draw_hilight_region(double *next_ms);        /* regional redraw of animating nets */
extern void net_hilight_anim_update(void);              /* (re)evaluate start/stop of the tick */
extern void draw_hilight_wire(unsigned int fg, NetHilightStyle *st, double dash_offset,
                              double linex1, double liney1, double linex2, double liney2, double bus);
extern void draw_hilight_dot(unsigned int fg, double x, double y, double r);
extern void incr_hilight_color(void);
extern void decr_hilight_color(void);
extern void get_inst_pin_coord(int i, int j, double *x, double *y);
extern void get_pin_escape_normal(int i, int r, double *nx, double *ny);

extern void del_inst_table(void);
extern void hash_inst(int what, int n);
extern void hash_instances(void); /*  20171203 insert instance bbox in spatial hash table */

extern void del_wire_table(void);
extern void hash_wire(int what, int n, int incremental);
extern void hash_wires(void);

extern void del_object_table(void);
extern void hash_object(int what, int type, int n, int c);
extern void hash_objects(void); /* hash all objects */

#if HAS_CAIRO==1
extern cairo_status_t png_reader(void* in_closure, unsigned char* out_data, unsigned int length);
extern cairo_status_t png_writer(void *in_closure, const unsigned char *in_data, unsigned int length);
extern int text_bbox_nocairo(const char * str,double xscale, double yscale,
            short rot, short flip, int hcenter, int vcenter,
            double x1,double y1, double *rx1, double *ry1,
            double *rx2, double *ry2, int *cairo_lines, double *longest_line);
#endif

extern Selected select_object(double mx,double my, unsigned short sel_mode,
                                    int override_lock, const Selected *selptr);
extern int set_first_sel(unsigned short type, int n, unsigned int col);
extern void unselect_all(int dr);
/* issue 0241: stamp / forget / re-select the object set a modal cursor placement is made of,
 * so its teardown deletes the PREVIEW and not whatever happens to be selected. See select.c. */
extern void stamp_placement_preview(void);
extern void clear_placement_preview(void);
extern int select_placement_preview(void);
extern void drag_sel_free(void);          /* cadence deferred-selection: reset the pre-press snapshot */
extern void drag_sel_snapshot(void);      /* snapshot pre-press selection ids before a transient drag-select */
extern void drag_sel_restore_now(void);   /* restore the pre-press selection after a moved drag */
extern void select_attached_nets(void);
extern void select_inside(int stretch, double x1,double y1, double x2, double y2, int sel);
extern void select_touch(double x1,double y1, double x2, double y2, int sel);
/*  Select all nets that are dangling, ie not attached to any non pin/port/probe components */
extern int select_dangling_nets(void);
extern void tclmainloop(void);
extern int Tcl_AppInit(Tcl_Interp *interp);
extern void abort_operation(int deselect);
/* issue 0245: the body of `case XK_Escape:` -- abort_operation(escape_deselects) behind the
 * `semaphore < 2` guard, plus the four reentrant siblings (tclstop, MENUSTARTWIRE clear,
 * snap-cursor erase, the cadence resting-wire fixup). Named and exported so a Tk form that
 * seized `.drw <Key-Escape>` can forward to it (`xschem escape`) instead of swallowing Escape.
 * NOT the same teardown as abort_operation() -- see the comment in callback.c. */
extern void escape_terminal(void);
extern void enter_deselect_mode(void);
extern void draw_crosshair(int what, int state);
extern void start_line(double mx, double my);
extern void start_wire(double mx, double my);
/* issue 0243 F2 (and 0242): tear down a modal cursor placement preview / the gate that does it
 * before a wire or line draw is armed on top of one. See callback.c. */
extern int abort_placement_preview(void);
extern void check_placement_preview_invariant(const char *where); /* issue 0242 tripwire */
/* issue 0262 (ratified 2026-08-11): the tripwire's REPAIR half -- un-stick sympin_preview /
 * wirelabel_preview / the preview_sel stamp after an ungated door dropped the gesture bits, so the
 * canvas is orphan-only instead of dead. Deletes nothing. See callback.c. */
extern int repair_orphan_placement_preview(void);
extern int leave_placement_for(const char *what);
/* issue 0265: the same pair for a pending PASTE/MERGE (STARTMERGE). abort_pending_merge() is the
 * teardown abort_operation()'s two arms carried inline until it grew a third caller;
 * leave_merge_for() is the gate every ARM calls so a second gesture cancels the pending paste
 * instead of silently committing it. See callback.c. */
extern int abort_pending_merge(void);
extern int leave_merge_for(const char *what);
/* the forward gate (issue 0240 / 0243 F1, widened to every remaining draw and placement verb by
 * phases 1-2 of doc/claude/suggestions/plan_modal_gesture_exclusion.md). Lives in scheduler.c
 * next to the arms that first needed it; callback.c / actions.c / draw.c arms call it too. */
extern void leave_wire_draw_for(const char *what);
extern int abort_wire_line_command(void); /* issue 0240 */
/* issue 0269 / plan phase 3: the fourth pair, for a SHAPE draw (rectangle, polygon, arc, circle,
 * zoom box) in both its states -- STARTRECT|STARTPOLYGON|STARTARC|STARTZOOM in ui_state, or
 * MENUSTART plus a MENUSTARTSHAPE bit in ui_state2. abort_shape_draw() is the teardown (band erase
 * + bit clear, no delete and no undo baseline: a shape draw stores nothing until it completes);
 * leave_shape_draw_for() is the gate every ARM calls. See callback.c. */
extern int abort_shape_draw(void);
extern void leave_shape_draw_for(const char *what);
/* issue 0257: the FIFTH teardown, for a persistent CLICK MODE (NET_HILIGHT / NET_UNHILIGHT /
 * DESEL_MODE) -- the three gestures that own Button-1 from a resting ui_state bit and whose press
 * arms `return` ahead of check_menu_start_commands(), so an armed descend pick never sees its
 * click. Returns the NAME of the mode it ended (static string) or NULL. It has no
 * leave_click_mode_for() wrapper on purpose: its only caller arms a held prompt one statement
 * later, which would replace any gate line written here, so the caller composes one sentence
 * carrying both facts (issue 0241). See callback.c. */
extern const char *abort_click_mode(void);
extern void backannotate_at_cursor_b_pos(xRect *r, Graph_ctx *gr);
/* S11: resolve cursor B against xctx->raw with NO graph object involved, so
 * `xschem set cursor2_x <t>` annotates on a schematic with nothing plotted.
 * Returns 1 if it annotated, 0 if there was no data and the call was a no-op.
 * See callback.c for why the rect is synthetic and the Graph_ctx is a stack
 * local carrying an explicit whole-sweep window. */
extern int backannotate_at_cursor_b_nograph(void);
/* extern void snapped_wire(double c_snap); */
extern void unselect_attached_floaters(void);
extern int callback(const char *win_path, int event, int mx, int my, KeySym key,
                        int button, int aux, int state);
/* Phase 3 (action-logging): act_* bodies shared with the `xschem
 * pan|scroll|snap|toggle_*` subcommands (callback.c) */
extern int view_pan_dir(const char *dir);
extern int view_scroll_dir(const char *dir);
extern void view_snap_change(int dbl);
extern void toggle_stretch_cmd(void);
extern void toggle_show_netlist_cmd(void);
extern void toggle_orthogonal_wiring_cmd(void);
extern void toggle_draw_pixmap_cmd(void);
/* Phase 3 data-driven input bindings (callback.c); backends for the
 * `xschem bind`/`unbind`/`bindings` subcommands. See
 * doc/claude/suggestions/refactor_plan_action_registry_phase3.md */
extern int action_cmd_set_log_cmd(int argc, const char **argv);
extern int action_cmd_set_nolog(int argc, const char **argv);
/* action-log: is s safe to embed in a logged command as a {braced} Tcl word?
 * (callback.c; conservative -- refuses braces and backslashes) */
extern int tcl_braceable(const char *s);
extern int action_cmd_bind(int argc, const char **argv);
extern int action_cmd_unbind(int argc, const char **argv);
extern int action_cmd_bindings(int argc, const char **argv);
extern void resetwin(int create_pixmap, int clear_pixmap, int force, int w, int h);
extern Selected find_closest_obj(double mx,double my, int override_lock);
/* instance-only, read-only point query: index of the instance under (mx,my), or -1.
 * Selects nothing. See doc/claude/issues/0200-descend-has-no-verb-noun-pick.md */
extern int find_closest_instance(double mx, double my, int override_lock);
/* Hover fly-lines (flyline.c, doc/claude/specs/hover_flylines.md). Read-only (invariant C1). */
extern const char *flyline_net_of(unsigned short type, int n, unsigned int col);
extern void flyline_compute(const char *netname, int have_pick, const Selected *pick,
                            double mx, double my, FlyResult *res);
extern void flyline_hub_point(const Selected *pick, double mx, double my, double *hx, double *hy);
extern void flyline_result_free(FlyResult *res);
/* find the instance pin within a tight radius of (mx,my); returns 1 and fills *r
 * (type=INST_PIN, n=instance, col=pin) on hit, 0 otherwise. See pin_selection.md */
extern int find_closest_pin(double mx, double my, Selected *r);
/*extern void find_closest_net_or_symbol_pin(double mx,double my, double *x, double *y);*/
extern int find_closest_net_or_symbol_pin(double mx,double my, double *x, double *y);

extern void drawline(int c, int what, double x1,double y1,double x2,double y2, double bus, int dash, void *ct);
/* drawline with an independent OFF run (dash_off <= 0 = same as dash, i.e.
 * drawline's historical 50% duty cycle). See draw.c. */
extern void drawline_duty(int c, int what, double x1,double y1,double x2,double y2,
                          double bus, int dash, int dash_off, void *ct);
extern void draw_xhair_line(GC gc, int size, double linex1, double liney1, double linex2, double liney2);
/* viewer plan item 9: the graph snap cursor. draw_graph_snap_cursor() is the
 * hover pump (query + repaint); graph_snap_clear() erases and disarms. */
extern int  graph_plotbox_at(int i, double px, double py);
/* --- axis-region drag zoom (issue 0190, doc/claude/specs/waveform_viewer_modes.md
 * §17). Query / formula / apply, deliberately three functions: the FORMULA has
 * exactly one home so the gesture (callback.c) and the replayable verb
 * (scheduler.c) cannot drift apart, and exposing it as `xschem get
 * graph_axis_map` is what lets a headless suite assert BOTH endpoints of a zoom
 * instead of only its width (landmine 45(a) in a second shape). */

/* Which axis-number MARGIN of graph `i` the CANVAS PIXEL (px, py) is in:
 * GRAPH_AXIS_X (below the plot box), GRAPH_AXIS_Y (left of it) or
 * GRAPH_AXIS_NONE. Pure geometry, and it deliberately does NOT copy
 * graph_plotbox_at's raw requirement or its digital refusal: an empty strip and
 * a digital strip both have meaningful axes. It DOES decline the reorder-grip
 * column and any pixel graph_legend_at claims (the vertical and digital legends
 * ARE the left margin). Fails closed on a bad index / non-graph rect /
 * off-screen graph. */
extern int  graph_axis_at(int i, double px, double py);
/* THE MAP, in one place. `p0`/`p1` are canvas pixels along `axis` (px for X, py
 * for Y): the press and the release. Writes the new data window to *lo/*hi and
 * returns 1; returns 0 for a bad index / no transform / travel <= `clicktol`
 * screen pixels. Both endpoints come out of one anchored linear map -- a
 * width-only implementation slides the window sideways and still passes every
 * "the range grew" assertion. Works in `gr` space, which IS log space when
 * logx/logy is set (landmine 35 from the other side: do NOT pow(10,.) here). */
extern int  graph_axis_map(int i, int axis, double p0, double p1,
                           double *lo, double *hi, double clicktol);
/* THE WHEEL formula's one home (issue 0191, §18), the twin of the map above.
 * `p` is a CANVAS PIXEL along `axis` (px for X, py for Y) -- the pointer -- and
 * `dir` is +1 for one click IN, -1 for one click OUT. Writes the new data window
 * to *lo/*hi and returns 1; returns 0 for a bad index / a non-graph rect / no
 * transform / a degenerate window.
 * The factor lives INSIDE (GRAPH_AXIS_WHEEL_FACTOR) rather than being an
 * argument, so the constant has exactly one home and a suite driving
 * `xschem get graph_axis_wheel_map` is driving the product's own step size.
 * THE FIXED POINT IS THE SPECIFICATION: the data coordinate under `p` keeps its
 * fraction of the window and therefore its screen pixel. lo = q - u*R2 is that
 * anchor; a width-only form has the right WIDTH in the wrong PLACE and passes
 * every "the range shrank" assertion. Log axes need nothing special -- gr space
 * IS log space when logx/logy is set (landmine 35 from the other side). */
extern int  graph_axis_wheel_map(int i, int axis, double p, int dir,
                                 double *lo, double *hi);
/* The click-vs-drag TRAVEL threshold in SCREEN PIXELS, i.e. what the gesture
 * hands graph_axis_map() as `clicktol`. The constant behind it (callback.c's
 * GRAPH_CLICK_TOL) stays file-private -- in this header it would read as
 * GRAPH_TRACE_PICK_TOL's twin and it is not (landmine 20) -- but the ONE other
 * caller of graph_axis_map(), the `xschem get graph_axis_map` getter, must use
 * the same number the gesture does or the suite driving that getter is driving
 * a different threshold from the product (landmine 45(a)). Accessor, not a
 * second #define. */
extern double graph_click_tol(void);
/* THE APPLY, in one place, shared by the gesture and by `xschem graph_axis_zoom`.
 * X writes x1/x2 on rect `i` AND on every PARTICIPATING rect (the shipped
 * predicate of the MMB pan / RMB box zoom); Y writes y1/y2 -- or ypos1/ypos2 on
 * a digital strip -- on rect `i` only. No set_modify, no push_undo (landmine 19:
 * a graph gesture is view state), one log_action line in the verb form so a
 * replay reproduces the whole propagation. Returns 1 when anything was written. */
extern int  graph_axis_zoom(int i, int axis, double lo, double hi);
extern void draw_graph_snap_cursor(int mx, int my);
extern void graph_snap_clear(void);
extern void draw_string(int layer,int what, const char *str, short rot, short flip, int hcenter, int vcenter,
       double x1, double y1, double xscale, double yscale);
extern void get_sym_text_size(int inst, int text_n, double *xscale, double *yscale);
extern void get_sym_text_layer(int inst, int text_n, int *layer);
extern void draw_symbol(int what,int c, int n,int layer,
            short tmp_flip, short tmp_rot, double xoffset, double yoffset);
extern void drawrect(int c, int what, double rectx1,double recty1,
            double rectx2,double recty2, double bus, int dash, int e_a, int e_b);
extern void filledrect(int c, int what, double rectx1,double recty1,
            double rectx2,double recty2, int fill, int e_a, int e_b);


extern void drawtempline(GC gc, int what, double x1,double y1,double x2,double y2);
extern void recompute_orthogonal_manhattanline(double linex1, double liney1, double linex2, double liney2);
extern void drawtemp_manhattanline(GC gc, int what, double x1,double y1,double x2,double y2, int force_manhattan);

/* instead of doing a drawtemprect(xctx->gctiled, NOW, ....) do 4 
 * XCopy Area operations. Used if fix_broken_tiled_fill is set */
extern void fix_restore_rect(double x1, double y1, double x2, double y2);

extern void drawtemprect(GC gc, int what, double rectx1,double recty1,
            double rectx2,double recty2);
extern void drawtemparc(GC gc, int what, double x, double y, double r, double a, double b);
extern void drawarc(int c, int what, double x, double y, double r, double a, double b,
            int arc_fill, double bus, int dash);
extern void filledarc(int c, int what, double x, double y, double r, double a, double b);
extern void drawtemppolygon(GC gc, int what, double *x, double *y, int points, int flags);
extern void drawbezier(Drawable w, GC gc, int c, double *x, double *y, int points, int fill);
extern void drawpolygon(int c, int what, double *x, double *y, int points, int poly_fill,
            int dash, double bus, int flags);
extern void draw_temp_symbol(int what, GC gc, int n,int layer,
            short tmp_flip, short tmp_rot, double xoffset, double yoffset);
extern void draw_temp_string(GC gc,int what, const char *str, short rot, short flip, int hcenter, int vcenter,
       double x1, double y1, double xscale, double yscale);

extern void MyXCopyAreaDouble(Display* display, Drawable src, Drawable dest, GC gc,
     double sx1, double sy1, double sx2, double sy2, double dx1, double dy1, double lw);
extern void draw(void);
extern void clip_xy_to_short(double x, double y, short *sx, short *sy);
/* clip a line (in screen coordinates) with screen boundaries */
extern int clip( double*,double*,double*,double*);
/* clip a line (xa,ya,xb,yb) with rectangle (sx1,sy1,sx2,sy2) */
extern int lineclip(double *xa,double *ya,double *xb,double *yb, 
             double sx1,double sy1,double sx2,double sy2);
extern int textclip(int x1,int y1,int x2,int y2,
           double xa,double ya,double xb,double yb);
extern double dist_from_rect(double mx,
              double my, double x1, double y1, double x2, double y2);
extern double dist(double x1,double y1,double x2,double y2,double xa,double ya);
extern double rectdist(double x1,double y1,double x2,double y2,double xa,double ya);
extern int touch(double,double,double,double,double,double);
extern int rectclip(int,int,int,int,
           double*,double*,double*,double*);
extern void trim_wires(void);
extern void update_conn_cues(int layer, int draw_cues, int dr_win);
extern void break_wires_at_point(double x0, double y0, int align);
extern void break_wires_at_pins(int remove);
extern int break_wires_at_attach_points(void);
extern void maintain_wire_segments(void);
extern int merge_collinear_wires(xWire *list, int n, int ignore_pins);

extern void check_touch(int i, int j,
         unsigned short *parallel,unsigned short *breaks,
         unsigned short *broken,unsigned short *touches,
         unsigned short *included, unsigned short *includes,
         double *xt, double *yt);

extern int storeobject(int pos, double x1,double y1,double x2,double y2,
                        unsigned short type,unsigned int rectcolor,
                        unsigned short sel, const char *prop_ptr);
extern int wire_store(int pos, double x1, double y1, double x2, double y2,
                        unsigned short sel, const char *prop_ptr);
extern int wire_store_split(int src, double x0, double y0, unsigned short sel);
extern int wire_delete_compact(int (*doomed)(int n, void *arg), void *arg);
extern void wire_storage_reset(void);
extern int wire_index_from_id(unsigned int id);
extern int inst_delete_compact(int (*doomed)(int n, void *arg), void *arg);
extern void inst_storage_reset(void);
extern void inst_register(int n);
extern int inst_index_from_id(unsigned int id);
extern void gfx_register(int type, int c, int n);
extern int gfx_index_from_id(int type, unsigned int id, int *layer_out);
extern void text_register(int n);
extern int text_index_from_id(unsigned int id);
extern void store_poly(int pos, double *x, double *y, int points,
           unsigned int rectcolor, unsigned short sel, char *prop_ptr);
extern void store_arc(int pos, double x, double y, double r, double a, double b,
               unsigned int rectcolor, unsigned short sel, const char *prop_ptr);

/* issue 0498: the hierarchy walks (the five global_*_netlist drivers and hier_psprint)
 * save and restore the user's document with their OWN xctx->push_undo()/pop_undo() pair.
 * That pair is the WALK's save/restore, not editing undo, so it must not be disableable by
 * xctx->no_undo (which silently no-ops both halves -- save.c, in_memory_undo.c). Take the
 * shield immediately before push_undo(), drop it on EVERY exit path (spec op_annotation.md
 * section 5, invariant I6). */
extern int undo_shield_push(void);
extern void undo_shield_pop(int saved);
extern void hier_psprint(char **res, int what);
extern int global_spice_netlist(int global, int alert);
extern int global_spectre_netlist(int global, int alert);
extern int global_tedax_netlist(int global, int alert);
extern int global_vhdl_netlist(int global, int alert);
extern int global_verilog_netlist(int global, int alert);
extern int vhdl_block_netlist(FILE *fd, int i, int alert);
extern int verilog_block_netlist(FILE *fd, int i, int alert);
extern int spice_block_netlist(FILE *fd, int i, int alert);
extern int spectre_block_netlist(FILE *fd, int i, int alert);
extern void remove_symbols(void);
extern void remove_symbol(int i);
extern void clear_drawing(void);
extern void get_sym_type(const char *symname, char **type,       
                         Int_hashtable *pintable, FILE *embed_fd, int *sym_n_pins);
extern int is_from_web(const char *f);
extern int load_sym_def(const char name[], FILE *embed_fd);
extern int descend_symbol(void);
extern int place_symbol(int pos, const char *symbol_name, double x, double y, short rot, short flip,
                         const char *inst_props, int draw_sym, int first_call, int to_push_undo);
extern int editing_symbol_view(void);
extern void place_net_label(int type);
extern int place_sch_pin(const char *name, const char *dir);
extern int place_wire_label(const char *name);
extern int point_on_wire_or_pin(double x, double y);
extern int inst_is_netlabel(int i);  /* wire_label_ride.md §5.2: symbol type is exactly "label" */
extern int wire_label_try_commit(void);
extern void attach_labels_to_inst(int interactive);
extern void clear_partial_selected_wires(void);
extern int connect_by_kissing(void);
extern int unselect_partial_sel_wires(void);
extern void delete_files(void);
extern int sym_vs_sch_pins(int all);
extern char *get_generator_command(const char *str);
extern int match_symbol(const char name[]);
extern Sch_pin_record *sort_schematic_pins(int *npins);
extern int save_schematic(const char *, int fast); /*  20171020 added return value */
extern int backup_file_name(char *dest, int destsize, const char *src);
extern void write_backup(void);
extern void remove_backup(void);
extern int load_backup_as(const char *cellfile, int set_title);
extern int hierarchy_modified(void);
extern void copy_symbol(xSymbol *dest_sym, xSymbol *src_sym);
extern void push_undo(void);
extern void pop_undo(int redo, int set_modify_status);
extern void delete_undo(void);
extern void clear_undo(void);
extern void mem_push_undo(void);
extern void mem_pop_undo(int redo, int set_modify_status);
extern void mem_serialize_slot(Undo_slot *s);
extern void mem_restore_slot(Undo_slot *s, int set_modify_status);
/* incremental_wire_reroute Phase II: alloc/free a STANDALONE snapshot slot (not in uslot[]).
 * mem_snapshot_alloc must run before mem_serialize_slot on a scratch slot (mem_serialize_slot
 * frees prior contents first, dereferencing the per-layer arrays). mem_snapshot_free releases the
 * deep copy AND the per-layer arrays and re-zeroes the slot. */
extern void mem_snapshot_alloc(Undo_slot *s);
extern void mem_snapshot_free(Undo_slot *s);
extern void mem_delete_undo(void);
extern void mem_clear_undo(void);
extern int load_schematic(int load_symbol, const char *fname, int reset_undo, int alert);
/* check if filename already in an open window/tab */
extern int get_tab_or_window_number(const char *win_path);
/* next Cadence-style window number (window_numbering.md counter; ASE-L toplevels) */
extern int allocate_window_number(void);
extern void swap_tabs(void);
extern void swap_windows(int dr);
extern int check_loaded(const char *f, char *win_path);
extern char *get_last_created_window_path(void);
extern int get_last_created_window(void);
extern char *get_window_path(int i);
extern int get_window_count(void);
extern void get_unused_untitled_name(const char *dir, int symbol, char *name, int namesize);
extern Xschem_ctx **get_save_xctx(void);
/* resolve open-window slot i -> its Xschem_ctx (NULL if empty) and, if win_path!=NULL, its window
 * path (".drw" for slot 0). Centralizes the single-schematic/save_xctx[0] invariant (see xinit.c). */
extern Xschem_ctx *get_window_ctx(int i, const char **win_path);
extern Xschem_ctx *get_old_xctx(void);
extern void link_symbols_to_instances(int from);
extern void load_ascii_string(char **ptr, FILE *fd);
extern char *read_line(FILE *fp, int dbg_level);
extern void read_record(int firstchar, FILE *fp, int dbg_level);
extern void create_sch_from_sym(void);
extern void get_sch_from_sym(char *filename, xSymbol *sym, int inst, int fallback);
extern const char *get_sym_name(int inst, int ndir, int ext, int abs_path);
extern void toggle_ignore(void);
extern void get_additional_symbols(int what);
extern int change_sch_path(int instnumber, int dr);
extern int descend_schematic(int instnumber, int fallback, int alert, int set_title);
/* ---------------------------------------------------------------------------
 * The descend refusal channel (issues 0249 / 0251 / 0254 / 0366). Record ALWAYS,
 * speak SELECTIVELY. See xctx->descend_err above and
 * doc/claude/code_analysis/descend_silent_refusal_census.md.
 * Each piece is a NAMED callee rather than inline code so a sabotage build can
 * neutralize exactly one of them (#define it away) and see which rows go red. */
extern void descend_clear_error(void);   /* both verbs call this on entry */
extern int  descend_speak_p(int speak);  /* the loud/silent PREDICATE */
extern void descend_speak(const char *msg); /* statusmsg_hold(): 0248-safe, never dbg(0) */
extern void descend_set_error(const char *code, const char *detail, const char *msg, int speak);
/* Resolve WHICH instance to descend into from the VISIBLE selection (ELEMENT
 * entries only -- xctx->lastsel also counts INST_PIN pseudo-selections the user
 * cannot see). Never reads sel_array[0] before proving an entry is live: that is
 * issue 0366's whole defect. Records+speaks its own refusal. 1 = *n is set. */
extern int  descend_pick_target(int *n, int multi_ok, const char *verb);
/* 1 (and reported) when instance n is a ---MISSING SYMBOL--- placeholder. */
extern int  descend_missing_sym(int n, const char *symname);
extern void go_back(int what); /* what == 1: confirm save; what == 2: do not reset window title */
extern void clear_schematic(int cancel, int symbol);
extern void view_unzoom(double z);
extern void view_zoom(double z);
extern void draw_stuff(void);
extern void new_wire(int what, double mx_snap, double my_snap);
extern void new_line(int what, double mx_snap, double my_snap);
extern void new_arc(int what, double sweep, double mousex_snap, double mousey_snap);
extern void arc_3_points(double x1, double y1, double x2, double y2, double x3, double y3,
         double *x, double *y, double *r, double *a, double *b);
/* sel: if set to 1 change references only on selected items, like in a copy operation */
extern void update_attached_floaters(const char *from_name, int inst, int sel);
extern void move_objects(int what,int merge, double dx, double dy);
/* incremental_wire_reroute Phase II: free any armed fluid-reroute snapshot + clear its flags.
 * Called by clear_schematic() so a buffer teardown/reload mid-gesture can't resurrect/leak it. */
extern void fluid_reroute_discard(void);
/* D1 (Track D): free the Fluid_gesture START-snapshot context + clear its armed flag. Called by
 * clear_schematic() alongside fluid_reroute_discard() so a buffer teardown mid-gesture closes the
 * gesture (else the next move START's arm assert would see a leaked-armed context). */
extern void fluid_gesture_free(void);
/* wire_label_ride.md §5.3 (S1): free the per-gesture net-label rider set. Called at move
 * END/ABORT and by clear_schematic() alongside fluid_gesture_free(), so a buffer teardown
 * mid-gesture cannot leak it or apply it to unrelated geometry. */
extern void label_ride_free(void);
/* D6 single-pass harness (scheduler `xschem fluid_snapshot arm` / `xschem fluid_pass <name>`):
 * run one END-cleanup pass in isolation, no gesture/X. arm returns 1 if a valid START snapshot was
 * taken (needs fluid_editing on + >=1 instance pin), else 0; run_pass returns the pass's
 * changed-count, 0 when it fail-safe-declines (no armed snapshot -- gate enforcement), or -1 for an
 * unknown / MANUAL_SITE name. */
extern int fluid_harness_snapshot_arm(void);
extern int fluid_harness_run_pass(const char *name);
/* FLUID_TRACE diagnostic (issue 0083/0123): on-flag, line writer, ui_state stringify, and the
 * runtime start/stop used by the Help>Debug menu (`xschem fluid_trace start|stop`). */
extern int fluid_trace_on(void);
extern void fltrace(const char *fmt, ...);
extern const char *fltrace_uistate(unsigned int s);
extern const char *fltrace_runtime_start(const char *path);
extern const char *fltrace_runtime_stop(void);
extern void check_collapsing_objects();
extern void redraw_w_a_l_r_p_z_rubbers(int force); /* redraw wire, arcs, line, polygon rubbers */
extern void copy_objects(int what);
extern void find_inst_to_be_redrawn(int what);
extern void pan(int what, int mx, int my);
extern void zoom_rectangle(int what);
extern void zoom_box(double x1, double y1, double x2, double y2, double factor);
extern void save_restore_zoom(int save, Zoom_info *zi);
extern void select_rect(int stretch, int what, int select);
extern void new_rect(int what, double mousex_snap, double mousey_snap);
extern void new_polygon(int what, double mousex_snap, double mousey_snap);
extern void compile_font(void);
extern void flip_rotate_ellipse(xRect *r, int rot, int flip);
extern void rebuild_selected_array(void);
extern void pop_undo_keep_selection(int redo, int set_modify); /* undo/redo, keep selection (issue 0007) */

extern int get_instance(const char *s);
extern void edit_property(int x);
extern int apply_instance_properties(const char *scope, unsigned int displayed_id,
                              const char *new_prop, const char *old_prop, int keep_name);
extern int scope_targets(int displayed_inst, const char *scope, int *targets);
extern int pin_scope_targets(int primary_n, const char *scope, int *targets);
/* Cadence-style pin-rename label propagation, doc/claude/specs/pin_rename_propagation.md.
 * Outcome codes: anything past PRR_MERGE means the propagation was REFUSED and no
 * label was touched. The refusals are all-or-nothing on purpose: a partial rewrite
 * makes the sheet look self-consistent while the netlist is wrong, which is worse
 * than not propagating at all. */
enum {
  PRR_OK = 0,     /* proceed                                                    */
  PRR_MERGE,      /* proceed, but NEW is already carried by another net object   */
  PRR_NOT_PIN,    /* source is not ipin/opin/iopin                               */
  PRR_SAME,       /* NEW == OLD                                                  */
  PRR_EMPTY_OLD,
  PRR_EMPTY_NEW,
  PRR_AMBIGUOUS,  /* another pin still carries OLD                               */
  PRR_GLOBAL_OLD, /* OLD is a global net name on this sheet                      */
  PRR_GLOBAL_NEW, /* NEW is a global net name on this sheet                      */
  PRR_BUSOVERLAP, /* a label bit-overlaps OLD without matching it exactly        */
  PRR_SELECTED,   /* a matching label is selected: the caller may be editing it  */
  PRR_BAD_INST
};
/* PURE: which net labels would follow pin <src_inst> from <oldlab> to <newlab>.
 * Reads xctx; writes only targets[] (caller-sized >= xctx->instances) and *status.
 * Returns the count; a 0 with *status past PRR_MERGE means refused. Ignores the
 * pin_rename_propagate preference so the decision can be inspected on its own. */
extern int pin_rename_targets(int src_inst, const char *oldlab, const char *newlab,
                              int *targets, int *status);
extern const char *pin_rename_status_str(int status);
/* Thin mutation shell. <src_inst> is ALREADY renamed; <oldlab> is a COPY of its
 * previous `lab` read with with_quotes=0. Honors the preference, warns on every
 * refusal a user would notice. Caller owns push_undo/set_modify/redraw.
 * Returns the number of net labels rewritten. */
extern int propagate_pin_rename(int src_inst, const char *oldlab);
/* flyline.c: bit-precise bus overlap -- A[1:0] matches A[0], A[1] does not. Read-only. */
extern int flyline_same_net(const char *a, const char *b);
extern int xschem(ClientData clientdata, Tcl_Interp *interp,
           int argc, const char * argv[]);
/* The single mutation/command boundary (Refactor B, audit §4): ONE readonly gate +
 * ONE effect + ONE log site. Entry points (scheduler branch, inline key, menu) call
 * this for a migrated verb instead of the raw core + a scattered readonly/log. Defined
 * in scheduler.c. This atom wires exactly one verb (trim_wires). */
extern int perform_action(const char *verb, int argc, const char *argv[]);
extern const char *tcleval(const char str[]);
extern const char *tclresult(void);
extern const char *tclgetvar(const char *s);
extern int tclgetboolvar(const char *s);
extern int tclgetintvar(const char *s);
extern double tclgetdoublevar(const char *s);
extern void tclsetvar(const char *s, const char *value);
extern void tclsetdoublevar(const char *s, const double value);
extern void tclsetboolvar(const char *s, const int value);
extern void tclsetintvar(const char *s, const int value);
extern int tclvareval(const char *script, ...);
extern const char *tcl_hook2(const char *res);
extern void statusmsg(char str[],int n);
/* issue 0248: statusmsg() + a hold, for lines a user must be able to READ (gate messages,
 * verb-noun prompts). The coordinate readout skips itself while statusmsg_held(). */
extern void statusmsg_hold(char str[],int n);
extern int statusmsg_held(void);
extern void statusmsg_hold_clear(void);
extern int place_text(int draw_text, double mx, double my);
extern int create_text(int draw_text, double x, double y, int rot, int flip, const char *txt,
       const char *props, double hsize, double vsize);
extern void synth_pin_views(void);
extern int create_pin(double x, double y, const char *name, const char *dir, unsigned short sel);
extern int pin_idx_by_id(unsigned int id);
extern int pin_name_view_of(unsigned int pin_id);
extern void pin_view_writeback(int ti);
extern void pin_rename_from_view(int ti);
extern void pin_view_refresh(int pi);
extern void pin_view_apply(int pi);
extern void pin_reorient(int pi);
extern void pin_views_reconcile_after_move(void);
extern void pin_views_reconcile_all(void);
extern int pin_name_visible(const char *prop);
extern void pin_names_sync_cache(void);
/* THE single text-visibility predicate, shared by draw/svg/ps/select/bbox (S7). */
extern int text_hidden(int flags, int ctx);
/* THE single annotation-colour override, shared by the same three back ends (0615).
 * -1 == "no override, use the layer you already computed". */
extern int annot_text_layer(int flags, int ctx);
extern void annot_show_sync_cache(void);
/* ---------------------------------------------------------------------------
 * S9 -- THE DRAW-TIME OP-ANNOTATION OVERLAY (doc/claude/specs/op_annotation.md).
 * ONE shared reader, three thin call sites (draw.c, svgdraw.c, psprint.c). Every
 * policy decision -- the visibility gate, the "is this device annotated at all"
 * gate, the anchor, the render constants -- lives in get_annot_overlay() so the
 * screen and the two exports cannot disagree (decision D2/D3/D9).
 *
 * get_annot_overlay() answers "draw instance n's operating-point block, here":
 * returns 1 and fills *txt (a cached, my_strdup'd block owned by actions.c --
 * do NOT free), the ABSOLUTE anchor *x/*y, the text *size and the text *layer;
 * returns 0 when the instance must not carry a block. It NEVER modifies the
 * schematic (invariant I4): no set_modify, no instance placed, nothing written.
 *
 * annot_overlay_sync() compares the observed-state epoch and flushes the whole
 * per-instance cache when anything it depends on moved. Call it ONCE per frame /
 * per export, beside annot_show_sync_cache().
 *
 * annot_data_changed() is the explicit invalidation the epoch cannot observe: a
 * re-run of the SAME deck republishes into the SAME Raw allocation with identical
 * nvars/level, so without this bump the overlay would show the previous run's
 * numbers -- the one thing invariant I3 forbids. Called by update_op() (save.c)
 * and backannotate_at_cursor_b_pos() (callback.c).
 * ------------------------------------------------------------------------- */
extern int get_annot_overlay(int n, const char **txt, double *x, double *y,
                             double *size, int *layer);
extern void annot_overlay_sync(void);
extern void annot_data_changed(void);
/* hold(1)/hold(0) around an INTERNAL maintenance reset that must not be read as
 * a document change. One caller: prepare_netlist_structs() (netlist.c). */
extern void annot_invalidate_hold(int on);
/* monotonic count of blocks the overlay reader approved; the ONLY seam that can
 * see the draw.c call site, whose whole body is inside if(has_x). Read with
 * `xschem get annot_overlay_count` (scheduler.c), mirroring draw_count. */
extern unsigned int annot_overlay_count;
/* monotonic count of WHOLESALE cache flushes; read with
 * `xschem get annot_overlay_flushes`. The companion seam to annot_overlay_count:
 * that one proves blocks were rendered, this one proves the cache still EXISTS
 * (a correct implementation flushes once per real change and zero times on an
 * unchanged repeat frame). Bumped in annot_overlay_sync() at the flush, never in
 * annot_data_changed() -- several hooks fire for one user action. */
extern unsigned int annot_overlay_flushes;
extern int check_pin_names(char **result);
/* pin name-label layout (offset/size/rot/flip) read from a pin's prop tokens by
 * get_pin_name_layout(); shared by draw_symbol / svg_draw_symbol / ps_draw_symbol. */
typedef struct { double dx, dy, size, rot, flip; } Pin_name_layout;
extern int get_pin_name_layout(const char *prop, Pin_name_layout *lay, char **name, char **font);
/* the yscale of pin 'pin' of symbol 'sym' (its name_size token, else 0.2 to match the
 * get_pin_name_layout render default); single source of truth for the wire-stub feature,
 * see actions.c get_pin_name_size. */
extern double get_pin_name_size(xSymbol *sym, int pin);
/* B1 (wire-stubs): median of n doubles (copy+sort+middle); reduces the processed pins' name
 * sizes to the one size that drives every stub+label. See actions.c median_double. */
extern double median_double(const double *a, int n);
/* B2 (wire-stubs): one (instance, pin) the stubber should process. */
typedef struct { int inst, pin; } Pin_stub_target;
/* B2: scan the selection into the (instance, pin) targets to stub -- selected pins win, else a
 * whole instance's not-already-wired pins. *out my_malloc'd, caller frees. See actions.c. */
extern int collect_pin_stub_targets(Pin_stub_target **out);
/* B3 (wire-stubs): the one size that drives an invocation + the derived label height and stub
 * length. size = median of the targets' pin-name sizes; text_h = label height at that size;
 * stub_len = smallest cadgrid multiple > 2*text_h. See actions.c compute_pin_stub_sizing. */
typedef struct { double size, text_h, stub_len; } Pin_stub_sizing;
extern int compute_pin_stub_sizing(const Pin_stub_target *t, int n, Pin_stub_sizing *out);
/* B4 (wire-stubs): the stub segment for one instance pin -- start = the pin's abs coord, end =
 * start + outward*stub_len, (dx,dy) = the absolute outward unit direction (one of +/-x, +/-y).
 * See actions.c compute_pin_stub_geom. */
typedef struct { double x1, y1, x2, y2, dx, dy; } Pin_stub_geom;
extern int compute_pin_stub_geom(int inst, int pin, double stub_len, Pin_stub_geom *out);
/* B5 (wire-stubs): draw a wire stub + a lab_pin net-label out of every selection stub target;
 * label net name = [instname_ if inst_prefix][prefix]<pinname>[suffix]. Returns stubs added. */
extern int add_pin_stubs(const char *prefix, const char *suffix, int inst_prefix);
extern int pin_names_all_off(void);
extern void init_inst_iterator(Iterator_ctx *ctx, double x1, double y1, double x2, double y2);
extern Instentry *inst_iterator_next(Iterator_ctx *ctx);

extern void init_wire_iterator(Iterator_ctx *ctx, double x1, double y1, double x2, double y2);
extern Wireentry *wire_iterator_next(Iterator_ctx *ctx);

extern void init_object_iterator(Iterator_ctx *ctx, double x1, double y1, double x2, double y2);
extern Objectentry *object_iterator_next(Iterator_ctx *ctx);

extern void check_unique_names(int rename);

extern unsigned int str_hash(const char *tok);
extern void str_hash_free(Str_hashtable *hashtable);
extern Str_hashentry *str_hash_lookup(Str_hashtable *hashtable,
       const char *token, const char *value, int what);
extern void str_hash_init(Str_hashtable *hashtable, int size);
extern void int_hash_init(Int_hashtable *hashtable, int size);
extern void int_hash_free(Int_hashtable *hashtable);
extern Int_hashentry *int_hash_lookup(Int_hashtable *hashtable,
       const char *token, const int value, int what);
extern void ptr_hash_init(Ptr_hashtable *hashtable, int size);
extern void ptr_hash_free(Ptr_hashtable *hashtable);
extern Ptr_hashentry *ptr_hash_lookup(Ptr_hashtable *hashtable,
       const char *token,  void * const value, int what);
extern char *trim_chars(const char *str, const char *sep);
extern char *find_nth(const char *str, const char *sep, const char *quote, int keep_quote, int n);
extern int isonlydigit(const char *s);
extern const char *spice_get_node(const char *token);
extern char *get_fqdevice(const char *param, int modelparam, const char *instname);
extern const char *translate(int inst, const char* s);
extern const char* translate2(Lcc *lcc, int level, char* s);
extern const char *translate3(const char* s, int eat_escapes, const char *s1,
                              const char *s2, const char *s3, const char *s4);
extern void print_tedax_element(FILE *fd, int inst);
extern int print_spice_element(FILE *fd, int inst);
extern void print_spice_subckt_nodes(FILE *fd, int symbol);
extern int print_spectre_element(FILE *fd, int inst);
extern void print_spectre_subckt_nodes(FILE *fd, int symbol);
extern void print_tedax_subckt(FILE *fd, int symbol);
extern void print_vhdl_element(FILE *fd, int inst);
extern void print_verilog_element(FILE *fd, int inst);
extern int get_inst_pin_number(int inst, const char *pin_name);
extern const char *get_tok_value(const char *s,const char *tok,int with_quotes);
/* NULL, empty, or all separator chars -- a value a producer MUST quote (issue 0183) */
extern int str_is_blank(const char *s);
extern const char *list_tokens(const char *s, int with_quotes);
extern char **parse_cmd_string(const char *cmd, int *argc);
extern double get_attr_val(const char *str);
extern double mylog10(double x);
extern double mylog(double x);
extern void *my_memmem(const void *haystack, size_t hlen, const void *needle, size_t nlen);
extern double atof_spice(const char *s);
extern double atof_eng(const char *s); /* same as atof_spice, but recognizes 'M' as Mega and 'm' as Milli */
extern char *dtoa_eng(double i, int precision);
extern char *dtoa_prec(double i);
extern double my_round(double a);
extern double snap_to_grid(double c);
extern double round_to_n_digits(double x, int n);
extern double floor_to_n_digits(double x, int n);
extern double ceil_to_n_digits(double x, int n);
extern int count_lines_bytes(int fd, size_t *lines, size_t *bytes);
extern const char *subst_token(const char *s, const char *tok, const char *new_val);
extern void new_prop_string(int i, const char *old_prop, int dis_uniq_names);
extern void hash_name(char *token, int remove);
extern void hash_names(int inst, int action); /* if i == -1 hash all instances, else do only inst */
extern void floater_hash_all_names(void);
extern void symbol_bbox(int i, double *x1,double *y1, double *x2, double *y2);
extern void set_inst_prop(int i);
extern void unselect_wire(int i);
extern void select_hilight_net(void);
extern void check_wire_storage(void);
extern void check_text_storage(void);
extern void check_inst_storage(void);
extern void check_symbol_storage(void);
extern void check_selected_storage(void);
extern void check_box_storage(int c);
extern void check_arc_storage(int c);
extern void check_line_storage(int c);
extern void check_polygon_storage(int c);
extern void eval_expr_init_table(void);
extern void eval_expr_clear_table(void);
extern char *eval_expr(const char *s);
extern const char *expandlabel(const char *s, int *m);
extern void parse(const char *s);
extern void clear_expandlabel_data(void);
extern void merge_file(int selection_load, const char ext[]);
/* cross-view pin mapping helpers (paste.c; shared with set_pin_type in scheduler.c) */
extern const char *pin_sym_dir(const char *name);
extern const char *dir_pin_sym(const char *dir);
extern const char *dir_literal(const char *d);
extern void select_wire(int i, unsigned short select_mode, int fast, int override_lock);
extern void select_element(int i, unsigned short select_mode, int fast, int override_lock);
extern void select_pin(int i, int j, unsigned short select_mode, int fast);
extern void select_text(int i, unsigned short select_mode, int fast, int override_lock);
extern void select_box(int c, int i, unsigned short select_mode, int fast, int override_lock);
extern void select_arc(int c, int i, unsigned short select_mode, int fast, int override_lock);
extern void select_line(int c, int i, unsigned short select_mode, int fast, int override_lock);
extern void select_polygon(int c, int i, unsigned short select_mode, int fast, int override_lock );
extern const char *net_name(int i, int j, int *mult, int hash_prefix_unnamed_net, int erc);
extern int record_global_node(int what, FILE *fp, const char *node);
extern int count_items(const char *s, const char *sep, const char *quote);
extern int get_unnamed_node(int what, int mult, int node);
extern void node_hash_free(void);
extern int traverse_node_hash();
extern Node_hashentry
                *bus_node_hash_lookup(const char *token, const char *dir,int what, int port, char *sig_type,
                char *verilog_type, char *value, char *class);
/* extern void insert_missing_pin(); */
extern void round_schematic_to_grid(double cadsnap);
extern void save_selection(int what);
extern void print_vhdl_signals(FILE *fd);
extern void print_verilog_signals(FILE *fd);
extern void list_nets(char **result);
extern void print_generic(FILE *fd, char *ent_or_comp, int symbol);
extern void print_verilog_param(FILE *fd, int symbol);
extern void hilight_net(int to_waveform);
extern void logic_set(int v, int num, const char *net_name);
extern int hilight_netname(const char *name, int fast);
extern void unhilight_net(int keep_sel);
extern void hilight_net_styled(void);
extern void propagate_hilights(int set, int clear, int mode);
extern void  select_connected_nets(int stop_at_junction);
extern int   select_grow_connected_step(double mx, double my, int pick_seed);
extern int   select_same_net_by_name(double mx, double my, int pick_seed, int add);
extern char *resolved_net(const char *net);
extern char *resolved_net_from(const char *net, int from_level);
extern void draw_hilight_net(int on_window);
extern void copy_hilights(void);
extern void display_hilights(int what, char **str);
extern void redraw_hilights(int clear);
extern void set_tcl_netlist_type(void);
extern void show_unconnected_pins(void);
extern void auto_set_wire_bus(int start, int end);
extern int prepare_netlist_structs(int for_netlist);
extern int is_auto_net_name(const char *s); /* "#net<N>", the engine's auto name (issue 0156) */
extern int attr_is_extra_node(const char *extra, const char *name); /* whole-token member of extra= (0163) */
extern int skip_wire(int i);
extern int skip_instance(int i,  int skip_short, int lvs_ignore);
extern int shorted_instance(int i, int lvs_ignore);
extern int compare_schematics(const char *filename);
extern void create_gc(void);
extern void free_gc(void);
extern void init_pixdata();
extern int warning_overlapped_symbols(int sel);
extern void free_simdata(void);
extern void delete_netlist_structs(void);
extern void delete_inst_node(int i);
extern void clear_all_hilights(void);
extern void hilight_child_pins(void);
extern void hilight_parent_pins(void);
extern void hilight_net_pin_mismatches(void);
extern Node_hashentry **get_node_table_ptr(void);
extern int drc_check(int i);
extern void change_elem_order(int n);
extern int is_generator(const char *name);
extern char *str_chars_replace(const char *str, const char *replace_set, const char with);
extern char *escape_chars(const char *source, const char *charset);
extern int set_different_token(char **s,const char *new, const char *old);
extern void print_hilight_net(int show);
extern void list_hilights(int all);
extern void change_layer();
extern void launcher();
extern void windowid(const char *win_path);
extern int preview_window(const char *what, const char *tk_win_path, const char *fname);
extern int new_schematic(const char *what, const char *win_path, const char *fname, int dr);
extern void toggle_fullscreen(const char *topwin);
extern int net_active_window(Window win); /* EWMH raise+focus, no re-map/drift (issue 0054) */
extern void toggle_only_probes();
extern int build_colors(double dim, double dim_bg); /*  reparse the TCL 'colors' list and reassign colors 20171113 */
extern void set_clip_mask(int what);
#ifdef __unix__
extern int pending_events(void);
#endif
extern void get_square(double x, double y, int *xx, int *yy);
extern const char *create_tmpdir(char *prefix);
extern FILE *open_tmpfile(char *prefix, char *suffix, char **filename);
extern void create_ps(char** psfile, int what, int fullzoom, int eps);
extern void MyXCopyArea(Display* display, Drawable src, Drawable dest, GC gc, int src_x, int src_y, unsigned int width, unsigned int height, int dest_x, int dest_y);
extern int win_regexec(const char *options, const char *pattern, const char *name);
#endif /*CADGLOBALS */
