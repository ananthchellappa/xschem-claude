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

void draw_selection(GC g, int interruptable)
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
    if(!firsti || !firstw) {
      xctx->prep_net_structs=0;
      xctx->prep_hi_structs=0;
    }
    /* build after copying and after recalculating prepare_netlist_structs() */
    check_collapsing_objects();
    if(tclgetboolvar("autotrim_wires")) trim_wires();
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
      if(px == x && py == y) return 1;
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
      if(px == x && py == y) return 1;
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
      /* a corner needs another wire endpoint coincident with the far end */
      for(m = 0; m < xctx->wires; m++) {
        if(m == n) continue;
        if((wire[m].x1 == fx && wire[m].y1 == fy) ||
           (wire[m].x2 == fx && wire[m].y2 == fy)) { has_corner = 1; break; }
      }
      if(!has_corner) continue;        /* free dangling far end -> jog (TC3) */

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
    doomed[i] = 1;
    removed = 1;
  }
  if(removed) {
    wire_delete_compact(wire_doomed_flag, doomed);
    xctx->prep_hash_wires = 0;
    xctx->prep_net_structs = 0;
    xctx->prep_hi_structs = 0;
    xctx->need_reb_sel_arr = 1;
    set_modify(1);
  }
  my_free(_ALLOC_ID_, &doomed);
}

/* Exit-stub preservation (wire-editing Phase 6, Issue E -> R13, TC10). The "dream":
 * after a stretch move, a short stub leaves each moved pin along the pin's OUTWARD
 * NORMAL (its natural lead direction) before the route's first bend, so the wire
 * physically exits the pin the way the symbol draws its lead rather than turning
 * immediately. A uniform, symbol-driven rule (the most predictable one -- Issue E).
 *
 * For each MOVING (selected) instance pin carrying exactly one attached wire (the
 * route's first leg):
 *   - the pin's outward normal = the dominant axis of (pin - symbol-bbox-center); e.g.
 *     res.sym pin M sits at the top of a +y lead (body below it) so it exits +y. (The
 *     bbox can be skewed a little by pin-number text, but for real symbols the pin's
 *     outward offset dwarfs that skew, so the dominant axis is the lead direction.)
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
static void insert_exit_stubs(void)
{
  int inst, r, rects, n, m;
  double grid = tclgetdoublevar("cadsnap");
  if(grid <= 0.0) grid = 1.0;
  for(inst = 0; inst < xctx->instances; inst++) {
    double bx1, by1, bx2, by2, cx, cy;
    if(!xctx->inst[inst].sel) continue;        /* only MOVING instances */
    if(xctx->inst[inst].ptr < 0) continue;
    symbol_bbox(inst, &bx1, &by1, &bx2, &by2);
    cx = (bx1 + bx2) / 2.0; cy = (by1 + by2) / 2.0;
    rects = (xctx->inst[inst].ptr + xctx->sym)->rects[PINLAYER];
    for(r = 0; r < rects; r++) {
      double px, py, ddx, ddy, nx, ny, sx, sy, fx, fy, nfx, nfy;
      int wfound = -1, endsel = 0, cnt = 0, has_corner = 0;
      get_inst_pin_coord(inst, r, &px, &py);
      /* outward normal = dominant axis of (pin - symbol center) */
      ddx = px - cx; ddy = py - cy;
      if(ddx == 0.0 && ddy == 0.0) continue;
      if(fabs(ddx) >= fabs(ddy)) { nx = (ddx > 0) ? 1.0 : -1.0; ny = 0.0; }
      else                       { nx = 0.0; ny = (ddy > 0) ? 1.0 : -1.0; }
      /* exactly one wire endpoint exactly on the pin = the route's first leg */
      for(n = 0; n < xctx->wires; n++) {
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
      for(m = 0; m < xctx->wires; m++) {
        if(m == n) continue;
        if((xctx->wire[m].x1 == fx && xctx->wire[m].y1 == fy) ||
           (xctx->wire[m].x2 == fx && xctx->wire[m].y2 == fy)) { has_corner = 1; break; }
      }
      if(!has_corner) continue;

      /* slide the first leg one grid out along the normal; drag the corner with it */
      sx  = px + grid * nx; sy  = py + grid * ny;   /* stub tip = leg's new pin end  */
      nfx = fx + grid * nx; nfy = fy + grid * ny;   /* leg's new far (corner) end     */
      for(m = 0; m < xctx->wires; m++) {            /* drag every neighbour at the corner */
        if(m == n) continue;
        if(xctx->wire[m].x1 == fx && xctx->wire[m].y1 == fy) { xctx->wire[m].x1 = nfx; xctx->wire[m].y1 = nfy; }
        if(xctx->wire[m].x2 == fx && xctx->wire[m].y2 == fy) { xctx->wire[m].x2 = nfx; xctx->wire[m].y2 = nfy; }
      }
      if(endsel == 1) { xctx->wire[n].x1 = sx; xctx->wire[n].y1 = sy; xctx->wire[n].x2 = nfx; xctx->wire[n].y2 = nfy; }
      else            { xctx->wire[n].x2 = sx; xctx->wire[n].y2 = sy; xctx->wire[n].x1 = nfx; xctx->wire[n].y1 = nfy; }
      /* fill the gap at the pin with the short exit stub (inherits the leg's net prop) */
      storeobject(-1, px, py, sx, sy, WIRE, 0, 0, xctx->wire[n].prop_ptr);
    }
  }
  xctx->prep_hash_wires = 0;
  xctx->prep_net_structs = 0;
  xctx->prep_hi_structs = 0;
  xctx->need_reb_sel_arr = 1;
  set_modify(1);
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
  xLine ** const line = xctx->line;
  xWire * const wire = xctx->wire;

  dbg(1, "move_objects: what=%d, dx=%g, dy=%g\n", what, dx, dy);
  if(what & START)
  {
   xctx->rotatelocal=0;
   xctx->deltax = xctx->deltay = 0.0;
   rebuild_selected_array();
   if(xctx->lastsel==0) return;
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
  }
  if(what & ABORT)  /* abort operation */
  {
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
   update_symbol_bboxes(0, 0);
  }
  if(what & RUBBER)  /* draw objects while moving */
  {
   if(xctx->mousex_snap == xctx->x2 && xctx->mousey_snap == xctx->y2) return;
   xctx->x2=xctx->mousex_snap;xctx->y2=xctx->mousey_snap;
   draw_selection(xctx->gctiled,0);
   xctx->deltax = xctx->x2-xctx->x1; xctx->deltay = xctx->y2 - xctx->y1;
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
  if(what & END)                                 /* move selected objects */
  {
   int firsti, firstw;

   dbg(1, "end move: unlink sel_file\n");
   xunlink(sel_file);
   xctx->paste_from = 0; /* end of a paste from clipboard command */
   if(xctx->connect_by_kissing == 2) xctx->connect_by_kissing = 0;

   /* button released after clicking elements, without moving... do nothing */
   if(xctx->drag_elements && xctx->deltax==0 && xctx->deltay == 0) {
      xctx->ui_state &= ~STARTMOVE;
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
   /* calculate moving symbols bboxes before actually doing the move */
   firsti = firstw = 1;
   draw_selection(xctx->gctiled,0);
   update_symbol_bboxes(0, 0);
   /* corner-slide rubber-band (wire-editing Phase 4): on an orthogonal, axis-aligned,
    * non-rotating move, let perpendicular attached wires forming a corner SLIDE with
    * the pin instead of jogging at the moved end. Modifies/propagates the wire
    * selection and rebuilds sel_array, so it must run before the commit loop. */
   if(orthogonal_wiring && xctx->move_rot == 0 && xctx->move_flip == 0 &&
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

         place_moved_wire(n, orthogonal_wiring);

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
   if(xctx->stretch_select || tclgetboolvar("autotrim_wires")) trim_wires();
   if(xctx->stretch_select) remove_move_orphan_wires();
   /* Exit-stub preservation (wire-editing Phase 6, Issue E -> R13). After the cleanup
    * above, ensure each moved pin's route leaves the pin along the pin's outward normal
    * (a short stub before the first bend). Runs AFTER trim_wires() so the stub it inserts
    * is never merged back. Gated on wire_exit_stub (default OFF) -- the biggest behavior
    * change, so it ships dark and leaves every existing move byte-identical when off. */
   if(xctx->stretch_select && tclgetboolvar("wire_exit_stub") && orthogonal_wiring &&
      xctx->move_rot == 0 && xctx->move_flip == 0) {
     insert_exit_stubs();
   }
   unselect_partial_sel_wires();
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
   set_modify(1); /* must be done before draw() if floaters are present to force cached values update */
   draw();
   xctx->rotatelocal=0;
  } /* what & end */
  draw_selection(xctx->gc[SELLAYER], 0);
  if(tclgetboolvar("draw_crosshair")) draw_crosshair(3, 0); /* what = 1(clear) + 2(draw) */
}
