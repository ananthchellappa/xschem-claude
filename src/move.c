/* File: move.c
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
#include <stdarg.h>   /* fluid-reroute FLUID_TRACE diagnostic (issue 0083) */


void flip_rotate_ellipse(xRect *r, int rot, int flip)
{
  if(r->ellipse_a == -1) return;
  else if(r->ellipse_b == 360) return;
  else {
    char str[100];
    if(flip) {
      r->ellipse_a = 180 - r->ellipse_a - r->ellipse_b;
      my_snprintf(str, S(str), "%d,%d", r->ellipse_a, r->ellipse_b);
      my_strdup2(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ellipse", str));
    }
    if(rot) {
      if(rot == 3) {
        r->ellipse_a += 90;
      } else if(rot == 2) {
        r->ellipse_a += 180;
      } else if(rot == 1) {
        r->ellipse_a += 270;
      }
      r->ellipse_a %= 360;
      my_snprintf(str, S(str), "%d,%d", r->ellipse_a, r->ellipse_b);
      my_strdup2(_ALLOC_ID_, &r->prop_ptr, subst_token(r->prop_ptr, "ellipse", str));
    }
  }
}

void rebuild_selected_array() /* can be used only if new selected set is lower */
                              /* that is, xctx->sel_array[] size can not increase */
{
 int i,c;

 dbg(2, "rebuild selected array\n");
 if(!xctx->need_reb_sel_arr) return;
 xctx->lastsel=0;
 for(i=0;i<xctx->texts; ++i)
  if(xctx->text[i].sel)
  {
   check_selected_storage();
   xctx->sel_array[xctx->lastsel].type = xTEXT;
   xctx->sel_array[xctx->lastsel].n = i;
   xctx->sel_array[xctx->lastsel++].col = TEXTLAYER;
  }
 for(i=0;i<xctx->instances; ++i)
  if(xctx->inst[i].sel)
  {
   check_selected_storage();
   xctx->sel_array[xctx->lastsel].type = ELEMENT;
   xctx->sel_array[xctx->lastsel].n = i;
   xctx->sel_array[xctx->lastsel++].col = WIRELAYER;
  }
 /* emit one INST_PIN entry per selected pin (pin_selection.md). This is independent
  * of inst.sel, so a pins-only instance contributes pin entries but no ELEMENT entry.
  * Scan is bounded by min(pin count, pin_sel_size) so a symbol pin-count change can
  * never read past the allocation. */
 for(i=0;i<xctx->instances; ++i)
  if(xctx->inst[i].pin_sel && xctx->inst[i].ptr >= 0)
  {
   int p, rects = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
   int lim = rects < xctx->inst[i].pin_sel_size ? rects : xctx->inst[i].pin_sel_size;
   for(p = 0; p < lim; ++p) if(xctx->inst[i].pin_sel[p])
   {
    check_selected_storage();
    xctx->sel_array[xctx->lastsel].type = INST_PIN;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = (unsigned int)p;
   }
  }
 for(i=0;i<xctx->wires; ++i)
  if(xctx->wire[i].sel)
  {
   check_selected_storage();
   xctx->sel_array[xctx->lastsel].type = WIRE;
   xctx->sel_array[xctx->lastsel].n = i;
   xctx->sel_array[xctx->lastsel++].col = WIRELAYER;
  }
 for(c=0;c<cadlayers; ++c)
 {
  for(i=0;i<xctx->arcs[c]; ++i)
   if(xctx->arc[c][i].sel)
   {
    check_selected_storage();
    xctx->sel_array[xctx->lastsel].type = ARC;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = c;
   }
  for(i=0;i<xctx->rects[c]; ++i)
   if(xctx->rect[c][i].sel)
   {
    check_selected_storage();
    xctx->sel_array[xctx->lastsel].type = xRECT;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = c;
   }
  for(i=0;i<xctx->lines[c]; ++i)
   if(xctx->line[c][i].sel)
   {
    check_selected_storage();
    xctx->sel_array[xctx->lastsel].type = LINE;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = c;
   }
  for(i=0;i<xctx->polygons[c]; ++i)
   if(xctx->poly[c][i].sel)
   {
    check_selected_storage();
    xctx->sel_array[xctx->lastsel].type = POLYGON;
    xctx->sel_array[xctx->lastsel].n = i;
    xctx->sel_array[xctx->lastsel++].col = c;
   }
 }
 if(xctx->lastsel==0) {
   xctx->ui_state &= ~SELECTION;
   set_first_sel(0, -1, 0);
 } else xctx->ui_state |= SELECTION;
 xctx->need_reb_sel_arr=0;
}

/* predicate for wire_delete_compact() — see wire lifecycle census */
static int wire_doomed_degenerate(int n, void *arg)
{
  (void)arg;
  return xctx->wire[n].x1==xctx->wire[n].x2 && xctx->wire[n].y1 == xctx->wire[n].y2;
}

void check_collapsing_objects()
{
  int  j,i, c;
  int found=0;

  j = wire_delete_compact(wire_doomed_degenerate, NULL);
  if(j) found=1;

 /* option: remove degenerated lines  */
   for(c=0;c<cadlayers; ++c)
   {
    j = 0;
    for(i=0;i<xctx->lines[c]; ++i)
    {
     if(xctx->line[c][i].x1==xctx->line[c][i].x2 && xctx->line[c][i].y1 == xctx->line[c][i].y2)
     {
      my_free(_ALLOC_ID_, &xctx->line[c][i].prop_ptr);
      found=1;
      ++j;
      continue;
     }
     if(j)
     {
      xctx->line[c][i-j] = xctx->line[c][i];
     }
    }
    xctx->lines[c] -= j;
   }
   for(c=0;c<cadlayers; ++c)
   {
    j = 0;
    for(i=0;i<xctx->rects[c]; ++i)
    {
     if(xctx->rect[c][i].x1==xctx->rect[c][i].x2 || xctx->rect[c][i].y1 == xctx->rect[c][i].y2)
     {
      my_free(_ALLOC_ID_, &xctx->rect[c][i].prop_ptr);
      set_rect_extraptr(0, &xctx->rect[c][i]);
      found=1;
      ++j;
      continue;
     }
     if(j)
     {
      xctx->rect[c][i-j] = xctx->rect[c][i];
     }
    }
    xctx->rects[c] -= j;
   }

  if(found) {
    xctx->need_reb_sel_arr=1;
    rebuild_selected_array();
  }
}

static void update_symbol_bboxes(short rot, short flip)
{
  int i, n;
  short save_flip, save_rot;

  for(i=0;i<xctx->movelastsel; ++i)
  {
    n = xctx->sel_array[i].n;
    dbg(1, "update_symbol_bboxes(): i=%d, movelastsel=%d, n=%d\n", i, xctx->movelastsel, n);
    if(xctx->sel_array[i].type == ELEMENT) {
      if(n < 0 || n >= xctx->instances || xctx->inst[n].ptr < 0) continue; /* stale/unlinked: symbol_bbox would read sym[ptr<0] */
      dbg(1, "update_symbol_bboxes(): symbol flip=%d, rot=%d\n",  xctx->inst[n].flip, xctx->inst[n].rot);
      save_flip = xctx->inst[n].flip;
      save_rot = xctx->inst[n].rot;
      xctx->inst[n].flip = flip ^ xctx->inst[n].flip;
      xctx->inst[n].rot = (xctx->inst[n].rot + rot) & 0x3;
      symbol_bbox(n, &xctx->inst[n].x1, &xctx->inst[n].y1, &xctx->inst[n].x2, &xctx->inst[n].y2 );
      xctx->inst[n].rot = save_rot;
      xctx->inst[n].flip = save_flip;
    }
  }
}

static void draw_selection_impl(GC g, int interruptable);

/* incremental_wire_reroute.md Phase II: while a fluid stretch RUBBER step has LIVE-COMMITTED the
 * moved geometry (xctx->fluid_reroute_dirty), the inst/wire/text coords ALREADY include the move
 * delta. xctx->deltax/deltay are deliberately kept equal to the accumulated total so the eventual
 * interactive END (move_objects(END,0,0,0)) can consume them (move.c live-commit tail), but the
 * selection OVERLAY must NOT re-add that delta: an external full redraw (window Expose, hover,
 * `xschem redraw`, crosshair) firing BETWEEN RUBBER frames -- when delta has been restored to the
 * total but the geometry is already committed -- would otherwise paint the ghost at origin+2*delta,
 * a greyed duplicate one full displacement beyond the real instance. Zero the move-delta for the
 * duration of the overlay draw and restore it after, so END still sees the accumulated total. The
 * wrapper (vs an inline zero) guarantees the restore on every early-return path inside the body
 * (interruptable resume, tiled-fill fast path). Gated on fluid_reroute_dirty, which is only ever set
 * when fluid_editing was on at START => default-off is byte-identical. */
void draw_selection(GC g, int interruptable)
{
  if(xctx->fluid_reroute_dirty) {
    double sv_dx = xctx->deltax, sv_dy = xctx->deltay;
    xctx->deltax = 0.0; xctx->deltay = 0.0;
    draw_selection_impl(g, interruptable);
    xctx->deltax = sv_dx; xctx->deltay = sv_dy;
  } else {
    draw_selection_impl(g, interruptable);
  }
}

static void draw_selection_impl(GC g, int interruptable)
{
  int i, c, k, n;
  double  angle; /* arc */
  #if HAS_CAIRO==1
  int customfont;
  #endif
  dbg(1,"draw_selection, %s, lastsel=%d\n", g == xctx->gctiled ? "gctiled" : "gcselect", xctx->lastsel);
  if(g != xctx->gctiled) xctx->movelastsel = xctx->lastsel;

  if((fix_broken_tiled_fill || !_unix) && g == xctx->gctiled && xctx->movelastsel > 800) {
    MyXCopyArea(display, xctx->save_pixmap, xctx->window, xctx->gc[0], xctx->xrect[0].x, xctx->xrect[0].y,
          xctx->xrect[0].width, xctx->xrect[0].height, xctx->xrect[0].x, xctx->xrect[0].y);
    return;
  }
  for(i=0;i<xctx->movelastsel; ++i)
  {
   short int tmp_rot;
   c = xctx->sel_array[i].col;n = xctx->sel_array[i].n;
   switch(xctx->sel_array[i].type)
   {
    case xTEXT:
     if(xctx->rotatelocal) {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->text[n].x0, xctx->text[n].y0,
         xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
     }
     #if HAS_CAIRO==1
     customfont =  set_text_custom_font(&xctx->text[n]);
     #endif
     draw_temp_string(g,ADD, get_text_floater(n),
      (xctx->text[n].rot +
      ( (xctx->move_flip && (xctx->text[n].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3,
       xctx->text[n].flip^xctx->move_flip, xctx->text[n].hcenter, xctx->text[n].vcenter,
       xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
       xctx->text[n].xscale, xctx->text[n].yscale);
     #if HAS_CAIRO==1
     if(customfont) {
       cairo_restore(xctx->cairo_ctx);
     }
     #endif

     break;
    case xRECT:
     if(xctx->rotatelocal) {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
         xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
         xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
     }
     if(xctx->rect[c][n].sel==SELECTED)
     {
       RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
       drawtemprect(g, ADD, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay);
     }
     else if(xctx->rect[c][n].sel==SELECTED1)
     {
      xctx->rx1+=xctx->deltax;
      xctx->ry1+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==SELECTED2)
     {
      xctx->rx2+=xctx->deltax;
      xctx->ry1+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==SELECTED3)
     {
      xctx->rx1+=xctx->deltax;
      xctx->ry2+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==SELECTED4)
     {
      xctx->rx2+=xctx->deltax;
      xctx->ry2+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==(SELECTED1|SELECTED2))
     {
      xctx->ry1+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==(SELECTED3|SELECTED4))
     {
      xctx->ry2+=xctx->deltay;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==(SELECTED1|SELECTED3))
     {
      xctx->rx1+=xctx->deltax;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     else if(xctx->rect[c][n].sel==(SELECTED2|SELECTED4))
     {
      xctx->rx2+=xctx->deltax;
      RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
      drawtemprect(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
     }
     break;
    case POLYGON:
     {
      int bezier;
      double *x = my_malloc(_ALLOC_ID_, sizeof(double) *xctx->poly[c][n].points);
      double *y = my_malloc(_ALLOC_ID_, sizeof(double) *xctx->poly[c][n].points);
      bezier = 2 + !strboolcmp(get_tok_value(xctx->poly[c][n].prop_ptr, "bezier", 0), "true");
      if(xctx->poly[c][n].sel==SELECTED || xctx->poly[c][n].sel==SELECTED1) {
        for(k=0;k<xctx->poly[c][n].points; ++k) {
          if( xctx->poly[c][n].sel==SELECTED || xctx->poly[c][n].selected_point[k]) {
            if(xctx->rotatelocal) {
              ROTATION(xctx->move_rot, xctx->move_flip, xctx->poly[c][n].x[0], xctx->poly[c][n].y[0],
                       xctx->poly[c][n].x[k], xctx->poly[c][n].y[k], xctx->rx1,xctx->ry1);
            } else {
              ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->poly[c][n].x[k], xctx->poly[c][n].y[k], xctx->rx1,xctx->ry1);
            }
            x[k] = xctx->rx1 + xctx->deltax;
            y[k] = xctx->ry1 + xctx->deltay;
          } else {
            x[k] = xctx->poly[c][n].x[k];
            y[k] = xctx->poly[c][n].y[k];
          }
        }
        drawtemppolygon(g, NOW, x, y, xctx->poly[c][n].points, bezier);
      }
      my_free(_ALLOC_ID_, &x);
      my_free(_ALLOC_ID_, &y);
     }
     break;

    case WIRE:
     if(xctx->rotatelocal) {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->wire[n].x1, xctx->wire[n].y1,
         xctx->wire[n].x1, xctx->wire[n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->wire[n].x1, xctx->wire[n].y1,
         xctx->wire[n].x2, xctx->wire[n].y2, xctx->rx2,xctx->ry2);
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->wire[n].x1, xctx->wire[n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->wire[n].x2, xctx->wire[n].y2, xctx->rx2,xctx->ry2);
     }

     ORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
     if(xctx->wire[n].sel==SELECTED)
     {
      double x1 = xctx->rx1 + xctx->deltax;
      double y1 = xctx->ry1 + xctx->deltay;
      double x2 = xctx->rx2 + xctx->deltax;
      double y2 = xctx->ry2 + xctx->deltay;
      dbg(1, "draw_selection() wire: %g %g - %g %g  manhattan=%d\n", x1, y1, x2, y2, xctx->manhattan_lines);
      if(xctx->wire[n].bus == -1.0) {
        drawtemp_manhattanline(g, THICK, x1, y1, x2, y2, 1);
      } else {
        drawtemp_manhattanline(g, ADD, x1, y1, x2, y2, 1);
      }
     }
     else if(xctx->wire[n].sel==SELECTED1)
     {
      double x1 = xctx->rx1 + xctx->deltax;
      double y1 = xctx->ry1 + xctx->deltay;
      double x2 = xctx->rx2;
      double y2 = xctx->ry2;
      dbg(1, "draw_selection() wire: %g %g - %g %g  manhattan=%d\n", x1, y1, x2, y2, xctx->manhattan_lines);
      if(xctx->wire[n].bus == -1.0) {
        drawtemp_manhattanline(g, THICK, x2, y2, x1, y1, 1);
      } else {
        drawtemp_manhattanline(g, ADD, x2, y2, x1, y1, 1);
      }
     }
     else if(xctx->wire[n].sel==SELECTED2)
     {
      double x1 = xctx->rx1;
      double y1 = xctx->ry1;
      double x2 = xctx->rx2 + xctx->deltax;
      double y2 = xctx->ry2 + xctx->deltay;
      dbg(1, "draw_selection() wire: %g %g - %g %g  manhattan=%d\n", x1, y1, x2, y2, xctx->manhattan_lines);
      if(xctx->wire[n].bus == -1.0) {
        drawtemp_manhattanline(g, THICK, x1, y1, x2, y2, 1);
      } else {
        drawtemp_manhattanline(g, ADD, x1, y1, x2, y2, 1);
      }
     }
     break;
    case LINE:
     if(xctx->rotatelocal) {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->line[c][n].x1, xctx->line[c][n].y1,
         xctx->line[c][n].x1, xctx->line[c][n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->line[c][n].x1, xctx->line[c][n].y1,
         xctx->line[c][n].x2, xctx->line[c][n].y2, xctx->rx2,xctx->ry2);
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->line[c][n].x1, xctx->line[c][n].y1, xctx->rx1,xctx->ry1);
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->line[c][n].x2, xctx->line[c][n].y2, xctx->rx2,xctx->ry2);
     }
     ORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
     if(xctx->line[c][n].sel==SELECTED)
     {
       if(xctx->line[c][n].bus == -1.0)
         drawtempline(g, THICK, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay);
       else
         drawtempline(g, ADD, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay);
     }
     else if(xctx->line[c][n].sel==SELECTED1)
     {
       if(xctx->line[c][n].bus == -1.0)
         drawtempline(g, THICK, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay, xctx->rx2, xctx->ry2);
       else
         drawtempline(g, ADD, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay, xctx->rx2, xctx->ry2);
     }
     else if(xctx->line[c][n].sel==SELECTED2)
     {
       if(xctx->line[c][n].bus == -1.0)
         drawtempline(g, THICK, xctx->rx1, xctx->ry1, xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay);
       else
         drawtempline(g, ADD, xctx->rx1, xctx->ry1, xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay);
     }
     break;
    case ARC:
     if(xctx->rotatelocal) {
       /* rotate center wrt itself: do nothing */
       xctx->rx1 = xctx->arc[c][n].x;
       xctx->ry1 = xctx->arc[c][n].y;
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->arc[c][n].x, xctx->arc[c][n].y, xctx->rx1,xctx->ry1);
     }
     angle = xctx->arc[c][n].a;
     if(xctx->move_flip) {
       angle = 270.*xctx->move_rot+180.-xctx->arc[c][n].b-xctx->arc[c][n].a;
     } else {
       angle = xctx->arc[c][n].a+xctx->move_rot*270.;
     }
     angle = fmod(angle, 360.);
     if(angle<0.) angle+=360.;
     if(xctx->arc[c][n].sel==SELECTED) {
       drawtemparc(g, ADD, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                xctx->arc[c][n].r, angle, xctx->arc[c][n].b);
     } else if(xctx->arc[c][n].sel==SELECTED1) {
       drawtemparc(g, ADD, xctx->rx1, xctx->ry1,
                fabs(xctx->arc[c][n].r+xctx->deltax), angle, xctx->arc[c][n].b);
     } else if(xctx->arc[c][n].sel==SELECTED3) {
       angle = my_round(fmod(atan2(-xctx->deltay, xctx->deltax)*180./XSCH_PI+xctx->arc[c][n].b, 360.));
       if(angle<0.) angle +=360.;
       if(angle==0) angle=360.;
       drawtemparc(g, ADD, xctx->rx1, xctx->ry1, xctx->arc[c][n].r, xctx->arc[c][n].a, angle);
     } else if(xctx->arc[c][n].sel==SELECTED2) {
       angle = my_round(fmod(atan2(-xctx->deltay, xctx->deltax)*180./XSCH_PI+angle, 360.));
       if(angle<0.) angle +=360.;
       drawtemparc(g, ADD, xctx->rx1, xctx->ry1, xctx->arc[c][n].r, angle, xctx->arc[c][n].b);
     }
     break;
    case ELEMENT:
     if(xctx->rotatelocal) {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->inst[n].x0, xctx->inst[n].y0,
         xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
     } else {
       ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
                xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
     }
     tmp_rot = (xctx->move_flip & xctx->inst[n].rot & 1) ?
                0x3 & (xctx->move_rot + 2) : xctx->move_rot;
     for(k=0;k<cadlayers; ++k) {
       draw_temp_symbol(ADD, g, n, k, xctx->move_flip,
         tmp_rot,
         xctx->rx1-xctx->inst[n].x0+xctx->deltax,xctx->ry1-xctx->inst[n].y0+xctx->deltay);
     }
     break;
    case INST_PIN: {
      /* selected instance pin (pin_selection.md D4): a box + diagonal cross centered on
       * the pin point, stroked in the SELECTION colour (SELLAYER). MUST NOT use the
       * pin's own layer colour -- pins are usually drawn in PINLAYER (often red), so a
       * PINLAYER marker is invisible on the pin. The box+X *shape* is what distinguishes
       * it from the whole-instance outline. Pins are inert, so it ignores any
       * in-progress move offset and sits on the true pin. NOW mode -> uses its own GC,
       * independent of the ADD/END batch flushed with g. Erase pass (g==gctiled)
       * restores the box region, which also covers the cross. */
      double px, py, h = PIN_SEL_HANDLE_H;
      GC mg = (g == xctx->gctiled) ? xctx->gctiled : xctx->gc[SELLAYER];
      get_inst_pin_coord(n, (int)c, &px, &py);
      drawtemprect(mg, NOW, px - h, py - h, px + h, py + h);
      if(g != xctx->gctiled) {
        drawtempline(mg, NOW, px - h, py - h, px + h, py + h);
        drawtempline(mg, NOW, px - h, py + h, px + h, py - h);
      }
      break;
    }
   }
#ifdef __unix__
   if(interruptable && pending_events())
   {
    drawtemparc(g, END, 0.0, 0.0, 0.0, 0.0, 0.0);
    drawtemprect(g, END, 0.0, 0.0, 0.0, 0.0);
    drawtempline(g, END, 0.0, 0.0, 0.0, 0.0);
    xctx->movelastsel = i+1;
    return;
   }
#else
   if (interruptable)
   {
     drawtemparc(g, END, 0.0, 0.0, 0.0, 0.0, 0.0);
     drawtemprect(g, END, 0.0, 0.0, 0.0, 0.0);
     drawtempline(g, END, 0.0, 0.0, 0.0, 0.0);
     xctx->movelastsel = i + 1;
     return;
   }
#endif
  } /* for(i=0;i<xctx->movelastsel; ++i) */
  drawtemparc(g, END, 0.0, 0.0, 0.0, 0.0, 0.0);
  drawtemprect(g, END, 0.0, 0.0, 0.0, 0.0);
  drawtempline(g, END, 0.0, 0.0, 0.0, 0.0);
  xctx->movelastsel = i;
}

/* sel: if set to 1 change references only on selected items, like in a copy operation.
 * If set to 0 operate on all objects with matching name=... attribute */
void update_attached_floaters(const char *from_name, int inst, int sel)
{
  int i, c;
  char *to_name = xctx->inst[inst].instname;
  const char *attach = get_tok_value(xctx->inst[inst].prop_ptr, "attach", 0);
  char *new_attach;

  if(!from_name || !from_name[0]) return;
  if(!to_name || !to_name[0]) return;
  if(!attach[0]) return;

     new_attach = str_replace(attach, from_name, to_name, 1, 1);
     my_strdup(_ALLOC_ID_, &xctx->inst[inst].prop_ptr,
               subst_token(xctx->inst[inst].prop_ptr, "attach", new_attach) );

     for(c = 0; c < cadlayers; c++) {
      for(i = 0; i < xctx->rects[c]; i++) {
        if(!sel || xctx->rect[c][i].sel == SELECTED) {
          if( !strcmp(from_name, get_tok_value(xctx->rect[c][i].prop_ptr, "name", 0))) {
            my_strdup(_ALLOC_ID_, &xctx->rect[c][i].prop_ptr,
                      subst_token(xctx->rect[c][i].prop_ptr, "name", to_name) );
          }
          if(c == GRIDLAYER) {
            const char *node = get_tok_value(xctx->rect[c][i].prop_ptr, "node", 2);
            if(node && node[0]) {
              const char *new_node = str_replace(node, from_name, to_name, 1, -1);
              my_strdup(_ALLOC_ID_, &xctx->rect[c][i].prop_ptr,
                   subst_token(xctx->rect[c][i].prop_ptr, "node", new_node));
            }
          }
        }
      }
      for(i = 0; i < xctx->lines[c]; i++) {
        if((!sel || xctx->line[c][i].sel == SELECTED) &&
           !strcmp(from_name, get_tok_value(xctx->line[c][i].prop_ptr, "name", 0))) {
          my_strdup(_ALLOC_ID_, &xctx->line[c][i].prop_ptr,
                    subst_token(xctx->line[c][i].prop_ptr, "name", to_name) );
        }
      }

      for(i = 0; i < xctx->polygons[c]; i++) {
        if((!sel || xctx->poly[c][i].sel == SELECTED) &&
           !strcmp(from_name, get_tok_value(xctx->poly[c][i].prop_ptr, "name", 0))) {
          my_strdup(_ALLOC_ID_, &xctx->poly[c][i].prop_ptr,
                    subst_token(xctx->poly[c][i].prop_ptr, "name", to_name) );

        }
      }
      for(i = 0; i < xctx->arcs[c]; i++) {
        if((!sel || xctx->arc[c][i].sel == SELECTED) &&
           !strcmp(from_name, get_tok_value(xctx->arc[c][i].prop_ptr, "name", 0))) {
          my_strdup(_ALLOC_ID_, &xctx->arc[c][i].prop_ptr,
                    subst_token(xctx->arc[c][i].prop_ptr, "name", to_name) );
        }
      }
    }
    for(i = 0; i < xctx->wires; i++) {
      if((!sel || xctx->wire[i].sel == SELECTED) &&
           !strcmp(from_name, get_tok_value(xctx->wire[i].prop_ptr, "name", 0))) {
          my_strdup(_ALLOC_ID_, &xctx->wire[i].prop_ptr,
                    subst_token(xctx->wire[i].prop_ptr, "name", to_name) );
      }
    }
    for(i = 0; i < xctx->texts; i++) {
      if((!sel || xctx->text[i].sel == SELECTED) &&
           !strcmp(from_name, get_tok_value(xctx->text[i].prop_ptr, "name", 0))) {
          my_strdup(_ALLOC_ID_, &xctx->text[i].prop_ptr,
                    subst_token(xctx->text[i].prop_ptr, "name", to_name) );
        set_text_flags(&xctx->text[i]);
      }
    }
}


void copy_objects(int what)
{
  int tmpi, c, i, n, k /*, tmp */ ;
  double angle, dtmp;
  int newpropcnt;
  double tmpx, tmpy;
  char *estr = NULL;

  #if HAS_CAIRO==1
  int customfont;
  #endif

  if(what & START)
  {
   xctx->rotatelocal=0;
   dbg(1, "copy_objects(): START copy\n");
   rebuild_selected_array();
   /* read-only backstop (issue 0041): refuse to begin a copy-place below the entry
    * guards; placed with the lastsel==0 early return so a refused START leaves the same
    * clean state (see move_objects START). */
   if(begin_edit("copy")) return;
   if(xctx->lastsel==0) return;
   update_symbol_bboxes(0, 0);
   if(xctx->connect_by_kissing == 2) xctx->kissing = connect_by_kissing();
   else xctx->kissing = 0;

   save_selection(1);
   xctx->deltax = xctx->deltay = 0.0;
   xctx->movelastsel = xctx->lastsel;
   xctx->x1=xctx->mousex_snap;xctx->y1=xctx->mousey_snap;
   xctx->move_flip = 0;xctx->move_rot = 0;
   xctx->ui_state|=STARTCOPY;
  }
  if(what & ABORT)                               /* abort operation */
  {
   draw_selection(xctx->gctiled,0);

   if(xctx->kissing) {
     pop_undo(0, 0);
     check_collapsing_objects(); /* sweep degenerate kiss stubs (see move_objects ABORT) */
   }
   /* Always clear the kissing request on abort (see move_objects ABORT): a
    * stale connect_by_kissing == 2 would leak into the next gesture. */
   if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;

   xctx->move_rot = xctx->move_flip = 0;
   xctx->deltax = xctx->deltay = 0.;
   xctx->ui_state&=~STARTCOPY;
   update_symbol_bboxes(0, 0);
  }
  if(what & RUBBER)                              /* draw objects while moving */
  {
   if(xctx->mousex_snap == xctx->x2 && xctx->mousey_snap == xctx->y2) return;
   xctx->x2=xctx->mousex_snap;xctx->y2=xctx->mousey_snap;
   draw_selection(xctx->gctiled,0);
   xctx->deltax = xctx->x2-xctx->x1; xctx->deltay = xctx->y2 - xctx->y1;
  }
  if(what & ROTATELOCAL ) {
   xctx->rotatelocal=1;
  }
  if(what & ROTATE) {
   draw_selection(xctx->gctiled,0);
   xctx->move_rot= (xctx->move_rot+1) & 0x3;
   update_symbol_bboxes(xctx->move_rot, xctx->move_flip);
  }
  if(what & FLIP)
  {
   draw_selection(xctx->gctiled,0);
   xctx->move_flip = !xctx->move_flip;
   update_symbol_bboxes(xctx->move_rot, xctx->move_flip);
  }
  if(what & END)                                 /* copy selected objects */
  {
    int l, firstw, firsti;

    dbg(1, "end copy: unlink sel_file\n");
    xunlink(sel_file);
    if(xctx->deltax != 0 || xctx->deltay != 0) set_first_sel(0, -1, 0); /* reset first selected object */
    if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;

    newpropcnt=0;

    /* button released after clicking elements, without moving... do nothing */
    if(xctx->drag_elements && xctx->deltax==0 && xctx->deltay == 0) {
       xctx->ui_state &= ~STARTCOPY;
       return;
    }

    if( !xctx->kissing ) {
      dbg(1, "copy_objects(): push undo state\n");
      xctx->push_undo();
    }

    /* calculate moving symbols bboxes before actually doing the copy */
    firstw = firsti = 1;
    draw_selection(xctx->gctiled,0);
    update_symbol_bboxes(0, 0);

    /* P4 (cadence_pin_name_text.md): a pin's name view is a DERIVED object, never copied.
     * Drop any selected name views from the copy set; each copied pin regenerates its own
     * view below (synth_pin_views), bound to the copy's fresh id -- otherwise the view would
     * be duplicated as a stray real text still bound to the ORIGINAL pin. */
    {
      int t, dropped = 0;
      for(t = 0; t < xctx->texts; ++t)
        if(xctx->text[t].owner_pin_id && xctx->text[t].sel) { xctx->text[t].sel = 0; dropped = 1; }
      if(dropped) { xctx->need_reb_sel_arr = 1; rebuild_selected_array(); }
    }

    for(i=0;i<xctx->lastsel; ++i)
    {
      n = xctx->sel_array[i].n;
      if(xctx->sel_array[i].type == WIRE)
      {
        xctx->prep_hash_wires=0;
        firstw = 0;
        check_wire_storage();
        if(xctx->rotatelocal) {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->wire[n].x1, xctx->wire[n].y1,
            xctx->wire[n].x1, xctx->wire[n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->wire[n].x1, xctx->wire[n].y1,
            xctx->wire[n].x2, xctx->wire[n].y2, xctx->rx2,xctx->ry2);
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->wire[n].x1, xctx->wire[n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->wire[n].x2, xctx->wire[n].y2, xctx->rx2,xctx->ry2);
        }
        if( xctx->wire[n].sel & (SELECTED|SELECTED1) )
        {
         xctx->rx1+=xctx->deltax;
         xctx->ry1+=xctx->deltay;
        }
        if( xctx->wire[n].sel & (SELECTED|SELECTED2) )
        {
         xctx->rx2+=xctx->deltax;
         xctx->ry2+=xctx->deltay;
        }
        tmpx=xctx->rx1; /* used as temporary storage */
        tmpy=xctx->ry1;
        ORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
        if( tmpx == xctx->rx2 &&  tmpy == xctx->ry2)
        {
         if(xctx->wire[n].sel == SELECTED1) xctx->wire[n].sel = SELECTED2;
         else if(xctx->wire[n].sel == SELECTED2) xctx->wire[n].sel = SELECTED1;
        }
        xctx->sel_array[i].n=xctx->wires;
        storeobject(-1, xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2,WIRE,0,xctx->wire[n].sel,xctx->wire[n].prop_ptr);
        xctx->wire[n].sel=0;

        l = xctx->wires -1;
      }
    }

    for(k=0;k<cadlayers; ++k)
    {
     for(i=0;i<xctx->lastsel; ++i)
     {
      c = xctx->sel_array[i].col;n = xctx->sel_array[i].n;
      switch(xctx->sel_array[i].type)
      {
       case LINE:
        if(c!=k) break;
        if(xctx->rotatelocal) {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->line[c][n].x1, xctx->line[c][n].y1,
            xctx->line[c][n].x1, xctx->line[c][n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->line[c][n].x1, xctx->line[c][n].y1,
            xctx->line[c][n].x2, xctx->line[c][n].y2, xctx->rx2,xctx->ry2);
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->line[c][n].x1, xctx->line[c][n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->line[c][n].x2, xctx->line[c][n].y2, xctx->rx2,xctx->ry2);
        }
        if( xctx->line[c][n].sel & (SELECTED|SELECTED1) )
        {
         xctx->rx1+=xctx->deltax;
         xctx->ry1+=xctx->deltay;
        }
        if( xctx->line[c][n].sel & (SELECTED|SELECTED2) )
        {
         xctx->rx2+=xctx->deltax;
         xctx->ry2+=xctx->deltay;
        }
        tmpx=xctx->rx1;
        tmpy=xctx->ry1;
        ORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
        if( tmpx == xctx->rx2 &&  tmpy == xctx->ry2)
        {
         if(xctx->line[c][n].sel == SELECTED1) xctx->line[c][n].sel = SELECTED2;
         else if(xctx->line[c][n].sel == SELECTED2) xctx->line[c][n].sel = SELECTED1;
        }
        xctx->sel_array[i].n=xctx->lines[c];
        storeobject(-1, xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2, LINE, c,
           xctx->line[c][n].sel, xctx->line[c][n].prop_ptr);
        xctx->line[c][n].sel=0;

        l = xctx->lines[c] - 1;
        break;

       case POLYGON:
        if(c!=k) break;
        {
          xPoly *p = &xctx->poly[c][n];
          double bx1 = 0.0, by1 = 0.0, bx2 = 0.0, by2 = 0.0;
          double *x = my_malloc(_ALLOC_ID_, sizeof(double) *p->points);
          double *y = my_malloc(_ALLOC_ID_, sizeof(double) *p->points);
          int j;
          for(j=0; j<p->points; ++j) {
            if( p->sel==SELECTED || p->selected_point[j]) {
              if(xctx->rotatelocal) {
                ROTATION(xctx->move_rot, xctx->move_flip, p->x[0], p->y[0], p->x[j], p->y[j], xctx->rx1,xctx->ry1);
              } else {
                ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1, p->x[j], p->y[j], xctx->rx1,xctx->ry1);
              }
              x[j] = xctx->rx1+xctx->deltax;
              y[j] = xctx->ry1+xctx->deltay;
            } else {
              x[j] = p->x[j];
              y[j] = p->y[j];
            }
            if(j==0 || x[j] < bx1) bx1 = x[j];
            if(j==0 || y[j] < by1) by1 = y[j];
            if(j==0 || x[j] > bx2) bx2 = x[j];
            if(j==0 || y[j] > by2) by2 = y[j];
          }
          xctx->sel_array[i].n=xctx->polygons[c];
          store_poly(-1, x, y, p->points, c, p->sel, p->prop_ptr);
          p->sel=0;
          my_free(_ALLOC_ID_, &x);
          my_free(_ALLOC_ID_, &y);
        }
        break;
       case ARC:
        if(c!=k) break;
        if(xctx->rotatelocal) {
          /* rotate center wrt itself: do nothing */
          xctx->rx1 = xctx->arc[c][n].x;
          xctx->ry1 = xctx->arc[c][n].y;
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->arc[c][n].x, xctx->arc[c][n].y, xctx->rx1,xctx->ry1);
        }
        angle = xctx->arc[c][n].a;
        if(xctx->move_flip) {
          angle = 270.*xctx->move_rot+180.-xctx->arc[c][n].b-xctx->arc[c][n].a;
        } else {
          angle = xctx->arc[c][n].a+xctx->move_rot*270.;
        }
        angle = fmod(angle, 360.);
        if(angle<0.) angle+=360.;
        xctx->arc[c][n].sel=0;
        xctx->sel_array[i].n=xctx->arcs[c];

        store_arc(-1, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                   xctx->arc[c][n].r, angle, xctx->arc[c][n].b, c, SELECTED, xctx->arc[c][n].prop_ptr);

        l = xctx->arcs[c] - 1;
        break;

       case xRECT:
        if(c!=k) break;
        if(xctx->rotatelocal) {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
            xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
            xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
        }
        RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
        xctx->rect[c][n].sel=0;
        xctx->sel_array[i].n=xctx->rects[c];
        /* following also clears extraptr */
        storeobject(-1, xctx->rx1+xctx->deltax, xctx->ry1+xctx->deltay,
                   xctx->rx2+xctx->deltax, xctx->ry2+xctx->deltay,xRECT, c, SELECTED, xctx->rect[c][n].prop_ptr);
        l = xctx->rects[c] - 1;
        flip_rotate_ellipse(&xctx->rect[c][l], xctx->move_rot, xctx->move_flip);
        break;

       case xTEXT:
        if(k!=TEXTLAYER) break;
        check_text_storage();
        if(xctx->rotatelocal) {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->text[n].x0, xctx->text[n].y0,
           xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
        }
        xctx->text[xctx->texts].txt_ptr=NULL;
        my_strdup2(_ALLOC_ID_, &xctx->text[xctx->texts].txt_ptr,xctx->text[n].txt_ptr);
        xctx->text[n].sel=0;
         dbg(2, "copy_objects(): current str=%s\n",
          xctx->text[xctx->texts].txt_ptr);
        xctx->text[xctx->texts].x0=xctx->rx1+xctx->deltax;
        xctx->text[xctx->texts].y0=xctx->ry1+xctx->deltay;
        xctx->text[xctx->texts].rot=(xctx->text[n].rot +
         ( (xctx->move_flip && (xctx->text[n].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3;
        xctx->text[xctx->texts].flip=xctx->move_flip^xctx->text[n].flip;
        set_first_sel(xTEXT, xctx->texts, 0);
        xctx->text[xctx->texts].sel=SELECTED;
        xctx->text[xctx->texts].prop_ptr=NULL;
        xctx->text[xctx->texts].font=NULL;
        xctx->text[xctx->texts].floater_instname=NULL;
        xctx->text[xctx->texts].floater_ptr=NULL;
        xctx->text[xctx->texts].owner_pin_id=0; /* copied text is real; P4 handles view-aware copy */
        my_strdup2(_ALLOC_ID_, &xctx->text[xctx->texts].prop_ptr, xctx->text[n].prop_ptr);
        my_strdup2(_ALLOC_ID_, &xctx->text[xctx->texts].floater_ptr, xctx->text[n].floater_ptr);
        my_strdup2(_ALLOC_ID_, &xctx->text[xctx->texts].floater_instname, xctx->text[n].floater_instname);
        set_text_flags(&xctx->text[xctx->texts]);
        xctx->text[xctx->texts].xscale=xctx->text[n].xscale;
        xctx->text[xctx->texts].yscale=xctx->text[n].yscale;

        l = xctx->texts;

        #if HAS_CAIRO==1 /* bbox after copy */
        customfont = set_text_custom_font(&xctx->text[l]);
        #endif
        estr = my_expand(get_text_floater(l), tclgetintvar("tabstop"));
        text_bbox(estr, xctx->text[l].xscale,
          xctx->text[l].yscale, xctx->text[l].rot,xctx->text[l].flip,
          xctx->text[l].hcenter, xctx->text[l].vcenter,
          xctx->text[l].x0, xctx->text[l].y0,
          &xctx->rx1,&xctx->ry1, &xctx->rx2,&xctx->ry2, &tmpi, &dtmp);
        my_free(_ALLOC_ID_, &estr);
        #if HAS_CAIRO==1
        if(customfont) {
          cairo_restore(xctx->cairo_ctx);
        }
        #endif

        xctx->sel_array[i].n=xctx->texts;
        text_register(xctx->texts);
         dbg(2, "copy_objects(): done copy string\n");
        break;
       default:
        break;
      } /* end switch(xctx->sel_array[i].type) */
     } /* end for(i=0;i<xctx->lastsel; ++i) */


    } /* end for(k=0;k<cadlayers; ++k) */

    for(i = 0; i < xctx->lastsel; ++i) {
      n = xctx->sel_array[i].n;
      if(xctx->sel_array[i].type == ELEMENT) {
        xctx->prep_hash_inst = 0;
        firsti = 0;
        check_inst_storage();
        if(xctx->rotatelocal) {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->inst[n].x0, xctx->inst[n].y0,
             xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
        } else {
          ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
             xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
        }
        xctx->inst[xctx->instances] = xctx->inst[n];
        xctx->inst[xctx->instances].prop_ptr=NULL;
        xctx->inst[xctx->instances].instname=NULL;
        xctx->inst[xctx->instances].lab=NULL;
        xctx->inst[xctx->instances].node=NULL;
        xctx->inst[xctx->instances].name=NULL;
        xctx->inst[xctx->instances].pin_sel=NULL;      /* transient pin selection: the copy
                                                        * must NOT alias the source's heap
                                                        * pin_sel buffer (pin_selection.md) */
        xctx->inst[xctx->instances].pin_sel_size=0;
        my_strdup2(_ALLOC_ID_, &xctx->inst[xctx->instances].name, xctx->inst[n].name);
        my_strdup2(_ALLOC_ID_, &xctx->inst[xctx->instances].prop_ptr, xctx->inst[n].prop_ptr);
        my_strdup2(_ALLOC_ID_, &xctx->inst[xctx->instances].lab, xctx->inst[n].lab);
        xctx->inst[n].sel=0;
        xctx->inst[xctx->instances].embed = xctx->inst[n].embed;
        xctx->inst[xctx->instances].flags = xctx->inst[n].flags;
        xctx->inst[xctx->instances].color = -10000;
        xctx->inst[xctx->instances].x0 = xctx->rx1+xctx->deltax;
        xctx->inst[xctx->instances].y0 = xctx->ry1+xctx->deltay;
        set_first_sel(ELEMENT, xctx->instances, 0);
        xctx->inst[xctx->instances].sel = SELECTED;
        xctx->inst[xctx->instances].rot = (xctx->inst[xctx->instances].rot + ( (xctx->move_flip &&
           (xctx->inst[xctx->instances].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3;
        xctx->inst[xctx->instances].flip = (xctx->move_flip? !xctx->inst[n].flip:xctx->inst[n].flip);
        my_strdup2(_ALLOC_ID_, &xctx->inst[xctx->instances].instname, xctx->inst[n].instname);
        /* the newpropcnt argument is zero for the 1st call and used in  */
        /* new_prop_string() for cleaning some internal caches. */
        if(!newpropcnt) hash_names(-1, XINSERT);
        newpropcnt++;
        new_prop_string(xctx->instances, xctx->inst[n].prop_ptr, /* sets also inst[].instname */
          tclgetboolvar("disable_unique_names"));

        update_attached_floaters(xctx->inst[n].instname, xctx->instances, 1);

        hash_names(xctx->instances, XINSERT);
        inst_register(xctx->instances); /* symbol_bbox calls translate and translate must have updated xctx->instances */
        symbol_bbox(xctx->instances-1,
             &xctx->inst[xctx->instances-1].x1, &xctx->inst[xctx->instances-1].y1,
             &xctx->inst[xctx->instances-1].x2, &xctx->inst[xctx->instances-1].y2);
      } /* if(xctx->sel_array[i].type == ELEMENT) */
    }  /* for(i = 0; i < xctx->lastsel; ++i) */
    xctx->need_reb_sel_arr=1;
    rebuild_selected_array();
    /* P4: regenerate name views for the just-copied pins. Each copy got a fresh xRect.id
     * (storeobject), so synth_pin_views() binds a NEW view to it; idempotent + symbol-mode
     * gated, so the original pins' existing views are left alone. */
    synth_pin_views();
    if(!firsti || !firstw) {
      xctx->prep_net_structs=0;
      xctx->prep_hi_structs=0;
    }
    /* build after copying and after recalculating prepare_netlist_structs() */
    check_collapsing_objects();
    /* W3: a moved/copied instance may drop a pin onto a wire (split) or lift one off (rejoin);
     * maintain re-splits at attachment points then pin-aware-merges. Gated on autotrim_wires;
     * undo owned by the enclosing move. See doc/claude/specs/wire_segment_splitting.md (W3). */
    if(tclgetboolvar("autotrim_wires")) maintain_wire_segments();
    if(xctx->hilight_nets) {
      propagate_hilights(1, 1, XINSERT_NOREPLACE);
    }
    xctx->ui_state &= ~STARTCOPY;
    xctx->x1 = xctx->y1 = xctx->x2 = xctx->y2 = xctx->deltax = xctx->deltay = 0;
    xctx->move_rot = xctx->move_flip = 0;
    set_modify(1); /* must be done before draw() if floaters are present to force cached values update */
    draw();
    xctx->rotatelocal=0;
  } /* if(what & END) */
  draw_selection(xctx->gc[SELLAYER], 0);
  if(tclgetboolvar("draw_crosshair")) draw_crosshair(3, 0); /* what = 1(clear) + 2(draw) */
}


/* order wire points and swap SELECTED1 / SELECTED2 if needed */
static void order_wire_points(int n)
{
  xWire * const wire = xctx->wire;
  double x1, y1;

  x1=wire[n].x1;
  y1=wire[n].y1;
  ORDER(wire[n].x1, wire[n].y1, wire[n].x2, wire[n].y2);
  if( x1 == wire[n].x2 && y1 == wire[n].y2) /* wire points reversed, so swap SELECTEDn */
  {
   if(wire[n].sel == SELECTED1) wire[n].sel = SELECTED2;
   else if(wire[n].sel == SELECTED2) wire[n].sel = SELECTED1;
  }
}

/* Phase III obstacle-aware L-orientation flip (defined below, next to the fluid snapshot code). */
static int fluid_ml_blocked(int ml, int sel1);
/* Phase IV P6 (min-bend): bias the fluid L orientation to a straight along-normal pin exit so the
 * P3 escape stub is unnecessary (defined below, after the fluid snapshot statics). */
static int fluid_p6_bias_ml(int sel1);
/* issue 0085 (blind-elbow diagonal fallback): full hazard classification of an L orientation --
 * superset of fluid_ml_blocked -- and its severity ranking (defined below, after the Layer-2
 * segment-test helpers they reuse). */
static int fluid_ml_hazards(int ml, int sel1);
static int fluid_mlh_sev(int h);
/* issue 0086 (future-blind elbow tie-break): does the L implied by `ml` lay copper on a co-moving
 * foreign-net pin's FINAL (post-remaining-legs) landing point? Tie-break input only (defined below,
 * after fluid_ml_hazards). */
static int fluid_ml_future_covers(int ml, int sel1);
/* issue 0086 companion: future-aware corner-slide decline (defined next to fluid_ml_future_covers) */
static int fluid_slide_future_hazard(int n, double fx, double fy, double mx, double my);
static void fltrace(const char *fmt, ...);

/* xctx->{rx1, ry1} and xctx->{rx2, ry2} are the two line points after the move.
 * they are not guaranteed to be ordered (since only one of the two points may have changed)
 * so this must be taken care for */
static void place_moved_wire(int n, int orthogonal_wiring)
{
  xWire * const wire = xctx->wire;


  /* Need to dynamically assign `manhattan_lines` to each wire. Otherwise, a single
   * `manhattan_lines` value gets forced on all wires connected to a moved object*/
  if(orthogonal_wiring) {
    recompute_orthogonal_manhattanline(xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
    /* incremental_wire_reroute.md Phase III (§5/§6): obstacle-aware L-orientation selection. The
     * naive manhattan L can lay one of its two legs straight across a STATIONARY device between two
     * of its distinct-net pins -- a P2 short (R18's M-riser leg sweeping through ammeter v8). If the
     * orientation recompute chose is blocked and the OTHER orientation is clear, flip
     * manhattan_lines: the four placement branches below then lay the clean L between the SAME two
     * endpoints (rx1,ry1)-(rx2,ry2), so connectivity (P1) is unchanged by construction. Gated on
     * fluid_editing (default off => never flips => byte-identical), a valid START name snapshot, a
     * non-rotating move, and a stretching (single-endpoint) wire. Pure function of (snapshot,
     * rx1..ry2) => deterministic and release==stepwise (recompute yields only ml 1 or 2). */
    if(tclgetboolvar("fluid_editing") && xctx->move_rot == 0 && xctx->move_flip == 0 &&
       (wire[n].sel == SELECTED1 || wire[n].sel == SELECTED2)) {
      int sel1 = (wire[n].sel == SELECTED1);
      int ml0 = xctx->manhattan_lines, ml1 = (ml0 == 1) ? 2 : 1;
      /* fluid_ml_hazards() returns 0 when there is no START name snapshot, so no flip fires unless a
       * fluid stretch armed one -- the snapshot-presence gate lives inside the helper (its statics
       * are declared below this function). issue 0085: the old fluid_ml_blocked test (stationary
       * device two-pin bridge only) was blind to the L plowing a CO-MOVING pin (the moved device's
       * own far pin) and to a T-contact with a stationary wire's endpoint (C12's stub, after_5.sch),
       * so it picked "clean" orientations that shorted. fluid_ml_hazards classifies all four classes;
       * pick the orientation with the strictly LOWER severity (fluid_mlh_sev: pristine-net-verified
       * classes outrank the heuristic stray-contact class, so a proven device bridge still flips to a
       * merely stray-flagged orientation exactly as the old code did). Ties keep ml0 -- when both are
       * hazardous the 0085 partition re-check + rigid-relay fallback in move_objects owns P2. */
      int h0 = fluid_ml_hazards(ml0, sel1);
      int h1 = fluid_ml_hazards(ml1, sel1);
      int s0 = fluid_mlh_sev(h0), s1 = fluid_mlh_sev(h1);
      if(h0 || h1)
        fltrace("FLTRACE elbow: wire=%d sel1=%d ml0=%d h0=0x%x h1=0x%x -> ml=%d r1=(%g,%g) r2=(%g,%g)\n",
                n, sel1, ml0, h0, h1, (s1 < s0) ? ml1 : ml0,
                xctx->rx1, xctx->ry1, xctx->rx2, xctx->ry2);
      if(s1 < s0) {
        xctx->manhattan_lines = ml1;                 /* P2 obstacle flip (Phase III + 0085 classes) */
      } else if(!s0 && !s1) {
        /* issue 0086: future-aware tie-break, BEFORE the P6 bias. Both orientations are P2-clear
         * for THIS leg, but during leg 0 of the 0081 X-then-Y decomposition one of them can paint
         * the corridor a co-moving pin lands in after leg 1 -- where the follow stretch is
         * degenerate (a straight extension, no elbow freedom) so the short is unavoidable and the
         * whole attempt collapses to the rigid diagonal relay (before_3.sch -> after_6.sch: leg-0's
         * H-first corner at (-250,-90) == R18.M's final landing). If exactly one orientation avoids
         * every future landing, pick it; on a tie (both clear / both covered) fall through to P6
         * exactly as before. fluid_leg_future_* are zero outside decomposed legs => inert there. */
        int f0 = fluid_ml_future_covers(ml0, sel1);
        int f1 = fluid_ml_future_covers(ml1, sel1);
        if(f0 && !f1) {
          xctx->manhattan_lines = ml1;               /* only ml1 avoids the future landing */
        } else if(f0 == f1) {
        /* Phase IV P6 (min-bend): both orientations are P2-clear, so the choice is free BELOW P2 in
         * the conflict order (P1=P2 > P3 > P5 > P4 > P7 > P6). Prefer the orientation whose pin leg
         * exits ALONG the moving pin's escape normal -- a straight P3 exit that insert_exit_stubs then
         * SKIPS (move.c:1648-1649), removing the redundant escape-stub staircase bend at IDENTICAL
         * length. Returns 0 (keep ml0) unless the along-normal orientation is a proven, strict win. */
          int p6 = fluid_p6_bias_ml(sel1);
          if(p6) xctx->manhattan_lines = p6;
        }
        /* (!f0 && f1): keep ml0; P6 must not flip INTO the future-covered orientation */
        /* trace AFTER the whole decision (incl. P6) so `-> ml=` is the COMMITTED orientation --
         * review wf_b333bd95: printing the pre-P6 guess misreported the f0==f1 case */
        if(f0 || f1)
          fltrace("FLTRACE elbow-future: wire=%d sel1=%d ml0=%d f0=%d f1=%d -> ml=%d\n",
                  n, sel1, ml0, f0, f1, xctx->manhattan_lines);
      }
      /* (s0 <= s1, either hazardous): keep ml0 -- no strictly better orientation exists; the Layer-2
       * stop-short detour (pin-incident device straddles) and the 0085 attempt-2 rigid relay (all
       * remaining classes) own P2 downstream. */
    }
  }

  /* wire x1,y1 point was moved
   *
   *                          x1,y1(old)       rx2,ry2
   *           -----------------o-----------------o
   *          |       (H)
   * selected |(V)
   *          |
   *          o
   *       rx1,ry1(new)
   */
  if(wire[n].sel == SELECTED1 && (xctx->manhattan_lines & 1)) /* H - V */
  {
   int last;
   wire[n].x1 = xctx->rx1;
   wire[n].y1 = xctx->ry1;
   wire[n].x2 = xctx->rx1;
   wire[n].y2 = xctx->ry2;
   order_wire_points(n);
   if( xctx->rx1 != xctx->rx2) {
     /* the L-jog's second leg is the SAME net as wire[n] -> inherit its prop (the bus
      * label etc.). Matters when the original wire[n] degenerates to zero length and is
      * collapsed away (a colinear slide): this stored segment is then the survivor, so
      * dropping the prop here loses the wire's lab= entirely (TC12/R19). */
     storeobject(-1, xctx->rx1,xctx->ry2,xctx->rx2,xctx->ry2,WIRE,0,0,wire[n].prop_ptr);
     last = xctx->wires-1;
     order_wire_points(last);
   }
  }

  /* wire x2,y2 point was moved
   *
   *        rx1,ry1            x2,y2(old)
   *           o-----------------o-----------------
   *                                      (H)      |
   *                                            (V)| selected
   *                                               |
   *                                               o
   *                                            rx2,ry2(new)
   */
  else if(wire[n].sel == SELECTED2 && (xctx->manhattan_lines & 1)) /* H - V */
  {
   int last;
   wire[n].x1 = xctx->rx2;
   wire[n].y1 = xctx->ry1;
   wire[n].x2 = xctx->rx2;
   wire[n].y2 = xctx->ry2;
   order_wire_points(n);
   if( xctx->rx1 != xctx->rx2) {
     storeobject(-1, xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry1,WIRE,0,0,wire[n].prop_ptr);
     last = xctx->wires-1;
     order_wire_points(last);
   }
  }

  /* wire x1,y1 point was moved
   *
   *                           x1,y1(old)       rx2,ry2
   *                             o-----------------o
   *                                               |
   *                                            (V)|
   *                  (H) selected                 |
   *           o-----------------------------------
   *        rx1,ry1(new)
   */
  else if(wire[n].sel == SELECTED1 && (xctx->manhattan_lines & 2)) /* V - H */
  {
   int last;
   wire[n].x1 = xctx->rx1;
   wire[n].y1 = xctx->ry1;
   wire[n].x2 = xctx->rx2;
   wire[n].y2 = xctx->ry1;
   order_wire_points(n);
   if( xctx->ry1 != xctx->ry2) {
     storeobject(-1, xctx->rx2,xctx->ry1,xctx->rx2,xctx->ry2,WIRE,0,0,wire[n].prop_ptr);
     last = xctx->wires-1;
     order_wire_points(last);
   }
  }

  /* wire x2,y2 point was moved
   *
   *        rx1,ry1            x2,y2(old)
   *           o-----------------o
   *           |
   *           |(V)
   *           |      (H) selected
   *            -----------------------------------o
   *                                            rx2,ry2(new)
   */
  else if(wire[n].sel == SELECTED2 && (xctx->manhattan_lines & 2)) /* V - H */
  {
   int last;
   wire[n].x1 = xctx->rx1;
   wire[n].y1 = xctx->ry2;
   wire[n].x2 = xctx->rx2;
   wire[n].y2 = xctx->ry2;
   order_wire_points(n);
   if( xctx->ry1 != xctx->ry2) {
     storeobject(-1, xctx->rx1,xctx->ry1,xctx->rx1,xctx->ry2,WIRE,0,0,wire[n].prop_ptr);
     last = xctx->wires-1;
     order_wire_points(last);
   }
  }

  else /* no manhattan or traslation since both line points moved */
  {
   wire[n].x1 = xctx->rx1;
   wire[n].y1 = xctx->ry1;
   wire[n].x2 = xctx->rx2;
   wire[n].y2 = xctx->ry2;
   order_wire_points(n);
  }
}

/* Does (x,y) coincide with instance pin (px,py)? Tolerance = cadsnap/2, the SAME
 * predicate select_attached_nets()'s endpoint_near() (select.c) uses to grab wires
 * for stretching -- so the two ends of the stretch pipeline agree on "on the pin":
 * a wire grabbed at a sub-grid-near pin is recognized by the corner-slide pin tests
 * too, instead of the corner-slide silently failing its exact `==` test and letting
 * the wire jog (issue 0046). Exact on grid-aligned designs (endpoints sit on pins,
 * and adjacent pins are cadsnap apart > cadsnap/2, so no false neighbour match). */
static int point_near_pin(double px, double py, double x, double y)
{
  double tol = tclgetdoublevar("cadsnap") / 2.0;
  if(tol < 1e-6) tol = 1e-6;
  return fabs(px - x) <= tol && fabs(py - y) <= tol;
}

/* Is (px,py) a point where a straight STATIONARY wire run -- PERPENDICULAR to the current
 * move axis -- passes THROUGH? Two collinear, oppositely-directed stationary wire endpoints
 * meeting there is the signature of a mid-span TAP that the wire-segment-splitting feature
 * broke into abutting collinear segments (doc/claude/specs/wire_segment_splitting.md).
 * Dragging the shared endpoint of such a PERPENDICULAR run bends it off-axis -> a detour;
 * so a stub anchored there (or a perpendicular slide candidate whose far end lands there)
 * must JOG/stay put instead of sliding.
 *
 * The run must be PERPENDICULAR to the move: a run PARALLEL to the move slides cleanly ALONG
 * itself (a device tapping a rail/bus and dragged along it -- the corner-slide we must NOT
 * suppress), so those are deliberately NOT reported. Uses xctx->deltax/deltay (the move axis,
 * valid inside compute_wire_slide, the sole caller). Mirrors select.c wire_through_tap_arm();
 * exact == compare -- split points sit on exact grid-aligned pin coords. */
static int point_is_collinear_pass(double px, double py)
{
  int a, b;
  double ax, ay, bx, by, cross, dot;
  for(a = 0; a < xctx->wires; a++) {
    if(xctx->wire[a].sel) continue; /* only STATIONARY wires form a "staying-put" run */
    if(xctx->wire[a].x1 == px && xctx->wire[a].y1 == py)      { ax = xctx->wire[a].x2 - px; ay = xctx->wire[a].y2 - py; }
    else if(xctx->wire[a].x2 == px && xctx->wire[a].y2 == py) { ax = xctx->wire[a].x1 - px; ay = xctx->wire[a].y1 - py; }
    else continue;
    if(ax == 0 && ay == 0) continue;
    /* keep only runs PERPENDICULAR to the move (vertical move -> horizontal run ay==0, and
     * vice-versa); a run parallel to the move slides cleanly and must not be blocked. */
    if(xctx->deltay != 0.0 && ay != 0.0) continue;
    if(xctx->deltax != 0.0 && ax != 0.0) continue;
    for(b = a + 1; b < xctx->wires; b++) {
      if(xctx->wire[b].sel) continue;
      if(xctx->wire[b].x1 == px && xctx->wire[b].y1 == py)      { bx = xctx->wire[b].x2 - px; by = xctx->wire[b].y2 - py; }
      else if(xctx->wire[b].x2 == px && xctx->wire[b].y2 == py) { bx = xctx->wire[b].x1 - px; by = xctx->wire[b].y1 - py; }
      else continue;
      if(bx == 0 && by == 0) continue;
      cross = ax * by - ay * bx;   /* 0  => collinear      */
      dot   = ax * bx + ay * by;   /* <0 => opposite sense */
      if(cross == 0 && dot < 0) return 1;
    }
  }
  return 0;
}

/* is (x,y) on a pin of a FIXED (non-selected, i.e. non-moving) instance? */
static int point_on_fixed_pin(double x, double y)
{
  int inst, r, rects;
  double px, py;
  for(inst = 0; inst < xctx->instances; inst++) {
    if(xctx->inst[inst].sel) continue;       /* skip moving instances */
    if(xctx->inst[inst].ptr < 0) continue;
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; r++) {
      get_inst_pin_coord(inst, r, &px, &py);
      if(point_near_pin(px, py, x, y)) return 1;
    }
  }
  return 0;
}

/* is (x,y) on a pin of a MOVING (selected) instance? The corner-slide only applies
 * when the stretch is DRIVEN by a moving instance pin. A wire grabbed at a wire-wire
 * junction (its moving end coincides with a dragged wire's endpoint, not a pin) must
 * stay anchored at that junction, not slide (issue 0014). */
static int point_on_moving_pin(double x, double y)
{
  int inst, r, rects;
  double px, py;
  for(inst = 0; inst < xctx->instances; inst++) {
    if(!xctx->inst[inst].sel) continue;      /* only MOVING instances */
    if(xctx->inst[inst].ptr < 0) continue;
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; r++) {
      get_inst_pin_coord(inst, r, &px, &py);
      if(point_near_pin(px, py, x, y)) return 1;
    }
  }
  return 0;
}

/* Corner-slide (wire-editing Phase 4, Issues D1/D2/D4 -> R7/R8). After a stretch
 * move has partially selected the wires attached to the moved pins (one endpoint
 * each, via select_attached_nets()), a wire that runs PERPENDICULAR to the move
 * and forms a CORNER with another wire should SLIDE: translate so the corner moves
 * with the pin, rather than freezing while place_moved_wire() grows a jog stub at
 * the moved end (the "frozen corner + spurious stub" of Issue D1/D2).
 *
 * Rule, iterated to a fixpoint so a chain of corners slides together:
 *   - take each partially-selected (single-endpoint) wire perpendicular to the move;
 *   - require its MOVING endpoint to sit on a MOVING instance pin -- i.e. the stretch
 *     is driven by a dragged component, not by a dragged wire. A wire grabbed at a
 *     wire-wire junction (moving end on another wire's endpoint, no pin there) stays
 *     anchored, so dragging a wire never pulls a perpendicular wire off the junction
 *     (issue 0014);
 *   - if its FAR (non-moving) endpoint sits on a FIXED instance pin, leave it alone
 *     -> it must JOG to keep that connection (guard R18/TC15);
 *   - else if the far endpoint is a free dangling end (no other wire there), leave
 *     it alone -> it JOGS, anchoring the free end (TC3);
 *   - else (the far end meets another wire = a corner) PROMOTE it to a full
 *     selection so both endpoints translate, and select the coincident endpoint of
 *     every neighbour wire at that corner so they stretch to follow (R2).
 *
 * Caller guards this to orthogonal-wiring, axis-aligned, non-rotating moves.
 * Uses xctx->deltax/deltay only to know the move axis. Rebuilds sel_array so the
 * move-commit loop visits the promoted/propagated wires. */
static void compute_wire_slide(void)
{
  int n, m, changed;
  double fx, fy;                        /* far (non-moving) endpoint of wire n */
  double mx, my;                        /* moving (selected) endpoint of wire n */
  int dxnz = (xctx->deltax != 0.0);     /* horizontal move */
  int dynz = (xctx->deltay != 0.0);     /* vertical move */
  xWire * const wire = xctx->wire;

  if(dxnz == dynz) return;              /* not a pure axis-aligned move: nothing to do */

  do {
    changed = 0;
    for(n = 0; n < xctx->wires; n++) {
      int has_corner = 0;
      /* only single-endpoint (stretching) wires; SELECTED (full) and 0 are skipped */
      if(wire[n].sel != SELECTED1 && wire[n].sel != SELECTED2) continue;
      /* perpendicular to the move? vertical move -> horizontal wire, and vice-versa */
      if(dynz && wire[n].y1 != wire[n].y2) continue;
      if(dxnz && wire[n].x1 != wire[n].x2) continue;
      /* far endpoint = the one NOT selected; moving endpoint = the selected one */
      if(wire[n].sel == SELECTED1) { fx = wire[n].x2; fy = wire[n].y2; mx = wire[n].x1; my = wire[n].y1; }
      else                         { fx = wire[n].x1; fy = wire[n].y1; mx = wire[n].x2; my = wire[n].y2; }
      /* (a) slide only when the moving end is driven by a moving instance pin; a wire
       * grabbed at a wire-wire junction stays anchored there (issue 0014) */
      if(!point_on_moving_pin(mx, my)) continue;
      /* never slide a wire off a fixed pin -> let it jog (keeps the connection) */
      if(point_on_fixed_pin(fx, fy)) continue;
      /* far end where a straight run passes through (a split mid-span tap) is not a
       * corner: jog/stay so moving a tap never drags the through-wire (the kiss stub
       * dropped at such a tap stays a clean single stub). */
      if(point_is_collinear_pass(fx, fy)) continue;
      /* a corner needs another wire endpoint coincident with the far end */
      for(m = 0; m < xctx->wires; m++) {
        if(m == n) continue;
        if((wire[m].x1 == fx && wire[m].y1 == fy) ||
           (wire[m].x2 == fx && wire[m].y2 == fy)) { has_corner = 1; break; }
      }
      if(!has_corner) continue;        /* free dangling far end -> jog (TC3) */
      /* issue 0086: the corner slide is a P4 aesthetic -- decline it when the slid copper (or a
       * dragged neighbour's stretched run) would park on a co-moving foreign-net pin's FINAL
       * landing point, because the later decomposition leg then has NO elbow freedom left and the
       * short is guaranteed. Declining falls back to the ordinary jog relay, whose hazard-aware
       * elbow (fluid_ml_hazards + fluid_ml_future_covers) picks a clean L. Inert outside
       * decomposed fluid legs (fluid_leg_future_* zero => helper returns 0). */
      if(fluid_slide_future_hazard(n, fx, fy, mx, my)) {
        fltrace("FLTRACE slide: wire=%d corner=(%g,%g) DECLINE (future pin landing on slid copper)\n",
                n, fx, fy);
        continue;
      }
      /* issue 0086 review (wf_b333bd95 F1): the corner is SHARED. Accepting THIS slide promotes
       * every co-candidate wire at the corner whose OTHER end is already pin-grabbed to full
       * SELECTED (the loop below adds the second flag; select_wire folds SELECTED1|SELECTED2 to
       * SELECTED, select.c:965) -- a RIGID translate of exactly the copper that co-candidate's own
       * hazard test would (or did) decline, bypassing the 0086 decline entirely and, order-
       * dependently, even skipping its candidacy test (line 1465 skips SELECTED). So veto the
       * whole corner group: if any co-candidate that would fold to full SELECTED is itself
       * future-hazardous as a rigid slide, this wire must jog too. Inert outside decomposed
       * fluid legs (fluid_slide_future_hazard returns 0). */
      {
        int hz = 0;
        for(m = 0; m < xctx->wires && !hz; m++) {
          if(m == n) continue;
          if(wire[m].x1 == fx && wire[m].y1 == fy && (wire[m].sel & SELECTED2) &&
             fluid_slide_future_hazard(m, fx, fy, wire[m].x2, wire[m].y2)) hz = 1;
          if(wire[m].x2 == fx && wire[m].y2 == fy && (wire[m].sel & SELECTED1) &&
             fluid_slide_future_hazard(m, fx, fy, wire[m].x1, wire[m].y1)) hz = 1;
        }
        if(hz) {
          fltrace("FLTRACE slide: wire=%d corner=(%g,%g) DECLINE (co-candidate at corner is future-hazardous)\n",
                  n, fx, fy);
          continue;
        }
      }

      /* slide: translate this wire, drag the neighbour endpoints at the corner */
      wire[n].sel = SELECTED;
      changed = 1;
      for(m = 0; m < xctx->wires; m++) {
        if(m == n) continue;
        if(wire[m].x1 == fx && wire[m].y1 == fy && !(wire[m].sel & (SELECTED | SELECTED1))) {
          select_wire(m, SELECTED1, 3, 0); changed = 1;
        }
        if(wire[m].x2 == fx && wire[m].y2 == fy && !(wire[m].sel & (SELECTED | SELECTED2))) {
          select_wire(m, SELECTED2, 3, 0); changed = 1;
        }
      }
    }
  } while(changed);

  rebuild_selected_array();
}

/* is (x,y) on a pin of ANY instance (moving or fixed)? */
static int point_on_any_pin(double x, double y)
{
  return point_on_fixed_pin(x, y) || point_on_moving_pin(x, y);
}

/* does any wire other than `self` touch (x,y) (endpoint OR mid-span)? */
static int point_on_other_wire(double x, double y, int self)
{
  int m;
  for(m = 0; m < xctx->wires; m++) {
    if(m == self) continue;
    if(touch(xctx->wire[m].x1, xctx->wire[m].y1, xctx->wire[m].x2, xctx->wire[m].y2, x, y))
      return 1;
  }
  return 0;
}

/* does any wire other than `self` that touches (x,y) carry net name `lab`? Used to
 * confirm the moved pin STAYS on the stub's net once the stub is dropped -- the
 * connectivity-preserving condition for removing a named stub (issue 0040). Compares
 * the `lab` prop token, which prepare_netlist_structs() has baked with the wire's
 * derived net name; `lab` is the caller's own COPY of the stub's token (get_tok_value
 * returns a shared buffer the loop below reuses). */
static int other_wire_same_lab(double x, double y, int self, const char *lab)
{
  int m;
  for(m = 0; m < xctx->wires; m++) {
    if(m == self) continue;
    if(!touch(xctx->wire[m].x1, xctx->wire[m].y1, xctx->wire[m].x2, xctx->wire[m].y2, x, y)) continue;
    if(!strcmp(lab, get_tok_value(xctx->wire[m].prop_ptr, "lab", 0))) return 1;
  }
  return 0;
}

/* predicate for wire_delete_compact(): delete wires flagged in the arg array */
static int wire_doomed_flag(int n, void *arg) { return ((unsigned short *)arg)[n]; }

/* was (x,y) an endpoint of a wire this stretch move grabbed? (coordinate snapshot
 * taken in select_attached_nets before the commit re-creates the wires) */
static int coord_was_grabbed(double x, double y)
{
  int k;
  for(k = 0; k < xctx->stretch_grabbed_n; k++)
    if(xctx->stretch_grabbed_xy[2*k] == x && xctx->stretch_grabbed_xy[2*k+1] == y) return 1;
  return 0;
}

/* Move-scoped orphan removal (wire-editing Phase 5, Issue D3 -> R12, TC9). A stretch
 * move of a component can leave a redundant dangling stub hanging off the moved pin:
 * a wire with exactly ONE endpoint free (on no pin and no other wire) whose other
 * endpoint sits on the MOVED component's pin while that pin is ALREADY served by
 * another wire. Such a stub carries no connection of its own and can be dropped
 * without changing connectivity (the bad2 residue: a vertical tail off pin M that
 * the horizontal rail already connects). Scoped tightly so it never over-reaches:
 *   - the FREE endpoint must match an endpoint of a wire THIS move grabbed (the
 *     coordinate snapshot from select_attached_nets), so a pre-existing wire the
 *     moved pin merely landed on -- a distinct net -- is never deleted (TC11). We
 *     scope by captured geometry, not the live wire id/sel bits, because the
 *     kissing/commit pipeline re-creates the wires (re-minting ids, clearing sel)
 *     before move END;
 *   - the kept (non-free) endpoint must be on a MOVING instance pin, so only stubs
 *     at the moved pin are candidates (stubs on fixed pins are untouched);
 *   - that pin must ALSO be touched by another wire, so removal never disconnects a
 *     pin the stub alone reached (R16 no accidental break);
 *   - a wire with both ends free, or both ends connected, is left alone.
 * Gated on stretch_select and run after trim_wires() so it sees merged/deduped
 * geometry (else an overlapping colinear pair would look like a stub-on-a-wire). */
static void remove_move_orphan_wires(void)
{
  int i, removed = 0;
  unsigned short *doomed = NULL;
  if(xctx->wires == 0) return;
  my_realloc(_ALLOC_ID_, &doomed, xctx->wires * sizeof(unsigned short));
  memset(doomed, 0, xctx->wires * sizeof(unsigned short));
  for(i = 0; i < xctx->wires; i++) {
    int free1, free2;
    double ax, ay, bx, by, fx, fy, kx, ky;
    ax = xctx->wire[i].x1; ay = xctx->wire[i].y1;
    bx = xctx->wire[i].x2; by = xctx->wire[i].y2;
    free1 = !point_on_any_pin(ax, ay) && !point_on_other_wire(ax, ay, i);
    free2 = !point_on_any_pin(bx, by) && !point_on_other_wire(bx, by, i);
    if(free1 == free2) continue;                  /* need exactly one free (dangling) end */
    if(free1) { fx = ax; fy = ay; kx = bx; ky = by; }   /* free / kept endpoints */
    else      { fx = bx; fy = by; kx = ax; ky = ay; }
    /* the free end must descend from a wire THIS move grabbed -- so a pre-existing
     * wire the moved pin merely landed on (TC11) is never deleted */
    if(!coord_was_grabbed(fx, fy)) continue;
    /* kept end must be on a MOVED pin (this move produced/dragged the stub there) ... */
    if(!point_on_moving_pin(kx, ky)) continue;
    /* ... and that pin must be redundantly served by another wire, else the stub is
     * the sole link to the pin and must stay */
    if(!point_on_other_wire(kx, ky, i)) continue;
    /* A named stub is dropped only when the moved pin STAYS on that same net via another
     * wire; otherwise deleting it would silently rename/lose the node (issue 0040). Compare
     * the net name against the serving wires -- NOT merely test lab non-empty:
     * prepare_netlist_structs() bakes the derived net name into EVERY named-net wire's
     * prop_ptr lab=, so a non-empty test wrongly protected ordinary same-net stubs (it
     * broke the redundant-stub cleanup, TC9). An anonymous stub (empty lab) stays removable
     * on the geometric point_on_other_wire redundancy above, as before. */
    {
      char *stublab = NULL;
      int keep;
      my_strdup(_ALLOC_ID_, &stublab, get_tok_value(xctx->wire[i].prop_ptr, "lab", 0));
      keep = (stublab && stublab[0] && !other_wire_same_lab(kx, ky, i, stublab));
      my_free(_ALLOC_ID_, &stublab);
      if(keep) continue;
    }
    doomed[i] = 1;
    removed++;
  }
  if(removed) {
    wire_delete_compact(wire_doomed_flag, doomed);
    xctx->prep_hash_wires = 0;
    xctx->prep_net_structs = 0;
    xctx->prep_hi_structs = 0;
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
    /* the trim is otherwise invisible -- tell the user a redundant wire was auto-removed
     * so a post-move connectivity change is never silent (issue 0040) */
    if(has_x) {
      char msg[80];
      my_snprintf(msg, S(msg), "auto-removed %d redundant wire%s after move",
                  removed, removed == 1 ? "" : "s");
      tclvareval("if {[info procs ciw_echo] ne {}} {ciw_echo {", msg, "}}", NULL);
    }
  }
  my_free(_ALLOC_ID_, &doomed);
}

/* Exit-stub preservation (wire-editing Phase 6, Issue E -> R13, TC10; nice_drag_rerouting
 * Phase 3 §8). The "dream": after a stretch move, a short stub leaves each moved pin along
 * the pin's OUTWARD NORMAL (its natural lead direction) before the route's first bend, so the
 * wire physically exits the pin the way the symbol draws its lead rather than turning
 * immediately. A uniform, symbol-driven rule (the most predictable one -- Issue E).
 *
 * For each MOVING (selected) instance pin carrying exactly one attached wire (the
 * route's first leg):
 *   - the pin's outward normal comes from get_pin_escape_normal() (nice_drag_rerouting §6:
 *     nearest body edge; e.g. res.sym pin M sits at the top edge so it exits +y). This
 *     replaced the earlier crude centroid dominant-axis heuristic; the two agree on
 *     symmetric symbols and the getter is better on asymmetric/corner pins.
 *   - if the first leg already runs ALONG that normal (a straight exit) leave it: a
 *     colinear stub would just be merged back by trim_wires, and a straight exit can't
 *     cross the symbol body, so no stub is needed;
 *   - if the first leg runs PERPENDICULAR to the normal (it bends right at the pin),
 *     SLIDE that leg one minor grid out along the normal and fill the gap at the pin
 *     with the short stub. The leg's far endpoint is dragged the same one grid so the
 *     leg stays axis-aligned, and every wire endpoint coincident with that far end is
 *     dragged too, so the connected riser/corner follows -- the route stays Manhattan
 *     and electrically identical (same net, still connected: G1/R16, netlist unchanged).
 *
 * Guards mirror compute_wire_slide: never pull a leg's far end off a FIXED pin (would
 * disconnect it); only when the far end meets another wire (a real corner/route, not a
 * lone dangling stub). Stub length = one minor grid (cadsnap) -- the grid the route
 * snaps to (the fixtures pin cadsnap=10; documented constant).
 *
 * Runs at move END AFTER trim_wires()/remove_move_orphan_wires() so the cleanup never
 * eats the freshly inserted stub (and the perpendicular bend just past it keeps it from
 * looking like a colinear degree-2 merge candidate anyway). Gated on wire_exit_stub
 * (default OFF): the biggest behavior change in the plan, shipped dark. */
/* Stored wires MUST be coordinate-ordered (x1<x2, or x1==x2 && y1<y2). touch() (clip.c) --
 * used by the netlister's name_attached_inst_to_net() to bind an instance pin to the wire that
 * reaches it -- documents this as its precondition ("works if segments are given left to
 * right") and returns 0 on an unordered wire. An exit stub is stored pin->tip, so a -x/-y
 * escape normal (tip below/left of the pin) yields an UNORDERED wire whose touch() then fails,
 * silently dropping the pin onto a fresh #net (the Phase-3 disconnect: a +y stub was ordered
 * by luck and bound, a -y stub was not). Normalize every wire this function rewrites. */
static void order_wire_coords(int n)
{
  xWire *w = &xctx->wire[n];
  if(w->x1 > w->x2 || (w->x1 == w->x2 && w->y1 > w->y2)) {
    double t;
    t = w->x1; w->x1 = w->x2; w->x2 = t;
    t = w->y1; w->y1 = w->y2; w->y2 = t;
  }
}

static void insert_exit_stubs(void)
{
  int inst, r, rects, n, m;
  double grid = tclgetdoublevar("cadsnap");
  int nwires0 = xctx->wires;   /* snapshot: stubs stored below (index >= nwires0) must NOT re-enter
                                * the pin/corner scans of later pins/instances (issue 0047) */
  if(grid <= 0.0) grid = 1.0;
  for(inst = 0; inst < xctx->instances; inst++) {
    const char *itype;
    if(!xctx->inst[inst].sel) continue;        /* only MOVING instances */
    if(xctx->inst[inst].ptr < 0) continue;
    itype = xctx->sym[xctx->inst[inst].ptr].type;
    if(itype && !strcmp(itype, "label")) continue;  /* net labels have no body/escape (§2) */
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; r++) {
      double px, py, nx, ny, sx, sy, fx, fy, nfx, nfy;
      int wfound = -1, endsel = 0, cnt = 0, has_corner = 0;
      get_inst_pin_coord(inst, r, &px, &py);
      /* outward escape normal (nice_drag_rerouting §6, geometry nearest-edge -- replaces the
       * old crude centroid dominant-axis heuristic; agrees with it on symmetric symbols like
       * res, better on asymmetric/corner pins). */
      get_pin_escape_normal(inst, r, &nx, &ny);
      if(nx == 0.0 && ny == 0.0) continue;
      /* exactly one wire endpoint exactly on the pin = the route's first leg */
      for(n = 0; n < nwires0; n++) {
        if(xctx->wire[n].x1 == px && xctx->wire[n].y1 == py)      { cnt++; wfound = n; endsel = 1; }
        else if(xctx->wire[n].x2 == px && xctx->wire[n].y2 == py) { cnt++; wfound = n; endsel = 2; }
      }
      if(cnt != 1) continue;
      n = wfound;
      if(endsel == 1) { fx = xctx->wire[n].x2; fy = xctx->wire[n].y2; }
      else            { fx = xctx->wire[n].x1; fy = xctx->wire[n].y1; }
      /* need the first leg PERPENDICULAR to the normal: vertical normal -> horizontal
       * leg, horizontal normal -> vertical leg. A leg colinear with the normal (straight
       * exit) or diagonal is left alone. */
      if(ny != 0.0 && xctx->wire[n].y1 != xctx->wire[n].y2) continue; /* vert normal needs horiz leg */
      if(nx != 0.0 && xctx->wire[n].x1 != xctx->wire[n].x2) continue; /* horiz normal needs vert leg */
      /* never pull the far end off a fixed (non-moving) pin -> would disconnect it */
      if(point_on_fixed_pin(fx, fy)) continue;
      /* require a real corner/route at the far end (another wire endpoint there) */
      for(m = 0; m < nwires0; m++) {
        if(m == n) continue;
        if((xctx->wire[m].x1 == fx && xctx->wire[m].y1 == fy) ||
           (xctx->wire[m].x2 == fx && xctx->wire[m].y2 == fy)) { has_corner = 1; break; }
      }
      if(!has_corner) continue;

      /* slide the first leg one grid out along the normal; drag the corner with it */
      sx  = px + grid * nx; sy  = py + grid * ny;   /* stub tip = leg's new pin end  */
      nfx = fx + grid * nx; nfy = fy + grid * ny;   /* leg's new far (corner) end     */
      for(m = 0; m < nwires0; m++) {                /* drag every neighbour at the corner */
        if(m == n) continue;
        if(xctx->wire[m].x1 == fx && xctx->wire[m].y1 == fy) { xctx->wire[m].x1 = nfx; xctx->wire[m].y1 = nfy; order_wire_coords(m); }
        if(xctx->wire[m].x2 == fx && xctx->wire[m].y2 == fy) { xctx->wire[m].x2 = nfx; xctx->wire[m].y2 = nfy; order_wire_coords(m); }
      }
      if(endsel == 1) { xctx->wire[n].x1 = sx; xctx->wire[n].y1 = sy; xctx->wire[n].x2 = nfx; xctx->wire[n].y2 = nfy; }
      else            { xctx->wire[n].x2 = sx; xctx->wire[n].y2 = sy; xctx->wire[n].x1 = nfx; xctx->wire[n].y1 = nfy; }
      order_wire_coords(n);                          /* keep the slid leg ordered (touch() precond) */
      /* fill the gap at the pin with the short exit stub (inherits the leg's net prop); stored
       * pin->tip, so ORDER it -- a -x/-y escape normal would otherwise store it unordered and
       * touch() would fail to bind the pin (the disconnect). */
      storeobject(-1, px, py, sx, sy, WIRE, 0, 0, xctx->wire[n].prop_ptr);
      order_wire_coords(xctx->wires - 1);            /* the just-appended stub is the last wire */
    }
  }
  xctx->prep_hash_wires = 0;
  xctx->prep_net_structs = 0;
  xctx->prep_hi_structs = 0;
  xctx->need_reb_sel_arr = 1;
  set_modify(1);
}

/* Phase 2 (doc/claude/specs/nice_drag_rerouting.md §6; geometry-only per the resolved §10.1):
 * outward escape normal of pin r of instance i -- the axis direction a wire should leave the
 * pin, perpendicular to the pin's edge. Nearest-edge geometry: the pin's WORLD coordinate vs
 * the instance's WORLD bounding box (already rotated/translated), so a rotated/flipped instance
 * yields the correctly rotated normal for free. Ties broken L,R,B,T -- identical to the Tcl
 * reference predicates.tcl pin_escape_normal, which this ports. Crude by design on ambiguous
 * pins (corner, near-centre/bulk, text-skewed bbox); accepted per the geometry-only decision (no
 * per-pin dir= symbol property). Returns a unit axis vector in (*nx,*ny), or (0,0) if invalid. */
void get_pin_escape_normal(int i, int r, double *nx, double *ny)
{
  double px, py, x1, y1, x2, y2, dl, dr, db, dt, m, t;
  *nx = 0.0; *ny = 0.0;
  if(i < 0 || i >= xctx->instances || xctx->inst[i].ptr < 0) return;
  get_inst_pin_coord(i, r, &px, &py);          /* pin world coord */
  x1 = xctx->inst[i].x1; y1 = xctx->inst[i].y1;    /* instance world bbox */
  x2 = xctx->inst[i].x2; y2 = xctx->inst[i].y2;
  if(x1 > x2) { t = x1; x1 = x2; x2 = t; }
  if(y1 > y2) { t = y1; y1 = y2; y2 = t; }
  dl = fabs(px - x1); dr = fabs(px - x2);
  db = fabs(py - y1); dt = fabs(py - y2);
  m = dl;
  if(dr < m) m = dr;
  if(db < m) m = db;
  if(dt < m) m = dt;
  if(m == dl)      { *nx = -1.0; *ny =  0.0; } /* nearest edge -> outward normal (tie: L,R,B,T) */
  else if(m == dr) { *nx =  1.0; *ny =  0.0; }
  else if(m == db) { *nx =  0.0; *ny = -1.0; }
  else             { *nx =  0.0; *ny =  1.0; }
}

/* Fluid-editing Phase 1 (doc/claude/specs/nice_drag_rerouting.md §8): runtime invariant guards
 * at move END. Non-fatal, log-only, gated on fluid_editing (default off => never run => every
 * move byte-identical). Bring the Phase-0 golden predicates P1/P2 into the interactive runtime
 * so a fast-path reroute that shorts/merges/disconnects a net is caught the moment it happens.
 * Two complementary checks, because a net-label's own pin node echoes its intended name and so
 * cannot see a merge, while the wire-level resolved names cannot cheaply see a disconnect:
 *   - no-short (P2): every net label still sits on a wire whose resolved node equals the
 *     label's own net (uses WIRE nodes; the merge the echo hides -- F5.P2).
 *   - connectivity (P1): the partition of instance pins into nets is unchanged across the move
 *     (uses instance pin nodes; catches a pin torn off its net -- a disconnect).
 *
 * The partition compare uses a CANONICAL first-seen relabeling: walking instance pins in a
 * fixed order, each new net name gets the next integer id. Ids are therefore keyed to pin
 * POSITION, not net name, so a pure #net rename (same groups, different auto-name) yields an
 * identical id vector (no false positive), while a real regrouping shifts it. The per-pin diff
 * COUNT is approximate (one real change can cascade later ids), but "any difference" is an
 * exact detector of a partition change. Snapshot taken at move START (pre-motion geometry). */

static int *fluid_snap_id = NULL;    /* canonical partition id per instance pin, captured at START */
static int  fluid_snap_npins = 0;    /* 0 => no valid snapshot */
/* issue 0086: remaining (not-yet-applied) delta of the LATER decomposition legs while a decomposed
 * (0081) leg is committing -- read by fluid_ml_future_covers so the leg-0 elbow tie-break sees each
 * co-moving pin's FINAL landing point. Zero outside decomposed legs (single-pass moves, attempts
 * 1/2), which makes the tie-break inert there. */
static double fluid_leg_future_dx = 0.0, fluid_leg_future_dy = 0.0;
static char **fluid_snap_pinnet = NULL; /* strdup'd resolved net name (or NULL) per instance pin at
                                         * START -- for the device-merge P2 check (spec §9) */
static void fluid_discard_snapshot(void);

/* Diagnostic trace of the fluid stretch/reroute path (issue 0083 debugging aid, requested by the user
 * to make the exact path through move_objects/the reroute layers visible for a REAL interactive drag --
 * WSLg headless-gesture repro is unusable, so the user launches with FLUID_TRACE=1, does the gesture,
 * and shares the captured stderr). OFF by default (env unset) => single cached int compare per trace
 * point, no output, no behaviour change. To use: `FLUID_TRACE=1 src/xschem ... 2>/tmp/fltrace.log`,
 * then `grep FLTRACE /tmp/fltrace.log`. Trace lines go to errfp (stderr) via dbg(0,...). */
static int fluid_trace_on(void)
{
  static int v = -1;
  if(v < 0) { const char *e = getenv("FLUID_TRACE"); v = (e && *e && *e != '0') ? 1 : 0; }
  return v;
}
/* Write a trace line to a DEDICATED file -- NOT stderr/dbg: a windowed (GUI) launch detaches and
 * freopen()s stderr to /dev/null (main.c), and --logdir points the action log elsewhere, so a shell
 * `2>file` capture is EMPTY for a real interactive drag. The file is $FLUID_TRACE when that looks like a
 * path (contains '/'), else /tmp/xschem_fltrace.log. Opened once (truncated), flushed per line so a
 * killed session still has the trace. OFF (env unset) => returns immediately, nothing opened/written. */
static void fltrace(const char *fmt, ...)
{
  static FILE *fp = NULL;
  static int tried = 0;
  va_list ap;
  if(!fluid_trace_on()) return;
  if(!tried) {
    const char *e = getenv("FLUID_TRACE");
    const char *path = (e && strchr(e, '/')) ? e : "/tmp/xschem_fltrace.log";
    fp = fopen(path, "w");
    tried = 1;
  }
  if(!fp) return;
  va_start(ap, fmt);
  vfprintf(fp, fmt, ap);
  va_end(ap);
  fflush(fp);
}

/* Phase IV P6 (min-bend): outward escape normal of the MOVING, non-label instance pin coincident
 * with (x,y). Same pin walk + tolerance (point_near_pin) as insert_exit_stubs, and reads the SAME
 * get_pin_escape_normal the P3 stub layer uses, so P6 and P3 can never disagree about "along the
 * normal" (even when the normal is a crude nearest-edge axis on a bulk/corner pin). Returns 1 with a
 * clean single-axis (*nx,*ny); 0 if (x,y) is not on a moving pin or the normal is zero/ambiguous. */
static int fluid_moving_pin_normal(double x, double y, double *nx, double *ny)
{
  int inst, r, rects;
  double px, py;
  *nx = 0.0; *ny = 0.0;
  for(inst = 0; inst < xctx->instances; inst++) {
    const char *itype;
    if(!xctx->inst[inst].sel || xctx->inst[inst].ptr < 0) continue;   /* only MOVING instances */
    itype = xctx->sym[xctx->inst[inst].ptr].type;
    if(itype && !strcmp(itype, "label")) continue;                    /* labels have no body (§2) */
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; r++) {
      get_inst_pin_coord(inst, r, &px, &py);
      /* EXACT match, not point_near_pin's cadsnap/2 tolerance: insert_exit_stubs binds the pin-leg by
       * exact endpoint == (move.c:1655), so P6 must use the same equality or a NON-incident neighbour
       * pin within tolerance (dense/corner symbol, declared earlier) would supply the wrong normal and
       * P6 and P3 would disagree -- biasing the wrong axis (adversarial review wf_6e97238b, pin-binding
       * finding). On grid-aligned designs the endpoint sits exactly on its pin; a sub-grid-near endpoint
       * simply declines (P6 is a bonus), which is safe. */
      if(px == x && py == y) {
        get_pin_escape_normal(inst, r, nx, ny);
        return (*nx != 0.0) ^ (*ny != 0.0);          /* exactly one axis nonzero, else decline */
      }
    }
  }
  return 0;
}

/* Phase IV P6 length veto: is there a STATIONARY wire incident at the anchor (fx,fy) running ALONG
 * the escape-normal axis? If so, the baseline PERPENDICULAR arrival leg is colinear with it and trim
 * absorbs that leg (no corner), so biasing to the along-normal orientation would only ADD length
 * (the cont=down/cont=up loser in the empirical sweep). Decline in that case. The follow wire itself
 * (always .sel here) is skipped by the .sel filter, so it is never mistaken for a continuation. */
static int fluid_anchor_absorbs_along_normal(double fx, double fy, double nx, double ny)
{
  int m;
  for(m = 0; m < xctx->wires; m++) {
    int at, vert, horiz;
    if(xctx->wire[m].sel) continue;                  /* only stationary (non-moving) continuations */
    at = (xctx->wire[m].x1 == fx && xctx->wire[m].y1 == fy) ||
         (xctx->wire[m].x2 == fx && xctx->wire[m].y2 == fy);
    if(!at) continue;
    vert  = (xctx->wire[m].x1 == xctx->wire[m].x2) && (xctx->wire[m].y1 != xctx->wire[m].y2);
    horiz = (xctx->wire[m].y1 == xctx->wire[m].y2) && (xctx->wire[m].x1 != xctx->wire[m].x2);
    if(ny != 0.0 && vert)  return 1;                 /* vertical normal, vertical continuation */
    if(nx != 0.0 && horiz) return 1;                 /* horizontal normal, horizontal continuation */
  }
  return 0;
}

/* Phase IV P6 P5-guard (adversarial review wf_6e97238b): does the axis-aligned segment (x1,y1)-(x2,y2)
 * pass through the STRICT interior of any STATIONARY, non-label instance body? The both-P2-clear arm
 * only proved no device SHORT (fluid_ml_blocked tests two-distinct-pin straddle, not a body crossing),
 * so a foreign device whose pins lie OFF the along-normal axis has b=0 yet its body sits on the leg --
 * P6 would drive the straight exit through it (a P5 break, and P5 > P6). Box = inst world bbox
 * (symbol_bbox, move.c:221, the same box the reroute layers use). Stationary only: the moving
 * instance's own body is excluded by the sel test, so the pin's own leg root is never flagged. */
static int fluid_seg_crosses_stationary_body(double x1, double y1, double x2, double y2)
{
  int i;
  for(i = 0; i < xctx->instances; i++) {
    double bx1, by1, bx2, by2, t, slo, shi;
    const char *itype;
    if(xctx->inst[i].sel || xctx->inst[i].ptr < 0) continue;         /* stationary obstacles only */
    itype = xctx->sym[xctx->inst[i].ptr].type;
    if(itype && !strcmp(itype, "label")) continue;                   /* labels have no body (§2) */
    bx1 = xctx->inst[i].x1; by1 = xctx->inst[i].y1;
    bx2 = xctx->inst[i].x2; by2 = xctx->inst[i].y2;
    if(bx1 > bx2) { t = bx1; bx1 = bx2; bx2 = t; }
    if(by1 > by2) { t = by1; by1 = by2; by2 = t; }
    if(x1 == x2) {                                                    /* vertical segment at x1 */
      if(x1 <= bx1 || x1 >= bx2) continue;                            /* not strictly inside x-span */
      slo = y1 < y2 ? y1 : y2; shi = y1 < y2 ? y2 : y1;
      if(slo < by2 && shi > by1) return 1;                           /* overlaps the open y-interior */
    } else if(y1 == y2) {                                             /* horizontal segment at y1 */
      if(y1 <= by1 || y1 >= by2) continue;
      slo = x1 < x2 ? x1 : x2; shi = x1 < x2 ? x2 : x1;
      if(slo < bx2 && shi > bx1) return 1;
    }
  }
  return 0;
}

/* Phase IV P6 length veto (pin end; adversarial review wf_6e97238b, length finding). Complements
 * fluid_anchor_absorbs_along_normal (anchor end): decline if a STATIONARY wire lies colinear with and
 * overlaps the BASELINE perpendicular pin-leg -- the pin's ROW for a vertical normal, its COLUMN for a
 * horizontal normal, spanning from the pin toward the anchor. autotrim dedups that overlap in the
 * baseline route but NOT in the along-normal route, so biasing would only ADD copper (and saves 0
 * bends: with a wire already on the pin row, insert_exit_stubs does not staircase). px,py = moved pin;
 * fx,fy = anchor. BLIND SPOT (pre-existing, non-correctness, re-review wf_3d079dd2): a corridor wire
 * that CROSSES the pin is grabbed by connect_by_kissing as a MOVING (.sel) follow wire, so the
 * stationary-only scan below skips it and P6 may add bends+length in that narrow case (reproduces on
 * the guard-free binary too; all predicates hold). Left as a documented quality limitation. */
static int fluid_perp_pinleg_absorbs(double px, double py, double fx, double fy, double nx, double ny)
{
  int m;
  double lo, hi, wlo, whi;
  for(m = 0; m < xctx->wires; m++) {
    if(xctx->wire[m].sel) continue;                                  /* stationary wires only */
    if(ny != 0.0) {                                                  /* vertical normal: baseline leg is horizontal at y=py */
      if(xctx->wire[m].y1 != py || xctx->wire[m].y2 != py) continue; /* stationary horizontal wire on the pin row */
      lo = px < fx ? px : fx; hi = px < fx ? fx : px;
      wlo = xctx->wire[m].x1 < xctx->wire[m].x2 ? xctx->wire[m].x1 : xctx->wire[m].x2;
      whi = xctx->wire[m].x1 < xctx->wire[m].x2 ? xctx->wire[m].x2 : xctx->wire[m].x1;
    } else {                                                         /* horizontal normal: baseline leg is vertical at x=px */
      if(xctx->wire[m].x1 != px || xctx->wire[m].x2 != px) continue;
      lo = py < fy ? py : fy; hi = py < fy ? fy : py;
      wlo = xctx->wire[m].y1 < xctx->wire[m].y2 ? xctx->wire[m].y1 : xctx->wire[m].y2;
      whi = xctx->wire[m].y1 < xctx->wire[m].y2 ? xctx->wire[m].y2 : xctx->wire[m].y1;
    }
    if((lo > wlo ? lo : wlo) < (hi < whi ? hi : whi)) return 1;      /* positive-length overlap */
  }
  return 0;
}

/* Phase IV P6 (min-bend, doc/claude/specs/incremental_wire_reroute.md §8 / nice_drag_rerouting §4):
 * among the two equal-length manhattan L orientations for a fluid follow wire, return the one whose
 * pin-incident leg exits ALONG the moving pin's escape normal (a straight P3 exit), or 0 to keep the
 * caller's baseline. Called ONLY from the both-P2-clear arm of place_moved_wire, so P2 > P6 holds by
 * construction (a P2-mandated flip already dominates; a both-blocked case is left to the Layer-2
 * reroute). Pure function of (START snapshot, xctx->rx1..ry2, moving-instance geometry) => determin-
 * istic and release==stepwise. DECLINES (returns 0) when: no armed START snapshot (P2 not verifi-
 * able); the moved endpoint is not on a moving non-label pin, or its normal is ambiguous/zero; the
 * anchor is NOT strictly on the outward-normal side (an away escape is a genuine P3-mandated stub --
 * biasing inward would make insert_exit_stubs skip a leg that actually enters the body, silently
 * breaking P3/P5); or a stationary along-normal continuation at the anchor would make the route
 * LONGER (length veto). sel1 selects which endpoint moved (SELECTED1 => rx1,ry1 is the pin). */
static int fluid_p6_bias_ml(int sel1)
{
  double px, py, fx, fy, nx, ny;
  int along;
  if(!fluid_snap_pinnet) return 0;                   /* P2-clear must be PROVEN, not merely unqueried */
  /* If the user EXPLICITLY forces literal exit stubs (wire_exit_stub, a user-facing Options toggle,
   * default OFF and NOT set by cadence_style_rc), respect that and stand down: P6's along-normal
   * straight exit would optimize the requested stub away. The normal fluid flow (wire_exit_stub off)
   * still gets the min-bend straight exit. */
  if(tclgetboolvar("wire_exit_stub")) return 0;
  px = sel1 ? xctx->rx1 : xctx->rx2;                 /* moved (post-move) pin endpoint */
  py = sel1 ? xctx->ry1 : xctx->ry2;
  fx = sel1 ? xctx->rx2 : xctx->rx1;                 /* fixed anchor endpoint */
  fy = sel1 ? xctx->ry2 : xctx->ry1;
  /* The moving instance coords are NOT yet committed when place_moved_wire runs (inst.x0 is written
   * later, move.c:3302), so get_inst_pin_coord() still reports the PRE-move pin. The wire endpoint
   * (px,py) is already delta-applied, so match the pin at the PRE-move point (px-delta). The escape
   * normal is translation-invariant, so the pre-move normal equals the post-move one. */
  if(!fluid_moving_pin_normal(px - xctx->deltax, py - xctx->deltay, &nx, &ny)) return 0;
  along = (ny != 0.0) ? 1 : 2;                       /* ny!=0 -> vertical pin-leg (ml=1); else ml=2 */
  /* toward gate: anchor strictly on the OUTWARD-normal side of the moved pin (else it is a real, */
  /* P3-mandated away-escape -- leave it to insert_exit_stubs). */
  if(ny != 0.0) { if(ny * (fy - py) <= 0.0) return 0; }
  else          { if(nx * (fx - px) <= 0.0) return 0; }
  if(fluid_anchor_absorbs_along_normal(fx, fy, nx, ny)) return 0;   /* length veto (anchor end) */
  if(fluid_perp_pinleg_absorbs(px, py, fx, fy, nx, ny)) return 0;   /* length veto (pin end, Finding 3) */
  /* P5 (P5 > P6): the along-normal L must not drive either leg through a stationary foreign device
   * body -- the both-P2-clear arm proved no short, not no body cross (Finding 1). L legs by orientation
   * (place_moved_wire branches): along==1 => vertical pin-leg then horizontal arrival; along==2 =>
   * horizontal pin-leg then vertical arrival. Both legs run between the SAME (px,py) and (fx,fy). */
  if(along == 1) {
    if(fluid_seg_crosses_stationary_body(px, py, px, fy)) return 0;  /* vertical pin-leg   */
    if(fluid_seg_crosses_stationary_body(px, fy, fx, fy)) return 0;  /* horizontal arrival */
  } else {
    if(fluid_seg_crosses_stationary_body(px, py, fx, py)) return 0;  /* horizontal pin-leg */
    if(fluid_seg_crosses_stationary_body(fx, py, fx, fy)) return 0;  /* vertical arrival   */
  }
  return along;
}

/* total number of instance pins in the current schematic */
static int fluid_count_pins(void)
{
  int i, tot = 0;
  for(i = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;                  /* unlinked symbol (see move.c:1274) */
    tot += (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
  }
  return tot;
}

/* fill out[] (sized >= maxpins) with the canonical first-seen partition id of each instance
 * pin; return the number written. prepare_netlist_structs() must have run. */
static int fluid_build_partition(int *out, int maxpins)
{
  int i, p, j, k = 0, nextid = 0, nnames = 0;
  const char **names;
  int *nameid;
  if(maxpins <= 0) return 0;
  names  = my_malloc(_ALLOC_ID_, maxpins * sizeof(char *)); /* net name -> id, first-seen list */
  nameid = my_malloc(_ALLOC_ID_, maxpins * sizeof(int));    /* (upper bound: one per pin) */
  for(i = 0; i < xctx->instances && k < maxpins; ++i) {
    int npins;
    if(xctx->inst[i].ptr < 0) continue;                  /* skip identically to fluid_count_pins */
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    for(p = 0; p < npins && k < maxpins; ++p) {
      const char *nm = xctx->inst[i].node ? xctx->inst[i].node[p] : NULL;
      int id = -1;
      if(nm && nm[0]) {
        for(j = 0; j < nnames; ++j) if(!strcmp(names[j], nm)) { id = nameid[j]; break; }
        if(id < 0) { names[nnames] = nm; nameid[nnames] = nextid; ++nnames; id = nextid++; }
      } else {
        id = nextid++;                                   /* unconnected pin -> unique singleton */
      }
      out[k++] = id;
    }
  }
  my_free(_ALLOC_ID_, &names);
  my_free(_ALLOC_ID_, &nameid);
  return k;
}

/* capture the pre-move connectivity partition (called at move START) */
static void fluid_snapshot_partition(void)
{
  int tot, p, k, i;
  fluid_discard_snapshot();                 /* free any prior snapshot (id + pin-name arrays) */
  if(!tclgetboolvar("fluid_editing")) return;
  prepare_netlist_structs(0);
  tot = fluid_count_pins();
  if(tot <= 0) return;
  fluid_snap_id = my_malloc(_ALLOC_ID_, tot * sizeof(int));
  fluid_snap_npins = fluid_build_partition(fluid_snap_id, tot);
  /* Parallel capture of each pin's resolved net NAME (strdup -- node[] is freed/rebuilt across the
   * move). The device-merge P2 check (spec §9) needs both pins be NAMED pre-move: an unconnected
   * pin joining a net is a connect (P1's job), not a device short. Same walk order + skip rule as
   * fluid_build_partition, so index k lines up with fluid_snap_id. */
  fluid_snap_pinnet = my_malloc(_ALLOC_ID_, fluid_snap_npins * sizeof(char *));
  k = 0;
  for(i = 0; i < xctx->instances && k < fluid_snap_npins; ++i) {
    int npins;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    for(p = 0; p < npins && k < fluid_snap_npins; ++p) {
      const char *nm = xctx->inst[i].node ? xctx->inst[i].node[p] : NULL;
      fluid_snap_pinnet[k] = NULL;
      if(nm && nm[0]) my_strdup(_ALLOC_ID_, &fluid_snap_pinnet[k], nm);
      ++k;
    }
  }
}

/* free the snapshot without comparing (called on move ABORT, at each new START, and after each
 * END compare). Frees both the partition-id array and the strdup'd per-pin net-name array. */
static void fluid_discard_snapshot(void)
{
  int k;
  if(fluid_snap_pinnet) {
    for(k = 0; k < fluid_snap_npins; ++k) my_free(_ALLOC_ID_, &fluid_snap_pinnet[k]);
    my_free(_ALLOC_ID_, &fluid_snap_pinnet);
  }
  my_free(_ALLOC_ID_, &fluid_snap_id);
  fluid_snap_npins = 0;
}

/* incremental_wire_reroute.md §9 -- general device-pin-merge no-short (P2). The label-centric P2
 * pass below only sees a net-LABEL merge; a DEVICE short (a reroute laying a leg across a foreign
 * device between two of its pins) merges two nets with no label involved. Detect it directly: any
 * instance (skip net labels -- node[] echoes lab=) with two pins that were on DISTINCT named nets
 * at START and now resolve to the SAME net = a merge. Requires the START name snapshot; both pins
 * must be named at both times (an unconnected pin is P1's concern). Returns the merge count. */
static int fluid_check_device_merge(void)
{
  int i, p, q, k = 0, merges = 0;
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return 0;
  if(fluid_count_pins() != fluid_snap_npins) return 0;   /* instance set changed: not comparable */
  for(i = 0; i < xctx->instances; ++i) {
    int npins, base;
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;                  /* skip identically to the snapshot walk */
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;                                /* advance k for EVERY instance incl. labels */
    if(k > fluid_snap_npins) break;                      /* structure drift guard */
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(type && !strcmp(type, "label")) continue;         /* net label pins echo lab=; not a device */
    for(p = 0; p < npins; ++p) {
      const char *bp = fluid_snap_pinnet[base + p];
      const char *ap = (xctx->inst[i].node && xctx->inst[i].node[p]) ? xctx->inst[i].node[p] : NULL;
      if(!bp || !bp[0] || !ap || !ap[0]) continue;
      for(q = p + 1; q < npins; ++q) {
        const char *bq = fluid_snap_pinnet[base + q];
        const char *aq = (xctx->inst[i].node && xctx->inst[i].node[q]) ? xctx->inst[i].node[q] : NULL;
        if(!bq || !bq[0] || !aq || !aq[0]) continue;
        if(strcmp(bp, bq) && !strcmp(ap, aq)) {          /* distinct before, one net now => merged */
          ++merges;
          dbg(0, "fluid_editing INVARIANT (P2 device): instance '%s' pins %d,%d were on distinct "
                 "nets ('%s','%s'), now both on '%s' after move -- device short/merge\n",
                 xctx->inst[i].instname, p, q, bp, bq, ap);
        }
      }
    }
  }
  return merges;
}

/* Count instance pins whose connectivity partition changed vs the START snapshot -- the COMPLETE
 * P1/P2 signal for the diagonal-decomposition fallback: a device merge, a merge onto a single-pin
 * net LABEL (invisible to the two-pin fluid_check_device_merge above), AND a disconnect all show up
 * as a changed canonical partition id. No net-rename false positive: the ids are canonical first-seen
 * keyed to pin POSITION order, so a #net rename yields an identical vector (same as the Phase-1
 * disconnect guard in fluid_check_move_invariants). A merge onto a pin-LESS wire net is correctly
 * NOT counted (no device pin changed net). Requires node[] fresh (prepare_netlist_structs) + the
 * START id snapshot. Same body as the P1 block of fluid_check_move_invariants, factored for reuse. */
static int fluid_partition_changed(void)
{
  int tot, m, k, changed = 0, *now;
  if(!fluid_snap_id || fluid_snap_npins <= 0) return 0;
  tot = fluid_count_pins();
  if(tot != fluid_snap_npins) return 0;              /* instance set changed: not comparable */
  now = my_malloc(_ALLOC_ID_, tot * sizeof(int));
  m = fluid_build_partition(now, tot);
  if(m == fluid_snap_npins)
    for(k = 0; k < m; ++k) if(now[k] != fluid_snap_id[k]) ++changed;
  /* FLUID_TRACE forensics: name each changed pin (live net vs pristine snapshot net) so a
   * partition rollback in the attempt loop is diagnosable from the trace alone. */
  if(changed && fluid_trace_on()) {
    int i, p, kk = 0;
    for(i = 0; i < xctx->instances && kk < m; ++i) {
      int npins;
      if(xctx->inst[i].ptr < 0) continue;
      npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
      for(p = 0; p < npins && kk < m; ++p, ++kk) {
        if(now[kk] == fluid_snap_id[kk]) continue;
        {
          double px, py;
          const char *nm = xctx->inst[i].node ? xctx->inst[i].node[p] : NULL;
          const char *sn = (fluid_snap_pinnet && kk < fluid_snap_npins) ? fluid_snap_pinnet[kk] : NULL;
          get_inst_pin_coord(i, p, &px, &py);
          fltrace("FLTRACE pchg:   %s pin %d (%g,%g) snap=%s(id %d) now=%s(id %d)\n",
                  xctx->inst[i].instname ? xctx->inst[i].instname : "?", p, px, py,
                  sn ? sn : "-", fluid_snap_id[kk], nm ? nm : "-", now[kk]);
        }
      }
    }
  }
  my_free(_ALLOC_ID_, &now);
  return changed;
}

/* Phase III helper: is foreign pin (px,py) on the axis-aligned segment (x1,y1)-(x2,y2)? cadsnap/2
 * tolerance on the CONSTANT axis (mirrors point_near_pin, move.c:1220); inclusive span on the
 * varying axis. A degenerate (point) or diagonal leg carries no two-pin bridge. */
static int fluid_pin_on_seg(double px, double py, double x1, double y1, double x2, double y2)
{
  double tol = tclgetdoublevar("cadsnap") / 2.0, lo, hi;
  if(tol < 1e-6) tol = 1e-6;
  if(y1 == y2 && x1 != x2) {                       /* horizontal leg */
    if(fabs(py - y1) > tol) return 0;
    lo = x1 < x2 ? x1 : x2; hi = x1 < x2 ? x2 : x1;
    return px >= lo - tol && px <= hi + tol;
  }
  if(x1 == x2 && y1 != y2) {                        /* vertical leg */
    if(fabs(px - x1) > tol) return 0;
    lo = y1 < y2 ? y1 : y2; hi = y1 < y2 ? y2 : y1;
    return py >= lo - tol && py <= hi + tol;
  }
  return 0;
}

/* Do two AXIS-ALIGNED segments A(ax1,ay1)-(ax2,ay2) and B(bx1,by1)-(bx2,by2) share any point?
 * (issue 0087) The future-aware hazard tests (fluid_ml_future_covers / fluid_slide_future_hazard)
 * originally probed only a co-moving pin's FINAL landing POINT, but a co-moving pin is not a point:
 * the remaining decomposition leg drags a RISER along the future axis from the pin's intermediate
 * (post-current-leg) position to its final one, and foreign copper touching ANYWHERE on that riser
 * shorts just as surely as copper on the pin itself. So those tests probe the whole corridor
 * SEGMENT and need segment-vs-segment overlap, not point-on-segment. A degenerate (point) input
 * (which the future=0 later legs always produce) falls back to fluid_pin_on_seg, so the later legs
 * and every pure-axis / plain move stay byte-identical. Diagonal input returns 0 (callers only ever
 * pass H/V copper and single-axis corridors), so it can never false-hit. Same cadsnap/2 tolerance
 * as fluid_pin_on_seg. */
static int fluid_seg_pair_touch(double ax1, double ay1, double ax2, double ay2,
                                double bx1, double by1, double bx2, double by2)
{
  double tol = tclgetdoublevar("cadsnap") / 2.0;
  int ah, av, bh, bv;
  if(tol < 1e-6) tol = 1e-6;
  if(ax1 == ax2 && ay1 == ay2) return fluid_pin_on_seg(ax1, ay1, bx1, by1, bx2, by2);  /* A is a point */
  if(bx1 == bx2 && by1 == by2) return fluid_pin_on_seg(bx1, by1, ax1, ay1, ax2, ay2);  /* B is a point */
  ah = (ay1 == ay2); av = (ax1 == ax2);
  bh = (by1 == by2); bv = (bx1 == bx2);
  if(!(ah || av) || !(bh || bv)) return 0;          /* diagonal: unsupported, never a false hit */
  if(ah && bh) {                                    /* both horizontal: same row + overlapping x */
    double alo, ahi, blo, bhi;
    if(fabs(ay1 - by1) > tol) return 0;
    alo = ax1 < ax2 ? ax1 : ax2; ahi = ax1 < ax2 ? ax2 : ax1;
    blo = bx1 < bx2 ? bx1 : bx2; bhi = bx1 < bx2 ? bx2 : bx1;
    return ahi >= blo - tol && bhi >= alo - tol;
  }
  if(av && bv) {                                    /* both vertical: same column + overlapping y */
    double alo, ahi, blo, bhi;
    if(fabs(ax1 - bx1) > tol) return 0;
    alo = ay1 < ay2 ? ay1 : ay2; ahi = ay1 < ay2 ? ay2 : ay1;
    blo = by1 < by2 ? by1 : by2; bhi = by1 < by2 ? by2 : by1;
    return ahi >= blo - tol && bhi >= alo - tol;
  }
  {                                                 /* perpendicular: cross point inside both */
    double hx1, hx2, hy, vx, vy1, vy2;
    if(ah) { hx1 = ax1 < ax2 ? ax1 : ax2; hx2 = ax1 < ax2 ? ax2 : ax1; hy = ay1;
             vx = bx1; vy1 = by1 < by2 ? by1 : by2; vy2 = by1 < by2 ? by2 : by1; }
    else   { hx1 = bx1 < bx2 ? bx1 : bx2; hx2 = bx1 < bx2 ? bx2 : bx1; hy = by1;
             vx = ax1; vy1 = ay1 < ay2 ? ay1 : ay2; vy2 = ay1 < ay2 ? ay2 : ay1; }
    return vx >= hx1 - tol && vx <= hx2 + tol && hy >= vy1 - tol && hy <= vy2 + tol;
  }
}

/* (issue 0087) Like fluid_seg_pair_touch, but a shared contact EXACTLY at (ex,ey) does not count:
 * returns 1 iff A and B share some point OTHER than (ex,ey). The elbow future tie-break
 * (fluid_ml_future_covers) uses this against a co-moving pin's riser corridor because the candidate
 * L legitimately TERMINATES at its own moving pin (ex,ey) -- and that pin travels on in the next leg,
 * so a contact there is not a future short; only copper crossing the corridor ELSEWHERE is. A/B are
 * axis-aligned; a real (non-degenerate) collinear overlap always contains a non-(ex,ey) point => hit.
 * Same cadsnap/2 span tolerance; the pin-exemption match uses a tight epsilon (on-grid coords). */
static int fluid_seg_pair_touch_except(double ax1, double ay1, double ax2, double ay2,
                                       double bx1, double by1, double bx2, double by2,
                                       double ex, double ey)
{
  double tol = tclgetdoublevar("cadsnap") / 2.0;
  double pe = 1e-6;                                  /* pin-identity epsilon */
  int ah, av, bh, bv;
  if(tol < 1e-6) tol = 1e-6;
  if(!fluid_seg_pair_touch(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)) return 0;
  ah = (ay1 == ay2); av = (ax1 == ax2);
  bh = (by1 == by2); bv = (bx1 == bx2);
  /* perpendicular (or either degenerate): the touch is a single point -- exempt iff it IS (ex,ey) */
  if((ah && bv) || (av && bh) || (ax1 == ax2 && ay1 == ay2) || (bx1 == bx2 && by1 == by2)) {
    double px, py;
    if(ax1 == ax2 && ay1 == ay2)      { px = ax1; py = ay1; }   /* A is the point */
    else if(bx1 == bx2 && by1 == by2) { px = bx1; py = by1; }   /* B is the point */
    else if(ah)                       { px = bx1; py = ay1; }   /* A horiz, B vert -> (Bx, Ay) */
    else                              { px = ax1; py = by1; }   /* A vert, B horiz -> (Ax, By) */
    return !(fabs(px - ex) < pe && fabs(py - ey) < pe);
  }
  /* collinear (both horizontal same row, or both vertical same col): compute the overlap span */
  {
    double alo, ahi, blo, bhi, olo, ohi;
    if(ah) { alo = ax1<ax2?ax1:ax2; ahi = ax1<ax2?ax2:ax1; blo = bx1<bx2?bx1:bx2; bhi = bx1<bx2?bx2:bx1; }
    else   { alo = ay1<ay2?ay1:ay2; ahi = ay1<ay2?ay2:ay1; blo = by1<by2?by1:by2; bhi = by1<by2?by2:by1; }
    olo = alo > blo ? alo : blo;                      /* overlap [olo,ohi] along the shared axis */
    ohi = ahi < bhi ? ahi : bhi;
    if(ohi - olo > pe) return 1;                      /* real sub-segment: has a non-(ex,ey) point */
    /* single-point overlap: exempt iff it is (ex,ey) */
    if(ah) return !(fabs(olo - ex) < pe && fabs(ay1 - ey) < pe);
    return !(fabs(ax1 - ex) < pe && fabs(olo - ey) < pe);
  }
}

/* incremental_wire_reroute.md Phase III (§5/§6): would the manhattan L formed by the horizontal
 * leg (hx1,hy)-(hx2,hy) and the vertical leg (vx,vy1)-(vx,vy2) lay across a STATIONARY (foreign)
 * device between two of its pins that were on DISTINCT nets pre-move? That is the P2 short the naive
 * jog creates (R18's riser leg sweeping through v8). The L is tested AS A WHOLE (union of both
 * legs), NOT leg-by-leg: an L bridges its two legs through the shared corner, so a device with one
 * distinct-net pin on the horizontal leg and another on the vertical leg is shorted through the
 * corner -- a per-leg test misses it (adversarial review, cross-leg hole). A pin counts if it is on
 * EITHER leg. Uses the START name snapshot (fluid_snap_pinnet), so it is a pure function of
 * (snapshot, geometry) -- no live node[], deterministic. Same base-walk as fluid_check_device_merge,
 * plus a sel==0 (stationary) filter: a moving/partially-selected device's pins travel WITH the drag,
 * so it is not a fixed obstacle. Cost O(fixed_inst * pins^2), pins 2..4. */
static int fluid_L_bridges_device(double hx1, double hy, double hx2, double vx, double vy1, double vy2)
{
  int i, p, q, k = 0;
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return 0;
  for(i = 0; i < xctx->instances; ++i) {
    int npins, base;
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(k > fluid_snap_npins) break;                /* structure drift guard */
    if(xctx->inst[i].sel) continue;                /* only STATIONARY devices are obstacles */
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(type && !strcmp(type, "label")) continue;   /* net labels are not devices */
    for(p = 0; p < npins; ++p) {
      const char *bp = fluid_snap_pinnet[base + p];
      double px, py;
      if(!bp || !bp[0]) continue;
      get_inst_pin_coord(i, p, &px, &py);
      /* pin p anywhere on the L (either leg; the corner is shared -> a corner-straddle counts) */
      if(!(fluid_pin_on_seg(px, py, hx1, hy, hx2, hy) ||
           fluid_pin_on_seg(px, py, vx, vy1, vx, vy2))) continue;
      for(q = p + 1; q < npins; ++q) {
        const char *bq = fluid_snap_pinnet[base + q];
        double qx, qy;
        if(!bq || !bq[0] || !strcmp(bp, bq)) continue;   /* need distinct pre-move named nets */
        get_inst_pin_coord(i, q, &qx, &qy);
        if(fluid_pin_on_seg(qx, qy, hx1, hy, hx2, hy) ||
           fluid_pin_on_seg(qx, qy, vx, vy1, vx, vy2)) return 1;
      }
    }
  }
  return 0;
}

/* incremental_wire_reroute.md Phase III: is the L-route implied by orientation `ml` blocked -- does
 * it lay across a stationary device between two distinct-net pins (either leg, or straddling the
 * corner)? sel1 = the wire's moving endpoint is endpoint 1 (SELECTED1). The leg geometry mirrors the
 * four place_moved_wire branches EXACTLY (verified): horizontal leg spans rx1..rx2 at hy, vertical
 * leg spans ry1..ry2 at vx, meeting at the corner (vx,hy). */
static int fluid_ml_blocked(int ml, int sel1)
{
  double rx1 = xctx->rx1, ry1 = xctx->ry1, rx2 = xctx->rx2, ry2 = xctx->ry2;
  double hy = sel1 ? ((ml & 1) ? ry2 : ry1) : ((ml & 1) ? ry1 : ry2);   /* horizontal leg y */
  double vx = sel1 ? ((ml & 1) ? rx1 : rx2) : ((ml & 1) ? rx2 : rx1);   /* vertical leg x */
  return fluid_L_bridges_device(rx1, hy, rx2, vx, ry1, ry2);
}

/* incremental_wire_reroute.md Layer 2 helpers (below). Largest on-grid value strictly LESS than v /
 * strictly GREATER than v -- used to pick a detour row one grid OUTSIDE a device body edge. */
static double fluid_grid_below(double v, double grid)
{
  double q = floor(v / grid) * grid;
  if(q >= v) q -= grid;
  return q;
}
static double fluid_grid_above(double v, double grid)
{
  double q = ceil(v / grid) * grid;
  if(q <= v) q += grid;
  return q;
}

/* incremental_wire_reroute.md Layer 3: perp-axis (horiz? y : x) min/max over ALL obstacle geometry
 * -- every instance world bbox and every wire endpoint -- so the outward detour-row search (below)
 * has a finite, geometry-derived cap. One grid beyond this extent on a side, a detour's along-leg
 * (leg2) can meet no obstacle, so a side still blocked out there is a permanently-blocked riser
 * (a foreign/co-moving pin fixed on M's or the landing column) => stop searching that side and
 * decline cleanly, never widening into a never-terminating scan. */
static void fluid_perp_extent(int horiz, double *plo, double *phi)
{
  double lo = 0, hi = 0;
  int seen = 0, i, w;
  for(w = 0; w < xctx->wires; ++w) {
    double a = horiz ? xctx->wire[w].y1 : xctx->wire[w].x1;
    double b = horiz ? xctx->wire[w].y2 : xctx->wire[w].x2;
    if(!seen) { lo = hi = a; seen = 1; }
    if(a < lo) lo = a; if(a > hi) hi = a;
    if(b < lo) lo = b; if(b > hi) hi = b;
  }
  for(i = 0; i < xctx->instances; ++i) {
    double a, b;
    if(xctx->inst[i].ptr < 0) continue;
    a = horiz ? xctx->inst[i].y1 : xctx->inst[i].x1;
    b = horiz ? xctx->inst[i].y2 : xctx->inst[i].x2;
    if(!seen) { lo = hi = a; seen = 1; }
    if(a < lo) lo = a; if(a > hi) hi = a;
    if(b < lo) lo = b; if(b > hi) hi = b;
  }
  *plo = lo; *phi = hi;
}

/* Layer 2: pristine (START-snapshot) net name of the MOVING instance pin at (x,y), or NULL if none.
 * Same instance/pin walk order as fluid_build_partition (skip ptr<0), so the snapshot index lines up
 * with fluid_snap_pinnet. */
static const char *fluid_moving_pin_net(double x, double y)
{
  int i, p, k = 0, npins, base;
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return NULL;
  for(i = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    if(!xctx->inst[i].sel) continue;                 /* only MOVING instances */
    for(p = 0; p < npins; ++p) {
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);
      if(point_near_pin(px, py, x, y)) return fluid_snap_pinnet[base + p];
    }
  }
  return NULL;
}

/* Layer 2: does segment (x1,y1)-(x2,y2) pass over any STATIONARY device pin that was on a net OTHER
 * than `nf` at START? Such a pin on a detour leg would merge nf with that foreign net -- a NEW short.
 * A same-net (== nf) pin or an unconnected (empty) pin is fine to touch. */
static int fluid_seg_hits_foreign_pin(double x1, double y1, double x2, double y2, const char *nf)
{
  int i, p, k = 0, npins, base;
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return 0;
  for(i = 0; i < xctx->instances; ++i) {
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    if(xctx->inst[i].sel) continue;                  /* only STATIONARY devices are obstacles */
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(type && !strcmp(type, "label")) continue;
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_snap_pinnet[base + p];
      double px, py;
      if(!pn || !pn[0]) continue;
      if(nf && !strcmp(pn, nf)) continue;            /* same net: not a short */
      get_inst_pin_coord(i, p, &px, &py);
      if(fluid_pin_on_seg(px, py, x1, y1, x2, y2)) return 1;
    }
  }
  return 0;
}

/* Layer 2: does a detour leg (x1,y1)-(x2,y2) pass over a pin of a MOVING (co-dragged) instance that
 * is NOT the follow pin M (mx,my) and is on a net OTHER than NF? A rigidly-dragged multi-terminal
 * device carries its OTHER pins to fixed post-move offsets near M; a detour leg plowing through one
 * solders it onto NF -- a NEW device short (e.g. a MOS gate/bulk merged onto the source it was routed
 * for). fluid_seg_hits_foreign_pin() deliberately skips sel!=0 instances (stationary obstacles only),
 * so this is its moving-instance counterpart (adversarial re-review wf_582991bf). Uses the pristine
 * (START) net -- a moving pin whose net == NF, or the follow pin M itself, is fine to touch. */
static int fluid_seg_hits_moving_pin(double x1, double y1, double x2, double y2,
                                     const char *nf, double mx, double my)
{
  int i, p, k = 0, npins, base;
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return 0;
  for(i = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    if(!xctx->inst[i].sel) continue;                 /* only MOVING (co-dragged) instances */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_snap_pinnet[base + p];
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);            /* live POST-move coord */
      /* exempt the follow pin M itself (its riser legitimately starts at M) by EXACT coincidence,
       * not point_near_pin's cadsnap/2 tolerance -- a DISTINCT co-dragged pin landing 1..cadsnap/2 from
       * M must NOT be treated as M (adversarial re-review wf_eade2790: it was soldered onto NF). M is
       * on NF anyway, so the net check below is the real exemption; this is a belt-and-suspenders. */
      if(px == mx && py == my) continue;             /* the follow pin M itself */
      if(pn && pn[0] && nf && !strcmp(pn, nf)) continue;  /* already on NF (incl. M): no new merge */
      if(fluid_pin_on_seg(px, py, x1, y1, x2, y2)) return 1;
    }
  }
  return 0;
}

/* issue 0085 (blind-elbow diagonal fallback, doc/claude/issues/0085-*.md): FULL hazard
 * classification of the L orientation `ml` for the stretching wire (sel1: the moving endpoint is
 * endpoint 1). fluid_ml_blocked tested only the stationary-device two-pin bridge, so the 0081
 * single-diagonal-pass fallback picked "clean" L elbows that (a) ran the moved device's OWN far pin
 * over (R18.P's riser plowing R18.M) and (b) T'd onto a stationary foreign wire's endpoint (C12's
 * stub) -- both P2 shorts (tests/from_user/after_5.sch). Bitmask:
 *   FLUID_MLH_BRIDGE  stationary device with two distinct-pristine-net pins on the L (Phase III class)
 *   FLUID_MLH_MOVPIN  the L covers a CO-MOVING pin (at its POST-move position) on a different
 *                     pristine net -- typically the moving device's own other pin
 *   FLUID_MLH_FPIN    a lone stationary foreign-net pin under either leg (a merge without a bridge)
 *   FLUID_MLH_STRAY   a wire-contact hazard whose foreignness cannot be pristine-net-verified: a
 *                     stationary wire's endpoint lands on a leg (or the L's corner lands on a
 *                     stationary wire), or a partially-selected SIBLING follow wire's FIXED
 *                     endpoint lands on a leg (review wf_e348633c F1 -- its span is about to be
 *                     relaid but its anchor stays put and is a real contact). Exemptions (one-hop
 *                     same-net evidence, review F2): a wire touching the anchor A, touching M (the
 *                     pin landing merges it in every orientation, test_wireedit_39 C2), touching
 *                     M's PRE-move position, or tapping the stretched wire's own PRE-move span
 *                     A..preM (already connected pre-move -- flipping away from re-covering that
 *                     span would DISCONNECT the tap, worse than any flip could gain).
 *   FLUID_MLH_SPANLOSS the wire's PRE-move span A..preM carries a stationary attachment strictly
 *                     inside it (tap endpoint / mid-span-fed pin) that no leg of this orientation
 *                     re-covers -- relocating the copper strands it, a P1 disconnect (review F2).
 * BRIDGE/FPIN/MOVPIN/SPANLOSS are geometrically/pristine-net-verified; STRAY is heuristic, hence
 * the severity split in fluid_mlh_sev(). When nf is unknown (M is not a moving-instance pin, e.g. a
 * wire-junction grab) the MOVPIN/label classes cannot verify distinctness and degrade to the
 * heuristic STRAY band instead of a false sev-2 (review F4). Stationary net-LABEL pins -- skipped
 * by every shared helper -- are classified here explicitly (review F3): a label pin under a leg
 * names the copper beneath it, so a distinct-pristine-net label is a merge (FPIN). Runs
 * PRE-commit: the ELEMENT commit loop runs after the wire pass, so co-moving pins sit at live
 * (pre-move) coords and are tested at coord+delta, and M's pristine net is looked up at M-delta
 * (rot/flip==0 is gated by the caller). Pure function of (snapshot, geometry, delta) =>
 * deterministic, release==stepwise. Returns 0 with no armed snapshot (same gate as before). */
#define FLUID_MLH_BRIDGE   1
#define FLUID_MLH_MOVPIN   2
#define FLUID_MLH_FPIN     4
#define FLUID_MLH_STRAY    8
#define FLUID_MLH_SPANLOSS 16
static int fluid_ml_hazards(int ml, int sel1)
{
  double rx1 = xctx->rx1, ry1 = xctx->ry1, rx2 = xctx->rx2, ry2 = xctx->ry2;
  double hy = sel1 ? ((ml & 1) ? ry2 : ry1) : ((ml & 1) ? ry1 : ry2);   /* horizontal leg y */
  double vx = sel1 ? ((ml & 1) ? rx1 : rx2) : ((ml & 1) ? rx2 : rx1);   /* vertical leg x */
  double mx = sel1 ? rx1 : rx2, my = sel1 ? ry1 : ry2;                  /* moving endpoint M */
  double ax = sel1 ? rx2 : rx1, ay = sel1 ? ry2 : ry1;                  /* fixed anchor A */
  double cx = vx, cy = hy;                                              /* the L's corner */
  double pmx, pmy;                                                      /* M's PRE-move position */
  const char *nf;
  int i, p, k, npins, base, h = 0, m;

  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return 0;
  pmx = mx - xctx->deltax; pmy = my - xctx->deltay;
  nf = fluid_moving_pin_net(pmx, pmy);

  /* (1) stationary device two-distinct-net-pin bridge (the original Phase III test) */
  if(fluid_L_bridges_device(rx1, hy, rx2, vx, ry1, ry2)) h |= FLUID_MLH_BRIDGE;

  /* (2) co-moving pin plow: a pin of a MOVING instance, at its POST-move position (live + delta),
   * on a different pristine net, covered by either leg. The moving endpoint M itself is exempt. */
  for(i = 0, k = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    if(!xctx->inst[i].sel) continue;                 /* only MOVING (co-dragged) instances */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_snap_pinnet[base + p];
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);            /* live == PRE-move here */
      px += xctx->deltax; py += xctx->deltay;
      if(px == mx && py == my) continue;             /* the follow pin M itself */
      if(!pn || !pn[0]) continue;                    /* unconnected pin: no merge */
      if(nf && !strcmp(pn, nf)) continue;            /* same pristine net: not a short */
      if(fluid_pin_on_seg(px, py, rx1, hy, rx2, hy) ||
         fluid_pin_on_seg(px, py, vx, ry1, vx, ry2)) {
        /* nf unknown => distinctness unverifiable: heuristic band, not a false sev-2 (review F4) */
        h |= nf ? FLUID_MLH_MOVPIN : FLUID_MLH_STRAY;
        break;
      }
    }
    if(h & (FLUID_MLH_MOVPIN | FLUID_MLH_STRAY)) break;
  }

  /* (3) lone stationary foreign-net pin under either leg (needs nf to tell foreign from own) */
  if(nf && nf[0] &&
     (fluid_seg_hits_foreign_pin(rx1, hy, rx2, hy, nf) ||
      fluid_seg_hits_foreign_pin(vx, ry1, vx, ry2, nf))) h |= FLUID_MLH_FPIN;

  /* (3b) stationary net-LABEL pin under either leg (review F3): every shared helper skips
   * type=="label", but a label names the copper beneath its pin, so a distinct-pristine-net label
   * under a leg is a merge. Labels exactly at A or M are orientation-independent contacts: skip. */
  for(i = 0, k = 0; i < xctx->instances && !(h & (FLUID_MLH_FPIN | FLUID_MLH_STRAY)); ++i) {
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    if(xctx->inst[i].sel) continue;                  /* only STATIONARY labels */
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(!type || strcmp(type, "label")) continue;
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_snap_pinnet[base + p];
      double px, py;
      if(!pn || !pn[0]) continue;
      if(nf && !strcmp(pn, nf)) continue;            /* same pristine net: not a merge */
      get_inst_pin_coord(i, p, &px, &py);
      if((px == ax && py == ay) || (px == mx && py == my)) continue;
      if(fluid_pin_on_seg(px, py, rx1, hy, rx2, hy) ||
         fluid_pin_on_seg(px, py, vx, ry1, vx, ry2)) {
        h |= nf ? FLUID_MLH_FPIN : FLUID_MLH_STRAY;  /* no nf: heuristic band (review F4) */
        break;
      }
    }
  }

  /* (4) stray wire contact. Fully STATIONARY wires (sel==0): an endpoint on a leg, or the L's
   * corner on the wire's span, at a point other than A or M. Wire-level exemptions (one-hop
   * same-net evidence): a wire touching the anchor A (pre-connected), touching M (the pin landing
   * merges it in every orientation, test_wireedit_39 C2), touching M's PRE-move position, or
   * tapping the stretched wire's own PRE-move span A..preM (already connected; flipping away from
   * re-covering that span would DISCONNECT the tap -- review wf_e348633c F2). Partially-selected
   * SIBLING follow wires (SELECTED1/2): their span is about to be relaid, but the FIXED endpoint
   * stays put and is a real contact (review F1) -- test just that point, with the same A/M/pre-span
   * exemptions (the stretching wire n itself is exempted here: its fixed endpoint IS A).
   * fluid_pin_on_seg / exact == compares, like fluid_seg_stray_contact. */
  for(m = 0; m < xctx->wires && !(h & FLUID_MLH_STRAY); ++m) {
    unsigned int msel = xctx->wire[m].sel;
    double wx1, wy1, wx2, wy2;
    if((msel & SELECTED) || ((msel & SELECTED1) && (msel & SELECTED2)))
      continue;                                      /* rigid co-moving wire: both endpoints travel */
    wx1 = xctx->wire[m].x1; wy1 = xctx->wire[m].y1;
    wx2 = xctx->wire[m].x2; wy2 = xctx->wire[m].y2;
    if(msel == 0) {
      if(fluid_pin_on_seg(ax, ay, wx1, wy1, wx2, wy2)) continue;  /* touches the anchor: pre-connected */
      if(fluid_pin_on_seg(mx, my, wx1, wy1, wx2, wy2)) continue;  /* touches M: merged by the landing */
      if(fluid_pin_on_seg(pmx, pmy, wx1, wy1, wx2, wy2)) continue;/* sat under pre-move M */
      if(fluid_pin_on_seg(wx1, wy1, ax, ay, pmx, pmy) ||
         fluid_pin_on_seg(wx2, wy2, ax, ay, pmx, pmy)) continue;  /* taps our own pre-move span */
      /* wire m's endpoint lands on a leg, away from A / M */
      if((fluid_pin_on_seg(wx1, wy1, rx1, hy, rx2, hy) || fluid_pin_on_seg(wx1, wy1, vx, ry1, vx, ry2)) &&
         !(wx1 == ax && wy1 == ay) && !(wx1 == mx && wy1 == my)) { h |= FLUID_MLH_STRAY; break; }
      if((fluid_pin_on_seg(wx2, wy2, rx1, hy, rx2, hy) || fluid_pin_on_seg(wx2, wy2, vx, ry1, vx, ry2)) &&
         !(wx2 == ax && wy2 == ay) && !(wx2 == mx && wy2 == my)) { h |= FLUID_MLH_STRAY; break; }
      /* the L's corner lands on wire m's span (a T of the L onto m) */
      if(fluid_pin_on_seg(cx, cy, wx1, wy1, wx2, wy2) &&
         !(cx == ax && cy == ay) && !(cx == mx && cy == my)) { h |= FLUID_MLH_STRAY; break; }
    } else {
      /* partial sibling follow wire: only its FIXED (stationary) endpoint is a real contact.
       * A sibling whose MOVING endpoint shares our junction (== preM, e.g. two follow wires
       * grabbed at the same pin) is on our net by construction: exempt (round-2 wf_876b8a88). */
      double fx = (msel & SELECTED1) ? wx2 : wx1;
      double fy = (msel & SELECTED1) ? wy2 : wy1;
      double sx = (msel & SELECTED1) ? wx1 : wx2;    /* sibling's MOVING endpoint (pre-move) */
      double sy = (msel & SELECTED1) ? wy1 : wy2;
      if(sx == pmx && sy == pmy) continue;           /* shares our junction: same net */
      if((fx == ax && fy == ay) || (fx == mx && fy == my)) continue;
      if(fluid_pin_on_seg(fx, fy, ax, ay, pmx, pmy)) continue;    /* on our own pre-move span */
      if(fluid_pin_on_seg(fx, fy, rx1, hy, rx2, hy) ||
         fluid_pin_on_seg(fx, fy, vx, ry1, vx, ry2)) { h |= FLUID_MLH_STRAY; break; }
    }
  }

  /* (5) span-loss (review F2 / test 43 D4): the wire's PRE-move span A..preM carries an attachment
   * STRICTLY inside it -- a stationary wire's endpoint (a tap), a partial SIBLING follow wire's
   * FIXED anchor (the T onto our span is what joined the two nets; its own relay lands on a
   * DIFFERENT pin -- round-2 wf_876b8a88), or a stationary instance pin fed mid-span -- and this
   * orientation does NOT keep that attachment connected: relocating the copper strands it, a P1
   * DISCONNECT. "Still connected" for a tap WIRE also counts its OTHER endpoint landing on a leg
   * or the L's corner landing on its span (connectivity retained through the tap itself --
   * round-2 false-positive fix); endpoint-on-wire IS connection in xschem, so this is
   * geometrically verified => verified severity band; it ties against e.g. a MOVPIN on the
   * covering orientation instead of losing to it (keep ml0 = the pre-fix outcome). */
  for(m = 0; m < xctx->wires && !(h & FLUID_MLH_SPANLOSS); ++m) {
    unsigned int msel = xctx->wire[m].sel;
    double wx1, wy1, wx2, wy2;
    int e, nend;
    if((msel & SELECTED) || ((msel & SELECTED1) && (msel & SELECTED2)))
      continue;                                      /* rigid co-moving: travels with the drag */
    wx1 = xctx->wire[m].x1; wy1 = xctx->wire[m].y1;
    wx2 = xctx->wire[m].x2; wy2 = xctx->wire[m].y2;
    nend = (msel == 0) ? 2 : 1;                      /* partial sibling: only its FIXED endpoint */
    for(e = 0; e < nend; ++e) {
      double ex, ey, ox, oy;
      if(msel == 0) {
        ex = e ? wx2 : wx1; ey = e ? wy2 : wy1;
        ox = e ? wx1 : wx2; oy = e ? wy1 : wy2;      /* the tap's other endpoint */
      } else {
        ex = (msel & SELECTED1) ? wx2 : wx1; ey = (msel & SELECTED1) ? wy2 : wy1;
        ox = (msel & SELECTED1) ? wx1 : wx2; oy = (msel & SELECTED1) ? wy1 : wy2;
        if(ox == pmx && oy == pmy) continue;         /* shares our junction: relays with us */
      }
      if(!fluid_pin_on_seg(ex, ey, ax, ay, pmx, pmy)) continue;   /* not on the pre-move span */
      if((ex == ax && ey == ay) || (ex == pmx && ey == pmy)) continue;  /* span end, not inside */
      if(fluid_pin_on_seg(ex, ey, rx1, hy, rx2, hy) ||
         fluid_pin_on_seg(ex, ey, vx, ry1, vx, ry2)) continue;    /* a leg still covers it */
      if(msel == 0) {
        /* connectivity retained through the tap itself? (other endpoint on a leg / corner on it) */
        if(fluid_pin_on_seg(ox, oy, rx1, hy, rx2, hy) ||
           fluid_pin_on_seg(ox, oy, vx, ry1, vx, ry2)) continue;
        if(fluid_pin_on_seg(cx, cy, wx1, wy1, wx2, wy2)) continue;
      }
      h |= FLUID_MLH_SPANLOSS; break;
    }
  }
  for(i = 0, k = 0; i < xctx->instances && !(h & FLUID_MLH_SPANLOSS); ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    if(xctx->inst[i].sel) continue;                  /* only STATIONARY instances */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_snap_pinnet[base + p];
      double px, py;
      if(!pn || !pn[0]) continue;                    /* was not connected: nothing to strand */
      get_inst_pin_coord(i, p, &px, &py);
      if(!fluid_pin_on_seg(px, py, ax, ay, pmx, pmy)) continue;
      if((px == ax && py == ay) || (px == pmx && py == pmy)) continue;
      if(fluid_pin_on_seg(px, py, rx1, hy, rx2, hy) ||
         fluid_pin_on_seg(px, py, vx, ry1, vx, ry2)) continue;
      h |= FLUID_MLH_SPANLOSS; break;
    }
  }
  return h;
}

/* issue 0085: severity of a hazard mask for the orientation choice. Pristine-net-VERIFIED classes
 * (bridge / co-moving pin / foreign pin) rank above the heuristic stray-wire-contact class, so a
 * proven short still flips to a merely stray-flagged orientation (preserving the old flip behavior
 * where the flip target's stray contact was invisible), while a stray-only orientation never steals
 * the choice from a fully clean one. */
static int fluid_mlh_sev(int h)
{
  return ((h & (FLUID_MLH_BRIDGE | FLUID_MLH_MOVPIN | FLUID_MLH_FPIN | FLUID_MLH_SPANLOSS)) ? 2 : 0)
       + ((h & FLUID_MLH_STRAY) ? 1 : 0);
}

/* issue 0086 (future-blind elbow tie-break): during leg 0 of the 0081 X-then-Y decomposition, does
 * the L implied by `ml` lay copper on the RISER a co-moving foreign-pristine-net instance pin drags
 * as the remaining leg carries it to its final landing? Both orientations can be hazard-free at
 * leg-0 sight while one of them paints the corridor the OTHER moving pin lands in after the Y leg --
 * by then the follow stretch is degenerate (a straight extension through its own anchor, no elbow
 * freedom) and the short is unavoidable, collapsing the whole gesture to the rigid diagonal relay
 * although a clean Manhattan route exists (before_3.sch -> after_6.sch, R18 by (+150,-80)). Used ONLY
 * as a tie-break between two P2-clean orientations, so a hit can never pick a hazardous L. Same walk,
 * index lineup, M/same-net/unconnected exemptions and leg geometry as fluid_ml_hazards class (2).
 * issue 0087: the co-moving pin is NOT just its final POINT -- the remaining leg drags a RISER from
 * its intermediate (post-current-leg) position to the final one, so this tests the whole corridor
 * SEGMENT (fluid_seg_pair_touch_except), exempting a contact AT the L's own moving pin (that pin
 * travels on next leg; the L must legitimately end there). Leg 1's future=0 collapses the corridor
 * to the old point test, so later legs / pure-axis / plain moves are byte-identical (fluid_leg_future_*
 * zero outside decomposed legs => returns 0). Pure function of (snapshot, geometry, deltas) =>
 * deterministic, release==stepwise. */
static int fluid_ml_future_covers(int ml, int sel1)
{
  double rx1 = xctx->rx1, ry1 = xctx->ry1, rx2 = xctx->rx2, ry2 = xctx->ry2;
  double hy = sel1 ? ((ml & 1) ? ry2 : ry1) : ((ml & 1) ? ry1 : ry2);   /* horizontal leg y */
  double vx = sel1 ? ((ml & 1) ? rx1 : rx2) : ((ml & 1) ? rx2 : rx1);   /* vertical leg x */
  double mx = sel1 ? rx1 : rx2, my = sel1 ? ry1 : ry2;                  /* moving endpoint M */
  const char *nf;
  int i, p, k, npins, base;

  if(fluid_leg_future_dx == 0.0 && fluid_leg_future_dy == 0.0) return 0;
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return 0;
  nf = fluid_moving_pin_net(mx - xctx->deltax, my - xctx->deltay);
  for(i = 0, k = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    if(!xctx->inst[i].sel) continue;                 /* only MOVING (co-dragged) instances */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_snap_pinnet[base + p];
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);            /* live == PRE-leg here */
      if(px + xctx->deltax == mx && py + xctx->deltay == my) continue;  /* the follow pin M itself */
      if(!pn || !pn[0]) continue;                    /* unconnected pin: no merge (class-2 parity) */
      if(nf && !strcmp(pn, nf)) continue;            /* same pristine net: own copper is fine */
      /* issue 0087: the co-moving pin's RISER corridor -- from its intermediate (post-current-leg)
       * position to its FINAL one -- not just the final point (leg 1's future=0 collapses this to
       * the old point test, so later legs are byte-identical). */
      {
        double ix = px + xctx->deltax, iy = py + xctx->deltay;                       /* intermediate */
        double fxc = ix + fluid_leg_future_dx, fyc = iy + fluid_leg_future_dy;        /* final       */
        /* exempt a corridor contact AT this L's own moving pin (mx,my): the L must end there and
         * that pin moves on in the next leg -- only copper crossing the corridor elsewhere shorts. */
        if(fluid_seg_pair_touch_except(ix, iy, fxc, fyc, rx1, hy, rx2, hy, mx, my) ||
           fluid_seg_pair_touch_except(ix, iy, fxc, fyc, vx, ry1, vx, ry2, mx, my)) return 1;
      }
    }
  }
  return 0;
}

/* issue 0086 (future-blind corner slide): would sliding wire n rigidly by the current leg's delta
 * park its copper -- or drag the corner (fx,fy)'s collinear-neighbour endpoints -- into the RISER a
 * co-moving foreign-pristine-net pin drags to its final landing? The corner slide is a P4 aesthetic;
 * when it fires here it REMOVES the elbow freedom the later leg needs: the neighbour's stretched
 * endpoint becomes a fixed anchor in the landing corridor, so the leg-1 follow stretch is a
 * degenerate straight run into a guaranteed short (before_3.sch, R18 by (+150,-80): the C12 stub
 * corner slides from (-400,-90) to (-250,-90) == R18.M's final landing). issue 0087: it is not just
 * the final POINT -- a horizontal slid stub whose far end parks on the shared landing COLUMN but a
 * grid off the final row still lands inside the riser (before_3.sch, R18 by (+250,-90)), so this
 * tests the whole corridor SEGMENT (fluid_seg_pair_touch). (mx,my) = wire n's moving (pin-driven)
 * endpoint at its PRE-leg position, used to resolve the wire's own pristine net. Same walk/exemptions
 * as fluid_ml_future_covers. Inert (returns 0) outside decomposed fluid legs or without a snapshot
 * => plain moves are byte-identical. */
static int fluid_slide_future_hazard(int n, double fx, double fy, double mx, double my)
{
  const char *nf;
  int i, p, k, m, npins, base;
  double dx = xctx->deltax, dy = xctx->deltay;
  if(fluid_leg_future_dx == 0.0 && fluid_leg_future_dy == 0.0) return 0;
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return 0;
  nf = fluid_moving_pin_net(mx, my);
  for(i = 0, k = 0; i < xctx->instances; ++i) {
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    if(!xctx->inst[i].sel) continue;                 /* only MOVING (co-dragged) instances */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_snap_pinnet[base + p];
      double px, py;
      get_inst_pin_coord(i, p, &px, &py);            /* live == PRE-leg here */
      if(px == mx && py == my) continue;             /* the driving pin M itself */
      if(!pn || !pn[0]) continue;                    /* unconnected pin: no merge (class-2 parity) */
      if(nf && !strcmp(pn, nf)) continue;            /* same pristine net: own copper is fine */
      /* issue 0087: the co-moving pin's RISER corridor (intermediate post-slide position ..
       * FINAL landing after the remaining legs), not just the final POINT. A horizontal slid stub
       * that parks its far end on the shared landing COLUMN but a grid off the final row still lands
       * inside the riser the later leg drags down that column -> short. Leg 1 (future=0) collapses
       * the corridor to a point == old behavior, so single-axis / plain moves are byte-identical. */
      {
        double ix = px + dx, iy = py + dy;                                    /* intermediate */
        double fxc = ix + fluid_leg_future_dx, fyc = iy + fluid_leg_future_dy; /* final        */
        /* on the slid wire's post-slide span? */
        if(fluid_seg_pair_touch(ix, iy, fxc, fyc, xctx->wire[n].x1 + dx, xctx->wire[n].y1 + dy,
                                                   xctx->wire[n].x2 + dx, xctx->wire[n].y2 + dy)) return 1;
        /* on a dragged collinear neighbour's post-stretch span (far end .. corner+delta)?
         * (a non-axis-aligned candidate span returns 0 from fluid_seg_pair_touch: no false hit) */
        for(m = 0; m < xctx->wires; ++m) {
          double ox, oy;
          if(m == n) continue;
          if(xctx->wire[m].x1 == fx && xctx->wire[m].y1 == fy)      { ox = xctx->wire[m].x2; oy = xctx->wire[m].y2; }
          else if(xctx->wire[m].x2 == fx && xctx->wire[m].y2 == fy) { ox = xctx->wire[m].x1; oy = xctx->wire[m].y1; }
          else continue;
          if(fluid_seg_pair_touch(ix, iy, fxc, fyc, ox, oy, fx + dx, fy + dy)) return 1;
        }
      }
    }
  }
  return 0;
}

/* Layer 2: would a detour leg (sx1,sy1)-(sx2,sy2) make a STRAY connection to some existing wire --
 * i.e. a T-junction at a point that is NOT the intended NF landing (cx,cy) nor the moving pin M
 * (mx,my)? A wire whose endpoint lands on the leg's span, or a leg endpoint that lands on another
 * wire, connects the two nets -- and unlike a foreign PIN (fluid_seg_hits_foreign_pin) the wire's net
 * is not cheaply known here, so ANY stray contact is treated as unsafe and makes the reroute pick the
 * OTHER detour side (or decline). Pure geometric crossings where both wires are mid-span do NOT
 * connect in xschem, so they are intentionally not flagged. `selfw` (the straddle wire being reused)
 * is excluded. */
static int fluid_seg_stray_contact(double sx1, double sy1, double sx2, double sy2,
                                   double cx, double cy, double mx, double my, int selfw)
{
  int m;
  for(m = 0; m < xctx->wires; ++m) {
    double ax, ay, bx, by;
    if(m == selfw) continue;
    ax = xctx->wire[m].x1; ay = xctx->wire[m].y1;
    bx = xctx->wire[m].x2; by = xctx->wire[m].y2;
    /* (1) wire m's endpoint lands on this leg (a T onto the detour) -- allowed only at C or M */
    if(fluid_pin_on_seg(ax, ay, sx1, sy1, sx2, sy2) &&
       !(ax == cx && ay == cy) && !(ax == mx && ay == my)) return 1;
    if(fluid_pin_on_seg(bx, by, sx1, sy1, sx2, sy2) &&
       !(bx == cx && by == cy) && !(bx == mx && by == my)) return 1;
    /* (2) a leg endpoint lands on wire m (a T onto m) -- allowed only at C or M */
    if(fluid_pin_on_seg(sx1, sy1, ax, ay, bx, by) &&
       !(sx1 == cx && sy1 == cy) && !(sx1 == mx && sy1 == my)) return 1;
    if(fluid_pin_on_seg(sx2, sy2, ax, ay, bx, by) &&
       !(sx2 == cx && sy2 == cy) && !(sx2 == mx && sy2 == my)) return 1;
  }
  return 0;
}

/* Layer 2: is there a NON-DEGENERATE wire (other than selfw), lying on the straddle line (y==perp if
 * horiz, else x==perp), that fully COVERS the along-span [u1,u2]? Used to confirm the NF bus extends
 * from the same-net pin one grid outward before landing the up-leg there. "Covers a span" (not merely
 * "touches a point") is deliberate: it rejects (a) a foreign wire that merely ends AT the offset
 * point, and (b) a degenerate zero-length wire, both of which a bare touch()/point_on_other_wire test
 * wrongly accepted at the pre-trim seam -- tearing the moving pin off its net (adversarial review
 * wf_838ec39f). Because the span starts at the same-net pin (u1==a_same), any covering wire also
 * carries NF, so no separate (cache-fragile) net lookup is needed. */
static int fluid_wire_covers_on_line(double u1, double u2, double perp, int horiz, int selfw)
{
  double lo = u1 < u2 ? u1 : u2, hi = u1 < u2 ? u2 : u1;
  int m;
  for(m = 0; m < xctx->wires; ++m) {
    double x1, y1, x2, y2, wlo, whi;
    if(m == selfw) continue;
    x1 = xctx->wire[m].x1; y1 = xctx->wire[m].y1;
    x2 = xctx->wire[m].x2; y2 = xctx->wire[m].y2;
    if(horiz) {
      if(y1 != y2 || x1 == x2 || y1 != perp) continue;   /* need a horizontal wire on the perp row */
      wlo = x1 < x2 ? x1 : x2; whi = x1 < x2 ? x2 : x1;
    } else {
      if(x1 != x2 || y1 == y2 || x1 != perp) continue;    /* need a vertical wire on the perp column */
      wlo = y1 < y2 ? y1 : y2; whi = y1 < y2 ? y2 : y1;
    }
    if(wlo <= lo && whi >= hi) return 1;                  /* covers the whole [lo,hi] span */
  }
  return 0;
}

/* incremental_wire_reroute.md Layer 2 (spec sec 5 step 2-3, sec 6): resolve a residual
 * both-orientations-blocked device short by ripping up the straddling follow leg and routing a
 * detour AROUND the device. Runs at the pre-trim seam (after the per-object commit loop, before
 * check_collapsing_objects), so -- like every pass in the shared geometry-commit block -- it is a
 * pure function of (pristine snapshot, total delta, obstacles): release == stepwise for free (Phase
 * II already reapplies the total delta each step). Gated identically to the Layer-1 flip
 * (fluid_editing && stretch_select && orthogonal_wiring && rot==flip==0) => default off byte-identical.
 *
 * Layer 1 (place_moved_wire flip) already avoids the short whenever ONE L orientation is clear; this
 * fires only when the naive route STILL lays a single leg straight across a stationary device between
 * two of its distinct-pre-move-net pins (both orientations blocked, or a degenerate straight-through
 * where the moved pin lands on the device pin row). The presence of that residual single-wire
 * straddle IS the trigger -- no separate both-blocked test needed.
 *
 * Conservative: DECLINES to the baseline (never makes it worse) unless every safety condition holds.
 * The straddling wire W has the moving pin M at one end and an anchor (on the follow net NF) at the
 * other, with device D between them. Of D's two straddled pins, one resolves to NF at START (the
 * same-net pin, legitimately connected) and the other is FOREIGN (the short). W is ripped up and
 * replaced by three legs:  M -> perpendicular to a detour row one grid OUTSIDE D's body -> along,
 * past D -> back up to the row, landing AT the same-net device pin (on NF and connected by
 * construction), shifted one grid outward to a visible offset solder-joint (spec sec 6) only when a
 * real NF wire demonstrably extends there. It never continues across D. The detour side (below/above;
 * left/right for a vertical W) is the FIRST whose three legs hit NO obstacle: a stationary foreign
 * pin (fluid_seg_hits_foreign_pin), a stray wire T-junction off the intended NF landing
 * (fluid_seg_stray_contact), or a co-dragged MOVING pin on a net != NF (fluid_seg_hits_moving_pin) --
 * so the "boxed between two devices" case takes the clear side, else it declines. Two adversarial
 * review rounds (wf_838ec39f landing net-blindness, wf_582991bf/wf_eade2790 moving-pin plow-through)
 * hardened these guards; each is conservative (over-reject => decline => baseline, never a short). */
static void fluid_reroute_around_obstacles(int orthogonal_wiring)
{
  double grid = tclgetdoublevar("cadsnap");
  int iter;
  if(!orthogonal_wiring) return;
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return;
  if(fluid_count_pins() != fluid_snap_npins) return; /* instance set changed: snapshot walk unreliable */
  if(grid <= 0.0) grid = 1.0;

  /* one reroute per straddled device; cap the loop at instance count as a runaway backstop */
  for(iter = 0; iter < xctx->instances + 1; ++iter) {
    int D, p, q, w, k = 0, npins, base;
    int wfound = -1, Dfound = -1, horiz = 0;
    double px_s = 0, py_s = 0, px_f = 0, py_f = 0;   /* the two straddled pins' coords */
    const char *nf = NULL, *net_p = NULL, *net_q = NULL; /* their pristine (START) nets */

    /* --- find one residual single-wire straddle: a stationary device D with two distinct-net pins
     *     that both lie on ONE wire W, where W has exactly one moving-pin endpoint (=M) --- */
    for(D = 0; D < xctx->instances && wfound < 0; ++D) {
      const char *type;
      if(xctx->inst[D].ptr < 0) continue;
      npins = (xctx->inst[D].ptr + xctx->sym)->rects[PINLAYER];
      base = k; k += npins;
      if(base + npins > fluid_snap_npins) break;
      if(xctx->inst[D].sel) continue;                /* only STATIONARY devices */
      type = xctx->sym[xctx->inst[D].ptr].type;
      if(type && !strcmp(type, "label")) continue;
      for(p = 0; p < npins && wfound < 0; ++p) {
        const char *np = fluid_snap_pinnet[base + p];
        double pax, pay;
        if(!np || !np[0]) continue;
        get_inst_pin_coord(D, p, &pax, &pay);
        for(q = p + 1; q < npins && wfound < 0; ++q) {
          const char *nq = fluid_snap_pinnet[base + q];
          double qbx, qby;
          if(!nq || !nq[0] || !strcmp(np, nq)) continue;   /* need distinct pre-move nets */
          get_inst_pin_coord(D, q, &qbx, &qby);
          for(w = 0; w < xctx->wires; ++w) {
            double x1 = xctx->wire[w].x1, y1 = xctx->wire[w].y1;
            double x2 = xctx->wire[w].x2, y2 = xctx->wire[w].y2;
            int h = (y1 == y2 && x1 != x2), v = (x1 == x2 && y1 != y2);
            if(!h && !v) continue;
            if(!(fluid_pin_on_seg(pax, pay, x1, y1, x2, y2) &&
                 fluid_pin_on_seg(qbx, qby, x1, y1, x2, y2))) continue;
            wfound = w; Dfound = D; horiz = h;
            px_s = pax; py_s = pay; net_p = np;    /* pin p and its pristine net */
            px_f = qbx; py_f = qby; net_q = nq;    /* pin q and its pristine net */
            break;
          }
        }
      }
    }
    if(wfound < 0) break;                            /* no straddle left */

    /* --- classify + build the detour; any failed safety condition DECLINES (leave baseline) --- */
    {
      w = wfound; D = Dfound;
      {
      double x1 = xctx->wire[w].x1, y1 = xctx->wire[w].y1;
      double x2 = xctx->wire[w].x2, y2 = xctx->wire[w].y2;
      double perp0 = horiz ? y1 : x1;                /* the straddle row/col */
      double e1a = horiz ? x1 : y1, e2a = horiz ? x2 : y2;    /* endpoint along-coords */
      int e1mov = point_on_moving_pin(x1, y1);
      int e2mov = point_on_moving_pin(x2, y2);
      double a_m, a_p = horiz ? px_s : py_s, a_q = horiz ? px_f : py_f;
      double a_same, a_for, a_C, dir, t;
      double bx1, by1, bx2, by2, body_p_lo, body_p_hi;
      double Vb = 0;
      double plo_ext = 0, phi_ext = 0, below_stop = 0, above_stop = 0, vb_lo = 0, vb_hi = 0;
      int have = 0, ci, lo_done = 0, hi_done = 0, guard_steps = 0;
      char *prop = NULL;

      if(e1mov == e2mov) break;                      /* need exactly one moving-pin endpoint (=M) */
      a_m      = e1mov ? e1a : e2a;
      nf = fluid_moving_pin_net(e1mov ? x1 : x2, e1mov ? y1 : y2);
      if(!nf || !nf[0]) break;
      /* of the two straddled pins (nets net_p/net_q captured in detection), the same-net pin
       * resolves to NF at START and the other is foreign; require EXACTLY one to match NF */
      {
        if(net_p && net_p[0] && !strcmp(net_p, nf) && !(net_q && net_q[0] && !strcmp(net_q, nf))) {
          a_same = a_p; a_for = a_q;
        } else if(net_q && net_q[0] && !strcmp(net_q, nf) && !(net_p && net_p[0] && !strcmp(net_p, nf))) {
          a_same = a_q; a_for = a_p;
        } else break;                                /* cannot classify same/foreign vs NF */
      }
      /* the foreign pin must lie strictly between M and the same-net pin, so a detour landing one
       * grid outside the same-net pin (away from M) never has to pass the foreign pin */
      if(!((a_for - a_m) * (a_same - a_for) > 0.0)) break;
      dir = (a_same > a_m) ? 1.0 : -1.0;             /* M -> same-net pin (= anchor) direction */

      /* device world bbox (valid for stationary D after update_symbol_bboxes) */
      bx1 = xctx->inst[D].x1; by1 = xctx->inst[D].y1; bx2 = xctx->inst[D].x2; by2 = xctx->inst[D].y2;
      if(bx1 > bx2) { t = bx1; bx1 = bx2; bx2 = t; }
      if(by1 > by2) { t = by1; by1 = by2; by2 = t; }
      body_p_lo = horiz ? by1 : bx1; body_p_hi = horiz ? by2 : bx2;

      /* Landing column. Land AT the same-net device pin a_same: it is on NF and connected by
       * construction (a real pin the netlister binds the up-leg endpoint to), so P1/P2 hold with NO
       * fragile "is a wire here" search -- the earlier point_on_other_wire test matched transient jog
       * geometry / degenerate zero-length kiss stubs / a foreign wire ending at C and tore the moving
       * pin off its net (adversarial review wf_838ec39f, 8 confirmed P1 disconnects). As a pure
       * aesthetic upgrade, shift ONE grid outward (away from M) to a visible offset solder-joint only
       * when a real NF wire demonstrably extends there -- a non-degenerate wire COVERING the whole
       * pin->offset span on the straddle line (so it is the NF bus continuing, not a foreign wire
       * merely ending at C, nor a spurious degenerate match). */
      a_C = a_same;
      {
        double aC_off = a_same + dir * grid;
        if(fluid_wire_covers_on_line(a_same, aC_off, perp0, horiz, w)) a_C = aC_off;
      }
      if(a_C == a_m) break;                           /* degenerate landing (M already at the pin col) */

      /* Layer 3 (incremental_wire_reroute.md sec 5/6 -- multi-bend detour): OUTWARD-STEPPING
       * detour-row search. Layer 2 tried exactly one grid outside the body on each side and declined
       * if both were blocked; Layer 3 keeps stepping the detour row one grid further out until a
       * clear side is found, or both sides pass the schematic's perp-axis obstacle extent (then a
       * still-blocked side is a permanently-blocked riser -> decline cleanly). Step 1 tries below
       * then above at the body edge -- BYTE-IDENTICAL to Layer 2's pick, so every case Layer 2
       * already routed at step 1 is unchanged; only both-blocked cases search further. The 3-leg
       * construction + 9 obstacle guards are UNCHANGED (just evaluated at more candidate rows), so
       * P1/P2 hold exactly as in Layer 2 and any over-rejection still degrades to baseline. */
      fluid_perp_extent(horiz, &plo_ext, &phi_ext);
      /* Cap = the outermost obstacle's grid row, plus ONE more grid so the search reaches the first
       * row genuinely OUTSIDE that obstacle's guard tolerance: the along-leg guards match a pin/wire
       * within cadsnap/2 (fluid_pin_on_seg), so an OFF-GRID extent obstacle blocks its own grid row
       * AND the adjacent one -- without the extra grid the loop would stop inside the tolerance band
       * and decline while a provably-clear row sits one grid beyond it (adversarial review wf_afb2b1af,
       * off-grid decline-regression). Still finite + monotonic-safe: a truly boxed device declines. */
      below_stop = fluid_grid_below(plo_ext, grid) - grid;
      above_stop = fluid_grid_above(phi_ext, grid) + grid;
      vb_lo = fluid_grid_below(body_p_lo, grid);       /* nearest below/left detour row (step 1)      */
      vb_hi = fluid_grid_above(body_p_hi, grid);       /* nearest above/right detour row (step 1)     */
      while(!have && !(lo_done && hi_done)) {
        if(++guard_steps > 100000) break;              /* runaway backstop (geometry cap already bounds) */
        for(ci = 0; ci < 2 && !have; ++ci) {
          double vb;
          if(ci == 0) { if(lo_done) continue; vb = vb_lo; }   /* below/left first (Layer-2 order) */
          else        { if(hi_done) continue; vb = vb_hi; }   /* then above/right                 */
          {
          /* leg endpoints in (x,y): along a -> x if horiz else y; perp -> y if horiz else x */
          double l1x1 = horiz ? a_m : perp0, l1y1 = horiz ? perp0 : a_m;
          double l1x2 = horiz ? a_m : vb,    l1y2 = horiz ? vb    : a_m;
          double l2x2 = horiz ? a_C : vb,    l2y2 = horiz ? vb    : a_C;
          double l3x2 = horiz ? a_C : perp0, l3y2 = horiz ? perp0 : a_C;
          double cx = l3x2, cy = l3y2, mx = l1x1, my = l1y1; /* landing C (up-leg top), moving pin M */
          if(fluid_seg_hits_foreign_pin(l1x1, l1y1, l1x2, l1y2, nf)) continue; /* M riser        */
          if(fluid_seg_hits_foreign_pin(l1x2, l1y2, l2x2, l2y2, nf)) continue; /* detour along    */
          if(fluid_seg_hits_foreign_pin(l2x2, l2y2, l3x2, l3y2, nf)) continue; /* up leg to NF row */
          /* also reject a side whose legs would T onto some OTHER wire (foreign-net short) anywhere
           * but the intended NF landing C or the moving pin M -- pick the other side, or decline */
          if(fluid_seg_stray_contact(l1x1, l1y1, l1x2, l1y2, cx, cy, mx, my, w)) continue;
          if(fluid_seg_stray_contact(l1x2, l1y2, l2x2, l2y2, cx, cy, mx, my, w)) continue;
          if(fluid_seg_stray_contact(l2x2, l2y2, l3x2, l3y2, cx, cy, mx, my, w)) continue;
          /* and reject a side whose legs plow through the MOVING device's OTHER (co-dragged) pins,
           * which travel to fixed post-move offsets near M -- soldering one onto NF is a new short */
          if(fluid_seg_hits_moving_pin(l1x1, l1y1, l1x2, l1y2, nf, mx, my)) continue;
          if(fluid_seg_hits_moving_pin(l1x2, l1y2, l2x2, l2y2, nf, mx, my)) continue;
          if(fluid_seg_hits_moving_pin(l2x2, l2y2, l3x2, l3y2, nf, mx, my)) continue;
          Vb = vb; have = 1;
          }
        }
        if(!have) {                                    /* both sides blocked this far out: step further */
          vb_lo -= grid; if(vb_lo < below_stop) lo_done = 1;
          vb_hi += grid; if(vb_hi > above_stop) hi_done = 1;
        }
      }
      if(!have) break;                               /* no clear detour row at any distance: baseline */

      /* --- commit the detour: reuse W as the M riser, store the along + up legs, all on NF's prop.
       *     storeobject() reallocs xctx->wire, so index (never a cached pointer) across it. --- */
      my_strdup(_ALLOC_ID_, &prop, xctx->wire[w].prop_ptr);
      {
        double l1x1 = horiz ? a_m : perp0, l1y1 = horiz ? perp0 : a_m;
        double l1x2 = horiz ? a_m : Vb,    l1y2 = horiz ? Vb    : a_m;
        double l2x2 = horiz ? a_C : Vb,    l2y2 = horiz ? Vb    : a_C;
        double l3x2 = horiz ? a_C : perp0, l3y2 = horiz ? perp0 : a_C;
        xctx->wire[w].x1 = l1x1; xctx->wire[w].y1 = l1y1;
        xctx->wire[w].x2 = l1x2; xctx->wire[w].y2 = l1y2;
        order_wire_coords(w);
        storeobject(-1, l1x2, l1y2, l2x2, l2y2, WIRE, 0, 0, prop);
        order_wire_coords(xctx->wires - 1);
        storeobject(-1, l2x2, l2y2, l3x2, l3y2, WIRE, 0, 0, prop);
        order_wire_coords(xctx->wires - 1);
      }
      my_free(_ALLOC_ID_, &prop);
      xctx->prep_hash_wires = 0;
      xctx->prep_net_structs = 0;
      xctx->prep_hi_structs = 0;
      xctx->need_reb_sel_arr = 1;
      set_modify(1);
      /* rerouted this device; loop to catch any further straddle (a fixed device won't re-match) */
      }
    }
  }
}

/* issue 0083 (far-pin landing): is (x,y) EXACTLY a STATIONARY device pin that was on a net OTHER
 * than nf at START? That is the FAR (distinct-net) pin a long drag lands the riser corner on. A
 * STATIONARY (unselected) wire ending there is pristinely attached to THAT pin -- pristinely on the
 * foreign net, never on nf -- so the V-H-V rebuild, which vacates the corner entirely, restores its
 * pristine contact set exactly (the accidental corner contact was the would-be short). Same
 * instance/pin walk order as fluid_moving_pin_net / fluid_seg_hits_foreign_pin (skip ptr<0, skip
 * labels) so the snapshot index lines up. EXACT coordinate match, NOT point_near_pin: the soundness
 * argument ("a wire ending there is pristinely attached to that pin") is an exact-contact property --
 * xschem connectivity is exact -- while point_near_pin's cadsnap/2 box would also match an OFF-GRID
 * pin the corner did NOT land on and exempt a wire that is NOT the pin's attachment (adversarial
 * review wf_dfd3e463: tolerance-band false match -> P1 disconnect). */
static int fluid_point_on_foreign_fixed_pin(double x, double y, const char *nf)
{
  int i, p, k = 0, npins, base;
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return 0;
  for(i = 0; i < xctx->instances; ++i) {
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    if(xctx->inst[i].sel) continue;                  /* only STATIONARY devices */
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(type && !strcmp(type, "label")) continue;     /* net labels are not device pins */
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_snap_pinnet[base + p];
      double px, py;
      if(!pn || !pn[0]) continue;
      if(nf && !strcmp(pn, nf)) continue;            /* same net: not foreign */
      get_inst_pin_coord(i, p, &px, &py);
      if(px == x && py == y) return 1;
    }
  }
  return 0;
}

/* issue 0083 far-pin landing, removed-span safety (adversarial review wf_dfd3e463). The V-H-V rebuild
 * leaves row copper [anchor..C'] U [C'..P] -- a strict subset of the naive [anchor..C] U [P..C] -- so
 * the (P..C] span is REMOVED. That removal is exactly the short-repair when only the foreign pin /
 * its attachments sit there, but anything ELSE attached STRICTLY INSIDE (P..C) on the row would be
 * stranded by it: an nf tap-wire endpoint (a pristine in-body arm, reachable with autotrim_wires=0,
 * the stock default) or a pin that was on NF at START (a second device fed mid-span by the bus).
 * Return 1 (unsafe -> decline to baseline) unless every wire endpoint strictly inside coincides
 * EXACTLY with a stationary START-foreign pin (that wire is the pin's own attachment and keeps it
 * when we vacate) and no START-nf pin (stationary or co-moving, non-label) lies strictly inside.
 * START-foreign pins strictly inside are fine: the naive route shorts them, the removal un-shorts. */
static int fluid_removed_span_unsafe(double Px, double Cx, double Py, const char *nf,
                                     int Rw, int wB, int wS)
{
  int rr, i, p, k = 0, npins, base;
  for(rr = 0; rr < xctx->wires; ++rr) {
    double ex[2], ey[2];
    int e;
    if(rr == Rw || rr == wB || rr == wS) continue;   /* the classified riser/bus/overshoot */
    ex[0] = xctx->wire[rr].x1; ey[0] = xctx->wire[rr].y1;
    ex[1] = xctx->wire[rr].x2; ey[1] = xctx->wire[rr].y2;
    for(e = 0; e < 2; ++e) {
      if(ey[e] != Py) continue;
      if((ex[e] - Px) * (Cx - ex[e]) <= 0.0) continue;         /* not strictly inside (P..C) */
      if(!fluid_point_on_foreign_fixed_pin(ex[e], ey[e], nf)) return 1;
    }
  }
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return 1;    /* no snapshot: cannot prove safe */
  for(i = 0; i < xctx->instances; ++i) {
    const char *type;
    if(xctx->inst[i].ptr < 0) continue;
    npins = (xctx->inst[i].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    type = xctx->sym[xctx->inst[i].ptr].type;
    if(type && !strcmp(type, "label")) continue;
    for(p = 0; p < npins; ++p) {
      const char *pn = fluid_snap_pinnet[base + p];
      double px, py;
      if(!pn || !pn[0]) continue;
      if(!nf || strcmp(pn, nf) != 0) continue;       /* only START-nf pins block the removal */
      get_inst_pin_coord(i, p, &px, &py);
      if(py != Py) continue;
      if((px - Px) * (Cx - px) > 0.0) return 1;      /* nf pin strictly inside the removed span */
    }
  }
  return 0;
}

/* issue 0083 (incremental_wire_reroute.md §6 stop-short/solder-joint, GENERALIZED off the short
 * trigger): a NO-SHORT foreign-pin LANDING. On a small pure-axis nudge the base stretch-follow
 * (compute_wire_slide) promotes a tool-owned riser to a full selection and TRANSLATES it, so its far
 * corner comes to rest flush on a stationary device pin, and trim_wires merges away the offset
 * solder-joint -- the visible T-junction buries on the pin and the riser runs flush along the device
 * body. Connectivity stays correct (no short, no disconnect, partition unchanged), so NO obstacle layer
 * fires: fluid_reroute_around_obstacles needs a two-distinct-net STRADDLE (both pins on one wire), which
 * does not exist when only one same-net pin is contacted; fluid_seg_crosses_stationary_body is a P6
 * decline-veto, never a driver. This is a pure P5/beautify feel bug (lowest-but-one in the conflict
 * order P1=P2 > P3 > P5 > P4 > P7 > P6), so it must NEVER trade a higher predicate: every guard DECLINES
 * to the naive baseline route (never worse).
 *
 * This sibling pass detects that committed shape and rebuilds the riser into the user's V-H-V: the pin
 * escapes one grid, jogs one grid AWAY from the body, and drops a long clear leg that lands one grid
 * OUTSIDE the body onto the bus at a restored VISIBLE degree-3 solder-dot, with a short stub reaching
 * the pin. The bus is shrunk to the solder-dot and the pin-reaching stub is re-added, so the horizontal
 * copper at the bus row is UNION-IDENTICAL to the baseline bus (only re-segmented) -- copper-neutral,
 * no new crossing -- and only the three new riser legs are genuinely new copper and are guarded. Runs
 * on the SAME shared commit block as a real END and a live fluid RUBBER step (pre-trim seam) so it is a
 * pure function of (pristine snapshot + total delta + geometry): release == stepwise for FREE. Gated
 * fluid_editing && stretch_select && rot==flip==0 (caller) plus a valid START name snapshot => default
 * off byte-identical. TRIGGER (broadened twice): the riser corner landed strictly PAST the pin-side
 * body edge, inward -- unbounded on the far side. Catches the exact-on-pin +1-grid case, a continuous
 * drag deeper into the body (+2/+3 grid, overshoot stub between pin and corner), AND a drag ON or PAST
 * the FAR (distinct-net) pin / past the whole body. That far-pin landing is a GENUINE would-be SHORT
 * (the stretched bus covers both device pins), and fluid_reroute_around_obstacles can NOT see it: its
 * straddle needs a wire with exactly one moving-pin endpoint, but the straddling wire here is the
 * stretched BUS/overshoot whose endpoints are the anchor and the dragged corner (e1mov==e2mov -> its
 * detection breaks out). So for the far-pin landing this pass is the ONLY layer that fires, and firing
 * REPAIRS the short (the rebuild vacates the corner); the classification tolerates STATIONARY wires
 * ending at a corner that sits exactly on a foreign stationary pin (fluid_point_on_foreign_fixed_pin)
 * -- they are pristinely on the foreign net and keep their own pin contact when the corner is vacated.
 * fluid_removed_span_unsafe declines the firing when any OTHER attachment (an nf tap endpoint, a
 * START-nf pin fed mid-span) sits strictly inside the removed (P..C] row span -- adversarial review
 * wf_dfd3e463 (P1 never-worse holes, reachable with autotrim_wires=0, the stock default).
 * All deltas rebuild to the SAME canonical result (offset column one grid outside the body, pin side).
 * SCOPE (first increment): vertical-riser / horizontal-bus only, and pure-axis (the caller gates on
 * nlegs==1 so it never stacks on the issue-0081 diagonal decomposition); a horizontal riser, a rotated
 * bus, or a diagonal drag DECLINE to baseline (documented limitations, all P1/P2-safe). */
static void fluid_offset_foreign_pin_landing(int orthogonal_wiring)
{
  double grid = tclgetdoublevar("cadsnap");
  int D, p, k = 0, npins, base;
  if(!orthogonal_wiring) { fltrace("FLTRACE offset: skip (not orthogonal)\n"); return; }
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) { fltrace("FLTRACE offset: skip (no snapshot)\n"); return; }
  if(fluid_count_pins() != fluid_snap_npins) { fltrace("FLTRACE offset: skip (pin count changed)\n"); return; }
  if(grid <= 0.0) grid = 1.0;
  fltrace("FLTRACE offset: ENTER wires=%d grid=%g\n", xctx->wires, grid);

  for(D = 0; D < xctx->instances; ++D) {
    const char *type;
    double bx1, by1, bx2, by2, t, xc;
    if(xctx->inst[D].ptr < 0) continue;
    npins = (xctx->inst[D].ptr + xctx->sym)->rects[PINLAYER];
    base = k; k += npins;
    if(base + npins > fluid_snap_npins) break;
    if(xctx->inst[D].sel) continue;                     /* only STATIONARY devices */
    type = xctx->sym[xctx->inst[D].ptr].type;
    if(type && !strcmp(type, "label")) continue;        /* labels have no body (§2) */
    /* device world bbox (the text/pin-inflated symbol_bbox the P5 body test also uses) */
    bx1 = xctx->inst[D].x1; by1 = xctx->inst[D].y1; bx2 = xctx->inst[D].x2; by2 = xctx->inst[D].y2;
    if(bx1 > bx2) { t = bx1; bx1 = bx2; bx2 = t; }
    if(by1 > by2) { t = by1; by1 = by2; by2 = t; }
    xc = (bx1 + bx2) / 2.0;
    for(p = 0; p < npins; ++p) {
      const char *np = fluid_snap_pinnet[base + p];
      const char *nf;
      double Px, Py;                                     /* the stationary device pin (the anchor) */
      double Mx = 0, My = 0, Cx = 0, Cy = 0;             /* riser: M = moving-pin end, C = corner in body */
      int Rw = -1, wB = -1, wS = -1, rr, ambiguous = 0, stranded = 0, c_on_foreign = 0;
      double dir_off, dir_mc, Cpx, JOGY;
      double l1x1, l1y1, l1x2, l1y2, l2x2, l2y2, l3x2, l3y2;
      char *prop = NULL;

      if(!np || !np[0]) continue;
      get_inst_pin_coord(D, p, &Px, &Py);               /* stationary D never moved: post == pre */
      if(Px == xc) continue;                            /* pin on body centre: no offset direction */
      dir_off = (Px > xc) ? 1.0 : -1.0;                 /* away from the body, along the bus (X) axis */
      Cpx = Px + dir_off * grid;                        /* the restored solder-dot column (PIN-relative) */

      /* --- guard 1: EXACTLY ONE tool-owned VERTICAL riser R whose corner (its endpoint on the pin's
       *     row Py) landed strictly PAST this device's pin-side body edge, inward (issue 0083,
       *     broadened from "corner exactly on the pin", then from "inside the body x-span": the far
       *     side is UNBOUNDED so a drag onto / past the FAR distinct-net pin -- a would-be short no
       *     other layer can repair -- is caught too). The OTHER end M is on a MOVING pin (so R is a
       *     riser the drag pulled). The degenerate collapsed stub is skipped. --- */
      for(rr = 0; rr < xctx->wires && !ambiguous; ++rr) {
        double x1 = xctx->wire[rr].x1, y1 = xctx->wire[rr].y1;
        double x2 = xctx->wire[rr].x2, y2 = xctx->wire[rr].y2;
        double cxx, cyy, ox, oy;
        if(!xctx->wire[rr].sel) continue;               /* tool-owned follow wires only */
        if(x1 == x2 && y1 == y2) continue;              /* degenerate (collapsing stub): skip */
        if(x1 != x2) continue;                          /* VERTICAL riser only (first increment) */
        if(y1 == Py)      { cxx = x1; cyy = y1; ox = x2; oy = y2; }   /* corner on the bus row */
        else if(y2 == Py) { cxx = x2; cyy = y2; ox = x1; oy = y1; }
        else continue;
        if(dir_off < 0.0 ? (cxx <= bx1) : (cxx >= bx2)) continue; /* strictly past the pin-side edge, inward */
        if(!point_on_moving_pin(ox, oy)) continue;      /* other end must be a moving pin */
        if(Rw >= 0) { ambiguous = 1; break; }
        Rw = rr; Mx = ox; My = oy; Cx = cxx; Cy = cyy;
      }
      if(ambiguous) { fltrace("FLTRACE offset: D=%d pin=%d ambiguous riser -> decline\n", D, p); continue; }
      if(Rw < 0) continue;                              /* no intruding riser at this pin (silent: common) */
      fltrace("FLTRACE offset: D=%d pin=%d riser Rw=%d M=(%g,%g) C=(%g,%g) P=(%g,%g) body_x=[%g,%g]\n",
                                D, p, Rw, Mx, My, Cx, Cy, Px, Py, bx1, bx2);

      /* --- guard 2: SAME-NET (no short). A distinct net at the pin is a straddle/short that
       *     fluid_reroute_around_obstacles already owns -- decline here. --- */
      nf = fluid_moving_pin_net(Mx, My);
      if(!nf || !nf[0] || strcmp(nf, np) != 0) { fltrace("FLTRACE offset:   decline (net nf=%s np=%s)\n", nf?nf:"(null)", np); continue; }

      /* --- jog row + non-degenerate legs; offset column clear of pins --- */
      dir_mc = (Cy > My) ? 1.0 : -1.0;
      JOGY = My + dir_mc * grid;
      if((JOGY - My) * (Cy - JOGY) <= 0.0) continue;    /* need |Cy-My| > grid (both legs non-degenerate) */
      if(point_on_any_pin(Cpx, Py)) continue;           /* offset column already occupied by a pin */

      /* --- classify the horizontal copper meeting the riser corner C on row Py. wB = the BUS (far end
       *     on the AWAY-from-body side, i.e. the anchor). wS = the OPTIONAL overshoot stub (far end AT
       *     the pin P) that a >1-grid drag leaves between the pin and the corner. Anything else touching
       *     C, or a second bus / second overshoot, is unexpected -> decline (never worse) -- EXCEPT a
       *     STATIONARY (unselected) wire ending at a C that sits exactly ON a foreign stationary pin
       *     (the far-pin landing): that wire is the foreign pin's own attachment, pristinely on the
       *     foreign net, and the rebuild vacates C so its pristine contact set is restored -- ignore it.
       *     A SELECTED wire ending at C still declines (vacating C would tear a moving wire off). --- */
      c_on_foreign = fluid_point_on_foreign_fixed_pin(Cx, Cy, nf);
      for(rr = 0; rr < xctx->wires; ++rr) {
        double x1 = xctx->wire[rr].x1, y1 = xctx->wire[rr].y1;
        double x2 = xctx->wire[rr].x2, y2 = xctx->wire[rr].y2;
        int atC1, atC2;
        double far;
        if(rr == Rw) continue;
        if(x1 == x2 && y1 == y2) continue;              /* degenerate collapsing stub: ignore */
        if(y1 != Cy || y2 != Cy) {                      /* off the bus row: only a problem if it ends at C */
          if((x1 == Cx && y1 == Cy) || (x2 == Cx && y2 == Cy)) {
            if(c_on_foreign && !xctx->wire[rr].sel) continue; /* the foreign pin's own attachment */
            stranded = 1; break;
          }
          continue;
        }
        atC1 = (x1 == Cx); atC2 = (x2 == Cx);
        if(atC1 == atC2) continue;                      /* horizontal on the row but not ending at C: ignore */
        fltrace("FLTRACE offset:   rowwire rr=%d sel=%d [%g %g %g %g]\n", rr, xctx->wire[rr].sel, x1, y1, x2, y2);
        far = atC1 ? x2 : x1;
        /* NOTE sel cannot distinguish the tool's bus/overshoot from user copper here: place_moved_wire
         * RE-LAYS the follow wires (the relaid bus/overshoot carry sel==0 at this seam), so the
         * classification is purely geometric; ambiguity (two bus / two overshoot candidates, e.g. a
         * stationary duplicate of the relaid overshoot) declines, and interior attachments of a
         * candidate are protected by the removed-span scan below (wf_dfd3e463). */
        if((far - Px) * dir_off > 0.0) {                /* far end AWAY from body -> the bus */
          if(wB >= 0) { stranded = 1; break; } wB = rr;
        } else if(far == Px) {                          /* far end AT the pin -> the overshoot stub */
          if(wS >= 0) { stranded = 1; break; } wS = rr;
        } else {                                        /* toward body but not at the pin -> unexpected */
          if(c_on_foreign && !xctx->wire[rr].sel) continue; /* the foreign pin's own attachment */
          stranded = 1; break;
        }
      }
      if(stranded || wB < 0) { fltrace("FLTRACE offset:   decline (wB=%d wS=%d stranded=%d conF=%d)\n", wB, wS, stranded, c_on_foreign); continue; }
      fltrace("FLTRACE offset:   classified wB=%d wS=%d Cpx=%g JOGY=%g conF=%d\n", wB, wS, Cpx, JOGY, c_on_foreign);

      /* --- removed-span safety: the rebuild deletes the naive (P..C] row copper; decline when any
       *     OTHER attachment (an nf tap endpoint, a START-nf pin fed mid-span) sits strictly inside
       *     -- vacating would strand it, a P1 disconnect naive does not have (wf_dfd3e463). --- */
      if(fluid_removed_span_unsafe(Px, Cx, Py, nf, Rw, wB, wS)) {
        fltrace("FLTRACE offset:   decline (removed-span attachment P=%g C=%g)\n", Px, Cx);
        continue;
      }

      /* --- the three new riser legs (candidate coords). Build the near-M column from R's OWN endpoint
       *     Mx (on-grid Mx==the riser column; off-grid this keeps leg1 anchored to the moving pin, no P1
       *     tear). leg1 = M escape; leg2 = jog to the offset column; leg3 = long clear drop to C'. --- */
      l1x1 = Mx;  l1y1 = My;   l1x2 = Mx;  l1y2 = JOGY;
      l2x2 = Cpx; l2y2 = JOGY;
      l3x2 = Cpx; l3y2 = Cy;

      /* --- guards on the NEW legs. The bus+stub horizontal copper after the rebuild (anchor..C' + C'..P)
       *     is a SUBSET of the baseline row copper (only re-segmented and the overshoot removed), so it
       *     adds no crossing and needs no guard. Any leg hit => decline to baseline (never worse). C'
       *     (=Cpx,Cy) and M are the exempt contacts for stray_contact. --- */
      if(fluid_seg_crosses_stationary_body(l1x1, l1y1, l1x2, l1y2)) continue;
      if(fluid_seg_crosses_stationary_body(l1x2, l1y2, l2x2, l2y2)) continue;
      if(fluid_seg_crosses_stationary_body(l2x2, l2y2, l3x2, l3y2)) continue;
      if(fluid_seg_hits_foreign_pin(l1x1, l1y1, l1x2, l1y2, nf)) continue;
      if(fluid_seg_hits_foreign_pin(l1x2, l1y2, l2x2, l2y2, nf)) continue;
      if(fluid_seg_hits_foreign_pin(l2x2, l2y2, l3x2, l3y2, nf)) continue;
      if(fluid_seg_hits_moving_pin(l1x1, l1y1, l1x2, l1y2, nf, Mx, My)) continue;
      if(fluid_seg_hits_moving_pin(l1x2, l1y2, l2x2, l2y2, nf, Mx, My)) continue;
      if(fluid_seg_hits_moving_pin(l2x2, l2y2, l3x2, l3y2, nf, Mx, My)) continue;
      if(fluid_seg_stray_contact(l1x1, l1y1, l1x2, l1y2, l3x2, l3y2, Mx, My, Rw)) continue;
      if(fluid_seg_stray_contact(l1x2, l1y2, l2x2, l2y2, l3x2, l3y2, Mx, My, Rw)) continue;
      if(fluid_seg_stray_contact(l2x2, l2y2, l3x2, l3y2, l3x2, l3y2, Mx, My, Rw)) continue;

      fltrace("FLTRACE offset:   FIRE! rebuild V-H-V: leg col Mx=%g, dot=(%g,%g), stub->pin=%g wS=%d\n",
                                Mx, Cpx, Cy, Px, wS);
      /* --- commit: reshape R into leg1; pull the bus's C-endpoint back to the solder-dot column C';
       *     turn the overshoot stub into the pin-reaching stub C'->P (or store a fresh one if there was
       *     no overshoot, e.g. an exact-on-pin +1-grid landing); storeobject the jog + drop. storeobject
       *     reallocs xctx->wire, so all reshapes (index-only) happen first, appends last. --- */
      my_strdup(_ALLOC_ID_, &prop, xctx->wire[Rw].prop_ptr);       /* carries lab= (net) */
      xctx->wire[Rw].x1 = l1x1; xctx->wire[Rw].y1 = l1y1;
      xctx->wire[Rw].x2 = l1x2; xctx->wire[Rw].y2 = l1y2;
      order_wire_coords(Rw);
      if(xctx->wire[wB].x1 == Cx && xctx->wire[wB].y1 == Cy) xctx->wire[wB].x1 = Cpx;
      else                                                   xctx->wire[wB].x2 = Cpx;
      order_wire_coords(wB);
      if(wS >= 0) {                                                /* reshape overshoot C..P -> C'..P */
        if(xctx->wire[wS].x1 == Cx && xctx->wire[wS].y1 == Cy) xctx->wire[wS].x1 = Cpx;
        else                                                   xctx->wire[wS].x2 = Cpx;
        order_wire_coords(wS);
      }
      storeobject(-1, l1x2, l1y2, l2x2, l2y2, WIRE, 0, 0, prop);    /* leg2 (jog)  */
      order_wire_coords(xctx->wires - 1);
      storeobject(-1, l2x2, l2y2, l3x2, l3y2, WIRE, 0, 0, prop);    /* leg3 (drop) */
      order_wire_coords(xctx->wires - 1);
      if(wS < 0) {                                                 /* exact-on-pin: no overshoot to reuse */
        storeobject(-1, Cpx, Py, Px, Py, WIRE, 0, 0, prop);        /* fresh stub C' -> pin */
        order_wire_coords(xctx->wires - 1);
      }
      my_free(_ALLOC_ID_, &prop);
      xctx->prep_hash_wires = 0;
      xctx->prep_net_structs = 0;
      xctx->prep_hi_structs = 0;
      xctx->need_reb_sel_arr = 1;
      set_modify(1);
      return;                                            /* one landing per pass (rare to have two) */
    }
  }
}

/* incremental_wire_reroute.md / issue 0015 §7 -- CONNECTED-WIRE SHOVE (drag-toward, the occupancy
 * model). A moving instance that drives its pin ALONG its own stub PAST a CONNECTED perpendicular
 * wire V must PUSH V ahead (a solid body cannot occupy the wire's location) instead of letting the
 * naive place_moved_wire relay the stub as a REVERSED leg back through the instance's own body
 * (the P5 own-body intrusion of after_1.sch). Away = pure stretch (untouched). This is the structural
 * inverse of compute_wire_slide (which slides a PERPENDICULAR cornered wire; here the stub is PARALLEL
 * to the move, so compute_wire_slide skips it and never sees V).
 *
 * Post-detection sibling of Layers 2/3: runs at the shared pre-trim commit seam for BOTH a real END
 * and a live fluid RUBBER step => release==stepwise for free; a pure function of (pristine snapshot +
 * total delta). Gated identically to the obstacle layers (caller: fluid_editing && stretch_select &&
 * rot==flip==0) plus a valid START name snapshot => default off byte-identical. Every relocated piece
 * (S, V, arm) stays on the moving pin's net NF (V is electrically one net with the stub at J), so P1
 * is preserved BY CONSTRUCTION for anything attached at J or C; a wire tapping V's INTERIOR, or a
 * COLLINEAR continuation at C (e.g. an autotrim split of V), would be stranded/bent, so those are
 * DECLINED (leave baseline) via the clean-span/clean-corner guards below. P2: the new S, new V and
 * each dragged arm are checked against stationary foreign device pins (fluid_seg_hits_foreign_pin),
 * co-moving distinct-net pins (fluid_seg_hits_moving_pin) and stationary foreign-net wires
 * (fluid_seg_hits_foreign_wire); any hit DECLINES => baseline, never worse. No transitive chain: only
 * V and the one level of arm endpoints coincident with V's far corner follow. NOTE it post-detects the
 * reversed stub place_moved_wire just laid (a parallel single-endpoint stub is always relaid as one
 * straight degenerate wire), so it is coupled to that relay shape.
 * See doc/claude/issues/0015-component-shove-push-connected-wire-when-moving-into-it.md §7. */
static int fluid_seg_hits_foreign_wire(double x1, double y1, double x2, double y2,
                                       const char *nf, int selfa, int selfb, int selfc)
{
  /* Does axis-aligned seg (x1,y1)-(x2,y2) touch a STATIONARY (unselected) wire that is NOT part of the
   * shove's own group {selfa=S, selfb=V, selfc=arm} and resolves to a net OTHER than nf? Uses the
   * pre-move net cache in xctx->wire[].node (prepare_netlist_structs(0) ran at the commit seam before
   * the shove); a NULL/empty node or an == nf node is same-net and fine to touch. Manhattan-only, so a
   * closed-bbox overlap is the exact seg-seg touch test. Conservative: an unresolved (NULL) node is
   * treated as same-net (skip) so we never DECLINE on a legitimate same-net landing (arm on its rail). */
  int m;
  double alo = x1 < x2 ? x1 : x2, ahi = x1 < x2 ? x2 : x1;
  double blo = y1 < y2 ? y1 : y2, bhi = y1 < y2 ? y2 : y1;
  for(m = 0; m < xctx->wires; ++m) {
    double wx1, wy1, wx2, wy2, clo, chi, dlo, dhi;
    const char *wn;
    if(m == selfa || m == selfb || m == selfc) continue;
    if(xctx->wire[m].sel) continue;                       /* moving wires ride rigidly, not obstacles */
    wn = xctx->wire[m].node;
    if(!wn || !wn[0]) continue;                           /* unresolved -> treat as same-net (skip) */
    if(nf && nf[0] && !strcmp(wn, nf)) continue;          /* same net -> a legitimate touch */
    wx1 = xctx->wire[m].x1; wy1 = xctx->wire[m].y1; wx2 = xctx->wire[m].x2; wy2 = xctx->wire[m].y2;
    clo = wx1 < wx2 ? wx1 : wx2; chi = wx1 < wx2 ? wx2 : wx1;
    dlo = wy1 < wy2 ? wy1 : wy2; dhi = wy1 < wy2 ? wy2 : wy1;
    if(alo <= chi && clo <= ahi && blo <= dhi && dlo <= bhi) return 1;   /* closed-bbox overlap = touch */
  }
  return 0;
}

static void fluid_shove_connected_wire(int orthogonal_wiring)
{
  double grid = tclgetdoublevar("cadsnap");
  int dxnz, dynz, s, iter;

  if(!orthogonal_wiring) return;
  if(!fluid_snap_pinnet || fluid_snap_npins <= 0) return;
  if(fluid_count_pins() != fluid_snap_npins) return;   /* instance set changed: snapshot unreliable */
  if(grid <= 0.0) grid = 1.0;
  dxnz = (xctx->deltax != 0.0);
  dynz = (xctx->deltay != 0.0);
  if(dxnz == dynz) return;                              /* pure axis-aligned moves only */
  s = dynz ? (xctx->deltay > 0.0 ? 1 : -1) : (xctx->deltax > 0.0 ? 1 : -1);

  /* refresh the pre-move net cache (xctx->wire[].node) so fluid_seg_hits_foreign_wire can tell a
   * distinct-net wire from a same-net one; the shove has not mutated geometry yet. */
  prepare_netlist_structs(0);

  /* one shove per crossed stub; cap at wire count as a runaway backstop (a shoved stub stops matching
   * the reached/passed test, so the loop terminates well before the cap). */
  for(iter = 0; iter < xctx->wires + 1; ++iter) {
    int n, found = -1, endpin = 0, m, V = -1, perpcount = 0, others = 0;
    double ex = 0, ey = 0, ox = 0, oy = 0;             /* stub S: pin end / junction (far) end */
    double cx = 0, cy = 0;                             /* V's far corner */
    double pm0, jc, pmc, jpx, jpy, dsx, dsy, ncx, ncy;
    double vlo, vhi, vperp;                            /* V span + line, for the clean-span guard */
    int unclean = 0;
    const char *nf;

    /* --- find the crossed stub S: a wire PARALLEL to the move with EXACTLY ONE moving-pin endpoint,
     *     driven TOWARD its fixed far end J and REACHED/PASSED it, whose J is a CLEAN corner carrying
     *     exactly one connected perpendicular wire V --- */
    for(n = 0; n < xctx->wires && found < 0; ++n) {
      double x1 = xctx->wire[n].x1, y1 = xctx->wire[n].y1;
      double x2 = xctx->wire[n].x2, y2 = xctx->wire[n].y2;
      int e1, e2;
      if(dynz && x1 != x2) continue;                   /* vertical move -> parallel stub is vertical */
      if(dxnz && y1 != y2) continue;
      if(x1 == x2 && y1 == y2) continue;               /* degenerate */
      e1 = point_on_moving_pin(x1, y1);
      e2 = point_on_moving_pin(x2, y2);
      if(e1 == e2) continue;                           /* need exactly one moving-pin endpoint */
      endpin = e1;
      ex = e1 ? x1 : x2;  ey = e1 ? y1 : y2;           /* moving pin end (post-move) */
      ox = e1 ? x2 : x1;  oy = e1 ? y2 : y1;           /* junction / far end (unchanged by the move) */
      if(point_on_fixed_pin(ox, oy)) continue;         /* never shove a wire off a fixed pin */
      pm0 = dynz ? (ey - xctx->deltay) : (ex - xctx->deltax);   /* pre-move pin along-coord */
      jc  = dynz ? oy : ox;                            /* junction along-coord */
      pmc = dynz ? ey : ex;                            /* post-move pin along-coord */
      if((jc - pm0) * s <= 0.0) continue;              /* must have been moving TOWARD J */
      if((pmc - jc) * s <  0.0) continue;              /* must have REACHED/PASSED J (overrun >= 0) */

      /* J must be a CLEAN corner: exactly one perpendicular UNSELECTED wire (=V), nothing else */
      perpcount = 0; others = 0; V = -1;
      for(m = 0; m < xctx->wires; ++m) {
        double mx1, my1, mx2, my2;
        int perp;
        if(m == n) continue;
        mx1 = xctx->wire[m].x1; my1 = xctx->wire[m].y1;
        mx2 = xctx->wire[m].x2; my2 = xctx->wire[m].y2;
        if(!((mx1 == ox && my1 == oy) || (mx2 == ox && my2 == oy))) continue;   /* not at J */
        perp = dynz ? (my1 == my2 && mx1 != mx2) : (mx1 == mx2 && my1 != my2);
        if(perp && xctx->wire[m].sel == 0) { V = m; ++perpcount; }
        else ++others;
      }
      if(perpcount != 1 || others != 0) continue;      /* T-tap / ambiguous -> leave to baseline */
      found = n;
    }
    if(found < 0) break;
    n = found;

    /* V's far corner C (the endpoint that is not J) */
    if(xctx->wire[V].x1 == ox && xctx->wire[V].y1 == oy) { cx = xctx->wire[V].x2; cy = xctx->wire[V].y2; }
    else                                                { cx = xctx->wire[V].x1; cy = xctx->wire[V].y1; }
    if(point_on_fixed_pin(cx, cy)) break;              /* can't tear V's far end off a fixed pin */

    /* V must be a CLEAN isolated segment J..C: (1) no wire endpoint STRICTLY inside its span (a
     * mid-span tap would be stranded when V translates -> P1 disconnect), and (2) no COLLINEAR wire
     * at C (a continuation / autotrim split of V; the one-level arm drag would bend it into a diagonal
     * -> P4). Perpendicular arms at C are fine (they are what legitimately follow). Else DECLINE. */
    vperp = dynz ? oy : ox;                             /* V's constant coord (its line) */
    vlo = (dynz ? ox : oy) < (dynz ? cx : cy) ? (dynz ? ox : oy) : (dynz ? cx : cy);
    vhi = (dynz ? ox : oy) < (dynz ? cx : cy) ? (dynz ? cx : cy) : (dynz ? ox : oy);
    for(m = 0; m < xctx->wires && !unclean; ++m) {
      double mx1, my1, mx2, my2;
      int e_at_c, coll;
      if(m == n || m == V) continue;
      mx1 = xctx->wire[m].x1; my1 = xctx->wire[m].y1;
      mx2 = xctx->wire[m].x2; my2 = xctx->wire[m].y2;
      /* (1) endpoint strictly inside V's open span, on V's line */
      if(dynz) {
        if(my1 == vperp && mx1 > vlo && mx1 < vhi) unclean = 1;
        if(my2 == vperp && mx2 > vlo && mx2 < vhi) unclean = 1;
      } else {
        if(mx1 == vperp && my1 > vlo && my1 < vhi) unclean = 1;
        if(mx2 == vperp && my2 > vlo && my2 < vhi) unclean = 1;
      }
      /* (2) a wire COLLINEAR with V that has an endpoint at C = a continuation, not an arm */
      e_at_c = (mx1 == cx && my1 == cy) || (mx2 == cx && my2 == cy);
      coll = dynz ? (my1 == my2 && my1 == vperp) : (mx1 == mx2 && mx1 == vperp);
      if(e_at_c && coll) unclean = 1;
    }
    if(unclean) break;                                 /* messy V -> decline, leave baseline */

    /* J' = pin one grid OUTWARD along the drive axis; ds = J' - J; C' = C + ds */
    jpx = dxnz ? ex + grid * s : ex;
    jpy = dynz ? ey + grid * s : ey;
    dsx = jpx - ox;  dsy = jpy - oy;
    ncx = cx + dsx;  ncy = cy + dsy;

    /* P2: decline (=> baseline) if the new stub, the shoved V, or a dragged arm would land on a
     * stationary distinct-net pin, a co-moving distinct-net pin, or a stationary foreign-net wire.
     * nf = the moving pin's pristine (START) net (S and V are on nf by construction). */
    nf = fluid_moving_pin_net(ex, ey);
    if(nf && nf[0]) {
      if(fluid_seg_hits_foreign_pin(ex, ey, jpx, jpy, nf)) break;           /* new S vs foreign pin */
      if(fluid_seg_hits_foreign_pin(jpx, jpy, ncx, ncy, nf)) break;         /* new V vs foreign pin */
      if(fluid_seg_hits_moving_pin(ex, ey, jpx, jpy, nf, ex, ey)) break;    /* new S vs co-moving pin */
      if(fluid_seg_hits_moving_pin(jpx, jpy, ncx, ncy, nf, ex, ey)) break;  /* new V vs co-moving pin */
      if(fluid_seg_hits_foreign_wire(ex, ey, jpx, jpy, nf, n, V, -1)) break;    /* new S vs foreign wire */
      if(fluid_seg_hits_foreign_wire(jpx, jpy, ncx, ncy, nf, n, V, -1)) break;  /* new V vs foreign wire */
      /* each arm (a wire with an endpoint at C, other than V/S) checked over its NEW span (far end->C') */
      for(m = 0; m < xctx->wires; ++m) {
        double af, ag;   /* arm's fixed far end */
        int at1, at2;
        if(m == n || m == V) continue;
        at1 = (xctx->wire[m].x1 == cx && xctx->wire[m].y1 == cy);
        at2 = (xctx->wire[m].x2 == cx && xctx->wire[m].y2 == cy);
        if(!at1 && !at2) continue;
        af = at1 ? xctx->wire[m].x2 : xctx->wire[m].x1;
        ag = at1 ? xctx->wire[m].y2 : xctx->wire[m].y1;
        if(fluid_seg_hits_foreign_pin(af, ag, ncx, ncy, nf)) { unclean = 1; break; }
        if(fluid_seg_hits_moving_pin(af, ag, ncx, ncy, nf, ex, ey)) { unclean = 1; break; }
        if(fluid_seg_hits_foreign_wire(af, ag, ncx, ncy, nf, n, V, m)) { unclean = 1; break; }
      }
      if(unclean) break;
    }

    /* commit: (1) one-level arm drag at C -> C' (skip V and S), (2) translate V wholesale,
     * (3) collapse S to the one-grid OUTWARD stub pin -> J'. (cx,cy captured before any mutation.) */
    for(m = 0; m < xctx->wires; ++m) {
      int touched = 0;
      if(m == n || m == V) continue;
      if(xctx->wire[m].x1 == cx && xctx->wire[m].y1 == cy) { xctx->wire[m].x1 = ncx; xctx->wire[m].y1 = ncy; touched = 1; }
      if(xctx->wire[m].x2 == cx && xctx->wire[m].y2 == cy) { xctx->wire[m].x2 = ncx; xctx->wire[m].y2 = ncy; touched = 1; }
      if(touched) order_wire_coords(m);
    }
    xctx->wire[V].x1 += dsx; xctx->wire[V].y1 += dsy;
    xctx->wire[V].x2 += dsx; xctx->wire[V].y2 += dsy;
    order_wire_coords(V);
    if(endpin) { xctx->wire[n].x2 = jpx; xctx->wire[n].y2 = jpy; }
    else       { xctx->wire[n].x1 = jpx; xctx->wire[n].y1 = jpy; }
    order_wire_coords(n);

    xctx->prep_hash_wires = 0; xctx->prep_net_structs = 0; xctx->prep_hi_structs = 0;
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
  }
}

static void fluid_check_move_invariants(void)
{
  int i, w, shorts = 0, disconnects = 0, dev_merges = 0;
  if(!tclgetboolvar("fluid_editing")) { fluid_discard_snapshot(); return; }
  prepare_netlist_structs(0);
  /* --- P2: no-short/merge (wire-level, see comment above) --- */
  for(i = 0; i < xctx->instances; ++i) {
    const char *type = xctx->sym[xctx->inst[i].ptr].type;
    const char *intended;
    double px, py;
    if(!type || strcmp(type, "label")) continue;         /* only net labels */
    if(!xctx->inst[i].node || !xctx->inst[i].node[0]) continue;
    intended = xctx->inst[i].node[0];                    /* the net this label names */
    get_inst_pin_coord(i, 0, &px, &py);                  /* a net label has a single pin (0) */
    for(w = 0; w < xctx->wires; ++w) {
      if(touch(xctx->wire[w].x1, xctx->wire[w].y1, xctx->wire[w].x2, xctx->wire[w].y2, px, py)) {
        const char *phys = xctx->wire[w].node;
        if(phys && strcmp(intended, phys)) {
          ++shorts;
          dbg(0, "fluid_editing INVARIANT (P2): net label '%s' (%s) now on net '%s' after "
                 "move -- possible short/merge\n", intended, xctx->inst[i].instname, phys);
        }
        break;                                           /* first wire at the pin is enough */
      }
    }
  }
  /* --- P1: connectivity partition unchanged (pin-level, vs START snapshot) --- */
  if(fluid_snap_id && fluid_snap_npins > 0) {
    int tot = fluid_count_pins();
    if(tot == fluid_snap_npins) {                        /* structure comparable (no inst added/removed) */
      int *now = my_malloc(_ALLOC_ID_, tot * sizeof(int));
      int m = fluid_build_partition(now, tot), k;
      if(m == fluid_snap_npins)
        for(k = 0; k < m; ++k) if(now[k] != fluid_snap_id[k]) ++disconnects;
      my_free(_ALLOC_ID_, &now);
    }
    if(disconnects)
      dbg(0, "fluid_editing INVARIANT (P1): %d instance pin(s) changed net partition after "
             "move -- possible disconnect\n", disconnects);
  }
  /* --- P2 (general): device-pin-merge -- catches a DEVICE short (no net label), the R18/v8 class
   * the label pass above misses. Runs BEFORE the snapshot is freed. --- */
  dev_merges = fluid_check_device_merge();
  fluid_discard_snapshot();
  tclsetvar("fluid_last_move_violations", my_itoa(shorts));
  tclsetvar("fluid_last_move_disconnects", my_itoa(disconnects));
  tclsetvar("fluid_last_move_dev_merges", my_itoa(dev_merges));
}

/* incremental_wire_reroute.md Phase II: restore the live schematic to the pristine (post-kiss,
 * pre-delta) snapshot taken at move START, then re-establish the move-scoped state that
 * mem_restore_slot() resets. Called before each per-step reroute (RUBBER) and before the final
 * commit at a dirty END.
 *
 * mem_restore_slot() clears the drawing, frees+reallocs every object array, and (via
 * unselect_all(1)) ZEROES xctx->ui_state and lastsel. Everything else the reroute pipeline needs
 * (x1/y1 anchor, deltax/deltay, stretch_select, stretch_grabbed_xy/n, connect_by_kissing/kissing,
 * fluid_startsel_wires, the Phase-1 partition snapshot) lives in xctx scalars/side-arrays that
 * restore does NOT touch, so it survives. What we must put back here:
 *   - ui_state: preserve the whole word (STARTMOVE + any gesture bits) across the restore;
 *   - the four session-stable id counters: reset to their START values so tool-created wires
 *     (exit stubs, split fragments, kiss stubs) re-stamp IDENTICAL ids every step (determinism);
 *   - sel_array/lastsel: rebuilt from the restored per-object .sel bits;
 *   - movelastsel = lastsel: so update_symbol_bboxes()'s [0,movelastsel) bound tracks the
 *     restored selection (a stale movelastsel > lastsel re-fires the dce0bea6 symbol_bbox
 *     heap-overflow). */
static void fluid_reroute_restore(void)
{
  unsigned int saved_ui = xctx->ui_state;
  mem_restore_slot(&xctx->fluid_reroute_snap, 0);
  xctx->ui_state = saved_ui;
  xctx->wire_id_counter = xctx->fluid_reroute_wid;
  xctx->inst_id_counter = xctx->fluid_reroute_iid;
  xctx->gfx_id_counter  = xctx->fluid_reroute_gid;
  xctx->text_id_counter = xctx->fluid_reroute_tid;
  xctx->need_reb_sel_arr = 1;
  rebuild_selected_array();
  xctx->movelastsel = xctx->lastsel;
}

/* incremental_wire_reroute.md Phase II: drop the active gesture's snapshot (free the deep copy +
 * the per-layer arrays) and clear the ownership flags. Runs on EVERY move END and ABORT exit so a
 * leaked fluid_reroute_active can never make an unrelated later gesture restore a stale/freed
 * snapshot. Also called from clear_schematic() (actions.c) so tearing down / reloading the buffer
 * while a fluid stretch is armed cannot resurrect the pre-clear geometry or leak the deep copy.
 * NOT static (clear_schematic calls it). Idempotent (mem_snapshot_free no-ops on a zeroed slot). */
void fluid_reroute_discard(void)
{
  mem_snapshot_free(&xctx->fluid_reroute_snap);
  xctx->fluid_reroute_active = 0;
  xctx->fluid_reroute_dirty = 0;
}

/* incremental_wire_reroute.md §10.10 / issue 0081: between the X and Y legs of a diagonal fluid
 * stretch, re-derive the tool-owned follow set from the (X-moved, cleaned) leg-A geometry so the
 * Y leg is a fresh pure-axis stretch. Leg A's deselect tail (the Phase-I follow-wire deselect,
 * gated on fluid_startsel_wires==0) has zeroed every wire.sel, so select_attached_nets re-grabs a
 * FRESH single-endpoint (SELECTED1/2) follow set at the X-moved pins -- place_moved_wire then
 * relays each pin-incident segment exactly ONCE per leg (never an L-of-an-L; the M2 failure mode).
 *   - fluid_startsel_wires: select_attached_nets recounts it (select.c) by scanning wire.sel; the
 *     recount is 0 here (leg A deselected all follow wires), which is also its START value on this
 *     path (the two-leg gate required ==0), so save/restore is a no-op belt-and-suspenders that
 *     keeps the deselect-tail gate correct for leg B regardless.
 *   - movelastsel: select_attached_nets -> rebuild_selected_array updates lastsel but NOT
 *     movelastsel; leg B's update_symbol_bboxes(0,0) iterates sel_array[0,movelastsel), and a stale
 *     movelastsel > lastsel re-fires the dce0bea6 symbol_bbox heap-buffer-overflow read. */
static void move_regrab_follow_set(void)
{
  int saved = xctx->fluid_startsel_wires;
  select_attached_nets();
  xctx->fluid_startsel_wires = saved;
  xctx->movelastsel = xctx->lastsel;
}

/* merge param unused, RFU */
void move_objects(int what, int merge, double dx, double dy)
{
  int c, i, n, k, tmpint;
  double angle, dtmp;
  double tx1,ty1; /* temporaries for swapping coordinates 20070302 */
  char *estr = NULL;
  int orthogonal_wiring = tclgetboolvar("orthogonal_wiring");
  #if HAS_CAIRO==1
  int customfont;
  #endif
  /* incremental_wire_reroute.md Phase II: when a fluid stretch RUBBER step wants to commit the
   * reroute live, it restores the pristine snapshot, sets commit_now, and FALLS THROUGH to the END
   * geometry-commit block below (which is guarded by `(what & END) || commit_now`). commit_now then
   * gates OUT every END-only finalizer (undo push, ui_state teardown, hilight, the final draw) so
   * the SAME commit code runs, but the gesture stays live. */
  int commit_now = 0;
  /* NOT const: a mem_restore_slot() inside a RUBBER step or a dirty END frees+reallocs xctx->wire /
   * xctx->line, so these are re-fetched just before the commit block (using the stale capture would
   * be a heap use-after-free). */
  xLine **line = xctx->line;
  xWire *wire = xctx->wire;

  dbg(1, "move_objects: what=%d, dx=%g, dy=%g\n", what, dx, dy);
  if(what & START)
  {
   xctx->rotatelocal=0;
   xctx->deltax = xctx->deltay = 0.0;
   rebuild_selected_array();
   /* read-only backstop (issue 0041): refuse to begin a move below the entry guards.
    * Placed alongside the lastsel==0 early return so a refused START leaves the same
    * clean state an empty-selection START does (deltas zeroed, selection rebuilt), which
    * keeps a follow-on END (the scheduler calls START then END) a no-op. ABORT/RUBBER/END
    * of an already-started gesture are left alone (none can start on a read-only buffer). */
   if(begin_edit("move")) return;
   if(xctx->lastsel==0) return;
   /* movelastsel must be refreshed to the CURRENT selection BEFORE update_symbol_bboxes(), which
    * iterates sel_array[0..movelastsel-1]. Otherwise it uses the STALE count from the previous move:
    * if that count exceeds the current selection (e.g. the last gesture selected more, then objects
    * were cleared/deleted), the loop reads stale sel_array entries that may index an instance with
    * ptr<0 (unlinked), and symbol_bbox() then dereferences (ptr + xctx->sym) BEFORE the sym array --
    * a heap-buffer-overflow read (found via AddressSanitizer). It is re-snapshotted below after
    * connect_by_kissing() so kissed stubs are still included in the move. */
   xctx->movelastsel = xctx->lastsel;
   update_symbol_bboxes(0, 0);
   /* if connect_by_kissing==2 it was set in callback.c ('M' command) */
   if(xctx->connect_by_kissing == 2) xctx->kissing = connect_by_kissing();
   else xctx->kissing = 0;
   xctx->movelastsel = xctx->lastsel;
   if(xctx->lastsel==1 && xctx->sel_array[0].type==ARC &&
           xctx->arc[c=xctx->sel_array[0].col][n=xctx->sel_array[0].n].sel!=SELECTED) {
     xctx->x1 = xctx->arc[c][n].x;
     xctx->y1 = xctx->arc[c][n].y;
   } else {xctx->x1=xctx->mousex_snap;xctx->y1=xctx->mousey_snap;}
   xctx->move_flip = 0;xctx->move_rot = 0;
   xctx->ui_state|=STARTMOVE;
   fluid_snapshot_partition(); /* Phase 1 P1 guard: capture pre-move connectivity partition */
   /* incremental_wire_reroute Phase I (ownership decoupling): xctx->fluid_startsel_wires (the count
    * of the user's own selected wires) is captured in select_attached_nets(), which runs BEFORE this
    * START -- it must be taken before follow-wires are grabbed/folded, so it cannot be recomputed
    * here. The END deselect is gated on stretch_select, set only by select_attached_nets alongside
    * that count, so the two are always consistent (a non-stretch move never consumes it). */
   /* incremental_wire_reroute.md Phase II: snapshot the pristine (post-kiss, pre-delta) schematic so
    * each RUBBER step can restore-and-reapply the total delta. Taken HERE -- after connect_by_kissing
    * and after movelastsel was refreshed to lastsel above -- so the snapshot's selection count equals
    * movelastsel. Only for a fluid stretch (the sole path that reroutes follow-wires). fluid_reroute_
    * discard() first clears any snapshot a prior gesture failed to release (defensive; END/ABORT
    * always discard, so normally a no-op). */
   fluid_reroute_discard();
   if(tclgetboolvar("fluid_editing") && xctx->stretch_select) {
     mem_snapshot_alloc(&xctx->fluid_reroute_snap);
     mem_serialize_slot(&xctx->fluid_reroute_snap);
     xctx->fluid_reroute_wid = xctx->wire_id_counter;
     xctx->fluid_reroute_iid = xctx->inst_id_counter;
     xctx->fluid_reroute_gid = xctx->gfx_id_counter;
     xctx->fluid_reroute_tid = xctx->text_id_counter;
     xctx->fluid_reroute_active = 1;
     xctx->fluid_reroute_dirty = 0;
   }
  }
  if(what & ABORT)  /* abort operation */
  {
   /* incremental_wire_reroute.md Phase II: a fluid stretch that committed >=1 live RUBBER step has
    * mutated the live geometry. Roll it back to the pristine snapshot FIRST, so the rest of this
    * ABORT block (and the kissing pop_undo below) sees exactly the post-kiss/pre-move state a
    * preview-only drag would present; then drop the snapshot. Repaint at the block end because the
    * committed intermediate route was baked into the canvas. */
   int fluid_was_dirty = xctx->fluid_reroute_active && xctx->fluid_reroute_dirty;
   if(xctx->fluid_reroute_active) {
     if(xctx->fluid_reroute_dirty) fluid_reroute_restore();
     fluid_reroute_discard();
   }
   xctx->paste_from = 0;
   draw_selection(xctx->gctiled,0);
   if(xctx->kissing) {
     pop_undo(0, 0);
     /* connect_by_kissing() created zero-length stub wires at the kissed pins
      * (meant to be stretched by the move). On an aborted/no-motion gesture they
      * stay degenerate; the pop_undo above can miss them when the cadence
      * deselect-on-release path perturbed the undo pointers, so sweep them with
      * the same degenerate-wire cleanup the normal move END uses. */
     check_collapsing_objects();
   }
   /* Always clear the kissing request on abort, even when nothing was kissed
    * (xctx->kissing == 0). Otherwise connect_by_kissing stays at 2 and leaks
    * into the NEXT move/copy gesture -- e.g. a plain press that kisses nothing
    * would make a subsequent Shift+drag copy spuriously draw connecting wires.
    * move END already resets it unconditionally; mirror that here. */
   if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;
   /* clear the stretch-move flag too, so an aborted stretch gesture does not leak
    * the Phase-5 cleanup trigger into the next move (mirror of move END). */
   xctx->stretch_select = 0;
   xctx->stretch_grabbed_n = 0;
   my_free(_ALLOC_ID_, &xctx->stretch_grabbed_xy);

   xctx->move_rot=xctx->move_flip=0;
   xctx->deltax=xctx->deltay=0.;
   xctx->ui_state &= ~STARTMOVE;
   fluid_discard_snapshot(); /* Phase 1: aborted gesture -> drop the START snapshot */
   update_symbol_bboxes(0, 0);
   /* the rolled-back pristine geometry replaces the committed intermediate route on screen. No
    * set_modify(): the RUBBER steps never set it (see the live-step branch), so an aborted fluid
    * drag leaves the buffer's modified flag exactly as it was pre-drag. */
   if(fluid_was_dirty) draw();
  }
  if(what & RUBBER)  /* draw objects while moving */
  {
   if(xctx->mousex_snap == xctx->x2 && xctx->mousey_snap == xctx->y2) return;
   /* incremental_wire_reroute.md Phase II: when a fluid stretch owns a snapshot, reroute LIVE on
    * every snap-grid step -- restore the pristine geometry and re-apply the CURRENT TOTAL delta
    * through the reroute pipeline (the shared geometry-commit block below, reached via commit_now).
    * mousex/y_snap is already cadsnap-quantized, so passing the no-motion guard above == a move of
    * >= one cadsnap. Pure translation only (RUBBER never rotates; the rot/flip==0 test is a guard). */
   if(tclgetboolvar("fluid_editing") && (xctx->ui_state & STARTMOVE) && xctx->stretch_select &&
      xctx->fluid_reroute_active && xctx->move_rot == 0 && xctx->move_flip == 0) {
     xctx->x2 = xctx->mousex_snap; xctx->y2 = xctx->mousey_snap;
     xctx->deltax = xctx->x2 - xctx->x1; xctx->deltay = xctx->y2 - xctx->y1;
     fluid_reroute_restore();   /* live geometry+selection -> pristine (frees+reallocs the arrays) */
     commit_now = 1;            /* fall through to the shared END geometry-commit block */
   } else {
     /* default / non-fluid: rubber-band preview only (bottom draw_selection paints it) */
     xctx->x2=xctx->mousex_snap;xctx->y2=xctx->mousey_snap;
     draw_selection(xctx->gctiled,0);
     xctx->deltax = xctx->x2-xctx->x1; xctx->deltay = xctx->y2 - xctx->y1;
   }
  }
  if(what & ROTATELOCAL) {
   xctx->rotatelocal=1;
  }
  if(what & ROTATE) {
   draw_selection(xctx->gctiled,0);
   xctx->move_rot= (xctx->move_rot+1) & 0x3;
   update_symbol_bboxes(xctx->move_rot, xctx->move_flip);
  }
  if(what & FLIP)
  {
   draw_selection(xctx->gctiled,0);
   xctx->move_flip = !xctx->move_flip;
   update_symbol_bboxes(xctx->move_rot, xctx->move_flip);
  }
  if((what & END) || commit_now)     /* commit the move: real END, or a live fluid RUBBER step */
  {
   int firsti, firstw;
   /* issue 0081: diagonal X-then-Y decomposition (nlegs==2) + P2 safety net (attempt loop).
    * issue 0085: attempt 2 = rigid diagonal relay (leg_ortho / diag_relay), alt_snap holds the
    * ortho attempt-1 result for the never-worse compare. */
   int nlegs = 1, leg, attempt, leg_snapped = 0;
   int leg_ortho, diag_relay = 0, alt_snapped = 0, alt_pchg = 0, saved_ml_lines = 0;
   unsigned int alt_wid = 0, alt_iid = 0, alt_gid = 0, alt_tid = 0;
   double totdx = 0.0, totdy = 0.0;
   Undo_slot leg_snap, alt_snap;

   /* --- END-only pre-commit finalizers; a live fluid RUBBER step (commit_now) skips them and
    * jumps straight to the shared geometry commit below. --- */
   if(!commit_now) {
   int end_was_dirty = xctx->fluid_reroute_active && xctx->fluid_reroute_dirty;
   /* incremental_wire_reroute.md Phase II: on a fluid stretch, RUBBER steps committed intermediate
    * routes into the live geometry. Roll back to the pristine snapshot BEFORE push_undo, so the undo
    * baseline (and capture_undo_ids' object-shape guard) is the true pre-move state, not the last
    * intermediate route; then drop the snapshot. Unconditional on active (a release-only fluid
    * gesture frees its unused snapshot here too), and ABOVE the no-motion early return so a
    * zero-delta release still frees + rolls back. */
   if(xctx->fluid_reroute_active) {
     if(xctx->fluid_reroute_dirty) fluid_reroute_restore();
     fluid_reroute_discard();
   }

   dbg(1, "end move: unlink sel_file\n");
   xunlink(sel_file);
   xctx->paste_from = 0; /* end of a paste from clipboard command */
   if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;

   /* button released after clicking elements, without moving... do nothing */
   if(xctx->drag_elements && xctx->deltax==0 && xctx->deltay == 0) {
      xctx->ui_state &= ~STARTMOVE;
      /* Clear the stretch scope, like the normal END tail (2321-2323) and ABORT do: this early
       * return skips those, so otherwise stretch_select / stretch_grabbed_xy bleed into the NEXT
       * gesture -- a plain move would then run the stretch cleanup with stale grabbed coords, and
       * (Phase II) the START/RUBBER reroute gates key on stretch_select so a plain move would
       * spuriously reroute. Pre-existing leak on HEAD; closed here as Phase II makes this a
       * first-class path (a fluid drag out and back to the origin snap). */
      xctx->stretch_select = 0;
      xctx->stretch_grabbed_n = 0;
      my_free(_ALLOC_ID_, &xctx->stretch_grabbed_xy);
      /* a dirty fluid drag committed live steps that the roll-back above reverted to pristine --
       * repaint so the stale committed route is cleared from the canvas. */
      if(end_was_dirty) draw();
      return;
   }

   /* no undo push for MERGE ad PLACE, already done before */
   if(!xctx->kissing &&
      !(xctx->ui_state & (START_SYMPIN | STARTMERGE | PLACE_SYMBOL | PLACE_TEXT)) ) {
     dbg(1, "move_objects(END): push undo state\n");
     xctx->push_undo();
   }
   if((xctx->ui_state & PLACE_SYMBOL)) {
     int n = xctx->sel_array[0].n;
     const char *f =  abs_sym_path((xctx->inst[n].ptr+ xctx->sym)->name, "");
     tclvareval("c_toolbar::add {",f, "}; c_toolbar::display", NULL);
   }
   xctx->ui_state &= ~PLACE_SYMBOL;
   xctx->ui_state &= ~PLACE_TEXT;
   if(dx!=0.0 || dy!=0.0) {
     xctx->deltax = dx;
     xctx->deltay = dy;
   }
   } /* end if(!commit_now): END-only pre-commit finalizers */

   /* incremental_wire_reroute.md §10.10 / issue 0081: DIAGONAL fluid stretch decomposition.
    * A diagonal drag (both Dx,Dy != 0) gets NO aesthetic slide/shove -- compute_wire_slide() and
    * fluid_shove_connected_wire() both bail on `dxnz == dynz`, so place_moved_wire relays the pin's
    * follow-wire as a reversed leg through the moving instance's own body (P5) and the escape
    * staircase reappears. Decompose the TOTAL delta into a fixed X-leg then a Y-leg -- each a pure
    * axis move the existing machinery handles -- by running the shared geometry-commit region below
    * TWICE, re-deriving the follow set between legs (move_regrab_follow_set). Fixed X-then-Y (NOT
    * magnitude-derived): the split depends only on the total delta, never on the drag path or a
    * |Dx|==|Dy| crossing, so it is deterministic => release==stepwise (the Phase-II invariant).
    * Gated so nlegs stays 1 (single pass, byte-identical to HEAD) unless a fluid, orthogonal,
    * non-rotating stretch with a TOOL-OWNED-ONLY follow set (fluid_startsel_wires==0 -- the
    * deselect-tail's own gate, so leg A always clears its follow wires for the re-grab) moves
    * diagonally. P1 (connectivity) holds by construction -- the obstacle ml-flip + fluid_reroute_
    * around_obstacles run inside EACH leg. P2 (no-short) is NOT automatic: the obstacle detour only
    * fires on the diagonal SWEEP, so a per-axis leg can lay a stationary-device straddle as a
    * non-pin-incident wire the detour misses (R18 into ammeter v8). It is enforced by the P2 safety
    * net below (the attempt loop) -- decomposition is lowest in the conflict order and must yield to
    * P2. The index-keyed START snapshot is REUSED (never re-taken, which would bake a possibly-
    * shorted intermediate's nets). The region below is left BYTE-FOR-BYTE
    * in place (only wrapped + per-leg delta set) -- the strongest byte-identical guarantee, matching
    * the Phase-II commit_now fall-through discipline; the body indentation is intentionally not
    * re-flowed to keep this a minimal, auditable diff (`git diff -w` shows only the scaffolding). */
   totdx = xctx->deltax; totdy = xctx->deltay;
   if(tclgetboolvar("fluid_editing") && xctx->stretch_select && orthogonal_wiring &&
      xctx->move_rot == 0 && xctx->move_flip == 0 && xctx->fluid_startsel_wires == 0 &&
      totdx != 0.0 && totdy != 0.0) {
     nlegs = 2;
     /* snapshot pristine (current geometry+selection, pre-delta) for the P2 fallback below.
      * mem_snapshot_alloc only sets up the per-layer arrays and ASSUMES a zeroed slot (xctx's own
      * snapshot is calloc'd; this stack slot is not) -- zero it first or serialize free()s garbage. */
     memset(&leg_snap, 0, sizeof(leg_snap));
     mem_snapshot_alloc(&leg_snap); mem_serialize_slot(&leg_snap); leg_snapped = 1;
   }
   if(what & (RUBBER | END))
     fltrace("FLTRACE move: what=%s%s commit_now=%d totdx=%g totdy=%g fluid=%d stretch=%d ortho=%d rot=%d startsel_w=%d -> nlegs=%d\n",
         (what & END) ? "END" : "", (what & RUBBER) ? "RUBBER" : "", commit_now, totdx, totdy,
         tclgetboolvar("fluid_editing"), xctx->stretch_select, orthogonal_wiring, xctx->move_rot,
         xctx->fluid_startsel_wires, nlegs);
   /* P2 safety net (P1=P2 outrank the decomposition, which is quality-only). attempt 0 runs the
    * nlegs==2 decomposed legs; if they CHANGE CONNECTIVITY the one-shot diagonal pass would not --
    * the obstacle detour (fluid_reroute_around_obstacles) only fires on the diagonal SWEEP, so a
    * per-axis leg can route a wire across a stationary-device straddle (R18 into ammeter v8, a device
    * merge) or through a stationary net LABEL (a foreign-net merge) the detour misses -- attempt 1
    * rolls back to pristine and re-runs as a SINGLE diagonal pass (the proven no-short Layers-1-3
    * path). The trigger is fluid_partition_changed() (the full P1/P2 signal: device merge, net-label
    * merge, AND disconnect), not the two-pin device check alone. A clean two-leg result (partition
    * preserved), or nlegs==1 from the start, breaks after attempt 0. */
   for(attempt = 0; attempt < 3; ++attempt) {
   for(leg = 0; leg < nlegs; ++leg) {
   /* issue 0085: attempt 2 runs the shared region with orthogonal relaying OFF (rigid diagonal
    * relay): place_moved_wire's else-branch just translates the moved endpoint, laying NO new
    * copper and NO elbow that could land on anything -- the true P2 last resort. */
   leg_ortho = diag_relay ? 0 : orthogonal_wiring;
   if(nlegs == 2) {                    /* leg 0 = (Dx,0) X move; leg 1 = (0,Dy) Y move */
     xctx->deltax = (leg == 0) ? totdx : 0.0;
     xctx->deltay = (leg == 0) ? 0.0 : totdy;
     /* issue 0086: expose the REMAINING legs' delta so the leg-0 elbow tie-break can avoid painting
      * a co-moving pin's final landing point (fluid_ml_future_covers). Leg 1 has no remaining leg. */
     fluid_leg_future_dx = 0.0;
     fluid_leg_future_dy = (leg == 0) ? totdy : 0.0;
   } else {
     fluid_leg_future_dx = fluid_leg_future_dy = 0.0; /* single-pass attempts: tie-break inert */
   }
   if(what & (RUBBER | END))
     fltrace("FLTRACE move: attempt=%d leg=%d/%d deltax=%g deltay=%g\n", attempt, leg, nlegs,
         xctx->deltax, xctx->deltay);

   /* --- shared geometry commit: byte-for-byte identical for a real END and a fluid RUBBER step.
    * Re-fetch wire/line -- a fluid_reroute_restore() (in the RUBBER branch, or the dirty-END block
    * above) reallocated xctx->wire / xctx->line, so the function-entry captures are stale. --- */
   wire = xctx->wire;
   line = xctx->line;
   /* calculate moving symbols bboxes before actually doing the move */
   firsti = firstw = 1;
   if(!commit_now && leg == 0) draw_selection(xctx->gctiled,0);  /* END: erase last rubber-band (once) */
   update_symbol_bboxes(0, 0);
   /* corner-slide rubber-band (wire-editing Phase 4): on an orthogonal, axis-aligned,
    * non-rotating move, let perpendicular attached wires forming a corner SLIDE with
    * the pin instead of jogging at the moved end. Modifies/propagates the wire
    * selection and rebuilds sel_array, so it must run before the commit loop. */
   if(leg_ortho && xctx->move_rot == 0 && xctx->move_flip == 0 &&
      ((xctx->deltax != 0.0) != (xctx->deltay != 0.0))) {
     compute_wire_slide();
   }
   for(k=0;k<cadlayers; ++k)
   {
    for(i=0;i<xctx->lastsel; ++i)
    {
     c = xctx->sel_array[i].col;n = xctx->sel_array[i].n;
     switch(xctx->sel_array[i].type)
     {
      case WIRE:
       xctx->prep_hash_wires=0;
       firstw = 0;
       if(k == 0) {
         if(xctx->rotatelocal) {
           ROTATION(xctx->move_rot, xctx->move_flip, wire[n].x1, wire[n].y1,
              wire[n].x1, wire[n].y1, xctx->rx1,xctx->ry1);
           ROTATION(xctx->move_rot, xctx->move_flip, wire[n].x1, wire[n].y1,
              wire[n].x2, wire[n].y2, xctx->rx2,xctx->ry2);
         } else {
           ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
              wire[n].x1, wire[n].y1, xctx->rx1,xctx->ry1);
           ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
              wire[n].x2, wire[n].y2, xctx->rx2,xctx->ry2);
         }
         if( wire[n].sel & (SELECTED|SELECTED1) )
         {
          xctx->rx1+=xctx->deltax;
          xctx->ry1+=xctx->deltay;
         }
         if( wire[n].sel & (SELECTED|SELECTED2) )
         {
          xctx->rx2+=xctx->deltax;
          xctx->ry2+=xctx->deltay;
         }

         place_moved_wire(n, leg_ortho);
         /* place_moved_wire() -> storeobject() may my_realloc(xctx->wire), leaving the loop-local
          * `wire` alias dangling. Refresh it so a LATER sel_array WIRE entry (e.g. the second of a
          * two-follow-wire fluid drag -- R18's M and P risers) does not read freed memory. This
          * pre-existing k-loop staleness was previously latent (only single-follow-wire stretches
          * were exercised); test_wireedit_34 exposes it. (line[] is untouched by place_moved_wire.) */
         wire = xctx->wire;

       }
       break;

      case LINE:
       if(c!=k) break;
       if(xctx->rotatelocal) {
         ROTATION(xctx->move_rot, xctx->move_flip, line[c][n].x1, line[c][n].y1,
            line[c][n].x1, line[c][n].y1, xctx->rx1,xctx->ry1);
         ROTATION(xctx->move_rot, xctx->move_flip, line[c][n].x1, line[c][n].y1,
            line[c][n].x2, line[c][n].y2, xctx->rx2,xctx->ry2);
       } else {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            line[c][n].x1, line[c][n].y1, xctx->rx1,xctx->ry1);
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            line[c][n].x2, line[c][n].y2, xctx->rx2,xctx->ry2);
       }

       if( line[c][n].sel & (SELECTED|SELECTED1) )
       {
        xctx->rx1+=xctx->deltax;
        xctx->ry1+=xctx->deltay;
       }
       if( line[c][n].sel & (SELECTED|SELECTED2) )
       {
        xctx->rx2+=xctx->deltax;
        xctx->ry2+=xctx->deltay;
       }
       line[c][n].x1=xctx->rx1;
       line[c][n].y1=xctx->ry1;
       ORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);
       if( line[c][n].x1 == xctx->rx2 &&  line[c][n].y1 == xctx->ry2)
       {
        if(line[c][n].sel == SELECTED1) line[c][n].sel = SELECTED2;
        else if(line[c][n].sel == SELECTED2) line[c][n].sel = SELECTED1;
       }
       line[c][n].x1=xctx->rx1;
       line[c][n].y1=xctx->ry1;
       line[c][n].x2=xctx->rx2;
       line[c][n].y2=xctx->ry2;
       break;

      case POLYGON:
       if(c!=k) break;
       {
         xPoly *p = &xctx->poly[c][n];
         double bx1=0., by1=0., bx2=0., by2=0.;
         int j;
         double savex0, savey0;
         savex0 = p->x[0];
         savey0 = p->y[0];
         for(j=0; j<p->points; ++j) {
           if(j==0 || p->x[j] < bx1) bx1 = p->x[j];
           if(j==0 || p->y[j] < by1) by1 = p->y[j];
           if(j==0 || p->x[j] > bx2) bx2 = p->x[j];
           if(j==0 || p->y[j] > by2) by2 = p->y[j];

           if( p->sel==SELECTED || p->selected_point[j]) {
             if(xctx->rotatelocal) {
               ROTATION(xctx->move_rot, xctx->move_flip, savex0, savey0, p->x[j], p->y[j],
                        xctx->rx1,xctx->ry1);
             } else {
               ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1, p->x[j], p->y[j],
                        xctx->rx1,xctx->ry1);
             }

             p->x[j] =  xctx->rx1+xctx->deltax;
             p->y[j] =  xctx->ry1+xctx->deltay;
           }
         }
         for(j=0; j<p->points; ++j) {
           if(j==0 || p->x[j] < bx1) bx1 = p->x[j];
           if(j==0 || p->y[j] < by1) by1 = p->y[j];
           if(j==0 || p->x[j] > bx2) bx2 = p->x[j];
           if(j==0 || p->y[j] > by2) by2 = p->y[j];
         }
       }
       break;

      case ARC:
       if(c!=k) break;
       if(xctx->rotatelocal) {
         /* rotate center wrt itself: do nothing */
         xctx->rx1 = xctx->arc[c][n].x;
         xctx->ry1 = xctx->arc[c][n].y;
       } else {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            xctx->arc[c][n].x, xctx->arc[c][n].y, xctx->rx1,xctx->ry1);
       }
       angle = xctx->arc[c][n].a;
       if(xctx->move_flip) {
         angle = 270.*xctx->move_rot+180.-xctx->arc[c][n].b-xctx->arc[c][n].a;
       } else {
         angle = xctx->arc[c][n].a+xctx->move_rot*270.;
       }
       angle = fmod(angle, 360.);
       if(angle<0.) angle+=360.;
       if(xctx->arc[c][n].sel == SELECTED) {
         xctx->arc[c][n].x = xctx->rx1+xctx->deltax;
         xctx->arc[c][n].y = xctx->ry1+xctx->deltay;
         xctx->arc[c][n].a = angle;
       } else if(xctx->arc[c][n].sel == SELECTED1) {
         xctx->arc[c][n].x = xctx->rx1;
         xctx->arc[c][n].y = xctx->ry1;
         if(xctx->arc[c][n].r+xctx->deltax) xctx->arc[c][n].r = fabs(xctx->arc[c][n].r+xctx->deltax);
         xctx->arc[c][n].a = angle;
       } else if(xctx->arc[c][n].sel == SELECTED2) {
         angle = my_round(fmod(atan2(-xctx->deltay, xctx->deltax)*180./XSCH_PI+angle, 360.));
         if(angle<0.) angle +=360.;
         xctx->arc[c][n].x = xctx->rx1;
         xctx->arc[c][n].y = xctx->ry1;
         xctx->arc[c][n].a = angle;
       } else if(xctx->arc[c][n].sel==SELECTED3) {
         angle = my_round(fmod(atan2(-xctx->deltay, xctx->deltax)*180./XSCH_PI+xctx->arc[c][n].b, 360.));
         if(angle<0.) angle +=360.;
         if(angle==0) angle=360.;
         xctx->arc[c][n].x = xctx->rx1;
         xctx->arc[c][n].y = xctx->ry1;
         xctx->arc[c][n].b = angle;
       }

       break;

      case xRECT:
       if(c!=k) break;
       /* bbox before move */
       if(xctx->rotatelocal) {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
           xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->rect[c][n].x1, xctx->rect[c][n].y1,
           xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
       } else {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            xctx->rect[c][n].x1, xctx->rect[c][n].y1, xctx->rx1,xctx->ry1);
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            xctx->rect[c][n].x2, xctx->rect[c][n].y2, xctx->rx2,xctx->ry2);
       }

       flip_rotate_ellipse(&xctx->rect[c][n], xctx->move_rot, xctx->move_flip);

       if( xctx->rect[c][n].sel == SELECTED) {
         xctx->rx1+=xctx->deltax;
         xctx->ry1+=xctx->deltay;
         xctx->rx2+=xctx->deltax;
         xctx->ry2+=xctx->deltay;
       }
       else if( xctx->rect[c][n].sel == SELECTED1) {   /* 20070302 stretching on rectangles */
         xctx->rx1+=xctx->deltax;
         xctx->ry1+=xctx->deltay;
       }
       else if( xctx->rect[c][n].sel == SELECTED2) {
         xctx->rx2+=xctx->deltax;
         xctx->ry1+=xctx->deltay;
       }
       else if( xctx->rect[c][n].sel == SELECTED3) {
         xctx->rx1+=xctx->deltax;
         xctx->ry2+=xctx->deltay;
       }
       else if( xctx->rect[c][n].sel == SELECTED4) {
         xctx->rx2+=xctx->deltax;
         xctx->ry2+=xctx->deltay;
       }
       else if(xctx->rect[c][n].sel==(SELECTED1|SELECTED2))
       {
         xctx->ry1+=xctx->deltay;
       }
       else if(xctx->rect[c][n].sel==(SELECTED3|SELECTED4))
       {
         xctx->ry2+=xctx->deltay;
       }
       else if(xctx->rect[c][n].sel==(SELECTED1|SELECTED3))
       {
         xctx->rx1+=xctx->deltax;
       }
       else if(xctx->rect[c][n].sel==(SELECTED2|SELECTED4))
       {
         xctx->rx2+=xctx->deltax;
       }

       tx1 = xctx->rx1;
       ty1 = xctx->ry1;
       RECTORDER(xctx->rx1,xctx->ry1,xctx->rx2,xctx->ry2);

       if( xctx->rx2 == tx1) {
         if(xctx->rect[c][n].sel==SELECTED1) xctx->rect[c][n].sel = SELECTED2;
         else if(xctx->rect[c][n].sel==SELECTED2) xctx->rect[c][n].sel = SELECTED1;
         else if(xctx->rect[c][n].sel==SELECTED3) xctx->rect[c][n].sel = SELECTED4;
         else if(xctx->rect[c][n].sel==SELECTED4) xctx->rect[c][n].sel = SELECTED3;
       }
       if( xctx->ry2 == ty1) {
         if(xctx->rect[c][n].sel==SELECTED1) xctx->rect[c][n].sel = SELECTED3;
         else if(xctx->rect[c][n].sel==SELECTED3) xctx->rect[c][n].sel = SELECTED1;
         else if(xctx->rect[c][n].sel==SELECTED2) xctx->rect[c][n].sel = SELECTED4;
         else if(xctx->rect[c][n].sel==SELECTED4) xctx->rect[c][n].sel = SELECTED2;
       }

       xctx->rect[c][n].x1 = xctx->rx1;
       xctx->rect[c][n].y1 = xctx->ry1;
       xctx->rect[c][n].x2 = xctx->rx2;
       xctx->rect[c][n].y2 = xctx->ry2;

       /* bbox after move */
       break;

      case xTEXT:
       if(k!=TEXTLAYER) break;
       #if HAS_CAIRO==1  /* bbox before move */
       customfont = set_text_custom_font(&xctx->text[n]);
       #endif
       estr = my_expand(get_text_floater(n), tclgetintvar("tabstop"));
       text_bbox(estr, xctx->text[n].xscale,
          xctx->text[n].yscale, xctx->text[n].rot,xctx->text[n].flip, xctx->text[n].hcenter,
          xctx->text[n].vcenter, xctx->text[n].x0, xctx->text[n].y0,
          &xctx->rx1,&xctx->ry1, &xctx->rx2,&xctx->ry2, &tmpint, &dtmp);
       my_free(_ALLOC_ID_, &estr);
       #if HAS_CAIRO==1
       if(customfont) {
         cairo_restore(xctx->cairo_ctx);
       }
       #endif
       if(xctx->rotatelocal) {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->text[n].x0, xctx->text[n].y0,
           xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
       } else {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            xctx->text[n].x0, xctx->text[n].y0, xctx->rx1,xctx->ry1);
       }
       xctx->text[n].x0=xctx->rx1+xctx->deltax;
       xctx->text[n].y0=xctx->ry1+xctx->deltay;
       xctx->text[n].rot=(xctx->text[n].rot +
        ( (xctx->move_flip && (xctx->text[n].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3;
       xctx->text[n].flip=xctx->move_flip^xctx->text[n].flip;

       #if HAS_CAIRO==1  /* bbox after move */
       customfont = set_text_custom_font(&xctx->text[n]);
       #endif
       estr = my_expand(get_text_floater(n), tclgetintvar("tabstop"));
       text_bbox(estr, xctx->text[n].xscale,
          xctx->text[n].yscale, xctx->text[n].rot,xctx->text[n].flip, xctx->text[n].hcenter,
          xctx->text[n].vcenter, xctx->text[n].x0, xctx->text[n].y0,
          &xctx->rx1,&xctx->ry1, &xctx->rx2,&xctx->ry2, &tmpint, &dtmp);
       my_free(_ALLOC_ID_, &estr);
       #if HAS_CAIRO==1
       if(customfont) {
         cairo_restore(xctx->cairo_ctx);
       }
       #endif

       break;

      default:
       break;
     } /* end switch(xctx->sel_array[i].type) */
    } /* end for(i=0;i<xctx->lastsel; ++i) */
   } /*end for(k=0;k<cadlayers; ++k) */

   for(i = 0; i < xctx->lastsel; ++i) {
     n = xctx->sel_array[i].n;
     if(xctx->sel_array[i].type == ELEMENT) {
       xctx->prep_hash_inst=0;
       firsti = 0;
       if(xctx->rotatelocal) {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->inst[n].x0, xctx->inst[n].y0,
            xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
       } else {
         ROTATION(xctx->move_rot, xctx->move_flip, xctx->x1, xctx->y1,
            xctx->inst[n].x0, xctx->inst[n].y0, xctx->rx1,xctx->ry1);
       }
       xctx->inst[n].x0 = xctx->rx1+xctx->deltax;
       xctx->inst[n].y0 = xctx->ry1+xctx->deltay;
       xctx->inst[n].rot = (xctx->inst[n].rot +
        ( (xctx->move_flip && (xctx->inst[n].rot & 1) ) ? xctx->move_rot+2 : xctx->move_rot) ) & 0x3;
       xctx->inst[n].flip = xctx->move_flip ^ xctx->inst[n].flip;
       symbol_bbox(n,
          &xctx->inst[n].x1, &xctx->inst[n].y1,
          &xctx->inst[n].x2, &xctx->inst[n].y2);
     }
   }
   if(!firsti || !firstw) {
     xctx->prep_net_structs=0;
     xctx->prep_hi_structs=0;
   }
   /* incremental_wire_reroute.md Layer 2 (spec sec 5/6): pre-trim rip-up-and-reroute detour. When
    * both L orientations were blocked (place_moved_wire could not flip away the short) the naive
    * route still lays a leg straight across a stationary device between two of its distinct-net pins.
    * Re-detect that residual straddle and route the moving pin AROUND the device with a stop-short
    * junction. Runs on the SAME shared commit block as a real END and a live fluid RUBBER step, so
    * release == stepwise for free. Gated identically to the Layer-1 flip; default off => byte-
    * identical (the whole function early-returns without a fluid START name snapshot). Placed before
    * check_collapsing_objects/trim so the existing cleanup normalises the new geometry once. */
   if(tclgetboolvar("fluid_editing") && xctx->stretch_select &&
      xctx->move_rot == 0 && xctx->move_flip == 0) {
     /* issue 0015 §7: shove a connected wire the moving pin drove past (serves P5), THEN the obstacle
      * layer gets the last word on P2 for anything with a moving-pin endpoint. */
     fluid_shove_connected_wire(leg_ortho);
     fluid_reroute_around_obstacles(leg_ortho);
     /* issue 0083: a NO-SHORT foreign-pin landing buries the offset solder-joint + grazes the body.
      * Restore the V-H-V + visible offset dot. Gated to a PURE-AXIS delta (one of deltax/deltay zero).
      * That fires it for a genuine pure-axis nlegs==1 move AND for EACH leg of the 0081 diagonal
      * decomposition (leg 0 = the pure-X move, leg 1 = the pure-Y move) -- so a diagonal drag that lands
      * the riser in the body is offset on its X leg, then the Y leg re-grabs the now-offset (outside-body)
      * riser and declines. A genuine diagonal delta (the 0081 P2 single-pass fallback, or a pre-selected
      * follow wire keeping nlegs==1) leaves BOTH nonzero -> does NOT fire (that single diagonal pass is
      * fluid_reroute's job, not this one). The internal guards + the same-net-only rule keep every firing
      * decline-to-baseline safe regardless (adversarial reviews wf_3029984d / wf_e96154bf). */
     fltrace("FLTRACE offset-call: deltax=%g deltay=%g pure_axis_gate=%d\n",
             xctx->deltax, xctx->deltay, (xctx->deltax == 0.0 || xctx->deltay == 0.0));
     if(xctx->deltax == 0.0 || xctx->deltay == 0.0)
       fluid_offset_foreign_pin_landing(leg_ortho);
   } else if(what & (RUBBER | END)) {
     fltrace("FLTRACE fluid-block: SKIPPED (fluid=%d stretch=%d rot=%d flip=%d)\n",
             tclgetboolvar("fluid_editing"), xctx->stretch_select, xctx->move_rot, xctx->move_flip);
   }
   /* build after copying and after recalculating prepare_netlist_structs() */
   check_collapsing_objects();
   /* Release-time cleanup (wire-editing Phase 5, Issue D3). On a STRETCH move the
    * rubber-band can leave redundant routing. Run it for stretch moves even when
    * autotrim_wires is off (the cadence rubber-band feel shouldn't depend on that
    * preference). Order matters:
    *   1. trim_wires() first: merge colinear degree-2 fragments (TC7) and drop
    *      included/overlapping duplicates (TC8);
    *   2. remove_move_orphan_wires() on the cleaned geometry: drop redundant dangling
    *      stubs this move produced (TC9). It must see post-trim geometry, else an
    *      overlapping colinear pair would look like a stub-on-a-wire. */
   /* W3: when autotrim is on a stretch/move can create or remove an attachment, so run the
    * full re-split/rejoin (maintain). When autotrim is OFF, a stretch still needs the plain
    * trim cleanup (merge colinear degree-2 fragments, drop dups) but must NOT split at pins
    * (D2 -- default users get no auto-split). See doc/claude/specs/wire_segment_splitting.md. */
   if(tclgetboolvar("autotrim_wires")) maintain_wire_segments();
   else if(xctx->stretch_select) trim_wires();
   if(xctx->stretch_select) remove_move_orphan_wires();
   /* Exit-stub preservation (wire-editing Phase 6, Issue E -> R13). After the cleanup above,
    * ensure each moved DEVICE pin's route leaves the pin along the pin's outward escape normal
    * (get_pin_escape_normal, geometry nearest-edge -- nice_drag_rerouting Phase 3 §6/§8) with a
    * short stub before the first bend. Runs AFTER trim_wires() so the stub is never merged
    * back. Gated on wire_exit_stub || fluid_editing (both default OFF) => byte-identical when
    * off. The fluid gate was previously DEFERRED because insert_exit_stubs disconnected a net
    * on a plain fluid drag (a -x/-y escape stub stored unordered -> touch() failed to bind the
    * pin, caught by the Phase-1 P1 guard). order_wire_coords() now normalizes every wire the
    * function writes, closing that (endpoint-ordering) disconnect class, so the fluid gate is
    * enabled. P1/connectivity is preserved for the tap cases too: a pin tap on the slid leg is
    * skipped by the point_on_fixed_pin guard, and a wire tap is a split junction the has_corner
    * neighbour-drag carries along (tests test_wireedit_29..31). NOT yet handled: the SLIDE can
    * still shift the leg/stub one grid onto a DIFFERENT net's wire -> a no-short (P2) hazard,
    * which is nice_drag_rerouting Phase 4 (no-short guard + rip-up) and is caught log-only by
    * fluid_check_move_invariants until then. See doc/claude/specs/nice_drag_rerouting.md. */
   /* issue 0086: FINAL leg only (leg == nlegs-1; unchanged for single-pass moves, nlegs==1). The
    * P3 exit stub is a final-state aesthetic: inserted at a leg-0 (intermediate) pin position it
    * plants a stub anchored INSIDE the later leg's stretch corridor (before_3.sch, R18 (+150,-80):
    * the (-250,-80)..(-250,-70) stub), and leg 1's follow stretch from that anchor is a degenerate
    * straight run across the other pin's landing -- a guaranteed short no elbow can avoid. The
    * final leg re-inserts stubs at the true (post-move) pin positions, so the P3 look is intact. */
   if(xctx->stretch_select &&
      (tclgetboolvar("wire_exit_stub") || tclgetboolvar("fluid_editing")) && leg_ortho &&
      xctx->move_rot == 0 && xctx->move_flip == 0 && leg == nlegs - 1) {
     insert_exit_stubs();
   }
   unselect_partial_sel_wires();
   /* incremental_wire_reroute Phase I (ownership decoupling, spec §4). A fluid stretch grabs the
    * wires attached to the moving selection into the SELECTION (select_attached_nets marks them
    * SELECTED1/2; compute_wire_slide promotes corner wires to full SELECTED), so with the cadence
    * default unselect_partial_sel_wires=0 they PERSIST as user selection after the drag -- the
    * user's complaint ("wires get selected when I only move an instance"). When the user selected
    * NO wires of her own (fluid_startsel_wires==0), every wire selected at END is a tool-owned
    * follow-wire: deselect them all so they are transient, not persistent user selection. This runs
    * AFTER all reroute/cleanup, touching only sel-flags => wire GEOMETRY is byte-identical (the
    * route is unchanged; Phase I is bookkeeping only). Gated on fluid_editing => default off is
    * byte-identical. The mixed case (user also selected wires, fluid_startsel_wires>0) is deferred
    * to a later phase: stand down and leave the selection as the stretch left it. */
   if(tclgetboolvar("fluid_editing") && xctx->stretch_select && xctx->fluid_startsel_wires == 0) {
     int wi, any = 0;
     /* direct clear (not select_wire(...,0,...)): a wire grabbed at BOTH ends is sel==
      * (SELECTED1|SELECTED2), which select_wire would fold to SELECTED instead of deselecting
      * (select.c:965). The following draw() repaints, so the un-highlight is handled there. */
     for(wi = 0; wi < xctx->wires; ++wi) if(xctx->wire[wi].sel) { xctx->wire[wi].sel = 0; any = 1; }
     if(any) { xctx->need_reb_sel_arr = 1; rebuild_selected_array(); }
   }
   /* issue 0081: end of one X-then-Y decomposition leg. After leg 0 (the X move + its cleanup + the
    * follow-wire deselect above) re-derive a fresh SELECTED1/2 follow set at the X-moved pins, so
    * leg 1 (the Y move) is a clean pure-axis stretch that relays each stub exactly once. */
   if(nlegs == 2 && leg == 0) move_regrab_follow_set();
   } /* end for(leg): issue 0081 diagonal X-then-Y decomposition */
   if(!leg_snapped) break;            /* plain single-pass move (no decomposition snapshot): commit as-is */
   /* attempt done: restore the accumulated total delta, then P2-check the composite route.
    * issue 0085: this check now also covers the attempt-1 single diagonal pass -- its blind-elbow
    * relays proved they CAN short (own-pin plow / stray wire-endpoint T, after_5.sch), so it is no
    * longer accepted sight-unseen; attempt 2 is the rigid diagonal relay above. */
   xctx->deltax = totdx; xctx->deltay = totdy;
   prepare_netlist_structs(0);        /* refresh inst[].node[] for the partition test */
   {
   int pchg;
   if(fluid_trace_on()) {
     int wi;
     for(wi = 0; wi < xctx->wires; ++wi)
       fltrace("FLTRACE wires:   attempt=%d w=%d [%g %g %g %g] sel=%u lab=%s\n", attempt, wi,
               xctx->wire[wi].x1, xctx->wire[wi].y1, xctx->wire[wi].x2, xctx->wire[wi].y2,
               xctx->wire[wi].sel, get_tok_value(xctx->wire[wi].prop_ptr, "lab", 0));
   }
   pchg = fluid_partition_changed();
   fltrace("FLTRACE move: attempt=%d done (nlegs=%d diag_relay=%d), partition_changed=%d %s\n",
           attempt, nlegs, diag_relay, pchg,
           pchg == 0 ? "-> ACCEPT" : attempt == 0 ? "-> ROLLBACK to single diagonal pass" :
           attempt == 1 ? "-> ROLLBACK to rigid diagonal relay" : "(last resort)");
   if(pchg == 0) break;               /* connectivity preserved (no merge/disconnect): accept */
   if(attempt == 2) {
     /* the rigid relay STILL changed the partition: either an intentional landing (a pin dropped
      * onto live copper -- every attempt shows it) or an unroutable scene. Keep the relay ONLY
      * when fully clean (pchg==0, handled by the break above); otherwise put the ortho attempt-1
      * result back. NOT `pchg < alt_pchg`: fluid_partition_changed()'s per-pin diff count is
      * cascade-sensitive (first-seen relabeling inflates one early merge past two late ones --
      * review wf_e348633c F5), so ordering two nonzero counts can prefer MORE real damage; the
      * only trustworthy verdict is zero/nonzero. Restore alt's OWN id counters (not the START
      * ones): they match the geometry being restored. */
     if(alt_snapped) {
       unsigned int saved_ui = xctx->ui_state;
       mem_restore_slot(&alt_snap, 0);
       xctx->ui_state = saved_ui;
       xctx->wire_id_counter = alt_wid;
       xctx->inst_id_counter = alt_iid;
       xctx->gfx_id_counter  = alt_gid;
       xctx->text_id_counter = alt_tid;
       xctx->need_reb_sel_arr = 1; rebuild_selected_array();
       xctx->movelastsel = xctx->lastsel;
       fltrace("FLTRACE move: rigid relay not clean (%d, attempt-1 had %d): kept ortho attempt-1 result\n",
               pchg, alt_pchg);
     }
     break;
   }
   if(attempt == 1) {
     /* issue 0085: snapshot the shorted-but-orthogonal attempt-1 result for the never-worse compare,
      * then arm the rigid relay: manhattan jogs off (place_moved_wire's else-branch translates the
      * moved endpoint; the wire goes diagonal) and the fluid passes decline via leg_ortho==0. */
     memset(&alt_snap, 0, sizeof(alt_snap));
     mem_snapshot_alloc(&alt_snap); mem_serialize_slot(&alt_snap); alt_snapped = 1;
     alt_pchg = pchg;
     alt_wid = xctx->wire_id_counter;
     alt_iid = xctx->inst_id_counter;
     alt_gid = xctx->gfx_id_counter;
     alt_tid = xctx->text_id_counter;
     saved_ml_lines = xctx->manhattan_lines;
     xctx->manhattan_lines = 0;
     diag_relay = 1;
   }
   /* the attempt changed connectivity: roll back to pristine + retry the next fallback.
    * Mirror fluid_reroute_restore(): mem_restore_slot zeroes ui_state/lastsel and reallocs the
    * arrays, so put back ui_state, the START id counters (determinism), sel_array, and movelastsel. */
   { unsigned int saved_ui = xctx->ui_state;
     mem_restore_slot(&leg_snap, 0);
     xctx->ui_state = saved_ui;
     xctx->wire_id_counter = xctx->fluid_reroute_wid;
     xctx->inst_id_counter = xctx->fluid_reroute_iid;
     xctx->gfx_id_counter  = xctx->fluid_reroute_gid;
     xctx->text_id_counter = xctx->fluid_reroute_tid;
     xctx->need_reb_sel_arr = 1; rebuild_selected_array();
     xctx->movelastsel = xctx->lastsel;
   }
   nlegs = 1;                          /* attempts 1/2: single pass from the restored pristine */
   xctx->deltax = totdx; xctx->deltay = totdy;
   } /* end pchg block */
   } /* end for(attempt): P2 safety net */
   fluid_leg_future_dx = fluid_leg_future_dy = 0.0;  /* issue 0086: never leak past the gesture */
   if(diag_relay) xctx->manhattan_lines = saved_ml_lines;
   if(alt_snapped) mem_snapshot_free(&alt_snap);
   if(leg_snapped) mem_snapshot_free(&leg_snap);
   /* the END delta-zeroing (below) and the commit_now redraw save/restore consume xctx->deltax/deltay
    * as the true accumulated total (not the last leg's split); it is set to (totdx,totdy) above. */
   /* --- END-only post-commit finalizers. A live fluid RUBBER step (commit_now) keeps the gesture
    * state and only repaints. stretch_select / stretch_grabbed_xy MUST be cleared/freed HERE, not
    * inside the shared commit above -- they scope the reroute (remove_move_orphan_wires reads
    * stretch_grabbed_xy) and must survive every per-step commit, to be freed exactly once at the
    * real END/ABORT (folding them into the shared commit would UAF on step 2 and double-free). --- */
   if(!commit_now) {
     xctx->stretch_select = 0;
     xctx->stretch_grabbed_n = 0;
     my_free(_ALLOC_ID_, &xctx->stretch_grabbed_xy);

     if(xctx->hilight_nets) {
       propagate_hilights(1, 1, XINSERT_NOREPLACE);
     }

     xctx->ui_state &= ~STARTMOVE;
     if(xctx->ui_state & STARTMERGE) xctx->ui_state |= SELECTION; /* leave selection state so objects can be deleted */
     xctx->ui_state &= ~STARTMERGE;
     xctx->move_rot=xctx->move_flip=0;
     xctx->x1=xctx->y1=xctx->x2=xctx->y2=xctx->deltax=xctx->deltay=0.;
     /* P3 write-through: a moved pin-name view records its new offset on the owning pin;
      * a pin moved without its view makes the view follow (Option B). */
     pin_views_reconcile_after_move();
     fluid_check_move_invariants(); /* Phase 1 runtime P1/P2 guard (log-only, gated on fluid_editing) */
     set_modify(1); /* must be done before draw() if floaters are present to force cached values update */
     draw();
     xctx->rotatelocal=0;
   } else {
     /* incremental_wire_reroute.md Phase II live step: the reroute is committed into the live
      * geometry but the gesture stays open. Mark dirty (END must roll back to pristine before its
      * push_undo), then repaint. The committed geometry ALREADY includes the delta, so zero delta
      * around the redraw (draw_selection paints at coord+delta -> would double-offset) and RESTORE
      * it after: the interactive END is move_objects(END,0,0,0) and consumes xctx->deltax/deltay as
      * the accumulated total, so leaving it zeroed would snap the whole move back to the origin. */
     double sdx = xctx->deltax, sdy = xctx->deltay;
     xctx->fluid_reroute_dirty = 1;
     /* Deliberately NO set_modify() here: like a non-fluid drag preview, the buffer's modified flag
      * is set only at the REAL END, so a fluid drag that is aborted or returns to the origin stays
      * clean (no spurious modified/save-prompt). Floater caches still refresh live -- each step's
      * fluid_reroute_restore() -> mem_restore_slot() invalidates floater_inst_table, so the draw()
      * below recomputes them from the current geometry. */
     xctx->deltax = xctx->deltay = 0.0;
     draw();
     draw_selection(xctx->gc[SELLAYER], 0);
     if(tclgetboolvar("draw_crosshair")) draw_crosshair(3, 0);
     xctx->deltax = sdx; xctx->deltay = sdy;
   }
  } /* what & end (or a live fluid commit_now step) */
  if(!commit_now) {
    draw_selection(xctx->gc[SELLAYER], 0);
    if(tclgetboolvar("draw_crosshair")) draw_crosshair(3, 0); /* what = 1(clear) + 2(draw) */
  }
}
