/* File: draw.c
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

#define xDashType LineOnOffDash
/* CapNotLast, CapButt, CapRound or CapProjecting */
#define xCap CapNotLast
/* JoinMiter, JoinRound, or JoinBevel */
#define xJoin JoinBevel

#if !defined(__unix__) && HAS_CAIRO==1
static void clear_cairo_surface(cairo_t *cr, double x, double y, double width, double height)
{
  cairo_save(cr);
  cairo_set_source_rgba(cr, 0, 0, 0, 0);
  cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
  cairo_rectangle(cr, x, y, width, height);
  cairo_fill(cr);
  /*cairo_paint(cr);
  cairo_set_operator(cr, CAIRO_OPERATOR_OVER);*/
  cairo_restore(cr);
}

static void my_cairo_fill(cairo_surface_t *src_surface, int x, int y, unsigned int width, unsigned int height)
{
  HWND hwnd = Tk_GetHWND(xctx->window);
  HDC dc = GetDC(hwnd);
  cairo_surface_t *dest_surface = cairo_win32_surface_create(dc);
  if (cairo_surface_status(dest_surface) != CAIRO_STATUS_SUCCESS) {
    fprintf(errfp, "ERROR: invalid cairo surface to copy over\n");
  }
  cairo_t *ct = cairo_create(dest_surface);
  cairo_surface_flush(src_surface);
  cairo_set_source_surface(ct, src_surface, 0, 0);
  cairo_rectangle(ct, x, y, width, height);
  cairo_set_operator(ct, CAIRO_OPERATOR_ADD);
  cairo_fill(ct);
  cairo_destroy(ct); ct = NULL;
  cairo_surface_destroy(dest_surface); dest_surface = NULL;
}
#endif
#ifdef __unix__
int xserver_ok(void)
{
  int has_x = 1;
  if(!getenv("DISPLAY") || !getenv("DISPLAY")[0]) has_x = 0;
  else {
    display = XOpenDisplay(NULL);
    if(!display) {
      has_x=0;
      fprintf(errfp, "\n   X server connection failed, although DISPLAY shell variable is set.\n"
                     "   A possible reason is that the X server is not running or DISPLAY shell variable\n"
                     "   is incorrectly set.\n"
                     "   Starting Xschem in text only mode.\n\n");
    } else XCloseDisplay(display);
  }
  return has_x;
}
#endif

int textclip(int x1,int y1,int x2,int y2,
          double xa,double ya,double xb,double yb)
/* check if some of (xa,ya-xb,yb) is inside (x1,y1-x2,y2) */
/* coordinates should be ordered, x1<x2,ya<yb and so on... */
{
 /*
 dbg(2, "textclip(): %.16g %.16g %.16g %.16g - %d %d %d %d\n",
 X_TO_SCREEN(xa),Y_TO_SCREEN(ya), X_TO_SCREEN(xb),Y_TO_SCREEN(yb),x1,y1,x2,y2);
 */
 /* drawtemprect(xctx->gc[WIRELAYER],xa,ya,xb,yb); */
 if          (X_TO_SCREEN(xa)>x2) return 0;
 else if     (Y_TO_SCREEN(ya)>y2) return 0;
 else if     (X_TO_SCREEN(xb)<x1) return 0;
 else if     (Y_TO_SCREEN(yb)<y1) return 0;
 return 1;
}

/* issue 0151: suppress ON-SCREEN-only UI decorations (currently the ASE viewer's
 * active-strip marker) while rendering to an export drawable. print_image() renders
 * through draw(), not through the export-specific draw_graph() callers, so it cannot
 * be gated by withholding draw_graph's flags bit 16 at the call site the way
 * svg_embedded_graph()/ps_embedded_graph() are — draw() consults this flag instead.
 * Bracketed like save_draw_grid/do_copy_area below; single-threaded, so a file
 * static is enough. */
static int draw_no_ui_decorations = 0;

void print_image()
{
  #if HAS_CAIRO == 0
  char cmd[PATH_MAX+100];
  #endif
  int save, save_draw_grid, save_draw_window;
  static char lastdir[PATH_MAX] = "";
  const char *r;

  if(!has_x) return;
  if(!lastdir[0]) my_strncpy(lastdir, pwd_dir, S(lastdir));
  if(!xctx->plotfile[0]) {
    /* tclvareval("tk_getSaveFile -title {Select destination file} -initialfile {",
     *   get_cell(xctx->sch[xctx->currsch], 0), ".png} -initialdir {", lastdir, "}", NULL); */
    tclvareval("save_file_dialog {Select destination file} *.png INITIALLOADDIR {", pwd_dir, "/",
      get_cell(xctx->sch[xctx->currsch], 0), ".png}", NULL);
    r = tclresult();
    if(r[0]) {
      my_strncpy(xctx->plotfile, r, S(xctx->plotfile));
      tclvareval("file dirname {", xctx->plotfile, "}", NULL);
      my_strncpy(lastdir, tclresult(), S(lastdir));
    }
    else return;
  }
  save_draw_grid = tclgetboolvar("draw_grid");
  tclsetvar("draw_grid", "0");
  save_draw_window = xctx->draw_window;
  xctx->draw_window=0;
  xctx->draw_pixmap=1;
  save = xctx->do_copy_area;
  xctx->do_copy_area=0;
  draw_no_ui_decorations = 1; /* issue 0151: no active-strip marker in exported images */
  draw();
  draw_no_ui_decorations = 0;


  #if HAS_CAIRO == 1 /* use cairo native support for png writing, no need to convert
                      * XPM and handles Xrender extensions for transparent embedded images */
  {
    cairo_surface_t *png_sfc;
    #ifdef __unix__
    png_sfc = cairo_xlib_surface_create(display, xctx->save_pixmap, visual,
               xctx->xrect[0].width, xctx->xrect[0].height);
    #else
    HWND hwnd = Tk_GetHWND(xctx->window);
    HDC dc = GetDC(hwnd);
    png_sfc = cairo_win32_surface_create(dc);
    #endif

    if(xctx->plotfile[0])
      cairo_surface_write_to_png(png_sfc, xctx->plotfile);
    else
      cairo_surface_write_to_png(png_sfc, "plot.png");

    cairo_surface_destroy(png_sfc);
  }
  #else /* no cairo */
  #ifdef __unix__
  XpmWriteFileFromPixmap(display, "plot.xpm", xctx->save_pixmap, 0, NULL ); /* .gz ???? */
  dbg(1, "print_image(): Window image saved\n");
  if(xctx->plotfile[0]) {
    my_snprintf(cmd, S(cmd), "convert_to_png plot.xpm {%s}", xctx->plotfile);
    tcleval(cmd);
  } else tcleval( "convert_to_png plot.xpm plot.png");
  #else
  char *psfile = NULL;
  create_ps(&psfile, 7, 0, 0);
  if (xctx->plotfile[0]) {
    my_snprintf(cmd, S(cmd), "convert_to_png {%s} {%s}", psfile, xctx->plotfile);
    tcleval(cmd);
  }
  else tclvareval("convert_to_png {", psfile, "} plot.png", NULL);
  #endif
  #endif
  my_strncpy(xctx->plotfile,"", S(xctx->plotfile));
  tclsetboolvar("draw_grid", save_draw_grid);
  xctx->draw_pixmap=1;
  xctx->draw_window=save_draw_window;
  xctx->do_copy_area=save;
}

#if defined(__unix__) && HAS_CAIRO==1
int grabscreen(const char *win_path, int event, int mx, int my, KeySym key,
                 int button, int aux, int state)
{
  static int grab_state = 0;
  static int x1, y1, x2, y2;
  int rmx, rmy, wmx, wmy;
  unsigned int msq;
  Window rw, cw;
  XSetWindowAttributes winattr;
  XGCValues gcv;
  static GC gc = NULL;
  static Window clientwin = 0;
  static int first_motion = 1;
  static int displayh = 0, displayw = 0;
  static unsigned long white = 0;

  if(grab_state == 0 && event == ButtonPress && button == Button1) {
    unsigned long gcvm = GCFunction | GCForeground;

    white = WhitePixel(display, screen_number);
    displayh = DisplayHeight(display, screen_number);
    displayw = DisplayWidth(display, screen_number);

    XQueryPointer(display, xctx->window, &rw, &cw , &rmx, &rmy, &wmx, &wmy, &msq);
    gcv.function = GXxor;
    gcv.foreground = white;
    gc = XCreateGC(display, rw, gcvm, &gcv);

    winattr.override_redirect = True;
    clientwin = XCreateWindow(display, rw, 0, 0, displayw, displayh, 0, screendepth,
                InputOutput, visual, CWOverrideRedirect, &winattr);
    XMapRaised(display,clientwin);

    x1 = rmx;
    y1 = rmy;
    dbg(1, "grabscreen(): got point1: %d %d\n", x1, y1);
    grab_state = 1;
  }

  if(grab_state == 1 && event == MotionNotify) {
    static int xx1, xx2, yy1, yy2;
    xx1 = x1; yy1 = y1; xx2 = x2; yy2 = y2;
    INT_RECTORDER(xx1, yy1, xx2, yy2);
    dbg(1, "Motion: %d %d %d %d\n", xx1, yy1, xx2, yy2);
    if(!first_motion) {
      XDrawRectangle(display, clientwin, gc, xx1 - 1, yy1 - 1, xx2 - xx1 + 2, yy2 - yy1 + 2);
    }
    first_motion = 0;
    XQueryPointer(display, xctx->window, &rw, &cw , &rmx, &rmy, &wmx, &wmy, &msq);
    x2 = xx2 = rmx;
    y2 = yy2 = rmy;
    xx1 = x1; yy1 = y1;
    INT_RECTORDER(xx1, yy1, xx2, yy2);
    XDrawRectangle(display, clientwin, gc, xx1 - 1, yy1 - 1, xx2 - xx1 + 2, yy2 - yy1 + 2);
  }

  if(grab_state == 1 && event == ButtonRelease) {
    int grab_w = 0, grab_h = 0;
    cairo_surface_t *sfc = NULL, *subsfc = NULL;
    png_to_byte_closure_t closure;
    char *encoded_data = NULL;
    size_t olength;
    char *prop = NULL;


    grab_state = 0;
    first_motion = 1;
    xctx->ui_state &= ~GRABSCREEN;
    XQueryPointer(display, xctx->window, &rw, &cw , &rmx, &rmy, &wmx, &wmy, &msq);
    x2 = rmx;
    y2 = rmy;
    INT_RECTORDER(x1, y1, x2, y2);
    tclvareval("grab release ", xctx->top_path, ".drw", NULL);
    if(x2 - x1 > 10 && y2 -y1 > 10) {
      xctx->push_undo();
      grab_w = (x2 - x1 + 1);
      grab_h = (y2 - y1 + 1);
      dbg(1, "grabscreen(): grab area: %d %d - %d %d\n", x1, y1, x2, y2);
      dbg(1, "grabscreen(): root w=%d, h=%d\n", displayw, displayh);
      sfc =  cairo_xlib_surface_create(display, rw, visual, displayw, displayh);
      if(!sfc || cairo_surface_status(sfc) != CAIRO_STATUS_SUCCESS) {
        dbg(0, "grabscreen(): failure creating sfc\n");
        XFreeGC(display, gc);
        XDestroyWindow(display, clientwin);
        return 0;
      }
      dbg(1, "sfc: w=%d, h=%d\n",
            cairo_xlib_surface_get_width(sfc),
            cairo_xlib_surface_get_height(sfc));
      subsfc = cairo_surface_create_for_rectangle(sfc, x1, y1, grab_w, grab_h);
      if(!subsfc || cairo_surface_status(subsfc) != CAIRO_STATUS_SUCCESS) {
        dbg(0, "grabscreen(): failure creating subsfc\n");
        cairo_surface_destroy(sfc);
        XFreeGC(display, gc);
        XDestroyWindow(display, clientwin);
        return 0;
      }
      closure.buffer = NULL;
      closure.size = 0;
      closure.pos = 0;
      cairo_surface_write_to_png_stream(subsfc, png_writer, &closure);
      cairo_surface_destroy(subsfc);
      cairo_surface_destroy(sfc);
      closure.size = closure.pos;
      dbg(1, "closure.size = %ld\n", closure.size);
      encoded_data = base64_encode((unsigned char *)closure.buffer, closure.size, &olength, 0);
      dbg(1, "olength = %ld\n", olength);
      my_free(_ALLOC_ID_, &closure.buffer);
      my_mstrcat(_ALLOC_ID_, &prop, "flags=image,unscaled\nalpha=0.8\nimage_data=", encoded_data, NULL);
      my_free(_ALLOC_ID_, &encoded_data);
      storeobject(-1, xctx->mousex_snap, xctx->mousey_snap, xctx->mousex_snap + grab_w, xctx->mousey_snap + grab_h,
                  xRECT, GRIDLAYER, SELECTED, prop);
      my_free(_ALLOC_ID_, &prop);
      xctx->need_reb_sel_arr=1;
      rebuild_selected_array();
      /* phase 2 of doc/claude/suggestions/plan_modal_gesture_exclusion.md (issue 0247) -- see
       * leave_wire_draw_for() in scheduler.c. The grabbed image arms the same cursor placement
       * (START_SYMPIN + STARTMOVE) as add_graph/add_image and would jam the same way on top of a
       * live wire draw. Gated at the ARM (here, on the release that completes the grab) rather
       * than where the grab is started, so an abandoned grab -- released too small, or a failed
       * surface -- leaves the wire alone. GUI-only path (X + cairo, driven by a real pointer
       * grab), so this one is proved by code and has no headless seam. */
      leave_wire_draw_for("Screen grab");
      leave_shape_draw_for("Screen grab");   /* issue 0269 -- phase 3, the SHAPE twin: see leave_shape_draw_for() (callback.c) */
      /* issue 0242, same siting argument as the wire gate above (at the ARM, on the release that
       * completes the grab): the grabbed image arms START_SYMPIN + STARTMOVE, so dropping it onto
       * a live Add-Pin / Add-Wire-Label preview would leave that preview committed. GUI-only
       * path, so this one is proved by code and has no headless seam either. */
      leave_placement_for("Screen grab");
      /* issue 0265 -- and a pending PASTE, the third modal gesture this arm can land on. One of
       * the four arms that never unselect_all(), so before the gate the merged objects were simply
       * folded into the stamp below and dropped with the image. GUI-only, proved by code. */
      leave_merge_for("Screen grab");
      move_objects(START,0,0,0);
      /* issue 0241. This arm never unselect_all()s, so the stamp deliberately captures the
       * user's pre-existing selection too -- it rides the cursor with the grabbed image and is
       * dropped with it, so it is part of the preview by construction. */
      stamp_placement_preview();
      xctx->ui_state |= START_SYMPIN;
    }
    XFreeGC(display, gc);
    XDestroyWindow(display, clientwin);
  }
  return 1;
}
#endif

#if HAS_CAIRO==1
static void set_cairo_color(int layer)
{
  cairo_set_source_rgb(xctx->cairo_ctx,
    (double)xctx->xcolor_array[layer].red/65535.0,
    (double)xctx->xcolor_array[layer].green/65535.0,
    (double)xctx->xcolor_array[layer].blue/65535.0);
  cairo_set_source_rgb(xctx->cairo_save_ctx,
    (double)xctx->xcolor_array[layer].red/65535.0,
    (double)xctx->xcolor_array[layer].green/65535.0,
    (double)xctx->xcolor_array[layer].blue/65535.0);
}

/* remember to call cairo_restore(xctx->cairo_ctx) when done !! */
int set_text_custom_font(xText *txt) /* 20171122 for correct text_bbox calculation */
{
  const char *textfont;
  if (xctx->cairo_ctx==NULL) return 0;
  textfont = txt->font;
  if((textfont && textfont[0]) || (txt->flags & (TEXT_BOLD | TEXT_OBLIQUE | TEXT_ITALIC))) {
    cairo_font_slant_t slant;
    cairo_font_weight_t weight;
    textfont = (txt->font && txt->font[0]) ? txt->font : tclgetvar("cairo_font_name");
    weight = ( txt->flags & TEXT_BOLD) ? CAIRO_FONT_WEIGHT_BOLD : CAIRO_FONT_WEIGHT_NORMAL;
    slant = CAIRO_FONT_SLANT_NORMAL;
    if(txt->flags & TEXT_ITALIC) slant = CAIRO_FONT_SLANT_ITALIC;
    if(txt->flags & TEXT_OBLIQUE) slant = CAIRO_FONT_SLANT_OBLIQUE;
    cairo_save(xctx->cairo_ctx);
    xctx->cairo_font =
          cairo_toy_font_face_create(textfont, slant, weight);
    cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
    cairo_font_face_destroy(xctx->cairo_font);
    return 1;
  }
  return 0;
}
#else
int set_text_custom_font(xText *txt)
{
  return 0;
}
#endif


#if HAS_CAIRO==1
static void cairo_draw_string_line(cairo_t *c_ctx, char *s,
    double x, double y, short rot, short flip,
    int lineno, double fontheight, double fontascent, double fontdescent,
    int llength, int no_of_lines, double longest_line)
{
  double ix, iy;
  short rot1;
  double line_delta;
  double lines;
  double vc; /* 20171121 vert correct */

  if(s==NULL) return;
  if(llength==0) return;

  line_delta = (lineno*fontheight*cairo_font_line_spacing);
  lines = (no_of_lines-1)*fontheight*cairo_font_line_spacing;

  ix=X_TO_SCREEN(x);
  iy=Y_TO_SCREEN(y);
  if(rot&1) {
    rot1=3;
  } else rot1=0;

  vc = cairo_vert_correct*xctx->mooz; /* converted to device (pixel) space */

  if(     rot==0 && flip==0) {iy+=line_delta+fontascent-vc;}
  else if(rot==1 && flip==0) {iy+=longest_line;ix=ix-fontheight+fontascent+vc-lines+line_delta;}
  else if(rot==2 && flip==0) {iy=iy-fontheight-lines+line_delta+fontascent+vc; ix=ix-longest_line;}
  else if(rot==3 && flip==0) {ix+=line_delta+fontascent-vc;}
  else if(rot==0 && flip==1) {ix=ix-longest_line;iy+=line_delta+fontascent-vc;}
  else if(rot==1 && flip==1) {ix=ix-fontheight+line_delta-lines+fontascent+vc;}
  else if(rot==2 && flip==1) {iy=iy-fontheight-lines+line_delta+fontascent+vc;}
  else if(rot==3 && flip==1) {iy=iy+longest_line;ix+=line_delta+fontascent-vc;}

  cairo_save(c_ctx);
  cairo_translate(c_ctx, ix, iy);
  cairo_rotate(c_ctx, XSCH_PI/2*rot1);

  cairo_move_to(c_ctx, 0, 0);
  cairo_show_text(c_ctx, s);
  cairo_restore(c_ctx);
}

/* CAIRO version */
void draw_string(int layer, int what, const char *str, short rot, short flip, int hcenter, int vcenter,
                 double x, double y, double xscale, double yscale)
{
  double textx1,textx2,texty1,texty2;
  char *tt, *ss, *sss=NULL;
  char c;
  int lineno=0;
  double size;
  char *estr = NULL; /* expanded str: tabs replaced with spaces */
  cairo_font_extents_t fext;
  int llength=0, no_of_lines;
  double longest_line;

  (void)what; /* UNUSED in cairo version, avoid compiler warning */
  if(str==NULL || !has_x ) return;
  size = xscale*52.*cairo_font_scale;
  /*fprintf(errfp, "size=%.16g\n", size*xctx->mooz); */
  if(size*xctx->mooz<3.0) return; /* too small */
  if(size*xctx->mooz>1600) return; /* too big */
  estr = my_expand(str, tclgetintvar("tabstop"));
  text_bbox(estr, xscale, yscale, rot, flip, hcenter, vcenter, x,y,
            &textx1,&texty1,&textx2,&texty2, &no_of_lines, &longest_line);
  if(!textclip(xctx->areax1,xctx->areay1,xctx->areax2,
               xctx->areay2,textx1,texty1,textx2,texty2)) {
    my_free(_ALLOC_ID_, &estr);
    return;
  }

  if(hcenter) {
    if(rot == 0 && flip == 0 ) { x=textx1;}
    if(rot == 1 && flip == 0 ) { y=texty1;}
    if(rot == 2 && flip == 0 ) { x=textx2;}
    if(rot == 3 && flip == 0 ) { y=texty2;}
    if(rot == 0 && flip == 1 ) { x=textx2;}
    if(rot == 1 && flip == 1 ) { y=texty2;}
    if(rot == 2 && flip == 1 ) { x=textx1;}
    if(rot == 3 && flip == 1 ) { y=texty1;}
  }
  if(vcenter) {
    if(rot == 0 && flip == 0 ) { y=texty1;}
    if(rot == 1 && flip == 0 ) { x=textx2;}
    if(rot == 2 && flip == 0 ) { y=texty2;}
    if(rot == 3 && flip == 0 ) { x=textx1;}
    if(rot == 0 && flip == 1 ) { y=texty1;}
    if(rot == 1 && flip == 1 ) { x=textx2;}
    if(rot == 2 && flip == 1 ) { y=texty2;}
    if(rot == 3 && flip == 1 ) { x=textx1;}
  }

  set_cairo_color(layer);
  cairo_set_font_size(xctx->cairo_ctx, size*xctx->mooz);
  cairo_set_font_size(xctx->cairo_save_ctx, size*xctx->mooz);
  cairo_font_extents(xctx->cairo_ctx, &fext);
  dbg(1, "draw_string(): size * mooz=%g height=%g ascent=%g descent=%g\n",
       size * xctx->mooz, fext.height, fext.ascent, fext.descent);
  llength=0;
  my_strdup2(_ALLOC_ID_, &sss, estr);
  tt=ss=sss;
  for(;;) {
    c=*ss;
    if(c=='\n' || c==0) {
      *ss='\0';
      /*fprintf(errfp, "cairo_draw_string(): tt=%s, longest line: %d\n", tt, longest_line); */
      if(xctx->draw_window) cairo_draw_string_line(xctx->cairo_ctx, tt, x, y, rot, flip,
         lineno, fext.height, fext.ascent, fext.descent, llength, no_of_lines, longest_line);
      if(xctx->draw_pixmap) cairo_draw_string_line(xctx->cairo_save_ctx, tt, x, y, rot, flip,
         lineno, fext.height, fext.ascent, fext.descent, llength, no_of_lines, longest_line);
      ++lineno;
      if(c==0) break;
      *ss='\n';
      tt=ss+1;
      llength=0;
    } else {
      ++llength;
    }
    ++ss;
  }
  my_free(_ALLOC_ID_, &sss);
  my_free(_ALLOC_ID_, &estr);
}

#else /* !HAS_CAIRO */

/* no CAIRO version */
void draw_string(int layer, int what, const char *str, short rot, short flip, int hcenter, int vcenter,
                 double x1,double y1, double xscale, double yscale)
{
 double textx1,textx2,texty1,texty2;
 double a=0.0,yy;
 register double rx1=0,rx2=0,ry1=0,ry2=0;
 double curr_x1,curr_y1,curr_x2,curr_y2;
 double zx1, invxscale;
 int pos=0,pos2=0;
 unsigned int cc;
 double *char_ptr_x1,*char_ptr_y1,*char_ptr_x2,*char_ptr_y2;
 int i,lines, no_of_lines;
 double longest_line;

 if(str==NULL || !has_x ) return;
 dbg(2, "draw_string(): string=%s\n",str);
 if(xscale*FONTWIDTH*xctx->mooz<1) {
   dbg(1, "draw_string(): xscale=%.16g zoom=%.16g \n",xscale,xctx->zoom);
   return;
 }
 else {
  char *estr = my_expand(str, tclgetintvar("tabstop"));
  text_bbox(estr, xscale, yscale, rot, flip, hcenter, vcenter, x1,y1,
            &textx1,&texty1,&textx2,&texty2, &no_of_lines, &longest_line);
  if(!textclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,
               textx1,texty1,textx2,texty2)) {
    my_free(_ALLOC_ID_, &estr);
    return;
  }
  xscale*=tclgetdoublevar("nocairo_font_xscale") * cairo_font_scale;
  yscale*=tclgetdoublevar("nocairo_font_yscale") * cairo_font_scale;
  x1=textx1;y1=texty1;
  if(rot&1) {y1=texty2;rot=3;}
  else rot=0;
  flip = 0; yy=y1;
  invxscale=1/xscale;
  while(estr[pos2]) {
     cc = (unsigned char)estr[pos2++];
     if(cc>127) cc= '?';
     if(cc=='\n') {
        yy+=(FONTHEIGHT+FONTDESCENT+FONTWHITESPACE)* yscale;
        pos=0;
        a=0.0;
        continue;
     }
     lines=(int)character[cc][0]*4;
     char_ptr_x1=character[cc]+1;
     char_ptr_y1=character[cc]+2;
     char_ptr_x2=character[cc]+3;
     char_ptr_y2=character[cc]+4;
     zx1=a+x1*invxscale;
     for(i=0;i<lines;i+=4) {
        curr_x1 = ( char_ptr_x1[i]+ zx1 ) * xscale ;
        curr_y1 = ( char_ptr_y1[i] ) * yscale+yy;
        curr_x2 = ( char_ptr_x2[i]+ zx1 ) * xscale ;
        curr_y2 = ( char_ptr_y2[i] ) * yscale+yy;
        ROTATION(rot, flip, x1,y1,curr_x1,curr_y1,rx1,ry1);
        ROTATION(rot, flip, x1,y1,curr_x2,curr_y2,rx2,ry2);
        ORDER(rx1,ry1,rx2,ry2);
        drawline(layer, what, rx1, ry1, rx2, ry2, 0.0, 0, NULL);
     }
     ++pos;
     a += FONTWIDTH+FONTWHITESPACE;
  }
  my_free(_ALLOC_ID_, &estr);
 }
}

#endif /* HAS_CAIRO */

void draw_temp_string(GC gctext, int what, const char *str, short rot, short flip, int hcenter, int vcenter,
                 double x1,double y1, double xscale, double yscale)
{
 double textx1,textx2,texty1,texty2;
 int tmp;
 double dtmp;
 char *estr = NULL;
 if(!has_x) return;

 estr = my_expand(str, tclgetintvar("tabstop"));
 dbg(2, "draw_string(): string=%s\n",estr);
 if(!text_bbox(estr, xscale, yscale, rot, flip, hcenter, vcenter, x1,y1,
     &textx1,&texty1,&textx2,&texty2, &tmp, &dtmp)) {
   my_free(_ALLOC_ID_, &estr);
   return;
 }
 drawtemprect(gctext,what, textx1,texty1,textx2,texty2);
 my_free(_ALLOC_ID_, &estr);
}

void get_sym_text_layer(int inst, int text_n, int *layer)
{
  char attr[50];
  const char *tl=NULL;
  int lay;
  int sym_n = xctx->inst[inst].ptr;

  *layer = -1;
  if(sym_n >= 0 && xctx->sym[sym_n].texts > text_n) {
    if(xctx->inst[inst].prop_ptr && strstr(xctx->inst[inst].prop_ptr, "text_layer_")) {
      my_snprintf(attr, S(attr), "text_layer_%d", text_n);
      tl = get_tok_value(xctx->inst[inst].prop_ptr, attr, 0);
    } else {
      xctx->tok_size = 0;
    }
    if(xctx->tok_size) {
      lay = atoi(tl);
      if(lay >= 0 && lay < cadlayers) *layer = lay;
    }
  }
}

void get_sym_text_size(int inst, int text_n, double *xscale, double *yscale)
{
  char attr[50];
  const char *ts=NULL;
  double size;
  int sym_n = xctx->inst[inst].ptr;

  if(sym_n >= 0 && xctx->sym[sym_n].texts > text_n) {
    if(xctx->inst[inst].prop_ptr && strstr(xctx->inst[inst].prop_ptr, "text_size_")) {
      my_snprintf(attr, S(attr), "text_size_%d", text_n);
      ts = get_tok_value(xctx->inst[inst].prop_ptr, attr, 0);
    } else {
      xctx->tok_size = 0;
    }
    if(xctx->tok_size) {
      size = atof(ts);
      *xscale = size;
      *yscale = size;
    } else {
      xText *txtptr;
      txtptr =  &(xctx->sym[sym_n].text[text_n]);
      *xscale = txtptr->xscale;
      *yscale = txtptr->yscale;
    }
  } else {
    *xscale = *yscale = 0.0;
  }
}


/*
 * layer: the set of symbol objects on xschem layer 'layer' to draw
 * c    : the layer 'c' to draw those objects on (if != layer it is the hilight color)
 */
void draw_symbol(int what,int c, int n,int layer,short tmp_flip, short rot,
        double xoffset, double yoffset)
                            /* draws current layer only, should be called within  */
{                           /* a "for(i=0;i<cadlayers; ++i)" loop */
  int k, j, textlayer, hide = 0, disabled = 0;
  double x0,y0,x1,y1,x2,y2;
  double *x, *y; /* polygon point arrays */
  short flip;
  xLine *line;
  xRect *rect;
  xArc *arc;
  xPoly *polygon;
  xText text;
  register xSymbol *symptr;
  char *type;
  int lvs_ignore = 0;
  int c_for_text;
  #if HAS_CAIRO==1
  const char *textfont;
  #endif

  type = xctx->sym[xctx->inst[n].ptr].type;
  lvs_ignore=tclgetboolvar("lvs_ignore");
  if(!has_x) return;
  if(xctx->inst[n].ptr == -1) return;
  if(layer == 0) {
    xctx->inst[n].flags &= ~IGNORE_INST; /* clear bit */
    if( type && strcmp(type, "launcher") && strcmp(type, "logo") &&
        strcmp(type, "probe") &&
        strcmp(type, "architecture") && strcmp(type, "noconn")) {
      if(skip_instance(n, 1, lvs_ignore)) {
        xctx->inst[n].flags |= IGNORE_INST;
      }
    }
  }
  if(shorted_instance(n, lvs_ignore)) {
    c = PINLAYER;
    what = NOW;
    disabled = 2;
  }
  else if(xctx->inst[n].flags & IGNORE_INST) {
    c = GRIDLAYER;
    what = NOW;
    disabled = 1;
  }
  if( (xctx->inst[n].flags & HIDE_INST) || ((xctx->inst[n].ptr + xctx->sym)->flags & HIDE_INST) ||
      (xctx->hide_symbols==1 && (xctx->inst[n].ptr + xctx->sym)->type &&
      !strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "subcircuit") ) ||
      (xctx->hide_symbols == 2) ) {
    hide = 1;
  } else {
    hide = 0;
  }
  if(layer==0) {
    x1=X_TO_SCREEN(xctx->inst[n].x1+xoffset);  /* 20150729 added xoffset, yoffset */
    x2=X_TO_SCREEN(xctx->inst[n].x2+xoffset);
    y1=Y_TO_SCREEN(xctx->inst[n].y1+yoffset);
    y2=Y_TO_SCREEN(xctx->inst[n].y2+yoffset);
    if(RECT_OUTSIDE(x1,y1,x2,y2,xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2))
    {
     xctx->inst[n].flags|=1;
     return;
    }
    else if(
         xctx->hilight_nets &&                  /* if highlights...                       */
         c == 0 &&                              /* we are not drawing highlighted inst    */
                                                /* otherwise c > layer...                 */
         type  &&                               /* ... and type...                        */
         (
          (                                     /* ... and inst is hilighted ...          */
            IS_LABEL_SH_OR_PIN(type) && xctx->inst[n].node && xctx->inst[n].node[0] &&
            bus_hilight_hash_lookup(xctx->inst[n].node[0], 0, XLOOKUP )
          ) || (/* !IS_LABEL_SH_OR_PIN(type) && */ (xctx->inst[n].color != -10000)) )) {
      xctx->inst[n].flags|=1;      /* ... then SKIP instance now and for following layers */
      return;
    }
    else if(!xctx->only_probes && (xctx->inst[n].x2 - xctx->inst[n].x1) * xctx->mooz < 3 &&
                       (xctx->inst[n].y2 - xctx->inst[n].y1) * xctx->mooz < 3) {
      drawrect(SYMLAYER, NOW, xctx->inst[n].xx1, xctx->inst[n].yy1, xctx->inst[n].xx2, xctx->inst[n].yy2,
               0.0, 0, -1, -1);
      xctx->inst[n].flags|=1;
      return;
    }
    else {
      xctx->inst[n].flags&=~1;
    }
    if(hide) {
      int color = (disabled==1) ? GRIDLAYER : (disabled == 2) ? PINLAYER : SYMLAYER;
      drawrect(color, NOW, xctx->inst[n].xx1, xctx->inst[n].yy1, xctx->inst[n].xx2, xctx->inst[n].yy2,
               0.0, 2, -1, -1);
    }
  } else if(xctx->inst[n].flags&1) {
    dbg(2, "draw_symbol(): skipping inst %d\n", n);
    return;
  }
  flip = xctx->inst[n].flip;
  if(tmp_flip) flip = !flip;
  rot = (xctx->inst[n].rot + rot ) & 0x3;

  x0=xctx->inst[n].x0 + xoffset;
  y0=xctx->inst[n].y0 + yoffset;
  symptr = (xctx->inst[n].ptr+ xctx->sym);

  if(layer == cadlayers) goto draw_texts;
  if( (layer != PINLAYER && !xctx->enable_layer[layer]) ) return;

  if(!hide) {
    for(j=0;j< symptr->lines[layer]; ++j)
    {
      int dash;
      line = &(symptr->line[layer])[j];
      dash = (disabled == 1) ? 3 : line->dash;
      ROTATION(rot, flip, 0.0, 0.0,line->x1,line->y1,x1,y1);
      ROTATION(rot, flip, 0.0, 0.0,line->x2,line->y2,x2,y2);
      ORDER(x1,y1,x2,y2);
      if(line->bus == -1.0)
        drawline(c,THICK, x0+x1, y0+y1, x0+x2, y0+y2, line->bus, dash, NULL);
      else
        drawline(c,what, x0+x1, y0+y1, x0+x2, y0+y2, line->bus, dash, NULL);
    }
    for(j=0;j< symptr->polygons[layer]; ++j)
    {
      int dash;
      int bezier;
      polygon = &(symptr->poly[layer])[j];
      bezier = !strboolcmp(get_tok_value(polygon->prop_ptr, "bezier", 0), "true");
      dash = (disabled == 1) ? 3 : polygon->dash;
      x = my_malloc(_ALLOC_ID_, sizeof(double) * polygon->points);
      y = my_malloc(_ALLOC_ID_, sizeof(double) * polygon->points);
      for(k=0;k<polygon->points; ++k) {
        ROTATION(rot, flip, 0.0, 0.0,polygon->x[k],polygon->y[k],x[k],y[k]);
        x[k]+= x0;
        y[k] += y0;
      }
      drawpolygon(c, NOW, x, y, polygon->points, polygon->fill, dash, polygon->bus, bezier); /* added fill */
      my_free(_ALLOC_ID_, &x);
      my_free(_ALLOC_ID_, &y);
    }
    for(j=0;j< symptr->arcs[layer]; ++j)
    {
      int dash;
      double angle;
      arc = &(symptr->arc[layer])[j];
      dash = (disabled == 1) ? 3 : arc->dash;
      if(flip) {
        angle = 270.*rot+180.-arc->b-arc->a;
      } else {
        angle = arc->a+rot*270.;
      }
      angle = fmod(angle, 360.);
      if(angle<0.) angle+=360.;
      ROTATION(rot, flip, 0.0, 0.0,arc->x,arc->y,x1,y1);
      drawarc(c,what, x0+x1, y0+y1, arc->r, angle, arc->b, arc->fill, arc->bus, dash);
    }
  } /* if(!hide) */

  if( (!hide && xctx->enable_layer[layer]) ||
      (hide && layer == PINLAYER && xctx->enable_layer[layer]) ) {
    for(j=0;j< symptr->rects[layer]; ++j)
    {
      int dash;
      rect = &(symptr->rect[layer])[j];
      dash = (disabled == 1) ? 3 : rect->dash;
      ROTATION(rot, flip, 0.0, 0.0,rect->x1,rect->y1,x1,y1);
      ROTATION(rot, flip, 0.0, 0.0,rect->x2,rect->y2,x2,y2);
      #if HAS_CAIRO == 1
      if(layer == GRIDLAYER && rect->flags & 1024) {
        double xx1 = x0 + x1;
        double yy1 = y0 + y1;
        double xx2 = x0 + x2;
        double yy2 = y0 + y2;
        draw_image(1, rect, &xx1, &yy1, &xx2, &yy2, rot, flip);
      } else
      #endif
      {
        int ellipse_a = rect->ellipse_a;
        int ellipse_b = rect->ellipse_b;

        if(ellipse_a != -1 && ellipse_b != 360) {
          if(flip) {
            ellipse_a = 180 - ellipse_a - ellipse_b;
          }
          if(rot) {
            if(rot == 3) {
              ellipse_a += 90;
            } else if(rot == 2) {
              ellipse_a += 180;
            } else if(rot == 1) {
              ellipse_a += 270;
            }
            ellipse_a %= 360;
          }
        }
        RECTORDER(x1,y1,x2,y2);
        drawrect(c,what, x0+x1, y0+y1, x0+x2, y0+y2, rect->bus, dash, ellipse_a, ellipse_b);
        if(rect->fill) filledrect(c,what, x0+x1, y0+y1, x0+x2, y0+y2, rect->fill,
                                  ellipse_a, ellipse_b);
      }
    }
  } /* if( (!hide && xctx->enable_layer[layer]) || ... */

  draw_texts:

  if(xctx->sym_txt && !(xctx->inst[n].flags & HIDE_SYMBOL_TEXTS) && (layer == cadlayers)) {
    if(c != layer) c_for_text = c;
    else if(xctx->inst[n].flags & PIN_OR_LABEL) c_for_text = TEXTWIRELAYER;
    else c_for_text = TEXTLAYER;
    for(j=0;j< symptr->texts; ++j)
    {
      double xscale, yscale;
      get_sym_text_size(n, j, &xscale, &yscale);
      text = symptr->text[j];
      if(!text.txt_ptr || !text.txt_ptr[0] || xscale*FONTWIDTH*xctx->mooz<1) continue;
      if(!xctx->show_hidden_texts && (text.flags & (HIDE_TEXT | HIDE_TEXT_INSTANTIATED))) continue;
      if( hide && text.txt_ptr && strcmp(text.txt_ptr, "@symname") && strcmp(text.txt_ptr, "@name") ) continue;
      ROTATION(rot, flip, 0.0, 0.0,text.x0,text.y0,x1,y1);
      textlayer = c_for_text;
      /* do not allow custom text color on hilighted instances */
      if(disabled == 1) textlayer = GRIDLAYER;
      else if(disabled == 2) textlayer = PINLAYER;
      else if( xctx->inst[n].color == -10000) {
        int lay;
        if(xctx->only_probes) textlayer = GRIDLAYER;
        else {
          get_sym_text_layer(n, j, &lay);
          if(lay != -1) textlayer = lay;
          else textlayer = symptr->text[j].layer;
        }
      }
      if(textlayer < 0 || textlayer >= cadlayers) textlayer = c_for_text;
      if(xctx->draw_single_layer != -1 && textlayer != xctx->draw_single_layer) continue;
      /* display PINLAYER colored instance texts even if PINLAYER disabled */
      if(xctx->inst[n].color == -PINLAYER || xctx->enable_layer[textlayer]) {
        char *txtptr = NULL;
        #if HAS_CAIRO==1
        textfont = symptr->text[j].font;
        if((textfont && textfont[0]) || (symptr->text[j].flags & (TEXT_BOLD | TEXT_OBLIQUE | TEXT_ITALIC))) {
          cairo_font_slant_t slant;
          cairo_font_weight_t weight;
          textfont = (symptr->text[j].font && symptr->text[j].font[0]) ?
            symptr->text[j].font : tclgetvar("cairo_font_name");
          weight = ( symptr->text[j].flags & TEXT_BOLD) ? CAIRO_FONT_WEIGHT_BOLD : CAIRO_FONT_WEIGHT_NORMAL;
          slant = CAIRO_FONT_SLANT_NORMAL;
          if(symptr->text[j].flags & TEXT_ITALIC) slant = CAIRO_FONT_SLANT_ITALIC;
          if(symptr->text[j].flags & TEXT_OBLIQUE) slant = CAIRO_FONT_SLANT_OBLIQUE;
          cairo_save(xctx->cairo_ctx);
          cairo_save(xctx->cairo_save_ctx);
          xctx->cairo_font =
                cairo_toy_font_face_create(textfont, slant, weight);
          cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
          cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
          cairo_font_face_destroy(xctx->cairo_font);
        }
        #endif
        dbg(1, "draw_symbol(): drawing string: before translate(): text.txt_ptr=%s\n", text.txt_ptr);
        my_strdup2(_ALLOC_ID_, &txtptr, translate(n, text.txt_ptr));
        /* do another round of substitutions if some @var are found, but if not found leave @var as is */
        dbg(1, "draw_symbol(): drawing string: str=%s prop=%s\n",
                txtptr, text.prop_ptr ?  text.prop_ptr : "<NULL>");
         my_strdup2(_ALLOC_ID_, &txtptr, translate3(txtptr, 0, xctx->inst[n].prop_ptr,
           xctx->sym[xctx->inst[n].ptr].templ, NULL, NULL));
        dbg(1, "draw_symbol(): after translate3: str=%s\n", txtptr);
        draw_string(textlayer, what, txtptr,
          (text.rot + ( (flip && (text.rot & 1) ) ? rot+2 : rot) ) & 0x3,
          flip^text.flip, text.hcenter, text.vcenter,
          x0+x1, y0+y1, xscale, yscale);
        my_free(_ALLOC_ID_, &txtptr);
        #if HAS_CAIRO!=1
        drawrect(textlayer, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, -1, -1);
        drawline(textlayer, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, NULL);
        #endif
        #if HAS_CAIRO==1
        if( (textfont && textfont[0]) || (symptr->text[j].flags & (TEXT_BOLD | TEXT_OBLIQUE | TEXT_ITALIC))) {
          cairo_restore(xctx->cairo_ctx);
          cairo_restore(xctx->cairo_save_ctx);
        }
        #endif
      }
    }

    /* P6 (doc/claude/specs/cadence_pin_name_text.md §4.2): render each pin's name directly
     * from the symbol's pin tokens (name=, name_dx/dy/size/rot/flip, name_font), gated by the
     * show_pin_names tri-state + per-pin show_pinname (pin_name_visible). Way A: the shared
     * sym[] cache is never augmented with synthetic view texts, so an instance draws the name
     * here from tokens (mirroring the symbol-edit view). Not drawn on a bbox-hidden symbol;
     * honors zoom-cull and the text-layer enable / single-layer gates like the loop above. */
    if(!hide && !pin_names_all_off()) for(j = 0; j < symptr->rects[PINLAYER]; ++j) {
      xRect *pin = &(symptr->rect[PINLAYER])[j];
      Pin_name_layout lay;
      char *pnm = NULL, *pfont = NULL;
      double pcx, pcy, tx, ty;
      int plw;
      if(!pin_name_visible(pin->prop_ptr)) continue;
      if(!get_pin_name_layout(pin->prop_ptr, &lay, &pnm, &pfont)) continue;
      if(lay.size * FONTWIDTH * xctx->mooz < 1) {                   /* zoom-cull, as texts */
        my_free(_ALLOC_ID_, &pnm); my_free(_ALLOC_ID_, &pfont); continue;
      }
      plw = c_for_text;
      if(disabled == 1) plw = GRIDLAYER;
      else if(disabled == 2) plw = PINLAYER;
      if(plw < 0 || plw >= cadlayers) plw = c_for_text;
      if((xctx->draw_single_layer == -1 || plw == xctx->draw_single_layer) &&
         (xctx->inst[n].color == -PINLAYER || xctx->enable_layer[plw])) {
        pcx = (pin->x1 + pin->x2) / 2.0;
        pcy = (pin->y1 + pin->y2) / 2.0;
        tx = pcx + lay.dx; ty = pcy + lay.dy;
        ROTATION(rot, flip, 0.0, 0.0, tx, ty, x1, y1);
        #if HAS_CAIRO==1
        if(pfont && pfont[0]) {
          xctx->cairo_font = cairo_toy_font_face_create(pfont,
            CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
          cairo_save(xctx->cairo_ctx); cairo_save(xctx->cairo_save_ctx);
          cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
          cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
          cairo_font_face_destroy(xctx->cairo_font);
        }
        #endif
        draw_string(plw, what, pnm,
          ((short)lay.rot + ((flip && ((short)lay.rot & 1)) ? rot + 2 : rot)) & 0x3,
          flip ^ (short)lay.flip, 0, 0, x0 + x1, y0 + y1, lay.size, lay.size);
        #if HAS_CAIRO!=1
        drawrect(plw, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, -1, -1);
        drawline(plw, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, NULL);
        #endif
        #if HAS_CAIRO==1
        if(pfont && pfont[0]) {
          cairo_restore(xctx->cairo_ctx); cairo_restore(xctx->cairo_save_ctx);
        }
        #endif
      }
      my_free(_ALLOC_ID_, &pnm);
      my_free(_ALLOC_ID_, &pfont);
    }
  }
}

void draw_temp_symbol(int what, GC gc, int n,int layer,short tmp_flip, short rot,
        double xoffset, double yoffset)
                            /* draws current layer only, should be called within */
{                           /* a "for(i=0;i<cadlayers; ++i)" loop */
 int j, hide = 0;
 double x0,y0,x1,y1,x2,y2;
 short flip;
 xLine *line;
 xPoly *polygon;
 xRect *rect;
 xArc *arc;
 xText text;
 register xSymbol *symptr;

 #if HAS_CAIRO==1
 int customfont;
 #endif

 if(xctx->inst[n].ptr == -1) return;
 if(!has_x) return;

 if( (xctx->inst[n].flags & HIDE_INST) || ((xctx->inst[n].ptr + xctx->sym)->flags & HIDE_INST) ||
     (xctx->hide_symbols==1 && (xctx->inst[n].ptr+ xctx->sym)->prop_ptr &&
     !strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "subcircuit") ) ||
     (xctx->hide_symbols == 2) ) {
   hide = 1;
 } else {
   hide = 0;
 }

 flip = xctx->inst[n].flip;
 if(tmp_flip) flip = !flip;
 rot = (xctx->inst[n].rot + rot ) & 0x3;

 if(layer==0) {
   x1=X_TO_SCREEN(xctx->inst[n].x1+xoffset); /* 20150729 added xoffset, yoffset */
   x2=X_TO_SCREEN(xctx->inst[n].x2+xoffset);
   y1=Y_TO_SCREEN(xctx->inst[n].y1+yoffset);
   y2=Y_TO_SCREEN (xctx->inst[n].y2+yoffset);
   if(RECT_OUTSIDE(x1,y1,x2,y2,xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2))
   {
    xctx->inst[n].flags|=1;
    return;
   }
   else if(!xctx->only_probes && (xctx->inst[n].x2 - xctx->inst[n].x1) * xctx->mooz < 3 &&
                      (xctx->inst[n].y2 - xctx->inst[n].y1) * xctx->mooz < 3) {
     drawtemprect(gc, what, xctx->inst[n].xx1 + xoffset, xctx->inst[n].yy1 + yoffset,
                            xctx->inst[n].xx2 + xoffset, xctx->inst[n].yy2 + yoffset);
     xctx->inst[n].flags|=1;
     return;
   }
   else xctx->inst[n].flags&=~1;
   if(hide) {
     /*
      * symptr = (xctx->inst[n].ptr+ xctx->sym);
      * x0=xctx->inst[n].x0;
      * y0=xctx->inst[n].y0;
      * x0 += xoffset;
      * y0 += yoffset;
      * ROTATION(rot, flip, 0.0, 0.0,symptr->minx, symptr->miny,x1,y1);
      * ROTATION(rot, flip, 0.0, 0.0,symptr->maxx, symptr->maxy,x2,y2);
      * RECTORDER(x1,y1,x2,y2);
      * drawtemprect(gc,what, x0+x1, y0+y1, x0+x2, y0+y2);
      */
      drawtemprect(gc,what,xctx->inst[n].xx1 + xoffset, xctx->inst[n].yy1 + yoffset,
                           xctx->inst[n].xx2 + xoffset, xctx->inst[n].yy2 + yoffset);
   }
 } else if(xctx->inst[n].flags&1) {
   dbg(2, "draw_symbol(): skipping inst %d\n", n);
   return;
 } /* /20150424 */

 x0=xctx->inst[n].x0 + xoffset;
 y0=xctx->inst[n].y0 + yoffset;
 symptr = (xctx->inst[n].ptr+ xctx->sym);
 if(!hide) {
   for(j=0;j< symptr->lines[layer]; ++j)
   {
    line = &(symptr->line[layer])[j];
    ROTATION(rot, flip, 0.0, 0.0,line->x1,line->y1,x1,y1);
    ROTATION(rot, flip, 0.0, 0.0,line->x2,line->y2,x2,y2);
    ORDER(x1,y1,x2,y2);
    if(line->bus == -1.0)
      drawtempline(gc,THICK, x0+x1, y0+y1, x0+x2, y0+y2);
    else
      drawtempline(gc,what, x0+x1, y0+y1, x0+x2, y0+y2);
   }
   for(j=0;j< symptr->polygons[layer]; ++j)
   {
     int bezier;
     polygon = &(symptr->poly[layer])[j];
     bezier = !strboolcmp(get_tok_value(polygon->prop_ptr, "bezier", 0), "true");
     {   /* scope block so we declare some auxiliary arrays for coord transforms. 20171115 */
       int k;
       double *x = my_malloc(_ALLOC_ID_, sizeof(double) * polygon->points);
       double *y = my_malloc(_ALLOC_ID_, sizeof(double) * polygon->points);
       for(k=0;k<polygon->points; ++k) {
         ROTATION(rot, flip, 0.0, 0.0,polygon->x[k],polygon->y[k],x[k],y[k]);
         x[k] += x0;
         y[k] += y0;
       }
       drawtemppolygon(gc, NOW, x, y, polygon->points, bezier);
       my_free(_ALLOC_ID_, &x);
       my_free(_ALLOC_ID_, &y);
     }
   }

   for(j=0;j< symptr->rects[layer]; ++j)
   {
    rect = &(symptr->rect[layer])[j];
    ROTATION(rot, flip, 0.0, 0.0,rect->x1,rect->y1,x1,y1);
    ROTATION(rot, flip, 0.0, 0.0,rect->x2,rect->y2,x2,y2);
    RECTORDER(x1,y1,x2,y2);
    drawtemprect(gc,what, x0+x1, y0+y1, x0+x2, y0+y2);
   }
   for(j=0;j< symptr->arcs[layer]; ++j)
   {
     double angle;
     arc = &(symptr->arc[layer])[j];
     if(flip) {
       angle = 270.*rot+180.-arc->b-arc->a;
     } else {
       angle = arc->a+rot*270.;
     }
     angle = fmod(angle, 360.);
     if(angle<0.) angle+=360.;
     ROTATION(rot, flip, 0.0, 0.0,arc->x,arc->y,x1,y1);
     drawtemparc(gc, what, x0+x1, y0+y1, arc->r, angle, arc->b);
   }

   if( !(xctx->inst[n].flags & HIDE_SYMBOL_TEXTS) &&  layer==SELLAYER && xctx->sym_txt)
   {
    char *txtptr = NULL;
    for(j=0;j< symptr->texts; ++j)
    {
     double xscale, yscale;

     get_sym_text_size(n, j, &xscale, &yscale);
     text = symptr->text[j];
     if(!text.txt_ptr || !text.txt_ptr[0] || xscale*FONTWIDTH*xctx->mooz<1) continue;
     if(!xctx->show_hidden_texts && (text.flags & (HIDE_TEXT | HIDE_TEXT_INSTANTIATED))) continue;
     ROTATION(rot, flip, 0.0, 0.0,text.x0,text.y0,x1,y1);
     #if HAS_CAIRO==1
     customfont = set_text_custom_font(&text);
     #endif
     my_strdup2(_ALLOC_ID_, &txtptr, translate(n, text.txt_ptr));
      /* do another round of substitutions if some @var are found, but if not found leave @var as is */
      my_strdup2(_ALLOC_ID_, &txtptr, translate3(txtptr, 0, xctx->inst[n].prop_ptr,
        xctx->sym[xctx->inst[n].ptr].templ, NULL, NULL));
     dbg(1, "draw_temp_symbol(): after translate3: str=%s\n", txtptr);
     if(txtptr[0]) draw_temp_string(gc, what, txtptr,
       (text.rot + ( (flip && (text.rot & 1) ) ? rot+2 : rot) ) & 0x3,
       flip^text.flip, text.hcenter, text.vcenter, x0+x1, y0+y1, xscale, yscale);
     my_free(_ALLOC_ID_, &txtptr);
     #if HAS_CAIRO==1
     if(customfont) {
       cairo_restore(xctx->cairo_ctx);
     }
     #endif

    }
   }
 }
}

static void drawgrid()
{
  double x, y, xax, yax, xx, yy;
  double delta,tmp;
  double mult;
  #if DRAW_ALL_CAIRO==0
  int i=0;
  const char *psize_ptr;
  int big_gr = tclgetboolvar("big_grid_points");
  int grid_point_size = -1;
  char dash_arr[2];
  int axes = tclgetboolvar("draw_grid_axes");

  psize_ptr = tclgetvar("grid_point_size");
  if(psize_ptr[0]) grid_point_size = atoi(psize_ptr);
  #endif
  dbg(1, "drawgrid(): draw grid\n");
  /* GRIDLAYER shares its GC with SELLAYER (both == layer 2, see xschem.h). The axes dash
   * setup below mutates that shared GC's line style. It MUST come after this early-out:
   * running it first left the GC LineOnOffDash on a grid-OFF redraw (the reset at the tail
   * of this function is only reached on the grid-ON path), so draw_selection() then stroked
   * the grey selection overlay dashed/broken -- the CTRL-G bug. The axis lines this sets up
   * are all drawn below the guard too, so nothing is lost on the grid-OFF path.
   * See doc/claude/issues/0082-grid-toggle-corrupts-selection-gc.md
   * xctx->no_grid stays FIRST (per-window grid-off, Waveform Viewer, item 18):
   * it must short-circuit before the shared-GC dash setup below, exactly like the
   * draw_grid guard it joins -- see doc/claude/specs/waveform_viewer.md. */
  if( xctx->no_grid || !tclgetboolvar("draw_grid") || !has_x) return;
  #if DRAW_ALL_CAIRO==0
  if(axes) {
    dash_arr[0] = dash_arr[1] = (char) 3;
    XSetDashes(display, xctx->gc[GRIDLAYER], 0, dash_arr, 1);
    if(!big_gr) {
      XSetLineAttributes (display, xctx->gc[GRIDLAYER],
          0, xDashType, xCap, xJoin);
    } else {
      XSetLineAttributes (display, xctx->gc[GRIDLAYER],
          XLINEWIDTH(xctx->lw), xDashType, xCap, xJoin);
    }
  }
  #endif
  delta=tclgetdoublevar("cadgrid")*xctx->mooz;
  #if DRAW_ALL_CAIRO==1
  set_cairo_color(GRIDLAYER);
  #endif


  if(delta < CADGRIDTHRESHOLD) {
    mult = ceil( (log(CADGRIDTHRESHOLD) - log(delta) ) / log(CADGRIDMULTIPLY) );
    delta = delta * pow(CADGRIDMULTIPLY, mult);
  }


  /* ************************ Draw axes ****************** */
  #if DRAW_ALL_CAIRO==1
  xax =floor(xctx->xorigin*xctx->mooz) + 0.5; yax = floor(xctx->yorigin*xctx->mooz) + 0.5;
  #else
  xax =xctx->xorigin*xctx->mooz; yax = xctx->yorigin*xctx->mooz;
  #endif
  if(yax > xctx->areay1 && yax < xctx->areay2) {
    if(xctx->draw_window) {
      #if DRAW_ALL_CAIRO==1
      cairo_move_to(xctx->cairo_ctx, xctx->areax1+1, yax);
      cairo_line_to(xctx->cairo_ctx, xctx->areax2-1, yax);
      #else
      if(axes) XDrawLine(display, xctx->window, xctx->gc[GRIDLAYER], xctx->areax1+1,
                 (int)yax, xctx->areax2-1, (int)yax);
      #endif
    }
    if(xctx->draw_pixmap) {
      #if DRAW_ALL_CAIRO==1
      cairo_move_to(xctx->cairo_save_ctx, xctx->areax1+1, yax);
      cairo_line_to(xctx->cairo_save_ctx, xctx->areax2-1, yax);
      #else
      if(axes) XDrawLine(display, xctx->save_pixmap, xctx->gc[GRIDLAYER], xctx->areax1+1, (int)yax,
                 xctx->areax2-1, (int)yax);
      #endif
    }
  }
  if(xax > xctx->areax1 && xax < xctx->areax2) {
    if(xctx->draw_window) {
      #if DRAW_ALL_CAIRO==1
      cairo_move_to(xctx->cairo_ctx, xax, xctx->areay1+1);
      cairo_line_to(xctx->cairo_ctx, xax, xctx->areay2-1);
      #else
      if(axes) XDrawLine(display, xctx->window, xctx->gc[GRIDLAYER], (int)xax, xctx->areay1+1,
                 (int)xax, xctx->areay2-1);
      #endif
    }
    if(xctx->draw_pixmap) {
      #if DRAW_ALL_CAIRO==1
      cairo_move_to(xctx->cairo_save_ctx, xax, xctx->areay1+1);
      cairo_line_to(xctx->cairo_save_ctx, xax, xctx->areay2-1);
      #else
      if(axes) XDrawLine(display, xctx->save_pixmap, xctx->gc[GRIDLAYER], (int)xax, xctx->areay1+1,
                 (int)xax, xctx->areay2-1);
      #endif
    }
  }
  /* ************************ /Draw axes ****************** */

  #if DRAW_ALL_CAIRO==0
  if(grid_point_size != -1) {
      XSetLineAttributes (display, xctx->gc[GRIDLAYER],
          grid_point_size, LineSolid, CapProjecting, LINEJOIN);
  } else if(!big_gr) {
    XSetLineAttributes (display, xctx->gc[GRIDLAYER],
        0, LineSolid, LINECAP, LINEJOIN);
  } else {
    XSetLineAttributes (display, xctx->gc[GRIDLAYER],
        XLINEWIDTH(xctx->lw), LineSolid, LINECAP, LINEJOIN);
  }
  #endif

  if(grid_point_size >= 0) big_gr = 1;

  tmp = floor((xctx->areay1+1)/delta)*delta-fmod(-xctx->yorigin*xctx->mooz, delta);
  for(x=floor((xctx->areax1+1)/delta)*delta-fmod(-xctx->xorigin*xctx->mooz, delta); x < xctx->areax2; x += delta) {
    xx = x;
    #if DRAW_ALL_CAIRO==1
    xx = floor(x) + 0.5;
    #endif
    if(axes && (int)xx == (int)xax) continue;
    for(y=tmp; y < xctx->areay2; y += delta) {
      yy = y;
      #if DRAW_ALL_CAIRO==1
      yy = floor(y) + 0.5;
      #endif
      if(axes && (int)yy == (int)yax) continue;
      #if DRAW_ALL_CAIRO==1
      if(xctx->draw_window) {
        cairo_move_to(xctx->cairo_ctx, xx, yy) ;
        cairo_close_path(xctx->cairo_ctx);
      }
      if(xctx->draw_pixmap) {
        cairo_move_to(xctx->cairo_save_ctx, xx, yy);
        cairo_close_path(xctx->cairo_save_ctx);
      }
      #else
      if(i>=CADMAXGRIDPOINTS) {
        if(xctx->draw_window) {
          if(big_gr) {
            XDrawSegments(display, xctx->window, xctx->gc[GRIDLAYER], xctx->biggridpoint, i);
          } else {
            XDrawPoints(display, xctx->window, xctx->gc[GRIDLAYER], xctx->gridpoint, i, CoordModeOrigin);
          }
        }
        if(xctx->draw_pixmap) {
          if(big_gr) {
            XDrawSegments(display, xctx->save_pixmap, xctx->gc[GRIDLAYER], xctx->biggridpoint, i);
          } else {
            XDrawPoints(display, xctx->save_pixmap, xctx->gc[GRIDLAYER], xctx->gridpoint, i, CoordModeOrigin);
          }
        }
        i=0;
      }
      if(big_gr) {
        xctx->biggridpoint[i].x1 = xctx->biggridpoint[i].x2 = (short)(x);
        xctx->biggridpoint[i].y1 =  xctx->biggridpoint[i].y2 = (short)(y);
        ++i;
      } else {
        xctx->gridpoint[i].x=(short)(x);
        xctx->gridpoint[i].y=(short)(y);
        ++i;
      }
      #endif
    }
  }
  #if DRAW_ALL_CAIRO==0
  if(xctx->draw_window) {
    if(big_gr) {
      XDrawSegments(display, xctx->window, xctx->gc[GRIDLAYER], xctx->biggridpoint, i);
    } else {
      XDrawPoints(display, xctx->window, xctx->gc[GRIDLAYER], xctx->gridpoint, i, CoordModeOrigin);
    }
  }
  if(xctx->draw_pixmap) {
    if(big_gr) {
      XDrawSegments(display, xctx->save_pixmap, xctx->gc[GRIDLAYER], xctx->biggridpoint, i);
    } else {
      XDrawPoints(display, xctx->save_pixmap, xctx->gc[GRIDLAYER], xctx->gridpoint, i, CoordModeOrigin);
    }
  }
  #endif

  #if DRAW_ALL_CAIRO==1
  if(xctx->draw_pixmap) cairo_stroke(xctx->cairo_save_ctx);
  if(xctx->draw_window) cairo_stroke(xctx->cairo_ctx);
  #endif

  #if DRAW_ALL_CAIRO==0
  XSetLineAttributes (display, xctx->gc[GRIDLAYER],
      XLINEWIDTH(xctx->lw), LineSolid, LINECAP, LINEJOIN);
  #endif

}

#if !defined(__unix__) && HAS_CAIRO==1
static void my_cairo_drawline(cairo_t *ct, int layer, double x1, double y1, double x2, double y2, int dash)
{
  cairo_set_source_rgb(ct,
    (double)xctx->xcolor_array[layer].red/65535.0,
    (double)xctx->xcolor_array[layer].green/65535.0,
    (double)xctx->xcolor_array[layer].blue/65535.0);
  if (dash) {
    double dashes[1];
    dashes[0] = dash;
    cairo_set_dash(ct, dashes, 1, 0);
  }
  cairo_move_to(ct, x1, y1);
  cairo_line_to(ct,x2, y2);
  cairo_stroke(ct); /* This lines need to be here */
}

static void my_cairo_drawpoints(cairo_t *ct, int layer, XPoint *points, int npoints)
{
  cairo_set_source_rgb(ct,
    (double)xctx->xcolor_array[layer].red/65535.0,
    (double)xctx->xcolor_array[layer].green/65535.0,
    (double)xctx->xcolor_array[layer].blue/65535.0);
  for (int i =0; i<npoints; ++i) {
    cairo_move_to(ct, points[i].x, points[i].y);
    cairo_rel_line_to(ct,1, 1);
    cairo_stroke(ct); /* This lines need to be here */
  }
}

static void check_cairo_drawline(void *cr, int layer, double x1, double y1, double x2, double y2, int dash)
{
  if (cr==NULL) return;
  cairo_t *ct = (cairo_t *)cr;
  my_cairo_drawline(cr, layer, x1, y1, x2, y2, dash);
}

static void check_cairo_drawpoints(void *cr, int layer, XPoint *points, int npoints)
{
  if (cr==NULL) return;
  cairo_t *ct = (cairo_t *)cr;
  my_cairo_drawpoints(cr, layer, points, npoints);
}
#endif


void draw_xhair_line(GC gc, int size, double linex1, double liney1, double linex2, double liney2)
{
  int big_gr = tclgetboolvar("big_grid_points");
  char dash_arr[2];
  double x1, y1, x2, y2;
  x1=/* X_TO_SCREEN */ (linex1);
  y1=/* Y_TO_SCREEN */ (liney1);
  x2=/* X_TO_SCREEN */ (linex2);
  y2=/* Y_TO_SCREEN */ (liney2);
  if( clip(&x1,&y1,&x2,&y2) )
  {
    dash_arr[0] = dash_arr[1] = (char) 3;
    XSetDashes(display, gc, 0, dash_arr, 1);
    if(!big_gr) {
      XSetLineAttributes (display, gc,
          0, size ? LineSolid : xDashType, xCap, xJoin);
    } else {
      XSetLineAttributes (display, gc,
          size ? 0 : XLINEWIDTH(xctx->lw), size ? LineSolid : xDashType, xCap, xJoin);
    }
    if(xctx->draw_window)
       XDrawLine(display, xctx->window, gc, (int)x1, (int)y1, (int)x2, (int)y2);
    if(xctx->draw_pixmap)
      XDrawLine(display, xctx->save_pixmap, gc, (int)x1, (int)y1, (int)x2, (int)y2);
    XSetLineAttributes (display, gc,
        XLINEWIDTH(xctx->lw), LineSolid, LINECAP, LINEJOIN);
  }
}

/* The historical drawline: an on-run and an off-run of the SAME length, i.e. a
 * 50% duty cycle. Kept as the name every one of its ~86 call sites uses, now a
 * one-line delegate. X11 treats a dash list {d} of length 1 and {d,d} of
 * length 2 identically (the pattern alternates on/off through the list and
 * repeats), so this is exactly equivalent to what it did before -- no call site
 * changes behaviour. */
void drawline(int c, int what, double linex1, double liney1, double linex2, double liney2,
              double bus, int dash, void *ct)
{
  drawline_duty(c, what, linex1, liney1, linex2, liney2, bus, dash, dash, ct);
}

/* drawline with an independent OFF run, so a caller can ask for a duty cycle
 * other than 50% -- e.g. the waveform graph grid's 1-on/3-off, which halves the
 * lit pixels without removing a single grid line (viewer plan item 2,
 * decision D-B).
 *
 * Split out as a wrapper + core rather than by adding a parameter to drawline
 * itself, and rather than by having a mutable global consulted inside the
 * primitive: drawline is the most shared drawing routine in the program, and a
 * global would be the same landmine class as the shared xctx->graph_struct --
 * it would leak onto every later line through any early return.
 *
 * dash_off <= 0 means "same as dash", the historical behaviour. */
void drawline_duty(int c, int what, double linex1, double liney1, double linex2, double liney2,
              double bus, int dash, int dash_off, void *ct)
{
  static int i = 0;
#ifndef __unix__
  int j = 0;
#endif
 static XSegment r[CADDRAWBUFFERSIZE];
 double x1,y1,x2,y2;
 register XSegment *rr;
 char dash_arr[2];
 int width;

 if(bus == -1.0) {
   what = THICK;
   width = INT_BUS_WIDTH(xctx->lw);
 } else if(bus > 0.0) {
   what = NOW;
   width = XLINEWIDTH(bus * xctx->mooz);
 } else {
   width = XLINEWIDTH(xctx->lw);
 }


 if(dash && what !=THICK) what = NOW;

 if(!has_x) return;
 rr=r;
 if(what & ADD)
 {
  if(i>=CADDRAWBUFFERSIZE)
  {
#ifdef __unix__
   if(xctx->draw_window) XDrawSegments(display, xctx->window, xctx->gc[c], rr,i);
   if(xctx->draw_pixmap)
     XDrawSegments(display, xctx->save_pixmap, xctx->gc[c], rr,i);
#else
    for (j = 0; j < i; ++j) {
      if (xctx->draw_window)
        XDrawLine(display, xctx->window, xctx->gc[c], rr[j].x1, rr[j].y1, rr[j].x2, rr[j].y2);
      if (xctx->draw_pixmap)
        XDrawLine(display, xctx->save_pixmap, xctx->gc[c], rr[j].x1, rr[j].y1, rr[j].x2, rr[j].y2);
    }
#endif
   i=0;
  }
  x1=X_TO_SCREEN(linex1);
  y1=Y_TO_SCREEN(liney1);
  x2=X_TO_SCREEN(linex2);
  y2=Y_TO_SCREEN(liney2);
  if( clip(&x1,&y1,&x2,&y2) )
  {
   rr[i].x1=(short)x1;
   rr[i].y1=(short)y1;
   rr[i].x2=(short)x2;
   rr[i].y2=(short)y2;
   ++i;
  }
 }
 else if(what & NOW)
 {
  x1=X_TO_SCREEN(linex1);
  y1=Y_TO_SCREEN(liney1);
  x2=X_TO_SCREEN(linex2);
  y2=Y_TO_SCREEN(liney2);
  if( clip(&x1,&y1,&x2,&y2) )
  {
   if(dash) {
     dash_arr[0] = (char)dash;
     dash_arr[1] = (char)(dash_off > 0 ? dash_off : dash);
     XSetDashes(display, xctx->gc[c], 0, dash_arr, 2);
     XSetLineAttributes (display, xctx->gc[c], width, xDashType, xCap, xJoin);
   } else if(bus > 0.0) {
     XSetLineAttributes (display, xctx->gc[c], width, LineSolid, CapProjecting, JoinMiter);
   } else if(bus == -1.0) {
     XSetLineAttributes (display, xctx->gc[c], width, LineSolid, LINECAP, LINEJOIN);
   }

   if(xctx->draw_window) XDrawLine(display, xctx->window, xctx->gc[c], (int)x1, (int)y1, (int)x2, (int)y2);
   if(xctx->draw_pixmap)
    XDrawLine(display, xctx->save_pixmap, xctx->gc[c], (int)x1, (int)y1, (int)x2, (int)y2);
   if(dash ||  bus > 0.0 || bus == -1.0) {
     XSetLineAttributes (display, xctx->gc[c], XLINEWIDTH(xctx->lw), LineSolid, LINECAP, LINEJOIN);
   }
  }
 }

 else if(what & THICK)
 {
  x1=X_TO_SCREEN(linex1);
  y1=Y_TO_SCREEN(liney1);
  x2=X_TO_SCREEN(linex2);
  y2=Y_TO_SCREEN(liney2);
  if( clip(&x1,&y1,&x2,&y2) )
  {
   if(dash) {
     dash_arr[0] = (char)dash;
     dash_arr[1] = (char)(dash_off > 0 ? dash_off : dash);
     XSetDashes(display, xctx->gc[c], 0, dash_arr, 2);
     XSetLineAttributes (display, xctx->gc[c], width, xDashType, xCap, xJoin);
   } else {
     XSetLineAttributes (display, xctx->gc[c], width, LineSolid, LINECAP, LINEJOIN);
   }
   if(xctx->draw_window) XDrawLine(display, xctx->window, xctx->gc[c], (int)x1, (int)y1, (int)x2, (int)y2);
   if(xctx->draw_pixmap) XDrawLine(display, xctx->save_pixmap, xctx->gc[c], (int)x1, (int)y1, (int)x2, (int)y2);
   XSetLineAttributes (display, xctx->gc[c], XLINEWIDTH(xctx->lw), LineSolid, LINECAP , LINEJOIN);
  }
 }
 else if((what & END) && i)
 {
#ifdef __unix__
  if(xctx->draw_window) XDrawSegments(display, xctx->window, xctx->gc[c], rr,i);
  if(xctx->draw_pixmap) XDrawSegments(display, xctx->save_pixmap, xctx->gc[c], rr,i);
#else
   for (j = 0; j < i; ++j) {
     if (xctx->draw_window)
       XDrawLine(display, xctx->window, xctx->gc[c], rr[j].x1, rr[j].y1, rr[j].x2, rr[j].y2);
     if (xctx->draw_pixmap)
       XDrawLine(display, xctx->save_pixmap, xctx->gc[c], rr[j].x1, rr[j].y1, rr[j].x2, rr[j].y2);
   }
#endif
  i=0;
 }
}

#if HAS_CAIRO==1
/* Set a cairo source from a net-hilight style's color. A layer-index style reads the RGB
 * already cached in xctx->xcolor_array (no XQueryColor server round-trip, and consistent
 * with the rest of the rendered net, which set_cairo_color() colors the same way). A
 * custom-RGB style (color_layer < 0) has no layer to read, so its pixel is queried through
 * the colormap ONCE and the RGB cached on the style (st->rgb_resolved); the cache is reset
 * whenever the style table is rebuilt (update_net_hilight_style re-resolves .color), so it
 * tracks colorscheme changes the same way .color does. fg is only a defensive fallback for
 * the (unreached) st==NULL case. */
static void hilight_cairo_set_source(cairo_t *ct, NetHilightStyle *st, unsigned int fg)
{
  unsigned short r, g, b;
  if(st && st->color_layer >= 0) {
    r = xctx->xcolor_array[st->color_layer].red;
    g = xctx->xcolor_array[st->color_layer].green;
    b = xctx->xcolor_array[st->color_layer].blue;
  } else if(st) {
    resolve_hilight_style_rgb(st);     /* resolve the custom pixel once, then reuse */
    r = st->cr; g = st->cg; b = st->cb;
  } else {
    XColor xc;
    xc.pixel = fg;
    XQueryColor(display, colormap, &xc);
    r = xc.red; g = xc.green; b = xc.blue;
  }
  cairo_set_source_rgb(ct, (double)r / 65535.0, (double)g / 65535.0, (double)b / 65535.0);
}

/* Pass 1.5 tilted-stripe rendering. Render a highlighted thick wire's dash pattern as
 * "stripes" sheared by st->angle (-45..45 deg; sign picks the tilt direction) instead of perpendicular dash bands (which
 * is all native XSetDashes can do). Works in a wire-local frame (translate to the start,
 * rotate so the wire lies along +x) and fills one parallelogram per dash "on" run with
 * its edges tilted by `half_width * tan(angle)`. Resolution-independent. x1,y1,x2,y2 are
 * device (screen) coords; width is the device line width in px. The dash walk starts a
 * whole number of pattern periods before the wire start so band positions match the
 * flat-dash path (toggling the angle does not shift the stripes), and extends `half` past
 * each endpoint to match the flat path's CapRound/CapProjecting overhang (else striped
 * wires would gap where the flat path has a cap). The redraw-bbox clip is already on the
 * cairo context (installed by set_clip_mask(), exactly as the flat path's gc_hilight
 * clip), so only the thick-wire rectangle is added here. Returns 1 if it rendered (caller
 * is done), 0 to fall back to the Xlib flat-dash path (thin wire, degenerate segment, or
 * no cairo context for an active target). */
static int draw_hilight_wire_striped(unsigned int fg, NetHilightStyle *st,
        double x1, double y1, double x2, double y2, int width, double dash_offset)
{
  double dx = x2 - x1, dy = y2 - y1;
  double len = sqrt(dx * dx + dy * dy);
  double half = width / 2.0;
  double ext = half;   /* cap overhang to match the flat path (CapRound/CapProjecting) */
  double theta, shear, period, cstart, pos, seg;
  int idx, on;
  cairo_t *targets[2];
  int nt = 0, t;

  /* a sub-2px wire can't show a meaningful tilt, and width 0 (change_lw off, zoomed out)
   * would make a zero-height clip that paints nothing; let the crisp Xlib flat-dash path
   * (which draws width 0 as a 1px line) handle these */
  if(width < 2) return 0;
  if(len < 1e-6) return 0;              /* degenerate point: flat path draws the cap square */
  /* fully off-screen reject (parity with the flat path's clip() viewport cull): cairo would
   * otherwise build a parallelogram run spanning huge off-screen coords for every redraw,
   * only to raster-clip it away. The wire bbox is its endpoints grown by the half-width +
   * cap overhang. */
  {
    double m = half + ext + 1.0;
    double bx1 = (x1 < x2 ? x1 : x2) - m, bx2 = (x1 > x2 ? x1 : x2) + m;
    double by1 = (y1 < y2 ? y1 : y2) - m, by2 = (y1 > y2 ? y1 : y2) + m;
    if(RECT_OUTSIDE(bx1, by1, bx2, by2,
                    xctx->areax1, xctx->areay1, xctx->areax2, xctx->areay2)) return 1;
  }
  /* gather the cairo context(s) for the active draw target(s); bail to the Xlib path
   * if a needed one is missing (e.g. cairo not yet (re)created) */
  if(xctx->draw_window) { if(!xctx->cairo_ctx)      return 0; targets[nt++] = xctx->cairo_ctx; }
  if(xctx->draw_pixmap) { if(!xctx->cairo_save_ctx) return 0; targets[nt++] = xctx->cairo_save_ctx; }
  if(nt == 0) return 1;                 /* no target: nothing to do, but handled */

  /* dash repeat period (odd-length patterns double — see net_hilight_dash_period). Shared with
   * the marching-offset math (net_hilight_march_offset) so the scroll phase stays aligned with
   * both the flat XSetDashes path and these stripes. */
  period = net_hilight_dash_period(st);
  if(period <= 0.0) return 0;          /* no "on" runs: let the flat path draw it */

  theta = atan2(dy, dx);
  shear = half * tan(st->angle * (XSCH_PI / 180.0));   /* |angle| <= 45 -> |shear| <= half; sign = tilt dir */
  /* start a whole number of periods before the wire start so a band begins at x=0 (phase
   * parity with XSetDashes), far enough back that the sheared back edge AND the cap
   * overhang at x=-ext are still covered regardless of the width/period ratio. Use |shear|
   * so the slack covers EITHER tilt direction (a negative angle leans the bands the other
   * way, reaching |shear| past the axis on the opposite side). The Pass-2b marching offset
   * (dash_offset, in [0,period)) then shifts the whole pattern along +x so the stripes
   * crawl; it is absorbed by the +period slack above, so x=-ext stays covered. */
  cstart = -ceil((ext + fabs(shear) + period) / period) * period + dash_offset;

  for(t = 0; t < nt; ++t) {
    cairo_t *ct = targets[t];
    cairo_save(ct);
    /* wire-local frame, then clip to the thick-wire rectangle (extended by ext at each
     * end for the cap overhang); cairo_clip() intersects with the ambient bbox clip */
    cairo_translate(ct, x1, y1);
    cairo_rotate(ct, theta);
    cairo_rectangle(ct, -ext, -half, len + 2.0 * ext, (double)width);
    cairo_clip(ct);
    hilight_cairo_set_source(ct, st, fg);
    pos = cstart; idx = 0; on = 1;
    while(pos < len + ext + fabs(shear) + 1.0) {   /* |shear|: cover the far end for either tilt */
      seg = (unsigned char)st->dash_arr[idx % st->dash_len];
      if(on) {
        /* parallelogram for the "on" run [pos, pos+seg], top/bottom edges sheared so the
         * band tilts: a band centered at axis position p crosses y at x = p + y*tan(angle) */
        cairo_move_to(ct, pos - shear,       -half);
        cairo_line_to(ct, pos + seg - shear, -half);
        cairo_line_to(ct, pos + seg + shear,  half);
        cairo_line_to(ct, pos + shear,        half);
        cairo_close_path(ct);
      }
      pos += seg;
      ++idx;
      on = !on;
    }
    cairo_fill(ct);
    cairo_restore(ct);
  }
  /* the buffered cairo fills are flushed to the surface(s) once by draw_hilight_net() after
   * its wire loop (before the Xlib instance highlights and the pixmap->window blit), not
   * per segment (a per-segment flush forces an X round-trip on every wire). */
  return 1;
}
#endif /* HAS_CAIRO==1 */

/* Draw one highlighted wire segment in the given X pixel color (resolved by the caller
 * via get_hilight_pixel(), which handles sim logic levels, layer-index styles and custom
 * RGB styles uniformly), with width and dash taken from the NetHilightStyle (st may be
 * NULL -> width 1, solid). Renders through the dedicated xctx->gc_hilight scratch GC
 * (layer GCs untouched), to both the window and the save pixmap (highlights are part of
 * the rendered schematic, so they must survive expose/blit). The style width multiplies
 * the bus-aware base width used by drawline(), so width 1 reproduces legacy widths;
 * cap/join also mirror drawline() (projecting/miter for bus-mult wires). gc_hilight is
 * given the bbox clip by set_clip_mask(). dash_len 0 = solid; else a full XSetDashes
 * pattern. A nonzero stripe angle (with a dash pattern) is rendered as tilted stripes via
 * cairo (draw_hilight_wire_striped); Xlib-only builds fall back to perpendicular dashes. */
void draw_hilight_wire(unsigned int fg, NetHilightStyle *st, double dash_offset,
                       double linex1, double liney1, double linex2, double liney2, double bus)
{
  double x1, y1, x2, y2;
  int width, base, mult, cap, join;
  GC gc = xctx->gc_hilight;

  if(!has_x) return;
  /* bus-aware base width, matching drawline() so width 1 == legacy highlight width */
  if(bus == -1.0) base = INT_BUS_WIDTH(xctx->lw);
  else if(bus > 0.0) base = XLINEWIDTH(bus * xctx->mooz);
  else base = XLINEWIDTH(xctx->lw);
  mult = (st && st->width >= 1) ? st->width : 1;
  width = base * mult;
  /* cap/join parity with drawline(): bus-mult (bus>0) wires use projecting/miter */
  cap  = (bus > 0.0) ? CapProjecting : LINECAP;
  join = (bus > 0.0) ? JoinMiter : LINEJOIN;

  x1 = X_TO_SCREEN(linex1); y1 = Y_TO_SCREEN(liney1);
  x2 = X_TO_SCREEN(linex2); y2 = Y_TO_SCREEN(liney2);

#if HAS_CAIRO==1
  /* nonzero stripe angle on a dashed style: render tilted stripes via cairo (native Xlib
   * dashes are perpendicular-only). Falls through to the flat dash path if cairo can't
   * handle this wire (thin/degenerate) or has no usable context for the active target. */
  if(st && st->angle != 0 && st->dash_len > 0) {   /* angle<0 tilts the other way (sign of tan) */
    if(draw_hilight_wire_striped(fg, st, x1, y1, x2, y2, width, dash_offset)) return;
  }
#endif

  XSetForeground(display, gc, fg);
  if(st && st->dash_len > 0) {
    /* dash_offset (Pass 2b marching ants): scroll phase in dash-length units; 0 on
     * ordinary/hardcopy draws (deterministic), nonzero only in an animation frame so the dashes
     * crawl. Two corrections vs feeding it raw:
     *  - DIRECTION: XSetDashes' phase advances the pattern toward the wire START (-x) as it
     *    grows -- the OPPOSITE of the cairo striped path (cstart += offset -> +x). Negate it
     *    (period - offset, reduced into [0,period)) so a march_fwd style scrolls the SAME
     *    visual direction at angle 0 and any nonzero angle. period = net_hilight_dash_period(st) (doubled
     *    for odd dash_len; the X server honors that doubled period -- verified by render).
     *  - PRECISION: the phase arg is an int, so the flat Xlib path steps in whole pixels (no
     *    sub-pixel glide like cairo); fine for marching ants, but slow scrolls advance coarsely.
     * X measures the phase from the first drawn point, i.e. the clip()-trimmed start below, so a
     * wire clipped at the viewport edge anchors its phase differently than the cairo path's
     * un-clipped x1 -- only visible on a partially off-screen wire, and the tick pauses during pan. */
    double period = net_hilight_dash_period(st);
    int phase = (period > 0.0) ? (int)fmod(period - dash_offset, period) : 0;
    XSetLineAttributes(display, gc, width, xDashType, cap, join);
    XSetDashes(display, gc, phase, st->dash_arr, st->dash_len);
  } else {
    XSetLineAttributes(display, gc, width, LineSolid, cap, join);
  }

  if( clip(&x1, &y1, &x2, &y2) ) {  /* clip() mutates x1..y2 to the on-screen segment */
    if(xctx->draw_window) XDrawLine(display, xctx->window, gc, (int)x1, (int)y1, (int)x2, (int)y2);
    if(xctx->draw_pixmap) XDrawLine(display, xctx->save_pixmap, gc, (int)x1, (int)y1, (int)x2, (int)y2);
  }
}

/* Filled junction dot for a highlighted wire, in the same resolved pixel as the wire
 * body (so body and dot never diverge), drawn through gc_hilight to window+pixmap. */
void draw_hilight_dot(unsigned int fg, double x, double y, double r)
{
  double xx1, yy1, xx2, yy2, cx1, cy1, cx2, cy2;
  GC gc = xctx->gc_hilight;
  if(!has_x) return;
  xx1 = X_TO_SCREEN(x - r); yy1 = Y_TO_SCREEN(y - r);
  xx2 = X_TO_SCREEN(x + r); yy2 = Y_TO_SCREEN(y + r);
  /* skip dots entirely outside the viewport, like filledarc() did: gc_hilight has no
   * clip mask during a full redraw, and huge off-screen coords wrap in XFillArc's
   * 16-bit fields (stray smear). */
  cx1 = xx1; cy1 = yy1; cx2 = xx2; cy2 = yy2;
  if(!rectclip(xctx->areax1, xctx->areay1, xctx->areax2, xctx->areay2, &cx1, &cy1, &cx2, &cy2)) return;
  XSetForeground(display, gc, fg);
  if(xctx->draw_window)
    XFillArc(display, xctx->window, gc, (int)xx1, (int)yy1,
             (int)(xx2 - xx1), (int)(yy2 - yy1), 0, 360 * 64);
  if(xctx->draw_pixmap)
    XFillArc(display, xctx->save_pixmap, gc, (int)xx1, (int)yy1,
             (int)(xx2 - xx1), (int)(yy2 - yy1), 0, 360 * 64);
}

void drawtempline(GC gc, int what, double linex1,double liney1,double linex2,double liney2)
{
  static int i = 0;
#ifndef __unix__
 int j = 0;
#endif
 static XSegment r[CADDRAWBUFFERSIZE];
 double x1,y1,x2,y2;

 if(!has_x) return;

 if((fix_broken_tiled_fill || !_unix) && gc == xctx->gctiled && what == ADD) what = NOW;
 if(what & ADD)
 {
  if(i>=CADDRAWBUFFERSIZE)
  {
#ifdef __unix__
   XDrawSegments(display, xctx->window, gc, r,i);
#else
    for (j = 0; j < i; ++j) {
        XDrawLine(display, xctx->window, gc, r[j].x1, r[j].y1, r[j].x2, r[j].y2);
    }
#endif
   i=0;
  }
  x1=X_TO_SCREEN(linex1);
  y1=Y_TO_SCREEN(liney1);
  x2=X_TO_SCREEN(linex2);
  y2=Y_TO_SCREEN(liney2);
  if( clip(&x1,&y1,&x2,&y2) )
  {
   r[i].x1=(short)x1;
   r[i].y1=(short)y1;
   r[i].x2=(short)x2;
   r[i].y2=(short)y2;
   ++i;
  }
 }
 else if(what & NOW)
 {
  x1=X_TO_SCREEN(linex1);
  y1=Y_TO_SCREEN(liney1);
  x2=X_TO_SCREEN(linex2);
  y2=Y_TO_SCREEN(liney2);
  if( clip(&x1,&y1,&x2,&y2) )
  {
   if((fix_broken_tiled_fill || !_unix) && gc == xctx->gctiled) {
     RECTORDER(linex1, liney1, linex2, liney2);
     MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
         linex1, liney1, linex2, liney2, linex1, liney1, xctx->lw);
   } else {
     XDrawLine(display, xctx->window, gc, (int)x1, (int)y1, (int)x2, (int)y2);
   }
  }
 }
 else if(what & THICK)
 {
  x1=X_TO_SCREEN(linex1);
  y1=Y_TO_SCREEN(liney1);
  x2=X_TO_SCREEN(linex2);
  y2=Y_TO_SCREEN(liney2);
  if( clip(&x1,&y1,&x2,&y2) )
  {
   if((fix_broken_tiled_fill || !_unix) && gc == xctx->gctiled) {
     RECTORDER(linex1, liney1, linex2, liney2);
     MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
         linex1, liney1, linex2, liney2, linex1, liney1, BUS_WIDTH * xctx->lw);
   } else {
     XSetLineAttributes (display, gc, INT_BUS_WIDTH(xctx->lw), LineSolid, LINECAP , LINEJOIN);
     XDrawLine(display, xctx->window, gc, (int)x1, (int)y1, (int)x2, (int)y2);
     XSetLineAttributes (display, gc, XLINEWIDTH(xctx->lw), LineSolid, LINECAP , LINEJOIN);
   }
  }
 }

 else if((what & END) && i)
 {
#ifdef __unix__
  XDrawSegments(display, xctx->window, gc, r,i);
#else
   for (j = 0; j < i; ++j) {
     XDrawLine(display, xctx->window, gc, r[j].x1, r[j].y1, r[j].x2, r[j].y2);
   }
#endif
  i=0;
 }
}

void drawtemp_manhattanline(GC gc, int what, double x1, double y1, double x2, double y2, int force_manhattan)
{
  double nl_xx1, nl_yy1, nl_xx2, nl_yy2;
  int saved_manhattan_lines = xctx->manhattan_lines;
  /* force_manhattan recomputes xctx->manhattan_lines from THIS line's own endpoints so it
   * can be stroked as an L. But manhattan_lines is global gesture state owned by the
   * wire/line currently being drawn (set in redraw_w_a_l_r_p_z_rubbers) or by the wire
   * placement (place_moved_wire) -- both of which recompute it themselves before use. So
   * drawing here must NOT leak its recomputed value: when a wire is selected and
   * orthogonal_wiring is on, the selection overlay is repainted (draw_selection ->
   * force_manhattan) under the in-progress rubber band on every motion, which otherwise
   * overwrites the active wire's direction with the selected wire's orientation. A
   * perpendicular new wire then collapses to zero length on the completing click and is
   * silently discarded -- the wire cannot be completed (issue 0018). Restore it below. */
  if(tclgetboolvar("orthogonal_wiring") && force_manhattan) {
    recompute_orthogonal_manhattanline(x1, y1, x2, y2);
  }
  if(xctx->manhattan_lines & 1) {
    nl_xx1 = x1; nl_yy1 = y1;
    nl_xx2 = x2; nl_yy2 = y2;
    ORDER(nl_xx1,nl_yy1,nl_xx2,nl_yy1);
    drawtempline(gc, what, nl_xx1,nl_yy1,nl_xx2,nl_yy1);
    nl_xx1 = x1; nl_yy1 = y1;
    nl_xx2 = x2; nl_yy2 = y2;
    ORDER(nl_xx2,nl_yy1,nl_xx2,nl_yy2);
    drawtempline(gc, what, nl_xx2,nl_yy1,nl_xx2,nl_yy2);
  } else if(xctx->manhattan_lines & 2) {
    nl_xx1 = x1; nl_yy1 = y1;
    nl_xx2 = x2; nl_yy2 = y2;
    ORDER(nl_xx1,nl_yy1,nl_xx1,nl_yy2);
    drawtempline(gc, what, nl_xx1,nl_yy1,nl_xx1,nl_yy2);
    nl_xx1 = x1; nl_yy1 = y1;
    nl_xx2 = x2; nl_yy2 = y2;
    ORDER(nl_xx1,nl_yy2,nl_xx2,nl_yy2);
    drawtempline(gc, what, nl_xx1,nl_yy2,nl_xx2,nl_yy2);
  } else {
    nl_xx1 = x1; nl_yy1 = y1;
    nl_xx2 = x2; nl_yy2 = y2;
    ORDER(nl_xx1,nl_yy1,nl_xx2,nl_yy2);
    drawtempline(gc, what, nl_xx1,nl_yy1,nl_xx2,nl_yy2);
  }
  if(force_manhattan) xctx->manhattan_lines = saved_manhattan_lines;
}

void drawtemparc(GC gc, int what, double x, double y, double r, double a, double b)
{
 static int i=0;
 static XArc xarc[CADDRAWBUFFERSIZE];
 double x1, y1, x2, y2; /* arc bbox */
 double xx1, yy1, xx2, yy2; /* complete circle bbox in screen coords */

 if(!has_x) return;
 if((fix_broken_tiled_fill || !_unix) && gc == xctx->gctiled && what == ADD) what = NOW;
 if(what & ADD)
 {
  if(i>=CADDRAWBUFFERSIZE)
  {
   XDrawArcs(display, xctx->window, gc, xarc,i);
   i=0;
  }
  xx1=X_TO_SCREEN(x-r);
  yy1=Y_TO_SCREEN(y-r);
  xx2=X_TO_SCREEN(x+r);
  yy2=Y_TO_SCREEN(y+r);
  arc_bbox(x, y, r, a, b, &x1,&y1,&x2,&y2);
  x1=X_TO_SCREEN(x1);
  y1=Y_TO_SCREEN(y1);
  x2=X_TO_SCREEN(x2);
  y2=Y_TO_SCREEN(y2);
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
   xarc[i].x=(short)xx1;
   xarc[i].y=(short)yy1;
   xarc[i].width= (unsigned short)(xx2 - xx1);
   xarc[i].height=(unsigned short)(yy2 - yy1);
   xarc[i].angle1 = (short)(a*64);
   xarc[i].angle2 = (short)(b*64);
   ++i;
  }
 }
 else if(what & NOW)
 {
  double sx1, sy1, sx2, sy2;
  xx1=X_TO_SCREEN(x-r);
  yy1=Y_TO_SCREEN(y-r);
  xx2=X_TO_SCREEN(x+r);
  yy2=Y_TO_SCREEN(y+r);
  arc_bbox(x, y, r, a, b, &x1,&y1,&x2,&y2);
  sx1=X_TO_SCREEN(x1);
  sy1=Y_TO_SCREEN(y1);
  sx2=X_TO_SCREEN(x2);
  sy2=Y_TO_SCREEN(y2);
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&sx1,&sy1,&sx2,&sy2) )
  {
    if((fix_broken_tiled_fill || !_unix) && gc == xctx->gctiled) {
      MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
          x1, y1, x2, y2, x1, y1, xctx->lw);
    } else {
      XDrawArc(display, xctx->window, gc, (int)xx1, (int)yy1, (int)(xx2-xx1), (int)(yy2-yy1),
               (int)(a*64), (int)(b*64));
    }
  }
 }
 else if((what & END) && i)
 {
  XDrawArcs(display, xctx->window, gc, xarc,i);
  i=0;
 }
}

/* x1,y1: start; x2,y2: end; x3,y3: way point */
void arc_3_points(double x1, double y1, double x2, double y2, double x3, double y3,
         double *x, double *y, double *r, double *a, double *b)
{
  double A, B, C;
  double c, s;

  /* s = signed_area, if > 0 : clockwise in xorg coordinate space */
  s = x3*y2-x2*y3 + x2*y1 -x1*y2 + x1*y3-x3*y1;
  A = x1*(y2-y3) - y1*(x2-x3) + x2*y3 - x3*y2;
  B = (x1*x1+y1*y1)*(y3-y2)+(x2*x2+y2*y2)*(y1-y3) + (x3*x3+y3*y3)*(y2-y1);
  C = (x1*x1+y1*y1)*(x2-x3)+(x2*x2+y2*y2)*(x3-x1) + (x3*x3+y3*y3)*(x1-x2);
  /* printf("s=%g\n", s); */
  *x = -B/2./A;
  *y = -C/2./A;
  *r = sqrt( (*x-x1)*(*x-x1) + (*y-y1)*(*y-y1) );
  *a = fmod(atan2(*y-y1 ,x1-*x )*180./XSCH_PI, 360.);
  if(*a<0.) *a+=360.;
  *b = fmod(atan2(*y-y2 ,x2-*x )*180./XSCH_PI, 360.);
  if(*b<0.) *b+=360.;
  if(s<0.) {  /* counter clockwise, P1, P3, P2 */
    *b = fmod(*b-*a, 360.);
    if(*b<0) *b+=360.;
    if(*b==0) *b=360.;
  } else if(s>0.) { /* clockwise, P2, P3, P1 */
    c = fmod(*a-*b, 360.);
    if(c<0) c+=360.;
    if(*b==0) *b=360.;
    *a = *b;
    *b = c;
  } else {
    *r = -1.0; /* no circle thru aligned points */
  }
}

void filledarc(int c, int what, double x, double y, double r, double a, double b)
{
 static int i=0;
 static XArc xarc[CADDRAWBUFFERSIZE];
 double x1, y1, x2, y2; /* arc bbox */
 double xx1, yy1, xx2, yy2; /* complete circle bbox in screen coords */

 if(!has_x) return;
 if(what & ADD)
 {
  if(i>=CADDRAWBUFFERSIZE)
  {
   if(xctx->draw_window) XFillArcs(display, xctx->window, xctx->gc[c], xarc,i);
   if(xctx->draw_pixmap) XFillArcs(display, xctx->save_pixmap, xctx->gc[c], xarc,i);
   i=0;
  }
  xx1=X_TO_SCREEN(x-r);
  yy1=Y_TO_SCREEN(y-r);
  xx2=X_TO_SCREEN(x+r);
  yy2=Y_TO_SCREEN(y+r);
  arc_bbox(x, y, r, a, b, &x1,&y1,&x2,&y2);
  x1=X_TO_SCREEN(x1);
  y1=Y_TO_SCREEN(y1);
  x2=X_TO_SCREEN(x2);
  y2=Y_TO_SCREEN(y2);
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
   xarc[i].x=(short)xx1;
   xarc[i].y=(short)yy1;
   xarc[i].width =(unsigned short)(xx2 - xx1);
   xarc[i].height=(unsigned short)(yy2 - yy1);
   xarc[i].angle1 = (short)(a*64);
   xarc[i].angle2 = (short)(b*64);
   ++i;
  }
 }
 else if(what & NOW)
 {
  xx1=X_TO_SCREEN(x-r);
  yy1=Y_TO_SCREEN(y-r);
  xx2=X_TO_SCREEN(x+r);
  yy2=Y_TO_SCREEN(y+r);
  arc_bbox(x, y, r, a, b, &x1,&y1,&x2,&y2);
  x1=X_TO_SCREEN(x1);
  y1=Y_TO_SCREEN(y1);
  x2=X_TO_SCREEN(x2);
  y2=Y_TO_SCREEN(y2);
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
   if(xctx->draw_window) XFillArc(display, xctx->window, xctx->gc[c], (int)xx1, (int)yy1,
                           (int)(xx2-xx1), (int)(yy2-yy1), (int)(a*64), (int)(b*64));
   if(xctx->draw_pixmap) XFillArc(display, xctx->save_pixmap, xctx->gc[c], (int)xx1, (int)yy1,
                            (int)(xx2-xx1), (int)(yy2-yy1), (int)(a*64), (int)(b*64));
  }
 }
 else if((what & END) && i)
 {
  if(xctx->draw_window) XFillArcs(display, xctx->window, xctx->gc[c], xarc,i);
  if(xctx->draw_pixmap) XFillArcs(display, xctx->save_pixmap, xctx->gc[c], xarc,i);
  i=0;
 }
}

void drawarc(int c, int what, double x, double y, double r, double a, double b, int arc_fill, double bus, int dash)
{
 static int i=0;
 static XArc xarc[CADDRAWBUFFERSIZE];
 double x1, y1, x2, y2; /* arc bbox */
 double xx1, yy1, xx2, yy2; /* complete circle bbox in screen coords */
 GC gc;
 int width;

 if(bus == -1.0) {
   what = NOW;
   width = INT_BUS_WIDTH(xctx->lw);
 } else if(bus > 0.0) {
   what = NOW;
   width = XLINEWIDTH(bus * xctx->mooz);
 } else {
   width = XLINEWIDTH(xctx->lw);
 }

 if(arc_fill || dash) what = NOW;

 if(!has_x) return;
 if(what & ADD)
 {
  if(i>=CADDRAWBUFFERSIZE)
  {
   if(xctx->draw_window) XDrawArcs(display, xctx->window, xctx->gc[c], xarc,i);
   if(xctx->draw_pixmap) XDrawArcs(display, xctx->save_pixmap, xctx->gc[c], xarc,i);
   i=0;
  }
  xx1=X_TO_SCREEN(x-r);
  yy1=Y_TO_SCREEN(y-r);
  xx2=X_TO_SCREEN(x+r);
  yy2=Y_TO_SCREEN(y+r);
  arc_bbox(x, y, r, a, b, &x1,&y1,&x2,&y2);
  x1=X_TO_SCREEN(x1);
  y1=Y_TO_SCREEN(y1);
  x2=X_TO_SCREEN(x2);
  y2=Y_TO_SCREEN(y2);
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
   xarc[i].x=(short)xx1;
   xarc[i].y=(short)yy1;
   xarc[i].width =(unsigned short)(xx2 - xx1);
   xarc[i].height=(unsigned short)(yy2 - yy1);
   xarc[i].angle1 = (short)(a*64);
   xarc[i].angle2 = (short)(b*64);
   ++i;
  }
 }
 else if(what & NOW)
 {
  xx1=X_TO_SCREEN(x-r);
  yy1=Y_TO_SCREEN(y-r);
  xx2=X_TO_SCREEN(x+r);
  yy2=Y_TO_SCREEN(y+r);
  if(arc_fill)
    arc_bbox(x, y, r, 0, 360, &x1,&y1,&x2,&y2);
  else
    arc_bbox(x, y, r, a, b, &x1,&y1,&x2,&y2);
  x1=X_TO_SCREEN(x1);
  y1=Y_TO_SCREEN(y1);
  x2=X_TO_SCREEN(x2);
  y2=Y_TO_SCREEN(y2);
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {

    if(dash) {
      char dash_arr[2];
      dash_arr[0] = dash_arr[1] = (char)dash;
      XSetDashes(display, xctx->gc[c], 0, dash_arr, 1);
      XSetLineAttributes (display, xctx->gc[c], width, xDashType, xCap, xJoin);
    } else if(bus > 0.0) {
      XSetLineAttributes (display, xctx->gc[c], width, LineSolid, CapProjecting, JoinMiter);
    } else if(bus == -1.0) {
      XSetLineAttributes (display, xctx->gc[c], width, LineSolid, LINECAP, LINEJOIN);
    }

   if(xctx->draw_window) {
     XDrawArc(display, xctx->window, xctx->gc[c], (int)xx1, (int)yy1,
              (int)(xx2-xx1), (int)(yy2-yy1), (int)(a*64), (int)(b*64));
   }
   if(xctx->draw_pixmap) {
     XDrawArc(display, xctx->save_pixmap, xctx->gc[c], (int)xx1, (int)yy1,
              (int)(xx2-xx1), (int)(yy2-yy1), (int)(a*64), (int)(b*64));
   }

   if(xctx->fill_pattern && (xctx->fill_type[c] || arc_fill == 2) ){

     if(arc_fill == 2) gc = xctx->gc[c];
     else             gc = xctx->gcstipple[c];
     if(arc_fill) {
       if(xctx->draw_window)
         XFillArc(display, xctx->window, gc, (int)xx1, (int)yy1,
              (int)(xx2-xx1), (int)(yy2-yy1), (int)(a*64), (int)(b*64));
       if(xctx->draw_pixmap)
         XFillArc(display, xctx->save_pixmap, gc, (int)xx1, (int)yy1,
              (int)(xx2-xx1), (int)(yy2-yy1), (int)(a*64), (int)(b*64));
     }
   }
   if(dash || bus > 0.0 || bus == -1.0) {
     XSetLineAttributes (display, xctx->gc[c], XLINEWIDTH(xctx->lw), LineSolid, LINECAP, LINEJOIN);
   }

  }
 }
 else if((what & END) && i)
 {
  if(xctx->draw_window) XDrawArcs(display, xctx->window, xctx->gc[c], xarc,i);
  if(xctx->draw_pixmap) XDrawArcs(display, xctx->save_pixmap, xctx->gc[c], xarc,i);
  i=0;
 }
}

void filledrect(int c, int what, double rectx1,double recty1,double rectx2,double recty2, int fill,
                int e_a, int e_b)
{
 static int iif = 0, iis = 0;
 int *i;
 static XRectangle rf[CADDRAWBUFFERSIZE]; /* full fill */
 static XRectangle rs[CADDRAWBUFFERSIZE]; /* stippled fill */
 XRectangle *r;
 double x1,y1,x2,y2;
 double xx1,yy1,xx2,yy2;
 GC gc;

 if(!has_x) return;
 if(!xctx->fill_pattern) return;
 if(fill != 2 && !xctx->fill_type[c]) return;
 if(fill == 2) { /* full fill */
   gc = xctx->gc[c];
   r = rf;
   i = &iif;
 } else { /* stippled fill */
   gc = xctx->gcstipple[c];
   r = rs;
   i = &iis;
 }
 if(e_a != -1) what = NOW;
 if(what & NOW)
 {
  xx1 = x1 = X_TO_SCREEN(rectx1);
  yy1 = y1 = Y_TO_SCREEN(recty1);
  xx2 = x2 = X_TO_SCREEN(rectx2);
  yy2 = y2 = Y_TO_SCREEN(recty2);
  if(!xctx->only_probes && (x2-x1)< 3.0 && (y2-y1)< 3.0) return;
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
   if(xctx->draw_window) {
     if(e_a != -1) {
       XFillArc(display, xctx->window, gc, (int)xx1, (int)yy1,
       (unsigned int)xx2 - (unsigned int)xx1,
       (unsigned int)yy2 - (unsigned int)yy1, e_a * 64, e_b * 64);
     } else {
       XFillRectangle(display, xctx->window, gc, (int)x1, (int)y1,
       (unsigned int)x2 - (unsigned int)x1,
       (unsigned int)y2 - (unsigned int)y1);
     }
   }
   if(xctx->draw_pixmap) {
     if(e_a != -1) {
       XFillArc(display, xctx->save_pixmap, gc, (int)xx1, (int)yy1,
       (unsigned int)xx2 - (unsigned int)xx1,
       (unsigned int)yy2 - (unsigned int)yy1, e_a * 64, e_b * 64);
     } else {
       XFillRectangle(display, xctx->save_pixmap, gc,  (int)x1, (int)y1,
       (unsigned int)x2 - (unsigned int)x1,
       (unsigned int)y2 - (unsigned int)y1);
     }
   }
  }
 }
 else if(what & ADD)
 {
  if(*i >= CADDRAWBUFFERSIZE)
  {
   if(xctx->draw_window) XFillRectangles(display, xctx->window, gc, r, *i);
   if(xctx->draw_pixmap)
     XFillRectangles(display, xctx->save_pixmap, gc, r, *i);
   *i=0;
  }
  x1=X_TO_SCREEN(rectx1);
  y1=Y_TO_SCREEN(recty1);
  x2=X_TO_SCREEN(rectx2);
  y2=Y_TO_SCREEN(recty2);
  if(!xctx->only_probes && (x2-x1)< 3.0 && (y2-y1)< 3.0) return;
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
   r[*i].x=(short)x1;
   r[*i].y=(short)y1;
   r[*i].width=(unsigned short)(x2-r[*i].x);
   r[*i].height=(unsigned short)(y2-r[*i].y);
   ++(*i);
  }
 }
 else if(what & END)
 {
  if(iis) {
    if(xctx->draw_window) XFillRectangles(display, xctx->window, xctx->gcstipple[c], rs, iis);
    if(xctx->draw_pixmap) XFillRectangles(display, xctx->save_pixmap, xctx->gcstipple[c], rs ,iis);
    iis = 0;
  }
  if(iif) {
    if(xctx->draw_window) XFillRectangles(display, xctx->window, xctx->gc[c], rf ,iif);
    if(xctx->draw_pixmap) XFillRectangles(display, xctx->save_pixmap, xctx->gc[c], rf ,iif);
    iif = 0;
  }

 }
}

void polygon_bbox(double *x, double *y, int points, double *bx1, double *by1, double *bx2, double *by2)
{
  int j;
  for(j=0; j<points; ++j) {
    if(j==0 || x[j] < *bx1) *bx1 = x[j];
    if(j==0 || x[j] > *bx2) *bx2 = x[j];
    if(j==0 || y[j] < *by1) *by1 = y[j];
    if(j==0 || y[j] > *by2) *by2 = y[j];
  }
}

void arc_bbox(double x, double y, double r, double a, double b,
              double *bx1, double *by1, double *bx2, double *by2)
{
  double x2, y2, x3, y3;
  int aa, bb, i;

  if(b==360.) {
    *bx1 = x-r;
    *by1 = y-r;
    *bx2 = x+r;
    *by2 = y+r;
    return;
  }
  if(b < 0.) {
    double aaa = a;
    a = aaa + b;
    b = -b;
  }
  a = fmod(a, 360.);
  if(a<0) a+=360.;
  aa = (int)(ceil(a/90.))*90;
  bb = (int)(floor((a+b)/90.))*90;


  /* printf("arc_bbox(): aa=%d bb=%d\n", aa, bb); */
  x2 = x + r * cos(a * XSCH_PI/180.);
  y2 = y - r * sin(a * XSCH_PI/180.);
  x3 = x + r * cos((a+b) * XSCH_PI/180.);
  y3 = y - r * sin((a+b) * XSCH_PI/180.);

  /* *bx1  = (x2 < x  ) ? x2 : x; */
  *bx1 = x2;
  if(x3 < *bx1) *bx1 = x3;
  /* *bx2  = (x2 > x  ) ? x2 : x; */
  *bx2 = x2;
  if(x3 > *bx2) *bx2 = x3;
  /* *by1  = (y2 < y  ) ? y2 : y; */
  *by1  = y2;
  if(y3 < *by1) *by1 = y3;
  /* *by2  = (y2 > y  ) ? y2 : y; */
  *by2  = y2;
  if(y3 > *by2) *by2 = y3;

  for(i=aa; i<=bb; ++i) {
    if(i%360==0) {
      *bx2 = x + r;
    }
    if(i%360==90) {
      *by1 = y - r;
    }
    if(i%360==180) {
      *bx1 = x - r;
    }
    if(i%360==270) {
      *by2 = y + r;
    }
  }
}

/* Convex Nonconvex Complex */
#define Polygontype Nonconvex

/* fill = 1: stippled fill, fill == 2: solid fill */
void drawbezier(Drawable w, GC gc, int c, double *x, double *y, int points, int fill)
{
  const double bez_steps = 1.0/32.0; /* divide the t = [0,1] interval into 32 steps */
  static int psize = 1024;
  static XPoint *p = NULL;
  int b, i;
  double t;
  double xp, yp;

  double x0, x1, x2, y0, y1, y2;

  if(points == 0 && x == NULL && y == NULL) { /* cleanup */
    my_free(_ALLOC_ID_, &p);
    return;
  }
  if(!p) p = my_malloc(_ALLOC_ID_, psize * sizeof(XPoint));
  i = 0;
  for(b = 0; b < points - 2; b++) {
    if(points == 3) { /* 3 points: only one bezier */
      x0 = x[0];
      y0 = y[0];
      x1 = x[1];
      y1 = y[1];
      x2 = x[2];
      y2 = y[2];
    } else if(b == points - 3) { /* last bezier */
      x0 = (x[points - 3] + x[points - 2]) / 2.0;
      y0 = (y[points - 3] + y[points - 2]) / 2.0;
      x1 =  x[points - 2];
      y1 =  y[points - 2];
      x2 =  x[points - 1];
      y2 =  y[points - 1];
    } else if(b == 0) { /* first bezier */
      x0 =  x[0];
      y0 =  y[0];
      x1 =  x[1];
      y1 =  y[1];
      x2 = (x[1] + x[2]) / 2.0;
      y2 = (y[1] + y[2]) / 2.0;
    } else { /* beziers in the middle */
      x0 = (x[b] + x[b + 1]) / 2.0;
      y0 = (y[b] + y[b + 1]) / 2.0;
      x1 =  x[b + 1];
      y1 =  y[b + 1];
      x2 = (x[b + 1] + x[b + 2]) / 2.0;
      y2 = (y[b + 1] + y[b + 2]) / 2.0;
    }
    for(t = 0; t <= 1.0; t += bez_steps) {
      xp = (1 - t) * (1 - t) * x0 + 2 * (1 - t) * t * x1 + t * t * x2;
      yp = (1 - t) * (1 - t) * y0 + 2 * (1 - t) * t * y1 + t * t * y2;
      if(i >= psize) {
        psize *= 2;
        my_realloc(_ALLOC_ID_, &p, psize * sizeof(XPoint));
      }
      p[i].x = (short)X_TO_SCREEN(xp);
      p[i].y = (short)Y_TO_SCREEN(yp);
      /* dbg(0, "i=%d, p[i].x=%d, p[i].y=%d\n", i, p[i].x, p[i].y); */
      i++;
    }
  }
  XDrawLines(display, w, gc, p, i, CoordModeOrigin);
  if(fill == 1)
    XFillPolygon(display, w, xctx->gcstipple[c], p, i, Polygontype, CoordModeOrigin);
  else if(fill==2)
    XFillPolygon(display, w, xctx->gc[c], p, i, Polygontype, CoordModeOrigin);
}

/* Unused 'what' parameter used in spice data draw_graph()
 * to avoid unnecessary clipping (what = 0) */
void drawpolygon(int c, int what, double *x, double *y, int points, int poly_fill, int dash, double bus, int flags)
{
  double x1,y1,x2,y2;
  int fill, bezier;
  XPoint *p;
  int i;
  int width = 0;
  short sx, sy;
  GC gc;
  if(!has_x) return;
  if(bus == -1.0) what = THICK;

  if(bus == -1.0) {
    width = INT_BUS_WIDTH(xctx->lw);
  } else if(bus > 0.0) {
    width = XLINEWIDTH(bus * xctx->mooz);
  } else {
    width = XLINEWIDTH(xctx->lw);
  }

  polygon_bbox(x, y, points, &x1,&y1,&x2,&y2);
  x1=X_TO_SCREEN(x1);
  x2=X_TO_SCREEN(x2);
  y1=Y_TO_SCREEN(y1);
  y2=Y_TO_SCREEN(y2);
  if( !rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) ) {
    return;
  }
  if(!xctx->only_probes && (x2-x1)<1.0 && (y2-y1)<1.0) return;
  p = my_malloc(_ALLOC_ID_, sizeof(XPoint) * points);
  if(what) {
    for(i=0;i<points; ++i) {
      clip_xy_to_short(X_TO_SCREEN(x[i]), Y_TO_SCREEN(y[i]), &sx, &sy);
      p[i].x = sx;
      p[i].y = sy;
    }
  } else {
      /* preserve cache locality working on contiguous data */
      for(i=0;i<points; ++i) p[i].x = (short)X_TO_SCREEN(x[i]);
      for(i=0;i<points; ++i) p[i].y = (short)Y_TO_SCREEN(y[i]);
  }
  fill = xctx->fill_pattern && ((xctx->fill_type[c] && poly_fill == 1) || poly_fill == 2 ) &&
         (x[0] == x[points-1]) && (y[0] == y[points-1]);
  bezier = (flags & 1)  && (points > 2);

  if(dash) {
    char dash_arr[2];
    dash_arr[0] = dash_arr[1] = (char)dash;
    XSetDashes(display, xctx->gc[c], 0, dash_arr, 1);
    XSetLineAttributes (display, xctx->gc[c], width, xDashType, xCap, xJoin);
  } else if(bus > 0.0) {
    XSetLineAttributes (display, xctx->gc[c], width, LineSolid, CapProjecting, JoinMiter);
  } else if(bus == -1.0) {
    XSetLineAttributes (display, xctx->gc[c], width, LineSolid, LINECAP, LINEJOIN);
  }

  if(xctx->draw_window) {
    if(bezier) {
      drawbezier(xctx->window, xctx->gc[c], c, x, y, points, fill ? poly_fill : 0 );
    } else {
      XDrawLines(display, xctx->window, xctx->gc[c], p, points, CoordModeOrigin);
    }
  }
  if(xctx->draw_pixmap) {
    if(bezier) {
      drawbezier(xctx->save_pixmap, xctx->gc[c], c, x, y, points, fill ? poly_fill : 0);
    } else {
      XDrawLines(display, xctx->save_pixmap, xctx->gc[c], p, points, CoordModeOrigin);
    }
  }
  if(poly_fill == 2) gc = xctx->gc[c];
  else              gc = xctx->gcstipple[c];
  if(fill && !bezier) {
    if(xctx->draw_window)
       XFillPolygon(display, xctx->window, gc, p, points, Polygontype, CoordModeOrigin);
    if(xctx->draw_pixmap)
       XFillPolygon(display, xctx->save_pixmap, gc, p, points, Polygontype, CoordModeOrigin);
  }
  if(dash || bus > 0.0 || bus == -1.0) {
    XSetLineAttributes (display, xctx->gc[c], XLINEWIDTH(xctx->lw), LineSolid, LINECAP, LINEJOIN);
  }
  my_free(_ALLOC_ID_, &p);
}

/* flags: bit 0: bezier
 *        bit 1: draw control point circles */
void drawtemppolygon(GC gc, int what, double *x, double *y, int points, int flags)
{
  double x1,y1,x2,y2;
  double sx1,sy1,sx2,sy2;
  XPoint *p;
  int i;
  short sx, sy;
  int bezier, drawpoints;
  if(!has_x) return;
  polygon_bbox(x, y, points, &x1,&y1,&x2,&y2);
  sx1=X_TO_SCREEN(x1);
  sy1=Y_TO_SCREEN(y1);
  sx2=X_TO_SCREEN(x2);
  sy2=Y_TO_SCREEN(y2);
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&sx1,&sy1,&sx2,&sy2) ) {

    bezier = (flags & 1) && (points > 2);
    drawpoints = (flags & 2);
    if((fix_broken_tiled_fill || !_unix) && gc == xctx->gctiled) {
      MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
          x1 - xctx->cadhalfdotsize, y1 - xctx->cadhalfdotsize,
          x2 + xctx->cadhalfdotsize, y2 + xctx->cadhalfdotsize,
          x1 - xctx->cadhalfdotsize, y1 - xctx->cadhalfdotsize, xctx->lw);
    } else {
      if(drawpoints && (gc == xctx->gc[SELLAYER] || gc == xctx->gctiled) ) for(i = 0; i < points; i++) {
        if( POINTINSIDE(X_TO_SCREEN(x[i]), Y_TO_SCREEN(y[i]), xctx->areax1, xctx->areay1,
               xctx->areax2, xctx->areay2)) {
          drawtemparc(gc, NOW, x[i], y[i], xctx->cadhalfdotsize, 0., 360.);
        }
      }
      if(bezier) {
        drawbezier(xctx->window, gc, 0, x, y, points, 0);
      } else {
        p = my_malloc(_ALLOC_ID_, sizeof(XPoint) * points);
        for(i=0;i<points; ++i) {
          clip_xy_to_short(X_TO_SCREEN(x[i]), Y_TO_SCREEN(y[i]), &sx, &sy);
          p[i].x = sx;
          p[i].y = sy;
        }
        XDrawLines(display, xctx->window, gc, p, points, CoordModeOrigin);
        my_free(_ALLOC_ID_, &p);
      }
    }
  }
}

void drawrect(int c, int what, double rectx1,double recty1,double rectx2,double recty2, double bus, int dash,
              int e_a, int e_b)
{
 static int i=0;
 static XRectangle r[CADDRAWBUFFERSIZE];
 double x1,y1,x2,y2;
 double xx1,yy1,xx2,yy2;
 char dash_arr[2];
 int width;

 if(!has_x) return;

 if(bus == -1.0) {
   what = NOW;
   width = INT_BUS_WIDTH(xctx->lw);
 } else if(bus > 0.0) {
   what = NOW;
   width = XLINEWIDTH(bus * xctx->mooz);
 } else {
   width = XLINEWIDTH(xctx->lw);
 }
 if(dash) what = NOW;

 if(e_a != -1) what = NOW; /* ellipse */
 if(what & NOW)
 {
  xx1 = x1 = X_TO_SCREEN(rectx1);
  yy1 = y1 = Y_TO_SCREEN(recty1);
  xx2 = x2 = X_TO_SCREEN(rectx2);
  yy2 = y2 = Y_TO_SCREEN(recty2);
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
   if(dash) {
     dash_arr[0] = dash_arr[1] = (char)dash;
     XSetDashes(display, xctx->gc[c], 0, dash_arr, 1);
     XSetLineAttributes (display, xctx->gc[c], width, xDashType, xCap, xJoin);
   } else if(bus > 0.0) {
     XSetLineAttributes (display, xctx->gc[c], width, LineSolid, CapProjecting, JoinMiter);
   } else if(bus == -1.0) {
     XSetLineAttributes (display, xctx->gc[c], width, LineSolid, LINECAP, LINEJOIN);
   }

   if(xctx->draw_window) {
     if(e_a != -1) {
       XDrawArc(display, xctx->window, xctx->gc[c], (int)xx1, (int)yy1,
       (unsigned int)xx2 - (unsigned int)xx1,
       (unsigned int)yy2 - (unsigned int)yy1, e_a * 64, e_b * 64);
     } else {
       XDrawRectangle(display, xctx->window, xctx->gc[c], (int)x1, (int)y1,
       (unsigned int)x2 - (unsigned int)x1,
       (unsigned int)y2 - (unsigned int)y1);
     }
   }
   if(xctx->draw_pixmap)
   {
     if(e_a != -1) {
       XDrawArc(display, xctx->save_pixmap, xctx->gc[c], (int)xx1, (int)yy1,
       (unsigned int)xx2 - (unsigned int)xx1,
       (unsigned int)yy2 - (unsigned int)yy1, e_a * 64, e_b * 64);

     } else {
       XDrawRectangle(display, xctx->save_pixmap, xctx->gc[c], (int)x1, (int)y1,
       (unsigned int)x2 - (unsigned int)x1,
       (unsigned int)y2 - (unsigned int)y1);
     }
   }
   if(dash || bus > 0.0 || bus == -1.0) {
     XSetLineAttributes (display, xctx->gc[c], XLINEWIDTH(xctx->lw), LineSolid, LINECAP, LINEJOIN);
   }
  }
 }
 else if(what & ADD)
 {
  if(i>=CADDRAWBUFFERSIZE)
  {
   if(xctx->draw_window) XDrawRectangles(display, xctx->window, xctx->gc[c], r,i);
   if(xctx->draw_pixmap)
     XDrawRectangles(display, xctx->save_pixmap, xctx->gc[c], r,i);
   i=0;
  }
  x1=X_TO_SCREEN(rectx1);
  y1=Y_TO_SCREEN(recty1);
  x2=X_TO_SCREEN(rectx2);
  y2=Y_TO_SCREEN(recty2);
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
   r[i].x=(short)x1;
   r[i].y=(short)y1;
   r[i].width=(unsigned short)(x2-r[i].x);
   r[i].height=(unsigned short)(y2-r[i].y);
   ++i;
  }
 }
 else if((what & END) && i)
 {
  if(xctx->draw_window) XDrawRectangles(display, xctx->window, xctx->gc[c], r,i);
  if(xctx->draw_pixmap) XDrawRectangles(display, xctx->save_pixmap, xctx->gc[c], r,i);
  i=0;
 }
}

void drawtemprect(GC gc, int what, double rectx1,double recty1,double rectx2,double recty2)
{
 static int i=0;
 static XRectangle r[CADDRAWBUFFERSIZE];
 double x1,y1,x2,y2;

 if(!has_x) return;
 if((fix_broken_tiled_fill || !_unix) && gc == xctx->gctiled && what == ADD) what = NOW;

 if(what & NOW)
 {
  x1=X_TO_SCREEN(rectx1);
  y1=Y_TO_SCREEN(recty1);
  x2=X_TO_SCREEN(rectx2);
  y2=Y_TO_SCREEN(recty2);
  /* if( (x2-x1)< 3.0 && (y2-y1)< 3.0) return; */
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
   if((fix_broken_tiled_fill || !_unix) && gc == xctx->gctiled) {
     /*
      * MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
      *     rectx1, recty1, rectx2, recty2, rectx1, recty1, xctx->lw);
      */
     fix_restore_rect(rectx1, recty1, rectx2, recty2);

   } else {
     XDrawRectangle(display, xctx->window, gc, (int)x1, (int)y1,
       (unsigned int)x2 - (unsigned int)x1,
       (unsigned int)y2 - (unsigned int)y1);
   }
  }
 }
 else if(what & ADD)
 {
  if(i>=CADDRAWBUFFERSIZE)
  {
   XDrawRectangles(display, xctx->window, gc, r,i);
   i=0;
  }
  x1=X_TO_SCREEN(rectx1);
  y1=Y_TO_SCREEN(recty1);
  x2=X_TO_SCREEN(rectx2);
  y2=Y_TO_SCREEN(recty2);
  /* if( (x2-x1)< 3.0 && (y2-y1)< 3.0) return; */
  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
   r[i].x=(short)x1;
   r[i].y=(short)y1;
   r[i].width=(unsigned short)(x2-r[i].x);
   r[i].height=(unsigned short)(y2-r[i].y);
   ++i;
  }
 }
 else if((what & END) && i)
 {
  XDrawRectangles(display, xctx->window, gc, r,i);
  i=0;
 }
}

/* round to closest 1e-ee. 2e-ee, 5e-ee
 * example: delta = 0.234 --> 0.2
 *                  3.23  --> 5
 *                  66    --> 100
 *                  4.3   --> 5
 *                  13    --> 20
 *                  112   --> 100
 *                  6300  --> 10000
 */
static double axis_increment(double a, double b, int div, int freq)
{
  double scale;
  double sign;
  double scaled_delta;
  double delta = b - a;
  if(div == 1) {
    return delta;
  }
  if(div < 1) div = 1;
  if(delta == 0.0) return delta;
  /* if user wants only one division, just do what user asks */
  if(div == 1) return delta;
  delta /= div;
  sign = (delta < 0.0) ? -1.0 : 1.0;
  delta = fabs(delta);
  scale = pow(10.0, floor(mylog10(delta)));
  scaled_delta =  delta / scale; /* 1 <= scaled_delta < 10 */
  dbg(1, "a=%g, b=%g, scale=%g, scaled_delta=%g --> ", a, b, scale, scaled_delta);
  if(freq && scaled_delta > 2.5) scaled_delta = 10.0;
  else if(freq && scaled_delta > 1.9) scaled_delta = 5.0;
  else if(freq && scaled_delta > 1.4) scaled_delta = 2.0;
  else if(freq) scaled_delta = 1.0;
  else if(scaled_delta > 5.5) scaled_delta = 10.0;
  else if(scaled_delta > 2.2) scaled_delta = 5.0;
  else if(scaled_delta > 1.1) scaled_delta = 2.0;
  else scaled_delta = 1.0;
  dbg(1, "scaled_delta = %g, scaled_delta * scale * sign=%g\n", scaled_delta, scaled_delta * scale * sign);
  return scaled_delta * scale * sign;
}

static double axis_start(double n, double delta, int div)
{
  if(div < 1) div = 1;
  if(delta == 0.0) return n;
  /* if user wants only one division, just do what user asks */
  if(div == 1) return n;
  if(delta < 0.0) return ceil(n / delta) * delta;
  return floor(n / delta) * delta;
}

static int axis_end(double x, double delta, double b)
{
  if(delta == 0.0) return 1;  /* guard against infinite loops */
  if(delta > 0) return x > b + delta / 100000.0;
  return x < b + delta / 100000.0;
}

static int axis_within_range(double x, double a, double b, double delta, int subdiv)
{
  double eps;
  if(subdiv == 0) subdiv = 1;
  eps = delta / (double) subdiv / 100.0;
  if(a < b) return x >= a - eps;
  return x <= a + eps;
}

static double get_unit(const char *val)
{
  if(!val)               return 1.0;
  else if(val[0] == 'f') return 1e15;
  else if(val[0] == 'p') return 1e12;
  else if(val[0] == 'n') return 1e9;
  else if(val[0] == 'u') return 1e6;
  else if(val[0] == 'm') return 1e3;
  else if(val[0] == 'k') return 1e-3;
  else if(val[0] == 'M') return 1e-6;
  else if(val[0] == 'G') return 1e-9;
  else if(val[0] == 'T') return 1e-12;
  return 1.0;
}

/* return hierarchy level where raw file was loaded (so may include top level 0) or -1
 * if there is no matching schematic name up in the hierarchy */
int sch_waves_loaded(void)
{
  int i;
  if(!xctx->raw || xctx->raw->level == -1) return -1;
  else if(xctx->raw && xctx->raw->values && xctx->raw->names && xctx->raw->schname) {
    dbg(1, "sch_waves_loaded(): raw->schname=%s\n", xctx->raw->schname);
    for(i = xctx->currsch; i >= 0; i--) {
      dbg(1, "sch_waves_loaded(): %d --> %s\n", i, xctx->sch[i]);
      if( !xctx->sch[i] ) continue;
      if( !strcmp(xctx->raw->schname, xctx->sch[i]) ) {
        dbg(1, "sch_waves_loaded(): returning %d\n", i);
        return i;
      }
    }
  }
  return -1;
}

static void get_bus_value(int n_bits, int hex_digits, SPICE_DATA **idx_arr, int p, char *busval,
                   double vthl, double vthh)
{
  double val;
  int i;
  int hexdigit = 0;
  int bin = 0;
  int hex = 0;
  char hexstr[] = "084C2A6E195D3B7F"; /* mirrored (Left/right) hex */
  int x = 0;
  for(i = n_bits - 1; i >= 0; i--) {
    if(idx_arr[i]) val = idx_arr[i][p];
    else val = 0.0; /* undefined bus element */
    if(val >= vthl && val <= vthh) { /* signal transitioning --> 'X' */
       x = 1; /* flag for 'X' value */
       i += bin - 3;
       bin = 3; /* skip remaining bits of hex digit */
       if(i < 0) break; /* MSB nibble is less than 4 bits --> break */
    } else hexdigit |= (val >= vthh ? 1 : 0);
    if(bin < 3) {
      ++bin;
      hexdigit <<= 1;
    } else {
      ++hex;
      if(x)
        busval[hex_digits - hex] = 'X';
      else
        busval[hex_digits - hex] = hexstr[hexdigit];
      hexdigit = 0; /* prepare for next hex digit */
      bin = 0;
      x = 0;
    }
  }
  if(bin) { /* process (incomplete) MSB nibble */
    ++hex;
    if(x)
      busval[hex_digits - hex] = 'X';
    else {
      hexdigit <<= (3 - bin);
      busval[hex_digits - hex] = hexstr[hexdigit];
    }
  }
  busval[hex_digits] = '\0';
}


/* idx_arr malloc-ated and returned, caller must free! */
static SPICE_DATA **get_bus_idx_array(const char *ntok, int *n_bits)
{
  SPICE_DATA **idx_arr =NULL;
  int p;
  char *saven, *nptr, *ntok_copy = NULL;
  const char *bit_name;
  *n_bits = count_items(ntok, ";,", "") - 1;
  dbg(1, "get_bus_idx_array(): ntok=%s\n", ntok);
  dbg(1, "get_bus_idx_array(): *n_bits=%d\n", *n_bits);
  idx_arr = my_malloc(_ALLOC_ID_, (*n_bits) * sizeof(SPICE_DATA *));
  p = 0;
  my_strdup2(_ALLOC_ID_, &ntok_copy, ntok);
  nptr = ntok_copy;
  my_strtok_r(nptr, ";,", "", 0, &saven); /*strip off bus name (1st field) */
  while( (bit_name = my_strtok_r(NULL, ";, \\\n", "", 0, &saven)) ) {
    int idx;
    if(p >= *n_bits) break; /* security check to avoid out of bound writing */
    if( (idx = get_raw_index(bit_name, NULL)) != -1) {
      idx_arr[p] = xctx->raw->values[idx];
    } else {
      idx_arr[p] = NULL;
    }
    /* dbg(0, "get_bus_idx_array(): bit_name=%s, p=%d\n", bit_name, p); */
    ++p;
  }
  my_free(_ALLOC_ID_, &ntok_copy);
  return idx_arr;
}

/* ---- trace SELECTION (issue 0175) -----------------------------------------
 *
 * The selection of one strip is a SET of NODE indices (landmine 34), stored in
 * the graph rect across two prop tokens that are always written together:
 *
 *   hilight_wave=<n>     the FIRST selected node, or -1. Grammar and sentinel
 *                        unchanged since forever -- every older build, the SVG
 *                        and PS exporters and the ~127 embedded schematic
 *                        graphs keep reading exactly what they always read.
 *   sel_waves="<n> <n>"  the WHOLE set, ascending, no duplicates. Written ONLY
 *                        when two or more traces are selected, so a strip that
 *                        was never Ctrl-clicked serialises byte-identically to
 *                        pre-0175 (the absent-means-absent rule `active` and
 *                        `markers` already follow).
 *
 * An older build reading a new file therefore bolds the FIRST selected trace and
 * ignores `sel_waves` as an unknown token -- fewer bold traces, never a wrong
 * one, never a parse error. A new build reading an old file sees no `sel_waves`
 * and takes the {hilight_wave} fallback. No XSCHEM_FILE_VERSION bump: an
 * additive optional rect token is exactly how `active` / `markers` /
 * `reorder_handle` / `legendbold` / `griddash` were all added.
 *
 * These four functions are the ONLY readers/writers of that pair, which is what
 * stops the two tokens drifting apart. */

/* Is NODE index `wcnt` part of graph `gr`'s selection? THE draw-side test:
 * every `gr->hilight_wave == wcnt` comparison in this file goes through it, or
 * a Ctrl-selected second trace renders thin while the token says it is bold. */
int wave_is_hilighted(Graph_ctx *gr, int wcnt)
{
  int k;
  if(!gr || wcnt < 0) return 0;
  /* a list, when present, is the WHOLE truth -- hilight_wave is its first
   * element and adding it again here would only mask a writer bug */
  if(gr->n_sel_waves > 0) {
    for(k = 0; k < gr->n_sel_waves; ++k) if(gr->sel_wave[k] == wcnt) return 1;
    return 0;
  }
  return gr->hilight_wave == wcnt;
}

/* --- the mid-drag SHRINK PREVIEW as a SET (issue 0192) ----------------------
 * doc/claude/specs/waveform_viewer_modes.md 19. A multi-trace drag carries N
 * traces, so the preview arm carries N (gi, node) pairs. Storage is the
 * graph_marker_sel shape (landmine 46): HEAD scalars that keep their exact
 * pre-0192 meaning + a FIXED set array + a count, with ONE writer and ONE
 * draw-side predicate. */

/* THE ONE WRITER. Sets the set, the count, the HEAD and the scale together, so
 * the head cannot drift from element 0 -- which is what keeps `xschem get
 * graph_preview` byte-identical for the single-trace case. `n` is clamped to
 * GRAPH_MAX_PREVIEW_WAVES: the cap bounds the PREVIEW only (xschem.h), never the
 * move, so an over-long selection loses chrome rather than the gesture.
 * scale == 0.0 or n <= 0 is the DISARM and zeroes all five fields, so there is
 * exactly one place that turns the preview off. */
void graph_preview_arm(const int *gis, const int *waves, int n, double scale)
{
  int k;
  if(!xctx) return;
  if(!gis || !waves || n <= 0 || scale == 0.0) {
    xctx->graph_preview_scale = 0.0;
    xctx->graph_preview_gi = 0;
    xctx->graph_preview_wave = 0;
    xctx->graph_preview_n = 0;
    return;
  }
  if(n > GRAPH_MAX_PREVIEW_WAVES) n = GRAPH_MAX_PREVIEW_WAVES;
  for(k = 0; k < n; ++k) {
    xctx->graph_preview_set_gi[k] = gis[k];
    xctx->graph_preview_set_wave[k] = waves[k];
  }
  xctx->graph_preview_n = n;
  xctx->graph_preview_gi = gis[0];
  xctx->graph_preview_wave = waves[0];
  xctx->graph_preview_scale = scale;
}

/* THE ONE DRAW-SIDE TEST: is NODE index `wcnt` of graph `gi` being carried?
 * The graph_marker_is_selected shape. Every `preview_wave == wcnt` comparison in
 * this file goes through it -- a surviving bare one draws a carried trace at
 * full size, and no leg that drags a SINGLE trace can see the difference, which
 * is why DM6 asserts the count at source level.
 * The scale test comes first so the resting cost is one compare. */
int graph_preview_has(int gi, int wcnt)
{
  int k;
  if(!xctx || wcnt < 0) return 0;
  if(xctx->graph_preview_scale == 0.0) return 0;
  for(k = 0; k < xctx->graph_preview_n; ++k) {
    if(xctx->graph_preview_set_gi[k] == gi && xctx->graph_preview_set_wave[k] == wcnt) return 1;
  }
  return 0;
}

/* --- NET-HIGHLIGHT STYLES ON WAVEFORM TRACES -------------------------------
 * doc/claude/specs/wave_trace_hilight.md. A trace is a polyline with no
 * junctions and no direction, so the whole net-highlight vocabulary applies to
 * it unchanged. The SET of highlighted traces is (gi, ni, style) triples in
 * xctx (xschem.h), with the storage and the discipline of graph_marker_sel_set
 * and graph_preview_set_*: FIXED arrays, ONE writer, ONE predicate.
 *
 * The highlight is an OVERLAY (D2): the trace is drawn normally, in its palette
 * colour, and the style is stroked ON TOP. That is what keeps the legend colour
 * meaningful AND what makes the cheap animation frame possible -- the base draw
 * path is never touched, so the overlay can be erased with one XCopyArea
 * instead of a redraw. */

/* Free every cached envelope. Losing the cache is a REBUILD, never a behaviour
 * change, so this is safe to call at any time and any number of times.
 * my_free() NULLs its argument, so a second call is a no-op. */
void wave_hilight_cache_free(void)
{
  int k;
  if(!xctx) return;
  for(k = 0; k < GRAPH_MAX_HILIGHT_WAVES; ++k) {
    WaveHilightEnv *e = &xctx->wave_hilight_env[k];
    if(e->pt) my_free(_ALLOC_ID_, &e->pt);
    if(e->prop) my_free(_ALLOC_ID_, &e->prop);
    e->npt = e->alloc = 0;
    e->valid = 0;
    e->painted = 0;
  }
}

/* THE WRITER. Copies at most GRAPH_MAX_HILIGHT_WAVES triples, dropping a
 * negative gi/ni/style and de-duplicating on (gi, ni) with the LAST style given
 * winning, then sets the count -- together, so nothing can drift.
 *
 * It also drops the whole envelope cache. That is deliberate and it is free
 * where it matters: an ANIMATION frame never writes the set (which is the case
 * that must cost nothing), while a set change is a fresh highlight that would
 * have to build its envelope anyway. Keying cache slots to set entries instead
 * would buy nothing and would need its own invalidation rules.
 * Returns the resulting count. */
int wave_hilight_write(const int *gis, const int *nis, const int *styles, int n)
{
  int k, w = 0;
  if(!xctx) return 0;
  for(k = 0; k < n && w < GRAPH_MAX_HILIGHT_WAVES; k++) {
    int j, dup = -1;
    if(!gis || !nis || !styles) break;
    if(gis[k] < 0 || nis[k] < 0 || styles[k] < 0) continue;
    for(j = 0; j < w; j++) {
      if(xctx->wave_hilight_gi[j] == gis[k] && xctx->wave_hilight_ni[j] == nis[k]) { dup = j; break; }
    }
    if(dup >= 0) { xctx->wave_hilight_style[dup] = styles[k]; continue; }
    xctx->wave_hilight_gi[w] = gis[k];
    xctx->wave_hilight_ni[w] = nis[k];
    xctx->wave_hilight_style[w] = styles[k];
    w++;
  }
  xctx->wave_hilight_n = w;
  wave_hilight_cache_free();
  return w;
}

/* Add, re-style, or (style < 0) REMOVE one trace. 1 when the set changed.
 * Routed through the writer so the cache invalidation has one home. */
int wave_hilight_set(int gi, int ni, int style)
{
  int gis[GRAPH_MAX_HILIGHT_WAVES], nis[GRAPH_MAX_HILIGHT_WAVES];
  int sty[GRAPH_MAX_HILIGHT_WAVES];
  int k, n = 0, hit = 0;
  if(!xctx || gi < 0 || ni < 0) return 0;
  for(k = 0; k < xctx->wave_hilight_n; ++k) {
    if(xctx->wave_hilight_gi[k] == gi && xctx->wave_hilight_ni[k] == ni) {
      hit = 1;
      if(style < 0) continue;                 /* the removal: simply not copied */
      if(xctx->wave_hilight_style[k] == style) return 0; /* already exactly this */
      gis[n] = gi; nis[n] = ni; sty[n] = style; n++;
      continue;
    }
    gis[n] = xctx->wave_hilight_gi[k];
    nis[n] = xctx->wave_hilight_ni[k];
    sty[n] = xctx->wave_hilight_style[k];
    n++;
  }
  if(!hit) {
    if(style < 0) return 0;                   /* nothing to remove */
    if(n >= GRAPH_MAX_HILIGHT_WAVES) return 0; /* the cap: refuse, do not evict */
    gis[n] = gi; nis[n] = ni; sty[n] = style; n++;
  }
  wave_hilight_write(gis, nis, sty, n);
  return 1;
}

/* Drop every entry of graph `gi`, or ALL of them for gi < 0. Returns how many
 * entries went. Routed through the writer, like wave_hilight_set. */
int wave_hilight_clear(int gi)
{
  int gis[GRAPH_MAX_HILIGHT_WAVES], nis[GRAPH_MAX_HILIGHT_WAVES];
  int sty[GRAPH_MAX_HILIGHT_WAVES];
  int k, n = 0, was;
  if(!xctx) return 0;
  was = xctx->wave_hilight_n;
  if(was <= 0) return 0;
  for(k = 0; k < was; ++k) {
    if(gi < 0 || xctx->wave_hilight_gi[k] == gi) continue;
    gis[n] = xctx->wave_hilight_gi[k];
    nis[n] = xctx->wave_hilight_ni[k];
    sty[n] = xctx->wave_hilight_style[k];
    n++;
  }
  if(n == was) return 0;
  wave_hilight_write(gis, nis, sty, n);
  return was - n;
}

/* THE ONE DRAW/QUERY-SIDE TEST: the style index of NODE `ni` of graph `gi`, or
 * -1 when that trace carries no highlight. The graph_preview_has shape, and for
 * the same reason -- a surviving bare `gi == .. && ni == ..` comparison is
 * invisible to any leg that highlights a SINGLE trace, so the count is asserted
 * at source level. The empty-set test comes first so the resting cost is one
 * compare. */
int wave_hilight_style_of(int gi, int ni)
{
  int k;
  if(!xctx || gi < 0 || ni < 0) return -1;
  if(xctx->wave_hilight_n <= 0) return -1;
  for(k = 0; k < xctx->wave_hilight_n; ++k) {
    if(xctx->wave_hilight_gi[k] == gi && xctx->wave_hilight_ni[k] == ni)
      return xctx->wave_hilight_style[k];
  }
  return -1;
}

/* Parse graph rect `i`'s selection into `out` (at most `max` entries, ascending,
 * de-duplicated); returns how many were written, 0 for "nothing selected".
 *
 * ⚠ An ABSENT token is not index 0. A bare atoi("") says 0 and would report a
 * strip that was never clicked as having node 0 selected -- the same trap issue
 * 0174's cross-strip sweep documents. Both tokens are tested for a non-empty
 * value before they are converted. */
int graph_sel_waves_get(int i, int *out, int max)
{
  const char *s;
  xRect *r;
  int n = 0, hw;
  if(!xctx || !out || max <= 0) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return 0;
  s = get_tok_value(r->prop_ptr, "sel_waves", 0);
  while(*s && n < max) {
    int v, dup, k;
    while(*s == ' ' || *s == '\t' || *s == '\n') ++s;
    if(!*s) break;
    /* fail closed on garbage -- and a LONE '-' is garbage, not node 0 */
    if(*s == '-') { if(s[1] < '0' || s[1] > '9') break; }
    else if(*s < '0' || *s > '9') break;
    v = atoi(s);
    while(*s && *s != ' ' && *s != '\t' && *s != '\n') ++s;
    if(v < 0) continue;
    for(dup = 0, k = 0; k < n; ++k) if(out[k] == v) { dup = 1; break; }
    if(!dup) out[n++] = v;
  }
  if(n > 0) {
    /* ascending: an insertion sort on <= 64 ints that are nearly always already
     * ordered (the writer emits them sorted) */
    int a, b;
    for(a = 1; a < n; ++a) {
      int v = out[a];
      for(b = a - 1; b >= 0 && out[b] > v; --b) out[b + 1] = out[b];
      out[b + 1] = v;
    }
    return n;
  }
  s = get_tok_value(r->prop_ptr, "hilight_wave", 0);
  if(!s[0]) return 0;
  hw = atoi(s);
  if(hw < 0) return 0;
  out[0] = hw;
  return 1;
}

/* Write the selection back onto graph rect `i`. n <= 0 clears it. Returns 1 when
 * the prop string actually changed, so a click that selects what was already
 * selected does not churn it (and does not force a redraw).
 *
 * `sel_waves` is REMOVED, not set to an empty value, for a selection of 0 or 1 --
 * subst_token(.., NULL) is the documented removal, and leaving `sel_waves=""`
 * behind would make every single-select rect differ from a pre-0175 one. */
int graph_sel_waves_set(int i, const int *waves, int n)
{
  xRect *r;
  const char *cur;
  char buf[GRAPH_MAX_SEL_WAVES * 12 + 1];
  int k, pos = 0, changed = 0;
  if(!xctx) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return 0;
  if(n > GRAPH_MAX_SEL_WAVES) n = GRAPH_MAX_SEL_WAVES;
  /* hilight_wave: the head of the selection, or -1 */
  {
    const char *want = (n > 0 && waves) ? my_itoa(waves[0]) : "-1";
    cur = get_tok_value(r->prop_ptr, "hilight_wave", 0);
    if(strcmp(cur, want)) {
      my_strdup2(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "hilight_wave", want));
      changed = 1;
    }
  }
  buf[0] = '\0';
  if(n >= 2 && waves) {
    for(k = 0; k < n; ++k) {
      const char *d = my_itoa(waves[k]);
      size_t l = strlen(d);
      if(pos + l + 2 >= sizeof(buf)) break;
      if(pos) buf[pos++] = ' ';
      memcpy(buf + pos, d, l);
      pos += (int)l;
    }
    buf[pos] = '\0';
  }
  cur = get_tok_value(r->prop_ptr, "sel_waves", 0);
  if(strcmp(cur, buf)) {
    my_strdup2(_ALLOC_ID_, &r->prop_ptr,
               subst_token(r->prop_ptr, "sel_waves", buf[0] ? buf : NULL));
    changed = 1;
  }
  return changed;
}

/* Ctrl+click: add NODE index `wcnt` to graph `i`'s selection if it is absent,
 * remove it if it is present. Returns 1 when something changed.
 *
 * The cap is a REFUSAL, not a silent drop: at GRAPH_MAX_SEL_WAVES the 65th add
 * leaves the selection exactly as it was (a removal always still works). */
int graph_sel_waves_toggle(int i, int wcnt)
{
  int sel[GRAPH_MAX_SEL_WAVES], n, k, at = -1;
  if(wcnt < 0) return 0;
  n = graph_sel_waves_get(i, sel, GRAPH_MAX_SEL_WAVES);
  for(k = 0; k < n; ++k) if(sel[k] == wcnt) { at = k; break; }
  if(at >= 0) {
    for(k = at; k < n - 1; ++k) sel[k] = sel[k + 1];
    --n;
  } else {
    if(n >= GRAPH_MAX_SEL_WAVES) {
      dbg(0, "graph_sel_waves_toggle(): graph %d already holds %d selected traces, refusing\n",
          i, n);
      return 0;
    }
    /* keep ascending: insert in place rather than appending + re-sorting */
    for(k = n; k > 0 && sel[k - 1] > wcnt; --k) sel[k] = sel[k - 1];
    sel[k] = wcnt;
    ++n;
  }
  return graph_sel_waves_set(i, sel, n);
}

/* what == 1: set thick lines,
 * what == 0: restore default
 */
static void set_thick_waves(int what, int wcnt, int wave_col, Graph_ctx *gr)
{
  unsigned long valuemask;
  XGCValues values;
  valuemask = GCLineWidth;
  dbg(1, "set_thick_waves(): what=%d\n", what);
  if(what) {
      if(wave_is_hilighted(gr, wcnt)) {
         int min = (int) tk_scaling * 2;
         values.line_width = XLINEWIDTH(2.4 * gr->linewidth_mult * xctx->lw);
         if(values.line_width < min) values.line_width = min;
         XChangeGC(display, xctx->gc[wave_col], valuemask, &values);
      }
  } else {
      if(wave_is_hilighted(gr, wcnt)) {
         values.line_width = XLINEWIDTH(gr->linewidth_mult * xctx->lw);
         XChangeGC(display, xctx->gc[wave_col], valuemask, &values);
      }
  }
}

/* ------------------------------------------------------------------------
 * THE one parser of a `node=` list entry.  Issue 0305:
 * doc/claude/issues/0305-per-trace-rawfile-is-honoured-by-three-of-six-node-walkers.md
 *
 * A graph rect's `node=` attribute is a newline separated list; one entry is
 *
 *     [alias;]<vec-or-RPN> [ '%' [<dataset-digits>] [<rawfile> [<sim_type>]] ]
 *
 * SEVEN functions in this file walk that list (draw_graph, graph_fullyzoom,
 * find_closest_wave, graph_point_at, wave_hilight_envelope, graph_wave_resolve
 * and -- since batch F item 8, spec D2 -- graph_fullxzoom(), which reaches it
 * through graph_x_union_rect()). Six of them used to hand-roll the `%` parse
 * and THREE of those six read only the leading dataset digits and silently
 * dropped the rawfile -- so a cross-DB trace (spec D1,
 * doc/claude/specs/mixed_signal_signal_browser.md) drew correctly and could
 * then not be picked, bolded or marked; the seventh, graph_fullxzoom(), never
 * parsed `%` at all and sized the X window from the wrong database entirely.
 * ANOTHER hand-rolled copy is how that drifted, so there is now exactly one:
 * a new walker becomes caller number eight, never parser number two.
 *
 *   ntok           IN  one token of the list. NOT modified.
 *   expr           OUT my_strdup'd token with the whole `%...` field removed
 *                      (the alias;vec part the callers evaluate). May be NULL.
 *   dataset        OUT the `%<n>` dataset restriction, -1 when absent.
 *   rawfile        OUT my_strdup'd per-trace database, "" when the token names
 *                      none. May be NULL.
 *   sim_type       OUT my_strdup'd sim type: the token's own when it carries
 *                      one, else `dflt_sim_type`. May be NULL.
 *   dflt_sim_type  IN  fallback (the graph's own `sim_type=`, then the current
 *                      raw's). NULL is read as "".
 *
 * The caller my_free()s *expr, *rawfile and *sim_type.
 * Both the path and the type go through a Tcl `subst {...}`, exactly as
 * draw_graph() has always done, so a token may name its database through a Tcl
 * variable. NOTHING here switches databases: the switch, and the balanced
 * restore that must pair with it, belong to the caller. */
static void node_token_split(const char *ntok, char **expr, int *dataset,
                             char **rawfile, char **sim_type, const char *dflt_sim_type)
{
  char *nd = NULL;
  int ds = -1;

  if(!dflt_sim_type) dflt_sim_type = "";
  my_strdup2(_ALLOC_ID_, &nd, find_nth(ntok, "%", "\"", 0, 2));
  if(nd[0]) {
    /* `%12 file.raw tran` -- the dataset digits are optional, so the rawfile is
     * field 1 or field 2 of the `%` payload (separators "\n ") */
    int pos = 1;
    if(isonlydigit(find_nth(nd, "\n ", "\"", 0, 1))) pos = 2;
    if(rawfile) {
      tclvareval("subst {", find_nth(nd, "\n ", "\"", 0, pos), "}", NULL);
      my_strdup2(_ALLOC_ID_, rawfile, tclresult());
    }
    if(sim_type) {
      tclvareval("subst {", find_nth(nd, "\n ", "\"", 0, pos + 1), "}", NULL);
      my_strdup2(_ALLOC_ID_, sim_type, tclresult()[0] ? tclresult() : dflt_sim_type);
    }
    if(pos == 2) ds = atoi(nd);
    if(expr) my_strdup(_ALLOC_ID_, expr, find_nth(ntok, "%", "\"", 4, 1));
  } else {
    if(rawfile) my_strdup2(_ALLOC_ID_, rawfile, "");
    if(sim_type) my_strdup2(_ALLOC_ID_, sim_type, dflt_sim_type);
    if(expr) my_strdup(_ALLOC_ID_, expr, ntok);
  }
  if(dataset) *dataset = ds;
  my_free(_ALLOC_ID_, &nd);
}

/* The sim_type a `%<rawfile>` with no explicit type inherits: the graph's own
 * `sim_type=` token, else the CURRENT raw's. Kept in one place because all seven
 * walkers must agree about it -- extra_rawfile()'s switch arm compares the type
 * with strcmp() and skips every slot whose sim_type is NULL (save.c). */
static const char *node_dflt_sim_type(const char *graph_sim_type)
{
  if(graph_sim_type && graph_sim_type[0]) return graph_sim_type;
  if(xctx && xctx->raw && xctx->raw->sim_type) return xctx->raw->sim_type;
  return "";
}

/* Restore the current database to registry slot `idx`, the balanced other half
 * of a per-node extra_rawfile() switch. `idx` < 0, or a database that is
 * already the current one, is a no-op. Index form (extra_rawfile `what` 2 with
 * an all-digit "file") rather than the mode-5 SWAP, because a swap is not a
 * stack pop: nested switches cannot be unwound with it. */
static void node_db_restore(int idx)
{
  char buf[30];
  if(idx < 0 || !xctx || xctx->extra_idx == idx) return;
  my_snprintf(buf, S(buf), "%d", idx);
  extra_rawfile(2, buf, NULL, -1.0, -1.0);
}

/* THE REGISTRY CURSOR IS A PAIR, AND node_db_restore() PUTS BACK ONLY HALF OF IT
 * (batch F item 2, fix round). `extra_idx` is the database that is current;
 * `extra_prev_idx` is where `xschem raw switch_back` -- extra_rawfile() mode 5,
 * scheduler.c, and the documented idiom of every `xschem raw switch <x>; ...;
 * switch_back` fragment in a schematic (xschem.tcl:4743) -- will GO. EVERY
 * extra_rawfile() switch overwrites the second half, and in READ mode so does a
 * FAILED one (save.c: `xctx->raw = save; xctx->extra_prev_idx = xctx->extra_idx;`).
 * So a walker that unwinds only extra_idx has still moved the session: measured
 * with prev=1, current=3, ONE call to any of graph_closest_wave / graph_trace_at /
 * wave_hilight_points / a refused fullyzoom made the next switch_back land on
 * slot 2. A read-only getter must not be able to do that.
 *
 * Called ONCE per walker, at the graph-level unwind and AFTER it (node_db_restore
 * is itself a switch and clobbers prev again). Deliberately NOT called by the
 * per-NODE unwinds inside a walk: those are intermediate, and the entry value is
 * what the session is owed. Unconditional -- a graph-level switch that REFUSED
 * moved no extra_idx but may still have moved prev, which is exactly the
 * graph_fullyzoom() graph-level refusal NDL3 now watches. */
static void node_db_prev_restore(int prev)
{
  if(!xctx || prev < 0) return;
  xctx->extra_prev_idx = prev;
}

/* ==========================================================================
 * SPEC D2 -- THE JOINT X DOMAIN.
 * doc/claude/specs/mixed_signal_signal_browser.md, row D2.
 *
 * graph_fullxzoom() used to compute the automatic X window from the extent of
 * whichever database happened to be CURRENT (or, for a follower strip, of the
 * MASTER rect's `rawfile=`). It was the one `node=` walker that never parsed
 * the `%` field at all, so a strip carrying an analog trace from a 0..2 us raw
 * and a digital trace from a 0..500 ns VCD was sized by one of the two and the
 * other was clipped or squeezed -- and WHICH one depended on the registry
 * cursor, which is exactly the silent-wrong-answer class issue 0305 is about.
 *
 * The window is now the UNION of the extents of every database contributing a
 * trace to the shared-X strip GROUP. See the three helpers below.
 * ========================================================================== */

/* Does graph rect `k` share graph rect `master`'s X axis?
 *
 * THE predicate, verbatim from callback.c's MMB pan / RMB box zoom / arrow pan
 * loop (and from graph_axis_zoom(), which used to hold the second copy):
 *
 *     rk->sel || (same_sim_type && !(rk->flags & 2)) || k == master
 *
 * where same_sim_type additionally requires the MASTER not to be `unlocked`
 * (flags & 2) and the two `sim_type=` PROPERTY TOKENS to match. Factored into
 * one place because D2 needs a third caller: the joint X domain is a property
 * of the GROUP, so the union has to be taken over exactly the rects that will
 * be handed the answer. Duplicating a predicate is how the `%` parse drifted to
 * three-of-six walkers (issue 0305) -- one copy, three callers.
 *
 * NOT the viewer's `sharedx` flag, which the C engine cannot see. */
static int graph_shares_x(int master, int k)
{
  xRect *rm, *rk;
  char *master_sim = NULL;
  int same_sim_type = 0, member;

  if(!xctx) return 0;
  if(master < 0 || master >= xctx->rects[GRIDLAYER]) return 0;
  if(k < 0 || k >= xctx->rects[GRIDLAYER]) return 0;
  rm = &xctx->rect[GRIDLAYER][master];
  rk = &xctx->rect[GRIDLAYER][k];
  if(!(rk->flags & 1)) return 0;     /* 1: graph, 3: graph_unlocked */
  if(k == master) return 1;
  /* get_tok_value() answers out of a rotating buffer, so the master's token has
   * to be copied before the second call can overwrite it */
  my_strdup2(_ALLOC_ID_, &master_sim, get_tok_value(rm->prop_ptr, "sim_type", 0));
  if(!(rm->flags & 2) &&
     !strcmp(master_sim, get_tok_value(rk->prop_ptr, "sim_type", 0))) {
    same_sim_type = 1;
  }
  my_free(_ALLOC_ID_, &master_sim);
  member = (rk->sel || (same_sim_type && !(rk->flags & 2)));
  return member ? 1 : 0;
}

/* ONE CONTRIBUTION to the joint X domain: the extent of the sweep variable
 * `sweep_name` (absent -> column 0) in the database that is CURRENT right now,
 * for dataset `dataset` (-1 = dataset 0).
 *
 * Returns 1 and fills lo/hi, or 0 -- and 0 is a real answer, not an excuse to
 * invent one. A database with no values, no columns, no datasets, an empty
 * dataset or a column that is all NaN contributes NOTHING to the union rather
 * than dragging it to 0, to NaN or to a window nothing can be drawn in. See the
 * degenerate-input ruling in the spec.
 *
 * The sweep column is resolved BY NAME here and clamped against the
 * switched-in nvars, for the reason batch F item 2 recorded at every other
 * walker: a column NUMBER belongs to the database it was resolved in, and
 * subscripting a three-column VCD with a five-column raw's column 4 is an
 * out-of-bounds read. */
static int graph_x_extent(const char *sweep_name, int dataset, double *lo, double *hi)
{
  Raw *raw;
  int idx, k, dset, np, first = 1;
  int save_datasets = -1, save_npoints = -1;
  double xx1 = 0.0, xx2 = 0.0;

  if(!xctx) return 0;
  raw = xctx->raw;
  if(!raw || !raw->values || !raw->npoints) return 0;
  if(raw->nvars <= 0 || raw->datasets <= 0) return 0;
  idx = -1;
  if(sweep_name && sweep_name[0]) {
    idx = get_raw_index(sweep_name, NULL);
    /* A database that does not HAVE the target strip's x quantity has no extent
     * IN that quantity, so it contributes nothing. Falling through to column 0
     * would fold a different quantity into the union -- the same class of error
     * as measuring each group member in its own `sweep=`. An ABSENT `sweep=`
     * token is NOT this case: it means column 0, which is what every database
     * here calls its x axis. */
    if(idx < 0) return 0;
  }
  if(idx < 0) idx = 0;
  if(idx >= raw->nvars) idx = 0;
  dset = (dataset == -1) ? 0 : dataset;
  if(dset < 0) dset = 0;
  if(dset >= raw->datasets) dset = 0;
  /* transform multiple OP points into a dc sweep (unchanged from the shipped
   * code, but now per DATABASE: the saved pair is put back before this function
   * returns, so a later contributor can never re-apply the first one's) */
  if(raw->sim_type && !strcmp(raw->sim_type, "op") &&
     raw->datasets > 1 && raw->npoints[0] == 1) {
    save_datasets = raw->datasets;
    raw->datasets = 1;
    save_npoints = raw->npoints[0];
    raw->npoints[0] = raw->allpoints;
    dset = 0;
  }
  np = raw->npoints[dset];
  for(k = 0; k < np; k++) {
    double v = get_raw_value(dset, idx, k);
    if(v != v) continue;              /* NaN has no ordering, so it is no extent */
    if(first) { xx1 = xx2 = v; first = 0; }
    else {
      if(v < xx1) xx1 = v;
      if(v > xx2) xx2 = v;
    }
  }
  if(save_npoints != -1) {
    raw->datasets = save_datasets;
    raw->npoints[0] = save_npoints;
  }
  if(first) return 0;                 /* nothing usable in that column */
  *lo = xx1;
  *hi = xx2;
  return 1;
}

/* fold one contribution into the running union */
static void graph_x_union_add(const char *sweep_name, int dataset,
                              double *lo, double *hi, int *got)
{
  double a = 0.0, b = 0.0;
  if(!graph_x_extent(sweep_name, dataset, &a, &b)) return;
  if(!*got) { *lo = a; *hi = b; }
  else {
    if(a < *lo) *lo = a;
    if(b > *hi) *hi = b;
  }
  (*got)++;
}

/* Add every database contributing a trace to graph rect `k` to the running
 * union [*lo, *hi]; `*got` counts the contributions that answered and
 * `*nodes_seen` counts the `node=` entries walked, resolvable or not.
 *
 * `sweep_name` is THE TARGET RECT's x quantity, passed down from
 * graph_fullxzoom() -- deliberately NOT rect k's own. A union is only meaningful
 * over ONE quantity, and the rect being written is the one that says which:
 * graph_shares_x() puts a locked X-Y strip (`sweep=v(a)`) in the same group as
 * a time strip, and measuring each member in its own quantity folded a VOLTAGE
 * range into a TIME window and squeezed the waveform to invisibility. Each
 * database still resolves the NAME itself (graph_x_extent), so a column number
 * never crosses a database boundary.
 *
 * WHAT CONTRIBUTES, and the ruling behind it (spec D2):
 *   - every `%<rawfile>` named by a `node=` entry THAT RESOLVES. One that does
 *     not resolve contributes nothing: every other walker REFUSES such a trace
 *     (issue 0305's ruling), so sizing the window for it would fit a trace that
 *     is never drawn.
 *   - the strip's OWN database -- its `rawfile=`, or the current one when it
 *     has none -- but only when a trace actually plots from it: at least one
 *     `node=` entry WITHOUT a `%<rawfile>`. A strip whose every entry names its
 *     own database must NOT be sized by whatever database the registry cursor
 *     happens to be parked on -- that is the defect this item exists to remove.
 *   - a TRACELESS strip contributes its own database ONLY under `empty_ok`,
 *     which graph_fullxzoom() sets on a SECOND pass and only when the whole
 *     group turned out to be traceless. An empty strip has nothing else to go on
 *     and must still get a drawable window, but folding its fallback into a
 *     group that does have traces put the current database back into the union
 *     and the window snapped to the registry cursor again -- the very defect,
 *     re-entering through the empty strip `wviewer::add_graph` appends. It also
 *     broke the group's agreement, since the fallback fired for some members and
 *     not others.
 *
 * Leaves the current database exactly where it found it. */
static void graph_x_union_rect(int k, const char *sweep_name, int dataset,
                               double *lo, double *hi, int *got,
                               int *nodes_seen, int empty_ok)
{
  xRect *rk;
  char *node = NULL, *custom_rawfile = NULL, *sim_type = NULL;
  char *node_rawfile = NULL, *node_sim_type = NULL, *ntok_copy = NULL;
  char *saven, *nptr;
  const char *ntok;
  int autoload, graph_idx, entry_extra_idx, own_db_plots = 0;

  if(!xctx || k < 0 || k >= xctx->rects[GRIDLAYER]) return;
  rk = &xctx->rect[GRIDLAYER][k];
  entry_extra_idx = xctx->extra_idx;

  autoload = !strboolcmp(get_tok_value(rk->prop_ptr, "autoload", 0), "true");
  if(autoload == 0) autoload = 2;
  my_strdup2(_ALLOC_ID_, &custom_rawfile, get_tok_value(rk->prop_ptr, "rawfile", 0));
  my_strdup2(_ALLOC_ID_, &sim_type, get_tok_value(rk->prop_ptr, "sim_type", 0));
  my_strdup2(_ALLOC_ID_, &node, get_tok_value(rk->prop_ptr, "node", 0));

  /* the strip's own database. A REFUSED graph-level switch is not fatal: the
   * strip simply contributes the database that is current, exactly as every
   * other walker treats an unresolvable `rawfile=`. */
  if(custom_rawfile[0]) {
    extra_rawfile(autoload, custom_rawfile,
                  sim_type[0] ? sim_type : node_dflt_sim_type(NULL), -1.0, -1.0);
  }
  graph_idx = xctx->extra_idx;

  /* ONE walk, ONE `%` parse (issue 0305: a second copy is how this family
   * drifted). Each entry either names its own database -- switch, measure,
   * unwind to the graph level -- or plots from the strip's own, which is then
   * folded in once, after the walk. The union is commutative, so measuring the
   * strip's own database last costs nothing and saves a second parse. */
  nptr = node;
  while( (ntok = my_strtok_r(nptr, "\n", "\"", 4, &saven)) ) {
    nptr = NULL;
    if(nodes_seen) (*nodes_seen)++;
    node_token_split(ntok, &ntok_copy, NULL, &node_rawfile, &node_sim_type,
                     node_dflt_sim_type(sim_type));
    if(node_rawfile[0]) {
      if(extra_rawfile(autoload, node_rawfile, node_sim_type, -1.0, -1.0) != 0) {
        graph_x_union_add(sweep_name, dataset, lo, hi, got);
      }
      node_db_restore(graph_idx);
    } else {
      own_db_plots = 1;
    }
  }
  if(!node[0] && empty_ok) own_db_plots = 1;
  if(own_db_plots) graph_x_union_add(sweep_name, dataset, lo, hi, got);

  node_db_restore(entry_extra_idx);
  my_free(_ALLOC_ID_, &node);
  my_free(_ALLOC_ID_, &custom_rawfile);
  my_free(_ALLOC_ID_, &sim_type);
  my_free(_ALLOC_ID_, &node_rawfile);
  my_free(_ALLOC_ID_, &node_sim_type);
  my_free(_ALLOC_ID_, &ntok_copy);
}

/* THE AUTOMATIC X WINDOW of graph rect `i` (the `f` key, and
 * `xschem setprop rect 2 <n> fullxzoom`). Spec D2: the union, over the whole
 * shared-X group, of every contributing database's extent.
 *
 * Returns 1 when x1/x2 were written (i.e. the caller owes a redraw).
 *
 * TWO REFUSALS, both leaving x1/x2 exactly as they were:
 *   - nothing contributed at all. Note WHICH way that cuts: a group whose every
 *     `node=` entry names a database that does not resolve keeps the window it
 *     had, rather than falling back to whatever the registry cursor points at.
 *     Only a WHOLLY TRACELESS group takes the current-database fallback, on the
 *     second pass below.
 *   - the union is DEGENERATE (zero width, e.g. a lone single-sample database).
 *     A zero-width X window makes every X transform divide by gr->gw == 0, so
 *     the window the strip already had is strictly the better answer. This is
 *     the one behaviour the shipped code got wrong in the safe direction only
 *     by luck: it wrote x1 == x2 and let setup_graph_data() divide by zero.
 *
 * The X QUANTITY is rect i's `sweep=` (absent -> column 0), resolved by NAME in
 * every contributing database. A shared-X group can hold members with different
 * `sweep=` tokens -- graph_shares_x() has never required otherwise -- and the
 * union has to be over one quantity or it is not a union at all. */
int graph_fullxzoom(int i, Graph_ctx *gr, int dataset)
{
  xRect *r;
  char *sweep_name = NULL;
  int master, k, got = 0, nodes_seen = 0;
  int entry_extra_idx, entry_prev_idx;
  double xx1 = 0.0, xx2 = 0.0;

  if(!xctx) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  if(sch_waves_loaded() < 0) return 0;
  r = &xctx->rect[GRIDLAYER][i];

  /* xctx->graph_master is MOUSE state: waves_selected() sets it to -1 whenever
   * the pointer is not over a graph (callback.c). A programmatic full zoom
   * (`xschem setprop rect 2 n fullxzoom`, see doc/claude/specs/waveform_viewer.md)
   * can therefore run with graph_master == -1, or stale beyond the rect count
   * after a canvas rebuild, and the unguarded xctx->rect[GRIDLAYER][graph_master]
   * reads walked off the array -> intermittent SIGSEGV. Out-of-range or
   * non-graph master -> treat the target graph as its own master. */
  master = xctx->graph_master;
  if(master < 0 || master >= xctx->rects[GRIDLAYER]) master = i;
  else if(!(xctx->rect[GRIDLAYER][master].flags & 1)) master = i;

  entry_extra_idx = xctx->extra_idx;
  entry_prev_idx = xctx->extra_prev_idx;

  /* ONE x quantity for the whole union, and it is the TARGET rect's: see the
   * `sweep_name` paragraph on graph_x_union_rect(). Copied because
   * get_tok_value() answers out of a rotating buffer the walk below reuses. */
  my_strdup2(_ALLOC_ID_, &sweep_name,
             find_nth(get_tok_value(r->prop_ptr, "sweep", 0), ", ", "\"", 0, 1));

  /* THE GROUP, not the rect: every strip that shares this X axis is about to be
   * given the SAME x1/x2 by callback.c's loop, so all of them must be measured.
   * Computing rect `i`'s own union instead would hand each member of a shared-X
   * group a different idea of the window, and the last one written would win. */
  for(k = 0; k < xctx->rects[GRIDLAYER]; ++k) {
    if(!(xctx->rect[GRIDLAYER][k].flags & 1)) continue;
    if(k != i && !graph_shares_x(master, k)) continue;
    graph_x_union_rect(k, sweep_name, dataset, &xx1, &xx2, &got, &nodes_seen, 0);
  }
  /* SECOND PASS, and only for a group in which nothing plots at all: an empty
   * strip still needs a drawable window, so the traceless group falls back to
   * its members' own databases. Over the GROUP rather than over rect i, so every
   * member of it computes the same answer whichever one the gesture started on.
   * `!nodes_seen` is what separates "no traces" from "traces named, none of them
   * resolvable" -- the latter keeps the window it had. */
  if(!got && !nodes_seen) {
    for(k = 0; k < xctx->rects[GRIDLAYER]; ++k) {
      if(!(xctx->rect[GRIDLAYER][k].flags & 1)) continue;
      if(k != i && !graph_shares_x(master, k)) continue;
      graph_x_union_rect(k, sweep_name, dataset, &xx1, &xx2, &got, NULL, 1);
    }
  }

  /* the registry cursor is a PAIR: extra_idx and the extra_prev_idx that
   * `xschem raw switch_back` goes to (batch F item 2, finding 1) */
  node_db_restore(entry_extra_idx);
  node_db_prev_restore(entry_prev_idx);
  my_free(_ALLOC_ID_, &sweep_name);

  if(!got) return 0;
  if(gr && gr->logx) {
    xx1 = mylog10(xx1);
    xx2 = mylog10(xx2);
  }
  if(!(xx1 < xx2)) return 0;   /* degenerate (or NaN): keep the drawable window */
  dbg(1, "graph_fullxzoom(): %d contribution(s), xx1=%g, xx2=%g\n", got, xx1, xx2);
  my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x1", dtoa(xx1)));
  my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "x2", dtoa(xx2)));
  return 1;
}

/* ==========================================================================
 * SPEC D4 -- CURSORS ACROSS DATABASES.
 * doc/claude/specs/mixed_signal_signal_browser.md, row D4.
 *
 * annot_p / annot_x / annot_sweep_idx / cursor_b_val are fields of `Raw`, i.e.
 * PER DATABASE. backannotate_at_cursor_b_pos() (callback.c) resolved cursor B
 * in xctx->raw and nowhere else, so with an analog raw and a VCD loaded
 * together a cursor at time t was not one object at one time: it was N objects
 * that happened to have been placed together, one of them fresh and the rest
 * holding whatever index they were last left with. Which one was fresh depended
 * on the registry cursor -- the same silent-wrong-answer shape as issue 0305
 * and spec D2.
 *
 * This is the enumerator half of the fix: the SET of registry slots a cursor
 * placed on graph rect `r` has to resolve in. The annotation itself stays in
 * callback.c, which owns the cursor and the Tcl-visible backannotation array.
 *
 * WHAT CONTRIBUTES (spec RULING D4-1), and it is deliberately a SUPERSET of
 * D2's rule for the X window:
 *   - the database that is CURRENT on entry, ALWAYS. It is what `xschem raw
 *     value <n> {}`, annotate_op() and the schematic voltage overlay read when
 *     nobody switched, so including it unconditionally is what makes a
 *     single-database session behave exactly as it did before this item.
 *   - every `%<rawfile>` named by a `node=` entry THAT RESOLVES. One that does
 *     not resolve contributes nothing -- that trace is refused everywhere else
 *     (issue 0305), so annotating for it would be annotating a trace that is
 *     never drawn.
 *   - the strip's OWN database (its `rawfile=`, else the current one) when a
 *     trace actually plots from it: at least one `node=` entry with no
 *     `%<rawfile>`. A traceless strip contributes its own database too -- unlike
 *     D2 there is no group to disagree with, and a cursor on an empty strip
 *     still has to annotate something.
 *   - all three of the above AGAIN, for every OTHER graph rect that shares this
 *     cursor (RULING D4-8, at the sibling loop below). Cursor B is one global,
 *     so a digital strip stacked under an analog one is inside its scope even
 *     though no caller ever passes that rect down here.
 *
 * *slots is my_malloc'd here with the DISTINCT registry indices and the return
 * value is how many were written; the caller my_free()s it. It grows rather
 * than truncating because an `autoload=true` strip can REGISTER databases while
 * this walks, so no bound taken before the walk is a bound. The current
 * database is always (*slots)[0], so a caller that annotates in order leaves the
 * Tcl-visible array written by the database the rest of the engine calls "the"
 * one.
 *
 * Leaves BOTH halves of the registry cursor exactly where it found them: this
 * is a read-only query and a query verb must not move the session (batch F
 * item 2, finding 1).
 * ========================================================================== */

/* append `idx` to *slots unless it is already there; returns the new count */
static int graph_db_slot_add(int **slots, int *cap, int n, int idx)
{
  int j;
  if(idx < 0) return n;
  for(j = 0; j < n; j++) if((*slots)[j] == idx) return n;
  if(n >= *cap) {
    *cap = n + 8;
    my_realloc(_ALLOC_ID_, slots, (size_t)(*cap) * sizeof(int));
  }
  (*slots)[n] = idx;
  return n + 1;
}

/* ONE STRIP's contribution to the set. Appends the registry slots rect `r`
 * plots from to *slots and answers the new count; the current database is put
 * back to `entry_extra_idx` on every exit path, so strips compose. */
static int graph_cursor_dbs_rect(xRect *r, int **slots, int *cap, int n, int entry_extra_idx)
{
  char *node = NULL, *custom_rawfile = NULL, *sim_type = NULL;
  char *node_rawfile = NULL, *node_sim_type = NULL, *ntok_copy = NULL;
  char *saven, *nptr;
  const char *ntok;
  int autoload, graph_idx;
  int own_db_plots = 0, nodes_seen = 0;

  autoload = !strboolcmp(get_tok_value(r->prop_ptr, "autoload", 0), "true");
  if(autoload == 0) autoload = 2;
  my_strdup2(_ALLOC_ID_, &custom_rawfile, get_tok_value(r->prop_ptr, "rawfile", 0));
  my_strdup2(_ALLOC_ID_, &sim_type, get_tok_value(r->prop_ptr, "sim_type", 0));
  my_strdup2(_ALLOC_ID_, &node, get_tok_value(r->prop_ptr, "node", 0));

  /* the strip's own database. A REFUSED graph-level switch is not fatal: the
   * strip then owns whatever database is current, as every other walker has it. */
  if(custom_rawfile[0]) {
    extra_rawfile(autoload, custom_rawfile,
                  sim_type[0] ? sim_type : node_dflt_sim_type(NULL), -1.0, -1.0);
  }
  graph_idx = xctx->extra_idx;

  /* ONE walk, ONE `%` parse: caller number eight of node_token_split(), never
   * parser number two (issue 0305). */
  nptr = node;
  while( (ntok = my_strtok_r(nptr, "\n", "\"", 4, &saven)) ) {
    nptr = NULL;
    nodes_seen++;
    node_token_split(ntok, &ntok_copy, NULL, &node_rawfile, &node_sim_type,
                     node_dflt_sim_type(sim_type));
    if(node_rawfile[0]) {
      if(extra_rawfile(autoload, node_rawfile, node_sim_type, -1.0, -1.0) != 0) {
        n = graph_db_slot_add(slots, cap, n, xctx->extra_idx);
      }
      node_db_restore(graph_idx);
    } else {
      own_db_plots = 1;
    }
  }
  if(!nodes_seen) own_db_plots = 1;
  if(own_db_plots) n = graph_db_slot_add(slots, cap, n, graph_idx);

  node_db_restore(entry_extra_idx);
  my_free(_ALLOC_ID_, &node);
  my_free(_ALLOC_ID_, &custom_rawfile);
  my_free(_ALLOC_ID_, &sim_type);
  my_free(_ALLOC_ID_, &node_rawfile);
  my_free(_ALLOC_ID_, &node_sim_type);
  my_free(_ALLOC_ID_, &ntok_copy);
  return n;
}

int graph_cursor_dbs(xRect *r, int **slots)
{
  int entry_extra_idx, entry_prev_idx;
  int n = 0, cap = 0, i;

  if(!xctx || !r || !slots) return 0;
  *slots = NULL;
  /* RE-ENTRANCY REFUSAL, and it is not defensive: raw_read() calls
   * backannotate_at_cursor_b_pos() from INSIDE extra_rawfile()'s read arm, at a
   * moment when xctx->raw is the freshly read database and it is NOT YET in
   * extra_raw_arr[] -- extra_idx still names the OUTGOING slot. Any switch made
   * from here would then overwrite xctx->raw with a registered database, and the
   * read arm's `extra_raw_arr[extra_raw_n] = xctx->raw` a few lines later would
   * register THAT pointer a second time and leak the one it just read: two
   * registry slots aliasing one Raw, i.e. a double free at the next `raw clear`.
   * Whenever xctx->raw is not the registry's current entry there is nothing this
   * function can safely enumerate, so it answers 0 and the caller falls back to
   * annotating the current database alone -- exactly the shipped behaviour. */
  if(xctx->extra_raw_n <= 0) return 0;
  if(xctx->extra_idx < 0 || xctx->extra_idx >= xctx->extra_raw_n) return 0;
  if(xctx->raw != xctx->extra_raw_arr[xctx->extra_idx]) return 0;
  entry_extra_idx = xctx->extra_idx;
  entry_prev_idx = xctx->extra_prev_idx;
  n = graph_db_slot_add(slots, &cap, n, entry_extra_idx);
  /* not a graph rect: the current database and nothing else. Through the
   * epilogue like every other exit -- nothing is outstanding here yet, but a
   * refusal that hand-copies (or hand-skips) the cleanup is exactly what batch
   * F item 2 had to unpick out of graph_fullyzoom(). */
  if(!(r->flags & 1)) goto cursor_dbs_done;

  n = graph_cursor_dbs_rect(r, slots, &cap, n, entry_extra_idx);

  /* RULING D4-8 (fix round) -- CURSOR B IS A VIEWER OBJECT, NOT A STRIP OBJECT,
   * SO ITS SCOPE IS EVERY STRIP THAT SHARES IT.
   *
   * xctx->graph_cursor2_x is ONE global, and the canonical mixed-signal layout
   * is the Cadence one: analog on one strip, the digital bus on its own strip
   * underneath. Fanning out over only the rect that happened to be passed in
   * left the digital strip's VCD never annotated at all -- annot_p -1 and
   * cursor_b_val my_calloc zero, which reads as "that signal is 0" rather than
   * "nothing asked" -- and `xschem set cursor2_x` (scheduler.c) hard-codes
   * rect[GRIDLAYER][0], so the headless path and the menu path both drove the
   * cursor from strip 0 only. Every mouse-motion caller passes just the rect
   * under the pointer, which is worse: which databases got a fresh cursor then
   * depended on where the mouse was.
   *
   * A strip with `private_cursor` (flags bit 4) is excluded, in BOTH directions:
   * it has a cursor2_x of its OWN, so it neither joins another strip's fan-out
   * nor drags other strips into its own. That is the same reading of the flag
   * backannotate_cursor_b_in_db() already has when it picks `cursor2`.
   *
   * The per-database RESOLUTION still uses the driving strip's Graph_ctx --
   * `gr` is the single shared xctx->graph_struct and re-running setup_graph_data()
   * per sibling on every cursor motion would both cost a walk and stamp another
   * strip's geometry into it. That is sound because of RULING D4-7: a database
   * with nothing inside the driving strip's X window is resolved against its
   * own whole sweep instead of being skipped, so the window a sibling happens
   * to be zoomed to cannot change the answer. */
  if(!(r->flags & 4)) {
    for(i = 0; i < xctx->rects[GRIDLAYER]; i++) {
      xRect *rr = &xctx->rect[GRIDLAYER][i];
      if(rr == r) continue;
      if(!(rr->flags & 1)) continue;   /* not a graph */
      if(rr->flags & 4) continue;      /* its own cursor, its own databases */
      n = graph_cursor_dbs_rect(rr, slots, &cap, n, entry_extra_idx);
    }
  }

  cursor_dbs_done:
  node_db_restore(entry_extra_idx);
  node_db_prev_restore(entry_prev_idx);
  dbg(1, "graph_cursor_dbs(): %d database(s)\n", n);
  return n;
}

int graph_fullyzoom(xRect *r,  Graph_ctx *gr, int graph_dataset)
{
  int need_redraw = 0;
  if( sch_waves_loaded() >= 0) {
    if(!gr->digital) {
      int dset;
      int p, v;
      char *bus_msb = NULL;
      int sweep_idx = 0;
      const char *sweep_name = NULL; /* last non-empty `sweep=` token, carried BY NAME */
      double val, start, end;
      double min=0.0, max=0.0;
      int firstyval = 1;
      char *saves, *sptr, *stok, *sweep = NULL, *saven, *nptr, *ntok, *node = NULL;
      int node_dataset = -1; /* dataset specified as %<n> after node/bus/expression name */
      char *ntok_copy = NULL; /* copy of ntok without %<n> */
      char *custom_rawfile = NULL; /* "rawfile" attr. set in graph: load and switch to specified raw */
      char *sim_type = NULL;
      /* per-node, but declared HERE and not in the loop body: the two refusals
       * below leave the loop through the epilogue, and the epilogue can only
       * free what is still in scope at the label (batch F item 2). */
      char *node_rawfile = NULL;
      char *node_sim_type = NULL;
      Raw *raw = NULL;
      char *tmp_ptr = NULL;
      int save_extra_idx = -1;
      int save_prev_idx = -1;   /* the OTHER half of the cursor: where switch_back goes */
      int autoload = 0, save_datasets = -1, save_npoints = -1;
      const char *ptr;

      autoload = !strboolcmp(get_tok_value(r->prop_ptr,"autoload", 0), "true");
      if(autoload == 0) autoload = 2;
      dbg(1, "graph_fullyzoom(): graph_dataset=%d\n", graph_dataset);
      my_strdup2(_ALLOC_ID_, &node, get_tok_value(r->prop_ptr,"node", 0));
      my_strdup2(_ALLOC_ID_, &sweep, get_tok_value(r->prop_ptr,"sweep", 0));

      ptr = get_tok_value(r->prop_ptr,"rawfile", 0);
      if(!ptr[0]) {
        if(xctx->raw && xctx->raw->rawfile) my_strdup2(_ALLOC_ID_, &custom_rawfile, xctx->raw->rawfile);
        else  my_strdup2(_ALLOC_ID_, &custom_rawfile, "");
      } else {
        my_strdup2(_ALLOC_ID_, &custom_rawfile, ptr);
      }

      my_strdup2(_ALLOC_ID_, &sim_type, get_tok_value(r->prop_ptr,"sim_type", 0));

      save_extra_idx = xctx->extra_idx;
      save_prev_idx = xctx->extra_prev_idx;
      nptr = node;
      sptr = sweep;
      start = (gr->gx1 <= gr->gx2) ? gr->gx1 : gr->gx2;
      end = (gr->gx1 <= gr->gx2) ? gr->gx2 : gr->gx1;

      while( (ntok = my_strtok_r(nptr, "\n", "\"", 4, &saven)) ) {
        if(sch_waves_loaded() != -1 && custom_rawfile[0]) {
          if(!extra_rawfile(autoload, custom_rawfile, sim_type[0] ? sim_type : xctx->raw->sim_type, -1.0, -1.0)) {
            goto fullyzoom_done; /* need_redraw stays 0: the refusal is unchanged */
          }
        }
        raw = xctx->raw;
        /* ONE `%` parse, issue 0305.
         * ⚠ THE TWO REFUSALS HERE USED TO BE BARE `return 0`s (batch F item 2).
         * Each hand-copied a subset of the epilogue's my_free()s -- and each got
         * the subset wrong: `ntok_copy` (this walker's only per-entry allocation,
         * handed back by node_token_split() a few lines below) was in neither, so
         * every refused fullyzoom leaked it, and NEITHER restored the database
         * the graph-level `rawfile=` switch above had just switched away from --
         * so a strip whose graph DB resolves and whose per-trace `%<rawfile>`
         * does not left the whole SESSION pointing at the graph's database.
         * Both are now `goto fullyzoom_done`, the function's single exit: a third
         * refusal added later inherits the frees and the restore by construction
         * instead of having to remember them.
         *
         * ⚠ THE TWO REFUSALS ARE NOT SYMMETRIC, and the paragraph above used to
         * over-claim by lumping them (review of the fix round). The GRAPH-level
         * refusal a few lines up can only fire on the FIRST iteration -- the
         * switch it guards is loop-invariant -- so at that point ntok_copy is
         * still NULL, no per-trace switch is outstanding and the old `return 0`
         * there leaked nothing and stranded nothing. Everything above is true of
         * the PER-TRACE refusal (this one). What the graph-level refusal really
         * does leave behind is the OTHER half of the registry cursor: in READ
         * mode (autoload=true) a failed extra_rawfile() sets extra_prev_idx =
         * extra_idx (save.c), moving where `raw switch_back` goes even though
         * the current slot never moved. The epilogue's node_db_prev_restore()
         * puts that back, and NDL3 is the check that watches it -- which is what
         * finally gives the first `goto` behavioural evidence rather than only
         * NDR4/NDR5's structural count. */
        node_token_split(ntok, &ntok_copy, &node_dataset, &node_rawfile, &node_sim_type,
                         node_dflt_sim_type(sim_type));
        if(node_rawfile[0] && raw && raw->values) {
          dbg(1, "node_rawfile=|%s| node_sim_type=|%s|\n", node_rawfile, node_sim_type);
          if(!extra_rawfile(autoload, node_rawfile, node_sim_type, -1.0, -1.0)) {
            goto fullyzoom_done;
          }
          raw = xctx->raw;
        }
        my_free(_ALLOC_ID_, &node_rawfile);
        my_free(_ALLOC_ID_, &node_sim_type);
        dbg(1, "nd=|%s|, node_dataset = %d\n", ntok, node_dataset);

        /* transform multiple OP points into a dc sweep */
        if(raw && raw->sim_type && !strcmp(raw->sim_type, "op") && raw->datasets > 1 && raw->npoints[0] == 1) {
          save_datasets = raw->datasets;
          raw->datasets = 1;
          save_npoints = raw->npoints[0];
          raw->npoints[0] = raw->allpoints;
        }

        dbg(1, "ntok=|%s|\nntok_copy=|%s|\nnode_dataset=%d\n", ntok, ntok_copy, node_dataset);

        tmp_ptr = find_nth(ntok_copy, ";", "\"", 4, 2);
        if(strstr(tmp_ptr, ",")) {
          tmp_ptr = find_nth(tmp_ptr, ",", "\"", 4, 1);
          /* also trim spaces */
          my_strdup2(_ALLOC_ID_, &bus_msb, trim_chars(tmp_ptr, "\n "));
        }
        dbg(1, "ntok_copy=|%s|, bus_msb=|%s|\n", ntok_copy, bus_msb ? bus_msb : "<NULL>");
        stok = my_strtok_r(sptr, "\n\t ", "\"", 0, &saves);
        nptr = sptr = NULL;
        /* the sweep column, re-resolved BY NAME on every entry (batch F item 2,
         * issue 0305) -- see the long note at the same point in draw_graph().
         * A `sweep=` list shorter than the `node=` list carries its last token
         * forward, and a carried column NUMBER was resolved in the previous
         * entry's database: with a cross-DB `%<rawfile>` entry between two
         * graph-DB entries, the wide raw's column 4 was used as the VCD's
         * values[4], an out-of-bounds read. */
        if(stok && stok[0]) sweep_name = stok;
        if(sweep_name && sweep_name[0]) {
          sweep_idx = get_raw_index(sweep_name, NULL);
          if( sweep_idx == -1) sweep_idx = 0;
        }
        if(raw && (sweep_idx < 0 || sweep_idx >= raw->nvars)) sweep_idx = 0;
        dbg(1, "graph_fullyzoom(): ntok_copy=%s\n", ntok_copy);
        v = -1;
        if(!bus_msb) {
          char *express = NULL;
          if(strstr(ntok_copy, ";")) {
            my_strdup2(_ALLOC_ID_, &express, find_nth(ntok_copy, ";", "\"", 0, 2));
          } else {
            my_strdup2(_ALLOC_ID_, &express, ntok_copy);
          }
          if(strpbrk(express, " \n\t")) {
            /* we *need* to recalculate the expression column for any new expression
             * This is *expecially needed if graph contains more than one expression */
            v = calc_custom_data_yrange(sweep_idx, express, gr);
          } else {
            v = get_raw_index(express, NULL);
          }
          my_free(_ALLOC_ID_, &express);
          dbg(1, "graph_fullyzoom(): v=%d\n", v);
        }
        if(xctx->raw && v >= 0) {
          int dataset = node_dataset >=0 ? node_dataset : graph_dataset;
          int sweepvar_wrap = 0; /* incremented on new dataset or sweep variable wrap */
          int ofs = 0, ofs_end;
          for(dset = 0 ; dset < raw->datasets; dset++) {
            double xx, xx0 = 0.0; /* gcc gives false warnings if xx0 not initialized here */
            int cnt=0, wrap;
            register SPICE_DATA *gv = raw->values[sweep_idx];
            register SPICE_DATA *gv0 = raw->values[0];
            ofs_end = ofs + raw->npoints[dset];

            /* optimization: skip unwanted datasets, if no dc no need to detect sweep variable wraps */
            if(dataset >= 0 && strcmp(xctx->raw->sim_type, "dc") && dataset != sweepvar_wrap) goto done;
            for(p = ofs ; p < ofs_end; p++) {
              if(gr->logx) xx = mylog10(gv[p]);
              else xx = gv[p];
              if(p == ofs) xx0 = gv0[p];
              wrap = xctx->raw->sim_type && !strcmp(xctx->raw->sim_type, "dc") && cnt > 1 && gv0[p] == xx0;
              if(wrap) {
                 sweepvar_wrap++;
                 cnt = 0;
              }
              if(dataset == -1 || dataset == sweepvar_wrap) {
                /* dbg(1, "graph_fullyzoom(): dataset=%d node=%s\n", dataset, raw->names[v]); */
                if( xx >= start && xx <= end) {
                  if(gr->logy)
                    val =mylog10(raw->values[v][p]);
                  else
                    val = raw->values[v][p];
                  if(firstyval || val < min) min = val;
                  if(firstyval || val > max) max = val;
                  firstyval = 0;
                }
              }
              if(xx >= start && xx <= end) {
                ++cnt;
              }
            } /* for(p = ofs ; p < ofs + raw->npoints[dset]; p++) */

            done:

            /* offset pointing to next dataset */
            ofs = ofs_end;
            sweepvar_wrap++;
          } /* for(dset...) */
        }
        if(bus_msb) my_free(_ALLOC_ID_, &bus_msb);
        if(save_npoints != -1) { /* restore multiple OP points from artificial dc sweep */
          raw->datasets = save_datasets;
          raw->npoints[0] = save_npoints;
        }
        node_db_restore(save_extra_idx);
        raw = xctx->raw;

      } /* while( (ntok = my_strtok_r(nptr, "\n\t ", "\"", 0, &saven)) ) */
      if(max == min) max += 0.01;
      min = floor_to_n_digits(min, 2);
      max = ceil_to_n_digits(max, 2);
      my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y1", dtoa(min)));
      my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "y2", dtoa(max)));
      need_redraw = 1;

      /* THE ONE EPILOGUE (batch F item 2). Every exit from the node walk above
       * lands here, so the database restore and the eight my_free()s exist once.
       * node_db_restore() is a no-op when nothing moved, and my_free() is a
       * no-op on a NULL pointer, so the label is reached safely from a refusal
       * on the very first entry as well as from the normal end of the walk. */
      fullyzoom_done:
      node_db_restore(save_extra_idx);
      node_db_prev_restore(save_prev_idx);
      my_free(_ALLOC_ID_, &node);
      my_free(_ALLOC_ID_, &sweep);
      my_free(_ALLOC_ID_, &custom_rawfile);
      my_free(_ALLOC_ID_, &sim_type);
      my_free(_ALLOC_ID_, &node_rawfile);
      my_free(_ALLOC_ID_, &node_sim_type);
      my_free(_ALLOC_ID_, &bus_msb);
      my_free(_ALLOC_ID_, &ntok_copy);
    } else { /* digital plot */
      my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos1",
         get_tok_value(r->prop_ptr, "y1", 0) ));
      my_strdup(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ypos2",
         get_tok_value(r->prop_ptr, "y2", 0) ));
      need_redraw = 1;
    }
    return need_redraw;
  } else {
   return 0;
  }
}

/* draw bussed signals: ntok is a comma separated list of items, first item is bus name,
 * following are bits that are bundled together:
   LDA,LDA[3],LDA[2],LDA1],LDA[0]
 */
static void draw_graph_bus_points(const char *ntok, int n_bits, SPICE_DATA **idx_arr,
         int first, int last, int wave_col, int sweep_idx, int wcnt, int n_nodes, Graph_ctx *gr, void *ct)
{
  int p;
  double s1 = DIG_NWAVES; /* 1/DIG_NWAVES  waveforms fit in graph if unscaled vertically */
  double s2 = DIG_SPACE; /* (DIG_NWAVES - DIG_SPACE) spacing between traces */
  double c = (n_nodes - wcnt) * s1 * gr->gh - gr->gy1 * s2; /* trace baseline */
  double c1 = c + gr->gh * 0.5 * s2; /* trace y-center, used for clipping */
  double lx1;
  double lx2;
  double ylow  = DW_Y(c + gr->gy2 * s2); /* swapped as xschem Y coordinates are top-bottom */
  double yhigh = DW_Y(c + gr->gy1 * s2);
  char busval[1024], old_busval[1024];
  double xval=0.0, xval_old=0.0;
  double ydelta = fabs(yhigh - ylow);
  double labsize = 0.015 * ydelta;
  double charwidth = labsize * 38.0;
  double x_size = 1.5 * xctx->zoom;
  double vthh = gr->gy1 * 0.2 + gr->gy2 * 0.8;
  double vthl = gr->gy1 * 0.8 + gr->gy2 * 0.2;
  int hex_digits = ((n_bits - 1) >> 2) + 1;
  Raw *raw = xctx->raw;

  if(!raw) {
    dbg(0, "draw_graph_bus_points(): no raw struct allocated\n");
    return;
  }
  for(p=0;p<cadlayers; ++p) {
    XSetLineAttributes(display, xctx->gc[p],
       XLINEWIDTH(gr->linewidth_mult * xctx->lw), LineSolid, LINECAP, LINEJOIN);
  }
  if(gr->logx) {
    lx1 = W_X(mylog10(raw->values[sweep_idx][first]));
    lx2 = W_X(mylog10(raw->values[sweep_idx][last]));
  } else {
    lx1 = W_X(raw->values[sweep_idx][first]);
    lx2 = W_X(raw->values[sweep_idx][last]);
  }
  if(c1 >= gr->ypos1 && c1 <=gr->ypos2) {
    set_thick_waves(1, wcnt, wave_col, gr);
    drawline(wave_col, NOW, lx1, ylow, lx2, ylow, 0.0, 0, ct);
    drawline(wave_col, NOW, lx1, yhigh, lx2, yhigh, 0.0, 0, ct);
    for(p = first ; p <= last; p++) {
      /* calculate value of bus by adding all binary bits */
      /* hex_digits = */
      get_bus_value(n_bits, hex_digits, idx_arr, p, busval, vthl, vthh);
      if(gr->logx) {
        xval =  W_X(mylog10(raw->values[sweep_idx][p]));
      } else {
        xval =  W_X(raw->values[sweep_idx][p]);
      }
      /* used to draw bus value before 1st transition */
      if(p == first) {
        my_strncpy(old_busval, busval, hex_digits+1);
        xval_old = xval;
      }
      if(p > first &&  strcmp(busval, old_busval)) {
        /* draw transition ('X') */
        drawline(BACKLAYER, NOW, xval-x_size, yhigh, xval+x_size, yhigh, 0.0, 0, ct);
        drawline(BACKLAYER, NOW, xval-x_size, ylow,  xval+x_size, ylow, 0.0, 0, ct);
        drawline(wave_col, NOW, xval-x_size, ylow,  xval+x_size, yhigh, 0.0, 0, ct);
        drawline(wave_col, NOW, xval-x_size, yhigh, xval+x_size, ylow, 0.0, 0, ct);
        /* draw hex bus value if there is enough room */
        if(  fabs(xval - xval_old) > hex_digits * charwidth) {
          draw_string(wave_col, NOW, old_busval, 2, 0, 1, 0, (xval + xval_old) * 0.5,
                      yhigh, labsize, labsize);
        }
        my_strncpy(old_busval, busval, hex_digits + 1);
        xval_old = xval;
      } /* if(p > first &&  busval != old_busval) */
    } /* for(p = first ; p < last; p++) */
    /* draw hex bus value after last transition */
    if(  fabs(xval - xval_old) > hex_digits * charwidth) {
      draw_string(wave_col, NOW, old_busval, 2, 0, 1, 0, (xval + xval_old) * 0.5,
                  yhigh, labsize, labsize);
    }
    set_thick_waves(0, wcnt, wave_col, gr);
  }
  for(p=0;p<cadlayers; ++p) {
    XSetLineAttributes(display, xctx->gc[p], XLINEWIDTH(xctx->lw), LineSolid, LINECAP , LINEJOIN);
  }
}

#define MAX_POLY_POINTS 4096*16
/* wcnt is the nth wave in graph, idx is the index in spice raw file */
static void draw_graph_points(int idx, int first, int last,
         XPoint *point, int wave_col, int wcnt, int n_nodes, Graph_ctx *gr, void *ct)
{
  int p, x;
  register double yy;
  register int digital;
  int poly_npoints = 0;
  double s1;
  double s2;
  double c = 0 /* , c1 */;
  Raw *raw = xctx->raw;
  register SPICE_DATA *gv;
  /* viewer plan item 6: the mid-drag shrink preview of THIS trace. Same
   * selection test set_thick_waves uses, on the same index space. */
  int preview = 0;
  double prev_c = 0.0, prev_cx = 0.0, prev_s = 1.0;
  short *prev_savex = NULL; /* the un-shrunk x values, restored after drawing */

  if(!raw) {
    dbg(0, "draw_graph_points(): no raw struct allocated\n");
    return;
  }
  dbg(1, "draw_graph_points: idx=%d, first=%d, last=%d, wcnt=%d\n", idx, first, last, wcnt);
  /* idx == -1 is "the expression was rejected / the vector does not exist" --
   * plot_raw_custom_data() returns it for an unresolvable token (spec
   * doc/claude/specs/calculator.md section 3.1) and, since issue 0325, for a
   * negative del() delay too. The load below MUST stay under the guard: with
   * idx == -1 `raw->values[idx]` is an 8-byte read one element BEFORE the
   * values[] pointer array, which valgrind flags as an Invalid read on every
   * redraw of such a graph. Issue 0325. */
  if(idx == -1) return;
  gv = raw->values[idx];
  for(p=0;p<cadlayers; ++p) {
    if(gr->mode == 1 || gr->mode == 2) { /* Histograms */
      XSetLineAttributes(display, xctx->gc[p],
         XLINEWIDTH(gr->linewidth_mult * xctx->lw), LineSolid, xCap , xJoin);
    } else {
      XSetLineAttributes(display, xctx->gc[p],
         XLINEWIDTH(gr->linewidth_mult * xctx->lw), LineSolid, LINECAP , LINEJOIN);
    }
  }
  digital = gr->digital;
  /* Shrink about the PLOT BOX's vertical centre, in SCREEN units.
   * ⚠ gr->cy is NEGATIVE (landmine 3), so S_Y(gy1) and S_Y(gy2) come back in
   * the opposite order to their data values -- taking the MEAN sidesteps the
   * ordering entirely rather than assuming it.
   * Analog only: the arming query (graph_wave_at) refuses digital strips, so a
   * digital trace can never be picked up and never previewed; scaling one about
   * the box centre would also drag it out of its own lane.
   * Issue 0192: the membership question is graph_preview_has()'s, the ONE
   * draw-side predicate; gr->preview_gi only says whether THIS graph is
   * chrome-enabled at all (-1 = no), so nothing walks the set at rest. */
  if(!digital && gr->preview_gi >= 0 && graph_preview_has(gr->preview_gi, wcnt)) {
    preview = 1;
    prev_c  = (S_Y(gr->gy1) + S_Y(gr->gy2)) * 0.5;
    prev_cx = (S_X(gr->gx1) + S_X(gr->gx2)) * 0.5;
    prev_s = xctx->graph_preview_scale;
  }
  if(digital) {
    s1 = DIG_NWAVES; /* 1/DIG_NWAVES  waveforms fit in graph if unscaled vertically */
    s2 = DIG_SPACE; /* (DIG_NWAVES - DIG_SPACE) spacing between traces */
    c = (n_nodes - wcnt) * s1 * gr->gh - gr->gy1 * s2; /* trace baseline */
    /* c1 = c + gr->gh * 0.5 * s2; */ /* trace y-center, used for clipping */
  }
  /* below condition seems no more necessary as a clip is set via bbox(SET...) */
  /* if( 1 || !digital || (c1 >= gr->ypos1 && c1 <= gr->ypos2) ) { */
  for(p = first ; p <= last; p++) {
    yy = gv[p];

    /* Below CLIP calls (for digital and non digital graphs) for Windows
     * clamp y-value of waves to be inside graph area. Not a clean solution
     * but avoids drawing outside of graph area when moving vertically on Windows
     * platform where is no XSetClipRectangles()
     * waveform points outise graph are drawn as a line on top or bottom of graph
     * <<<<< FIXME: remove these points completely
     */
    if(digital) {
      yy = c + yy *s2;
      #if !defined(__unix__)
      yy = CLIP(DS_Y(yy), Y_TO_SCREEN(gr->y1), Y_TO_SCREEN(gr->y2));
      #else
      yy = CLIP(DS_Y(yy), -30000, 30000); /* only clip to 16 bit signed short limits */
      #endif
      /* Build poly y array. Translate from graph coordinates to screen coordinates  */
      point[poly_npoints].y = (short)yy;
    } else {
      /* Build poly y array. Translate from graph coordinates to screen coordinates  */
      if(gr->logy) yy = mylog10(yy);
      yy = S_Y(yy);
      /* item 6: scale BEFORE the clamp. A rail-clamped sample scaled afterwards
       * would shrink from the rail instead of from its true position and put a
       * visible kink where the trace leaves the box. */
      if(preview) yy = prev_c + (yy - prev_c) * prev_s;
      #if !defined(__unix__)
      yy = CLIP(yy, Y_TO_SCREEN(gr->y1), Y_TO_SCREEN(gr->y2));
      #else
      yy = CLIP(yy, -30000, 30000); /* only clip to 16 bit signed short limits */
      #endif
      point[poly_npoints].y = (short)yy;
    }
    poly_npoints++;
  }
  /* item 6: the X half of the shrink (review 2026-07-29: "shrink in both X and
   * Y, not just Y"). Y is scaled per sample in the loop above because this
   * function owns the y array; X is NOT ours -- point[].x is built by the
   * caller and, unlike y, is not necessarily rewritten for every wave. So it is
   * scaled IN PLACE and restored verbatim below from the saved shorts, which is
   * exact (no inverse-transform rounding) and safe however the caller reuses the
   * array. One allocation per drawn frame of one dragged trace. */
  if(preview && poly_npoints > 0) {
    prev_savex = my_malloc(_ALLOC_ID_, (size_t)poly_npoints * sizeof(short));
    if(prev_savex) {
      for(p = 0; p < poly_npoints; p++) {
        prev_savex[p] = point[p].x;
        point[p].x = (short)CLIP(prev_cx + (point[p].x - prev_cx) * prev_s,
                                 -30000, 30000);
      }
    }
  }
  set_thick_waves(1, wcnt, wave_col, gr);
  if(digital || gr->mode == 0) { /* Line */
    for(x = 0; x < 2; x++) {
      Drawable  w;
      int offset = 0, size;
      XPoint *pt = point;
      if(x == 0 && xctx->draw_window) w = xctx->window;
      else if(x == 1 && xctx->draw_pixmap) w = xctx->save_pixmap;
      else continue;
      while(1) {
        pt =  point + offset;
        size = poly_npoints - offset;
        if(size > MAX_POLY_POINTS) size = MAX_POLY_POINTS;
        /* dbg(0, "draw_graph_points(): drawing from %d, size %d\n", offset, size);*/
        XDrawLines(display, w, xctx->gc[wave_col], pt, size, CoordModeOrigin);
        if(offset + size >= poly_npoints) break;
        offset += MAX_POLY_POINTS -1; /* repeat last point on next iteration */
      }
    }
  }
  else if(gr->mode == 1) { /* HistoV */
    int y2 = (int)S_Y(0.0);
    for(x = 0; x < 2; x++) {
      Drawable  w;
      if(x == 0 && xctx->draw_window) w = xctx->window;
      else if(x == 1 && xctx->draw_pixmap) w = xctx->save_pixmap;
      else continue;
      for(p = 0; p < poly_npoints; p++) {
        if(point[p].y < y2) {
          XDrawLine(display, w, xctx->gc[wave_col], point[p].x, point[p].y, point[p].x, y2);
        }
      }
    }
  }

  else if(gr->mode == 2) { /* HistoH */
    int x1 = (int)S_X(0.0);
    for(x = 0; x < 2; x++) {
      Drawable  w;
      if(x == 0 && xctx->draw_window) w = xctx->window;
      else if(x == 1 && xctx->draw_pixmap) w = xctx->save_pixmap;
      else continue;
      for(p = 0; p < poly_npoints; p++) {
        if(point[p].x > x1) {
          XDrawLine(display, w, xctx->gc[wave_col], x1, point[p].y, point[p].x, point[p].y);
        }
      }
    }
  }

  set_thick_waves(0, wcnt, wave_col, gr);
  /* item 6: hand the caller's x array back exactly as it was found */
  if(prev_savex) {
    for(p = 0; p < poly_npoints; p++) point[p].x = prev_savex[p];
    my_free(_ALLOC_ID_, &prev_savex);
  }
  /* } else dbg(1, "skipping wave: %s\n", raw->names[idx]); */
  for(p=0;p<cadlayers; ++p) {
    XSetLineAttributes(display, xctx->gc[p], XLINEWIDTH(xctx->lw), LineSolid, LINECAP , LINEJOIN);
  }
}

static void draw_graph_grid(Graph_ctx *gr, void *ct)
{
  double deltax, startx, deltay, starty, wx,wy,  dash_size;
  int j, k;
  int dash_on, dash_off;
  double mark_size = gr->marginy/10.0;

  /* calculate dash length for grid lines */
  dash_size = 1.5 * xctx->mooz;
  dash_size = dash_size < 1.0 ? 0.0: (dash_size > 3.0 ? 3.0 : 2.0);
  /* viewer plan item 2 (decision D-B): "the grid is too heavy -- halve its
   * pixel density". Of the three readings, the chosen one keeps EVERY grid line
   * and its colour and halves the DUTY CYCLE instead. XSetDashes here has
   * always been called with a 1-element list, which makes the on-run and the
   * off-run equal -- a 50% duty cycle. `griddash` (per-rect, viewer-only) is
   * the OFF run against a 1-pixel ON run, so griddash=3 gives 1-on/3-off: the
   * same 4-pixel period, half the lit pixels.
   * dash_on stays 0 when dash_size is 0 -- at that zoom the grid is solid, and
   * a solid line has no duty cycle to halve. */
  /* viewer plan item 3: `grid=0` (Ctrl-G) suppresses the DASHED LINES ONLY.
   * The background, the bounding box, the tick marks, the axis NUMBERS and the
   * zero lines are all drawn by this function too and all survive -- a plot
   * with no readable axis is not a useful thing to toggle to. The plan said
   * "gate draw_graph_grid's body"; that would have taken the numbers with it. */
  dash_on = (int)dash_size;
  dash_off = (int)dash_size;
  if(gr->griddash > 0 && dash_on > 0) {
    dash_on = 1;
    dash_off = gr->griddash;
  }

  /* clipping everything outside container area */
  /* background */
  filledrect(0, NOW, gr->rx1, gr->ry1, gr->rx2, gr->ry2, 2, -1, -1);
  /* graph bounding box */
  drawrect(GRIDLAYER, NOW, gr->rx1, gr->ry1, gr->rx2, gr->ry2, 0.0, 2, -1, -1);

  bbox(START, 0.0, 0.0, 0.0, 0.0);
  bbox(ADD, gr->rx1, gr->ry1, gr->rx2, gr->ry2);
  bbox(SET_INSIDE, 0.0, 0.0, 0.0, 0.0);
  /* vertical grid lines */
  deltax = axis_increment(gr->gx1, gr->gx2, gr->divx, (gr->logx));
  startx = axis_start(gr->gx1, deltax, gr->divx);
  for(j = -1;; ++j) { /* start one interval before to allow sub grids at beginning */
    wx = startx + j * deltax;
    if(gr->subdivx > 0) for(k = 1; k <=gr->subdivx; ++k) {
      double subwx;
      if(gr->logx)
        subwx = wx + deltax * mylog10(1.0 + (double)k * 9.0 / ((double)gr->subdivx + 1.0));
      else
        subwx = wx + deltax * (double)k / ((double)gr->subdivx + 1.0);
      if(!axis_within_range(subwx, gr->gx1, gr->gx2, deltax, gr->subdivx)) continue;
      if(axis_end(subwx, deltax, gr->gx2)) break;
      if(gr->grid)
        drawline_duty(GRIDLAYER, ADD, W_X(subwx),   W_Y(gr->gy2), W_X(subwx),   W_Y(gr->gy1), 0.0, dash_on, dash_off, ct);
    }
    if(!axis_within_range(wx, gr->gx1, gr->gx2, deltax, gr->subdivx)) continue;
    if(axis_end(wx, deltax, gr->gx2)) break;
    /* swap order of gy1 and gy2 since grap y orientation is opposite to xorg orientation */
    if(gr->grid)
      drawline_duty(GRIDLAYER, ADD, W_X(wx),   W_Y(gr->gy2), W_X(wx),   W_Y(gr->gy1), 0.0, dash_on, dash_off, ct);
    drawline(GRIDLAYER, ADD, W_X(wx),   W_Y(gr->gy1), W_X(wx),   W_Y(gr->gy1) + mark_size, 0.0, 0, ct); /* axis marks */
    /* X-axis labels */
    if(gr->logx)
      draw_string(3, NOW, dtoa_eng(pow(10, wx) * gr->unitx, 5), 0, 0, 1, 0, W_X(wx),
                gr->y2 + mark_size + 5 * gr->txtsizex, gr->txtsizex, gr->txtsizex);
    else
      draw_string(3, NOW, dtoa_eng(wx * gr->unitx, 5), 0, 0, 1, 0, W_X(wx), gr->y2 + mark_size + 5 * gr->txtsizex,
                gr->txtsizex, gr->txtsizex);
  }
  /* first and last vertical box delimiters */
  drawline(GRIDLAYER, ADD, W_X(gr->gx1),   W_Y(gr->gy2), W_X(gr->gx1),   W_Y(gr->gy1), 0.0, 0, ct);
  drawline(GRIDLAYER, ADD, W_X(gr->gx2),   W_Y(gr->gy2), W_X(gr->gx2),   W_Y(gr->gy1), 0.0, 0, ct);
  /* horizontal grid lines */
  if(!gr->digital) {
    deltay = axis_increment(gr->gy1, gr->gy2, gr->divy, gr->logy);
    starty = axis_start(gr->gy1, deltay, gr->divy);
    /* start one interval before to allow sub grids at beginning */
    for(j = -1; gr->gy1 == gr->gy1 && gr->gy2 == gr->gy2; ++j) { /* gy1 and gy2 are not NaN */
      wy = starty + j * deltay;
      if(gr->subdivy > 0) for(k = 1; k <=gr->subdivy; ++k) {
        double subwy;
        if(gr->logy)
          subwy = wy + deltay * mylog10(1.0 + (double)k * 9.0 / ((double)gr->subdivy + 1.0));
        else
          subwy = wy + deltay * (double)k / ((double)gr->subdivy + 1.0);
        if(!axis_within_range(subwy, gr->gy1, gr->gy2, deltay, gr->subdivy)) continue;
        if(axis_end(subwy, deltay, gr->gy2)) break;
        if(gr->grid)
          drawline_duty(GRIDLAYER, ADD, W_X(gr->gx1), W_Y(subwy),   W_X(gr->gx2), W_Y(subwy), 0.0, dash_on, dash_off, ct);
      }
      if(!axis_within_range(wy, gr->gy1, gr->gy2, deltay, gr->subdivy)) continue;
      if(axis_end(wy, deltay, gr->gy2)) break;
      if(gr->grid)
        drawline_duty(GRIDLAYER, ADD, W_X(gr->gx1), W_Y(wy),   W_X(gr->gx2), W_Y(wy), 0.0, dash_on, dash_off, ct);
      drawline(GRIDLAYER, ADD, W_X(gr->gx1) - mark_size, W_Y(wy),   W_X(gr->gx1), W_Y(wy), 0.0, 0, ct); /* axis marks */
      /* Y-axis labels */
      if(gr->logy)
        draw_string(3, NOW, dtoa_eng(pow(10, wy) * gr->unity, 5), 0, 1, 0, 1,
                  gr->x1 - mark_size - 5 * gr->txtsizey, W_Y(wy), gr->txtsizey, gr->txtsizey);
      else
        draw_string(3, NOW, dtoa_eng(wy * gr->unity, 5), 0, 1, 0, 1, gr->x1 - mark_size - 5 * gr->txtsizey, W_Y(wy),
                  gr->txtsizey, gr->txtsizey);
    }
  }
  /* first and last horizontal box delimiters */
  drawline(GRIDLAYER, ADD, W_X(gr->gx1),   W_Y(gr->gy1), W_X(gr->gx2),   W_Y(gr->gy1), 0.0, 0, ct);
  drawline(GRIDLAYER, ADD, W_X(gr->gx1),   W_Y(gr->gy2), W_X(gr->gx2),   W_Y(gr->gy2), 0.0, 0, ct);
  /* Horizontal axis (if in viewport) */
  if(!gr->digital && gr->gy1 <= 0 && gr->gy2 >= 0)
    drawline(GRIDLAYER, ADD, W_X(gr->gx1), W_Y(0), W_X(gr->gx2), W_Y(0), 0.0, 0, ct);
  /* Vertical axis (if in viewport)
   * swap order of gy1 and gy2 since grap y orientation is opposite to xorg orientation */
  if(gr->gx1 <= 0 && gr->gx2 >= 0)
    drawline(GRIDLAYER, ADD, W_X(0),   W_Y(gr->gy2), W_X(0),   W_Y(gr->gy1), 0.0, 0, ct);
  drawline(GRIDLAYER, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, ct);
  bbox(END, 0.0, 0.0, 0.0, 0.0);
}

void setup_graph_data(int i, int skip, Graph_ctx *gr)
{
  double tmp;
  const char *val;
  xRect *r = &xctx->rect[GRIDLAYER][i];

  dbg(1, "setup_graph_data: i=%d\n", i);
  /* default values */
  gr->magx = gr->magy = gr->maglegend = 1.0;
  gr->divx = gr->divy = 5;
  gr->subdivx = gr->subdivy = 0;
  gr->logx = gr->logy = 0;
  gr->digital = 0;
  gr->rainbow = 0;
  /* issue 0151: ASE viewer target-strip marker. Defaulted (and parsed) HERE,
   * BEFORE the RECT_OUTSIDE early return below: gr is the SHARED
   * xctx->graph_struct reused for every graph, so an off-screen graph that
   * returned early would otherwise inherit the previous graph's value. */
  gr->active = 0;
  val = get_tok_value(r->prop_ptr,"active", 0);
  if(val[0]) gr->active = atoi(val);
  /* viewer plan item 6: the mid-drag shrink preview. NOT a prop token — it is
   * armed from xctx by draw_graph, which is the only caller that knows the
   * flags. Defaulted here, before the RECT_OUTSIDE early return, for exactly
   * the same shared-graph_struct reason as `active` above: without it a QUERY
   * that calls setup_graph_data (graph_point_at, graph_plotbox_at, ...) would
   * leave the previous graph's preview armed in the shared struct.
   * Issue 0192: the field now holds the RECT INDEX this draw may preview rather
   * than a node index, but the default and its position are unchanged and still
   * load-bearing for exactly that reason. */
  gr->preview_gi = -1;
  /* strip drag-reorder affordance: 1 = grip, 2 = grip + TOP drop bar,
   * 3 = grip + BOTTOM drop bar. Same early-default rule as `active` above and
   * for the same reason (shared xctx->graph_struct, off-screen early return). */
  gr->reorder_handle = 0;
  val = get_tok_value(r->prop_ptr,"reorder_handle", 0);
  if(val[0]) gr->reorder_handle = atoi(val);
  /* viewer plan item 1: draw EVERY legend entry bold, not just the bolded
   * wave's. A per-rect token, not a global, for the D-G blast-radius reason:
   * draw_graph_variables is shared by every graph in the tree including ~127
   * shipped schematics with embedded graphs, and only the ASE viewer template
   * emits this. Same early-default rule as `active`/`reorder_handle` above and
   * for the same reason (shared xctx->graph_struct, off-screen early return). */
  gr->legendbold = 0;
  val = get_tok_value(r->prop_ptr,"legendbold", 0);
  if(val[0]) gr->legendbold = atoi(val);
  /* viewer plan item 2 (D-B): grid dash OFF run. Same early-default rule and
   * the same reason as the three tokens above -- shared xctx->graph_struct,
   * off-screen early return. Clamped to what XSetDashes can carry (a dash
   * element is an unsigned char and must be non-zero); 0 = shipped pattern. */
  gr->griddash = 0;
  val = get_tok_value(r->prop_ptr,"griddash", 0);
  if(val[0]) gr->griddash = atoi(val);
  if(gr->griddash < 0 || gr->griddash > 32) gr->griddash = 0;
  /* viewer plan item 3: grid on/off (Ctrl-G in the viewer). DEFAULT 1 -- an
   * absent token must mean "draw the grid", or every schematic graph in the
   * tree would lose its grid. Same early-default rule as the tokens above. */
  gr->grid = 1;
  val = get_tok_value(r->prop_ptr,"grid", 0);
  if(val[0]) gr->grid = atoi(val) ? 1 : 0;
  gr->linewidth_mult = tclgetdoublevar("graph_linewidth_mult");
  xctx->graph_flags &= ~(128 | 256); /* clear hcursor flags */
  gr->hcursor1_y = gr->hcursor2_y = 0.0;
  val = get_tok_value(r->prop_ptr,"hcursor1_y", 0);
  if(val[0]) {
    gr->hcursor1_y = atof_eng(val);
    xctx->graph_flags |= 128;
  }
  val = get_tok_value(r->prop_ptr,"hcursor2_y", 0);
  if(val[0]) {
    gr->hcursor2_y = atof_eng(val);
    xctx->graph_flags |= 256;
  }
  if(!skip) {
    gr->gx1 = 0;
    gr->gx2 = 1e-6;
    val = get_tok_value(r->prop_ptr,"x1", 0);
    if(val[0]) gr->gx1 = atof_eng(val);
    val = get_tok_value(r->prop_ptr,"x2", 0);
    if(val[0]) gr->gx2 = atof_eng(val);
    if(gr->gx1 == gr->gx2) gr->gx2 += 1e-6;
    gr->gw = gr->gx2 - gr->gx1;
  }
  gr->gy1 = 0;
  gr->gy2 = 5;
  gr->dataset = -1; /* -1 means 'plot all datasets' */
  gr->ypos1 = 0;
  gr->ypos2 = 2;
  gr->digtxtsizelab = 0.3;
  gr->txtsizelab = 0.3;
  gr->txtsizex = 0.3;
  gr->txtsizey = 0.3;
  gr->txtsizelegend = 0.3;

  /* container (embedding rectangle) coordinates */
  gr->rx1 = r->x1;
  gr->ry1 = r->y1;
  gr->rx2 = r->x2;
  gr->ry2 = r->y2;

  /* screen position */
  gr->sx1=X_TO_SCREEN(gr->rx1);
  gr->sy1=Y_TO_SCREEN(gr->ry1);
  gr->sx2=X_TO_SCREEN(gr->rx2);
  gr->sy2=Y_TO_SCREEN(gr->ry2);

  if(RECT_OUTSIDE(gr->sx1, gr->sy1, gr->sx2, gr->sy2,
                  xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2)) return;

  gr->rw = gr->rx2 - gr->rx1;
  gr->rh = gr->ry2 - gr->ry1;

  /* wave to display in bold, -1=none */
  val=get_tok_value(r->prop_ptr,"hilight_wave", 0);
  if(val[0]) gr->hilight_wave = atoi(val);
  else gr->hilight_wave = -1;
  /* ... and the REST of the selection when there is more than one (issue 0175).
   * Parsed right beside hilight_wave and therefore under the same caveat: this
   * is BELOW the RECT_OUTSIDE early return (landmine 37a), so an off-screen
   * graph leaves both fields holding the previous graph's values -- harmless
   * because draw_graph draws nothing for such a graph, and true of hilight_wave
   * since long before this. graph_sel_waves_get() re-reads the tokens off the
   * RECT for anything that must be right off-screen too.
   *
   * It is deliberately NOT collapsed to "0 when there is only one": a
   * hand-edited `sel_waves=3 hilight_wave=-1` must render node 3 bold, i.e. the
   * PARSE has to win over the scalar wherever the two disagree, and the
   * one-element case is exactly where that shows. */
  gr->n_sel_waves = graph_sel_waves_get(i, gr->sel_wave, GRAPH_MAX_SEL_WAVES);

  /* legend */
  gr->legend = 1;
  val = get_tok_value(r->prop_ptr,"legend", 0);
  if(val[0]) gr->legend = atoi(val);
  gr->vlegend = 0;
  val = get_tok_value(r->prop_ptr,"vlegend", 0);
  if(val[0]) gr->vlegend = atoi(val);

  /* draw mode (0: Line, 1: Histo. Default: Line) */
  val = get_tok_value(r->prop_ptr,"mode", 0);
  if(!strcmp(val, "HistoV")) gr->mode = 1;
  else if(!strcmp(val, "HistoH")) gr->mode = 2;
  else gr->mode = 0;

  /* get x/y range, grid info etc */
  val = get_tok_value(r->prop_ptr,"unitx", 0);
  gr->unitx_suffix = val[0];
  gr->unitx = get_unit(val);
  val = get_tok_value(r->prop_ptr,"unity", 0);
  if(gr->logx) { /* AC */
    gr->unity_suffix = '1';
    gr->unity = 1.0;
  } else {
    gr->unity_suffix = val[0];
    gr->unity = get_unit(val);
  }
  val = get_tok_value(r->prop_ptr,"xlabmag", 0);
  if(val[0]) gr->magx = atof(val);
  val = get_tok_value(r->prop_ptr,"ylabmag", 0);
  if(val[0]) gr->magy = atof(val);
  val = get_tok_value(r->prop_ptr,"legendmag", 0);
  if(val[0]) gr->maglegend = atof(val);
  val = get_tok_value(r->prop_ptr,"subdivx", 0);
  if(val[0]) gr->subdivx = atoi(val);
  val = get_tok_value(r->prop_ptr,"subdivy", 0);
  if(val[0]) gr->subdivy = atoi(val);
  val = get_tok_value(r->prop_ptr,"divx", 0);
  if(val[0]) gr->divx = atoi(val);
  if(gr->divx < 1) gr->divx = 1;
  val = get_tok_value(r->prop_ptr,"divy", 0);
  if(val[0]) gr->divy = atoi(val);
  if(gr->divy < 1) gr->divy = 1;
  val = get_tok_value(r->prop_ptr,"linewidth_mult", 0);
  if(val[0]) gr->linewidth_mult = atof(val);
  val = get_tok_value(r->prop_ptr,"rainbow", 0);
  if(val[0] == '1') gr->rainbow = 1;
  val = get_tok_value(r->prop_ptr,"logx", 0);
  if(val[0] == '1') gr->logx = 1;
  val = get_tok_value(r->prop_ptr,"logy", 0);
  if(val[0] == '1') gr->logy = 1;
  val = get_tok_value(r->prop_ptr,"y1", 0);
  if(val[0]) gr->gy1 = atof_eng(val);
  val = get_tok_value(r->prop_ptr,"y2", 0);
  if(val[0]) gr->gy2 = atof_eng(val);
  if(gr->gy1 == gr->gy2) gr->gy2 += 1.0;
  val = get_tok_value(r->prop_ptr,"digital", 0);
  if(val[0]) gr->digital = atoi(val);
  if(gr->digital) {
    val = get_tok_value(r->prop_ptr,"ypos1", 0);
    if(val[0]) gr->ypos1 = atof_eng(val);
    val = get_tok_value(r->prop_ptr,"ypos2", 0);
    if(val[0]) gr->ypos2 = atof_eng(val);
    if(gr->ypos2 == gr->ypos1) gr->ypos2 += 1.0;
  }
  gr->posh = gr->ypos2 - gr->ypos1;

  /* plot single dataset */
  val = get_tok_value(r->prop_ptr,"dataset", 0);
  if(val[0]) gr->dataset = atoi(val);
  gr->gh = gr->gy2 - gr->gy1;
  /* set margins */
  tmp = gr->rw * 0.14;
  gr->marginx = tmp;
  tmp = gr->rh * 0.14;
  gr->marginy = tmp;
  /* calculate graph bounding box (container - margin)
   * This is the box where plot is done */
  gr->x1 =  gr->rx1 + gr->marginx;
  gr->x2 =  gr->rx2 - gr->marginx * 0.35; /* less space for right margin */
  if(gr->digital) gr->y1 = gr->ry1 + gr->marginy * 0.4; /* less top space for digital graphs */
  else {
    if(gr->vlegend) gr->y1 =  gr->ry1 + gr->marginy / 3.0;
    else            gr->y1 =  gr->ry1 + gr->marginy;
  }
  gr->y2 =  gr->ry2 - gr->marginy;
  gr->w = gr->x2 - gr->x1;
  gr->h = gr->y2 - gr->y1;

  /* label text size calculations */
  gr->txtsizelab = gr->marginy * 0.006;
  /*
   * tmp =  gr->w * 0.00044;
   * if(tmp < gr->txtsizelab) gr->txtsizelab = tmp;
   */
  tmp = gr->posh;
  if(tmp < gr->gh * 1.4) tmp = gr->gh * 1.4; /* limit value so wave labels don't grow too much in size */
  if(xctx->graph_flags & 2)
    gr->digtxtsizelab = 0.000900 * fabs( gr->h / tmp * gr->gh );
  else
    gr->digtxtsizelab = 0.001200 * fabs( gr->h / tmp * gr->gh );
  gr->txtsizelab *= gr->maglegend;

  /* x axis, y axis text sizes */
  gr->txtsizey = gr->h / gr->divy * 0.0095;
  tmp = gr->marginx * 0.004;
  if(tmp < gr->txtsizey) gr->txtsizey = tmp;
  /* tmp = gr->marginy * 0.02;
   * if(tmp < gr->txtsizey) gr->txtsizey = tmp;
   */
  gr->txtsizey *= gr->magy;

  gr->txtsizex = gr->w / gr->divx * 0.0070;
  tmp = gr->marginy * 0.0065;
  if(tmp < gr->txtsizex) gr->txtsizex = tmp;
  gr->txtsizex *= gr->magx;

  /* signal names (vertical legend) size. */
  gr->txtsizelegend = gr->h * 0.00095;
  gr->txtsizelegend *= gr->maglegend;
  dbg(1, "setup_graph_data(): txtsizelegend=%g, maglegend=%g\n", gr->txtsizelegend, gr->maglegend);

  /* cache coefficients for faster graph --> xschem coord transformations */
  gr->cx = gr->w / gr->gw;
  gr->dx = gr->x1 - gr->gx1 * gr->cx;
  gr->cy = -gr->h / gr->gh;
  gr->dy = gr->y2 - gr->gy1 * gr->cy;
  /* graph --> xschem transform for digital waves y axis */
  gr->dcy = -gr->h / gr->posh;
  gr->ddy = gr->y2 - gr->ypos1 * gr->dcy;

  /* direct graph --> screen transform */
  gr->scx = gr->cx * xctx->mooz;
  gr->sdx = (gr->dx + xctx->xorigin) * xctx->mooz;
  gr->scy = gr->cy * xctx->mooz;
  gr->sdy = (gr->dy + xctx->yorigin) * xctx->mooz;
  /* direct graph --> screen for digital waves y axis */
  gr->dscy = gr->dcy * xctx->mooz;
  gr->dsdy = (gr->ddy + xctx->yorigin) * xctx->mooz;
}

static void draw_cursor(double active_cursorx, double other_cursorx, int cursor_color, Graph_ctx *gr)
{

  double xx, pos = active_cursorx;
  double tx1, ty1, tx2, ty2, dtmp;
  int tmp;
  char tmpstr[100];
  double txtsize = gr->txtsizex;
  short flip = (other_cursorx > active_cursorx) ? 0 : 1;
  int xoffs = flip ? 3 : -3;

  if(gr->logx) pos = mylog10(pos);
  xx = W_X(pos);
  if(xx >= gr->x1 && xx <= gr->x2) {
    drawline(cursor_color, NOW, xx, gr->ry1, xx, gr->ry2, 0.0, 1, NULL);
    if(gr->unitx != 1.0)
       sprintf(tmpstr, "%.*g%c", xctx->ev_precision, gr->unitx * active_cursorx , gr->unitx_suffix);
    else
       my_snprintf(tmpstr, S(tmpstr), "%s",  dtoa_eng(active_cursorx, 5));
    text_bbox(tmpstr, txtsize, txtsize, 2, flip, 0, 0, xx + xoffs, gr->ry2-1, &tx1, &ty1, &tx2, &ty2, &tmp, &dtmp);
    filledrect(0, NOW,  tx1, ty1, tx2, ty2, 2, -1, -1);
    draw_string(cursor_color, NOW, tmpstr, 2, flip, 0, 0, xx + xoffs, gr->ry2-1, txtsize, txtsize);
  }
}

static void draw_cursor_difference(double c1, double c2, Graph_ctx *gr)
{
  int tmp;
  char tmpstr[100];
  double txtsize = gr->txtsizex;
  double tx1, ty1, tx2, ty2;
  double cc1 = gr->logx ? mylog10(c1) : c1;
  double cc2 = gr->logx ? mylog10(c2) : c2;
  double aa = W_X(cc1);
  double a = CLIP(aa, gr->x1, gr->x2);
  double bb = W_X(cc2);
  double b = CLIP(bb, gr->x1, gr->x2);
  double diff = fabs(b - a);
  double diffw;
  double xx = ( a + b ) * 0.5;
  double yy = gr->ry2 - 1;
  double dtmp;
  double yline;


  diffw = fabs(c2 - c1);

  if(gr->unitx != 1.0)
     sprintf(tmpstr, "%.*g%c", xctx->ev_precision, gr->unitx * diffw , gr->unitx_suffix);
  else
     my_snprintf(tmpstr, S(tmpstr), "%s",  dtoa_eng(diffw, 5));
  text_bbox(tmpstr, txtsize, txtsize, 2, 0, 1, 0, xx, yy, &tx1, &ty1, &tx2, &ty2, &tmp, &dtmp);
  if( tx2 - tx1 < diff ) {
    draw_string(3, NOW, tmpstr, 2, 0, 1, 0, xx, yy, txtsize, txtsize);
    if( a > b) {
      dtmp = a; a = b; b = dtmp;
    }
    yline = (ty1 + ty2) * 0.5;
    if( tx1 - a > 4.0) drawline(3, NOW, a + 2, yline, tx1 - 2, yline, 0.0, 1, NULL);
    if( b - tx2 > 4.0) drawline(3, NOW, tx2 + 2, yline, b - 2, yline, 0.0, 1, NULL);
  }
}

static void draw_hcursor(double active_cursory, int cursor_color, Graph_ctx *gr)
{
  double yy, pos = active_cursory;
  double tx1, ty1, tx2, ty2, dtmp;
  int tmp;
  char tmpstr[100];
  double txtsize = gr->txtsizey;
  double th;

  if(gr->digital) return;
  if(gr->logy) pos = mylog10(pos);
  yy = W_Y(pos);
  if(yy >= gr->y1 && yy <= gr->y2) {
    drawline(cursor_color, NOW, gr->rx1 + 10, yy, gr->rx2 - 10, yy, 0.0, 1, NULL);
    if(gr->unity != 1.0)
       sprintf(tmpstr, " %.*g%c ", xctx->ev_precision, gr->unity * active_cursory , gr->unity_suffix);
    else
       my_snprintf(tmpstr, S(tmpstr), " %s ",  dtoa_eng(active_cursory, 5));
    text_bbox(tmpstr, txtsize, txtsize, 0, 0, 0, 0, gr->rx1 + 5, yy, &tx1, &ty1, &tx2, &ty2, &tmp, &dtmp);
    th = (ty2 - ty1) / 2.; /* half text height */
    ty1 -= th;
    ty2 -= th;
    filledrect(0, NOW,  tx1, ty1, tx2, ty2, 2, -1, -1);
    draw_string(cursor_color, NOW, tmpstr, 0, 0, 0, 0, gr->rx1 + 5, yy - th, txtsize, txtsize);
  }
}

static void draw_hcursor_difference(double c1, double c2, Graph_ctx *gr)
{
  int tmp;
  char tmpstr[100];
  double txtsize = gr->txtsizey;
  double tx1, ty1, tx2, ty2;
  double cc1 = gr->logy ? mylog10(c1) : c1;
  double cc2 = gr->logy ? mylog10(c2) : c2;
  double aa = W_Y(cc1);
  double a = CLIP(aa, gr->y1, gr->y2);
  double bb = W_Y(cc2);
  double b = CLIP(bb, gr->y1, gr->y2);
  double diff = fabs(b - a);
  double diffh;
  double yy = ( a + b ) * 0.5;
  double xx = gr->rx1 + 5;
  double dtmp;
  double xline;

  if(gr->digital) return;
  diffh = fabs(c2 - c1);
  if(gr->unity != 1.0)
     sprintf(tmpstr, " %.*g%c ", xctx->ev_precision, gr->unity * diffh , gr->unity_suffix);
  else
     my_snprintf(tmpstr, S(tmpstr), " %s ",  dtoa_eng(diffh, 5));
  text_bbox(tmpstr, txtsize, txtsize, 0, 0, 0, 1, xx, yy, &tx1, &ty1, &tx2, &ty2, &tmp, &dtmp);
  if( 2 * (ty2 - ty1) < diff ) {
    filledrect(0, NOW,  tx1, ty1, tx2, ty2, 2, -1, -1);
    draw_string(3, NOW, tmpstr, 0, 0, 0, 1, xx, yy, txtsize, txtsize);
    if( a > b) {
      dtmp = a; a = b; b = dtmp;
    }
    xline = tx1 + 10;
    if( ty1 - a > 4.0) drawline(3, NOW, xline, a + 2, xline, ty1 - 2, 0.0, 1, NULL);
    if( b - ty2 > 4.0) drawline(3, NOW, xline, ty2 + 2, xline, b - 2, 0.0, 1, NULL);
  }

}

/* sweep variables on x-axis, node labels */
static void draw_graph_variables(int wcnt, int wave_color, int n_nodes, int sweep_idx,
        int flags, const char *ntok, const char *stok, const char *bus_msb, Graph_ctx *gr)
{
  char tmpstr[1024];
  /* clipping everything outside container area */
  bbox(START, 0.0, 0.0, 0.0, 0.0);
  bbox(ADD, gr->rx1, gr->ry1, gr->rx2, gr->ry2);
  bbox(SET_INSIDE, 0.0, 0.0, 0.0, 0.0);
  /* draw sweep variable(s) on x-axis */
  if(wcnt == 0 || (stok && stok[0])) {
    if(sch_waves_loaded() >= 0) stok = xctx->raw->names[sweep_idx];
    if(gr->unitx != 1.0) my_snprintf(tmpstr, S(tmpstr), "%s[%c]", stok ? stok : "" , gr->unitx_suffix);
    else  my_snprintf(tmpstr, S(tmpstr), "%s", stok ? stok : "");
    my_snprintf(tmpstr, S(tmpstr), "%s", str_replace(tmpstr, "\\ ", " ", 0, -1));
    draw_string(wave_color, NOW, tmpstr, 2, 1, 0, 0,
       gr->rx1 + 2 + gr->rw / n_nodes * wcnt, gr->ry2-2, gr->txtsizelab, gr->txtsizelab);
  }

  if(gr->legend || gr->digital) {
    /* draw node labels in graph */
    if(bus_msb) {
      if(gr->unity != 1.0) my_snprintf(tmpstr, S(tmpstr), "%s[%c]",
           find_nth(ntok, ";,", "\"", 0, 1), gr->unity_suffix);
      else  my_snprintf(tmpstr, S(tmpstr), "%s",find_nth(ntok, ";,", "\"", 0, 1));
    } else {
      char *ntok_ptr = NULL;
      char *alias_ptr = NULL;
      dbg(1, "ntok=%s\n", ntok);
      if(strstr(ntok, ";")) {
         my_strdup2(_ALLOC_ID_, &alias_ptr, find_nth(ntok, ";", "\"", 0, 1));
         my_strdup2(_ALLOC_ID_, &ntok_ptr, find_nth(ntok, ";", "\"", 0, 2));
      }
      else {
         my_strdup2(_ALLOC_ID_, &alias_ptr, ntok);
         my_strdup2(_ALLOC_ID_, &ntok_ptr, ntok);
      }

      if(gr->unity != 1.0) my_snprintf(tmpstr, S(tmpstr), "%s[%c]", alias_ptr, gr->unity_suffix);
      else  my_snprintf(tmpstr, S(tmpstr), "%s", alias_ptr);
      my_free(_ALLOC_ID_, &alias_ptr);
      my_free(_ALLOC_ID_, &ntok_ptr);
    }
    if(gr->vlegend && !gr->digital) { 
      double xt = gr->rx1 + 5;
      double yt;
      yt = gr->y1 + (double)wcnt / (double)n_nodes * (gr->h) ;
      if(!(flags & 2)) { /* NOT cursor1 with measures */
        #if HAS_CAIRO == 1
        if(wave_is_hilighted(gr, wcnt)) {
          xctx->cairo_font =
                cairo_toy_font_face_create("Sans-Serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
          cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
          cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
          cairo_font_face_destroy(xctx->cairo_font);
        }
        #endif
        dbg(1, "%g %g %s\n", xt, yt, tmpstr);
        my_snprintf(tmpstr, S(tmpstr), "%s", str_replace(tmpstr, "\\ ", " ", 0, -1));
        dbg(1, "txtsizelegend=%g\n", gr->txtsizelegend);
        draw_string(wave_color, NOW, tmpstr, 0, 0, 0, 0,
          xt, yt, gr->txtsizelegend, gr->txtsizelegend);
        #if HAS_CAIRO == 1
        if(wave_is_hilighted(gr, wcnt)) {
          xctx->cairo_font =
                cairo_toy_font_face_create("Sans-Serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
          cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
          cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
          cairo_font_face_destroy(xctx->cairo_font);
        }
        #endif
      }
    } else if(gr->digital) {
      double xt = gr->x1 - 15 * gr->txtsizelab;
      double s1 = DIG_NWAVES; /* 1/DIG_NWAVES  waveforms fit in graph if unscaled vertically */
      double s2 = DIG_SPACE; /* (DIG_NWAVES - DIG_SPACE) spacing between traces */
      double yt;
      if(flags & 2)  /* cursor1 with measures */
        yt = s1 * (double)(n_nodes - wcnt) * gr->gh + gr->gh * 0.4 * s2;
      else
        yt = s1 * (double)(n_nodes - wcnt) * gr->gh + gr->gh * 0.1 * s2;

      if(yt <= gr->ypos2 && yt >= gr->ypos1) {
        #if HAS_CAIRO == 1
        if(wave_is_hilighted(gr, wcnt)) {
          xctx->cairo_font =
                cairo_toy_font_face_create("Sans-Serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
          cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
          cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
          cairo_font_face_destroy(xctx->cairo_font);
        }
        #endif
        my_snprintf(tmpstr, S(tmpstr), "%s", str_replace(tmpstr, "\\ ", " ", 0, -1));
        draw_string(wave_color, NOW, tmpstr, 2, 0, 0, 0,
          xt, DW_Y(yt), gr->digtxtsizelab * gr->magy, gr->digtxtsizelab * gr->magy);
        dbg(1, "draw_graph_variables(): h=%g, posh=%g, gh=%g\n", gr->h, gr->posh, gr->gh);
        #if HAS_CAIRO == 1
        if(wave_is_hilighted(gr, wcnt)) {
          xctx->cairo_font =
                cairo_toy_font_face_create("Sans-Serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
          cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
          cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
          cairo_font_face_destroy(xctx->cairo_font);
        }
        #endif
      }
    } else {
      /* viewer plan item 1. `legendbold` (ASE viewer strips only) draws EVERY
       * entry bold so the legend reads at the weight of the axis numbers. That
       * erases the issue-0152 cue, which WAS "the bolded wave's entry is the
       * only bold one" — so on a legendbold graph the bolded wave is
       * distinguished by SLANT instead: bold italic against bold upright. One
       * token in the existing toy-font call, no new drawing code and no layout
       * change (the entries sit in fixed per-node slots, so nothing shifts).
       * Without legendbold the shipped behaviour is untouched, which is what
       * keeps the ~127 embedded schematic graphs out of this. */
      #if HAS_CAIRO == 1
      if(gr->legendbold || wave_is_hilighted(gr, wcnt)) {
        xctx->cairo_font =
              cairo_toy_font_face_create("Sans-Serif",
                (gr->legendbold && wave_is_hilighted(gr, wcnt)) ?
                   CAIRO_FONT_SLANT_ITALIC : CAIRO_FONT_SLANT_NORMAL,
                CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
        cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
        cairo_font_face_destroy(xctx->cairo_font);
      }
      #endif
      my_snprintf(tmpstr, S(tmpstr), "%s", str_replace(tmpstr, "\\ ", " ", 0, -1));
      draw_string(wave_color, NOW, tmpstr, 0, 0, 0, 0,
          gr->rx1 + 2 + gr->rw / n_nodes * wcnt, gr->ry1, gr->txtsizelab, gr->txtsizelab);
      #if HAS_CAIRO == 1
      if(gr->legendbold || wave_is_hilighted(gr, wcnt)) {
        xctx->cairo_font =
              cairo_toy_font_face_create("Sans-Serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
        cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
        cairo_font_face_destroy(xctx->cairo_font);
      }
      #endif
    }
  } /* if(gr->legend) */
  bbox(END, 0.0, 0.0, 0.0, 0.0);
}

static void show_node_measures(int measure_p, double measure_x, double measure_prev_x,
       const char *bus_msb, int wave_color, int idx, SPICE_DATA **idx_arr,
       int n_bits, int n_nodes, const char *ntok, int wcnt, Graph_ctx *gr, xRect *r, double cursor1)
{
  char tmpstr[1024] = "";
  double yy;
  /* show values of signals if cursor1 active */
  if(idx == -1) return;
  if(!xctx->raw) {
    dbg(0, "show_node_measures(): no raw struct allocated\n");
    return;
  }
  if(!gr->legend && !gr->digital) return;
  if(measure_p >= 0) {
    /* draw node values in graph */
    char *ntok_ptr = NULL;
    char *alias_ptr = NULL;
    if(strstr(ntok, ";")) {
       my_strdup2(_ALLOC_ID_, &alias_ptr, find_nth(ntok, ";", "\"", 0, 1));
       my_strdup2(_ALLOC_ID_, &ntok_ptr, find_nth(ntok, ";", "\"", 0, 2));
    }
    else {
       my_strdup2(_ALLOC_ID_, &alias_ptr, ntok);
       my_strdup2(_ALLOC_ID_, &ntok_ptr, ntok);
    }
    bbox(START, 0.0, 0.0, 0.0, 0.0);
    bbox(ADD, gr->rx1, gr->ry1, gr->rx2, gr->ry2);
    bbox(SET_INSIDE, 0.0, 0.0, 0.0, 0.0);
    if(!bus_msb) {
      double diffy;
      double diffx;
      char *fmt1, *fmt2;
      double yy1;
      int prec = xctx->ev_precision;

      if( gr->logx) cursor1 = mylog10(cursor1);
      yy1 = xctx->raw->values[idx][measure_p-1];
      diffy = xctx->raw->values[idx][measure_p] - yy1;
      diffx = measure_x - measure_prev_x;
      yy = yy1 + diffy / diffx * (cursor1 - measure_prev_x);
      if(XSIGN0(gr->gy1) != XSIGN0(gr->gy2) && fabs(yy) < 1e-12 * fabs(gr->gh)) yy = 0.0;
      if(yy != 0.0  && fabs(yy * gr->unity) < 1.0e-3) {
        prec = 2;
        fmt1="%.*e";
        fmt2="%.*e%c";
      } else {
        fmt1="%.*g";
        fmt2="%.*g%c";
      }
      if(gr->unity != 1.0) sprintf(tmpstr, fmt2, prec, yy * gr->unity, gr->unity_suffix);
      else  sprintf(tmpstr, fmt1, prec, yy);
    } else {
      double vthl, vthh;
      int hex_digits = ((n_bits - 1) >> 2) + 1;
      vthh = gr->gy1 * 0.2 + gr->gy2 * 0.8;
      vthl = gr->gy1 * 0.8 + gr->gy2 * 0.2;
      get_bus_value(n_bits, hex_digits, idx_arr, measure_p - 1, tmpstr, vthl, vthh);
    }

    if(gr->vlegend && !gr->digital) {
      char str[1024];
      double xt = gr->rx1 + 5;
      double yt = gr->y1 + (double)wcnt / (double)n_nodes * (gr->h) ;
      if(!bus_msb) my_snprintf(str, S(str), "%s\n(%s)", alias_ptr, tmpstr);
      else my_snprintf(str, S(str), "%s", alias_ptr);
      #if HAS_CAIRO == 1
      if(wave_is_hilighted(gr, wcnt)) {
        xctx->cairo_font =
              cairo_toy_font_face_create("Sans-Serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_BOLD);
        cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
        cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
        cairo_font_face_destroy(xctx->cairo_font);
      }
      #endif
      draw_string(wave_color, NOW, str, 0, 0, 0, 0,
         xt, yt, gr->txtsizey * gr->magy * 0.4, gr->txtsizey * gr->magy * 0.4);
      #if HAS_CAIRO == 1
      if(wave_is_hilighted(gr, wcnt)) {
        xctx->cairo_font =
              cairo_toy_font_face_create("Sans-Serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
        cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
        cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
        cairo_font_face_destroy(xctx->cairo_font);
      }
      #endif
    } else if(!bus_msb && !gr->digital) {
      draw_string(wave_color, NOW, tmpstr, 0, 0, 0, 0,
         gr->rx1 + 2 + gr->rw / n_nodes * wcnt, gr->ry1 + gr->txtsizelab * 60,
          gr->txtsizelab * 0.8, gr->txtsizelab * 0.8);
      dbg(1, "node: %s, x=%g, value=%g\n", ntok, measure_x, yy);
    }
    else if(gr->digital) {
      double xt = gr->x1 - 15 * gr->txtsizelab;
      double s1 = DIG_NWAVES; /* 1/DIG_NWAVES  waveforms fit in graph if unscaled vertically */
      double s2 = DIG_SPACE; /* (DIG_NWAVES - DIG_SPACE) spacing between traces */
      double yt = s1 * (double)(n_nodes - wcnt) * gr->gh + gr->gh * 0.4 * s2;
      if(yt <= gr->ypos2 && yt >= gr->ypos1) {
        draw_string(wave_color, NOW, tmpstr, 2, 0, 0, 0,
           xt, DW_Y(yt) + gr->digtxtsizelab * 50, gr->digtxtsizelab * 0.8, gr->digtxtsizelab * 0.8);
      }
    }
    bbox(END, 0.0, 0.0, 0.0, 0.0);
    my_free(_ALLOC_ID_, &alias_ptr);
    my_free(_ALLOC_ID_, &ntok_ptr);
  } /* if(measure_p >= 0) */
}

int embed_rawfile(const char *rawfile)
{
  int res = 0;
  size_t len;
  char *ptr;

  dbg(1, "embed_rawfile(): rawfile=%s\n", rawfile);
  if(xctx->lastsel==1 && xctx->sel_array[0].type==ELEMENT) {
    xInstance *i = &xctx->inst[xctx->sel_array[0].n];
    xctx->push_undo();
    ptr = base64_from_file(rawfile, &len);
    my_strdup2(_ALLOC_ID_, &i->prop_ptr, subst_token(i->prop_ptr, "spice_data", ptr));
    my_free(_ALLOC_ID_, &ptr);
    set_modify(1);
  }
  return res;
}

/* ---- the LEGEND hit test (issue 0175 D5) ----------------------------------
 *
 * Which legend entry is under a point? Three layouts, and the arithmetic below
 * is the SAME arithmetic draw_graph_variables() uses to place the entries -- the
 * horizontal slot formula in particular is literally the draw's
 * `gr->rx1 + 2 + gr->rw / n_nodes * wcnt`, so the drawn label and its clickable
 * target cannot drift apart.
 *
 * This used to live INSIDE edit_wave_attributes(), triplicated once per layout
 * and fused to that function's action, which is why the legend had no query
 * anybody else could call and why two comments in wave_viewer.tcl claimed the
 * engine had "no C hit-test API". It is now a pure function with two callers:
 * the Button3 arm below (through edit_wave_attributes) and the Button1 arm in
 * callback.c, which is what makes the two buttons agree on where an entry is by
 * construction.
 *
 * Takes XSCHEM (schematic) coordinates, because that is the space the legend
 * boxes are computed in -- gr->rx1/ry1/rw/rh are xschem coordinates while
 * S_X/S_Y (graph_wave_at, graph_plotbox_at) are SCREEN PIXELS. The two picking
 * surfaces of one strip genuinely do not share a coordinate space; the
 * conversion is graph_legend_at()'s job and is done exactly once, there.
 *
 * `gr` must already be set up for graph `i`. Returns the NODE index or -1. */
static int legend_slot_hit(Graph_ctx *gr, const char *node, double xx, double yy)
{
  int wcnt, n_nodes;
  if(!gr || !node || !node[0]) return -1;
  /* `legend=0` draws no entries at all, so there is nothing to hit. The
   * triplicated in-place version did not test this and would happily pick an
   * INVISIBLE entry; both buttons now refuse together, which is the whole point
   * of there being one query. */
  if(!gr->legend) return -1;
  n_nodes = count_items(node, "\n", "\"");
  if(n_nodes <= 0) return -1;
  for(wcnt = 0; wcnt < n_nodes; ++wcnt) {
    if(gr->vlegend && !gr->digital) {
      double xt1 = gr->rx1 + 5;
      double xt2 = gr->x1 - 5;
      double yt1 = gr->y1 + (double)wcnt / (double)n_nodes * (gr->h);
      double yt2 = yt1 + 1.0 / (double)n_nodes * (gr->h);
      if(POINTINSIDE(xx, yy, xt1, yt1, xt2, yt2)) return wcnt;
    } else if(gr->digital) {
      double xt1 = gr->rx1; /* <-- waves_selected() is more restrictive than this */
      double xt2 = gr->x1 - 20 * gr->txtsizelab;
      double s1 = DIG_NWAVES; /* 1/DIG_NWAVES  waveforms fit in graph if unscaled vertically */
      double s2 = DIG_SPACE; /* (DIG_NWAVES - DIG_SPACE) spacing between traces */
      double yt1 = s1 * (double)(n_nodes - wcnt) * gr->gh - gr->gy1 * s2;
      double yt2 = yt1 + s1 * gr->gh;
      if(yt1 <= gr->ypos2 && yt1 >= gr->ypos1) {
        double tmp = DW_Y(yt1);
        yt1 = DW_Y(yt2);
        yt2 = tmp;
        if(POINTINSIDE(xx, yy, xt1, yt1, xt2, yt2)) return wcnt;
      }
    } else {
      double xt1 = gr->rx1 + 2 + gr->rw / n_nodes * wcnt;
      double yt1 = gr->ry1;
      double xt2 = xt1 + gr->rw / n_nodes;
      double yt2 = gr->y1;
      if(POINTINSIDE(xx, yy, xt1, yt1, xt2, yt2)) return wcnt;
    }
  }
  return -1;
}

/* The public query: which legend entry of graph `i` sits under the CANVAS PIXEL
 * (px, py)? NODE index, or -1.
 *
 * ⚠ RAW PIXELS, never xctx->mousex_snap. The in-place version this replaces
 * tested the GRID-SNAPPED mouse mirror, which for the two waves_callback callers
 * happens to be harmless (waves_callback overwrites mousex_snap with mousex at
 * its head, issue 0143) but is wrong for anything else -- with a coarse snap a
 * pointer sitting on entry 2 tests as entry 1. Taking the event's own pixels
 * closes that for good and matches graph_wave_at / graph_plotbox_at.
 *
 * Fails closed exactly like graph_plotbox_at: a bad index, a non-graph rect, an
 * off-screen graph or a strip with no `node` token all answer -1, never a
 * plausible 0. Uses a LOCAL Graph_ctx and brackets graph_flags' hcursor bits
 * (landmines 11 and 37) -- it is a query and must not leave the session
 * describing a strip nobody is pointing at.
 *
 * Unlike graph_plotbox_at it does NOT refuse digital strips: the digital legend
 * has its own working layout, and on a digital strip the legend is the only way
 * to select a trace at all (graph_wave_at answers -1 across the whole body). */
int graph_legend_at(int i, double px, double py)
{
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  xRect *r;
  const char *node;
  int saveflags, ret;
  double xx, yy;

  if(!xctx) return -1;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return -1;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return -1;
  node = get_tok_value(r->prop_ptr, "node", 0);
  if(!node[0]) return -1;
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  saveflags = xctx->graph_flags & (128 | 256);
  setup_graph_data(i, 0, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->scx == 0.0 || gr->scy == 0.0) return -1;   /* off-screen: no transform */
  /* SCREEN -> XSCHEM. The inverse of X_TO_SCREEN/Y_TO_SCREEN (xschem.h): the
   * legend boxes are in xschem coordinates and the caller speaks canvas pixels. */
  xx = px / xctx->mooz - xctx->xorigin;
  yy = py / xctx->mooz - xctx->yorigin;
  /* get_tok_value's buffer is reused by setup_graph_data, so re-read `node` */
  node = get_tok_value(r->prop_ptr, "node", 0);
  ret = legend_slot_hit(gr, node, xx, yy);
  dbg(1, "graph_legend_at(): graph=%d px=%g py=%g -> node %d\n", i, px, py, ret);
  return ret;
}

/* Act on the legend entry under the pointer.
 *
 * what == 1: open the wave dialog for it ("graph_edit_wave <graph> <wave>")
 * what == 2: TOGGLE that trace's membership of the selection (issue 0175 D7).
 *            Before 0175 the selection was a scalar and this was a plain
 *            hilight_wave toggle; toggling MEMBERSHIP is a strict superset --
 *            byte-identical whenever the selection holds at most one trace --
 *            and it is what makes RMB-on-legend and Ctrl+LMB-on-legend the same
 *            gesture on two buttons. It deliberately does NOT sweep the other
 *            strips: it never did, and now that a multi-trace selection is legal
 *            that stops being an inconsistency.
 * returns 1 if a wave was found (the caller then redraws / stops routing).
 *
 * All three legend layouts, and the geometry, now live in legend_slot_hit()
 * above -- this function used to carry all of it three times over. */
int edit_wave_attributes(int what, int i, Graph_ctx *gr)
{
  const char *node;
  int wcnt;
  xRect *r = &xctx->rect[GRIDLAYER][i];

  node = get_tok_value(r->prop_ptr, "node", 0);
  if(!node[0]) return 0;
  /* the pointer mirror, NOT the event pixels: this is the shipped contract of
   * both callers (a Button3 press and the double-click arm), and inside
   * waves_callback mousex_snap/mousey_snap have already been overwritten with
   * the UNsnapped mousex/mousey at the head of the function (issue 0143), so
   * these are raw coordinates despite the field names. */
  wcnt = legend_slot_hit(gr, node, xctx->mousex_snap, xctx->mousey_snap);
  if(wcnt < 0) return 0;
  if(what == 1) {
    char s[50];
    int save = gr->hilight_wave;
    my_snprintf(s, S(s), "%d %d", i, wcnt);
    gr->hilight_wave = wcnt;
    tclvareval("graph_edit_wave ", s, NULL);
    gr->hilight_wave = save;
  } else {
    if(graph_sel_waves_toggle(i, wcnt)) {
      /* keep the live Graph_ctx in step with the tokens just written -- the
       * caller redraws with THIS gr and would otherwise paint the old state */
      gr->n_sel_waves = graph_sel_waves_get(i, gr->sel_wave, GRAPH_MAX_SEL_WAVES);
      gr->hilight_wave = gr->n_sel_waves ? gr->sel_wave[0] : -1;
    }
  }
  return 1;
}

/* derived from draw_graph(), used to calculate y range of custom equation graph data,
 * call the plot_raw_custom_data
 * handling multiple datasets ad wraps (as in multi-sweep DC sims).
 */
int calc_custom_data_yrange(int sweep_idx, const char *express, Graph_ctx *gr)
{
  int idx = -1;
  int p, dset, ofs, ofs_end;
  int first, last;
  double xx; /* the p-th sweep variable value:  xctx->raw->values[sweep_idx][p] */
  double xx0 = 0; /* first sweep value */
  double start;
  double end;
  int sweepvar_wrap = 0; /* incremented on new dataset or sweep variable wrap */
  int dataset = gr->dataset;
  Raw *raw = xctx->raw;
  if(!raw) {
    dbg(0, "calc_custom_data_yrange(): no raw struct allocated\n");
    return idx;
  }
  ofs = 0;
  start = (gr->gx1 <= gr->gx2) ? gr->gx1 : gr->gx2;
  end = (gr->gx1 <= gr->gx2) ? gr->gx2 : gr->gx1;
  for(dset = 0 ; dset < raw->datasets; dset++) {
    int cnt=0, wrap;
    register SPICE_DATA *gv = raw->values[sweep_idx];
    register SPICE_DATA *gv0 = raw->values[0];
    ofs_end = ofs + raw->npoints[dset];
    first = -1;
    last = ofs;

    /* optimization: skip unwanted datasets, if no dc no need to detect sweep variable wraps */
    if(dataset >= 0 && strcmp(xctx->raw->sim_type, "dc") && dataset != sweepvar_wrap) goto done;
    for(p = ofs ; p < ofs_end; p++) {
      if(gr->logx)
        xx = mylog10(gv[p]);
      else
        xx = gv[p];

      if(p == ofs) xx0 = gv0[p];
      wrap = xctx->raw->sim_type && !strcmp(xctx->raw->sim_type, "dc") && cnt > 1 && gv0[p] == xx0;
      if(first != -1) {                      /* there is something to plot ... */
        if(xx > end || xx < start ||         /* ... and we ran out of graph area ... */
          wrap) {                          /* ... or sweep variable changed direction */
          if(dataset == -1 || dataset == sweepvar_wrap) {
            idx = plot_raw_custom_data(sweep_idx, first, last, express, NULL);
          }
          first = -1;
        }
      }
      if(wrap) {
         sweepvar_wrap++;
         cnt = 0;
      }
      if(xx >= start && xx <= end) {
        if(first == -1) first = p;
        last = p;
        ++cnt;
      } /* if(xx >= start && xx <= end) */
    } /* for(p = ofs ; p < ofs + raw->npoints[dset]; p++) */
    if(first != -1) {
      if(dataset == -1 || dataset == sweepvar_wrap) {
        idx = plot_raw_custom_data(sweep_idx, first, last, express, NULL);
      }
    }

    done:

    /* offset pointing to next dataset */
    ofs = ofs_end;
    sweepvar_wrap++;
  } /* for(dset...) */
  return idx;
}
/* return in node_number the node index that is closest to mouse coordinates */
int find_closest_wave(int i, Graph_ctx *gr, int *node_number)
{
  double xval, yval;
  char *node = NULL, *sweep = NULL;
  int sweep_idx = 0;
  int node_sweep_idx = 0;         /* the sweep column IN THE ENTRY'S OWN database */
  const char *sweep_name = NULL;  /* last non-empty `sweep=` token, carried forward */
  char *saven, *saves, *nptr, *sptr;
  const char *ntok, *stok;
  int wcnt = -1, idx, expression;
  char *ntok_copy = NULL; /* copy of ntok without %<n> */
  char *express = NULL;
  xRect *r = &xctx->rect[GRIDLAYER][i];
  int autoload = 0, closest_dataset = -1, node_dataset = -1;
  double min=-1.0;
  char *custom_rawfile = NULL; /* "rawfile" attr. set in graph: load and switch to specified raw */
  char *sim_type = NULL;
  int entry_extra_idx = -1;  /* the session's database on entry -- the unwind point */
  int entry_prev_idx = -1;   /* ...and where switch_back pointed on entry */
  int switched = 0;          /* the graph-level switch actually took */
  int valid_rawfile = 1;
  const char *ptr;

  /* Written FIRST, before either refusal (issue 0174). Both early returns used
   * to leave *node_number untouched, and the one caller that reads it
   * (callback.c's wave-bold arm) passed an uninitialised local -- so a body
   * click on a digital strip, or with no raw loaded, persisted stack garbage
   * into the graph's hilight_wave token (measured: -1859984240). That caller no
   * longer uses this function, but the contract "always writes *node_number"
   * belongs here, not at the call site. */
  *node_number = -1;
  if(!xctx->raw) {
    dbg(0, "find_closest_wave(): no raw struct allocated\n");
    return -1;
  }
  if(gr->digital) return -1;

  autoload = !strboolcmp(get_tok_value(r->prop_ptr,"autoload", 0), "true");
  if(autoload == 0) autoload = 2; /* 2: switch */
  else if(autoload == 1) autoload = 33; /* 1: read, 32: no_warning */

  yval = G_Y(xctx->mousey);
  xval = G_X(xctx->mousex);
  /* get data to plot */
  my_strdup2(_ALLOC_ID_, &node, get_tok_value(r->prop_ptr,"node", 0));
  my_strdup2(_ALLOC_ID_, &sweep, get_tok_value(r->prop_ptr,"sweep", 0));

  ptr = get_tok_value(r->prop_ptr,"rawfile", 0);
  if(!ptr[0]) {
    if(xctx->raw && xctx->raw->rawfile) my_strdup2(_ALLOC_ID_, &custom_rawfile, xctx->raw->rawfile);
    else  my_strdup2(_ALLOC_ID_, &custom_rawfile, "");
  } else {
    my_strdup2(_ALLOC_ID_, &custom_rawfile, ptr);
  }

  my_strdup2(_ALLOC_ID_, &sim_type, get_tok_value(r->prop_ptr,"sim_type", 0));

  /* ⚠ THE BRACKET (batch F item 2, issue 0305). `rawfile`/`sim_type` are
   * GRAPH-level tokens, so the switch is made ONCE here, above the node loop --
   * it used to be made once per node, inside it, and unwound by a single
   * extra_rawfile(5, ...) after the loop. That is the shape graph_point_at()
   * was already repaired into (landmine 40), and both halves of it were wrong
   * here:
   *   - mode 5 is a SWAP of extra_idx with extra_prev_idx, not a stack pop, so
   *     with a per-trace `%<rawfile>` switch nested inside the graph-level one
   *     (spec D1) it lands the session on whichever database the LAST switch
   *     came from. Measured on the three-entry nested strip of
   *     tests/headless/test_node_token_split.tcl: entering on the session raw
   *     and hovering left the session pointing at the VCD.
   *   - the swap ran whether or not the switch had TAKEN, so a graph whose
   *     `rawfile=` does not resolve had its unpaired restore repoint the
   *     session's current raw on every call -- and this function runs on a
   *     graph gesture, i.e. constantly, against the session's real database
   *     rather than a local.
   * Both levels now unwind by ABSOLUTE INDEX (node_db_restore), which composes;
   * the per-node half is at the bottom of the loop body. */
  entry_extra_idx = xctx->extra_idx;
  entry_prev_idx = xctx->extra_prev_idx;
  if(custom_rawfile[0]) {
    if(extra_rawfile(autoload, custom_rawfile, sim_type[0] ? sim_type :
       (xctx->raw && xctx->raw->sim_type ? xctx->raw->sim_type : NULL), -1.0, -1.0) == 0) {
      valid_rawfile = 0;
    } else {
      switched = 1;
    }
  }

  nptr = node;
  sptr = sweep;
  /* process each node given in "node" attribute, get also associated sweep var if any*/
  while( (ntok = my_strtok_r(nptr, "\n", "\"", 4, &saven)) ) {
    char *node_rawfile = NULL;
    char *node_sim_type = NULL;
    int node_valid = valid_rawfile;
    int node_saved_idx;
    wcnt++;
    /* Consume this entry's sweep token and clear the strtok seeds BEFORE the bus
     * skip. Two bugs used to live in the old ordering (both also fixed in
     * graph_point_at(), keep the two in sync):
     *   - `continue` before `nptr = NULL` restarted my_strtok_r from the head of
     *     `node` (it re-seeds whenever str != NULL, util.c), so a graph whose
     *     FIRST node entry is a bus looped forever;
     *   - a bus entry did not consume its `sweep` token, so every trace after a
     *     bus was measured against the previous entry's sweep variable.
     * draw_graph() consumes the sweep token for every entry, bus included. */
    stok = my_strtok_r(sptr, "\t\n ", "\"", 0, &saves);
    nptr = sptr = NULL;
    if(strstr(ntok, ",")) {
      if(find_nth(ntok, ";,", "\"", 0, 2)[0]) continue; /* bus signal: skip */
    }
    dbg(1, "ntok=%s\n", ntok);

    if(stok && stok[0]) {
      sweep_name = stok;
      sweep_idx = get_raw_index(stok, NULL);
      if( sweep_idx == -1) {
        sweep_idx = 0;
      }
    }
    /* ONE `%` parse, issue 0305. The per-trace switch it enables is unwound at
     * the bottom of this loop body, by index, back to whatever was current when
     * this entry started (the graph-level `rawfile=` when the graph has one). */
    node_saved_idx = xctx->extra_idx;
    node_sweep_idx = sweep_idx;
    node_token_split(ntok, &ntok_copy, &node_dataset, &node_rawfile, &node_sim_type,
                     node_dflt_sim_type(sim_type));
    if(node_rawfile[0] && xctx->raw && xctx->raw->values) {
      dbg(1, "node_rawfile=|%s| node_sim_type=|%s|\n", node_rawfile, node_sim_type);
      if(extra_rawfile(autoload, node_rawfile, node_sim_type, -1.0, -1.0) == 0) {
        node_valid = 0;
      } else {
        /* the sweep COLUMN is a per-database index: re-resolve it BY NAME in the
         * database this entry actually lives in, on EVERY entry that took the
         * switch and not only on the ones carrying their own `sweep=` token (a
         * short `sweep=` list carries the last one forward, and a carried INDEX
         * was resolved in the previous database -- an out-of-bounds read of
         * values[] when the foreign database is narrower). Same rule, same
         * reason, as graph_point_at()/wave_hilight_envelope(). */
        node_sweep_idx = 0;
        if(sweep_name && sweep_name[0]) {
          node_sweep_idx = get_raw_index(sweep_name, NULL);
          if(node_sweep_idx == -1) node_sweep_idx = 0;
        }
      }
    }
    /* belt and braces: the column must be one the database that is NOW current
     * actually has (values holds nvars+1 columns, the last the expression scratch) */
    if(xctx->raw && (node_sweep_idx < 0 || node_sweep_idx >= xctx->raw->nvars)) node_sweep_idx = 0;
    my_free(_ALLOC_ID_, &node_rawfile);
    my_free(_ALLOC_ID_, &node_sim_type);
    dbg(1, "ntok=|%s|, node_dataset = %d\n", ntok, node_dataset);

    /* if ntok following possible 'alias;' definition contains spaces --> custom data plot */
    idx = -1;
    expression = 0;
    if(xctx->raw->values) {
      if(strstr(ntok_copy, ";")) {
        my_strdup2(_ALLOC_ID_, &express, find_nth(ntok_copy, ";", "\"", 0, 2));
      } else {
        my_strdup2(_ALLOC_ID_, &express, ntok_copy);
      }
      if(strpbrk(express, " \n\t")) {
        expression = 1;
      }
    }
    if(expression) idx = xctx->raw->nvars;
    else idx = get_raw_index(express, NULL);
    dbg(1, "find_closest_wave(): expression=%d, ntok_copy=%s express=%s idx=%d\n", expression, ntok_copy, express, idx);
    if( sch_waves_loaded() != -1 && node_valid && idx != -1 ) {
      int p, dset, ofs, ofs_end;
      int first, last;
      double xx, yy ; /* the p-th point */
      double xx0 = 0.0; /* first sweep value */
      double start;
      double end;
      int sweepvar_wrap = 0; /* incremented on new dataset or sweep variable wrap */
      ofs = 0;
      start = (gr->gx1 <= gr->gx2) ? gr->gx1 : gr->gx2;
      end = (gr->gx1 <= gr->gx2) ? gr->gx2 : gr->gx1;
      /* loop through all datasets found in raw file */
      for(dset = 0 ; dset < xctx->raw->datasets; dset++) {
        double prev_x = 0.0;
        int cnt=0, wrap;
        register SPICE_DATA *gvx = xctx->raw->values[node_sweep_idx];
        register SPICE_DATA *gv0 = xctx->raw->values[0];
        register SPICE_DATA *gvy;
        /* ofs_end MUST be computed before the dataset-skip goto: `done:` does
         * `ofs = ofs_end;`, so skipping dataset 0 used to read an uninitialized
         * ofs_end and thereafter a stale one. graph_point_at() gets this right. */
        ofs_end = ofs + xctx->raw->npoints[dset];
        if(node_dataset != -1 && node_dataset != dset) goto done;
        if(expression) plot_raw_custom_data(node_sweep_idx, ofs, ofs_end - 1, express, NULL);
        gvy = xctx->raw->values[idx];
        dbg(1, "find_closest_wave(): dset=%d\n", dset);
        first = -1;
        /* Process "npoints" simulation items
         * p loop split repeated 2 timed (for x and y points) to preserve cache locality */
        last = ofs;
        dbg(1, "find_closest_wave(): xval=%g yval=%g\n", xval, yval);
        for(p = ofs ; p < ofs_end; p++) {
          if(gr->logx) xx = mylog10(gvx[p]);
          else xx = gvx[p];
          if(gr->logy) yy = mylog10(gvy[p]);
          else  yy = gvy[p];
          if(p == ofs) xx0 = gv0[p];
          wrap = xctx->raw->sim_type && !strcmp(xctx->raw->sim_type, "dc") && cnt > 1 && gv0[p] == xx0;
          if(first != -1) {
            if(xx > end || xx < start || wrap) {
              dbg(1, "find_closest_wave(): last=%d\n", last);
              first = -1;
            }
          }
          if(wrap) {
             cnt = 0;
             sweepvar_wrap++;
          }
          if(xx >= start && xx <= end) {
            double tmp;
            if(first == -1) first = p;
            if( p > ofs && XSIGN(xval - xx) != XSIGN(xval - prev_x)) {
               tmp = fabs(yval - yy);
               if(min < 0.0) {
                  min = tmp;
                  closest_dataset = sweepvar_wrap;
                  *node_number = wcnt;
               } else {
                 if(tmp < min) {
                   min = tmp;
                   closest_dataset = sweepvar_wrap;
                   *node_number = wcnt;
                 }
               }
               dbg(1, "find_closest_wave(): dset=%d expression=%d idx=%d wcnt=%d dist=%g sweepvar_wrap=%d ntok=%s stok=%s\n",
                   dset, expression, idx, wcnt, tmp, sweepvar_wrap, ntok, stok? stok : "<NULL>");
            }
            last = p;
            ++cnt;
          } /* if(xx >= start && xx <= end) */
          prev_x = xx;
        } /* for(p = ofs ; p < ofs + raw->npoints[dset]; p++) */
        /* offset pointing to next dataset */
        done:
        ofs = ofs_end;
        sweepvar_wrap++;
      } /* for(dset...) */

    } /*  if( (idx = get_raw_index(ntok, NULL)) != -1 ) */
    /* the other half of the per-node switch, on every path out of the body:
     * this is the only exit, and the `continue`s above all sit ABOVE the switch */
    node_db_restore(node_saved_idx);
    my_free(_ALLOC_ID_, &express);
  } /* while( (ntok = my_strtok_r(nptr, "\n\t ", "", 0, &saven)) ) */
  /* dbg LEVEL 1, not 0 (batch F item 2, fix round). This was an unconditional
   * stderr line: debug_var is 0 in a normal run, so dbg(0, ...) always prints.
   * At HEAD it could only fire on a real graph `t` keypress; `xschem get
   * graph_closest_wave` turned it into one line per QUERY on a verb whose own
   * contract is "changes nothing else" -- 20 lines from NDC5 alone. It is a
   * trace, so it belongs at the level every other trace in this function is. */
  dbg(1, "closest dataset=%d wave index=%d\n", closest_dataset, *node_number);
  if(express) my_free(_ALLOC_ID_, &express);

  /* the other half of the GRAPH-level switch, and only if it took */
  if(switched) node_db_restore(entry_extra_idx);
  node_db_prev_restore(entry_prev_idx);
  my_free(_ALLOC_ID_, &custom_rawfile);
  my_free(_ALLOC_ID_, &sim_type);

  if(ntok_copy) my_free(_ALLOC_ID_, &ntok_copy);
  my_free(_ALLOC_ID_, &node);
  my_free(_ALLOC_ID_, &sweep);
  dbg(1, "find_closest_wave(): node_number = %d\n", *node_number);
  return closest_dataset;
}

/* find_closest_wave(), asked a question instead of driven by a gesture.
 *
 * WHY THIS EXISTS (batch F item 2, issue 0305). find_closest_wave() takes a
 * Graph_ctx and reads the C mouse mirror, so its ONLY caller is callback.c's
 * graph key handler -- i.e. a real DISPLAY -- and nothing headless could reach
 * it. That is exactly how its restore drifted: it kept the single mode-5 SWAP
 * every other walker had already been repaired away from, and no check in the
 * tree could see it. This is the same read-only query shape as
 * graph_wave_at()/graph_plotbox_at() above (`xschem get graph_closest_wave`):
 * it sets up the transform, moves the mouse mirror to the CANVAS PIXEL asked
 * about for the duration of the call and puts it back, and answers
 *   *node_number  the node index (find_closest_wave's own index space, the one
 *                 hilight_wave lives in), -1 when nothing answered;
 *   return        the closest DATASET (its sweepvar_wrap counter), -1 on refusal.
 * It changes nothing else -- in particular the session's current database must
 * be exactly what it was, which is the property under test. "The current
 * database" is a PAIR: extra_idx and extra_prev_idx, the second being where
 * `xschem raw switch_back` will go. find_closest_wave() restores both (see
 * node_db_prev_restore); NDU1 watches the second half, which the first cut of
 * this verb moved. The mouse-mirror put-back two lines below the call is watched
 * by NDC9, through `xschem closest_object` -- the production consumer of
 * xctx->mousex/mousey. */
int graph_closest_wave(int i, double px, double py, int *node_number)
{
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  xRect *r;
  int saveflags, dset, dummy = -1;
  double save_mousex, save_mousey;

  if(node_number) *node_number = -1;
  if(!xctx) return -1;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return -1;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return -1;
  if(!xctx->raw || sch_waves_loaded() == -1) return -1;
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  /* landmine 37: setup_graph_data() rewrites graph_flags' hcursor bits from the
   * rect it is given, and this is a query */
  saveflags = xctx->graph_flags & (128 | 256);
  setup_graph_data(i, 0, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->scx == 0.0 || gr->scy == 0.0) return -1;
  if(gr->digital) return -1;
  save_mousex = xctx->mousex;
  save_mousey = xctx->mousey;
  xctx->mousex = X_TO_XSCHEM(px);
  xctx->mousey = Y_TO_XSCHEM(py);
  dset = find_closest_wave(i, gr, node_number ? node_number : &dummy);
  xctx->mousex = save_mousex;
  xctx->mousey = save_mousey;
  return dset;
}

/* Screen-pixel distance from point (px,py) to the segment (ax,ay)-(bx,by). */
/* Distance from (px,py) to the SEGMENT a-b, and -- when ox/oy are given -- the
 * foot of the perpendicular itself, clamped to the segment's ends. That second
 * answer is the trace-snap point of issue 0193: at a zoom tighter than the
 * sample spacing the visible curve contains no sample at all, so the nearest
 * SAMPLE is the wrong thing to point at (it is off-screen) and the nearest
 * POINT ON THE CURVE is the only one that exists. */
static double graph_point_seg_dist(double px, double py,
                                   double ax, double ay, double bx, double by,
                                   double *ox, double *oy)
{
  double vx = bx - ax, vy = by - ay;
  double c1, c2, t, dx, dy;
  c2 = vx * vx + vy * vy;
  if(c2 <= 0.0) {
    dx = px - ax; dy = py - ay;
    if(ox) *ox = ax;
    if(oy) *oy = ay;
    return sqrt(dx * dx + dy * dy);
  }
  c1 = (px - ax) * vx + (py - ay) * vy;
  t = c1 / c2;
  if(t < 0.0) t = 0.0;
  else if(t > 1.0) t = 1.0;
  if(ox) *ox = ax + t * vx;
  if(oy) *oy = ay + t * vy;
  dx = px - (ax + t * vx);
  dy = py - (ay + t * vy);
  return sqrt(dx * dx + dy * dy);
}

/* The trace/sample picking family. Three public entry points, ONE traversal:
 *
 *   graph_point_at()  the engine: nearest SAMPLE (trace + dataset + point + x/y)
 *   graph_wave_at()   which displayed trace of graph `i` passes within `tol`
 *                     SCREEN PIXELS of the CANVAS PIXEL (px, py)? Returns the
 *                     trace's NODE INDEX (its position in the `node` prop token,
 *                     counted like find_closest_wave()'s node_number — bus
 *                     entries occupy an index even though they are never
 *                     hit-tested), or -1 when nothing is within `tol` (also for
 *                     a bad index, a non-graph rect, an off-screen graph or no
 *                     loaded data). When more than one trace qualifies the
 *                     NEAREST one wins.
 *   graph_near_wave() the same question as a boolean: the exclusion zone.
 *
 * The ASE waveform viewer's LMB seam (drag-to-reorder strips + drag a trace to
 * another strip, doc/claude/specs/waveform_viewer_modes.md): empty waveform-body
 * space belongs to strip reordering, a fixed pixel band around every trace is
 * the trace's own — the C engine's precise interactions (cursor grab, wave-bold)
 * plus the Tcl trace-to-strip drag. The zone has to be measured through the
 * ENGINE's own transform — Tcl approximating it from the strip bbox would drift
 * the moment margins, log axes or ranges change.
 *
 * Unlike find_closest_wave() this is a real distance, in screen pixels, to the
 * drawn POLYLINE (point-to-segment, not just |dy| at the nearest sample), it has
 * a threshold, and it uses the coordinates the caller passes rather than the
 * C mouse-position mirror (which is stale for a press with no preceding Motion).
 *
 * Uses a LOCAL Graph_ctx: never clobber xctx->graph_struct, which an active
 * draw_graph may be using (landmine 11,
 * doc/claude/code_analysis/waveform_subsystem_reference.md).
 *
 * DOCUMENTED LIMITS: digital strips and bus traces answer -1 (their rendering is
 * a band/ribbon, not a polyline — the whole body is then reorder space), and the
 * search is capped by the graph's own x window, exactly like the draw. */
/* The generalized picker every one of the three answers above is built on.
 * Returns 1 when a trace of graph `i` passes within `tol` SCREEN PIXELS of the
 * canvas pixel (px, py), filling *hit with the identity of the NEAREST SAMPLE on
 * that trace; 0 otherwise (*hit untouched).
 *
 * Trace RANKING is unchanged from the original graph_wave_at(): point-to-SEGMENT
 * distance, strictly-nearer wins, ties go to the first node in the list. The ASE
 * trace-exclusion zone, the issue-0152 wave-bold and the trace-drag pick all
 * depend on exactly that. The nearest SAMPLE is tracked independently, by plain
 * point distance, because a marker anchors to a real data point, not to a place
 * on a segment.
 *
 * restrict_wave >= 0    confine the search to that node index (a marker drag
 *                       slides along its OWN trace and nothing else)
 * restrict_dataset >= 0 confine it to that raw dataset
 *
 * hit->x / hit->y are the RAW gvx[p]/gvy[p], NEVER the mylog10()'ed ones: the
 * log mapping is only for the screen transform, and mylog10() clamps x <= 0 to
 * -35, so a round trip through pow(10,.) would turn a zero sample into 1e-35
 * (landmine 35). They are also captured INSIDE the sample loop and never
 * re-read afterwards: for an expression trace values[nvars] is a single global
 * scratch column that plot_raw_custom_data() rewrites for every dataset, so a
 * post-loop read would return whatever the LAST dataset left there.
 *
 * Uses a LOCAL Graph_ctx: never clobber xctx->graph_struct, which an active
 * draw_graph may be using (landmine 11). */

/* Is the CANVAS PIXEL (px, py) inside graph `i`'s PLOT BOX -- the rectangle
 * delineated by the two axes and the two lines opposite them? 0 for a bad
 * index, a non-graph rect, an off-screen graph, a digital strip or no loaded
 * data.
 *
 * This is what decides whether the snap cursor is active, and it is NOT a
 * distance to a trace: inside the box the diamond snaps to the nearest sample
 * of the nearest trace HOWEVER FAR that trace is. The first cut used
 * graph_point_at's `tol` as the gate, so the pointer had to pass within ~20 px
 * of a trace before anything appeared -- reported as "the mouse pointer needs
 * to be too close to the trace".
 *
 * ⚠ gr->cy is NEGATIVE (landmine 3), so S_Y(gy1) and S_Y(gy2) come back in the
 * opposite order to S_X(gx1)/S_X(gx2). Both pairs are normalised rather than
 * assumed.
 *
 * Uses a LOCAL Graph_ctx and brackets graph_flags' hcursor bits exactly as
 * graph_point_at does (landmines 11 and 37) -- this is a query and must not
 * leave the session describing a strip nobody is hovering. */
int graph_plotbox_at(int i, double px, double py)
{
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  xRect *r;
  int saveflags;
  double ax1, ax2, ay1, ay2, t;

  if(!xctx) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return 0;
  if(!xctx->raw || sch_waves_loaded() == -1) return 0;
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  saveflags = xctx->graph_flags & (128 | 256);
  setup_graph_data(i, 0, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->scx == 0.0 || gr->scy == 0.0) return 0;  /* off-screen: no transform */
  if(gr->digital) return 0;                       /* graph_point_at refuses these too */

  ax1 = S_X(gr->gx1); ax2 = S_X(gr->gx2);
  ay1 = S_Y(gr->gy1); ay2 = S_Y(gr->gy2);
  if(ax1 > ax2) { t = ax1; ax1 = ax2; ax2 = t; }
  if(ay1 > ay2) { t = ay1; ay1 = ay2; ay2 = t; }
  return (px >= ax1 && px <= ax2 && py >= ay1 && py <= ay2);
}

/* ---- axis-region drag zoom (issue 0190) ----------------------------------
 *
 * doc/claude/specs/waveform_viewer_modes.md §17. Three functions, deliberately:
 * graph_axis_at() answers WHICH margin a pixel is in, graph_axis_map() is THE
 * formula and graph_axis_zoom() is THE apply. The formula has one home because
 * the gesture (callback.c) and the replayable verb (scheduler.c) both need it
 * and a feature whose feedback and whose commit each compute the same thing
 * will drift -- landmine 45(a). Exposing the map as `xschem get graph_axis_map`
 * is also what lets a headless suite assert BOTH endpoints of a zoom.
 *
 * Issue 0191 (§18) added the WHEEL twin of the map, graph_axis_wheel_map(), in
 * the same shape and reusing graph_axis_at() and graph_axis_zoom() verbatim --
 * plus graph_axis_window(), the one home for "what is this axis's window and
 * what pixel extent does it occupy", which both formulas now call.
 */

/* Which axis-number MARGIN of graph `i` is the CANVAS PIXEL (px, py) in?
 * GRAPH_AXIS_X = the bottom margin (the X tick numbers), GRAPH_AXIS_Y = the
 * left margin (the Y tick numbers), GRAPH_AXIS_NONE = neither.
 *
 * The regions are derived from the PLOT BOX (gr->x1/x2/y1/y2) and the CONTAINER
 * (gr->sx1..sy2), never from marginx/marginy: the right plot edge is
 * rx2 - 0.35*marginx and the top edge is one of three formulas depending on
 * digital/vlegend (setup_graph_data above), so re-deriving the regions from the
 * margin widths would re-implement three special cases and drift.
 *
 * Four refusals, in order, and each one belongs to an owner that was there
 * first:
 *   - inside the plot box: that is the traces' / the reorder's / the marker's;
 *   - outside the container rect: not this strip at all;
 *   - the reorder GRIP column, at every height: graph_marker_press() gives it
 *     the same unconditional first refusal (callback.c), and so does the Tcl
 *     seam (wviewer::strip_handle_at_pixel);
 *   - any pixel graph_legend_at() claims: for vlegend=1 and for digital strips
 *     the legend IS the left margin (legend_slot_hit above).
 * The bottom-LEFT corner answers Y, matching the shipped RMB left-margin arm,
 * which tests graph_left first and never consults graph_bottom (callback.c).
 *
 * ⚠ Deliberately UNLIKE graph_plotbox_at, which this otherwise copies: no
 * loaded-raw requirement and no digital refusal (decisions D-19/D-20). This is
 * pure geometry -- setup_graph_data produces a valid transform from the tokens
 * alone (gx1=0, gx2=1e-6 defaults) -- and both axes are meaningful on a digital
 * strip: X is x1/x2, Y is the ypos1/ypos2 band the RMB left-margin arm already
 * writes. Copying that raw gate would make the whole region silently dead
 * before the first simulation.
 *
 * ⚠ gr->cy is NEGATIVE (landmine 3), so S_Y(gy1) and S_Y(gy2) come back in the
 * opposite order to the S_X pair. Both pairs are normalised, never assumed.
 *
 * Uses a LOCAL Graph_ctx and brackets graph_flags' hcursor bits (landmines 11
 * and 37) -- it is a query and must not leave the session describing a strip
 * nobody is pointing at. Fails closed: bad index, non-graph rect, off-screen. */
int graph_axis_at(int i, double px, double py)
{
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  xRect *r;
  int saveflags;
  double ax1, ax2, ay1, ay2, cx1, cx2, cy1, cy2, t;

  if(!xctx) return GRAPH_AXIS_NONE;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return GRAPH_AXIS_NONE;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return GRAPH_AXIS_NONE;
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  saveflags = xctx->graph_flags & (128 | 256);
  setup_graph_data(i, 0, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->scx == 0.0 || gr->scy == 0.0) return GRAPH_AXIS_NONE; /* off-screen */

  ax1 = S_X(gr->gx1); ax2 = S_X(gr->gx2);
  ay1 = S_Y(gr->gy1); ay2 = S_Y(gr->gy2);
  if(ax1 > ax2) { t = ax1; ax1 = ax2; ax2 = t; }
  if(ay1 > ay2) { t = ay1; ay1 = ay2; ay2 = t; }
  /* 1: the plot box itself is somebody else's */
  if(px >= ax1 && px <= ax2 && py >= ay1 && py <= ay2) return GRAPH_AXIS_NONE;
  /* 2: outside the container rect (sx1..sy2 are computed BEFORE the RECT_OUTSIDE
   * early return, so they are trustworthy whenever the transform is) */
  cx1 = gr->sx1; cx2 = gr->sx2;
  cy1 = gr->sy1; cy2 = gr->sy2;
  if(cx1 > cx2) { t = cx1; cx1 = cx2; cx2 = t; }
  if(cy1 > cy2) { t = cy1; cy1 = cy2; cy2 = t; }
  if(px < cx1 || px > cx2 || py < cy1 || py > cy2) return GRAPH_AXIS_NONE;
  /* 3: the reorder grip owns its column at EVERY height, unconditionally */
  if(gr->reorder_handle && px >= cx2 - GRAPH_REORDER_HANDLE_W) return GRAPH_AXIS_NONE;
  /* 4: the vertical / digital legend IS the left margin */
  if(graph_legend_at(i, px, py) >= 0) return GRAPH_AXIS_NONE;
  /* 5/6: left wins over below, so the bottom-left corner is Y */
  if(px < ax1) return GRAPH_AXIS_Y;
  if(py > ay2) return GRAPH_AXIS_X;
  return GRAPH_AXIS_NONE;  /* top margin, right margin */
}

/* WHAT IS THIS AXIS'S WINDOW, AND WHAT PIXEL EXTENT DOES IT OCCUPY?
 *
 * The ONE home for that question (issue 0191 D-29), called by BOTH formulas --
 * graph_axis_map() (the item-0190 drag) and graph_axis_wheel_map() (the CTRL
 * wheel). `gr` must already have been through the caller's own
 * setup_graph_data() + 128|256 bracket. Writes the data window to *A/*B and the
 * screen-pixel extent of that window along `axis` to *e1/*e2, both pairs
 * normalised low-first.
 *
 * ⚠ THE DIGITAL BRANCH IS WHY THIS EXISTS. graph_axis_zoom() writes a digital
 * strip's Y into ypos1/ypos2, not y1/y2 (the RMB left-margin arm's rule), but
 * graph_axis_map() used to resolve the Y window from gy1/gy2 and S_Y
 * UNCONDITIONALLY. MEASURED before this change, on a strip with y1=0 y2=2.5
 * ypos1=0 ypos2=4: `xschem get graph_axis_map 0 y 636 310` answered
 * `0 1.6437` -- inside the ANALOG window -- and the apply then put that into a
 * band whose real extent is 0..4. So 0190's own decision D-19 ("Y writes
 * ypos1/ypos2 through DG_Y") was documented and not implemented. One helper,
 * written correctly, rather than a second copy of a known-wrong resolution:
 * landmine 45(a)/47(b).
 *
 * ⚠ gr->cy (and gr->dcy) are NEGATIVE (landmine 3), so the Y pixel pair comes
 * back inverted -- S_Y(gy1) is the BOTTOM pixel. Both pairs are normalised here,
 * once, so neither caller has to remember it.
 *
 * ⚠ The three branches assign LOCALS and the out-parameters are written once at
 * the end, rather than the shorter `*A = ...` form: a line beginning with `*`
 * is what a C comment continuation looks like, and the source-level tripwires
 * this file's suite runs (test_wave_axis_zoom.tcl, az_count_code) skip exactly
 * those lines -- so the digital branch would have been invisible to CS4. The
 * same reason graph_axis_map's `zlo` and graph_axis_wheel_map's are named
 * locals. */
static void graph_axis_window(Graph_ctx *gr, int axis,
                              double *A, double *B, double *e1, double *e2)
{
  double a, b, f1, f2, t;

  if(axis == GRAPH_AXIS_X) {
    a = gr->gx1; b = gr->gx2;
    f1 = S_X(gr->gx1); f2 = S_X(gr->gx2);
  } else if(gr->digital) {
    a = gr->ypos1; b = gr->ypos2;
    f1 = DS_Y(gr->ypos1); f2 = DS_Y(gr->ypos2);
  } else {
    a = gr->gy1; b = gr->gy2;
    f1 = S_Y(gr->gy1); f2 = S_Y(gr->gy2);
  }
  if(f1 > f2) { t = f1; f1 = f2; f2 = t; }
  if(a  > b)  { t = a;  a  = b;  b  = t;  }
  *A = a; *B = b; *e1 = f1; *e2 = f2;
}

/* THE MAP. `p0` (press) and `p1` (release) are CANVAS PIXELS along `axis`: px
 * for GRAPH_AXIS_X, py for GRAPH_AXIS_Y. On success writes the new data window
 * to *lo / *hi and returns 1.
 *
 * Returns 0 -- and writes nothing -- for a bad index, a non-graph rect, an
 * off-screen graph, an unknown axis, or a travel of `clicktol` SCREEN PIXELS or
 * less. The threshold is a parameter rather than a constant here because the
 * 3.0 belongs to callback.c's file-private GRAPH_CLICK_TOL, which answers the
 * click-vs-drag question and must not be confused with GRAPH_TRACE_PICK_TOL
 * (landmine 20's warning is exactly why it is file-private).
 *
 * The maths, once:
 *
 *   A = min(g_lo, g_hi), B = max(...), R = B - A     the CURRENT window
 *   u(p) = (G_axis(p) - A) / R                       a pixel, normalised 0..1
 *   ua = u(p0), ub = u(p1), s = ub - ua
 *
 *   s > 0  (forward drag: X left->right, Y upward)  ZOOM IN
 *       lo = A + ua*R,  hi = A + ub*R
 *       i.e. exactly the two data coordinates the press and the release land on.
 *   s < 0  (reverse drag)                            ZOOM OUT
 *       R2 = R / |s|,  lo = A - ub*R2,  hi = lo + R2
 *       i.e. the CURRENT window ends up occupying the screen span between the
 *       release and the press. The `- ub*R2` term is the ANCHOR: without it the
 *       new range has the right WIDTH and the wrong POSITION, which passes every
 *       "the range grew" assertion. That is why both endpoints are asserted.
 *
 * Two worked checks, which are also two legs of the suite:
 *   - a FULL-EXTENT reverse drag leaves the window unchanged: ua=1, ub=0, s=-1,
 *     R2=R, lo = A - 0 = A, hi = A + R = B. (Note this is precisely the case
 *     the anchor term vanishes in -- hence the other checks.)
 *   - a HALF-EXTENT reverse drag from the far edge: ua=1, ub=0.5, s=-0.5,
 *     R2=2R, lo = A - 0.5*2R = A - R, hi = A + R.
 *
 * ⚠ Everything runs in `gr` space, which IS log space when logx/logy is set --
 * gr->gx1..gy2 and G_X/G_Y are already log-mapped there. The shipped box zoom
 * writes dtoa(G_X(...)) straight into x1/x2 with no pow(10,.) for the same
 * reason; applying one here would double-convert (landmine 35 from the other
 * side, decision D-18).
 *
 * ⚠ p0/p1 are CLAMPED to the plot extent (decision D-11): a drag that overshoots
 * the box by 2 px must commit, not silently cancel. GRAPHPAN keeps the drag
 * routed to the graph after the pointer leaves the strip, so the release arrives.
 *
 * Local Graph_ctx + the 128|256 bracket, like every query on this pattern. */
int graph_axis_map(int i, int axis, double p0, double p1,
                   double *lo, double *hi, double clicktol)
{
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  xRect *r;
  int saveflags;
  double e1, e2, A, B, R, ua, ub, s, f, R2, zlo;

  if(!xctx || !lo || !hi) return 0;
  if(axis != GRAPH_AXIS_X && axis != GRAPH_AXIS_Y) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return 0;
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  saveflags = xctx->graph_flags & (128 | 256);
  setup_graph_data(i, 0, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->scx == 0.0 || gr->scy == 0.0) return 0;  /* off-screen: no transform */

  graph_axis_window(gr, axis, &A, &B, &e1, &e2);
  R = B - A;
  if(R == 0.0 || e2 == e1) return 0;
  /* clamp both ends to the plot extent -- an overshoot commits (D-11) */
  if(p0 < e1) p0 = e1; if(p0 > e2) p0 = e2;
  if(p1 < e1) p1 = e1; if(p1 > e2) p1 = e2;
  /* click, not drag: no write, no log */
  if(fabs(p1 - p0) <= clicktol) return 0;
  /* the pixel->data inverse MUST match the transform graph_axis_window used for
   * the extent, or the map is self-inconsistent on a digital strip: DS_Y's
   * inverse is DG_Y, never G_Y */
  if(axis == GRAPH_AXIS_X) {
    ua = (G_X(X_TO_XSCHEM(p0)) - A) / R;
    ub = (G_X(X_TO_XSCHEM(p1)) - A) / R;
  } else if(gr->digital) {
    ua = (DG_Y(Y_TO_XSCHEM(p0)) - A) / R;
    ub = (DG_Y(Y_TO_XSCHEM(p1)) - A) / R;
  } else {
    ua = (G_Y(Y_TO_XSCHEM(p0)) - A) / R;
    ub = (G_Y(Y_TO_XSCHEM(p1)) - A) / R;
  }
  s = ub - ua;
  if(s > 0.0) {                      /* zoom IN */
    *lo = A + ua * R;
    *hi = A + ub * R;
  } else {                           /* zoom OUT, anchored */
    f = -s;
    if(f < 1.0 / GRAPH_AXIS_ZOOM_MAX_FACTOR) f = 1.0 / GRAPH_AXIS_ZOOM_MAX_FACTOR;
    R2 = R / f;
    /* THE ANCHORED ZOOM-OUT, and the only place it is written. A named local
     * rather than `*lo = ...` so the expression sits on a line a source-level
     * tripwire can count (tests/headless/test_wave_axis_zoom.tcl AS1 skips
     * lines beginning with `*`, which is how a C comment continuation looks). */
    zlo = A - ub * R2;
    *lo = zlo;
    *hi = zlo + R2;
  }
  if(*hi == *lo) *hi += 1e-6;        /* the shipped idiom (callback.c box zoom) */
  dbg(1, "graph_axis_map: graph=%d axis=%d p0=%g p1=%g -> %g %g\n", i, axis, p0, p1, *lo, *hi);
  return 1;
}

/* THE WHEEL MAP (issue 0191, doc/claude/specs/waveform_viewer_modes.md §18) --
 * one CTRL+wheel click in an axis-number margin, anchored at the pointer.
 * `p` is the pointer's CANVAS PIXEL along `axis`; `dir` is +1 in / -1 out.
 *
 * The maths, and it IS the specification:
 *
 *   A,B,R  the current window (graph_axis_window, shared with the drag map)
 *   q      = G_axis(p)                the data coordinate under the pointer
 *   u      = (q - A) / R              its fraction of the window, 0..1
 *   f      = dir > 0 ? K : 1/K        K = GRAPH_AXIS_WHEEL_FACTOR
 *   R2     = R * f
 *   lo     = q - u * R2               THE ANCHOR
 *   hi     = lo + R2
 *
 * Invariant: (q - lo)/(hi - lo) == u, so q keeps its fraction of the window and
 * therefore its SCREEN PIXEL -- which is the whole user ask ("the point on the
 * trace at the mouse pointer will remain there after zoom"). N clicks in and N
 * clicks out restore the window exactly, because f and 1/f are exact inverses
 * and q is a fixed point of both steps; the shipped Shift+wheel arms
 * (callback.c) are x0.8 / x1.2 and lose 4% per round trip.
 *
 * NO GRAPH_AXIS_ZOOM_MAX_FACTOR here (D-34), deliberately: that constant guards
 * the drag map's `R / |s|`, a division by a user-controlled span that can
 * approach zero. R * f divides nothing, and repeated clicks shrink R
 * geometrically without ever reaching it in finite steps -- `hi == lo` catches
 * the denormal end, exactly as the shipped box zoom does.
 *
 * `p` is CLAMPED to the plot extent (D-11, the drag map's rule): a pointer 2 px
 * outside the box still zooms, it does not silently refuse. Log axes need
 * nothing special -- gr space IS log space (landmine 35 from the other side).
 * Local Graph_ctx + the 128|256 bracket, like every query on this pattern. */
int graph_axis_wheel_map(int i, int axis, double p, int dir,
                         double *lo, double *hi)
{
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  xRect *r;
  int saveflags;
  double A, B, R, e1, e2, q, u, f, R2, zlo;

  if(!xctx || !lo || !hi) return 0;
  if(axis != GRAPH_AXIS_X && axis != GRAPH_AXIS_Y) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return 0;
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  saveflags = xctx->graph_flags & (128 | 256);
  setup_graph_data(i, 0, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->scx == 0.0 || gr->scy == 0.0) return 0;  /* off-screen: no transform */

  graph_axis_window(gr, axis, &A, &B, &e1, &e2);
  R = B - A;
  if(R == 0.0 || e2 == e1) return 0;
  if(p < e1) p = e1; if(p > e2) p = e2;
  /* same rule as the drag map: DS_Y's inverse is DG_Y on a digital strip */
  if(axis == GRAPH_AXIS_X) {
    q = G_X(X_TO_XSCHEM(p));
  } else if(gr->digital) {
    q = DG_Y(Y_TO_XSCHEM(p));
  } else {
    q = G_Y(Y_TO_XSCHEM(p));
  }
  u = (q - A) / R;
  f = (dir > 0) ? GRAPH_AXIS_WHEEL_FACTOR : 1.0 / GRAPH_AXIS_WHEEL_FACTOR;
  R2 = R * f;
  /* THE ANCHOR, and the only place it is written. Drop the `- u * R2` term and
   * the new range still has the right WIDTH -- every "the range shrank" leg
   * passes while the window has slid sideways. Landmine 45(a)/47(b); a named
   * local rather than `*lo = ...` so the expression sits on a line a
   * source-level tripwire can count (the count_code idiom skips lines starting
   * with `*`, which is what a C comment continuation looks like). */
  zlo = q - u * R2;
  *lo = zlo;
  *hi = zlo + R2;
  if(*hi == *lo) *hi += 1e-6;        /* the shipped idiom (callback.c box zoom) */
  dbg(1, "graph_axis_wheel_map: graph=%d axis=%d p=%g dir=%d -> %g %g\n",
      i, axis, p, dir, *lo, *hi);
  return 1;
}

/* THE APPLY, shared by the gesture (callback.c) and by `xschem graph_axis_zoom`.
 * Returns 1 when at least one token was written.
 *
 * X propagates: rect `i` AND every PARTICIPATING rect, reproducing the shipped
 * predicate of the MMB pan / RMB box zoom / arrow pans verbatim --
 *   r->sel || (same_sim_type && !(r->flags & 2)) || k == i
 * where same_sim_type additionally requires the MASTER (`i`) not to be
 * `unlocked` and the two sim_type tokens to match. ⚠ This is NOT the viewer's
 * `sharedx` flag, which the C engine cannot see: propagation has always come
 * from this predicate, and wviewer::graph_props never emits `unlocked`, so in
 * the viewer X follows every strip of the same sim_type whatever sharedx says.
 * Y is per-graph and touches rect `i` only.
 *
 * A DIGITAL strip's Y is the ypos1/ypos2 band, not y1/y2 -- mirroring the RMB
 * left-margin arm (callback.c).
 *
 * NO set_modify and NO push_undo: landmine 19 -- a graph gesture is view state,
 * every pan/box-zoom/fit already rewrites these tokens silently, and the ASE
 * viewer's buffer is read-only for life so a dirty flag there would be a lie.
 * Exactly ONE log_action line, in the VERB form, so a replay reproduces the
 * whole propagation from one line (log_action is a plain varargs printf, so
 * %.17g is fine here -- my_snprintf is not and must not be used for it). */
int graph_axis_zoom(int i, int axis, double lo, double hi)
{
  xRect *r, *rk;
  int k, wrote = 0;

  if(!xctx) return 0;
  if(axis != GRAPH_AXIS_X && axis != GRAPH_AXIS_Y) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return 0;
  if(axis == GRAPH_AXIS_X) {
    /* the participation predicate lives in graph_shares_x() (spec D2): this
     * loop used to hold the second hand-written copy of it, and
     * graph_fullxzoom() now needs the same answer to know which databases its
     * union has to span. One predicate, three callers. */
    for(k = 0; k < xctx->rects[GRIDLAYER]; ++k) {
      rk = &xctx->rect[GRIDLAYER][k];
      if(!graph_shares_x(i, k)) continue;
      my_strdup(_ALLOC_ID_, &rk->prop_ptr, subst_token(rk->prop_ptr, "x1", dtoa(lo)));
      my_strdup(_ALLOC_ID_, &rk->prop_ptr, subst_token(rk->prop_ptr, "x2", dtoa(hi)));
      wrote = 1;
    }
  } else {
    /* `digital` is read straight OFF THE RECT, never through a scratch
     * Graph_ctx: setup_graph_data() parses it BELOW its off-screen early return
     * (landmine 37a), so an off-screen strip would answer 0 and this would
     * silently write y1/y2 into a digital graph. Measured, while writing the
     * suite: the AV5 leg failed exactly that way. */
    const char *dv = get_tok_value(r->prop_ptr, "digital", 0);
    int digital = dv[0] ? atoi(dv) : 0;
    my_strdup(_ALLOC_ID_, &r->prop_ptr,
              subst_token(r->prop_ptr, digital ? "ypos1" : "y1", dtoa(lo)));
    my_strdup(_ALLOC_ID_, &r->prop_ptr,
              subst_token(r->prop_ptr, digital ? "ypos2" : "y2", dtoa(hi)));
    wrote = 1;
  }
  if(wrote) {
    log_action("xschem graph_axis_zoom %d %s %.17g %.17g\n",
               i, axis == GRAPH_AXIS_X ? "x" : "y", lo, hi);
  }
  return wrote;
}

/* ---- viewer plan item 9: the diamond SNAP CURSOR -------------------------
 *
 * While the pointer hovers a waveform graph, a small diamond sticks to the
 * NEAREST SAMPLE of the nearest trace, and the sample's raw x/y are published
 * for the status bar (item 10) through `xschem get graph_snap`.
 *
 * The query is 100% shipped: graph_point_at() already returns the identity of
 * the nearest sample, with hit.sx/hit.sy in SCREEN PIXELS and hit.x/hit.y as
 * the RAW values (landmine 35 -- never the mylog10()'d ones, which clamp a
 * zero sample to -35 and would read back as 1e-35).
 *
 * The cadence is draw_snap_cursor()'s (callback.c ~2422), minus its
 * X_TO_SCREEN calls because the hit is already screen: window only
 * (draw_pixmap = 0), erase the old glyph with gctiled, draw the new one,
 * restore. Because nothing is ever written to save_pixmap, the glyph cannot
 * reach a print or an SVG -- which is what the flags-bit-16 "UI chrome" rule
 * exists to guarantee elsewhere, obtained here for free.
 *
 * ⚠ COST. graph_point_at() walks every sample of every trace of the strip,
 * and item 9 runs it on BARE HOVER rather than during a drag. Two brakes:
 * the query is skipped entirely unless the mouse PIXEL changed (the repaint
 * early-out in draw_snap_cursor suppresses the paint but not the query -- that
 * is not enough here), and it never runs while any gesture is armed. */

/* The glyph: four segments, top->right->bottom->left->top, in SCREEN pixels.
 * draw_snap_cursor_shape() (callback.c) draws the same diamond but takes
 * schematic coordinates; this one is fed straight from GraphPointHit. */
static void graph_snap_shape(GC gc, double sx, double sy, int size)
{
  double l = sx - size, r = sx + size, t = sy - size, b = sy + size;
  draw_xhair_line(gc, size, sx, t,  r,  sy);
  draw_xhair_line(gc, size, r,  sy, sx, b);
  draw_xhair_line(gc, size, sx, b,  l,  sy);
  draw_xhair_line(gc, size, l,  sy, sx, t);
}

/* Erase the diamond at (sx, sy) by copying that patch of save_pixmap back over
 * the window.
 *
 * ⚠ NOT the gctiled stroke that draw_snap_cursor()/erase_snap_cursor() use on
 * this platform. That is the SHIPPED erase for the schematic snap cursor and it
 * is guarded there by `fix_broken_tiled_fill || !_unix` -- but with
 * FIX_BROKEN_TILED_FILL undefined (the default) the guard picks the tiled
 * stroke, and in a VIEWER window that stroke does not remove the glyph: the
 * diamond left a TRAIL across the strip, and only a full redraw (`f` = fit)
 * cleared it. Reported from a real session, and the reason this function exists
 * instead of a one-line call to graph_snap_shape(xctx->gctiled, ...).
 *
 * The copy-back is what erase_snap_cursor() itself falls back to on platforms
 * where the tiled fill is known broken, so this is not a new mechanism -- it is
 * the reliable one of the two, used unconditionally. save_pixmap is maintained
 * by the ordinary double-buffered draw(), and the glyph is never written into
 * it (draw_pixmap is 0 for the whole cadence), so the patch underneath is
 * always the clean plot. */
static void graph_snap_erase(double sx, double sy, int size)
{
  int lw = INT_LINE_W(xctx->lw);
  int x = (int)sx - lw - size;
  int y = (int)sy - lw - size;
  unsigned int wh = (unsigned int)(2 * lw + 2 * size);
  MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
              x, y, wh, wh, x, y);
}

/* Erase the painted diamond (if any) and disarm. Safe to call at any time and
 * any number of times -- LeaveNotify, a gesture starting, the pointer moving
 * off every graph, and clear_drawing() all funnel through here. */
void graph_snap_clear(void)
{
  int size;
  if(!has_x) { xctx->graph_snap_on = 0; return; }
  if(xctx->graph_snap_on) {
    size = tclgetintvar("graph_snap_cursor_size");
    if(size < 1) size = 4;
    graph_snap_erase(xctx->graph_snap_sx, xctx->graph_snap_sy, size);
  }
  xctx->graph_snap_on = 0;
  xctx->graph_snap_gi = 0;
  xctx->graph_snap_wave = 0;
  xctx->graph_snap_have_prev = 0;
}

/* The hover pump. (mx, my) is the raw canvas pixel from the MotionNotify. */
void draw_graph_snap_cursor(int mx, int my)
{
  GraphPointHit hit;
  int i, size, found = 0, gi = -1;
  int prev_pixmap, prev_window;

  if(!has_x) return;
  /* Off by default and armed PER CONTEXT (`xschem set graph_snap_cursor 1`),
   * not by a global Tcl var -- the pick walks every sample of every trace, and
   * graph_point_at is shared with every embedded schematic graph in the tree.
   * The no_grid precedent, for the same blast-radius reason. */
  if(!xctx->graph_snap) { graph_snap_clear(); return; }
  /* YIELD to every armed gesture. A marker drag, a strip or trace drag, a
   * cursor drag, a graph pan and a box zoom all own the pointer while they
   * run, and a diamond chasing the samples underneath them is noise at best.
   * ui_state != 0 is deliberately the broadest possible test: in a read-only
   * viewer canvas it is 0 at rest, so anything set means a gesture. */
  if(xctx->ui_state || xctx->graph_marker_dragmode) { graph_snap_clear(); return; }
  if(!xctx->mouse_inside) { graph_snap_clear(); return; }

  /* THE BRAKE. graph_point_at() walks every sample of every trace, so the
   * query itself -- not just the repaint -- has to be skipped when the pointer
   * has not actually moved. Motion events repeat freely (autorepeat, tablet
   * jitter, a redraw pump), and draw_snap_cursor()'s pos_changed test guards
   * only the paint. */
  if(xctx->graph_snap_have_prev &&
     mx == xctx->graph_snap_prev_mx && my == xctx->graph_snap_prev_my) return;
  xctx->graph_snap_prev_mx = mx;
  xctx->graph_snap_prev_my = my;
  xctx->graph_snap_have_prev = 1;

  /* THE GATE IS THE PLOT BOX, NOT A DISTANCE TO A TRACE. Inside the box the
   * diamond snaps to the nearest sample of the nearest trace however far away
   * that trace is; outside it there is no snap at all. graph_point_at's `tol`
   * is therefore handed a value nothing can exceed -- the ranking it does
   * (nearest trace by point-to-segment distance, then nearest sample on it) is
   * what we want, the threshold is not.
   * Strips do not overlap, so at most one box contains the pointer; the loop
   * still ranks, so a future overlapping layout degrades gracefully. */
  for(i = 0; i < xctx->rects[GRIDLAYER]; ++i) {
    GraphPointHit h;
    if(!(xctx->rect[GRIDLAYER][i].flags & 1)) continue;   /* not a graph */
    if(!graph_plotbox_at(i, (double)mx, (double)my)) continue;
    if(graph_point_at(i, (double)mx, (double)my, 1e30, -1, -1, &h)) {
      if(!found || h.dist < hit.dist) { hit = h; found = 1; gi = i; }
    }
  }

  if(!found) { graph_snap_clear(); return; }

  /* Nothing to repaint when the snapped POINT has not changed. Issue 0193 moved
   * this from the sample to the point ON THE CURVE, so at a zoom tighter than
   * the sample spacing the diamond still has somewhere to be -- it now slides
   * along the segment under the pointer instead of vanishing. The equality test
   * still earns its keep on the common case (a near-vertical edge, where many
   * pointer pixels project onto the same place). */
  if(xctx->graph_snap_on && gi == xctx->graph_snap_gi &&
     hit.wave == xctx->graph_snap_wave &&
     hit.seg_sx == xctx->graph_snap_sx && hit.seg_sy == xctx->graph_snap_sy) return;

  size = tclgetintvar("graph_snap_cursor_size");
  if(size < 1) size = 4;
  if(xctx->graph_snap_on) {
    graph_snap_erase(xctx->graph_snap_sx, xctx->graph_snap_sy, size);
  }
  prev_pixmap = xctx->draw_pixmap;
  prev_window = xctx->draw_window;
  xctx->draw_pixmap = 0;   /* window only: the glyph must never enter save_pixmap,
                            * or the copy-back erase above would restore it */
  xctx->draw_window = 1;
  graph_snap_shape(xctx->gc[xctx->crosshair_layer], hit.seg_sx, hit.seg_sy, size);
  xctx->draw_pixmap = prev_pixmap;
  xctx->draw_window = prev_window;

  xctx->graph_snap_on = 1;
  xctx->graph_snap_gi = gi;
  xctx->graph_snap_wave = hit.wave;
  /* issue 0193: the POINT ON THE CURVE, not the nearest sample. A trace is a
   * polyline and the user is pointing at the polyline; below the sample spacing
   * the nearest sample is off-screen, which is why the diamond used to snap to
   * one lone point and then disappear entirely. The readout follows it, so
   * `xschem get graph_snap` now reports an INTERPOLATED x/y -- still unscaled
   * (landmine 35), and still the value the eye is on. */
  xctx->graph_snap_sx = hit.seg_sx;
  xctx->graph_snap_sy = hit.seg_sy;
  xctx->graph_snap_x = hit.seg_x;   /* RAW -- landmine 35 */
  xctx->graph_snap_y = hit.seg_y;
}

int graph_point_at(int i, double px, double py, double tol,
                   int restrict_wave, int restrict_dataset, GraphPointHit *hit)
{
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  GraphPointHit best;
  char *node = NULL, *sweep = NULL;
  char *saven, *saves, *nptr, *sptr;
  const char *ntok, *stok;
  /* the LAST non-empty `sweep=` token seen, i.e. the sweep variable's NAME (not
   * its column) for the entry being walked -- a `sweep=` list shorter than the
   * `node=` list carries its last entry forward. Points into `sweep`, which
   * my_strtok_r splits IN PLACE and leaves NUL terminated, so earlier tokens
   * stay valid until `sweep` is freed. */
  const char *sweep_name = NULL;
  char *ntok_copy = NULL;
  char *express = NULL;
  char *custom_rawfile = NULL;
  char *sim_type = NULL;
  char *node_rawfile = NULL;
  char *node_sim_type = NULL;
  const char *ptr;
  xRect *r;
  int sweep_idx = 0, idx, expression, autoload;
  int node_dataset = -1;
  int wcnt = -1, best_wave = -1;
  int valid_rawfile = 1, switched = 0, saveflags;
  /* per-NODE state (issue 0305): the registry slot to unwind this entry's
   * `%<rawfile>` switch to, whether THIS entry's database resolved, and this
   * entry's sweep column IN ITS OWN database */
  int node_saved_idx = -1, node_valid = 1, node_sweep_idx = 0;
  int entry_extra_idx = 0;  /* the database that was current on the way in */
  int entry_prev_idx = -1;  /* ...and where switch_back pointed on the way in */
  double best_dist = 0.0;
  double start, end;

  if(!xctx) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return 0;
  if(!xctx->raw || sch_waves_loaded() == -1) return 0;
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  memset(&best, 0, sizeof(best));
  /* landmine 37: setup_graph_data() rewrites graph_flags' hcursor bits from the
   * rect it is given. This is a query (the `graph_trace_at`/`graph_near_wave`
   * verbs, and one call per motion event during a marker drag), so it must not
   * leave the session describing a strip nobody is hovering. */
  saveflags = xctx->graph_flags & (128 | 256);
  setup_graph_data(i, 0, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  /* setup_graph_data() returns early for an off-screen graph without computing
   * the transform (the RECT_OUTSIDE test); a zero scale means "no transform" */
  if(gr->scx == 0.0 || gr->scy == 0.0) return 0;
  if(gr->digital) return 0;
  if(tol < 0.0) tol = 0.0;

  autoload = !strboolcmp(get_tok_value(r->prop_ptr,"autoload", 0), "true");
  if(autoload == 0) autoload = 2;
  else if(autoload == 1) autoload = 33;

  my_strdup2(_ALLOC_ID_, &node, get_tok_value(r->prop_ptr,"node", 0));
  my_strdup2(_ALLOC_ID_, &sweep, get_tok_value(r->prop_ptr,"sweep", 0));
  ptr = get_tok_value(r->prop_ptr,"rawfile", 0);
  if(!ptr[0]) {
    if(xctx->raw->rawfile) my_strdup2(_ALLOC_ID_, &custom_rawfile, xctx->raw->rawfile);
    else my_strdup2(_ALLOC_ID_, &custom_rawfile, "");
  } else {
    my_strdup2(_ALLOC_ID_, &custom_rawfile, ptr);
  }
  my_strdup2(_ALLOC_ID_, &sim_type, get_tok_value(r->prop_ptr,"sim_type", 0));

  /* `rawfile`/`sim_type` are GRAPH-level tokens, so the switch is made once, not
   * once per node: the per-node form re-switched an already-switched raw and the
   * single extra_rawfile(5,...) below then restored only one level of it. */
  entry_extra_idx = xctx->extra_idx;
  entry_prev_idx = xctx->extra_prev_idx;
  if(custom_rawfile[0]) {
    if(extra_rawfile(autoload, custom_rawfile,
       sim_type[0] ? sim_type : (xctx->raw->sim_type ? xctx->raw->sim_type : NULL),
       -1.0, -1.0) == 0) {
      valid_rawfile = 0;
    } else {
      switched = 1;
    }
  }

  start = (gr->gx1 <= gr->gx2) ? gr->gx1 : gr->gx2;
  end   = (gr->gx1 <= gr->gx2) ? gr->gx2 : gr->gx1;

  nptr = node;
  sptr = sweep;
  while( (ntok = my_strtok_r(nptr, "\n", "\"", 4, &saven)) ) {
    /* the counter tracks the node's POSITION in the list, so it must advance
     * for every entry including the bus ones skipped below (find_closest_wave()
     * counts the same way, and hilight_wave is in that index space) */
    wcnt++;
    /* consume the sweep token and clear the strtok seeds BEFORE the bus skip --
     * see the matching comment in find_closest_wave(): `continue` with nptr
     * still non-NULL re-seeds my_strtok_r from the head of `node` and loops
     * forever on a leading bus entry, and a bus that does not consume its sweep
     * token shifts every following trace onto the wrong sweep variable. */
    stok = my_strtok_r(sptr, "\t\n ", "\"", 0, &saves);
    nptr = sptr = NULL;
    if(strstr(ntok, ",")) {
      if(find_nth(ntok, ";,", "\"", 0, 2)[0]) continue; /* bus signal: skip */
    }
    /* the sweep column must be resolved for EVERY entry before the restriction
     * skip: a `sweep` list shorter than the `node` list carries its last entry
     * forward (stok comes back NULL and sweep_idx keeps its value), so skipping
     * first made a restricted walk -- i.e. every anchor drag -- fall back to raw
     * column 0 and find nothing. graph_wave_resolve() has the same ordering. */
    if(stok && stok[0]) {
      sweep_name = stok;
      sweep_idx = get_raw_index(stok, NULL);
      if(sweep_idx == -1) sweep_idx = 0;
    }
    if(restrict_wave >= 0 && wcnt != restrict_wave) continue;
    /* ⚠ ISSUE 0305 -- THIS WALKER USED TO READ ONLY THE `%<n>` DATASET DIGITS
     * and drop the `%<rawfile>` that follows them, so a trace plotted from a
     * FOREIGN database (spec D1) was resolved against whatever database happens
     * to be current -- for a mixed analog+VCD strip the analog one, where a VCD
     * signal name does not exist. The trace drew (draw_graph does honour it) and
     * was then unpickable, unhoverable and unmarkable, which is the whole of
     * issue 0305's symptom for this function.
     * The switch is per NODE, so it is unwound per node too, at the bottom of
     * this loop body -- by INDEX, back to whatever was current when this entry
     * started (which is the graph-level `rawfile=` when the graph has one). */
    node_saved_idx = xctx->extra_idx;
    node_valid = valid_rawfile;
    node_sweep_idx = sweep_idx;
    node_token_split(ntok, &ntok_copy, &node_dataset, &node_rawfile, &node_sim_type,
                     node_dflt_sim_type(sim_type));
    if(node_rawfile[0] && xctx->raw && xctx->raw->values) {
      if(extra_rawfile(autoload, node_rawfile, node_sim_type, -1.0, -1.0) == 0) {
        node_valid = 0;
      } else {
        /* the sweep COLUMN is a per-database index, so it must be looked up in
         * the database the trace lives in -- draw_graph() resolves it after its
         * own switch for exactly this reason. Kept in a per-node copy so the
         * carry-forward of a short `sweep=` list still hands the NEXT entry the
         * index it had in ITS database.
         * ⚠ RE-RESOLVED ON EVERY ENTRY THAT TOOK THE SWITCH, by NAME, not only
         * on the entries that carry their OWN `sweep=` token: a carried-forward
         * index was resolved in the PREVIOUS database and means nothing here.
         * With a `sweep=` list shorter than the `node=` list (the documented
         * carry-forward case) that index can be past the end of the foreign
         * database's values[] -- an out-of-bounds read, and a SEGFAULT on a
         * cross-DB strip whose foreign database has fewer columns. */
        node_sweep_idx = 0;
        if(sweep_name && sweep_name[0]) {
          node_sweep_idx = get_raw_index(sweep_name, NULL);
          if(node_sweep_idx == -1) node_sweep_idx = 0;
        }
      }
    }
    /* belt and braces: whatever the arithmetic above decided, the column must be
     * one the database that is NOW current actually has (values holds nvars+1
     * columns, the last being the expression scratch). */
    if(xctx->raw && (node_sweep_idx < 0 || node_sweep_idx >= xctx->raw->nvars)) node_sweep_idx = 0;

    idx = -1;
    expression = 0;
    if(xctx->raw->values) {
      if(strstr(ntok_copy, ";")) {
        my_strdup2(_ALLOC_ID_, &express, find_nth(ntok_copy, ";", "\"", 0, 2));
      } else {
        my_strdup2(_ALLOC_ID_, &express, ntok_copy);
      }
      if(strpbrk(express, " \n\t")) expression = 1;
    }
    if(expression) idx = xctx->raw->nvars; /* the scratch column (values has nvars+1) */
    else if(express) idx = get_raw_index(express, NULL);

    if(sch_waves_loaded() != -1 && node_valid && idx != -1) {
      int p, dset, ofs = 0, ofs_end;
      double xx, yy, prev_sx = 0.0, prev_sy = 0.0;
      double nd_min = -1.0;   /* smallest SEGMENT distance found for THIS node */
      double nd_pdist = -1.0; /* smallest POINT distance found for THIS node */
      double nd_x = 0.0, nd_y = 0.0, nd_sx = 0.0, nd_sy = 0.0;
      int nd_dataset = 0, nd_point = 0;
      /* the same four again, over samples the x window does NOT contain. Issue
       * 0193 keeps off-window samples in the walk (they own the segment that
       * spans the view), but a MARKER must still land on the same sample it
       * always did, so the in-window answer wins whenever there is one and this
       * is only the fallback for "the zoom is tighter than the sample spacing",
       * where there is no in-window sample to prefer. */
      double no_pdist = -1.0;
      double no_x = 0.0, no_y = 0.0, no_sx = 0.0, no_sy = 0.0;
      int no_dataset = 0, no_point = 0;
      /* the winning point ON THE CURVE, in screen pixels (issue 0193), and the
       * sample that segment STARTS at -- the anchor a marker record keeps so it
       * is still addressable by (dataset, point) */
      double nd_ex = 0.0, nd_ey = 0.0;
      int nd_epoint = 0, nd_edataset = 0;
      double prev_xx = 0.0;
      int prev_point = 0;
      int have_prev;
      for(dset = 0; dset < xctx->raw->datasets; dset++) {
        SPICE_DATA *gvx = xctx->raw->values[node_sweep_idx];
        SPICE_DATA *gvy;
        ofs_end = ofs + xctx->raw->npoints[dset];
        if(node_dataset != -1 && node_dataset != dset) { ofs = ofs_end; continue; }
        if(restrict_dataset >= 0 && restrict_dataset != dset) { ofs = ofs_end; continue; }
        /* plot_raw_custom_data() returns -1 on a malformed/overflowing RPN
         * WITHOUT touching the scratch column, so measuring afterwards would
         * compare against whatever expression was evaluated last. */
        if(expression &&
           plot_raw_custom_data(node_sweep_idx, ofs, ofs_end - 1, express, NULL) < 0) {
          ofs = ofs_end;
          continue;
        }
        gvy = xctx->raw->values[idx];
        have_prev = 0;
        for(p = ofs; p < ofs_end; p++) {
          double sx, sy, d, ddx, ddy, pd, ex = 0.0, ey = 0.0;
          int in, seg_ok;
          if(gr->logx) xx = mylog10(gvx[p]); else xx = gvx[p];
          if(gr->logy) yy = mylog10(gvy[p]); else yy = gvy[p];
          sx = S_X(xx);
          sy = S_Y(yy);
          /* a non-finite screen coordinate cannot be near anything and would
           * poison the distance arithmetic */
          if(!(sx > -1e9 && sx < 1e9 && sy > -1e9 && sy < 1e9)) { have_prev = 0; continue; }
          in = (xx >= start && xx <= end);
          /* ⚠ ISSUE 0193 -- THE CLIP THAT USED TO LIVE HERE WAS THE BUG, and it
           * disagreed with the one the RENDERER uses. This loop used to open
           * with `if(xx < start || xx > end) { have_prev = 0; continue; }`,
           * dropping the sample AND breaking the chain, so no segment ever
           * crossed the window edge. draw_graph's own test (~8221) is
           * `xxfollowing >= start && xxprevious <= end`: it KEEPS one sample
           * outside each edge precisely so the segment spanning the view is
           * still stroked. Hence the three regimes the user hit -- >=2 samples
           * in view: fine; exactly 1: have_prev never set, so `d = pd` and only
           * that one sample answered; 0 (zoom tighter than the sample spacing,
           * e.g. a 2-sample enable edge or a 1-sample supply): the loop body
           * never ran, nd_min stayed -1 and the trace was UNPICKABLE while
           * plainly visible on screen.
           * A segment is relevant unless BOTH its ends are off the same edge. */
          seg_ok = have_prev && !(xx < start && prev_xx < start)
                             && !(xx > end   && prev_xx > end);
          ddx = sx - px;
          ddy = sy - py;
          pd = sqrt(ddx * ddx + ddy * ddy);
          if(seg_ok) {
            d = graph_point_seg_dist(px, py, prev_sx, prev_sy, sx, sy, &ex, &ey);
          } else if(in) {
            /* a lone in-window sample with no usable neighbour: it IS the curve */
            d = pd; ex = sx; ey = sy;
          } else {
            d = -1.0;        /* wholly outside and no segment: contributes nothing */
          }
          if(d >= 0.0 && (nd_min < 0.0 || d < nd_min)) {
            nd_min = d;
            nd_ex = ex;
            nd_ey = ey;
            /* the segment's LEFT sample when there is a segment, else the lone
             * sample itself -- either way an index that addresses this trace */
            nd_epoint = seg_ok ? prev_point : p;
            nd_edataset = dset;
          }
          /* the nearest SAMPLE, tracked independently of the ranking metric and
           * frozen HERE -- values[] must not be read again after this loop */
          if(in) {
            if(nd_pdist < 0.0 || pd < nd_pdist) {
              nd_pdist = pd;
              nd_x = gvx[p];   /* RAW, not the log-mapped xx */
              nd_y = gvy[p];   /* RAW, not the log-mapped yy */
              nd_sx = sx;
              nd_sy = sy;
              nd_dataset = dset;
              nd_point = p;
            }
          } else if(no_pdist < 0.0 || pd < no_pdist) {
            no_pdist = pd;
            no_x = gvx[p];
            no_y = gvy[p];
            no_sx = sx;
            no_sy = sy;
            no_dataset = dset;
            no_point = p;
          }
          prev_sx = sx;
          prev_sy = sy;
          prev_xx = xx;
          prev_point = p;
          have_prev = 1;
        }
        ofs = ofs_end;
      }
      /* issue 0193: no sample fell inside the x window, so the SAMPLE half of
       * the answer comes from the straddling neighbour that owns the segment
       * being drawn. Without this the `nd_pdist >= 0.0` gate below would still
       * reject the whole trace and the pick would stay dead at high zoom. */
      if(nd_pdist < 0.0 && no_pdist >= 0.0) {
        nd_pdist = no_pdist;
        nd_x = no_x; nd_y = no_y;
        nd_sx = no_sx; nd_sy = no_sy;
        nd_dataset = no_dataset;
        nd_point = no_point;
      }
      /* strictly nearer wins, so overlapping traces resolve to the topmost
       * match by distance and, on a tie, to the FIRST node in the list */
      if(nd_min >= 0.0 && nd_min <= tol && nd_pdist >= 0.0 &&
         (best_wave < 0 || nd_min < best_dist)) {
        best_wave = wcnt;
        best_dist = nd_min;
        best.wave = wcnt;
        best.dataset = nd_dataset;
        best.point = nd_point;
        best.idx = idx;
        best.expression = expression;
        best.sweep_idx = node_sweep_idx;
        best.x = nd_x;
        best.y = nd_y;
        best.sx = nd_sx;
        best.sy = nd_sy;
        best.dist = nd_pdist;
        best.seg_dist = nd_min;
        /* the point ON THE CURVE (issue 0193), back-transformed to unscaled
         * values. GS_X/GS_Y land in graph space, which is still LOG space on a
         * log axis -- pow(10) undoes the mylog10() applied on the way in, so
         * what is stored obeys landmine 35 exactly like best.x/best.y do. */
        best.seg_sx = nd_ex;
        best.seg_sy = nd_ey;
        best.seg_point = nd_epoint;
        best.seg_dataset = nd_edataset;
        best.seg_x = GS_X(nd_ex);
        best.seg_y = GS_Y(nd_ey);
        if(gr->logx) best.seg_x = pow(10.0, best.seg_x);
        if(gr->logy) best.seg_y = pow(10.0, best.seg_y);
      }
    }
    if(express) my_free(_ALLOC_ID_, &express);
    /* THE OTHER HALF OF THE PER-NODE SWITCH (issue 0305), and it runs on every
     * path out of the body: this is the only exit, and the `continue`s above all
     * sit ABOVE the switch. Restoring by INDEX rather than the mode-5 swap is
     * what makes a strip with two foreign databases unwind correctly. */
    node_db_restore(node_saved_idx);
    node_saved_idx = -1;
    my_free(_ALLOC_ID_, &node_rawfile);
    my_free(_ALLOC_ID_, &node_sim_type);
  }

  /* Restore ONLY if the switch actually took -- an unpaired restore silently
   * repoints the session's current raw (measured: a pure hover query on a graph
   * whose `rawfile=` does not resolve flipped xctx->raw on every call).
   * BY INDEX, not the mode-5 swap it used to be: issue 0305 put a SECOND,
   * per-node switch inside the loop, and a swap cannot unwind two levels -- it
   * would land back on the last node's database. Both halves are now absolute
   * restores, so they compose. */
  if(switched) node_db_restore(entry_extra_idx);
  node_db_prev_restore(entry_prev_idx);
  my_free(_ALLOC_ID_, &custom_rawfile);
  my_free(_ALLOC_ID_, &sim_type);
  if(node_rawfile) my_free(_ALLOC_ID_, &node_rawfile);
  if(node_sim_type) my_free(_ALLOC_ID_, &node_sim_type);
  if(ntok_copy) my_free(_ALLOC_ID_, &ntok_copy);
  my_free(_ALLOC_ID_, &node);
  my_free(_ALLOC_ID_, &sweep);
  dbg(1, "graph_point_at(): graph=%d px=%g py=%g tol=%g -> wave %d (dist=%g)\n",
      i, px, py, tol, best_wave, best_dist);
  if(best_wave < 0) return 0;
  if(hit) *hit = best;
  return 1;
}

int graph_wave_at(int i, double px, double py, double tol)
{
  GraphPointHit h;
  return graph_point_at(i, px, py, tol, -1, -1, &h) ? h.wave : -1;
}

/* 1 when canvas pixel (px,py) is within `tol` screen pixels of ANY displayed
 * trace of graph `i`, else 0 — the trace EXCLUSION ZONE, expressed on top of
 * graph_wave_at() so the boundary the viewer refuses to reorder in is by
 * construction the same one it picks a trace from. */
int graph_near_wave(int i, double px, double py, double tol)
{
  return graph_wave_at(i, px, py, tol) >= 0 ? 1 : 0;
}

/* --- the trace-highlight ENVELOPE (wave_trace_hilight.md §5.2) --------------
 *
 * THE COST CLAIM IS THE FEATURE. A blinking or marching highlight must cost the
 * same on a 200-sample trace and on a 200 000-sample one, so the overlay does
 * NOT stroke the real polyline: it strokes a min/max envelope at ONE SCREEN
 * COLUMN PER PIXEL of the plot box, built once and cached.
 *
 *   for each screen column x in [plotbox_x1 .. plotbox_x2]:
 *       emit (x, ymin of the samples in that column)
 *       emit (x, ymax of them)      -- only when it differs from ymin
 *
 * <= 2 * plotbox_width_px points regardless of sample count. On a dense trace
 * that reproduces the same solid band the real draw produces (which is why the
 * user cannot catch it out); on a SPARSE one -- fewer samples than columns --
 * every column holds one sample, ymax == ymin, and the envelope degenerates to
 * the samples themselves, so it is exact there too. `xschem get
 * wave_hilight_points` exposes the count precisely so a headless leg can assert
 * both halves of that.
 *
 * The walk below is graph_point_at()'s, not a fresh one, and the three rules it
 * carries are not optional:
 *   - CONSUME THE SWEEP TOKEN BEFORE ANY `continue` (landmine 38): `sweep=` is
 *     routinely shorter than `node=` and carries its last entry forward, so a
 *     skip above the pull silently measures against the wrong x column;
 *   - switch to the graph's own `rawfile`/`sim_type` ONCE, above the node loop,
 *     and unwind only if the switch TOOK (landmine 40) -- mode 5 is a SWAP, not
 *     a stack pop, so an unpaired call repoints the session's current raw;
 *   - bracket graph_flags 128|256 around setup_graph_data (landmine 37): this is
 *     a query and must not leave the session describing another strip's
 *     hcursors.
 */

/* Find the cache slot holding (gi, ni)'s envelope for exactly this geometry, or
 * NULL. The key is everything a rebuild would depend on -- a marching frame
 * changes none of it, which is what makes a tick cost zero rebuilds. */
static WaveHilightEnv *wave_hilight_cache_find(int gi, int ni, Graph_ctx *gr,
                                               double bx1, double by1, double bx2, double by2,
                                               const char *prop)
{
  int k;
  for(k = 0; k < GRAPH_MAX_HILIGHT_WAVES; ++k) {
    WaveHilightEnv *e = &xctx->wave_hilight_env[k];
    if(!e->valid || e->gi != gi || e->ni != ni) continue;
    if(e->gx1 != gr->gx1 || e->gx2 != gr->gx2) continue;
    if(e->gy1 != gr->gy1 || e->gy2 != gr->gy2) continue;
    if(e->bx1 != bx1 || e->by1 != by1 || e->bx2 != bx2 || e->by2 != by2) continue;
    /* the rect's WHOLE prop string: node / sweep / %N / rawfile / sim_type /
     * digital / logx / logy / dataset all steer the walk and all live in it */
    if(!e->prop || !prop || strcmp(e->prop, prop)) continue;
    if(e->raw != (const void *)xctx->raw) continue;
    if(!xctx->raw) continue;
    if(e->rawpoints != xctx->raw->allpoints || e->rawsets != xctx->raw->datasets ||
       e->rawvars != xctx->raw->nvars) continue;
    return e;
  }
  return NULL;
}

/* The slot a rebuild should land in: the one already claimed by (gi, ni) if
 * there is one (its geometry key just went stale), else a free one, else slot 0.
 * The cache has exactly as many slots as the set has entries, so "else slot 0"
 * is unreachable while wave_hilight_write owns the count -- it is the fail-safe,
 * not the policy. */
static WaveHilightEnv *wave_hilight_cache_slot(int gi, int ni)
{
  int k;
  for(k = 0; k < GRAPH_MAX_HILIGHT_WAVES; ++k) {
    WaveHilightEnv *e = &xctx->wave_hilight_env[k];
    if(e->valid && e->gi == gi && e->ni == ni) return e;
  }
  for(k = 0; k < GRAPH_MAX_HILIGHT_WAVES; ++k) {
    if(!xctx->wave_hilight_env[k].valid) return &xctx->wave_hilight_env[k];
  }
  return &xctx->wave_hilight_env[0];
}

/* Build (or reuse) the envelope of NODE `ni` of graph `gi`. Returns the cache
 * entry, or NULL when the trace cannot be walked at all -- no raw, an off-screen
 * or digital strip, a `rawfile=` that does not resolve, an unknown vector.
 * `gr_out` (may be NULL) receives the local Graph_ctx, which the caller needs
 * for the plot-box clamp. */
static WaveHilightEnv *wave_hilight_envelope(int gi, int ni, Graph_ctx *gr_out)
{
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  WaveHilightEnv *e;
  xRect *r;
  char *node = NULL, *sweep = NULL;
  char *saven, *saves, *nptr, *sptr;
  const char *ntok, *stok;
  /* the last non-empty `sweep=` token, i.e. the sweep variable's NAME; see
   * graph_point_at() for why the NAME and not the carried column index */
  const char *sweep_name = NULL;
  char *ntok_copy = NULL;
  char *express = NULL;
  char *custom_rawfile = NULL;
  char *sim_type = NULL;
  char *node_rawfile = NULL;
  char *node_sim_type = NULL;
  const char *ptr;
  short *cmin = NULL, *cmax = NULL;
  char *cseen = NULL;
  int sweep_idx = 0, idx = -1, expression = 0, autoload;
  int node_dataset = -1;
  int wcnt = -1, found = 0;
  int valid_rawfile = 1, switched = 0, saveflags;
  /* per-NODE state (issue 0305), see graph_point_at() for the same three */
  int node_saved_idx = -1, node_valid = 1, node_sweep_idx = 0;
  int entry_extra_idx = 0;  /* the database that was current on the way in */
  int entry_prev_idx = -1;  /* ...and where switch_back pointed on the way in */
  int ncol, col, ix1, ix2, iy1, iy2, npt = 0;
  int keypoints = 0, keysets = 0, keyvars = 0;
  const void *keyraw = NULL;
  double bx1, by1, bx2, by2, t, start, end;

  if(!xctx) return NULL;
  if(gi < 0 || gi >= xctx->rects[GRIDLAYER]) return NULL;
  r = &xctx->rect[GRIDLAYER][gi];
  if(!(r->flags & 1)) return NULL;
  if(!xctx->raw || sch_waves_loaded() == -1) return NULL;
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  /* landmine 37: this is a QUERY, so the hcursor bits setup_graph_data rewrites
   * from the rect must be put back. */
  saveflags = xctx->graph_flags & (128 | 256);
  setup_graph_data(gi, 0, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->scx == 0.0 || gr->scy == 0.0) return NULL;  /* off-screen: no transform */
  if(gr->digital) return NULL;                       /* D8: analog polylines only */
  if(gr_out) *gr_out = gr_ctx;

  /* the plot box in SCREEN pixels. gr->cy is NEGATIVE (landmine 3), so S_Y(gy1)
   * and S_Y(gy2) come back in the opposite order to S_X(gx1)/S_X(gx2) -- both
   * pairs are normalised rather than assumed, exactly as graph_plotbox_at does. */
  bx1 = S_X(gr->gx1); bx2 = S_X(gr->gx2);
  by1 = S_Y(gr->gy1); by2 = S_Y(gr->gy2);
  if(bx1 > bx2) { t = bx1; bx1 = bx2; bx2 = t; }
  if(by1 > by2) { t = by1; by1 = by2; by2 = t; }

  e = wave_hilight_cache_find(gi, ni, gr, bx1, by1, bx2, by2, r->prop_ptr);
  if(e) return e->npt > 0 ? e : NULL;  /* the whole point: no walk. npt == 0 is a
                                        * NEGATIVE hit -- "walked, nothing here" */

  ix1 = (int)floor(bx1); ix2 = (int)ceil(bx2);
  iy1 = (int)floor(by1); iy2 = (int)ceil(by2);
  if(ix2 < ix1) return NULL;
  ncol = ix2 - ix1 + 1;
  if(ncol <= 0 || ncol > 100000) return NULL;        /* a degenerate transform */

  cmin = my_malloc(_ALLOC_ID_, (size_t)ncol * sizeof(short));
  cmax = my_malloc(_ALLOC_ID_, (size_t)ncol * sizeof(short));
  cseen = my_calloc(_ALLOC_ID_, (size_t)ncol, sizeof(char));
  if(!cmin || !cmax || !cseen) {
    if(cmin) my_free(_ALLOC_ID_, &cmin);
    if(cmax) my_free(_ALLOC_ID_, &cmax);
    if(cseen) my_free(_ALLOC_ID_, &cseen);
    return NULL;
  }

  autoload = !strboolcmp(get_tok_value(r->prop_ptr,"autoload", 0), "true");
  if(autoload == 0) autoload = 2;
  else if(autoload == 1) autoload = 33;

  my_strdup2(_ALLOC_ID_, &node, get_tok_value(r->prop_ptr,"node", 0));
  my_strdup2(_ALLOC_ID_, &sweep, get_tok_value(r->prop_ptr,"sweep", 0));
  ptr = get_tok_value(r->prop_ptr,"rawfile", 0);
  if(!ptr[0]) {
    if(xctx->raw->rawfile) my_strdup2(_ALLOC_ID_, &custom_rawfile, xctx->raw->rawfile);
    else my_strdup2(_ALLOC_ID_, &custom_rawfile, "");
  } else {
    my_strdup2(_ALLOC_ID_, &custom_rawfile, ptr);
  }
  my_strdup2(_ALLOC_ID_, &sim_type, get_tok_value(r->prop_ptr,"sim_type", 0));

  /* landmine 40: `rawfile`/`sim_type` are GRAPH-level tokens, so the switch is
   * made ONCE here, and unwound below only when it actually took. */
  entry_extra_idx = xctx->extra_idx;
  entry_prev_idx = xctx->extra_prev_idx;
  if(custom_rawfile[0]) {
    if(extra_rawfile(autoload, custom_rawfile,
       sim_type[0] ? sim_type : (xctx->raw->sim_type ? xctx->raw->sim_type : NULL),
       -1.0, -1.0) == 0) {
      valid_rawfile = 0;
    } else {
      switched = 1;
    }
  }

  start = (gr->gx1 <= gr->gx2) ? gr->gx1 : gr->gx2;
  end   = (gr->gx1 <= gr->gx2) ? gr->gx2 : gr->gx1;

  nptr = node;
  sptr = sweep;
  while( (ntok = my_strtok_r(nptr, "\n", "\"", 4, &saven)) ) {
    wcnt++;
    /* landmine 38: the sweep token and the strtok seeds are consumed for EVERY
     * entry, above the bus skip and above the node restriction below. */
    stok = my_strtok_r(sptr, "\t\n ", "\"", 0, &saves);
    nptr = sptr = NULL;
    if(strstr(ntok, ",")) {
      if(find_nth(ntok, ";,", "\"", 0, 2)[0]) continue; /* D8: a bus is not a polyline */
    }
    if(stok && stok[0]) {
      sweep_name = stok;
      sweep_idx = get_raw_index(stok, NULL);
      if(sweep_idx == -1) sweep_idx = 0;
    }
    if(wcnt != ni) continue;
    /* ⚠ ISSUE 0305 -- LIKE graph_point_at(), THIS WALKER READ ONLY THE `%<n>`
     * DATASET DIGITS. A trace plotted out of a foreign database (spec D1) then
     * had its name resolved in the CURRENT database, where it does not exist,
     * so idx came back -1, the envelope was empty and the LMB wave-bold click
     * (issue 0152) bolded nothing at all.
     * There is exactly ONE walked entry here (`wcnt != ni` skips the rest and
     * the body ends in `break`), so the unwind sits below the loop -- AFTER the
     * cache key is captured, so the key still describes the database actually
     * walked, which is what its own comment down there promises. */
    node_saved_idx = xctx->extra_idx;
    node_valid = valid_rawfile;
    node_sweep_idx = sweep_idx;
    node_token_split(ntok, &ntok_copy, &node_dataset, &node_rawfile, &node_sim_type,
                     node_dflt_sim_type(sim_type));
    if(node_rawfile[0] && xctx->raw && xctx->raw->values) {
      if(extra_rawfile(autoload, node_rawfile, node_sim_type, -1.0, -1.0) == 0) {
        node_valid = 0;
      } else {
        /* the sweep column is a per-database index, re-resolved by NAME on every
         * entry that took the switch -- a carried-forward index belongs to the
         * PREVIOUS database and can be past the end of this one (see
         * graph_point_at() for the full note; it is an out-of-bounds read) */
        node_sweep_idx = 0;
        if(sweep_name && sweep_name[0]) {
          node_sweep_idx = get_raw_index(sweep_name, NULL);
          if(node_sweep_idx == -1) node_sweep_idx = 0;
        }
      }
    }
    /* belt and braces: the column must exist in the database now current */
    if(xctx->raw && (node_sweep_idx < 0 || node_sweep_idx >= xctx->raw->nvars)) node_sweep_idx = 0;

    idx = -1;
    expression = 0;
    if(xctx->raw->values) {
      if(strstr(ntok_copy, ";")) {
        my_strdup2(_ALLOC_ID_, &express, find_nth(ntok_copy, ";", "\"", 0, 2));
      } else {
        my_strdup2(_ALLOC_ID_, &express, ntok_copy);
      }
      if(strpbrk(express, " \n\t")) expression = 1;
    }
    if(expression) idx = xctx->raw->nvars; /* the scratch column (values has nvars+1) */
    else if(express) idx = get_raw_index(express, NULL);

    if(sch_waves_loaded() != -1 && node_valid && idx != -1) {
      int p, dset, ofs = 0, ofs_end;
      double xx, yy;
      for(dset = 0; dset < xctx->raw->datasets; dset++) {
        SPICE_DATA *gvx = xctx->raw->values[node_sweep_idx];
        SPICE_DATA *gvy;
        ofs_end = ofs + xctx->raw->npoints[dset];
        if(node_dataset != -1 && node_dataset != dset) { ofs = ofs_end; continue; }
        /* plot_raw_custom_data() returns -1 without touching the scratch column,
         * so a malformed RPN must skip the dataset rather than measure whatever
         * the previous expression left there. */
        if(expression &&
           plot_raw_custom_data(node_sweep_idx, ofs, ofs_end - 1, express, NULL) < 0) {
          ofs = ofs_end;
          continue;
        }
        gvy = xctx->raw->values[idx];
        for(p = ofs; p < ofs_end; p++) {
          double sx, sy;
          short sh;
          if(gr->logx) xx = mylog10(gvx[p]); else xx = gvx[p];
          if(gr->logy) yy = mylog10(gvy[p]); else yy = gvy[p];
          /* ⚠ issue 0193, third instance of the same clip. Dropping every
           * off-window sample also drops the two that own the segment SPANNING
           * the view, so once the zoom is tighter than the sample spacing this
           * built an EMPTY envelope and the highlight vanished off a trace that
           * was still being drawn (draw_graph keeps those two -- ~8221). One
           * neighbour each side is enough: the envelope is per screen column
           * and the stroke bridges the columns between them. */
          if(xx < start && !(p + 1 < ofs_end &&
               (gr->logx ? mylog10(gvx[p + 1]) : gvx[p + 1]) >= start)) continue;
          if(xx > end && !(p > ofs &&
               (gr->logx ? mylog10(gvx[p - 1]) : gvx[p - 1]) <= end)) continue;
          sx = S_X(xx);
          sy = S_Y(yy);
          if(!(sx > -1e9 && sx < 1e9 && sy > -1e9 && sy < 1e9)) continue;
          col = (int)floor(sx) - ix1;
          if(col < 0) col = 0;
          if(col >= ncol) col = ncol - 1;
          /* clamp to the 16-bit signed short XPoint carries, exactly as
           * draw_graph_points does -- an out-of-range value would WRAP. */
          sh = (short)CLIP(sy, -30000.0, 30000.0);
          if(!cseen[col]) { cmin[col] = cmax[col] = sh; cseen[col] = 1; }
          else { if(sh < cmin[col]) cmin[col] = sh; if(sh > cmax[col]) cmax[col] = sh; }
          found = 1;
        }
        ofs = ofs_end;
      }
    }
    if(express) my_free(_ALLOC_ID_, &express);
    break;                                  /* the restricted walk found its node */
  }

  /* The KEY's raw identity is captured HERE, while the graph's own `rawfile=`
   * is still switched in, so it describes the data actually walked rather than
   * whatever the session happens to be pointing at afterwards. */
  keyraw    = (const void *)xctx->raw;
  keypoints = xctx->raw ? xctx->raw->allpoints : 0;
  keysets   = xctx->raw ? xctx->raw->datasets  : 0;
  keyvars   = xctx->raw ? xctx->raw->nvars     : 0;
  /* issue 0305: unwind the PER-NODE `%<rawfile>` switch first, by index, back to
   * whatever was current when that entry started (the graph-level `rawfile=`
   * when the graph has one). It must come AFTER the key capture above and
   * BEFORE the graph-level mode-5 swap below -- a swap performed while a second
   * switch is still outstanding would leave the session on the wrong database. */
  node_db_restore(node_saved_idx);
  if(node_rawfile) my_free(_ALLOC_ID_, &node_rawfile);
  if(node_sim_type) my_free(_ALLOC_ID_, &node_sim_type);
  /* landmine 40 again: restore ONLY if the switch actually took -- and BY INDEX,
   * because the per-node restore just above is a second level a mode-5 swap
   * could not unwind (issue 0305). */
  if(switched) node_db_restore(entry_extra_idx);
  node_db_prev_restore(entry_prev_idx);
  my_free(_ALLOC_ID_, &custom_rawfile);
  my_free(_ALLOC_ID_, &sim_type);
  if(ntok_copy) my_free(_ALLOC_ID_, &ntok_copy);
  my_free(_ALLOC_ID_, &node);
  my_free(_ALLOC_ID_, &sweep);

  /* A slot is claimed and keyed EVEN WHEN NOTHING WAS FOUND. That npt == 0
   * entry is a NEGATIVE cache hit -- "walked, no sample of this node is in this
   * window" -- and it is what stops a trace zoomed off-screen, or one whose
   * vector the raw does not know, from re-walking every sample on every
   * animation tick. Without it the cheap frame is only cheap for traces that
   * happen to be visible, which is not the guarantee. */
  e = wave_hilight_cache_slot(gi, ni);
  if(found) {
    if(e->alloc < 2 * ncol) {
      if(e->pt) my_free(_ALLOC_ID_, &e->pt);
      e->pt = my_malloc(_ALLOC_ID_, (size_t)(2 * ncol) * sizeof(XPoint));
      e->alloc = e->pt ? 2 * ncol : 0;
    }
    if(e->pt) {
      for(col = 0; col < ncol; ++col) {
        if(!cseen[col]) continue;
        e->pt[npt].x = (short)CLIP((double)(ix1 + col), -30000.0, 30000.0);
        e->pt[npt].y = cmin[col];
        npt++;
        /* ONE point where min == max: that is what makes a SPARSE trace's
         * envelope exactly its samples, which WD2 asserts as an exact count. */
        if(cmax[col] != cmin[col]) {
          e->pt[npt].x = e->pt[npt - 1].x;
          e->pt[npt].y = cmax[col];
          npt++;
        }
      }
    }
  }
  my_free(_ALLOC_ID_, &cmin);
  my_free(_ALLOC_ID_, &cmax);
  my_free(_ALLOC_ID_, &cseen);

  e->npt = npt;
  e->gi = gi; e->ni = ni;
  e->gx1 = gr->gx1; e->gx2 = gr->gx2; e->gy1 = gr->gy1; e->gy2 = gr->gy2;
  e->bx1 = bx1; e->by1 = by1; e->bx2 = bx2; e->by2 = by2;
  e->digital = gr->digital; e->dataset = gr->dataset;
  my_strdup2(_ALLOC_ID_, &e->prop, r->prop_ptr ? r->prop_ptr : "");
  e->raw = keyraw;
  e->rawpoints = keypoints;
  e->rawsets = keysets;
  e->rawvars = keyvars;
  e->valid = 1;
  dbg(1, "wave_hilight_envelope(): gi=%d ni=%d cols=%d -> %d points\n", gi, ni, ncol, npt);
  return npt > 0 ? e : NULL;
}

/* How many points the envelope of (gi, ni) holds; 0 when there is no envelope
 * to have -- a bad index, a non-graph rect, no loaded raw, an off-screen strip,
 * a digital strip, a bus entry, or a vector the raw does not know.
 *
 * Backs `xschem get wave_hilight_points`, and it is THE COST SEAM: it is what
 * lets a leg assert that a >= 50 000-sample trace really decimated to <= 2W
 * points and that a sparse one did not decimate at all. It therefore BUILDS the
 * envelope when the cache does not hold one -- because the paint path that
 * would otherwise fill the cache is `if(!has_x) return;`, so under --nogui a
 * pure cache read could only ever answer 0 and the whole group would pass
 * vacuously in the arm that matters most. The build is the same one the paint
 * does, cached identically, and no animation path ever calls this. */
int wave_hilight_points(int gi, int ni)
{
  WaveHilightEnv *e;
  if(!xctx) return 0;
  /* Straight through the builder, with NO (gi, ni)-only pre-scan of its own: a
   * shortcut that matched on the identity alone would answer with a count built
   * for a data window or a raw that no longer exists -- the exact staleness the
   * geometry key is there to prevent, reintroduced in the one function whose
   * whole job is to report the truth. The builder's own lookup is keyed, and a
   * hit costs one loop over 16 slots. */
  e = wave_hilight_envelope(gi, ni, NULL);
  return e ? e->npt : 0;
}

/* Copy one entry's previous overlay bbox back from save_pixmap, which is the
 * whole erase (D6). The graph_snap_erase() mechanism: save_pixmap is maintained
 * by the ordinary double-buffered draw() and the overlay is NEVER written into
 * it (draw_pixmap is 0 for the whole cadence), so the patch underneath is always
 * the clean plot. */
static void wave_hilight_erase(WaveHilightEnv *e)
{
  int w, h;
  if(!e->painted) return;
  e->painted = 0;
  if(!has_x || !xctx->save_pixmap) return;
  w = e->px2 - e->px1 + 1;
  h = e->py2 - e->py1 + 1;
  if(w <= 0 || h <= 0) return;
  MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
              e->px1, e->py1, (unsigned int)w, (unsigned int)h, e->px1, e->py1);
}

/* THE OVERLAY PAINTER (§5.1/§5.3). Window-only chrome, stroked at the TAIL of
 * draw() and again by the cheap animation frame.
 *
 * Landmine 44's rule: the "does this context have wave highlights" test lives
 * INSIDE the drawer, never in a caller's local, or the erase paths and the paint
 * paths drift apart. Consequence, and it is the desired one: EXPORTS never carry
 * the overlay -- SVG/PS/PNG go through their own callers and never touch the
 * window, the same doctrine as draw_graph bit 16.
 *
 * `erase` copies each entry's previous bbox back from save_pixmap first. That is
 * the standalone animation frame; a frame that went through draw() passes 0,
 * because the region was just repainted wholesale.
 *
 * Cost per animating trace per tick: one XCopyArea + one GC change + one
 * XDrawLines of <= 2W cached points. No sample walk, no draw(), no pixmap write. */
void draw_wave_hilight(int erase)
{
  int k, anim;
  double now = 0.0;
  int prev_pixmap, prev_window;
  if(!has_x) return;
  if(!xctx) return;
  if(xctx->wave_hilight_n <= 0) return;     /* landmine 44: the test is HERE */

  /* the blink/march phase is advanced ONLY in an animation frame or under the
   * test hook, exactly as draw_hilight_net gates it -- so an ordinary redraw and
   * every hardcopy path render the overlay steady, i.e. deterministic. */
  anim = (xctx->in_hilight_anim_frame || xctx->net_hilight_test_active) &&
         tclgetboolvar("net_hilight_animate");
  if(anim) now = net_hilight_now_ms();
  else {
    /* An ordinary draw paints the overlay steady-ON but does not advance the
     * blink phase, so the tick's change-detection signature is now describing a
     * frame nobody rendered. Invalidate it, exactly as draw_hilight_net does and
     * for exactly its reason -- otherwise a redraw that lands during an OFF
     * phase leaves the next tick seeing a stale-matching signature, skipping,
     * and the highlight is stuck ON.
     * ⚠ It cannot be left to draw_hilight_net: that function opens with
     * `if(!xctx->hilight_nets) return;`, and a waveform viewer has no
     * highlighted NETS -- the same shape as the two gate terms in hilight.c. */
    xctx->net_hilight_anim_sig = 0;
  }

  /* ERASE EVERY ENTRY FIRST, THEN PAINT. Not per entry: the erase is a
   * copy-back from save_pixmap over a whole bbox, so an interleaved loop lets
   * entry k+1's erase wipe entry k's freshly painted pixels wherever the two
   * bboxes overlap -- which is every time two traces of the SAME strip are
   * highlighted, i.e. the ordinary case. */
  if(erase) {
    for(k = 0; k < GRAPH_MAX_HILIGHT_WAVES; ++k) {
      WaveHilightEnv *pe = &xctx->wave_hilight_env[k];
      if(pe->painted) wave_hilight_erase(pe);
    }
  }

  prev_pixmap = xctx->draw_pixmap;
  prev_window = xctx->draw_window;
  xctx->draw_pixmap = 0;   /* window only: the overlay must never enter save_pixmap,
                            * or the copy-back erase above would restore it */
  xctx->draw_window = 1;
  for(k = 0; k < xctx->wave_hilight_n; ++k) {
    WaveHilightEnv *e;
    NetHilightStyle *st;
    GC gc = xctx->gc_hilight;
    XRectangle clipr;
    int gi = xctx->wave_hilight_gi[k];
    int ni = xctx->wave_hilight_ni[k];
    int width, half, x, offset, size, i;
    int mnx, mny, mxx, mxy;
    e = wave_hilight_envelope(gi, ni, NULL);
    if(!e || e->npt <= 0) continue;
    st = get_hilight_style(xctx->wave_hilight_style[k]);
    /* blink OFF this instant: the erase above already exposed the plain trace */
    if(anim && !net_hilight_style_on_now(st, now)) continue;

    width = XLINEWIDTH(xctx->lw) * ((st && st->width >= 1) ? st->width : 1);
    XSetForeground(display, gc, get_hilight_pixel(xctx->wave_hilight_style[k]));
    if(st && st->dash_len > 0) {
      /* the marching phase, in the flat Xlib path's whole-pixel units and with
       * draw_hilight_wire()'s direction correction: XSetDashes' phase advances
       * the pattern toward the polyline START as it grows, so a march_fwd style
       * must be fed (period - offset) to crawl the same way a wire does. */
      double period = net_hilight_dash_period(st);
      double off = anim ? net_hilight_march_offset(st, now) : 0.0;
      int phase = (period > 0.0) ? (int)fmod(period - off, period) : 0;
      XSetLineAttributes(display, gc, width, xDashType, LINECAP, LINEJOIN);
      XSetDashes(display, gc, phase, st->dash_arr, st->dash_len);
    } else {
      XSetLineAttributes(display, gc, width, LineSolid, LINECAP, LINEJOIN);
    }
    /* CLIP TO THE PLOT BOX. The envelope's y values are S_Y() of real samples,
     * clamped only to the 16-bit XPoint range -- so a trace that leaves the y
     * window is stroked far outside its strip, across its neighbours. The real
     * trace does not do that because draw_graph runs inside a bbox(SET) whose
     * clip covers the graph; this overlay is painted at the tail of draw(),
     * outside any such bracket, so it needs its own. It also has to match the
     * erase, which IS clamped to the box -- an unclipped stroke with a clamped
     * copy-back leaves permanent residue on the neighbour.
     * The restore is XSetClipMask(None), which is exactly what set_clip_mask(END)
     * leaves behind: the overlay is the last thing drawn either way. */
    clipr.x = (short)floor(e->bx1);
    clipr.y = (short)floor(e->by1);
    clipr.width  = (unsigned short)(ceil(e->bx2) - floor(e->bx1) + 1);
    clipr.height = (unsigned short)(ceil(e->by2) - floor(e->by1) + 1);
    XSetClipRectangles(display, gc, 0, 0, &clipr, 1, Unsorted);
    /* chunked at MAX_POLY_POINTS with the last point of a chunk repeated as the
     * first of the next (landmine 16) -- an off-by-one here is a visible gap. */
    offset = 0;
    while(1) {
      XPoint *pt = e->pt + offset;
      size = e->npt - offset;
      if(size > MAX_POLY_POINTS) size = MAX_POLY_POINTS;
      XDrawLines(display, xctx->window, gc, pt, size, CoordModeOrigin);
      if(offset + size >= e->npt) break;
      offset += MAX_POLY_POINTS - 1;
    }
    XSetClipMask(display, gc, None);
    /* record the painted bbox for the next frame's erase, grown by the half
     * width the stroke spills and clamped to the plot box the envelope came
     * from -- the erase must never restore pixels outside this strip. */
    mnx = mxx = e->pt[0].x; mny = mxy = e->pt[0].y;
    for(i = 1; i < e->npt; ++i) {
      if(e->pt[i].x < mnx) mnx = e->pt[i].x;
      if(e->pt[i].x > mxx) mxx = e->pt[i].x;
      if(e->pt[i].y < mny) mny = e->pt[i].y;
      if(e->pt[i].y > mxy) mxy = e->pt[i].y;
    }
    half = width / 2 + 2;
    x = (int)floor(e->bx1) - half; if(mnx - half > x) x = mnx - half;
    e->px1 = x;
    x = (int)ceil(e->bx2) + half;  if(mxx + half < x) x = mxx + half;
    e->px2 = x;
    x = (int)floor(e->by1) - half; if(mny - half > x) x = mny - half;
    e->py1 = x;
    x = (int)ceil(e->by2) + half;  if(mxy + half < x) x = mxy + half;
    e->py2 = x;
    e->painted = 1;
  }
  xctx->draw_pixmap = prev_pixmap;
  xctx->draw_window = prev_window;
}

/* ===========================================================================
 * Waveform markers — doc/claude/specs/graph_markers.md
 *
 * A marker is DURABLE CONTENT, not UI chrome: it is a `markers` prop token on
 * the graph rect, so it rides save/reload, copy/paste and undo for free, and it
 * is rendered under draw_graph's flags bit 8 (never bit 16), so it appears in
 * SVG/PNG export exactly like a trace does.
 *
 *   markers="<num> <wave> <dset> <point> <x> <y> <prev> <ldx> <ldy>[\n...]"
 *
 * All fields are numeric on purpose: subst_token() does not escape a quote or a
 * backslash, so an alphabet without them cannot corrupt the following tokens,
 * and it dodges tcl_hook2's "a value starting with tcleval( is executed".
 * x/y are written with %.17g because they must identify the EXACT sample -- the
 * house dtoa() is %.8g and would re-snap a reloaded marker onto a neighbour.
 * =========================================================================== */

#if HAS_CAIRO==1
#define GRAPH_DELTA_STR "\316\224"  /* UTF-8 U+0394 GREEK CAPITAL LETTER DELTA */
#else
/* the vector font maps every byte > 127 to '?' INDEPENDENTLY (draw_string), so a
 * cairo-less build must degrade to ASCII rather than render "??" */
#define GRAPH_DELTA_STR "D"
#endif

#define GRAPH_MARKER_FINITE(v) ((v) > -1e308 && (v) < 1e308)

/* Parse the `markers` token of a prop string into a freshly allocated array.
 * Returns the record count (also written to *n); the caller my_free()s *arr.
 * A malformed record is DROPPED and the rest are kept -- the same per-record
 * tolerance wviewer::markers_decode has. */
int graph_markers_parse(const char *prop_ptr, GraphMarker **arr, int *n)
{
  char *val = NULL, *save = NULL, *ptr;
  const char *tok;
  GraphMarker *a = NULL;
  int cnt = 0, size = 0;

  if(arr) *arr = NULL;
  if(n) *n = 0;
  if(!prop_ptr) return 0;
  /* get_tok_value() returns a SHARED static buffer and my_strtok_r() mutates
   * its input: copy first (draw_graph does the same for `node`) */
  my_strdup2(_ALLOC_ID_, &val, get_tok_value(prop_ptr, "markers", 0));
  if(!val || !val[0]) {
    if(val) my_free(_ALLOC_ID_, &val);
    return 0;
  }
  ptr = val;
  while( (tok = my_strtok_r(ptr, "\n", "", 0, &save)) ) {
    GraphMarker m;
    ptr = NULL;
    memset(&m, 0, sizeof(m));
    if(sscanf(tok, "%d %d %d %d %lf %lf %d %lf %lf",
              &m.num, &m.wave, &m.dataset, &m.point,
              &m.x, &m.y, &m.prev, &m.ldx, &m.ldy) < 9) {
      dbg(0, "graph_markers_parse(): dropping malformed marker record |%s|\n", tok);
      continue;
    }
    if(!GRAPH_MARKER_FINITE(m.x) || !GRAPH_MARKER_FINITE(m.y) ||
       !GRAPH_MARKER_FINITE(m.ldx) || !GRAPH_MARKER_FINITE(m.ldy)) {
      dbg(0, "graph_markers_parse(): dropping non-finite marker record |%s|\n", tok);
      continue;
    }
    /* NO cap here, deliberately. GRAPH_MARKERS_MAX bounds CREATION only.
     * Truncating on the read side would be data destruction, not a guard: every
     * mutating op rewrites the whole token from this array, so the first
     * keystroke on a hand-edited or foreign file carrying more than the cap
     * would silently and irreversibly drop the excess. Memory stays proportional
     * to the file, like every other object array. */
    if(cnt >= size) {
      size += 16;
      my_realloc(_ALLOC_ID_, &a, (size_t)size * sizeof(GraphMarker));
    }
    a[cnt++] = m;
  }
  my_free(_ALLOC_ID_, &val);
  if(arr) *arr = a;
  else if(a) my_free(_ALLOC_ID_, &a);
  if(n) *n = cnt;
  return cnt;
}

/* Build the token VALUE (no `markers=` prefix, no quoting -- subst_token quotes
 * a value containing spaces/newlines by itself). *dest is NULL for n == 0. */
void graph_markers_format(char **dest, const GraphMarker *arr, int n)
{
  int k;
  char line[256];

  if(!dest) return;
  if(*dest) my_free(_ALLOC_ID_, dest);
  if(n <= 0 || !arr) return;
  for(k = 0; k < n; k++) {
    my_snprintf(line, S(line), "%s%d %d %d %d %.17g %.17g %d %.10g %.10g",
                k ? "\n" : "", arr[k].num, arr[k].wave, arr[k].dataset, arr[k].point,
                arr[k].x, arr[k].y, arr[k].prev, arr[k].ldx, arr[k].ldy);
    if(k == 0) my_strdup2(_ALLOC_ID_, dest, line);
    else my_strcat(_ALLOC_ID_, dest, line);
  }
}

/* Write the array back into the rect. An empty array DELETES the token (that is
 * subst_token's empty-value branch), so "never marked" and "all markers removed"
 * are the same representation. */
void graph_markers_store(xRect *r, const GraphMarker *arr, int n)
{
  char *buf = NULL;

  if(!r) return;
  graph_markers_format(&buf, arr, n);
  my_strdup2(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "markers", buf ? buf : ""));
  if(buf) my_free(_ALLOC_ID_, &buf);
  /* cheapest correct convention after any direct prop_ptr write; provably a
   * no-op for this token (set_rect_flags reads only `flags`) */
  set_rect_flags(r);
}

/* Highest marker number in the WHOLE window (0 when there are none). No counter
 * is kept anywhere: a rect deleted, undone, pasted or regenerated can then never
 * desync the numbering. */
int graph_marker_max_number(void)
{
  int i, k, n, max = 0;

  if(!xctx) return 0;
  for(i = 0; i < xctx->rects[GRIDLAYER]; i++) {
    GraphMarker *a = NULL;
    xRect *r = &xctx->rect[GRIDLAYER][i];
    if(!(r->flags & 1)) continue;
    n = graph_markers_parse(r->prop_ptr, &a, &n);
    for(k = 0; k < n; k++) if(a[k].num > max) max = a[k].num;
    if(a) my_free(_ALLOC_ID_, &a);
  }
  return max;
}

int graph_marker_next_number(void)
{
  return graph_marker_max_number() + 1;
}

/* Locate marker `num` anywhere in the window. A delta's partner may live in a
 * DIFFERENT strip, which is why this is window-wide. */
int graph_marker_find(int num, int *graph_idx, GraphMarker *out)
{
  int i, k, n;

  if(!xctx || num <= 0) return 0;
  for(i = 0; i < xctx->rects[GRIDLAYER]; i++) {
    GraphMarker *a = NULL;
    xRect *r = &xctx->rect[GRIDLAYER][i];
    if(!(r->flags & 1)) continue;
    n = graph_markers_parse(r->prop_ptr, &a, &n);
    for(k = 0; k < n; k++) {
      if(a[k].num == num) {
        if(graph_idx) *graph_idx = i;
        if(out) *out = a[k];
        my_free(_ALLOC_ID_, &a);
        return 1;
      }
    }
    if(a) my_free(_ALLOC_ID_, &a);
  }
  return 0;
}

/* One value, engineering-formatted the way the MEASUREMENT TOOLTIP does it
 * (callback.c): ev_precision on both branches. draw_cursor hardcodes 5 on the
 * plain branch -- a marker is a readout the user explicitly asked for, so it
 * follows the tooltip. Deliberate, documented divergence. */
static void graph_marker_fmt(char *dest, int destsize, double v, double unit, int suffix, int prec)
{
  if(unit != 1.0 && unit != 0.0 && suffix) {
    /* plain sprintf, NOT my_snprintf: without HAS_SNPRINTF the house
     * my_snprintf is a minimal reimplementation that does not understand the
     * `*` precision, so "%.*g" made it consume the int `prec` AS THE DOUBLE
     * (measured: "700.0000000000001136868377216160297393798828125" and a
     * swallowed suffix). draw_cursor()/the measurement tooltip use raw sprintf
     * here for exactly this reason. prec is clamped by the caller, so the
     * longest possible output is ~24 chars + the suffix. */
    sprintf(dest, "%.*g%c", prec, unit * v, suffix);
  }
  else my_snprintf(dest, destsize, "%s", dtoa_eng(v, prec));
}

/* Every marker in the window, parsed ONCE, with the rect each lives on.
 * The renderer and the hit-tester build this once per call and resolve delta
 * partners out of it: doing a graph_marker_find() per record instead re-parsed
 * every rect in the window per marker and made both operations O(N^2) -- 512
 * markers (the shipped cap) measured at ~220 ms per redraw AND per mouse press.
 * Caller my_free()s *arr. */
typedef struct {
  GraphMarker m;
  int graph;
} GraphMarkerRef;

static int graph_markers_collect(GraphMarkerRef **arr, int *n)
{
  int i, k, cnt = 0, size = 0;
  GraphMarkerRef *a = NULL;

  if(arr) *arr = NULL;
  if(n) *n = 0;
  if(!xctx) return 0;
  for(i = 0; i < xctx->rects[GRIDLAYER]; i++) {
    GraphMarker *b = NULL;
    int m = 0;
    xRect *r = &xctx->rect[GRIDLAYER][i];
    if(!(r->flags & 1)) continue;
    m = graph_markers_parse(r->prop_ptr, &b, &m);
    for(k = 0; k < m; k++) {
      if(cnt >= size) {
        size += 32;
        my_realloc(_ALLOC_ID_, &a, (size_t)size * sizeof(GraphMarkerRef));
      }
      a[cnt].m = b[k];
      a[cnt].graph = i;
      cnt++;
    }
    if(b) my_free(_ALLOC_ID_, &b);
  }
  if(arr) *arr = a;
  else if(a) my_free(_ALLOC_ID_, &a);
  if(n) *n = cnt;
  return cnt;
}

/* Render a marker RECORD's label into dest. Returns 1 on success.
 *
 * Takes the record, not a number, so the renderer can pass the LIVE DRAG
 * SCRATCH: re-deriving from the number would read the rect's stored token,
 * which is deliberately not written until the release, and the callout would
 * then keep showing the pre-drag x/y, dx/dy and slope while the anchor slides
 * -- i.e. the readout, the entire reason a marker exists, would be frozen for
 * the whole gesture.
 *
 * `pool` (may be NULL) is the pre-parsed window used to resolve the delta
 * partner without a fresh full-window scan.
 *
 * dtoa_eng() returns a SHARED static buffer, so every value is staged into its
 * own local before assembly -- two dtoa_eng calls in one sprintf print the same
 * number twice. */
static int graph_marker_text_rec(const GraphMarker *mp, int gi,
                                 const GraphMarkerRef *pool, int npool,
                                 char *dest, int destsize)
{
  GraphMarker m, p;
  xRect *r;
  int pgi = -1, havep = 0;
  int prec, logx, sufx, sufy;
  double unitx, unity;
  const char *val;
  char sx[80], sy[80], sdx[80], sdy[80], ssl[80];

  if(!dest || destsize <= 0) return 0;
  dest[0] = '\0';
  if(!xctx || !mp) return 0;
  if(gi < 0 || gi >= xctx->rects[GRIDLAYER]) return 0;
  m = *mp;
  /* a getter must not write xctx->ev_precision (draw_graph owns that) */
  prec = tclgetintvar("ev_precision");
  if(prec <= 0) prec = 5;
  /* clamped so graph_marker_fmt's sprintf can never outgrow its 80-byte buffer
   * (17 significant digits already round-trips a double exactly) */
  if(prec > 17) prec = 17;
  /* the axis units are read straight off the rect rather than through
   * setup_graph_data(): that returns EARLY for an off-screen graph (RECT_OUTSIDE)
   * without ever reaching the unitx/unity parse, and it has the side effect of
   * rewriting xctx->graph_flags' hcursor bits -- neither is wanted in a query
   * that can be called from a Tcl verb outside any draw. */
  r = &xctx->rect[GRIDLAYER][gi];
  val = get_tok_value(r->prop_ptr, "logx", 0);
  logx = (val[0] == '1');
  val = get_tok_value(r->prop_ptr, "unitx", 0);
  sufx = val[0];
  unitx = get_unit(val);
  if(logx) { /* AC: the y axis carries no unit suffix, mirroring setup_graph_data */
    sufy = 0;
    unity = 1.0;
  } else {
    val = get_tok_value(r->prop_ptr, "unity", 0);
    sufy = val[0];
    unity = get_unit(val);
  }
  graph_marker_fmt(sx, S(sx), m.x, unitx, sufx, prec);
  graph_marker_fmt(sy, S(sy), m.y, unity, sufy, prec);
  if(m.prev >= 1) {
    if(pool) {
      int k;
      for(k = 0; k < npool; k++) {
        if(pool[k].m.num == m.prev) { p = pool[k].m; pgi = pool[k].graph; havep = 1; break; }
      }
    } else {
      havep = graph_marker_find(m.prev, &pgi, &p);
    }
  }
  (void) pgi;
  if(havep) {
    double dx = m.x - p.x;
    double dy = m.y - p.y;
    graph_marker_fmt(sdx, S(sdx), dx, unitx, sufx, prec);
    graph_marker_fmt(sdy, S(sdy), dy, unity, sufy, prec);
    /* exact compare: both operands are exact doubles read out of the raw */
    if(dx == 0.0) my_snprintf(ssl, S(ssl), "undef");
    else my_snprintf(ssl, S(ssl), "%s", dtoa_eng(dy / dx, prec));
    my_snprintf(dest, destsize, "M%d:%s,%s\n%sx:%s,%sy:%s\nslope:%s",
                m.num, sx, sy, GRAPH_DELTA_STR, sdx, GRAPH_DELTA_STR, sdy, ssl);
  } else {
    my_snprintf(dest, destsize, "M%d:%s,%s", m.num, sx, sy);
  }
  return 1;
}

/* The by-number wrapper: the Tcl `graph_marker text` verb and the tests. */
int graph_marker_text(int num, char *dest, int destsize)
{
  GraphMarker m;
  int gi = -1;

  if(!dest || destsize <= 0) return 0;
  dest[0] = '\0';
  if(!graph_marker_find(num, &gi, &m)) return 0;
  return graph_marker_text_rec(&m, gi, NULL, 0, dest, destsize);
}

/* Callout box padding, as a fraction of ONE text LINE -- not of the whole text
 * block, or a 3-line delta callout would be padded three times as much as a
 * plain one -- with a floor in SCREEN pixels so a callout on a short stacked
 * strip still gets breathing room. */
#define GRAPH_MARKER_PADX     0.40
#define GRAPH_MARKER_PADY     0.22
#define GRAPH_MARKER_PADX_MIN 2.0
#define GRAPH_MARKER_PADY_MIN 1.5

/* drawrect()/drawline()/drawarc() turn their `bus` argument into
 * XLINEWIDTH(bus * xctx->mooz), which TRUNCATES toward zero. xctx->mooz is a
 * stored double equal to fl(1/zoom), NOT a symbolic reciprocal, so n * zoom *
 * mooz can land one ulp below n and truncate to n-1 (measured: 1.9999999999999998
 * for 13.9% of zoom values at n = 2, which silently erased the selection cue).
 * The +0.25 rounds that back and stays far below n+1. */
#define GRAPH_MARKER_PX(n) (((n) + 0.25) * xctx->zoom)

/* Marker stroke weights, in SCREEN PIXELS, for the leader line, the callout
 * outline and the selection ring. 1 px is the FLOOR of this path: XLINEWIDTH
 * clamps (int)0 to 1 whenever change_lw is set, DRAW_ALL_CAIRO is 0 so there is
 * no sub-pixel stroking available, and an X11 line width of 0 is the "thin
 * line" special case (1 px, fast algorithm), not invisible. */
#define GRAPH_MARKER_LW     1.0
#define GRAPH_MARKER_LW_SEL 2.0

/* Inflate the raw text box into the CALLOUT box, so the glyphs do not touch the
 * border. Applied INSIDE graph_marker_label_box(), immediately after EVERY
 * text_bbox() call, and that placement is the whole point: the four-candidate
 * fit test, the shove-back-inside and the hit test must all see the SAME box.
 * Padding in the renderer alone would desync the drawn box from the clickable
 * one, which is the exact class the shared function exists to prevent --
 * enlarging the clickable area along with the drawn one is intended.
 *
 * lx/ly are deliberately NOT touched. text_bbox()'s (x,y) names the TOP-LEFT of
 * the text block (rot=0/flip=0/hcenter=0/vcenter=0, so tx1 == lx exactly), and
 * draw_string() re-derives its own box from that same (x,y) and never sees this
 * one -- so a SYMMETRIC inflation leaves the glyphs exactly where they were and
 * visually centres them in the padded box. An asymmetric pad would not. */
static void graph_marker_pad_box(int nlines, double *tx1, double *ty1,
                                 double *tx2, double *ty2)
{
  double lineh = *ty2 - *ty1;
  double padx, pady;

  if(nlines > 1) lineh /= nlines;
  padx = lineh * GRAPH_MARKER_PADX;
  pady = lineh * GRAPH_MARKER_PADY;
  /* xctx->zoom is world units per pixel, so these floors are screen pixels */
  if(padx < GRAPH_MARKER_PADX_MIN * xctx->zoom) padx = GRAPH_MARKER_PADX_MIN * xctx->zoom;
  if(pady < GRAPH_MARKER_PADY_MIN * xctx->zoom) pady = GRAPH_MARKER_PADY_MIN * xctx->zoom;
  *tx1 -= padx; *tx2 += padx;
  *ty1 -= pady; *ty2 += pady;
}

/* THE marker label font size. The renderer's draw_string() and the hit-tester's
 * text_bbox() must agree exactly or the drawn text and the clickable box come
 * out different sizes, so both go through here (they used to name gr->txtsizex
 * independently -- a latent desync).
 *
 * The base is gr->txtsizey, the Y-AXIS numbering size, and that is a deliberate
 * change from the gr->txtsizex it used to be. Neither raw coefficient (0.0070
 * for x, 0.0095 for y) is what actually governs: BOTH are clamped, txtsizex by
 * `marginy * 0.0065` and txtsizey by `marginx * 0.004`. The txtsizex clamp binds
 * for every strip wider than 1.25x its height -- i.e. every realistic one -- so
 * the callout font was governed by the BOTTOM MARGIN, the band of container
 * below the plot box where the X-axis numbers live and which has nothing to do
 * with a callout drawn INSIDE the plot box. It therefore collapsed with strip
 * height: measured on a default 800x500 canvas, 23.7 screen px for a single
 * strip, 5.9 px in a 4-stack and 2.96 px in an 8-stack -- below draw_string()'s
 * own 3-px "too small" floor, i.e. an invisible callout that was still
 * clickable. The txtsizey clamp stops binding at aspect >= 2.44, so in any
 * stack it is exactly 1.5033x larger (4.45 px at 8 strips, above the floor),
 * while on a single tall strip the two agree to within 1.6%.
 *
 * graph_marker_textmag scales it and is CLAMPED for the same reason
 * graph_marker_color is: this value feeds text_bbox and therefore the HIT box,
 * so a wild rc value would enlarge the clickable area, not merely the glyphs. */
static double graph_marker_txtsize(Graph_ctx *gr)
{
  double mag = tclgetdoublevar("graph_marker_textmag");
  /* the >=/<= form also rejects nan, which fails every comparison */
  if(!(mag >= 0.1) || !(mag <= 10.0)) mag = 1.0;
  return gr->txtsizey * mag;
}

/* THE single source of truth for callout geometry, used by BOTH the renderer and
 * the hit-tester so the drawn box and the clickable box can never disagree.
 * Everything is in XSCHEM (world) coordinates. Returns 0 when there is nothing
 * to draw or hit (anchor outside the plot box). `txtsize` comes from
 * graph_marker_txtsize(), computed ONCE per call by each caller.
 *
 * The label is clamped to the PLOT box, not the container: the container's right
 * margin is the ASE strip-reorder grip's hit zone, and its top margin is where
 * xctx->graph_top disables the GRAPHPAN routing latch (landmine 36). */
static int graph_marker_label_box(const GraphMarker *m, Graph_ctx *gr, const char *lab,
                                  double txtsize,
                                  double *ax, double *ay, double *lx, double *ly,
                                  double *tx1, double *ty1, double *tx2, double *ty2)
{
  double mx = gr->logx ? mylog10(m->x) : m->x;
  double my = gr->logy ? mylog10(m->y) : m->y;
  double cand[4][2];
  int nlines = 1, k;
  double dtmp;

  *ax = W_X(mx);
  *ay = W_Y(my);
  if(!POINTINSIDE(*ax, *ay, gr->x1, gr->y1, gr->x2, gr->y2)) return 0;

  cand[0][0] =  m->ldx; cand[0][1] =  m->ldy;
  cand[1][0] =  m->ldx; cand[1][1] = -m->ldy;
  cand[2][0] = -m->ldx; cand[2][1] =  m->ldy;
  cand[3][0] = -m->ldx; cand[3][1] = -m->ldy;
  for(k = 0; k < 4; k++) {
    *lx = *ax + cand[k][0] * gr->w;
    *ly = *ay + cand[k][1] * gr->h;
    text_bbox(lab, txtsize, txtsize, 0, 0, 0, 0, *lx, *ly, tx1, ty1, tx2, ty2, &nlines, &dtmp);
    /* the fit test judges the PADDED box: the drawn border is what must stay
     * inside the plot box, not the glyphs */
    graph_marker_pad_box(nlines, tx1, ty1, tx2, ty2);
    if(*tx1 >= gr->x1 && *tx2 <= gr->x2 && *ty1 >= gr->y1 && *ty2 <= gr->y2) return 1;
  }
  /* nothing fits: take the primary placement and shove it back inside. The pad
   * goes on BEFORE the shove for the same reason -- §4.1 of the spec rests on
   * the callout never reaching the top margin (where xctx->graph_top disables
   * the GRAPHPAN routing latch) nor the reorder-grip column. */
  *lx = *ax + m->ldx * gr->w;
  *ly = *ay + m->ldy * gr->h;
  text_bbox(lab, txtsize, txtsize, 0, 0, 0, 0, *lx, *ly, tx1, ty1, tx2, ty2, &nlines, &dtmp);
  graph_marker_pad_box(nlines, tx1, ty1, tx2, ty2);
  if(*tx1 < gr->x1) *lx += gr->x1 - *tx1;
  if(*tx2 > gr->x2) *lx -= *tx2 - gr->x2;
  if(*ty1 < gr->y1) *ly += gr->y1 - *ty1;
  if(*ty2 > gr->y2) *ly -= *ty2 - gr->y2;
  text_bbox(lab, txtsize, txtsize, 0, 0, 0, 0, *lx, *ly, tx1, ty1, tx2, ty2, &nlines, &dtmp);
  graph_marker_pad_box(nlines, tx1, ty1, tx2, ty2);
  return 1;
}

/* The marker colour layer, clamped: gc[c] is indexed UNCHECKED by every drawing
 * primitive, so an out-of-range rc value would be an out-of-bounds read. */
static int graph_marker_color(void)
{
  int col = tclgetintvar("graph_marker_color");
  if(col < 0 || col >= cadlayers) col = 7 < cadlayers ? 7 : 0;
  return col;
}

/* Install the same cairo toy face draw_graph_all() uses, so a label MEASURED by
 * graph_marker_at() (which can be called from a Tcl verb, outside any draw) and
 * a label DRAWN by draw_graph_markers() come out the same size. Returns 1 when
 * a matching graph_marker_font_restore() is required. */
static int graph_marker_font_install(void)
{
#if HAS_CAIRO==1
  if(has_x && xctx->cairo_ctx) {
    cairo_save(xctx->cairo_ctx);
    cairo_save(xctx->cairo_save_ctx);
    xctx->cairo_font = cairo_toy_font_face_create("Sans-Serif",
                         CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
    cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
    cairo_font_face_destroy(xctx->cairo_font);
    return 1;
  }
#endif
  return 0;
}

static void graph_marker_font_restore(int installed)
{
#if HAS_CAIRO==1
  if(installed) {
    cairo_restore(xctx->cairo_ctx);
    cairo_restore(xctx->cairo_save_ctx);
  }
#else
  (void) installed;
#endif
}

/* Paint every marker of graph `i`, on top of the traces. Called from draw_graph
 * under flags bit 8. */
static void draw_graph_markers(int i, xRect *r, Graph_ctx *gr)
{
  GraphMarker *a = NULL;
  GraphMarkerRef *pool = NULL;
  int n = 0, np = 0, k, col, font, need_pool = 0;
  double lw, tsz;

  n = graph_markers_parse(r->prop_ptr, &a, &n);
  if(n <= 0) {
    if(a) my_free(_ALLOC_ID_, &a);
    return;
  }
  /* the window-wide pool is only needed to resolve DELTA partners, which may
   * live on another strip -- build it lazily so a plain-marker strip costs one
   * parse, not one per record */
  for(k = 0; k < n; k++) if(a[k].prev >= 1) { need_pool = 1; break; }
  if(need_pool) np = graph_markers_collect(&pool, &np);
  col = graph_marker_color();
  /* once per strip, not once per record: it reads a Tcl var, and draw_graph_all
   * loops every graph rect on every pan, zoom, cursor move and repaint */
  tsz = graph_marker_txtsize(gr);
  font = graph_marker_font_install();
  for(k = 0; k < n; k++) {
    GraphMarker m = a[k];
    double ax, ay, lx, ly, tx1, ty1, tx2, ty2, ex, ey;
    char lab[512];
    int selected;

    /* live drag: the scratch record replaces the stored one until the release
     * commits it, so a motion event costs no allocation and no undo point.
     * The label is built FROM THAT RECORD, so the readout tracks the anchor
     * while it slides instead of freezing at the pre-drag sample. */
    if(xctx->graph_marker_drag && i == xctx->graph_marker_draggraph &&
       m.num == xctx->graph_marker_dragnum) {
      m = xctx->graph_marker_scratch;
    }
    if(!graph_marker_text_rec(&m, i, pool, np, lab, S(lab))) {
      my_snprintf(lab, S(lab), "M%d", m.num);
    }
    if(!graph_marker_label_box(&m, gr, lab, tsz, &ax, &ay, &lx, &ly, &tx1, &ty1, &tx2, &ty2)) continue;
    /* Number ONLY, not `&& i == graph_marker_selgraph`: numbering is window-wide
     * and unique, so the number already identifies exactly one marker, whereas
     * selgraph is a rect INDEX that goes stale the moment a strip is reordered
     * or a multi-plot batch prepends one. It stays a hint (see the Delete gate,
     * which re-resolves the owner) and is never a correctness input.
     * Since issue 0189 the test is SET MEMBERSHIP, through the one predicate --
     * which is also why a cross-strip pair (a difference marker and its
     * reference on another band) can both render selected at all. */
    selected = graph_marker_is_selected(m.num);
    /* "selected" is stroke WEIGHT, not a different layer: SELLAYER == GRIDLAYER
     * so a selection colour here would be the grid colour, and drawgrid()
     * mutates that shared GC's dash style (issue 0082).
     *
     * BOTH states are now an EXPLICIT fixed pixel width. The unselected case
     * used to pass 0.0, which is not a zero width at all: drawrect/drawline
     * take their `else` branch and inherit the GC's resting width,
     * XLINEWIDTH(xctx->lw), and xctx->lw is 1.125 * mooz -- 1 px only while
     * zoom >= 0.5625. Zoomed into an on-canvas graph the unselected outline
     * grew to 2, 3, 4 ... 10 px, and at zoom <= 0.375 it was HEAVIER than the
     * selected one, inverting the cue. Pinning it at 1 px halves it or better
     * wherever it was heavy, makes "selected reads heavier" true at every zoom,
     * and matches the dot and ring, which have always been fixed pixel sizes.
     * 1 px is the floor of this path -- see GRAPH_MARKER_LW. */
    lw = selected ? GRAPH_MARKER_PX(GRAPH_MARKER_LW_SEL) : GRAPH_MARKER_PX(GRAPH_MARKER_LW);
    /* leader line first, so the opaque label box paints over its tail */
    ex = (tx1 + tx2) * 0.5;
    ey = (ay < ty1) ? ty1 : ((ay > ty2) ? ty2 : (ty1 + ty2) * 0.5);
    if(ax < tx1) ex = tx1;
    else if(ax > tx2) ex = tx2;
    drawline(col, NOW, ax, ay, ex, ey, lw, 0, NULL);
    filledrect(0, NOW, tx1, ty1, tx2, ty2, 2, -1, -1);
    /* the outline is ALWAYS drawn: filledrect returns early when the global fill
     * pattern is off (Ctrl+=) and for a box under ~3 world units */
    drawrect(col, NOW, tx1, ty1, tx2, ty2, lw, 0, -1, -1);
    /* the SAME tsz graph_marker_label_box() measured with: the drawn glyphs and
     * the clickable box must not be able to come out different sizes */
    draw_string(col, NOW, lab, 0, 0, 0, 0, lx, ly, tsz, tsz);
    /* xctx->zoom is world-units-per-pixel, so these are fixed pixel sizes */
    filledarc(col, NOW, ax, ay, 3.0 * xctx->zoom, 0, 360);
    if(selected) drawarc(col, NOW, ax, ay, 6.0 * xctx->zoom, 0, 360, 0, lw, 0);
  }
  graph_marker_font_restore(font);
  if(pool) my_free(_ALLOC_ID_, &pool);
  my_free(_ALLOC_ID_, &a);
}

/* Which marker is under the CANVAS PIXEL (px, py) of graph `i`?
 * Returns the marker NUMBER (0 = none) and sets *part to 1 (anchor) or 2 (label)
 * -- the two answers drive DIFFERENT drags, which is the whole reason this
 * returns a part rather than a boolean.
 *
 * Deliberately does NOT inherit graph_wave_at()'s `!xctx->raw` gate: a marker
 * still DRAWS when the raw is unloaded (its x/y are cached), so it must stay
 * selectable, draggable and deletable, or a schematic opened without its raw
 * would carry permanently stuck annotations. */
int graph_marker_at(int i, double px, double py, double tol, int *part)
{
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  GraphMarker *a = NULL;
  GraphMarkerRef *pool = NULL;
  xRect *r;
  int n = 0, np = 0, k, font, need_pool = 0, saveflags;
  int best = 0, best_part = 0;
  double best_d = 0.0;
  double wx, wy, tsz;

  if(part) *part = 0;
  if(!xctx) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return 0;
#if HAS_CAIRO==1
  /* --nogui has no cairo context, hence no measurable label box (and no pointer
   * either): answer "nothing", never crash. */
  if(!has_x || !xctx->cairo_ctx) return 0;
#endif
  n = graph_markers_parse(r->prop_ptr, &a, &n);
  if(n <= 0) {
    if(a) my_free(_ALLOC_ID_, &a);
    return 0;
  }
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  /* setup_graph_data() REWRITES graph_flags' hcursor bits from the rect it is
   * given (landmine 37). This is a pure query, also reachable from a Tcl verb,
   * so it must not leave the session describing a strip nobody is hovering. */
  saveflags = xctx->graph_flags & (128 | 256);
  setup_graph_data(i, 0, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->scx == 0.0 || gr->scy == 0.0) {
    my_free(_ALLOC_ID_, &a);
    return 0;
  }
  if(tol < 0.0) tol = 0.0;
  wx = X_TO_XSCHEM(px);
  wy = Y_TO_XSCHEM(py);
  for(k = 0; k < n; k++) if(a[k].prev >= 1) { need_pool = 1; break; }
  if(need_pool) np = graph_markers_collect(&pool, &np);
  tsz = graph_marker_txtsize(gr); /* once, like the renderer -- see draw_graph_markers */
  font = graph_marker_font_install();
  /* ANCHORS FIRST: a hit on the dot must beat the label box even if they overlap.
   * This pass reads only ax/ay, so the callout padding cannot steal an anchor hit. */
  for(k = 0; k < n; k++) {
    double ax, ay, lx, ly, tx1, ty1, tx2, ty2, d, sx, sy;
    char lab[512];
    if(!graph_marker_text_rec(&a[k], i, pool, np, lab, S(lab)))
      my_snprintf(lab, S(lab), "M%d", a[k].num);
    if(!graph_marker_label_box(&a[k], gr, lab, tsz, &ax, &ay, &lx, &ly, &tx1, &ty1, &tx2, &ty2)) continue;
    sx = X_TO_SCREEN(ax);
    sy = Y_TO_SCREEN(ay);
    d = sqrt((sx - px) * (sx - px) + (sy - py) * (sy - py));
    if(d <= tol && (best == 0 || d < best_d)) {
      best = a[k].num;
      best_part = 1;
      best_d = d;
    }
  }
  if(!best) {
    for(k = n - 1; k >= 0; k--) { /* last drawn is on top */
      double ax, ay, lx, ly, tx1, ty1, tx2, ty2;
      char lab[512];
      if(!graph_marker_text_rec(&a[k], i, pool, np, lab, S(lab)))
        my_snprintf(lab, S(lab), "M%d", a[k].num);
      if(!graph_marker_label_box(&a[k], gr, lab, tsz, &ax, &ay, &lx, &ly, &tx1, &ty1, &tx2, &ty2)) continue;
      if(POINTINSIDE(wx, wy, tx1, ty1, tx2, ty2)) {
        best = a[k].num;
        best_part = 2;
        break;
      }
    }
  }
  graph_marker_font_restore(font);
  if(pool) my_free(_ALLOC_ID_, &pool);
  my_free(_ALLOC_ID_, &a);
  if(part) *part = best_part;
  return best;
}

/* Resolve node index `wave` of graph rect `r` to the raw column that feeds it.
 * Mirrors the per-node walk of graph_point_at(), including the sweep-token
 * consumption for bus entries. Returns 1 on success. The caller my_free()s
 * *express when it is non-NULL.
 *
 * ⚠ ISSUE 0305, AND THE ONE PLACE THE BRACKET DOES NOT CLOSE HERE. This walker
 * read only the `%<n>` dataset digits, so a marker on a trace plotted from a
 * FOREIGN database (spec D1) resolved its name in the current database, where
 * it does not exist -- the readout was blank or, when the name happened to
 * exist in both, showed ANOTHER trace's number.
 * The returned `*idx` and `*sweep_idx` are COLUMN NUMBERS IN THAT DATABASE, so
 * the switch must still be in force while the caller reads them: this function
 * therefore leaves the database switched and reports, in `*db_restore_idx`, the
 * registry slot to unwind to (-1 = nothing to unwind). THE CALLER MUST CALL
 * node_db_restore(*db_restore_idx) on every exit path, including its failure
 * ones -- graph_marker_sample()'s `done:` label is that single point. */
static int graph_wave_resolve(xRect *r, int wave, int *idx, int *expression,
                              int *sweep_idx, char **express, int *node_dataset,
                              int *db_restore_idx)
{
  char *node = NULL, *sweep = NULL, *ntok_copy = NULL, *ex = NULL;
  char *graph_sim_type = NULL;
  char *node_rawfile = NULL, *node_sim_type = NULL;
  char *saven, *saves, *nptr, *sptr;
  const char *ntok, *stok;
  /* the last non-empty `sweep=` token, i.e. the sweep variable's NAME; see
   * graph_point_at() for why the NAME and not the carried column index */
  const char *sweep_name = NULL;
  int wcnt = -1, found = 0, autoload;
  int sw = 0, nds = -1;

  if(db_restore_idx) *db_restore_idx = -1;
  if(!r || wave < 0 || !xctx || !xctx->raw) return 0;
  autoload = !strboolcmp(get_tok_value(r->prop_ptr, "autoload", 0), "true");
  if(autoload == 0) autoload = 2;
  else if(autoload == 1) autoload = 33;
  my_strdup2(_ALLOC_ID_, &node, get_tok_value(r->prop_ptr, "node", 0));
  my_strdup2(_ALLOC_ID_, &sweep, get_tok_value(r->prop_ptr, "sweep", 0));
  my_strdup2(_ALLOC_ID_, &graph_sim_type, get_tok_value(r->prop_ptr, "sim_type", 0));
  nptr = node;
  sptr = sweep;
  while( (ntok = my_strtok_r(nptr, "\n", "\"", 4, &saven)) ) {
    wcnt++;
    stok = my_strtok_r(sptr, "\t\n ", "\"", 0, &saves);
    nptr = sptr = NULL;
    if(strstr(ntok, ",")) {
      if(find_nth(ntok, ";,", "\"", 0, 2)[0]) continue; /* bus: skip */
    }
    if(stok && stok[0]) {
      sweep_name = stok;
      sw = get_raw_index(stok, NULL);
      if(sw == -1) sw = 0;
    }
    if(wcnt != wave) continue;
    node_token_split(ntok, &ntok_copy, &nds, &node_rawfile, &node_sim_type,
                     node_dflt_sim_type(graph_sim_type));
    if(node_rawfile[0] && xctx->raw && xctx->raw->values) {
      int save_idx = xctx->extra_idx;
      if(extra_rawfile(autoload, node_rawfile, node_sim_type, -1.0, -1.0) == 0) {
        /* the database this trace names cannot be resolved: refuse rather than
         * read the numbers out of whatever database is current */
        found = 0;
        break;
      }
      if(db_restore_idx) *db_restore_idx = save_idx;
      /* the sweep column is a per-database index, re-resolved by NAME on every
       * entry that took the switch -- a carried-forward index belongs to the
       * PREVIOUS database and can be past the end of this one, and the caller
       * subscripts values[] with it (see graph_point_at() for the full note) */
      sw = 0;
      if(sweep_name && sweep_name[0]) {
        sw = get_raw_index(sweep_name, NULL);
        if(sw == -1) sw = 0;
      }
    }
    /* belt and braces: the column must exist in the database now current */
    if(xctx->raw && (sw < 0 || sw >= xctx->raw->nvars)) sw = 0;
    if(strstr(ntok_copy, ";")) my_strdup2(_ALLOC_ID_, &ex, find_nth(ntok_copy, ";", "\"", 0, 2));
    else my_strdup2(_ALLOC_ID_, &ex, ntok_copy);
    found = 1;
    break;
  }
  if(node_rawfile) my_free(_ALLOC_ID_, &node_rawfile);
  if(node_sim_type) my_free(_ALLOC_ID_, &node_sim_type);
  my_free(_ALLOC_ID_, &graph_sim_type);
  if(found) {
    int isexpr = (ex && strpbrk(ex, " \n\t")) ? 1 : 0;
    int ix = isexpr ? xctx->raw->nvars : (ex ? get_raw_index(ex, NULL) : -1);
    if(ix == -1) found = 0;
    if(idx) *idx = ix;
    if(expression) *expression = isexpr;
    if(sweep_idx) *sweep_idx = sw;
    if(node_dataset) *node_dataset = nds;
  }
  if(express && found) *express = ex;
  else if(ex) my_free(_ALLOC_ID_, &ex);
  if(ntok_copy) my_free(_ALLOC_ID_, &ntok_copy);
  my_free(_ALLOC_ID_, &node);
  my_free(_ALLOC_ID_, &sweep);
  return found;
}

/* Read the (x, y) of ABSOLUTE raw point `point` of node `wave` of graph `i`.
 * An EXPRESSION trace lives in the single GLOBAL scratch column values[nvars],
 * so its dataset window must be re-evaluated before the read -- a bare
 * get_raw_value() there returns whatever expression was plotted last. */
static int graph_marker_sample(int i, int wave, int dataset, int point, double *x, double *y)
{
  xRect *r;
  char *express = NULL;
  char *custom_rawfile = NULL, *sim_type = NULL;
  const char *ptr;
  int idx = -1, expression = 0, sweep_idx = 0, node_dataset = -1;
  int dset = 0, ofs = 0, ofs_end = 0, ok = 0, autoload, switched = 0;
  /* the registry slot graph_wave_resolve()'s PER-TRACE `%<rawfile>` switch has
   * to be unwound to (issue 0305); -1 = it made no switch */
  int node_restore_idx = -1;
  int entry_extra_idx = 0;  /* the database that was current on the way in */
  int entry_prev_idx = -1;  /* ...and where switch_back pointed on the way in */

  if(!xctx || !xctx->raw || !xctx->raw->values) return 0;
  if(sch_waves_loaded() == -1) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  r = &xctx->rect[GRIDLAYER][i];
  if(!(r->flags & 1)) return 0;
  /* Switch to the graph's OWN raw first, exactly as graph_point_at() does.
   * Without this the pixel path (which switches) and this data path (which did
   * not) disagreed on a multi-raw graph: the drag previewed samples from the
   * graph's rawfile and then committed values read out of whatever raw happened
   * to be current -- or silently failed when the node name is absent there.
   * graph_marker_release() commits EVERY anchor drag through here. */
  autoload = !strboolcmp(get_tok_value(r->prop_ptr, "autoload", 0), "true");
  if(autoload == 0) autoload = 2;
  else if(autoload == 1) autoload = 33;
  entry_extra_idx = xctx->extra_idx;
  entry_prev_idx = xctx->extra_prev_idx;
  ptr = get_tok_value(r->prop_ptr, "rawfile", 0);
  if(ptr[0]) {
    my_strdup2(_ALLOC_ID_, &custom_rawfile, ptr);
    my_strdup2(_ALLOC_ID_, &sim_type, get_tok_value(r->prop_ptr, "sim_type", 0));
    if(extra_rawfile(autoload, custom_rawfile,
       sim_type[0] ? sim_type : (xctx->raw->sim_type ? xctx->raw->sim_type : NULL),
       -1.0, -1.0) != 0) {
      switched = 1;
    } else {
      /* the pixel path (graph_point_at) skips every node when the graph's raw
       * cannot be resolved; the data path must agree rather than quietly read
       * the values out of whatever raw is current */
      goto done;
    }
  }
  if(!xctx->raw || !xctx->raw->values) goto done;
  /* issue 0305: resolve FIRST. For a cross-DB trace the resolve switches to the
   * trace's own database and `point`, `idx`, `sweep_idx` and every npoints[]
   * below are indices INTO THAT DATABASE, so a bounds check taken before the
   * switch would be measuring the wrong one. */
  if(!graph_wave_resolve(r, wave, &idx, &expression, &sweep_idx, &express, &node_dataset,
                         &node_restore_idx)) goto done;
  if(!xctx->raw || !xctx->raw->values) goto done;
  if(point < 0 || point >= xctx->raw->allpoints) goto done;
  for(dset = 0; dset < xctx->raw->datasets; dset++) {
    ofs_end = ofs + xctx->raw->npoints[dset];
    if(point >= ofs && point < ofs_end) break;
    ofs = ofs_end;
  }
  if(dset >= xctx->raw->datasets) goto done;
  if(dataset >= 0 && dataset != dset) goto done;
  if(expression) {
    if(plot_raw_custom_data(sweep_idx, ofs, ofs_end - 1, express, NULL) >= 0) ok = 1;
  } else ok = 1;
  if(ok) {
    if(x) *x = xctx->raw->values[sweep_idx][point];
    if(y) *y = xctx->raw->values[idx][point];
  }
  done:
  /* THE OTHER HALF of graph_wave_resolve()'s per-trace switch, and the reason
   * every failure above uses `goto done` rather than `return`. It must precede
   * the graph-level mode-5 swap: mode 5 is a SWAP, not a stack pop, so swapping
   * while a second switch is outstanding lands on the wrong database. */
  node_db_restore(node_restore_idx);
  if(switched) node_db_restore(entry_extra_idx); /* switch back, by index */
  node_db_prev_restore(entry_prev_idx);
  if(express) my_free(_ALLOC_ID_, &express);
  if(custom_rawfile) my_free(_ALLOC_ID_, &custom_rawfile);
  if(sim_type) my_free(_ALLOC_ID_, &sim_type);
  return ok;
}

static void graph_marker_refuse(const char *msg)
{
  if(has_x) tclvareval("if {[info procs ciw_echo] ne {}} {ciw_echo {", msg, "}}", NULL);
  dbg(1, "graph_marker: %s\n", msg);
}

/* THE read-only gate for markers, and the only one: 1 = refuse.
 *
 * It lives down here, in the mutating primitives, rather than in the key arms,
 * so it also covers the DRAG-COMMIT path (graph_marker_release ->
 * anchor_at/label_offset -> graph_marker_update), which reaches no key arm at
 * all and would otherwise let a mouse gesture permanently edit a read-only
 * buffer -- with NO undo point, because push_undo is skipped when readonly, and
 * `xschem undo` is itself readonly-rejected.
 *
 * A marker is durable CONTENT, unlike hilight_wave / cursor positions / the
 * axis ranges, which the graph engine has always written into read-only rects.
 *
 * The refusal is NON-BLOCKING (ciw_echo), like every other marker refusal --
 * deliberately not readonly_block()'s modal, which on a keystroke deadlocks any
 * script driving the refusal path.
 *
 * The ASE viewer is readonly for its whole life by construction and gets
 * through because wviewer::key_filter forwards m/d/Delete inside
 * wviewer::with_edit, the bracket every other viewer mutation already uses. */
static int graph_marker_ro_refuse(void)
{
  if(!xctx || !xctx->readonly) return 0;
  graph_marker_refuse("xschem: read-only, markers cannot be edited "
                      "(Edit > Make Editable to enable editing)");
  return 1;
}

/* Append one marker record to graph `i`. Shared tail of the pixel- and
 * data-addressed creators. Returns the new marker number, 0 on refusal. */
static int graph_marker_add_record(int i, int wave, int dataset, int point,
                                   double x, double y, int delta)
{
  xRect *r = &xctx->rect[GRIDLAYER][i];
  GraphMarker *a = NULL;
  GraphMarker m;
  int n = 0, prev;

  if(graph_marker_ro_refuse()) return 0;
  if(!GRAPH_MARKER_FINITE(x) || !GRAPH_MARKER_FINITE(y)) {
    graph_marker_refuse("xschem: cannot mark a non-finite sample");
    return 0;
  }
  n = graph_markers_parse(r->prop_ptr, &a, &n);
  if(n >= GRAPH_MARKERS_MAX) {
    if(a) my_free(_ALLOC_ID_, &a);
    graph_marker_refuse("xschem: too many markers on this graph");
    return 0;
  }
  /* the delta partner is the most recently created marker, resolved BEFORE the
   * new number is allocated (so `d` on an empty window makes a plain marker) */
  prev = delta ? graph_marker_max_number() : 0;
  memset(&m, 0, sizeof(m));
  m.num = graph_marker_next_number();
  m.wave = wave;
  m.dataset = dataset;
  m.point = point;
  m.x = x;
  m.y = y;
  m.prev = prev;
  m.ldx = 0.06;
  m.ldy = -0.09;
  my_realloc(_ALLOC_ID_, &a, (size_t)(n + 1) * sizeof(GraphMarker));
  a[n++] = m;
  if(!xctx->readonly) xctx->push_undo();
  graph_markers_store(r, a, n);
  my_free(_ALLOC_ID_, &a);
  set_modify(1);
  graph_marker_notify();
  /* ⚠ THE POSITION IS PART OF THE LINE (issue 0193). It used to be just
   * (i, wave, dataset, point), because x/y were BY DEFINITION that sample's
   * values and add_at re-derived them. They are interpolated now, so a replay
   * that re-derived would snap the marker back onto the sample and land it
   * somewhere the user never put it -- off-screen, at the zoom this matters at.
   * Old logs without the two trailing numbers still replay: add_at falls back
   * to the sample, which is exactly what those lines meant when they were
   * written. */
  log_action("xschem graph_marker add_at %d %d %d %d%s %.17g %.17g\n",
             i, wave, dataset, point, delta ? " -delta" : "", x, y);
  return m.num;
}

int graph_marker_create(int i, double px, double py, int delta)
{
  GraphPointHit hit;
  Graph_ctx gr_ctx;
  Graph_ctx *gr = &gr_ctx;
  int saveflags;

  if(!xctx) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  if(!(xctx->rect[GRIDLAYER][i].flags & 1)) return 0;
  memset(&gr_ctx, 0, sizeof(gr_ctx));
  saveflags = xctx->graph_flags & (128 | 256);   /* landmine 37, as above */
  setup_graph_data(i, 1, gr);
  xctx->graph_flags = (xctx->graph_flags & ~(128 | 256)) | saveflags;
  if(gr->digital) {
    graph_marker_refuse("xschem: markers are not supported on digital strips");
    return 0;
  }
  /* THE GATE IS THE PLOT BOX, NOT A DISTANCE TO A TRACE. `m`/`d` are keys --
   * pressing one is a clear intention -- so anywhere inside the strip's plot
   * area marks the sample the item-9 diamond is already sitting on, however far
   * that trace is. This is the SAME pair of calls draw_graph_snap_cursor()
   * makes (its snap pick loop, above), so the marker cannot land anywhere but
   * under the diamond. Outside the box -- the legend band, the axis-number
   * margins, the reorder grip column -- no diamond is drawn
   * (doc/claude/specs/waveform_viewer_modes.md 15.7), so there is no snapped
   * point to mark and the key refuses.
   * The gate MUST come from graph_plotbox_at(): the local `gr` above was built
   * with setup_graph_data(i, 1, ...) and skip = 1 leaves gx1/gx2/gw at 0 with
   * every derived coefficient at infinity, so gr->digital is the only field of
   * it that may be read (landmine 45). */
  if(!graph_plotbox_at(i, px, py)) {
    graph_marker_refuse("xschem: the pointer is not inside the plot area of a strip");
    return 0;
  }
  /* A tol nothing can exceed: the RANKING graph_point_at does (nearest trace by
   * point-to-segment distance, then the nearest sample on it) is what we want,
   * the threshold is not. Reaching the refusal below now means the strip has no
   * markable trace at all -- traceless, bus-only, or an unresolvable rawfile=. */
  if(!graph_point_at(i, px, py, 1e30, -1, -1, &hit)) {
    graph_marker_refuse("xschem: no trace to mark in this strip");
    return 0;
  }
  /* issue 0193: the POINT ON THE CURVE, which is what the diamond is sitting on
   * -- issue 0188's promise ("add a marker at the point that the diamond cursor
   * has snapped to") is only kept if the two read the same field. The record
   * still carries a sample index as its anchor, the segment's left end. */
  return graph_marker_add_record(i, hit.wave, hit.seg_dataset, hit.seg_point,
                                 hit.seg_x, hit.seg_y, delta);
}

/* `have_xy` 0 = resolve the position from the sample, which is what every log
 * line written before issue 0193 meant; 1 = place it at the given interpolated
 * point, with (dataset, point) kept only as the anchor. */
int graph_marker_create_at(int i, int wave, int dataset, int point, int delta,
                           int have_xy, double xin, double yin)
{
  double x = 0.0, y = 0.0;

  if(!xctx) return 0;
  if(i < 0 || i >= xctx->rects[GRIDLAYER]) return 0;
  if(!(xctx->rect[GRIDLAYER][i].flags & 1)) return 0;
  /* resolved even when the caller supplies x/y: it is the ONE validation that
   * the trace/dataset/point triple addresses anything at all, and a replay that
   * silently created a marker on a nonexistent trace would be worse than one
   * that refuses. */
  if(!graph_marker_sample(i, wave, dataset, point, &x, &y)) {
    graph_marker_refuse("xschem: cannot resolve that trace/point");
    return 0;
  }
  if(have_xy) { x = xin; y = yin; }
  return graph_marker_add_record(i, wave, dataset, point, x, y, delta);
}

/* Rewrite one marker record in place. `store` 0 = scratch only (no token write). */
static int graph_marker_update(int num, const GraphMarker *upd)
{
  int gi = -1, k, n = 0;
  GraphMarker *a = NULL;
  xRect *r;

  if(!xctx || num <= 0) return 0;
  if(graph_marker_ro_refuse()) return 0;
  if(!graph_marker_find(num, &gi, NULL)) return 0;
  r = &xctx->rect[GRIDLAYER][gi];
  n = graph_markers_parse(r->prop_ptr, &a, &n);
  for(k = 0; k < n; k++) {
    if(a[k].num == num) {
      a[k] = *upd;
      if(!xctx->readonly) xctx->push_undo();
      graph_markers_store(r, a, n);
      my_free(_ALLOC_ID_, &a);
      set_modify(1);
      graph_marker_notify();
      return 1;
    }
  }
  if(a) my_free(_ALLOC_ID_, &a);
  return 0;
}

/* A delta rendered against a ghost is a bug: clear every `prev` pointing at
 * `num`, window-wide (the partner may live in another strip). Shared by the
 * single delete and by delete -all. */
static void graph_marker_clear_prev_n(const int *nums, int nnums)
{
  int i, k, j;

  if(!xctx || !nums || nnums <= 0) return;
  /* ONE pass over the window for the WHOLE set, not one pass per number: a
   * partial `delete -all <gi>` leaves the other strips populated, and the
   * per-number form was O(deleted x surviving records) -- measured 10 s at 4000
   * markers, i.e. the same full-window-rescan-per-record shape the renderer's
   * pool was introduced to remove. */
  for(i = 0; i < xctx->rects[GRIDLAYER]; i++) {
    GraphMarker *b = NULL;
    int m = 0, changed = 0;
    xRect *rr = &xctx->rect[GRIDLAYER][i];
    if(!(rr->flags & 1)) continue;
    m = graph_markers_parse(rr->prop_ptr, &b, &m);
    for(k = 0; k < m; k++) {
      if(b[k].prev <= 0) continue;
      for(j = 0; j < nnums; j++) {
        if(b[k].prev == nums[j]) { b[k].prev = 0; changed = 1; break; }
      }
    }
    if(changed) graph_markers_store(rr, b, m);
    if(b) my_free(_ALLOC_ID_, &b);
  }
}

static void graph_marker_clear_prev(int num)
{
  graph_marker_clear_prev_n(&num, 1);
}

/* ---- THE SELECTION (issue 0189) -------------------------------------------
 * It is a SET of marker NUMBERS, head first, held in xctx and NEVER in a prop
 * token: selection is UI state and must die with the document
 * (graph_markers.md 3.5 / D9). xctx->graph_marker_sel is kept as the HEAD, so
 * `xschem get graph_marker_sel`, this file's Delete scope gate and
 * wviewer::marker_selected are byte-for-byte unchanged.
 *
 * These five functions are the ONLY readers/writers of the pair of fields
 * (plus the three sanctioned HEAD readers: the getter in scheduler.c, the
 * Delete scope gate and the repaint-scope hint in callback.c). That is what
 * stopped the two issue-0175 trace tokens drifting, and it is what the
 * source-level MS13 leg asserts. */

/* THE predicate. Every "is this marker selected" test in the tree goes through
 * it -- a bare `== xctx->graph_marker_sel` renders a selected partner in the
 * unselected style and no leg that selects ONE marker can see it. */
int graph_marker_is_selected(int num)
{
  int k;
  if(!xctx || num <= 0) return 0;
  for(k = 0; k < xctx->graph_marker_n_sel; k++)
    if(xctx->graph_marker_sel_set[k] == num) return 1;
  return 0;
}

/* THE writer. Drops <= 0, dedupes, caps at GRAPH_MARKER_MAX_SEL, keeps the
 * given ORDER (selection order, not sorted) and re-derives the head.
 * Pure UI state: no token write, no undo point, no modify flag, no log line
 * (D-17 -- trace selection does not log either). */
int graph_marker_select_set(const int *nums, int n, int graph_idx)
{
  int k, w = 0;
  if(!xctx) return -1;
  for(k = 0; k < n && w < GRAPH_MARKER_MAX_SEL; k++) {
    int j, dup = 0;
    if(nums[k] <= 0) continue;
    for(j = 0; j < w; j++) if(xctx->graph_marker_sel_set[j] == nums[k]) dup = 1;
    if(dup) continue;
    xctx->graph_marker_sel_set[w++] = nums[k];
  }
  xctx->graph_marker_n_sel = w;
  xctx->graph_marker_sel = w ? xctx->graph_marker_sel_set[0] : -1;
  xctx->graph_marker_selgraph = w ? graph_idx : -1;
  return xctx->graph_marker_sel;
}

/* The shipped single-selection form, now a one-line wrapper. Its contract and
 * its return value are byte-identical to before the set existed. */
int graph_marker_select(int num, int graph_idx)
{
  if(!xctx) return -1;
  if(num < 0) return graph_marker_select_set(NULL, 0, -1);
  return graph_marker_select_set(&num, 1, graph_idx);
}

/* THE POLICY behind the double-click: select `num` and, when it is a DIFFERENCE
 * marker whose partner still resolves, the one marker its deltas are derived
 * from. The IMMEDIATE pair only -- never the chain (D-6) and never the reverse
 * direction (D-7): `prev` is a back-pointer and N deltas may share one
 * reference. An unresolvable partner is silent (D-5): graph_marker_clear_prev_n
 * already zeroes dangling links on every delete, so a dangling one only comes
 * from a hand-edited or foreign token. It SETS; it never toggles. */
int graph_marker_select_pair(int num, int graph_idx)
{
  int nums[2], n = 1, owner = -1;
  GraphMarker m;

  if(!xctx || num <= 0) return graph_marker_select(-1, -1);
  /* permissive, exactly like the shipped `select <num>`: an unknown number is
   * still selected (it simply renders no ring) */
  if(!graph_marker_find(num, &owner, &m)) return graph_marker_select(num, graph_idx);
  nums[0] = num;
  if(m.prev >= 1 && graph_marker_find(m.prev, NULL, NULL)) {
    nums[1] = m.prev;
    n = 2;
  }
  return graph_marker_select_set(nums, n, owner);
}

/* remove one number from the set, keeping the order of the survivors. Used by
 * the delete path: a deleted marker cannot stay selected. */
static void graph_marker_sel_drop(int num)
{
  int k, w = 0, keep[GRAPH_MARKER_MAX_SEL];
  int gi;
  if(!xctx) return;
  gi = xctx->graph_marker_selgraph;
  for(k = 0; k < xctx->graph_marker_n_sel; k++)
    if(xctx->graph_marker_sel_set[k] != num) keep[w++] = xctx->graph_marker_sel_set[k];
  if(w == xctx->graph_marker_n_sel) return;
  graph_marker_select_set(keep, w, gi);
}

/* The engine of the two public delete forms. `push` is 0 when the CALLER
 * already pushed one undo point for the whole gesture -- a multi-marker delete
 * owes exactly ONE, or a one-key gesture would need two `u` to take back. */
static int graph_marker_delete_1(int num, int push)
{
  int gi = -1, k, n = 0, w = 0;
  GraphMarker *a = NULL;
  xRect *r;

  if(!xctx || num <= 0) return 0;
  if(graph_marker_ro_refuse()) return 0;
  if(!graph_marker_find(num, &gi, NULL)) return 0;
  if(push && !xctx->readonly) xctx->push_undo();
  r = &xctx->rect[GRIDLAYER][gi];
  n = graph_markers_parse(r->prop_ptr, &a, &n);
  for(k = 0; k < n; k++) if(a[k].num != num) a[w++] = a[k];
  graph_markers_store(r, a, w);
  if(a) my_free(_ALLOC_ID_, &a);
  graph_marker_clear_prev(num);
  graph_marker_sel_drop(num);
  set_modify(1);
  graph_marker_notify();
  log_action("xschem graph_marker delete %d\n", num);
  return 1;
}

int graph_marker_delete(int num)
{
  return graph_marker_delete_1(num, 1);
}

int graph_marker_delete_all(int graph_idx)
{
  int i, k, n = 0, cnt = 0, pushed = 0;
  int *gone = NULL, ngone = 0;

  if(!xctx) return 0;
  if(graph_marker_ro_refuse()) return 0;
  for(i = 0; i < xctx->rects[GRIDLAYER]; i++) {
    GraphMarker *a = NULL;
    xRect *r = &xctx->rect[GRIDLAYER][i];
    if(!(r->flags & 1)) continue;
    if(graph_idx >= 0 && graph_idx != i) continue;
    n = graph_markers_parse(r->prop_ptr, &a, &n);
    if(n > 0) {
      if(!pushed) {
        if(!xctx->readonly) xctx->push_undo();
        pushed = 1;
      }
      /* remember what vanished so the dangling prev links can be swept below --
       * a partial delete -all leaves deltas on the strips it did not touch */
      my_realloc(_ALLOC_ID_, &gone, (size_t)(ngone + n) * sizeof(int));
      for(k = 0; k < n; k++) gone[ngone++] = a[k].num;
      cnt += n;
      graph_markers_store(r, NULL, 0);
    }
    if(a) my_free(_ALLOC_ID_, &a);
  }
  graph_marker_clear_prev_n(gone, ngone);
  if(gone) my_free(_ALLOC_ID_, &gone);
  if(cnt) {
    graph_marker_select_set(NULL, 0, -1);
    set_modify(1);
    graph_marker_notify();
    log_action("xschem graph_marker delete -all %d\n", graph_idx);
  }
  return cnt;
}

/* Deletes the WHOLE selection as ONE gesture with ONE undo point (issue 0189 /
 * D-8): a Delete that needed two `u` to take back is the defect this shape
 * exists to prevent. Each member still self-logs its own
 * `xschem graph_marker delete <n>` line, so a replay reproduces the deletions
 * by explicit number.
 *
 * Returns 0 WITHOUT touching anything when nothing is selected -- that is what
 * lets the Delete key fall through to its historical canvas behaviour. */
int graph_marker_delete_selected(void)
{
  int nums[GRAPH_MARKER_MAX_SEL];
  int k, n, cnt = 0;

  if(!xctx || xctx->graph_marker_n_sel <= 0) return 0;
  if(graph_marker_ro_refuse()) return 0;   /* ONE CIW line, not one per member */
  /* COPY the set before the loop: graph_marker_sel_drop() mutates it as the
   * records go, so iterating it in place would skip every other member. */
  n = xctx->graph_marker_n_sel;
  for(k = 0; k < n; k++) nums[k] = xctx->graph_marker_sel_set[k];
  if(!xctx->readonly) xctx->push_undo();
  for(k = 0; k < n; k++) cnt += graph_marker_delete_1(nums[k], 0);
  return cnt;
}

int graph_marker_move(int num, double px, double py)
{
  GraphMarker m;
  GraphPointHit hit;
  int gi = -1;

  if(!xctx || num <= 0) return 0;
  if(!graph_marker_find(num, &gi, &m)) return 0;
  /* a huge tolerance so a drag can never "lose" the marker; the two restrictions
   * keep it sliding along its OWN trace, within its own sweep */
  if(!graph_point_at(gi, px, py, 1e30, m.wave, m.dataset, &hit)) return 0;
  /* issue 0193: a drag follows the CURVE, for the same reason the creation does
   * -- the marker must stay under the pointer, and below the sample spacing the
   * nearest sample is not even on screen. */
  m.dataset = hit.seg_dataset;
  m.point = hit.seg_point;
  m.x = hit.seg_x;
  m.y = hit.seg_y;
  if(!graph_marker_update(num, &m)) return 0;
  log_action("xschem graph_marker anchor %d %d %d %.17g %.17g\n",
             num, m.dataset, m.point, m.x, m.y);
  return 1;
}

/* `have_xy` 0 = snap to the sample (every pre-0193 log line), 1 = the given
 * interpolated position, with (dataset, point) kept as the anchor. */
int graph_marker_anchor_at(int num, int dataset, int point, int have_xy,
                           double xin, double yin)
{
  GraphMarker m;
  int gi = -1;
  double x = 0.0, y = 0.0;

  if(!xctx || num <= 0) return 0;
  if(!graph_marker_find(num, &gi, &m)) return 0;
  /* always resolved: it validates the triple even when x/y are supplied */
  if(!graph_marker_sample(gi, m.wave, dataset, point, &x, &y)) return 0;
  if(have_xy) { x = xin; y = yin; }
  if(!GRAPH_MARKER_FINITE(x) || !GRAPH_MARKER_FINITE(y)) return 0;
  m.dataset = dataset;
  m.point = point;
  m.x = x;
  m.y = y;
  if(!graph_marker_update(num, &m)) return 0;
  log_action("xschem graph_marker anchor %d %d %d %.17g %.17g\n",
             num, dataset, point, x, y);
  return 1;
}

int graph_marker_label_offset(int num, double ldx, double ldy)
{
  GraphMarker m;
  int gi = -1;

  if(!xctx || num <= 0) return 0;
  if(!GRAPH_MARKER_FINITE(ldx) || !GRAPH_MARKER_FINITE(ldy)) return 0;
  if(!graph_marker_find(num, &gi, &m)) return 0;
  if(ldx < -2.0) ldx = -2.0;
  if(ldx >  2.0) ldx =  2.0;
  if(ldy < -2.0) ldy = -2.0;
  if(ldy >  2.0) ldy =  2.0;
  m.ldx = ldx;
  m.ldy = ldy;
  if(!graph_marker_update(num, &m)) return 0;
  log_action("xschem graph_marker label %d %.10g %.10g\n", num, ldx, ldy);
  return 1;
}

/* Give every marker of a freshly pasted rect a unique number. `base` is computed
 * ONCE: merge_box runs BEFORE gfx_register bumps xctx->rects[], so the rect
 * being merged is invisible to graph_marker_next_number()'s scan and calling it
 * per record would hand every record the same number. `prev` links are cleared
 * (a cross-rect number map is not visible from a per-rect callback). */
int graph_marker_renumber_rect(xRect *r)
{
  GraphMarker *a = NULL;
  int n = 0, k, base;

  if(!xctx || !r || !(r->flags & 1)) return 0;
  n = graph_markers_parse(r->prop_ptr, &a, &n);
  if(n <= 0) {
    if(a) my_free(_ALLOC_ID_, &a);
    return 0;
  }
  base = graph_marker_next_number();
  for(k = 0; k < n; k++) {
    a[k].num = base + k;
    a[k].prev = 0;
  }
  graph_markers_store(r, a, n);
  my_free(_ALLOC_ID_, &a);
  return n;
}

/* Push a marker change into the ASE waveform viewer's Tcl model.
 *
 * WHY A PUSH AND NOT A PULL: wviewer::regenerate clears the canvas and re-places
 * every rect from the Tcl model, and it is called from ~18 sites -- including a
 * plain WINDOW RESIZE (configure_apply) -- of which only three first fold live
 * rect state back into the model. A pull-only design therefore loses every
 * marker on a resize, with no user action that reads as destructive.
 *
 * Result codes from the Tcl side: 1 model updated, 2 not a viewer window
 * (nothing to do), 0 the viewer proc bailed, -1 a Tcl error was caught. A silent
 * bail would resurface much later as "my markers vanished", so it is logged. */
void graph_marker_notify(void)
{
  const char *res;

  if(!has_x) return;
  tcleval("if {[llength [info commands graph_marker_changed]]} "
          "{ if {[catch {graph_marker_changed} __gmr]} { set __gmr -1 }; set __gmr } "
          "else { list 2 }");
  res = tclresult();
  if(res && res[0] && strcmp(res, "1") && strcmp(res, "2"))
    dbg(0, "graph_marker_notify(): ASE marker push did NOT land (result=%s)\n", res);
}


/* flags:
 *  1: do final XCopyArea (copy 2nd buffer areas to screen)
 *     If draw_graph_all() is called from draw() no need to do XCopyArea, as draw() does it already.
 *     This makes drawing faster and removes a 'tearing' effect when moving around.
 *  2: draw x-cursor1
 *  4: draw x-cursor2
 * 128: draw y-cursor1
 * 256: draw y-cursor2
 *  8: all drawing, if not set do only XCopyArea / x-cursor if specified
 * 16: ON-SCREEN draw: also paint the ASE viewer's active-strip marker when the
 *     graph carries `active=1` (issue 0151). Set by draw_graph_all() and by the
 *     interactive partial-redraw callers (callback.c, `xschem draw_graph`), NOT
 *     by the SVG/PS export callers — a printed schematic carries no UI marker.
 * ct is a pointer used in windows for cairo
 */
void draw_graph(int i, int flags, Graph_ctx *gr, void *ct)
{
  int wc = 4, wave_color = 4;
  char *node = NULL, *color = NULL, *sweep = NULL;
  int sweep_idx = 0;
  const char *sweep_name = NULL; /* last non-empty `sweep=` token, carried forward BY NAME */
  int n_nodes; /* number of variables to display in a single graph */
  char *saven, *savec, *saves, *nptr, *cptr, *sptr;
  const char *ntok, *ctok, *stok;
  char *bus_msb = NULL;
  int wcnt = 0, idx, expression;
  int measure_p;
  double measure_x;
  double measure_prev_x;
  char *express = NULL;
  xRect *r = &xctx->rect[GRIDLAYER][i];
  int node_dataset = -1; /* dataset specified as %<n> after node/bus/expression name */
  char *ntok_copy = NULL; /* copy of ntok without %<n> */
  char *custom_rawfile = NULL; /* "rawfile" attr. set in graph: load and switch to specified raw */
  char *sim_type = NULL;
  int save_extra_idx = -1;
  int save_prev_idx = -1;   /* the OTHER half of the cursor: where switch_back goes */
  double cursor1, cursor2;

  xctx->ev_precision = tclgetintvar("ev_precision");
  if(xctx->only_probes) return;
  if(RECT_OUTSIDE( gr->sx1, gr->sy1, gr->sx2, gr->sy2,
      xctx->areax1, xctx->areay1, xctx->areax2, xctx->areay2)) return;

  /* viewer plan item 6: arm the mid-drag SHRINK PREVIEW for this graph. Done
   * here rather than in setup_graph_data because this is the only place that
   * has BOTH the graph index and the flags, and the flags decide it:
   * bit 16 is on-screen CHROME, stripped from every export (landmine 18), so a
   * printed or SVG'd schematic always gets the trace at full size. `has_x`
   * because a preview is a thing you look at.
   * The scale is read straight from xctx at draw time (a scalar, not the shared
   * graph_struct), so a motion event only has to write a handful of numbers.
   * Issue 0192: this only decides whether the graph is chrome-enabled. The
   * MEMBERSHIP test moved into graph_preview_has(), so ONE predicate answers for
   * every graph and a multi-strip drag needs no per-graph bookkeeping here. */
  gr->preview_gi = ((flags & 16) && has_x) ? i : -1;

  if(r->flags & 4) { /* private_cursor */
    const char *s = get_tok_value(r->prop_ptr, "cursor1_x", 0);
    if(s[0]) {
      cursor1 = atof_eng(s);
    } else {
      cursor1 = xctx->graph_cursor1_x;
    }
  } else {
    cursor1 = xctx->graph_cursor1_x;
  }

  if(r->flags & 4) { /* private_cursor */
    const char *s = get_tok_value(r->prop_ptr, "cursor2_x", 0);
    if(s[0]) {
      cursor2 = atof_eng(s);
    } else {
      cursor2 = xctx->graph_cursor2_x;
    }
  } else {
    cursor2 = xctx->graph_cursor2_x;
  }

  #if 0
  dbg(0, "draw_graph(): window: %d %d %d %d\n", xctx->areax1, xctx->areay1, xctx->areax2, xctx->areay2);
  dbg(0, "draw_graph(): graph: %g %g %g %g\n", gr->sx1, gr->sy1, gr->sx2, gr->sy2);
  dbg(0, "draw_graph(): i = %d, flags = %d graph_flags=%d\n", i, flags, xctx->graph_flags);
  #endif

  /* draw stuff */
  if(flags & 8) {
    int autoload = 0;
    char *tmp_ptr = NULL;
    int save_datasets = -1, save_npoints = -1;
    const char *ptr;
    #if !defined(__unix__) && HAS_CAIRO==1
    double sw = (gr->sx2 - gr->sx1);
    double sh = (gr->sy2 - gr->sy1);
    clear_cairo_surface(xctx->cairo_save_ctx, gr->sx1, gr->sy1, sw, sh);
    clear_cairo_surface(xctx->cairo_ctx, gr->sx1, gr->sy1, sw, sh);
    #endif
    autoload = !strboolcmp(get_tok_value(r->prop_ptr,"autoload", 0), "true");
    if(autoload == 0) autoload = 2; /* 2: switch */
    else if(autoload == 1) autoload = 33; /* 1: read, 32: no_warning */
    /* graph box, gridlines and axes */
    draw_graph_grid(gr, ct);
    /* get data to plot */
    my_strdup2(_ALLOC_ID_, &node, get_tok_value(r->prop_ptr,"node", 0));
    my_strdup2(_ALLOC_ID_, &color, get_tok_value(r->prop_ptr,"color", 0));
    my_strdup2(_ALLOC_ID_, &sweep, get_tok_value(r->prop_ptr,"sweep", 0));

    ptr = get_tok_value(r->prop_ptr,"rawfile", 0);
    if(!ptr[0]) {
      if(xctx->raw && xctx->raw->rawfile) my_strdup2(_ALLOC_ID_, &custom_rawfile, xctx->raw->rawfile);
      else  my_strdup2(_ALLOC_ID_, &custom_rawfile, "");
    } else {
      my_strdup2(_ALLOC_ID_, &custom_rawfile, ptr);
    }
    my_strdup2(_ALLOC_ID_, &sim_type, get_tok_value(r->prop_ptr,"sim_type", 0));
    dbg(1, "draw_graph(): graph %d: custom_rawfile=%s autoload=%d sim_type=%s\n",
        i, custom_rawfile, autoload, sim_type);
    save_extra_idx = xctx->extra_idx;
    save_prev_idx = xctx->extra_prev_idx;

    nptr = node;
    cptr = color;
    sptr = sweep;
    n_nodes = count_items(node, "\n", "\"");

    /* process each node given in "node" attribute, get also associated color/sweep var if any*/
    while( (ntok = my_strtok_r(nptr, "\n", "\"", 4, &saven)) ) {
      int valid_rawfile = 1;
      char *node_rawfile = NULL;
      char *node_sim_type = NULL;
      char str_extra_idx[30];

      nptr = NULL;
      measure_p = -1;
      measure_x = 0.0;
      measure_prev_x = 0.0;
      if(custom_rawfile[0]) {
        if(extra_rawfile(autoload, custom_rawfile, sim_type[0] ? sim_type :
           (xctx->raw && xctx->raw->sim_type ? xctx->raw->sim_type : NULL), -1.0, -1.0) == 0) {
          valid_rawfile = 0;
        }
      }
      if(wcnt >= n_nodes) {
        dbg(0, "draw_graph(): WARNING: wcnt (wave #) >= n_nodes (counted # of waves)\n");
        dbg(0, "draw_graph(): n_nodes=%d\n", n_nodes);
        wcnt--; /* nosense, but avoid a crash */
      }
      /* if %<n> is specified after node name, <n> is the dataset number to plot in graph */
      /* if %n rawfile.raw is specified use rawfile.raw for this node */
      /* THE REFERENCE SITE for issue 0305: this walker always honoured the
       * per-trace `%<rawfile>`, and its switch is unwound at the bottom of the
       * loop by save_extra_idx. Only the PARSE moved into node_token_split();
       * the switch, the guard and the restore are byte-for-byte what they were. */
      node_token_split(ntok, &ntok_copy, &node_dataset, &node_rawfile, &node_sim_type,
                       node_dflt_sim_type(sim_type));
      if(node_rawfile[0] && xctx->raw && xctx->raw->values) {
        dbg(1, "node_rawfile=|%s| node_sim_type=|%s|\n", node_rawfile, node_sim_type);
        if(extra_rawfile(autoload, node_rawfile, node_sim_type, -1.0, -1.0) == 0) {
          valid_rawfile = 0;
        }
      }
      my_free(_ALLOC_ID_, &node_rawfile);
      my_free(_ALLOC_ID_, &node_sim_type);
      dbg(1, "ntok=|%s|, node_dataset = %d\n", ntok, node_dataset);
      /* transform multiple OP points into a dc sweep */
      if(xctx->raw && xctx->raw->sim_type && !strcmp(xctx->raw->sim_type, "op")
         && xctx->raw->datasets > 1 && xctx->raw->npoints[0] == 1) {
        save_datasets = xctx->raw->datasets;
        xctx->raw->datasets = 1;
        save_npoints = xctx->raw->npoints[0];
        xctx->raw->npoints[0] = xctx->raw->allpoints;
      }

      dbg(1, "ntok=|%s|\nntok_copy=|%s|\nnode_dataset=%d\n", ntok, ntok_copy, node_dataset);

      tmp_ptr = find_nth(ntok_copy, ";", "\"", 4, 2);
      if(strstr(tmp_ptr, ",")) {
        tmp_ptr = find_nth(tmp_ptr, ",", "\"", 4, 1);
        /* also trim spaces */
        my_strdup2(_ALLOC_ID_, &bus_msb, trim_chars(tmp_ptr, "\n "));
      }
      dbg(1, "ntok_copy=|%s|, bus_msb=|%s|\n", ntok_copy, bus_msb ? bus_msb : "<NULL>");
      ctok = my_strtok_r(cptr, " ", "", 0, &savec);
      stok = my_strtok_r(sptr, "\t\n ", "\"", 0, &saves);
      cptr = sptr = NULL;
      dbg(1, "ntok_copy=%s ctok=%s\n", ntok_copy, ctok? ctok: "<NULL>");
      if(ctok && ctok[0]) wc = atoi(ctok);
      if(wc < 0) wc = 4;
      if(wc >= cadlayers) wc = cadlayers - 1;
      /* ⚠ THE SWEEP COLUMN IS RE-RESOLVED BY NAME ON EVERY ENTRY (batch F item 2,
       * issue 0305). This is the reference walker and it always resolved the
       * column AFTER its per-node switch -- but only for entries carrying their
       * OWN `sweep=` token. A `sweep=` list shorter than the `node=` list carries
       * its last entry forward (stok comes back NULL), and what an entry must
       * inherit is the sweep variable's NAME: a column NUMBER was resolved in the
       * PREVIOUS entry's database and means nothing in this one. With a cross-DB
       * `%<rawfile>` entry (spec D1) between two graph-DB entries, a five-column
       * analog raw's column 4 was carried into a three-column VCD and used as
       * values[4] -- an out-of-bounds read on the renderer's hot path.
       * graph_point_at(), wave_hilight_envelope(), graph_wave_resolve() and
       * find_closest_wave() all keep the name for the same reason. */
      if(stok && stok[0]) sweep_name = stok;
      if(sweep_name && sweep_name[0]) {
        sweep_idx = get_raw_index(sweep_name, NULL);
        if( sweep_idx == -1) {
          sweep_idx = 0;
        }
      }
      /* belt and braces: values[] holds nvars+1 columns, the last the scratch */
      if(xctx->raw && (sweep_idx < 0 || sweep_idx >= xctx->raw->nvars)) sweep_idx = 0;
      draw_graph_variables(wcnt, wc, n_nodes, sweep_idx, flags, ntok, stok, bus_msb, gr);
      /* if ntok_copy following possible 'alias;' definition contains spaces --> custom data plot */
      idx = -1;
      expression = 0;
      if(!bus_msb) {
        char *match;
        if(strstr(ntok_copy, ";")) {
          my_strdup2(_ALLOC_ID_, &express, find_nth(ntok_copy, ";", "\"", 0, 2));
        } else {
          my_strdup2(_ALLOC_ID_, &express, ntok_copy);
        }
        dbg(1, "express=|%s|\n", express);

        match = strpbrk(express, " \n\t");
        if( match  && (match == express || *(match - 1) != '\\')) {
          expression = 1;
        }
        if(match && match > express && *(match - 1) == '\\') {
          my_strdup2(_ALLOC_ID_, &express, str_replace(express, "\\ ", " ", 0, -1));
        }
      }
      if(sch_waves_loaded() != -1 && tclgetboolvar("auto_hilight_graph_nodes")) {
        if(!expression && xctx->raw->sim_type && strcmp(xctx->raw->sim_type, "op") ) {
          if(!bus_msb) hilight_graph_node(express, wc);
          else         hilight_graph_node(bus_msb, wc);
        }
      }
      dbg(1, "express=%s, bus_msb=%s\n", express ? express : "<NULL>", bus_msb ? bus_msb : "<NULL>");
      /* quickly find index number of ntok_copy variable to be plotted */
      if(sch_waves_loaded() != -1 && valid_rawfile &&
         (expression || (idx = get_raw_index(bus_msb ? bus_msb : express, NULL)) != -1)) {
        int p, dset, ofs, ofs_end;
        int poly_npoints;
        int first, last;
        double xx; /* the p-th sweep variable value:  xctx->raw->values[sweep_idx][p] */
        double xx0 = 0.0; /* the first sweep value */
        double start;
        double end;
        int n_bits = 1;
        SPICE_DATA **idx_arr = NULL;
        int sweepvar_wrap = 0; /* incremented on new dataset or sweep variable wrap */
        XPoint *point = NULL;
        int dataset = node_dataset >=0 ? node_dataset : gr->dataset;
        int digital = gr->digital;
        ofs = 0;
        start = (gr->gx1 <= gr->gx2) ? gr->gx1 : gr->gx2;
        end = (gr->gx1 <= gr->gx2) ? gr->gx2 : gr->gx1;
        if(bus_msb) {
          idx_arr = get_bus_idx_array(ntok_copy, &n_bits); /* idx_arr allocated by function, must free! */
        }
        bbox(START, 0.0, 0.0, 0.0, 0.0);
        bbox(ADD,gr->x1, gr->y1, gr->x2, gr->y2);
        bbox(SET, 0.0, 0.0, 0.0, 0.0);
        /* loop through all datasets found in raw file */

        if(sch_waves_loaded() != -1) for(dset = 0 ; dset < xctx->raw->datasets; dset++) {
          double prev_x;
          int cnt=0, wrap;
          register SPICE_DATA *gv = xctx->raw->values[sweep_idx];
          register SPICE_DATA *gv0 = xctx->raw->values[0];

          ofs_end = ofs + xctx->raw->npoints[dset];
          first = -1;
          poly_npoints = 0;
          my_realloc(_ALLOC_ID_, &point, xctx->raw->npoints[dset] * sizeof(XPoint));
          /* Process "npoints" simulation items
           * p loop split repeated 2 timed (for x and y points) to preserve cache locality */
          prev_x = 0;
          last = ofs;

          /* optimization: skip unwanted datasets, if no dc no need to detect sweep variable wraps */
          if(dataset >= 0 && strcmp(xctx->raw->sim_type, "dc") && dataset != sweepvar_wrap) goto done;
          for(p = ofs ; p < ofs_end; p++) {
            double xxprevious, xxfollowing;

            if(gr->logx) xx = mylog10(gv[p]);
            else  xx = gv[p];

            xxprevious = xxfollowing = xx;
            /* do not use sweep variable for wrap detection. sweep variables other that simulation sweep var
             * are simulated and thos no equality test can be done, and any "approx equal" test si going
             * to do unexpected things (liek in simulations with very dense steps) */
            if(p == ofs) xx0 = gv0[p]; /* gv[p];*/
            wrap = xctx->raw->sim_type && !strcmp(xctx->raw->sim_type, "dc") && cnt > 1 && gv0[p] == xx0;
            #if 1 /* plot one point before start and one point after end so
                   * waves will extend to whole graph area even if there are few points
                   * but NOT if we are about to wrap (missing 1st/last point in 2-var dc sweeps) */
            if(!wrap && p > ofs) {
              if(gr->logx) xxprevious = mylog10(gv[p - 1]);
              else  xxprevious = gv[p - 1];
            }
            /*                    .................<-- next point will not wrap.  */
            if(p < ofs_end - 1 && gv[p + 1] != xx0) {
              if(gr->logx) xxfollowing = mylog10(gv[p + 1]);
              else  xxfollowing = gv[p + 1];
            }
            #endif
            /* comment dbg() calls since we are in a deep, deep nested loop */
            /* dbg(1, "draw_graph(): wrap=%d, xx=%g, xx0=%g, p=%d\n", wrap, xx, xx0, p); */

            /* if gr->mode == 2 (HistH) don't wrap */
            if((gr->mode != 2) && first != -1) { /* there is something to plot ... */
              /* ... and we ran out of graph area ... */
              /* ... or sweep variable changed direction */
              if(xxprevious > end || xxfollowing < start || wrap) {
                if(dataset == -1 || dataset == sweepvar_wrap) {
                  /* plot graph */
                  if(gr->rainbow) wave_color = 4 + (wc - 4 + sweepvar_wrap) % (cadlayers - 4);
                  else wave_color = wc;
                  if(bus_msb) {
                    if(digital) {
                       draw_graph_bus_points(ntok_copy, n_bits, idx_arr, first, last, wave_color,
                                    sweep_idx, wcnt, n_nodes, gr, ct);
                    }
                  } else {
                    if(expression) idx = plot_raw_custom_data(sweep_idx, first, last, express, NULL);
                    draw_graph_points(idx, first, last, point, wave_color, wcnt, n_nodes, gr, ct);
                  }
                }
                poly_npoints = 0;
                first = -1;
              }
            }
            if(wrap) {
               sweepvar_wrap++;
               cnt = 0;
            }
            /* for HistH get all points */
            if((gr->mode == 2) || (xxfollowing >= start && xxprevious <= end)) {
              if(first == -1) first = p;
              /* Build poly x array. Translate from graph coordinates to screen coords */
              point[poly_npoints].x = (short)CLIP(S_X(xx), -30000, 30000);
              if(dataset == -1 || dataset == sweepvar_wrap) {
                /* cursor1: show measurements on nodes in graph */
                if(flags & 2 && measure_p == -1 && cnt) {
                  double curs1;

                  curs1 = cursor1;
                  if(gr->logx) curs1 = mylog10(cursor1);
                  if(XSIGN(xx - curs1) != XSIGN(prev_x - curs1)) {
                    measure_p = p;
                    measure_x = xx;
                    measure_prev_x = prev_x;
                  }
                } /* if(flags & 2 && measure_p == -1 && cnt) */
              } /* if(dataset == -1 || dataset == sweepvar_wrap) */
              last = p;
              poly_npoints++;
              ++cnt;
            } /* if(xx >= start && xx <= end) */
            prev_x = xx;
          } /* for(p = ofs ; p < ofs + xctx->raw->npoints[dset]; p++) */


          if(first != -1) {
            if(dataset == -1 || dataset == sweepvar_wrap) {
              /* plot graph. Bus bundles are not plotted if graph is not digital.*/
              if(gr->rainbow) wave_color = 4 + (wc - 4 + sweepvar_wrap) % (cadlayers - 4);
              else wave_color = wc;
              if(bus_msb) {
                if(digital) {
                  draw_graph_bus_points(ntok_copy, n_bits, idx_arr, first, last, wave_color,
                               sweep_idx, wcnt, n_nodes, gr, ct);
                }
              } else {
                if(expression) idx = plot_raw_custom_data(sweep_idx, first, last, express, NULL);
                draw_graph_points(idx, first, last, point, wave_color, wcnt, n_nodes, gr, ct);
              }
            }
          }

          done:

          /* offset pointing to next dataset */
          ofs = ofs_end;
          sweepvar_wrap++;
        } /* for(dset...) */
        bbox(END, 0.0, 0.0, 0.0, 0.0);
        if(sch_waves_loaded()!= -1 && flags & 2 && measure_p != -1)
           show_node_measures(measure_p, measure_x, measure_prev_x, bus_msb, wave_color,
              idx, idx_arr, n_bits, n_nodes, ntok_copy, wcnt, gr, r, cursor1);

        my_free(_ALLOC_ID_, &point);
        if(idx_arr) my_free(_ALLOC_ID_, &idx_arr);
      } /* if( expression || (idx = get_raw_index(bus_msb ? bus_msb : express, NULL)) != -1 ) */
      ++wcnt;
      if(bus_msb) my_free(_ALLOC_ID_, &bus_msb);
      if(sch_waves_loaded()!= -1 && save_npoints != -1) { /* restore multiple OP points from artificial dc sweep */
        xctx->raw->datasets = save_datasets;
        xctx->raw->npoints[0] = save_npoints;
      }
      if(save_extra_idx != -1 && save_extra_idx != xctx->extra_idx) {
        my_snprintf(str_extra_idx, S(str_extra_idx), "%d", save_extra_idx);
        extra_rawfile(2, str_extra_idx, NULL, -1.0, -1.0);
      }

    } /* while( (ntok = my_strtok_r(nptr, "\n\t ", "", 0, &saven)) ) */
    node_db_prev_restore(save_prev_idx);
    if(ntok_copy) my_free(_ALLOC_ID_, &ntok_copy);
    if(express) my_free(_ALLOC_ID_, &express);
    /* if(sch_waves_loaded()!= -1 && custom_rawfile[0]) extra_rawfile(5, NULL, NULL, -1.0, -1.0); */
    my_free(_ALLOC_ID_, &custom_rawfile);
    my_free(_ALLOC_ID_, &sim_type);
    my_free(_ALLOC_ID_, &node);
    my_free(_ALLOC_ID_, &color);
    my_free(_ALLOC_ID_, &sweep);
  } /* if(flags & 8) */
  
  if(flags & 8) {
    bbox(START, 0.0, 0.0, 0.0, 0.0);
    bbox(ADD, gr->rx1, gr->ry1, gr->rx2, gr->ry2);
    bbox(SET_INSIDE, 0.0, 0.0, 0.0, 0.0);
    /* cursor1 */
    if((flags & 2)) draw_cursor(cursor1, cursor2, 1, gr);
    /* cursor2 */
    if((flags & 4)) draw_cursor(cursor2, cursor1, 3, gr);
    /* difference between cursors */
    if((flags & 2) && (flags & 4)) draw_cursor_difference(cursor1, cursor2, gr);
    /* difference between hcursors */
    if((flags & 128) && (flags & 256)) draw_hcursor_difference(gr->hcursor1_y, gr->hcursor2_y, gr);
    /* hcursor1 */
    if(flags & 128) draw_hcursor(gr->hcursor1_y, 15, gr);
    /* hcursor2 */
    if(flags & 256) draw_hcursor(gr->hcursor2_y, 19, gr);
    bbox(END, 0.0, 0.0, 0.0, 0.0);
  }
  /* Waveform markers (doc/claude/specs/graph_markers.md). Painted here, LAST of
   * the content, so they sit on top of traces, legend and cursors, and before
   * the flags-bit-16 UI chrome and the final buffer copy.
   *
   * Gated on bit 8 (CONTENT), never bit 16: markers are user annotations and
   * must appear in SVG/PNG export, unlike the active-strip marker and the
   * reorder grip below.
   *
   * The cheap token test comes FIRST: draw_graph_all loops every graph rect on
   * every redraw, and bbox(SET_INSIDE) reprograms the X clip mask across the
   * whole GC set. A separate bbox scope is used rather than appending to the
   * cursor block above because markers must be paintable independently of the
   * cursor flags -- and bbox(START) is not re-entrant (a nested START pops a
   * modal Tcl alert on every redraw), hence strictly after the bbox(END). */
  if((flags & 8) && get_tok_value(r->prop_ptr, "markers", 0)[0]) {
    bbox(START, 0.0, 0.0, 0.0, 0.0);
    bbox(ADD, gr->rx1, gr->ry1, gr->rx2, gr->ry2);
    bbox(SET_INSIDE, 0.0, 0.0, 0.0, 0.0);
    draw_graph_markers(i, r, gr);
    bbox(END, 0.0, 0.0, 0.0, 0.0);
  }
  /* issue 0151: ASE waveform viewer ACTIVE-STRIP marker — a solid dull-yellow
   * bar down the right edge of the target strip, full container height. Only
   * the viewer ever writes the `active` prop token (wviewer::graph_props), and
   * only while more than one strip is up, so ordinary schematic graphs are
   * untouched. flags bit 16 = "on-screen draw": set by draw_graph_all and by
   * the interactive partial-redraw callers, NOT by the SVG/PS export callers —
   * a printed schematic must not carry a UI marker. Drawn here, inside
   * draw_graph, because every partial graph repaint starts by refilling the
   * whole container box (draw_graph_grid), which would erase anything painted
   * from outside. */
  if((flags & 16) && gr->active && has_x) {
    double bx1, by1, bx2, by2;
    int w = tclgetintvar("graph_active_strip_width");
    dbg(1, "draw_graph(): active-strip marker on graph %d\n", i);
    if(w <= 0) w = 5;
    bx2 = gr->sx2;
    bx1 = gr->sx2 - w;
    by1 = gr->sy1;
    by2 = gr->sy2;
    /* screen-space clip: the GC has no clip mask, and 16-bit X coordinate
     * fields wrap on huge off-screen values (draw_hilight_dot's lesson) */
    if(rectclip(xctx->areax1, xctx->areay1, xctx->areax2, xctx->areay2,
                &bx1, &by1, &bx2, &by2)) {
      if(xctx->draw_window)
        XFillRectangle(display, xctx->window, xctx->gc_graph_active,
          (int)bx1, (int)by1, (unsigned int)(bx2 - bx1), (unsigned int)(by2 - by1));
      if(xctx->draw_pixmap)
        XFillRectangle(display, xctx->save_pixmap, xctx->gc_graph_active,
          (int)bx1, (int)by1, (unsigned int)(bx2 - bx1), (unsigned int)(by2 - by1));
    }
  }
  /* Strip drag-reorder affordance (ASE waveform viewer only — the
   * `reorder_handle` prop token is written by wviewer::graph_props and by
   * nothing else). Same on-screen gate as the active-strip marker above:
   * flags bit 16, so SVG/PS/PNG export never carries it.
   *   >=1 : the GRIP — three short bars in the strip's right margin, the
   *         discoverable "grab me to move this strip" target. Its hit zone is
   *         GRAPH_REORDER_HANDLE_W screen pixels wide (mirrored in Tcl).
   *   ==2 : plus a drop bar along the strip's TOP edge    (drag going up)
   *   ==3 : plus a drop bar along the strip's BOTTOM edge (drag going down)
   *   ==4 : plus a FRAME around the whole strip — the destination of a trace
   *         being dragged out of another strip (the whole strip is the target
   *         there, not one of its edges, so the feedback is a frame not a bar)
   * 2/3/4 are transient drag feedback: Tcl rewrites the token on the affected
   * rects when the prospective destination changes (never on every Motion) and
   * clears it on commit/cancel. */
  if((flags & 16) && gr->reorder_handle && has_x) {
    double hx1, hy1, hx2, hy2;
    double cy = (gr->sy1 + gr->sy2) / 2.0;
    int k;
    /* grip bars: 8 px wide, 2 px thick, 4 px pitch, left of the 5 px active
     * marker so the two never overlap on the target strip */
    for(k = -1; k <= 1; k++) {
      hx1 = gr->sx2 - GRAPH_REORDER_HANDLE_W + 1;
      hx2 = hx1 + 8;
      hy1 = cy + k * 4 - 1;
      hy2 = hy1 + 2;
      if(rectclip(xctx->areax1, xctx->areay1, xctx->areax2, xctx->areay2,
                  &hx1, &hy1, &hx2, &hy2)) {
        if(xctx->draw_window)
          XFillRectangle(display, xctx->window, xctx->gc[GRIDLAYER],
            (int)hx1, (int)hy1, (unsigned int)(hx2 - hx1), (unsigned int)(hy2 - hy1));
        if(xctx->draw_pixmap)
          XFillRectangle(display, xctx->save_pixmap, xctx->gc[GRIDLAYER],
            (int)hx1, (int)hy1, (unsigned int)(hx2 - hx1), (unsigned int)(hy2 - hy1));
      }
    }
    if(gr->reorder_handle == 2 || gr->reorder_handle == 3) {
      hx1 = gr->sx1;
      hx2 = gr->sx2;
      if(gr->reorder_handle == 2) { hy1 = gr->sy1; hy2 = gr->sy1 + GRAPH_REORDER_DROPBAR_H; }
      else                        { hy1 = gr->sy2 - GRAPH_REORDER_DROPBAR_H; hy2 = gr->sy2; }
      if(rectclip(xctx->areax1, xctx->areay1, xctx->areax2, xctx->areay2,
                  &hx1, &hy1, &hx2, &hy2)) {
        if(xctx->draw_window)
          XFillRectangle(display, xctx->window, xctx->gc_graph_active,
            (int)hx1, (int)hy1, (unsigned int)(hx2 - hx1), (unsigned int)(hy2 - hy1));
        if(xctx->draw_pixmap)
          XFillRectangle(display, xctx->save_pixmap, xctx->gc_graph_active,
            (int)hx1, (int)hy1, (unsigned int)(hx2 - hx1), (unsigned int)(hy2 - hy1));
      }
    }
    if(gr->reorder_handle == 4) {
      /* four filled bars, not an XDrawRectangle: the GC line width is shared
       * state and a frame drawn as four fills clips like everything else here */
      int e;
      for(e = 0; e < 4; e++) {
        switch(e) {
          case 0: hx1 = gr->sx1; hx2 = gr->sx2;
                  hy1 = gr->sy1; hy2 = gr->sy1 + GRAPH_TRACE_DROP_W; break;
          case 1: hx1 = gr->sx1; hx2 = gr->sx2;
                  hy1 = gr->sy2 - GRAPH_TRACE_DROP_W; hy2 = gr->sy2; break;
          case 2: hx1 = gr->sx1; hx2 = gr->sx1 + GRAPH_TRACE_DROP_W;
                  hy1 = gr->sy1; hy2 = gr->sy2; break;
          default: hx1 = gr->sx2 - GRAPH_TRACE_DROP_W; hx2 = gr->sx2;
                  hy1 = gr->sy1; hy2 = gr->sy2; break;
        }
        if(rectclip(xctx->areax1, xctx->areay1, xctx->areax2, xctx->areay2,
                    &hx1, &hy1, &hx2, &hy2)) {
          if(xctx->draw_window)
            XFillRectangle(display, xctx->window, xctx->gc_graph_active,
              (int)hx1, (int)hy1, (unsigned int)(hx2 - hx1), (unsigned int)(hy2 - hy1));
          if(xctx->draw_pixmap)
            XFillRectangle(display, xctx->save_pixmap, xctx->gc_graph_active,
              (int)hx1, (int)hy1, (unsigned int)(hx2 - hx1), (unsigned int)(hy2 - hy1));
        }
      }
    }
  }
  if(flags & 1) { /* copy save buffer to screen */
    if(!xctx->draw_window) {
      /*
       * MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0], xctx->xrect[0].x, xctx->xrect[0].y,
       *   xctx->xrect[0].width, xctx->xrect[0].height, xctx->xrect[0].x, xctx->xrect[0].y);
       */
      MyXCopyAreaDouble(display, xctx->save_pixmap, xctx->window, xctx->gc[0],
        gr->rx1, gr->ry1, gr->rx2, gr->ry2, gr->rx1, gr->ry1, 0.0);

    }
  }
}

/* flags:
 * see draw_graph()
 */
static void draw_graph_all(int flags)
{
  int  i, sch_loaded, hide_graphs;
  int bbox_set = 0;
  int save_bbx1 = 0, save_bby1 = 0, save_bbx2 = 0, save_bby2 = 0;
  dbg(1, "draw_graph_all(): flags=%d\n", flags);
  /* save bbox data, since draw_graph_all() is called from draw() which may be called after a bbox(SET) */
  sch_loaded = (sch_waves_loaded() >= 0);
  dbg(1, "draw_graph_all(): sch_loaded=%d\n", sch_loaded);
  hide_graphs =  tclgetboolvar("hide_empty_graphs");
  if(sch_loaded || !hide_graphs) {
    if(xctx->bbox_set) {
      bbox_set = 1;
      save_bbx1 = xctx->bbx1;
      save_bby1 = xctx->bby1;
      save_bbx2 = xctx->bbx2;
      save_bby2 = xctx->bby2;
      bbox(END, 0.0, 0.0, 0.0, 0.0);
    }
    #if HAS_CAIRO==1
    cairo_save(xctx->cairo_ctx);
    cairo_save(xctx->cairo_save_ctx);
    xctx->cairo_font =
          cairo_toy_font_face_create("Sans-Serif", CAIRO_FONT_SLANT_NORMAL, CAIRO_FONT_WEIGHT_NORMAL);
    cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
    cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
    cairo_font_face_destroy(xctx->cairo_font);
    #endif
    if(xctx->draw_single_layer==-1 || GRIDLAYER == xctx->draw_single_layer) {
      if(xctx->enable_layer[GRIDLAYER]) for(i = 0; i < xctx->rects[GRIDLAYER]; ++i) {
        xRect *r = &xctx->rect[GRIDLAYER][i];
        if(r->flags & 1) {
          int flags2;
          setup_graph_data(i, 0, &xctx->graph_struct);
          flags2 = flags | (xctx->graph_flags & (128 | 256)); /* include drawing hcursors if enabled */
          draw_graph(i, flags2, &xctx->graph_struct, NULL); /* draw data in each graph box */
        }
      }
    }
    #if HAS_CAIRO==1
    cairo_restore(xctx->cairo_ctx);
    cairo_restore(xctx->cairo_save_ctx);
    #endif
    /* restore previous bbox */
    if(bbox_set) {
      xctx->bbx1 = save_bbx1;
      xctx->bby1 = save_bby1;
      xctx->bbx2 = save_bbx2;
      xctx->bby2 = save_bby2;
      xctx->bbox_set = 1;
      bbox(SET, 0.0, 0.0, 0.0, 0.0);
    }
  }
}

#if HAS_CAIRO==1
cairo_status_t png_reader(void *in_closure, unsigned char *out_data, unsigned int length)
{
  png_to_byte_closure_t *closure = (png_to_byte_closure_t *) in_closure;
  if(!closure->buffer) return CAIRO_STATUS_READ_ERROR;
  memcpy(out_data, closure->buffer + closure->pos, length);
  closure->pos += length;
  return CAIRO_STATUS_SUCCESS;
}

cairo_status_t png_writer(void *in_closure, const unsigned char *in_data, unsigned int length)
{
  png_to_byte_closure_t *closure = (png_to_byte_closure_t *) in_closure;
  if(!in_data) return CAIRO_STATUS_WRITE_ERROR;
  if(closure->pos + length > closure->size) {
    my_realloc(_ALLOC_ID_, &closure->buffer, closure->pos + length + 65536);
    closure->size =  closure->pos + length + 65536;
  }
  memcpy(closure->buffer + closure->pos, in_data, length);
  closure->pos += length;
  return CAIRO_STATUS_SUCCESS;
}
#endif

/*
 * The memmem() function finds the start of the first occurrence of the
 * substring 'needle' of length 'nlen' in the memory area 'haystack' of
 * length 'hlen'.
 *
 * The return value is a pointer to the beginning of the sub-string, or
 * NULL if the substring is not found.
 */
void *my_memmem(const void *haystack, size_t hlen, const void *needle, size_t nlen)
{
    int needle_first;
    const char *p = haystack;
    size_t plen = hlen;

    if (!nlen) return NULL;
    needle_first = *(unsigned char *)needle;

    while (plen >= nlen && (p = memchr(p, needle_first, plen - nlen + 1)))
    {
        if (!memcmp(p, needle, nlen)) return (void *)p;
        p++;
        plen = hlen - (p - (char *)haystack);
    }
    return NULL;
}

#if HAS_CAIRO==1
/* what:
 *    1: invert colors
 *    2: set white to transparent
 *    4: set black to transparent
 *    8: set transparent to white
 *   16: set transparent to black
 *   32: blend with white, remove alpha
 *   64: blend with black, remove alpha
 *  256: write back into `image_data` attribute
 */
int edit_image(int what, xRect *r)
{
  cairo_t *ct;
  unsigned char *data;
  cairo_surface_t *newsfc;
  cairo_format_t format;
  int jpg, size_x, size_y, stride, x, y;
  xEmb_image *emb_ptr = r->extraptr;
  cairo_surface_t **surface;
  const char *attr;

  if(!emb_ptr || !emb_ptr->image) return 0;
  attr = get_tok_value(r->prop_ptr, "image_data", 0);
  surface = &emb_ptr->image;
  cairo_surface_flush(*surface);
  if(attr[0]) {
    if(!strncmp(attr, "/9j/", 4)) jpg = 1;
    else if(!strncmp(attr, "iVBOR", 5)) jpg = 0;
    else jpg = -1; /* some invalid data */
  } else {
   jpg = -1;
  }
  if(jpg == -1) return 0;
  format = cairo_image_surface_get_format(*surface);
  size_x = cairo_image_surface_get_width(*surface);
  size_y = cairo_image_surface_get_height(*surface);
  stride = cairo_image_surface_get_stride(*surface);
  /* add alpha channel if missing */
  if(format != CAIRO_FORMAT_ARGB32) {
    newsfc = cairo_surface_create_similar_image(*surface, CAIRO_FORMAT_ARGB32, size_x, size_y);
    ct = cairo_create(newsfc);
    cairo_set_source_surface(ct, *surface, 0, 0);
    cairo_set_operator(ct, CAIRO_OPERATOR_SOURCE);
    cairo_paint(ct);
    cairo_destroy(ct);
    cairo_surface_destroy(*surface);
    *surface = newsfc;
  }
  data = cairo_image_surface_get_data(*surface);
  for(x = 0; x < size_x; x++) {
    for(y = 0; y < size_y; y++) {
      unsigned char *ptr = data + y * stride + x * 4;
      unsigned char a = ptr[3];
      unsigned char r = ptr[2];
      unsigned char g = ptr[1];
      unsigned char b = ptr[0];

      /* invert colors */
      if(what & 1) {
        r = a - r;
        g = a - g;
        b = a - b;
      }

      /* set white to transparent */
      if(what & 2) {
        if(r > 242  && g > 242 && b >242) {r = g = b = a = 0;}
      }

      /* set black to transparent */
      if(what & 4) {
        if(r < 13 && g < 13 && b < 13) {r = g = b = a = 0;}
      }

      /* set transparent to white */
      if(what & 8) {
        if(a == 0) {r = g = b = a = 0xff;}
      }

      /* set transparent to black */
      if(what & 16) {
        if(a == 0) {r = g = b = 0x00; a = 0xff;}
      }

      /* remove alpha, blend with white */
      if(what & 32) {
        r += (unsigned char)(0xff - a);
        g += (unsigned char)(0xff - a);
        b += (unsigned char)(0xff - a);
        a  = (unsigned char)0xff;
      }

      /* remove alpha, blend with black */
      if(what & 64) {
        a  = (unsigned char)0xff;
      }

      /* write result back */
      ptr[3] = a;
      ptr[2] = r;
      ptr[1] = g;
      ptr[0] = b;
    }
  }
  cairo_surface_mark_dirty(*surface);

  /* write back modified image to image_data attribute */
  if(what & 256) {
    char *encoded_data = NULL;
    size_t olength;
    png_to_byte_closure_t closure;
    if(jpg == 0) {
      /* write PNG to in-memory buffer */
      closure.buffer = NULL;
      closure.size = 0;
      closure.pos = 0;
      cairo_surface_write_to_png_stream(emb_ptr->image, png_writer, &closure);
      closure.size = closure.pos;
    } else if(jpg == 1) {
      /* write JPG to in-memory buffer */
      #if defined(HAS_LIBJPEG)
      int jpeg_quality;
      const char *ptr;
      ptr = get_tok_value(r->prop_ptr, "jpeg_quality", 0);
      jpeg_quality = 75;
      if(ptr[0]) jpeg_quality = atoi(ptr);
      closure.buffer = NULL;
      closure.size = 0;
      closure.pos = 0;
      cairo_image_surface_write_to_jpeg_mem(emb_ptr->image, &closure.buffer, &closure.pos, jpeg_quality);
      closure.size = closure.pos;
      #endif
    }

    /* put base64 encoded data to rect image_data attribute */
    encoded_data = base64_encode((unsigned char *)closure.buffer, closure.size, &olength, 0);
    my_strdup2(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "image_data", encoded_data));
    my_free(_ALLOC_ID_, &closure.buffer);
    my_free(_ALLOC_ID_, &encoded_data);
  }
  dbg(1, "size_x = %d, size_y = %d, stride = %d\n", size_x, size_y, stride);
  return 1;
}

/* returns a cairo surface.
 * `filename` should be a  png or jpeg image or anything else that can be converted to png
 * or jpeg via a `filter` pipeline. (example: filter="gm convert - png:-")
 * buffer returns the content of filename or the filtered result if filter is given.
 *  `size` is set to the size of the returned data */
static cairo_surface_t *get_surface_from_file(const char *filename, const char *filter,
                        unsigned char **buffer, size_t *size)
{
  int jpg = 0;
  png_to_byte_closure_t closure = {NULL, 0L, 0L};
  size_t filesize = 0;
  char *filedata = NULL;
  FILE *fd;
  struct stat buf;
  int svg = 0;
  cairo_surface_t *surface = NULL;
  *buffer = NULL;
  *size = 0;
  if(filename && filename[0]) {
    if(stat(filename, &buf)) {
      dbg(0, "get_surface_from_file(): file %s not found.\n", filename);
      return NULL;
    }
    filesize = (size_t)buf.st_size;
    if(filesize > 0) {
      fd = my_fopen(filename, fopen_read_mode);
      if(fd) {
        size_t bytes_read;
        filedata = my_malloc(_ALLOC_ID_, filesize);
        if((bytes_read = fread(filedata, 1, filesize, fd)) < filesize) {
          filesize = bytes_read;
          dbg(0, "get_surface_from_file(): less bytes read than expected from %s, got %ld bytes\n",
              filename, bytes_read);
        }
        fclose(fd);
      }
    } else {
      dbg(0, "get_surface_from_file(): file %s has zero size\n", filename);
      return NULL;
    }
    if(filedata && my_memmem(filedata, filesize, "<svg", 4) &&
       my_memmem(filedata, filesize, "xmlns", 5)) {
      if(filter) svg = 1;
      else {
        dbg(0, "get_surface_from_file():\n");
        dbg(0, "  A SVG file is specified but no 'filter' attribute to convert to png was given\n");
        dbg(0, "  May be no 'svg_to_png' variable was specified in xschemrc\n");
        my_free(_ALLOC_ID_, &filedata);
        return NULL;
      }
    }
  } /* if(filename...) */
  if(filter) {
    size_t filtered_img_size = 0;
    char *filtered_img_data = NULL;
    filter_data(filedata, filesize, &filtered_img_data, &filtered_img_size, filter);
    if(!svg) my_free(_ALLOC_ID_, &filedata);
    closure.buffer = (unsigned char *)filtered_img_data;
    closure.size = filtered_img_size;
    closure.pos = 0;
  } else { /* no filter attribute */
    closure.buffer = (unsigned char *)filedata;
    filedata = NULL;
    closure.size = filesize;
    closure.pos = 0;
  }

  if(closure.size > 4) {
    if(!strncmp((char *)closure.buffer, "\x89PNG", 4)) jpg = 0;
    else if(!strncmp((char *)closure.buffer, "\xFF\xD8\xFF", 3)) jpg = 1;
    else jpg = -1;
  } else {
    jpg = -1;
  }
  if(closure.buffer) {
    if(jpg == 0) {
      surface = cairo_image_surface_create_from_png_stream(png_reader, &closure);
    } else if(jpg == 1) {
      #if defined(HAS_LIBJPEG)
      surface = cairo_image_surface_create_from_jpeg_mem(closure.buffer, closure.size);
      #endif
    }
    if(!surface || cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
      if(jpg != 1) dbg(0, "get_surface_from_file(): failure creating image surface from %s\n", filename);
      if(surface) cairo_surface_destroy(surface);
      my_free(_ALLOC_ID_, &closure.buffer);
      *buffer = NULL;
      *size = 0;
      return NULL;
    }
  }
  if(svg) { /* if the file type is SVG return in buffer the plain file,
             * not the filtered content, This way we don't lose resolution */
    *buffer = (unsigned char *)filedata;
    *size = filesize;
    my_free(_ALLOC_ID_, &closure.buffer);
  } else {
    *buffer = closure.buffer;
    *size = closure.size;
  }
  return surface;
}

static cairo_surface_t *get_surface_from_b64data(const char *attr, size_t attr_len, const char *filter)
{
  int jpg = -1; /* 0: png, 1: jpg, 2: svg, -1: invalid data */
  png_to_byte_closure_t closure;
  size_t data_size;
  cairo_surface_t *surface = NULL;

  closure.buffer = base64_decode(attr, attr_len, &data_size);
  closure.pos = 0;
  closure.size = data_size; /* should not be necessary */

  if(!strncmp(attr, "/9j/", 4)) jpg = 1; /* jpg */
  else if(!strncmp(attr, "iVBOR", 5)) jpg = 0; /* png */
  else if(my_memmem(closure.buffer, closure.size, "<svg", 4) &&
          my_memmem(closure.buffer, closure.size, "xmlns", 5)) {
    if(filter) jpg = 2; /* svg */
  }
  else jpg = -1; /* some invalid data */

  if(jpg == -1) {
    my_free(_ALLOC_ID_, &closure.buffer);
    return NULL;
  }

  if(closure.buffer == NULL) {
    dbg(0, "get_surface_from_b64data(): decoding base64 data for image failed\n");
    return NULL;
  }

  if(jpg == 0) { /* png */
    surface = cairo_image_surface_create_from_png_stream(png_reader, &closure);
  } else if(jpg == 1) { /* jpg */
    #if defined(HAS_LIBJPEG)
    surface = cairo_image_surface_create_from_jpeg_mem(closure.buffer, closure.size);
    #endif
  } else if(jpg == 2) { /* svg */
    size_t filtered_img_size = 0;
    char *filtered_img_data = NULL;
    int ret =
      filter_data((char *)closure.buffer, closure.size, &filtered_img_data, &filtered_img_size, filter);
    my_free(_ALLOC_ID_, &closure.buffer);
    closure.buffer = (unsigned char *)filtered_img_data;
    closure.size = filtered_img_size;
    closure.pos = 0;
    if(!ret) {
      surface = cairo_image_surface_create_from_png_stream(png_reader, &closure);
    } else {
      surface = NULL;
      if(closure.buffer) my_free(_ALLOC_ID_, &closure.buffer);
      return NULL;;
    }
  }
  if(!surface || cairo_surface_status(surface) != CAIRO_STATUS_SUCCESS) {
    dbg(0, "get_surface_from_b64data(): failure creating image surface from \"image_data\" attribute\n");
    if(surface) cairo_surface_destroy(surface);
    surface = NULL;
  }
  my_free(_ALLOC_ID_, &closure.buffer);
  return surface;
}
#endif /* HAS_CAIRO==1 */

/* rot and flip for rotated / flipped symbols
 * dr: 1 draw image
 *     0 only load image and build base64
 */
int draw_image(int dr, xRect *r, double *x1, double *y1, double *x2, double *y2, int rot, int flip)
{
  #if HAS_CAIRO==1
  const char *ptr;
  int w,h;
  double x, y, rw, rh;
  double sx1, sy1, sx2, sy2, alpha;
  char filename[PATH_MAX];
  const char *attr ;
  double xx1, yy1, scalex, scaley;
  xEmb_image *emb_ptr;
  size_t attr_len;
  char *filter = NULL;

  if(xctx->only_probes) return 0;
  xx1 = *x1; yy1 = *y1; /* image anchor point */
  RECTORDER(*x1, *y1, *x2, *y2);

  /* screen position */
  sx1=X_TO_SCREEN(*x1);
  sy1=Y_TO_SCREEN(*y1);
  sx2=X_TO_SCREEN(*x2);
  sy2=Y_TO_SCREEN(*y2);
  if(RECT_OUTSIDE(sx1, sy1, sx2, sy2,
                  xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2)) return 0;
  set_rect_extraptr(1, r); /* create r->extraptr pointing to a xEmb_image struct */
  emb_ptr = r->extraptr;
  my_strncpy(filename, get_tok_value(r->prop_ptr, "image", 0), S(filename));
  my_strdup(_ALLOC_ID_, &filter, get_tok_value(r->prop_ptr, "filter", 0));
  /******* read image from in-memory buffer ... *******/
  if(emb_ptr && emb_ptr->image) {
     /* nothing to do, image is already created */
  /******* ... or read PNG from image_data attribute *******/
  } else if( (attr = get_tok_value(r->prop_ptr, "image_data", 0))[0] && (attr_len = strlen(attr)) > 5) {
    emb_ptr->image = get_surface_from_b64data(attr, attr_len, filter);
    if(!emb_ptr->image) {
      my_free(_ALLOC_ID_, &filter);
      return 0;
    }
  /******* ... or read PNG from file (image attribute) *******/
  } else if(filename[0] || (filter && filter[0])) {
    unsigned char *buffer = NULL;
    size_t size = 0;
    char *encoded_data = NULL;
    size_t olength;

    /* if filename is a SVG file buffer will be the plain svg file content, not the filtered data */
    emb_ptr->image = get_surface_from_file(filename, filter, &buffer, &size);
    if(!emb_ptr->image) {
      my_free(_ALLOC_ID_, &filter);
      return 0;
    }
    /* put base64 encoded data to rect image_data attribute */
    encoded_data = base64_encode((unsigned char *)buffer, size, &olength, 0);
    my_strdup2(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "image_data", encoded_data));
    my_free(_ALLOC_ID_, &encoded_data);
    my_free(_ALLOC_ID_, &buffer);
  } else { /* no emb_ptr->image and no "image_data" attribute */
    return 0;
  }
  ptr = get_tok_value(r->prop_ptr, "alpha", 0);
  alpha = 1.0;
  if(ptr[0]) alpha = atof(ptr);
  w = cairo_image_surface_get_width (emb_ptr->image);
  h = cairo_image_surface_get_height (emb_ptr->image);
  dbg(1, "draw_image() w=%d, h=%d\n", w, h);
  x = X_TO_SCREEN(xx1);
  y = Y_TO_SCREEN(yy1);
  dbg(1, "draw_image() x=%g, y=%g\n", x, y);
  if(r->flags & 2048) { /* resize container rectangle to fit image */
    *x2 = *x1 + w;
    *y2 = *y1 + h;
    scalex = xctx->mooz;
    scaley = xctx->mooz;
  } else { /* resize image to fit in rectangle */
    rw = abs((int)(*x2 - *x1));
    rh = abs((int)(*y2 - *y1));
    if (rot == 1 || rot == 3)
    {
      scalex = rh/w * xctx->mooz;
      scaley = rw/h * xctx->mooz;
    }else
    {
      scalex = rw/w * xctx->mooz;
      scaley = rh/h * xctx->mooz;
    }
  }
  dbg(1, "draw_image() : rectangle coords: %g %g %g %g\n", *x1, *y1, *x2, *y2);
  if(dr) {
    cairo_save(xctx->cairo_ctx);
    cairo_save(xctx->cairo_save_ctx);
  }
  if(dr && xctx->draw_pixmap) {
    cairo_translate(xctx->cairo_save_ctx, x, y);
    cairo_rotate(xctx->cairo_save_ctx, rot * XSCH_PI * 0.5);
    if(flip && (rot == 0 || rot == 2)) cairo_scale(xctx->cairo_save_ctx, -scalex, scaley);
    else if(flip && (rot == 1 || rot == 3)) cairo_scale(xctx->cairo_save_ctx, -scalex, scaley);
    else cairo_scale(xctx->cairo_save_ctx, scalex, scaley);

    cairo_set_source_surface(xctx->cairo_save_ctx, emb_ptr->image, 0. , 0.);
    cairo_rectangle(xctx->cairo_save_ctx, 0, 0, w , h );
    /* cairo_fill(xctx->cairo_save_ctx);
     * cairo_stroke(xctx->cairo_save_ctx); */
    cairo_clip(xctx->cairo_save_ctx);
    cairo_paint_with_alpha(xctx->cairo_save_ctx, alpha);
    cairo_surface_flush(xctx->cairo_save_sfc);
  }
  if(dr && xctx->draw_window) {
    cairo_translate(xctx->cairo_ctx, x, y);
    cairo_rotate(xctx->cairo_ctx, rot * XSCH_PI * 0.5);
    if(flip && (rot == 0 || rot == 2)) cairo_scale(xctx->cairo_ctx, -scalex, scaley);
    else if(flip && (rot == 1 || rot == 3)) cairo_scale(xctx->cairo_ctx, -scalex, scaley);
    else cairo_scale(xctx->cairo_ctx, scalex, scaley);
    cairo_set_source_surface(xctx->cairo_ctx, emb_ptr->image, 0. , 0.);
    cairo_rectangle(xctx->cairo_ctx, 0, 0, w , h );
    /* cairo_fill(xctx->cairo_ctx);
     * cairo_stroke(xctx->cairo_ctx); */
    cairo_clip(xctx->cairo_ctx);
    cairo_paint_with_alpha(xctx->cairo_ctx, alpha);
    cairo_surface_flush(xctx->cairo_sfc);
  }
  if(dr) {
    cairo_restore(xctx->cairo_ctx);
    cairo_restore(xctx->cairo_save_ctx);
  }
  my_free(_ALLOC_ID_, &filter);
  #endif
  return 1;
}

static void draw_images_all(void)
{
  #if HAS_CAIRO==1
  int i;
  if(xctx->draw_single_layer==-1 || GRIDLAYER == xctx->draw_single_layer) {
    if(xctx->enable_layer[GRIDLAYER]) for(i = 0; i < xctx->rects[GRIDLAYER]; ++i) {
      xRect *r = &xctx->rect[GRIDLAYER][i];
      if(r->flags & 1024) {
        draw_image(1, r, &r->x1, &r->y1, &r->x2, &r->y2, 0, 0);
      }
    }
  }
  #endif
}

void svg_embedded_graph(FILE *fd, int i, double rx1, double ry1, double rx2, double ry2)
{
  #ifndef __unix__
  xRect *r = &xctx->rect[GRIDLAYER][i];
  #endif
  #if HAS_CAIRO==1
  Zoom_info zi;
  char *ptr = NULL;
  double x1, y1, x2, y2, w, h, rw, rh, scale;
  char transform[150];
  png_to_byte_closure_t closure;
  cairo_surface_t *png_sfc;
  int save, save_draw_window, save_draw_grid, rwi, rhi;
  size_t olength;
  const double max_size = 2500.0;

  if(!has_x) return;

  /* screen position */
  x1=X_TO_SCREEN(rx1);
  y1=Y_TO_SCREEN(ry1);
  x2=X_TO_SCREEN(rx2);
  y2=Y_TO_SCREEN(ry2);
  if(RECT_OUTSIDE(x1, y1, x2, y2,
                  xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2)) return;

  rw = fabs(rx2 -rx1);
  rh = fabs(ry2 - ry1);
  scale = 3.0;
  if(rw > rh && rw * scale > max_size) {
    scale = max_size / rw;
  } else if(rh * scale > max_size) {
    scale = max_size / rh;
  }
  rwi = (int) (rw * scale + 1.0);
  rhi = (int) (rh * scale + 1.0);
  save_restore_zoom(1, &zi);
  xctx->lw *= scale;
  set_viewport_size(rwi, rhi, xctx->lw);

  /* zoom_box(rx1 - xctx->lw, ry1 - xctx->lw, rx2 + xctx->lw, ry2 + xctx->lw, 1.0); */

  xctx->xorigin = -rx1;
  xctx->yorigin = -ry1;
  xctx->zoom=(rx2-rx1)/(rwi - 1);
  xctx->mooz = 1 / xctx->zoom;

  resetwin(1, 1, 1, rwi, rhi);
  save_draw_grid = tclgetboolvar("draw_grid");
  tclsetvar("draw_grid", "0");
  save_draw_window = xctx->draw_window;
  xctx->draw_window=0;
  xctx->draw_pixmap=1;
  save = xctx->do_copy_area;
  xctx->do_copy_area=0;
  setup_graph_data(i, 0, &xctx->graph_struct);
  draw_graph(i, 8 + (xctx->graph_flags & (4 | 2 | 128 | 256)), &xctx->graph_struct, NULL);

#ifdef __unix__
  png_sfc = cairo_xlib_surface_create(display, xctx->save_pixmap, visual,
               xctx->xrect[0].width, xctx->xrect[0].height);
#else
  /* pixmap doesn't work on windows
       Copy from cairo_save_sfc and use cairo
       to draw in the data points to embed the graph */
    png_sfc = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, xctx->xrect[0].width, xctx->xrect[0].height);
    cairo_t *ct = cairo_create(png_sfc);
    cairo_set_source_surface(ct, xctx->cairo_save_sfc, 0, 0);
    cairo_set_operator(ct, CAIRO_OPERATOR_SOURCE);
    cairo_paint(ct);
    if(r->flags & 1) {
      setup_graph_data(i, 0, &xctx->graph_struct);
      draw_graph(i, 8 + (xctx->graph_flags & (4 | 2 | 128 | 256)), &xctx->graph_struct, (void *)ct);
    }
#endif
  closure.buffer = NULL;
  closure.size = 0;
  closure.pos = 0;
  cairo_surface_write_to_png_stream(png_sfc, png_writer, &closure);
  ptr = base64_encode(closure.buffer, closure.pos, &olength, 1);
  my_free(_ALLOC_ID_, &closure.buffer);
  cairo_surface_destroy(png_sfc);
  xctx->draw_pixmap=1;
  xctx->draw_window=save_draw_window;
  xctx->do_copy_area=save;
  tclsetboolvar("draw_grid", save_draw_grid);
  save_restore_zoom(0, &zi);
  resetwin(1, 1, 1, xctx->xrect[0].width, xctx->xrect[0].height);

  h = fabs(y2 - y1);
  w = fabs(x2 - x1);

  my_snprintf(transform, S(transform), "transform=\"translate(%g,%g)\"", x1, y1);
  if(ptr[0]) {
    fprintf(fd, "<image x=\"%g\" y=\"%g\" width=\"%g\" height=\"%g\" %s "
                "xlink:href=\"data:image/png;base64,%s\"/>\n",
                0.0, 0.0, w, h, transform, ptr);
  }
  my_free(_ALLOC_ID_, &ptr);
  #endif
}

/* ===========================================================================
 * Apply-scope highlight overlay (the white outline on edit targets).
 *
 * A transient overlay holding a set of {type, stable-id} drawable references,
 * stroked with the dedicated high-contrast GC (xctx->gc_scope) by
 * draw_scope_highlight(), which runs at the END of draw() — right after the
 * selection overlay (draw.c) — so it is RE-STROKED on every full redraw while
 * active and survives pan/zoom (decision doc D2). The set is held by STABLE ID
 * so it survives any reindexing while the dialog is open; indices are resolved
 * at draw time. Clearing it is just `scope_hi_n = 0` followed by a redraw — no
 * XOR erase, the canvas rebuilds from the pixmap pixel-identical. The form
 * drives it through the `xschem highlight_scope` / `highlight_objects` commands.
 *
 * The renderer mirrors draw_selection()'s per-type shape dispatch but strokes a
 * white outline and reads its set from the overlay (not sel_array): each type in
 * its NATURAL shape — instances as their (no-text) bounding box, a WIRE as its
 * line segment, etc. Text (pure annotation, never an edit target here) is
 * deferred (its outline needs the font-extent bbox — H3).
 * =========================================================================== */
void clear_scope_highlight(void)
{
  xctx->scope_hi_n = 0;
}

void add_scope_highlight(int type, unsigned int id)
{
  if(xctx->scope_hi_n >= xctx->scope_hi_alloc) {
    xctx->scope_hi_alloc = xctx->scope_hi_alloc ? xctx->scope_hi_alloc * 2 : 16;
    my_realloc(_ALLOC_ID_, &xctx->scope_hi_type, xctx->scope_hi_alloc * sizeof(int));
    my_realloc(_ALLOC_ID_, &xctx->scope_hi_id, xctx->scope_hi_alloc * sizeof(unsigned int));
  }
  xctx->scope_hi_type[xctx->scope_hi_n] = type;
  xctx->scope_hi_id[xctx->scope_hi_n] = id;
  ++xctx->scope_hi_n;
}

void draw_scope_highlight(void)
{
  int k, idx, layer;
  GC g = xctx->gc_scope;

  if(!has_x || xctx->scope_hi_n <= 0) return;
  for(k = 0; k < xctx->scope_hi_n; ++k) {
    unsigned int id = xctx->scope_hi_id[k];
    switch(xctx->scope_hi_type[k]) {
      case ELEMENT:
        idx = inst_index_from_id(id);
        if(idx >= 0) {
          double x1 = xctx->inst[idx].xx1, y1 = xctx->inst[idx].yy1;
          double x2 = xctx->inst[idx].xx2, y2 = xctx->inst[idx].yy2;
          RECTORDER(x1, y1, x2, y2);
          drawtemprect(g, ADD, x1, y1, x2, y2);
        }
        break;
      case WIRE:
        idx = wire_index_from_id(id);
        if(idx >= 0)
          drawtempline(g, ADD, xctx->wire[idx].x1, xctx->wire[idx].y1,
                               xctx->wire[idx].x2, xctx->wire[idx].y2);
        break;
      case xRECT:
        idx = gfx_index_from_id(xRECT, id, &layer);
        if(idx >= 0) {
          double x1 = xctx->rect[layer][idx].x1, y1 = xctx->rect[layer][idx].y1;
          double x2 = xctx->rect[layer][idx].x2, y2 = xctx->rect[layer][idx].y2;
          RECTORDER(x1, y1, x2, y2);
          drawtemprect(g, ADD, x1, y1, x2, y2);
        }
        break;
      case LINE:
        idx = gfx_index_from_id(LINE, id, &layer);
        if(idx >= 0)
          drawtempline(g, ADD, xctx->line[layer][idx].x1, xctx->line[layer][idx].y1,
                               xctx->line[layer][idx].x2, xctx->line[layer][idx].y2);
        break;
      case POLYGON:
        idx = gfx_index_from_id(POLYGON, id, &layer);
        if(idx >= 0) {
          int bezier = 2 + !strboolcmp(
            get_tok_value(xctx->poly[layer][idx].prop_ptr, "bezier", 0), "true");
          drawtemppolygon(g, NOW, xctx->poly[layer][idx].x, xctx->poly[layer][idx].y,
                          xctx->poly[layer][idx].points, bezier);
        }
        break;
      case ARC:
        idx = gfx_index_from_id(ARC, id, &layer);
        if(idx >= 0)
          drawtemparc(g, ADD, xctx->arc[layer][idx].x, xctx->arc[layer][idx].y,
                      xctx->arc[layer][idx].r, xctx->arc[layer][idx].a, xctx->arc[layer][idx].b);
        break;
      case xTEXT:
        idx = text_index_from_id(id);
        if(idx >= 0) {
          double tx1, ty1, tx2, ty2, longest;
          int nlines;
          char *estr;
          #if HAS_CAIRO==1
          int customfont = set_text_custom_font(&xctx->text[idx]);
          #endif
          estr = my_expand(get_text_floater(idx), tclgetintvar("tabstop"));
          /* outline the text's bounding box (mirrors the selection bbox math) */
          if(text_bbox(estr, xctx->text[idx].xscale, xctx->text[idx].yscale,
                       xctx->text[idx].rot, xctx->text[idx].flip,
                       xctx->text[idx].hcenter, xctx->text[idx].vcenter,
                       xctx->text[idx].x0, xctx->text[idx].y0,
                       &tx1, &ty1, &tx2, &ty2, &nlines, &longest)) {
            RECTORDER(tx1, ty1, tx2, ty2);
            drawtemprect(g, ADD, tx1, ty1, tx2, ty2);
          }
          my_free(_ALLOC_ID_, &estr);
          #if HAS_CAIRO==1
          if(customfont) cairo_restore(xctx->cairo_ctx);
          #endif
        }
        break;
      default: break;
    }
  }
  /* flush the batched primitives (polygons draw immediately, no END) */
  drawtemparc(g, END, 0.0, 0.0, 0.0, 0.0, 0.0);
  drawtemprect(g, END, 0.0, 0.0, 0.0, 0.0);
  drawtempline(g, END, 0.0, 0.0, 0.0, 0.0);
}

/* ===========================================================================
 * Hover (awareness) highlight — outline ONE object (the one under the tracking
 * cursor) in its natural shape with the GC <g>. Mirrors draw_scope_highlight()'s
 * per-type dispatch, but takes a live {type, index, layer} (the object is
 * re-found on every motion, so no stable-id indirection is needed) and is
 * bounds-checked so a stale ref (e.g. after an edit) is a safe no-op rather than
 * a crash. The orchestration (detect on motion, erase previous, draw new,
 * window-only) lives in draw_hover() in callback.c, alongside draw_crosshair().
 * Called with g = gc_hover to draw, or g = gctiled to erase (re-stamp the
 * background pixmap over the old outline). type 0 = nothing -> no-op.
 * =========================================================================== */
/* Union bounding box of an instance's *visible* symbol texts (the rendered net name
 * for a label/pin), mirroring the text loop of symbol_bbox() in select.c: translate
 * @-vars, skip @spice annotator texts, honor hidden-text flags, account for per-text
 * size and Cairo custom fonts. Returns 1 and fills *x1..*y2 if at least one text was
 * found, else 0. Used by draw_hover_shape() so hovering a net label outlines its name
 * text rather than the tiny pin stub. See doc/claude/specs/hover_netlabel_text.md */
static int inst_text_bbox(int n, double *x1, double *y1, double *x2, double *y2)
{
  xSymbol *symptr = xctx->inst[n].ptr + xctx->sym;
  short flip = xctx->inst[n].flip, rot = xctx->inst[n].rot;
  double x0 = xctx->inst[n].x0, y0 = xctx->inst[n].y0;
  int j, found = 0, tmp;
  double dtmp;
  for(j = 0; j < symptr->texts; ++j) {
    double xscale, yscale, text_x0, text_y0, tx1, ty1, tx2, ty2;
    const char *tmp_txt;
    char *estr;
    xText text = symptr->text[j];
    #if HAS_CAIRO==1
    int customfont;
    #endif
    if(!xctx->show_hidden_texts && (text.flags & (HIDE_TEXT | HIDE_TEXT_INSTANTIATED))) continue;
    get_sym_text_size(n, j, &xscale, &yscale);
    tmp_txt = translate(n, text.txt_ptr);
    if(!tmp_txt || !tmp_txt[0]) continue;
    if(!strncmp(tmp_txt, "@spice", 6)) continue; /* annotator texts not part of the visible name */
    ROTATION(rot, flip, 0.0, 0.0, text.x0, text.y0, text_x0, text_y0);
    #if HAS_CAIRO==1
    customfont = set_text_custom_font(&text);
    #endif
    estr = my_expand(tmp_txt, tclgetintvar("tabstop"));
    if(text_bbox(estr, xscale, yscale,
       (text.rot + ((flip && (text.rot & 1)) ? rot+2 : rot)) & 0x3,
       flip ^ text.flip, text.hcenter, text.vcenter,
       x0+text_x0, y0+text_y0, &tx1, &ty1, &tx2, &ty2, &tmp, &dtmp)) {
      if(!found) { *x1 = tx1; *y1 = ty1; *x2 = tx2; *y2 = ty2; found = 1; }
      else {
        if(tx1 < *x1) *x1 = tx1;
        if(ty1 < *y1) *y1 = ty1;
        if(tx2 > *x2) *x2 = tx2;
        if(ty2 > *y2) *y2 = ty2;
      }
    }
    my_free(_ALLOC_ID_, &estr);
    #if HAS_CAIRO==1
    if(customfont) cairo_restore(xctx->cairo_ctx);
    #endif
  }
  return found;
}

void draw_hover_shape(GC g, int type, int n, int c)
{
  switch(type) {
    case ELEMENT:
      if(n >= 0 && n < xctx->instances) {
        double x1, y1, x2, y2;
        const char *symtype = (xctx->inst[n].ptr + xctx->sym)->type;
        /* for net labels/pins the body is a tiny stub at the attachment point; outline
         * the visible net-name text the user is actually pointing at instead */
        if(symtype && IS_LABEL_SH_OR_PIN(symtype) && inst_text_bbox(n, &x1, &y1, &x2, &y2)) {
          /* x1..y2 already hold the text union bbox */
        } else {
          x1 = xctx->inst[n].xx1; y1 = xctx->inst[n].yy1;
          x2 = xctx->inst[n].xx2; y2 = xctx->inst[n].yy2;
        }
        RECTORDER(x1, y1, x2, y2);
        drawtemprect(g, ADD, x1, y1, x2, y2);
      }
      break;
    case WIRE:
      if(n >= 0 && n < xctx->wires)
        drawtempline(g, ADD, xctx->wire[n].x1, xctx->wire[n].y1,
                             xctx->wire[n].x2, xctx->wire[n].y2);
      break;
    case xRECT:
      if(c >= 0 && c < cadlayers && n >= 0 && n < xctx->rects[c]) {
        double x1 = xctx->rect[c][n].x1, y1 = xctx->rect[c][n].y1;
        double x2 = xctx->rect[c][n].x2, y2 = xctx->rect[c][n].y2;
        RECTORDER(x1, y1, x2, y2);
        drawtemprect(g, ADD, x1, y1, x2, y2);
      }
      break;
    case LINE:
      if(c >= 0 && c < cadlayers && n >= 0 && n < xctx->lines[c])
        drawtempline(g, ADD, xctx->line[c][n].x1, xctx->line[c][n].y1,
                             xctx->line[c][n].x2, xctx->line[c][n].y2);
      break;
    case POLYGON:
      if(c >= 0 && c < cadlayers && n >= 0 && n < xctx->polygons[c]) {
        int bezier = 2 + !strboolcmp(
          get_tok_value(xctx->poly[c][n].prop_ptr, "bezier", 0), "true");
        drawtemppolygon(g, NOW, xctx->poly[c][n].x, xctx->poly[c][n].y,
                        xctx->poly[c][n].points, bezier);
      }
      break;
    case ARC:
      if(c >= 0 && c < cadlayers && n >= 0 && n < xctx->arcs[c])
        drawtemparc(g, ADD, xctx->arc[c][n].x, xctx->arc[c][n].y,
                    xctx->arc[c][n].r, xctx->arc[c][n].a, xctx->arc[c][n].b);
      break;
    case xTEXT:
      if(n >= 0 && n < xctx->texts) {
        double tx1, ty1, tx2, ty2, longest;
        int nlines;
        char *estr;
        #if HAS_CAIRO==1
        int customfont = set_text_custom_font(&xctx->text[n]);
        #endif
        estr = my_expand(get_text_floater(n), tclgetintvar("tabstop"));
        if(text_bbox(estr, xctx->text[n].xscale, xctx->text[n].yscale,
                     xctx->text[n].rot, xctx->text[n].flip,
                     xctx->text[n].hcenter, xctx->text[n].vcenter,
                     xctx->text[n].x0, xctx->text[n].y0,
                     &tx1, &ty1, &tx2, &ty2, &nlines, &longest)) {
          RECTORDER(tx1, ty1, tx2, ty2);
          drawtemprect(g, ADD, tx1, ty1, tx2, ty2);
        }
        my_free(_ALLOC_ID_, &estr);
        #if HAS_CAIRO==1
        if(customfont) cairo_restore(xctx->cairo_ctx);
        #endif
      }
      break;
    default: break;
  }
  drawtemparc(g, END, 0.0, 0.0, 0.0, 0.0, 0.0);
  drawtemprect(g, END, 0.0, 0.0, 0.0, 0.0);
  drawtempline(g, END, 0.0, 0.0, 0.0, 0.0);
}


void draw(void)
{
  /* inst_ptr  and wire hash iterator 20171224 */
  double x1, y1, x2, y2;
  Instentry *instanceptr;
  Wireentry *wireptr;
  int use_hash;
  int cc, c, i = 0 /*, floaters = 0 */;
  xSymbol *symptr;
  int textlayer;
  #if HAS_CAIRO==1
  const char *textfont;
  #endif

  dbg(1, "draw()\n");
  if(!xctx || xctx->no_draw) return;
  draw_count++; /* test/introspection seam: a full draw is about to run (xschem get drawcount) */
  pin_names_sync_cache(); /* P6: refresh the show_pin_names cache read by the draw_symbol pin pass */
  /* `tk scaling` is a Tk command; under true headless (--nogui, has_x==0) there is no Tk
   * interpreter, so calling it errors ("invalid command name tk"). Skip it and keep the
   * global default (1.0) -- headless runs that still reach draw() (e.g. scripted
   * move_objects) then produce clean output instead of per-call Tk warnings. */
  if(has_x) tk_scaling = atof(tcleval("tk scaling"));
  xctx->ev_precision = tclgetintvar("ev_precision");
  cairo_font_scale  = tclgetdoublevar("cairo_font_scale");
  set_dotsize_from_snap();   /* reference snap, not the live one (actions.c) */
  xctx->crosshair_layer = tclgetintvar("crosshair_layer");
  if(xctx->crosshair_layer < 0 ) xctx->crosshair_layer = 2;
  if(xctx->crosshair_layer >= cadlayers ) xctx->crosshair_layer = 2;
  #if HAS_CAIRO==1
  #ifndef __unix__
  clear_cairo_surface(xctx->cairo_save_ctx,
    xctx->xrect[0].x, xctx->xrect[0].y, xctx->xrect[0].width, xctx->xrect[0].height);
  clear_cairo_surface(xctx->cairo_ctx,
    xctx->xrect[0].x, xctx->xrect[0].y, xctx->xrect[0].width, xctx->xrect[0].height);
  #endif
  #endif
  xctx->show_hidden_texts = tclgetboolvar("show_hidden_texts");
  rebuild_selected_array();
  if(has_x) {
    Iterator_ctx ctx;

    if(xctx->only_probes) {
      if(tclgetboolvar("dark_colorscheme")) build_colors(-1.5, 0);
      else build_colors(1.5, 0);
    }
    if(xctx->draw_pixmap) {
      XFillRectangle(display, xctx->save_pixmap, xctx->gc[BACKLAYER], xctx->areax1, xctx->areay1,
                     xctx->areaw, xctx->areah);
    }
    if(xctx->draw_window)
      XFillRectangle(display, xctx->window, xctx->gc[BACKLAYER], xctx->areax1, xctx->areay1,
                     xctx->areaw, xctx->areah);
    dbg(1, "draw(): window: %d %d %d %d\n",xctx->areax1, xctx->areay1, xctx->areax2, xctx->areay2);
    if(!xctx->only_probes) drawgrid();
    /* 2: draw cursor 1
     * 4: draw cursor 2 */
    /* +16: on-screen draw -> the ASE viewer active-strip marker (issue 0151);
     * dropped while print_image() renders an export drawable */
    draw_graph_all((xctx->graph_flags & (2 | 4)) + 8 +
                   (draw_no_ui_decorations ? 0 : 16)); /* xctx->graph_flags for cursors */
    draw_images_all();

    x1 = X_TO_XSCHEM(xctx->areax1);
    y1 = Y_TO_XSCHEM(xctx->areay1);
    x2 = X_TO_XSCHEM(xctx->areax2);
    y2 = Y_TO_XSCHEM(xctx->areay2);
    use_hash =  (xctx->wires> 2000 || xctx->instances > 2000 ) &&  (x2 - x1  < ITERATOR_THRESHOLD);
    if(use_hash) {
      hash_instances();
      hash_wires();
    }
    dbg(3, "draw(): check4\n");
    for(c=0;c<cadlayers; ++c) {
      int draw_layer = (xctx->draw_single_layer == -1 || c == xctx->draw_single_layer);
      cc = c; if(xctx->only_probes) cc = GRIDLAYER;
      if(draw_layer && xctx->enable_layer[c]) for(i=0;i<xctx->lines[c]; ++i) {
        xLine *l = &xctx->line[c][i];
        if(l->bus == -1.0) drawline(cc, THICK, l->x1, l->y1, l->x2, l->y2, l->bus, l->dash, NULL);
        else       drawline(cc, ADD, l->x1, l->y1, l->x2, l->y2, l->bus, l->dash, NULL);
      }
      if(draw_layer && xctx->enable_layer[c]) for(i=0;i<xctx->rects[c]; ++i) {
        xRect *r = &xctx->rect[c][i];
        #if HAS_CAIRO==1
        if(c != GRIDLAYER || !(r->flags & (1 + 1024)))
        #else
        if(c != GRIDLAYER || !(r->flags & 1) )
        #endif
        {
          drawrect(cc, ADD, r->x1, r->y1, r->x2, r->y2, r->bus, r->dash, r->ellipse_a, r->ellipse_b);
          if(r->fill) filledrect(cc, ADD, r->x1, r->y1, r->x2, r->y2, r->fill, r->ellipse_a, r->ellipse_b);
        }
      }
      if(draw_layer && xctx->enable_layer[c]) for(i=0;i<xctx->arcs[c]; ++i) {
        xArc **arc = xctx->arc;
        drawarc(cc, ADD, arc[c][i].x, arc[c][i].y, arc[c][i].r, arc[c][i].a, arc[c][i].b,
                arc[c][i].fill, arc[c][i].bus, arc[c][i].dash);
      }
      if(draw_layer && xctx->enable_layer[c]) for(i=0;i<xctx->polygons[c]; ++i) {
        int bezier;
        xPoly *p = &xctx->poly[c][i];
        bezier = 2 + !strboolcmp(get_tok_value(p->prop_ptr, "bezier", 0), "true");
        drawpolygon(cc, NOW, p->x, p->y, p->points, p->fill, p->dash, p->bus, bezier);
      }
      if(use_hash) init_inst_iterator(&ctx, x1, y1, x2, y2);
      else i = -1;
      while(1) {
        if(use_hash) {
          if( !(instanceptr = inst_iterator_next(&ctx))) break;
          i = instanceptr->n;
        }
        else {
          ++i;
          if(i >= xctx->instances) break;
        }
        if(xctx->inst[i].ptr == -1 || (c > 0 && (xctx->inst[i].flags & 1)) ) continue;
        symptr = (xctx->inst[i].ptr+ xctx->sym);
        if(
            c==0 || /*draw_symbol call is needed on layer 0 to avoid redundant work (outside check) */
            symptr->lines[c] ||
            symptr->arcs[c] ||
            symptr->rects[c] ||
            symptr->polygons[c] ||
            ((c==cadlayers - 1) && symptr->texts) )
        {
          if(c == 0 || c == cadlayers - 1 || draw_layer) {
            draw_symbol(ADD, cc, i, c, 0, 0, 0.0, 0.0); /* ... then draw current layer */
            if(c == cadlayers - 1) {
              if(cc == c)  draw_symbol(ADD, c + 1, i, c + 1, 0, 0, 0.0, 0.0); /* ... draw texts */
              else         draw_symbol(ADD, cc   , i, c + 1, 0, 0, 0.0, 0.0); /* ... draw texts */
            }
          }
        }
      }
      filledrect(cc, END, 0.0, 0.0, 0.0, 0.0, 2, -1, -1); /* fill parameter must be 2! */
      drawarc(cc, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0.0, 0);
      drawrect(cc, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, -1, -1);
      drawline(cc, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, NULL);
    }
    cc = WIRELAYER; if(xctx->only_probes) cc = GRIDLAYER;
    if(xctx->draw_single_layer==-1 || xctx->draw_single_layer==WIRELAYER) {
      if(use_hash) init_wire_iterator(&ctx, x1, y1, x2, y2);
      else i = -1;
      while(1) {
        if(use_hash) {
          if( !(wireptr = wire_iterator_next(&ctx))) break;
          i = wireptr->n;
        }
        else {
          ++i;
          if(i >= xctx->wires) break;
        }


        if(tclgetboolvar("auto_set_wire_bus")) auto_set_wire_bus(i, i + 1);

        if(xctx->wire[i].bus == -1.0) {
          if(skip_wire(i))
            drawline(GRIDLAYER, THICK, xctx->wire[i].x1,xctx->wire[i].y1,
              xctx->wire[i].x2,xctx->wire[i].y2, xctx->wire[i].bus, 2, NULL);
          else 
            drawline(cc, THICK, xctx->wire[i].x1,xctx->wire[i].y1,
              xctx->wire[i].x2,xctx->wire[i].y2, xctx->wire[i].bus, 0, NULL);
        }
        else if(skip_wire(i)) 
         drawline(GRIDLAYER, NOW, xctx->wire[i].x1,xctx->wire[i].y1,
            xctx->wire[i].x2,xctx->wire[i].y2, xctx->wire[i].bus, 2, NULL);
        else
          drawline(cc, ADD, xctx->wire[i].x1,xctx->wire[i].y1,
            xctx->wire[i].x2,xctx->wire[i].y2, xctx->wire[i].bus, 0, NULL);
      }
      update_conn_cues(cc, 1, xctx->draw_window);
      filledrect(cc, END, 0.0, 0.0, 0.0, 0.0, 2, -1, -1); /* fill parameter must be 2! */
      drawline(cc, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, NULL);
    }
    for(i=0;i<xctx->texts; ++i)
    {
      const char *txt_ptr;
      textlayer = xctx->text[i].layer;
      if(!xctx->show_hidden_texts && (xctx->text[i].flags & HIDE_TEXT)) continue;
      if(xctx->only_probes) textlayer = GRIDLAYER;
      else if(textlayer < 0 ||  textlayer >= cadlayers) textlayer = TEXTLAYER;
      #if HAS_CAIRO==1
      if(!xctx->enable_layer[textlayer]) continue;
      if(xctx->draw_single_layer != -1 && xctx->draw_single_layer != textlayer) continue;
      textfont = xctx->text[i].font;
      if( (textfont && textfont[0]) ||
          (xctx->text[i].flags & (TEXT_BOLD | TEXT_OBLIQUE | TEXT_ITALIC))) {
        cairo_font_slant_t slant;
        cairo_font_weight_t weight;
        textfont = (xctx->text[i].font && xctx->text[i].font[0]) ?
          xctx->text[i].font : tclgetvar("cairo_font_name");
        weight = ( xctx->text[i].flags & TEXT_BOLD) ? CAIRO_FONT_WEIGHT_BOLD : CAIRO_FONT_WEIGHT_NORMAL;
        slant = CAIRO_FONT_SLANT_NORMAL;
        if(xctx->text[i].flags & TEXT_ITALIC) slant = CAIRO_FONT_SLANT_ITALIC;
        if(xctx->text[i].flags & TEXT_OBLIQUE) slant = CAIRO_FONT_SLANT_OBLIQUE;

        cairo_save(xctx->cairo_ctx);
        cairo_save(xctx->cairo_save_ctx);
        xctx->cairo_font =
              cairo_toy_font_face_create(textfont, slant, weight);
        cairo_set_font_face(xctx->cairo_ctx, xctx->cairo_font);
        cairo_set_font_face(xctx->cairo_save_ctx, xctx->cairo_font);
        cairo_font_face_destroy(xctx->cairo_font);
      }
      #endif
      txt_ptr =  get_text_floater(i);
      dbg(1, "draw(): drawing string %d = %s\n",i, txt_ptr);
      draw_string(textlayer, ADD, txt_ptr,
        xctx->text[i].rot, xctx->text[i].flip, xctx->text[i].hcenter, xctx->text[i].vcenter,
        xctx->text[i].x0,xctx->text[i].y0,
        xctx->text[i].xscale, xctx->text[i].yscale);
      #if HAS_CAIRO==1
      if( (textfont && textfont[0]) ||
          (xctx->text[i].flags & (TEXT_BOLD | TEXT_OBLIQUE | TEXT_ITALIC))) {
        cairo_restore(xctx->cairo_ctx);
        cairo_restore(xctx->cairo_save_ctx);
      }
      #endif
      #if HAS_CAIRO!=1
      drawrect(textlayer, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, -1, -1);
      drawline(textlayer, END, 0.0, 0.0, 0.0, 0.0, 0.0, 0, NULL);
      #endif
    } /* for(i=0;i<xctx->texts; ++i) */
    if(xctx->only_probes) build_colors(1.0, 0);
    if(xctx->only_probes) {
      xctx->save_lw = xctx->lw;
      xctx->lw=3.0;
      change_linewidth(xctx->lw);
    }
    draw_hilight_net(xctx->draw_window);
    if(xctx->only_probes) {
      xctx->lw = xctx->save_lw;
      change_linewidth(xctx->save_lw);
    }
    /* do_copy_area is zero only when doing png hardcopy to avoid video flickering */
    if(xctx->do_copy_area) {
      if(!xctx->draw_window && xctx->draw_pixmap) {
        MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0], xctx->xrect[0].x, xctx->xrect[0].y,
           xctx->xrect[0].width, xctx->xrect[0].height, xctx->xrect[0].x, xctx->xrect[0].y);
      }
      #if !defined(__unix__) && HAS_CAIRO==1
      else
        my_cairo_fill(xctx->cairo_sfc, xctx->xrect[0].x, xctx->xrect[0].y,
                      xctx->xrect[0].width, xctx->xrect[0].height);
      #endif
    }
    if(tclgetboolvar("compare_sch") /* && xctx->sch_to_compare[0]*/ ){
      compare_schematics("");
    } else {
      draw_selection(xctx->gc[SELLAYER], 0); /* 20181009 moved outside of cadlayers loop */
    }
    draw_scope_highlight(); /* apply-scope white outline, on top of the selection */
    /* this full redraw wiped the window-only hover outline: forget it, then
     * re-establish it at the current pointer so the awareness cue survives
     * pan/zoom (like the crosshair below). draw_hover() no-ops when disabled /
     * mid-gesture / pointer outside. */
    xctx->hover_type = 0;
    draw_hover(1);
    /* this full redraw also wiped the window-only fly-line star: re-stroke the tracked segments
     * (xctx->fly_seg) so the overlay survives pan/zoom/expose, exactly like the hover outline
     * above. No-op when nothing is shown. See draw_flylines() / hover_flylines.md (Track B). */
    flyline_restamp();
    if(tclgetboolvar("draw_crosshair")) draw_crosshair(7, 0); /* what = 1(clear) + 2(draw) */
    /* THE TRACE-HIGHLIGHT OVERLAY IS PAINTED LAST, and into the WINDOW ONLY
     * (doc/claude/specs/wave_trace_hilight.md §5.1). Last, because it is chrome
     * on top of the plot; window-only, because that is what lets an animation
     * frame erase it with one XCopyArea from save_pixmap instead of a redraw.
     * `erase` is 0 here: this redraw has just repainted the whole region, so
     * there is nothing stale to copy back. It is also what satisfies §6's
     * "the overlay is always painted last" for the MIXED animation frame, where
     * draw_hilight_region runs a real draw() -- this call is that re-stroke, so
     * no separate one is owed there. No-op when this context has no wave
     * highlights (the test is inside the drawer -- landmine 44). */
    draw_wave_hilight(0);
  } /* if(has_x) */
}

#ifndef __unix__
/* place holder for Windows to show that these XLib functions are not supported in Windows. */
int XSetClipRectangles(register Display* dpy, GC gc, int clip_x_origin, int clip_y_origin,
                       XRectangle* rectangles, int n, int ordering)
{
  return 0;
}
int XSetTile(Display* display, GC gc, Pixmap s_pixmap)
{
  return 0;
}
#endif

void MyXCopyArea(Display* display, Drawable src, Drawable dest, GC gc, int src_x, int src_y,
     unsigned int width, unsigned int height, int dest_x, int dest_y)
{
  dbg(1, "MyXCopyArea(%d, %d, %u, %u)\n", src_x, src_y, width, height);
  #if !defined(__unix__)
  XCopyArea(display, src, dest, gc, src_x, src_y, width, height, dest_x, dest_y);
  #if HAS_CAIRO==1
  my_cairo_fill(xctx->cairo_save_sfc, dest_x, dest_y, width, height);
  #endif
  /*
   * #elif (defined(__unix__)  && HAS_CAIRO==1) || DRAW_ALL_CAIRO==1
   * cairo_set_source_surface(xctx->cairo_ctx, xctx->cairo_save_sfc, 0, 0);
   * cairo_paint(xctx->cairo_ctx);
   */
  #else
  XCopyArea(display, src, dest, gc, src_x, src_y, width, height, dest_x, dest_y);
  #endif
}

void MyXCopyAreaDouble(Display* display, Drawable src, Drawable dest, GC gc,
     double sx1, double sy1, double sx2, double sy2,
     double dx1, double dy1, double lw)
{
  double isx1, isy1, isx2, isy2, idx1, idy1;
  unsigned int width, height;
  int intlw = INT_LINE_W(lw);
  dbg(1, "MyXCopyAreaDouble(%g, %g, %g, %g, intlw=%d)\n", sx1, sy1, sx2, sy2, intlw);
  isx1=X_TO_SCREEN(sx1) - 2 * intlw;
  isy1=Y_TO_SCREEN(sy1) - 2 * intlw;
  isx2=X_TO_SCREEN(sx2) + 2 * intlw;
  isy2=Y_TO_SCREEN(sy2) + 2 * intlw;

  idx1=X_TO_SCREEN(dx1) - 2 * intlw;
  idy1=Y_TO_SCREEN(dy1) - 2 * intlw;

  width = (unsigned int)isx2 - (unsigned int)isx1;
  height = (unsigned int)isy2 - (unsigned int)isy1;
  #if !defined(__unix__)
  XCopyArea(display, src, dest, gc, (int)isx1, (int)isy1, width, height, (int)idx1, (int)idy1);
  #if HAS_CAIRO==1
  my_cairo_fill(xctx->cairo_save_sfc, (int)idx1, (int)idy1, width, height);
  #endif
  #else
  XCopyArea(display, src, dest, gc, (int)isx1, (int)isy1, width, height, (int)idx1, (int)idy1);
  #endif
}

