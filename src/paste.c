/* File: paste.c
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

#include "xschem.h"

/* ---- cross-view paste (doc/claude/specs/crossview_copy_paste.md) --------------------
 * Armed by merge_file for the duration of ONE merge when the clipboard's
 * #XSCHEM_CLIPBOARD_VIEW= marker names the OTHER view type:
 *   mode 1: schematic clipboard -> symbol view (C pin instances become PINLAYER pin
 *           rects via create_pin; other instances and wires are skipped)
 *   mode 2: symbol clipboard -> schematic view (PINLAYER B rects carrying name=/dir=
 *           become devices/ipin|opin|iopin.sym instances)
 * A clipboard without the marker (old xschem) keeps legacy behavior (mode 0). */
static int xview_mode = 0;
static int xview_pre_pins = 0;   /* rect[PINLAYER] count before the merge (coercion scan) */
static int xview_pre_insts = 0;  /* instance count before the merge (coercion scan) */
static int xview_converted = 0, xview_skipped = 0, xview_coerced = 0;
static int xview_inst_hashed = 0; /* hash_names(-1) done once before first created inst */
static char xview_coerced_names[256];

/* "in"/"out"/"inout" if name is a schematic port symbol (basename match), else NULL.
 * Shared with set_pin_type (scheduler.c) -- see pin_type_editing.md. */
const char *pin_sym_dir(const char *name)
{
  const char *b, *s;
  if(!name) return NULL;
  b = name;
  for(s = name; *s; s++) if(*s == '/') b = s + 1;
  /* accept both the legacy 'ipin.sym' and the library-manager 'ipin' (lib/cell,
   * no .sym extension) reference forms -- see pin_type_editing.md */
  if(!strcmp(b, "ipin.sym")  || !strcmp(b, "ipin"))  return "in";
  if(!strcmp(b, "opin.sym")  || !strcmp(b, "opin"))  return "out";
  if(!strcmp(b, "iopin.sym") || !strcmp(b, "iopin")) return "inout";
  return NULL;
}

const char *dir_pin_sym(const char *dir)
{
  if(dir && !strcmp(dir, "in")) return "devices/ipin.sym";
  if(dir && !strcmp(dir, "out")) return "devices/opin.sym";
  return "devices/iopin.sym";
}

/* normalize a dir attribute to one of the three literals (lifetime-safe vs the
 * get_tok_value internal buffer) */
const char *dir_literal(const char *d)
{
  if(d && !strcmp(d, "in")) return "in";
  if(d && !strcmp(d, "out")) return "out";
  return "inout";
}

static void xview_note_coerced(const char *name)
{
  size_t l = strlen(xview_coerced_names), nl = strlen(name);
  ++xview_coerced;
  if(l + nl + 2 < sizeof(xview_coerced_names) && !strpbrk(name, "{}\\")) {
    if(l) xview_coerced_names[l++] = ' ';
    memcpy(xview_coerced_names + l, name, nl + 1);
  }
}

/* mode 2: store a port instance for a pasted symbol pin rect, mirroring merge_inst's
 * storage sequence (link_symbols_to_instances(old) later selects it like any merge) */
static void place_merged_pin_inst(double cx, double cy, const char *lab, const char *symname)
{
  int i;
  char *prop = NULL;
  i = xctx->instances;
  check_inst_storage();
  xctx->inst[i].name = NULL;
  my_strdup(_ALLOC_ID_, &xctx->inst[i].name, symname);
  xctx->inst[i].x0 = cx;
  xctx->inst[i].y0 = cy;
  xctx->inst[i].rot = 0;
  xctx->inst[i].flip = 0;
  xctx->inst[i].sel = 0;
  xctx->inst[i].color = -10000;
  xctx->inst[i].ptr = -1;
  xctx->inst[i].instname = NULL;
  xctx->inst[i].prop_ptr = NULL;
  xctx->inst[i].lab = NULL;
  xctx->inst[i].node = NULL;
  xctx->inst[i].pin_sel = NULL;
  xctx->inst[i].pin_sel_size = 0;
  my_mstrcat(_ALLOC_ID_, &prop, "name=p1 lab=", lab, NULL);
  my_strdup(_ALLOC_ID_, &xctx->inst[i].prop_ptr, prop);
  set_inst_flags(&xctx->inst[i]);
  if(!xview_inst_hashed) { hash_names(-1, XINSERT); xview_inst_hashed = 1; }
  new_prop_string(i, prop, tclgetboolvar("disable_unique_names"));
  hash_names(i, XINSERT);
  my_free(_ALLOC_ID_, &prop);
  inst_register(i);
}

static void merge_text(FILE *fd)
{
   int i;
    check_text_storage();
    i=xctx->texts;
     xctx->text[i].txt_ptr=NULL;
     load_ascii_string(&xctx->text[i].txt_ptr,fd);
     if(fscanf(fd, "%lf %lf %hd %hd %lf %lf ",
       &xctx->text[i].x0, &xctx->text[i].y0, &xctx->text[i].rot,
       &xctx->text[i].flip, &xctx->text[i].xscale,
       &xctx->text[i].yscale) <6) {
         fprintf(errfp,"merge_text(): WARNING:  missing fields for TEXT object, ignoring\n");
         read_line(fd, 0);
         return;
     }
     xctx->text[i].prop_ptr=NULL;
     xctx->text[i].font=NULL;
     xctx->text[i].floater_instname=NULL;
     xctx->text[i].floater_ptr=NULL;
     xctx->text[i].sel=0;
     xctx->text[i].owner_pin_id=0; /* pasted texts are real, never synthesized pin views */
     load_ascii_string(&xctx->text[i].prop_ptr,fd);
     set_text_flags(&xctx->text[i]);
     select_text(i,SELECTED, 1, 1);
     text_register(i);
}

static void merge_wire(FILE *fd)
{
    int i;
    double x1,y1,x2,y2;
    char *ptr=NULL;
    i=xctx->wires;
    if(fscanf(fd, "%lf %lf %lf %lf",&x1, &y1, &x2, &y2 ) < 4) {
      fprintf(errfp,"merge_wire(): WARNING:  missing fields for WIRE object, ignoring\n");
      read_line(fd, 0);
      return;
    }
    load_ascii_string( &ptr, fd);
    storeobject(-1, x1,y1,x2,y2,WIRE,0,SELECTED,ptr);
    my_free(_ALLOC_ID_, &ptr);
    select_wire(i, SELECTED, 1, 1);
}

static void merge_box(FILE *fd)
{
    int i,c,n;
    xRect *ptr;
    const char *attr, *fill_ptr;

    n = fscanf(fd, "%d",&c);
    if(n != 1 || c < 0 || c >= cadlayers) {
      fprintf(errfp,"merge_arc(): WARNING: wrong or missing layer number for xRECT object, ignoring.\n");
      read_line(fd, 0);
      return;
    }
    check_box_storage(c);
    i=xctx->rects[c];
    ptr=xctx->rect[c];
    if(fscanf(fd, "%lf %lf %lf %lf ",&ptr[i].x1, &ptr[i].y1,
       &ptr[i].x2, &ptr[i].y2) < 4) {
      fprintf(errfp,"merge_arc(): WARNING:  missing fields for xRECT object, ignoring\n");
      read_line(fd, 0);
      return;
    }
    ptr[i].prop_ptr=NULL;
    ptr[i].extraptr=NULL;
    RECTORDER(ptr[i].x1, ptr[i].y1, ptr[i].x2, ptr[i].y2);
    ptr[i].sel=0;
    load_ascii_string( &ptr[i].prop_ptr, fd);
    /* cross-view divert (mode 2): a symbol pin rect (PINLAYER + name= + dir=) pasted
     * into a schematic becomes a devices/ipin|opin|iopin.sym port instance at the rect
     * center. Any other rect (or a PINLAYER rect without pin attrs) stays graphics. */
    if(xview_mode == 2 && c == PINLAYER) {
      char *nm = NULL;
      my_strdup(_ALLOC_ID_, &nm, get_tok_value(ptr[i].prop_ptr, "name", 0));
      if(nm && nm[0]) {
        const char *dr = get_tok_value(ptr[i].prop_ptr, "dir", 0);
        if(dr[0]) {
          const char *symname = dir_pin_sym(dir_literal(dr));
          const char *edir;
          int j;
          /* dup-name coercion: an existing port instance labeled nm forces the type */
          for(j = 0; j < xview_pre_insts; ++j) {
            edir = pin_sym_dir(xctx->inst[j].name);
            if(edir && !strcmp(get_tok_value(xctx->inst[j].prop_ptr, "lab", 0), nm)) {
              symname = dir_pin_sym(edir);
              xview_note_coerced(nm);
              break;
            }
          }
          place_merged_pin_inst((ptr[i].x1 + ptr[i].x2) / 2.0,
                                (ptr[i].y1 + ptr[i].y2) / 2.0, nm, symname);
          ++xview_converted;
          my_free(_ALLOC_ID_, &nm);
          my_free(_ALLOC_ID_, &ptr[i].prop_ptr);
          return;
        }
      }
      my_free(_ALLOC_ID_, &nm);
    }
    ptr[i].bus = get_attr_val(get_tok_value(ptr[i].prop_ptr, "bus", 0));
    attr = get_tok_value(ptr[i].prop_ptr,"dash",0);
    if(strcmp(attr, "")) {
      int d = atoi(attr);
      ptr[i].dash = (short)(d >= 0 ? d : 0);
    } else {
      ptr[i].dash = 0;
    }

    attr = get_tok_value(ptr[i].prop_ptr,"ellipse",0);
    if(strcmp(attr, "")) {
      int a;
      int b;
      if(sscanf(attr, "%d%*[ ,]%d", &a, &b) != 2) {
        a = 0;
        b = 360;
      }
      ptr[i].ellipse_a = a;
      ptr[i].ellipse_b = b;
    } else {
      ptr[i].ellipse_a = -1;
      ptr[i].ellipse_b = -1;
    }

    fill_ptr = get_tok_value(ptr[i].prop_ptr,"fill",0);
    if( !strcmp(fill_ptr, "full") )
      ptr[i].fill = 2;
    else if( !strboolcmp(fill_ptr, "false") )
      ptr[i].fill = 0;
    else
      ptr[i].fill = 1;
    set_rect_flags(&xctx->rect[c][i]); /* set cached .flags bitmask from on attributes */
    /* merge_box carries prop_ptr through verbatim, so pasting a graph would give
     * the copy the SAME marker numbers as the original. Renumber, once, from the
     * window-wide maximum (doc/claude/specs/graph_markers.md). Note this runs
     * BEFORE the gfx_register below bumps xctx->rects[c], so the rect being
     * merged is still invisible to the numbering scan -- which is exactly why
     * graph_marker_renumber_rect() computes its base ONCE for the whole rect. */
    if(xctx->rect[c][i].flags & 1) graph_marker_renumber_rect(&xctx->rect[c][i]);
    select_box(c,i, SELECTED, 1, 1);
    gfx_register(xRECT, c, i);
}

static void merge_arc(FILE *fd)
{
    int i,c,n;
    xArc *ptr;
    const char *dash, *fill_ptr;

    n = fscanf(fd, "%d",&c);
    if(n != 1 || c < 0 || c >= cadlayers) {
      fprintf(errfp,"merge_arc(): WARNING: wrong or missing layer number for ARC object, ignoring.\n");
      read_line(fd, 0);
      return;
    }
    check_arc_storage(c);
    i=xctx->arcs[c];
    ptr=xctx->arc[c];
    if(fscanf(fd, "%lf %lf %lf %lf %lf ",&ptr[i].x, &ptr[i].y,
           &ptr[i].r, &ptr[i].a, &ptr[i].b) < 5) {
      fprintf(errfp,"merge_arc(): WARNING:  missing fields for ARC object, ignoring\n");
      read_line(fd, 0);
      return;
    }

    ptr[i].prop_ptr=NULL;
    ptr[i].sel=0;
    load_ascii_string(&ptr[i].prop_ptr, fd);
    ptr[i].bus = get_attr_val(get_tok_value(ptr[i].prop_ptr,"bus",0));
    fill_ptr = get_tok_value(ptr[i].prop_ptr,"fill",0);
    if( !strcmp(fill_ptr, "full") )
      ptr[i].fill = 2; /* bit 1: solid fill (not stippled) */
    else if( !strboolcmp(fill_ptr, "true") )
      ptr[i].fill = 1;
    else
      ptr[i].fill = 0;
    dash = get_tok_value(ptr[i].prop_ptr,"dash",0);
    if(strcmp(dash, "")) {
      int d = atoi(dash);
      ptr[i].dash = (short)(d >= 0 ? d : 0);
    } else {
      ptr[i].dash = 0;
    }
    select_arc(c,i, SELECTED, 1, 1);
    gfx_register(ARC, c, i);
}


static void merge_polygon(FILE *fd)
{
    const char *fill_ptr;
    int i,c, j, points;
    xPoly *ptr;
    const char *dash;

    if(fscanf(fd, "%d %d",&c, &points)<2) {
      fprintf(errfp,"merge_polygon(): WARNING: missing fields for POLYGON object, ignoring.\n");
      read_line(fd, 0);
      return;
    }
    if(c < 0 || c>=cadlayers) {
      fprintf(errfp,"merge_polygon(): Rectangle layer > defined cadlayers, increase cadlayers\n");
      read_line(fd, 0);
      return;
    }
    check_polygon_storage(c);
    i=xctx->polygons[c];
    ptr=xctx->poly[c];
    ptr[i].x=NULL;
    ptr[i].y=NULL;
    ptr[i].selected_point=NULL;
    ptr[i].prop_ptr=NULL;
    ptr[i].x = my_calloc(_ALLOC_ID_, points, sizeof(double));
    ptr[i].y = my_calloc(_ALLOC_ID_, points, sizeof(double));
    ptr[i].selected_point= my_calloc(_ALLOC_ID_, points, sizeof(unsigned short));
    ptr[i].points=points;
    ptr[i].sel=0;
    for(j=0;j<points; ++j) {
      if(fscanf(fd, "%lf %lf ",&(ptr[i].x[j]), &(ptr[i].y[j]))<2) {
        fprintf(errfp,"merge_polygon(): WARNING: missing fields for POLYGON points, ignoring.\n");
        my_free(_ALLOC_ID_, &ptr[i].x);
        my_free(_ALLOC_ID_, &ptr[i].y);
        my_free(_ALLOC_ID_, &ptr[i].selected_point);
        read_line(fd, 0);
        return;
      }
    }
    load_ascii_string( &ptr[i].prop_ptr, fd);
    ptr[i].bus = get_attr_val(get_tok_value(ptr[i].prop_ptr, "bus", 0));
    fill_ptr = get_tok_value(ptr[i].prop_ptr,"fill",0);
    if( !strcmp(fill_ptr, "full") )
      ptr[i].fill = 2; /* bit 1: solid fill (not stippled) */
    else if( !strboolcmp(fill_ptr, "true") )
      ptr[i].fill = 1;
    else
      ptr[i].fill = 0;
    dash = get_tok_value(ptr[i].prop_ptr,"dash",0);
    if(strcmp(dash, "")) {
      int d = atoi(dash);
      ptr[i].dash = (short)(d >= 0 ? d : 0);
    } else {
      ptr[i].dash = 0;
    }
    select_polygon(c,i, SELECTED, 1, 1);
    gfx_register(POLYGON, c, i);
}

static void merge_line(FILE *fd)
{
    int i,c,n;
    xLine *ptr;
    const char *dash;

    n = fscanf(fd, "%d",&c);
    if(n != 1 || c < 0 || c >= cadlayers) {
      fprintf(errfp,"merge_line(): WARNING: Wrong or missing layer number for LINE object, ignoring\n");
      read_line(fd, 0);
      return;
    }
    check_line_storage(c);
    i=xctx->lines[c];
    ptr=xctx->line[c];
    if(fscanf(fd, "%lf %lf %lf %lf ",&ptr[i].x1, &ptr[i].y1, &ptr[i].x2, &ptr[i].y2) < 4) {
      fprintf(errfp,"merge_line(): WARNING:  missing fields for LINE object, ignoring\n");
      read_line(fd, 0);
      return;
    }
    ORDER(ptr[i].x1, ptr[i].y1, ptr[i].x2, ptr[i].y2);
    ptr[i].prop_ptr=NULL;
    ptr[i].sel=0;
    load_ascii_string( &ptr[i].prop_ptr, fd);
    ptr[i].bus = get_attr_val(get_tok_value(ptr[i].prop_ptr, "bus", 0));
    dash = get_tok_value(ptr[i].prop_ptr,"dash",0);
    if(strcmp(dash, "")) {
      int d = atoi(dash);
      ptr[i].dash = (short)(d >= 0 ? d : 0);
    } else {
      ptr[i].dash = 0;
    }
    select_line(c,i, SELECTED, 1, 1);
    gfx_register(LINE, c, i);
}

static void merge_inst(int k,FILE *fd)
{
    int i;
    char *prop_ptr=NULL;
    char *tmp = NULL;
    i=xctx->instances;
    check_inst_storage();
    xctx->inst[i].name=NULL;
    load_ascii_string(&tmp, fd);
    /* avoid as much as possible calls to rel_sym_path (slow) */
    #ifdef __unix__
    if(tmp[0] == '/') my_strdup(_ALLOC_ID_, &xctx->inst[i].name, rel_sym_path(tmp));
    else my_strdup(_ALLOC_ID_, &xctx->inst[i].name,tmp);
    #else
    my_strdup(_ALLOC_ID_, &xctx->inst[i].name, rel_sym_path(tmp));
    #endif
    my_free(_ALLOC_ID_, &tmp);
    if(fscanf(fd, "%lf %lf %hd %hd",&xctx->inst[i].x0, &xctx->inst[i].y0,&xctx->inst[i].rot, &xctx->inst[i].flip) < 4) {
      fprintf(errfp,"WARNING: missing fields for INSTANCE object, ignoring.\n");
      read_line(fd, 0);
      return;
    }
    xctx->inst[i].sel=0;
    xctx->inst[i].color=-10000;
    xctx->inst[i].ptr=-1;
    xctx->inst[i].instname=NULL;
    xctx->inst[i].prop_ptr=NULL;
    xctx->inst[i].lab=NULL;  /* assigned in link_symbols_to_instances */
    xctx->inst[i].node=NULL;
    xctx->inst[i].pin_sel=NULL;     /* transient pin selection, not pasted (pin_selection.md) */
    xctx->inst[i].pin_sel_size=0;
    load_ascii_string(&prop_ptr,fd);
    /* cross-view divert (mode 1): a schematic port instance pasted into a symbol view
     * becomes a PINLAYER pin rect (owned name view included). Non-port instances are
     * skipped: they have no symbol-view meaning. The slot writes above are abandoned
     * (i was never registered), only the strdup'd name must be freed. */
    if(xview_mode == 1) {
      const char *dir = pin_sym_dir(xctx->inst[i].name);
      if(dir) {
        char *lab = NULL;
        int j;
        my_strdup(_ALLOC_ID_, &lab, get_tok_value(prop_ptr, "lab", 0));
        if(lab && lab[0]) {
          /* dup-name coercion: an existing pin named lab forces the incoming dir */
          for(j = 0; j < xview_pre_pins; ++j) {
            if(!strcmp(get_tok_value(xctx->rect[PINLAYER][j].prop_ptr, "name", 0), lab)) {
              dir = dir_literal(get_tok_value(xctx->rect[PINLAYER][j].prop_ptr, "dir", 0));
              xview_note_coerced(lab);
              break;
            }
          }
          create_pin(xctx->inst[i].x0, xctx->inst[i].y0, lab, dir, SELECTED);
          ++xview_converted;
        } else ++xview_skipped; /* port symbol without a lab: nothing to name a pin */
        my_free(_ALLOC_ID_, &lab);
      } else ++xview_skipped;
      my_free(_ALLOC_ID_, &xctx->inst[i].name);
      my_free(_ALLOC_ID_, &prop_ptr);
      return;
    }
    my_strdup(_ALLOC_ID_, &xctx->inst[i].prop_ptr, prop_ptr);
    set_inst_flags(&xctx->inst[i]);
    if(!k) hash_names(-1, XINSERT);
    new_prop_string(i, prop_ptr, tclgetboolvar("disable_unique_names")); /* will also assign .instname */
    /* the final tmp argument is zero for the 1st call and used in */
    /* new_prop_string() for cleaning some internal caches. */
    hash_names(i, XINSERT);
    my_free(_ALLOC_ID_, &prop_ptr);
    inst_register(i);
}

/* merge selection if selection_load=1, otherwise ask for filename
 * selection_load:
 *                      0: ask filename to merge
 *                         if ext=="" else use ext as name
 *                      1: merge selection
 *                      2: merge clipboard
 *                      if bit 3 is set do not start a  move_objects(RUBBER,0,0,0)
 *                      to avoid graphical artifacts if doing a xschem paste with x and y offsets
 *                      from script
 */
void merge_file(int selection_load, const char ext[])
{
    FILE *fd;
    int k=0, old;
    int endfile=0;
    char *name;
    char filename[PATH_MAX];
    char tag[1]; /* overflow safe */
    char tmp[256]; /* 20161122 overflow safe */
    char *aux_ptr=NULL;
    int got_mouse, generator = 0;
    int rubber = 1;

    rubber = !(selection_load & 8);
    selection_load &= 7;
    xctx->paste_from = 0;
    if(selection_load==0)
    {
     if(!strcmp(ext,"")) {
       my_snprintf(tmp, S(tmp), "load_file_dialog {Merge file} {*} INITIALLOADDIR");
       tcleval(tmp);
       if(!strcmp(tclresult(),"")) return;
       my_strncpy(filename, (char *)tclresult(), S(filename));
       name = filename;
       xctx->paste_from = 3;
     }
     else {
       my_strncpy(filename, ext, S(filename));
       name = filename;
     }
     dbg(1, "merge_file(): sch=%d name=%s\n",xctx->currsch,name);
    }
    else if(selection_load==1)
    {
      name = sel_file;
      xctx->paste_from = 1;
    }
    else    /* selection_load==2, clipboard load */
    {
      name = clip_file;
      xctx->paste_from = 2;
    }

    if(is_generator(name)) generator = 1;

    if(generator) {
      char *cmd;
      cmd = get_generator_command(name);
      if(cmd) {
        fd = popen(cmd, "r");
        my_free(_ALLOC_ID_, &cmd);
      } else fd = NULL;
    } else {
      fd=my_fopen(name, fopen_read_mode);
    }
    if(fd) {
     /* action-log (issue 0069): remember what the pending merge reads, so the drop
      * logger (end_move_copy_logged) can record a self-contained replay line for
      * non-clipboard sources (`xschem paste dx dy ... -file {f}`). Stored per-window
      * (xctx) because each window can hold its own pending STARTMERGE. */
     my_strncpy(xctx->merge_source, name, S(xctx->merge_source));
     xctx->prep_hi_structs=0;
     xctx->prep_net_structs=0;
     xctx->prep_hash_inst=0;
     xctx->prep_hash_wires=0;
     got_mouse = 0;
     /* ISSUE 0242 -- see leave_placement_for() (callback.c). A pending merge and a modal cursor
      * PLACEMENT preview cannot coexist: the unselect_all(1) on the next line zeroes ui_state
      * wholesale (select.c), dropping START_SYMPIN|STARTMOVE WITHOUT running the placement
      * teardown, while sympin_preview/wirelabel_preview (not part of ui_state) and the preview
      * INSTANCE both survive -- a connected, netlist-visible lab_pin/ipin silently renaming a net,
      * committed by a user who never dropped it, and sympin_preview stuck at 1 thereafter kills
      * the Button-1 click-select guard (callback.c) and wire_label_try_commit() for the rest of
      * the session. Same ratified rule as 0243 F2 / 0240: whatever you just pressed is what you
      * meant, so Ctrl+V / Merge abandons the pending preview.
      * Sited HERE, not at the verbs: this is the ONE funnel every merge door shares -- the `paste`
      * and `merge` scheduler verbs, the Ctrl+V binding, and the `xschem paste x y ... -file {f}`
      * action-log REPLAY form. Replay is covered rather than broken: the gate needs a live
      * placement, and a replay run has none, so it is a no-op there (the coordinate-form-bypass
      * note at scheduler.c's paste branch still holds -- no log line is emitted from here).
      * Sited INSIDE `if(fd)` and BEFORE push_undo() for two reasons: a cancelled Merge file
      * dialog (above) must not destroy the preview, and the teardown's delete() must land before
      * the merge's undo baseline is taken, or undoing the paste would resurrect the preview. */
     leave_placement_for(selection_load == 2 ? "Paste" : "Merge");
     /* ISSUE 0244 -- latch the modify flag the merge is STARTING FROM.
      * abort_operation()'s two STARTMERGE arms (callback.c) used to call set_modify(0) flat, on
      * the reasoning "an aborted merge changed nothing, so undo the flag delete() just set". That
      * is true only for a document that was already clean: on a document with real unsaved edits
      * ESC-ing a Ctrl+V reported it UNMODIFIED, which kills the Close/Quit prompts, save()'s
      * `if(force || xctx->modified)` gate and go_back()'s ascend prompt -- and File > New then
      * runs clear_schematic()'s silent save(1,0) followed by remove_backup(), deleting the `~`
      * file that held the only copy of the work.
      * Latched, NOT read at the abort: the unconditional set_modify(1) at the bottom of this
      * function runs on every exit, so by abort time xctx->modified is always 1 and the
      * save/restore idiom the PLACEMENT arm uses (abort_placement_preview()) would read the
      * already-clobbered value -- leaving a clean document dirty after every Ctrl+V/ESC.
      * Sited here, after leave_placement_for() and before the first mutation: push_undo() below is
      * the merge's first write, and taking the latch after the placement teardown is the honest
      * reading of "the flag this merge starts from" (that teardown is modified-neutral today --
      * abort_placement_preview() does set_modify(save) -- so the order is not load-bearing yet,
      * but it stays correct if it ever stops being neutral). */
     xctx->pre_merge_modified = xctx->modified;
     xctx->push_undo();
     unselect_all(1);
     old=xctx->instances;
     /* cross-view paste: fresh state per merge; mode arms only if the clipboard's
      * view marker (read in the '#' case below, always before object records)
      * names the other view type */
     xview_mode = 0;
     xview_converted = xview_skipped = xview_coerced = 0;
     xview_coerced_names[0] = '\0';
     xview_inst_hashed = 0;
     xview_pre_pins = xctx->rects[PINLAYER];
     xview_pre_insts = xctx->instances;
     while(!endfile)
     {
      if(fscanf(fd," %c",tag)==EOF) break;
      switch(tag[0])
      {
       case 'v':
        load_ascii_string(&aux_ptr, fd);
        break;
       case '#':
        {
          /* capture the cross-view source marker; every other comment is discarded
           * as before (read_line consumes to end of line either way) */
          char *cl = read_line(fd, 1);
          if(cl && !strncmp(cl, "XSCHEM_CLIPBOARD_VIEW=", 22)) {
            int src_sym = !strcmp(cl + 22, "symbol");
            int dst_sym = editing_symbol_view();
            if(src_sym && !dst_sym) xview_mode = 2;
            else if(!src_sym && dst_sym) xview_mode = 1;
            else xview_mode = 0;
          }
        }
        break;
       case 'F': /* extension for future symbol floater labels */
        read_line(fd, 1);
        break;
       case 'V':
        load_ascii_string(&aux_ptr, fd);
        break;
       case 'E':
        load_ascii_string(&aux_ptr, fd);
        break;
       case 'S':
        load_ascii_string(&aux_ptr, fd);
        break;
       case 'K':
        load_ascii_string(&aux_ptr, fd);
        break;
       case 'G':
        load_ascii_string(&aux_ptr, fd);
        if(selection_load)
        {
          xctx->mx_double_save = xctx->mousex_snap;
          xctx->my_double_save = xctx->mousey_snap;
          sscanf( aux_ptr, "%lf %lf", &xctx->mousex_snap, &xctx->mousey_snap);
          got_mouse = 1;
        }
        break;
       case 'L':
        merge_line(fd);
        break;
       case 'B':
        merge_box(fd);
        break;
       case 'A':
        merge_arc(fd);
        break;
       case 'P':
        merge_polygon(fd);
        break;
       case 'T':
        merge_text(fd);
        break;
       case 'N':
        if(xview_mode == 1) {
          /* wires have no symbol-view meaning: parse + skip (cross-view only) */
          double dx1, dy1, dx2, dy2;
          char *dptr = NULL;
          if(fscanf(fd, "%lf %lf %lf %lf", &dx1, &dy1, &dx2, &dy2) < 4) {
            fprintf(errfp,"merge_file(): WARNING: missing fields for skipped WIRE\n");
          } else {
            load_ascii_string(&dptr, fd);
            my_free(_ALLOC_ID_, &dptr);
          }
          ++xview_skipped;
        } else merge_wire(fd);
        break;
       case 'C':
        merge_inst(k++,fd);
        break;
       default:
        if( tag[0] == '{' ) ungetc(tag[0], fd);
        read_record(tag[0], fd, 0);
        break;
      }
      read_line(fd, 0); /* discard any remaining characters till (but not including) newline */
     }
     if(!got_mouse) {
       xctx->mx_double_save = xctx->mousex_snap;
       xctx->my_double_save = xctx->mousey_snap;
       xctx->mousex_snap = 0.;
       xctx->mousey_snap = 0.;
     }
     my_free(_ALLOC_ID_, &aux_ptr);
     link_symbols_to_instances(old); /* in case of paste/merge will set instances .sel to SELECTED */
     if(generator) pclose(fd);
     else fclose(fd);

     /* P4 (cadence_pin_name_text.md): pasted pins arrive WITHOUT their name views (save
      * skips synthesized views), so regenerate a view per pasted shown pin and add it to
      * the merge selection so it drags with its pin. Each pasted pin got a fresh xRect.id
      * (gfx_register), so synth binds a new view to it. Symbol-edit only (synth is gated). */
     synth_pin_views();
     {
       int r, vt;
       for(r = 0; r < xctx->rects[PINLAYER]; ++r) {
         if(xctx->rect[PINLAYER][r].sel == SELECTED &&
            (vt = pin_name_view_of(xctx->rect[PINLAYER][r].id)) >= 0) {
           select_text(vt, SELECTED, 1, 1);
         }
       }
       xctx->need_reb_sel_arr = 1;
       rebuild_selected_array();
     }

     /* cross-view paste report ([[ciw-feedback-channels]]: ciw_echo, guarded) */
     if(xview_mode && (xview_converted || xview_skipped || xview_coerced)) {
       char cnt[120];
       my_snprintf(cnt, S(cnt), "# cross-view paste: %d pin(s) converted, %d object(s) skipped, %d dir-coerced",
                   xview_converted, xview_skipped, xview_coerced);
       if(has_x) tclvareval("if {[info procs ciw_echo] ne {}} {ciw_echo {", cnt,
                            xview_coerced_names[0] ? " (" : "", xview_coerced_names,
                            xview_coerced_names[0] ? ")" : "", "}}", NULL);
       dbg(1, "merge_file(): %s (%s)\n", cnt, xview_coerced_names);
     }
     xview_mode = 0;
     /* ISSUE 0244 part B / ISSUE 0241 -- name what the cancel is allowed to delete.
      * abort_operation()'s two STARTMERGE arms (callback.c) tear the pending paste down with a
      * SELECTION-scoped delete(1), trusting the "selection == the merged objects" invariant this
      * function establishes right here. Nothing defends it afterwards: between the paste and the
      * ESC the user can reach Ctrl+A, Edit>Select all or select_dangling_nets, none of which
      * inspects ui_state, and the cancel then took the WHOLE DOCUMENT (measured at 7da044ff:
      * 2 wires + 1 instance + 1 text + 1 line -> nothing, and issue 0244's flat set_modify(0)
      * reported the emptied schematic clean, so it closed without a prompt).
      * Same fix as the placement sibling: stamp the identity of the merged objects HERE, at the
      * arm, and re-select exactly that stamp before the delete. THE STAMP IS THE SELECTION,
      * which on this path is exactly the merged set -- push_undo() + unselect_all(1) above ran
      * BEFORE the load, so nothing of the user's survives in it -- plus the pin name views
      * synth_pin_views() just added, which must drag and die with their pins.
      * Sited before `ui_state |= STARTMERGE` for the same reason as the placement arms: the stamp
      * and the bit that authorises reading it are one fact and are written together.
      * SHARED SLOT: the stamp goes in xctx->preview_sel, the same field the placement preview
      * uses -- deliberately, and NOT because the two can never be co-armed. 0242 closed only the
      * placement-then-merge direction (leave_placement_for() above); NOTHING tears down a pending
      * STARTMERGE, so merge-then-placement is reachable. It is still safe, on two properties that
      * the readers' comments (abort_operation(), callback.c) restate because nobody enforces them:
      *   - every arm of either kind stamps immediately before setting its bit, and merge_file() is
      *     the ONLY writer of STARTMERGE, so no reader can ever see a stale stamp;
      *   - of the twelve placement arms, eight run unselect_all(1), which zeroes ui_state wholesale
      *     and so destroys STARTMERGE before writing their stamp (no merge arm left to read it);
      *     the four that do not (ctx-menu text, `t`, the screen grab, place_net_label's
      *     failed-place_symbol path) leave the merged objects SELECTED, so their stamp is a
      *     SUPERSET of this one and their teardown removes the merge with the placement -- after
      *     which this arm's select_placement_preview() correctly resolves 0 and deletes nothing.
      * A separate merge_sel field would behave identically in every reachable sequence. */
     stamp_placement_preview();
     xctx->ui_state |= STARTMERGE;
     dbg(1, "End merge_file(): loaded file %s: wire=%d inst=%d ui_state=%ld\n",
             name, xctx->wires , xctx->instances, xctx->ui_state);
     move_objects(START,0,0,0);
     if(xctx->lastsel) {
       xctx->mousex_snap = xctx->mx_double_save;
       xctx->mousey_snap = xctx->my_double_save;
       if(rubber) move_objects(RUBBER,0,0,0);
     }
     else {
       /* nothing merged (empty file / empty clipboard): move_objects(START) early-returned,
        * so no gesture is pending and neither of the STARTMERGE-clearing sites (move END
        * tail, ESC abort) will ever run. Don't leave the flag dangling: a later real
        * move/copy drop would be mislogged as a paste (issue 0069 atom-9 review), and a
        * later ESC would delete(1) whatever selection exists. */
       xctx->ui_state &= ~STARTMERGE;
       clear_placement_preview(); /* issue 0244 part B: nothing merged, so nothing to name */
     }
    } else {
      dbg(0, "merge_file(): can not open %s\n", name);
      xctx->paste_from = 0;
    }
    set_modify(1);
}
