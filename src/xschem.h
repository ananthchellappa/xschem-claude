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

#define S(a) (sizeof(a)/sizeof(a[0]))
#define BUS_WIDTH 4
#define POINTINSIDE(xa,ya,x1,y1,x2,y2)  \
 (xa>=x1 && xa<=x2 && ya>=y1 && ya<=y2 )

#define RECT_INSIDE(xa,ya,xb,yb,x1,y1,x2,y2)  \
 (xa>=x1 && xa<=x2 && xb>=x1 && xb<=x2 && ya>=y1 && ya<=y2 && yb>=y1 && yb<=y2 )

#define RECT_OUTSIDE(xa,ya,xb,yb,x1,y1,x2,y2)  \
( (xa) > (x2) || (xb) < (x1) || (ya) > (y2) || (yb) < (y1) )

#define RECT_TOUCH(xa,ya,xb,yb,x1,y1,x2,y2)  (!(xa > x2 || xb < x1 || ya > y2 || yb < y1))

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
              * bit 2 : TEXT_ITALICi
              * bit 3 : HIDE_TEXT
              * bit 4 : TEXT_FLOATER */
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
  int hilight_wave; /* wave index */
  int logx, logy;
  int rainbow; /* draw multiple datasets with incrementing colors */
  double linewidth_mult; /* multiply factor for waveforms line width */
  double hcursor1_y, hcursor2_y; /* hcursor positions */
} Graph_ctx;

typedef struct {
  int savew, saveh;
  double savexor, saveyor, savezoom, savelw;
} Zoom_info;

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
  int paste_from; /* set to 1 if paste from clipboard is called ,
                   *        2 if paste from selection
                   *        3 if paste from user provided file */
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
  int hover_type;       /* hover highlight: currently-outlined object type (0 = none) */
  int hover_n;          /* hover highlight: its array index */
  int hover_col;        /* hover highlight: its layer (graphical types) */
  GC gc_hilight;        /* net highlight scratch GC: reconfigured per wire from the
                         * NetHilightStyle (color+width+dash) at draw time */
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
  short move_flip;
  int manhattan_lines;
  int movelastsel;
  short rotatelocal;
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
extern double get_raw_value(int dataset, int idx, int point);
extern int plot_raw_custom_data(int sweep_idx, int first, int last, const char *ntok, const char *yname);
extern int calc_custom_data_yrange(int sweep_idx, const char *express, Graph_ctx *gr);
extern int sch_waves_loaded(void);
extern int edit_wave_attributes(int what, int i, Graph_ctx *gr);
extern void draw_graph(int i, int flags, Graph_ctx *gr, void *ct);
extern int find_closest_wave(int i, Graph_ctx *gr, int *node_number);
extern void setup_graph_data(int i, int skip, Graph_ctx *gr);
extern int graph_fullyzoom(xRect *r,  Graph_ctx *gr, int graph_dataset);
extern int graph_fullxzoom(int i, Graph_ctx *gr, int dataset);
extern void sleep_ms(int milliseconds);
extern double timer(int start);
extern void enable_layers(void);
extern void set_snap(double);
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
extern void symbol_in_new_window(int new_process);
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
extern void select_attached_nets(void);
extern void select_inside(int stretch, double x1,double y1, double x2, double y2, int sel);
extern void select_touch(double x1,double y1, double x2, double y2, int sel);
/*  Select all nets that are dangling, ie not attached to any non pin/port/probe components */
extern int select_dangling_nets(void);
extern void tclmainloop(void);
extern int Tcl_AppInit(Tcl_Interp *interp);
extern void abort_operation(void);
extern void enter_deselect_mode(void);
extern void draw_crosshair(int what, int state);
extern void start_line(double mx, double my);
extern void start_wire(double mx, double my);
extern void backannotate_at_cursor_b_pos(xRect *r, Graph_ctx *gr);
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
/* find the instance pin within a tight radius of (mx,my); returns 1 and fills *r
 * (type=INST_PIN, n=instance, col=pin) on hit, 0 otherwise. See pin_selection.md */
extern int find_closest_pin(double mx, double my, Selected *r);
/*extern void find_closest_net_or_symbol_pin(double mx,double my, double *x, double *y);*/
extern int find_closest_net_or_symbol_pin(double mx,double my, double *x, double *y);

extern void drawline(int c, int what, double x1,double y1,double x2,double y2, double bus, int dash, void *ct);
extern void draw_xhair_line(GC gc, int size, double linex1, double liney1, double linex2, double liney2);
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
extern void mem_delete_undo(void);
extern void mem_clear_undo(void);
extern int load_schematic(int load_symbol, const char *fname, int reset_undo, int alert);
/* check if filename already in an open window/tab */
extern int get_tab_or_window_number(const char *win_path);
extern void swap_tabs(void);
extern void swap_windows(int dr);
extern int check_loaded(const char *f, char *win_path);
extern char *get_last_created_window_path(void);
extern int get_last_created_window(void);
extern char *get_window_path(int i);
extern int get_window_count(void);
extern void get_unused_untitled_name(int symbol, char *name, int namesize);
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
extern int xschem(ClientData clientdata, Tcl_Interp *interp,
           int argc, const char * argv[]);
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
extern char *resolved_net(const char *net);
extern void draw_hilight_net(int on_window);
extern void copy_hilights(void);
extern void display_hilights(int what, char **str);
extern void redraw_hilights(int clear);
extern void set_tcl_netlist_type(void);
extern void show_unconnected_pins(void);
extern void auto_set_wire_bus(int start, int end);
extern int prepare_netlist_structs(int for_netlist);
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
