/* File: editprop.c
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

#include <stdarg.h>
#include "xschem.h"

double mylog10(double x)
{
  if(x > 0) return log10(x);
  else return -35;
}

double mylog(double x)
{
  if(x > 0) return log(x);
  else return -35;
}





/* if s is an double return double value
 * else if s == ( 1 | true | on | yes) return -1.0
 * else if s == (false | off | no) return 0.0
 * else return 0.0
 */
double get_attr_val(const char *str)
{
  double s = 0.0;
  char *endptr;

  if(!str) return 0.0;
  else if(!my_strcasecmp(str, "true") ||
     !my_strcasecmp(str, "1") ||
     !my_strcasecmp(str, "on") ||
     !my_strcasecmp(str, "yes")) s = -1.0;
  else if(!my_strcasecmp(str, "false") ||
     !my_strcasecmp(str, "off") ||
     !my_strcasecmp(str, "no")) s = 0.0;
  else if((strtod(str, &endptr), endptr) > str) { /* NUMBER */
    s = atof(str);
  }

  return s;
}













/* recognizes spice suffixes: 12p --> 1.2e11, 3MEG --> 3e6 */
double atof_spice(const char *s)
{
  int n;
  double a = 0.0, mul=1.0;
  char lower_s[100];
  char suffix[100]={0};
  const char *p;

  if(!s) return 0.0;
  my_strncpy(lower_s, s, S(lower_s));
  strtolower(lower_s);
  n = sscanf(lower_s, "%lf%s", &a, suffix);
  if(n == 0) {
    return 0.0;
  } else if(n == 1) {
    mul = 1.0;
  } else {
    p = strpbrk(suffix, "tgmxkunpfa");
    if(p != suffix ) mul = 1.0;
    else if(*p == 't') mul=1e12;
    else if(*p == 'g') mul=1e9;
    else if(*p == 'x') mul=1e6; /* Xyce extension */
    else if(*p == 'm') {
      if(strstr(p, "meg") == p) mul=1e6;
      else if(strstr(p, "mil") == p) mul=25.4e-6;
      else mul=1e-3;
    }
    else if(*p == 'k') mul=1e3;
    else if(*p == 'u') mul=1e-6;
    else if(*p == 'n') mul=1e-9;
    else if(*p == 'p') mul=1e-12;
    else if(*p == 'f') mul=1e-15;
    else if(*p == 'a') mul=1e-18;
    else mul = 1.0;
    a *= mul;
  }
  return a;
}


/* same as atof_spice, but recognizes 'M' as Mega, and 'm' as Milli
 * as long as not 'MEG' or 'meg' which is always Mega */
double atof_eng(const char *s)
{
  int n;
  double a = 0.0, mul=1.0;
  char suffix[100]={0, 0, 0, 0, 0};
  const char *p;

  if(!s) return 0.0;
  n = sscanf(s, "%lf%s", &a, suffix);
  if(n == 0) {
    return 0.0;
  } else if(n == 1) {
    mul = 1.0;
  } else {
    p = strpbrk(suffix, "TGMXKUNPFAtgmxkunpfa");
    if(p != suffix ) mul = 1.0;
    else if(tolower(*p) == 't') mul=1e12;
    else if(tolower(*p) == 'g') mul=1e9;
    else if(tolower(*p) == 'x') mul=1e6; /* Xyce extension */
    else if(tolower(p[0]) == 'm' && tolower(p[1]) == 'e' && tolower(p[2]) == 'g') mul=1e6;
    else if(*p == 'M') mul=1e6;
    else if(*p == 'm') mul=1e-3;
    else if(tolower(*p) == 'k') mul=1e3;
    else if(tolower(*p) == 'u') mul=1e-6;
    else if(tolower(*p) == 'n') mul=1e-9;
    else if(tolower(*p) == 'p') mul=1e-12;
    else if(tolower(*p) == 'f') mul=1e-15;
    else if(tolower(*p) == 'a') mul=1e-18;
    else mul = 1.0;
    a *= mul;
  }
  return a;
}




char *dtoa_eng(double i, int precision)
{
  static char s[80];
  size_t n;
  int suffix = 0;
  double absi = fabs(i);
  dbg(1,  "dtoa_eng(): i=%.17g, absi=%.17g, precision=%d\n", i, absi, precision);
  if     (absi == 0.0)        {            suffix =  0 ;}
  else if(absi < 0.999999e-23) { i  = 0.0 ; suffix =  0 ;}
  else if(absi > 0.999999e12)  { i /= 1e12; suffix = 'T';}
  else if(absi > 0.999999e9)   { i /= 1e9 ; suffix = 'G';}
  else if(absi > 0.999999e6)   { i /= 1e6 ; suffix = 'M';}
  else if(absi > 0.999999e3)   { i /= 1e3 ; suffix = 'k';}
  else if(absi > 0.999999e-1)  {            suffix = 0;  }
  else if(absi > 0.999999e-3)  { i *= 1e3 ; suffix = 'm';}
  else if(absi > 0.999999e-6)  { i *= 1e6 ; suffix = 'u';}
  else if(absi > 0.999999e-9)  { i *= 1e9 ; suffix = 'n';}
  else if(absi > 0.999999e-12) { i *= 1e12; suffix = 'p';}
  else if(absi > 0.999999e-15) { i *= 1e15; suffix = 'f';}
  else                        { i *= 1e18; suffix = 'a';}
  if(suffix) {
    /* can not use my_snprintf() here due to indirect precision */
    if(suffix == 'M')
      n = sprintf(s, "%.*gMEG", precision, i);
    else
      n = sprintf(s, "%.*g%c", precision, i, suffix);
  } else {
    n = sprintf(s, "%.*g", precision, i);
  }
  if(xctx) xctx->tok_size = n;
  return s;
}

char *dtoa_prec(double i)
{
  static char s[70];
  size_t n;
  n = my_snprintf(s, S(s), "%.10e", i);
  if(xctx) xctx->tok_size = n;
  return s;
}













/* caller should do hash_names() (once) before (repeatedly) using this function */
void set_inst_prop(int i)
{
  char *ptr;
  char *tmp = NULL;
  if(xctx->inst[i].ptr == -1) return;
  ptr = (xctx->inst[i].ptr+ xctx->sym)->templ;
  dbg(1, "set_inst_prop(): i=%d, name=%s, prop_ptr = %s, template=%s\n",
     i, xctx->inst[i].name, xctx->inst[i].prop_ptr, ptr);
  my_strdup(_ALLOC_ID_, &xctx->inst[i].prop_ptr, ptr);
  if(get_tok_value(ptr, "name",0)[0]) {
    my_strdup(_ALLOC_ID_, &tmp, xctx->inst[i].prop_ptr);
    new_prop_string(i, tmp, tclgetboolvar("disable_unique_names")); /* sets also inst[].instname */
    my_free(_ALLOC_ID_, &tmp);
  }
}

/* super fast count # of newlines (and bytes) in a file */
int count_lines_bytes(int fd, size_t *lines, size_t *bytes)
{
  enum {BUFFER_SIZE=16384};
  size_t nread;
  size_t nls, nbytes;
  char buf[BUFFER_SIZE];

  if(!lines || !bytes) return 0;
  nls = nbytes = 0;
  while((nread = read(fd, buf, BUFFER_SIZE)) > 0) {
    char *p;
    char *last;

    if(nread == -1) return 0;
    nbytes += nread;
    p = buf;
    last = buf + nread;
    while((p = memchr(p, '\n', last - p))) {
      ++p;
      ++nls;
    }
  }
  *bytes = nbytes;
  *lines = nls;
  return 1;
}

static int edit_rect_property(int x)
{
  int i, c, n;
  int drw = 0;
  int pin_full_redraw = 0; /* a pin's name view is a separate object -> full redraw */
  char olddir[40];         /* pin direction before the edit (to detect re-orient) */
  const char *attr;
  int preserve, modified = 0;
  char *oldprop=NULL;
  double bus = 0.0, oldbus = 0.0;
  double width;
  if(x < 0 || x > 2) {
    fprintf(errfp, "edit_rect_property() : unknown parameter x=%d\n",x);
    return 0;
  }
  my_strdup(_ALLOC_ID_, &oldprop, xctx->rect[xctx->sel_array[0].col][xctx->sel_array[0].n].prop_ptr);
  if(oldprop && oldprop[0]) {
    tclsetvar("tctx::retval",oldprop);
  } else {
    tclsetvar("tctx::retval","");
  }
  if(x==0) {
    xctx->semaphore++;
    tcleval("text_line {Input property:} 0 normal");
    xctx->semaphore--;
  }
  else if(x==2) tcleval("viewdata $tctx::retval");
  else tcleval("edit_vi_prop {Text:}"); /* x == 1 */
  preserve = tclgetboolvar("preserve_unchanged_attrs");
  if(strcmp(tclgetvar("tctx::rcode"),"") )
  {
    xctx->push_undo();
    for(i=0; i<xctx->lastsel; ++i) {
      if(xctx->sel_array[i].type != xRECT) continue;
      c = xctx->sel_array[i].col;
      n = xctx->sel_array[i].n;
      olddir[0] = '\0';
      if(c == PINLAYER) /* capture old dir (own prop) before it is overwritten below */
        my_snprintf(olddir, S(olddir), "%s", get_tok_value(xctx->rect[c][n].prop_ptr, "dir", 0));
      oldbus = xctx->rect[c][n].bus;
      if(oldprop && preserve == 1) {
        set_different_token(&xctx->rect[c][n].prop_ptr, (char *) tclgetvar("tctx::retval"), oldprop);
      } else {
        my_strdup(_ALLOC_ID_, &xctx->rect[c][n].prop_ptr,
               (char *) tclgetvar("tctx::retval"));
      }
      bus = xctx->rect[c][n].bus = get_attr_val(get_tok_value(xctx->rect[c][n].prop_ptr,"bus",0));

      if(bus > 0.0) width = XLINEWIDTH(bus) / 2.0;
      else width = INT_BUS_WIDTH(xctx->lw) / 2.0;
      if(oldbus / 2.0 > width) width = XLINEWIDTH(oldbus) / 2.0;

      set_rect_flags(&xctx->rect[c][n]); /* set cached .flags bitmask from attributes */

      /* Pin edit write-through: if the direction changed, re-orient the name label to
       * the conventional side; then sync the name view (content/pos/size) from tokens. */
      if(c == PINLAYER) {
        if(strcmp(olddir, get_tok_value(xctx->rect[c][n].prop_ptr, "dir", 0))) pin_reorient(n);
        pin_view_apply(n); /* create/delete the view per show_pinname, then sync it */
        pin_full_redraw = 1;
      }

      set_rect_extraptr(0, &xctx->rect[c][n]);

      attr = get_tok_value(xctx->rect[c][n].prop_ptr,"dash",0);
      if( strcmp(attr, "") ) {
        int d = atoi(attr);
        xctx->rect[c][n].dash = (short)(d >= 0? d : 0);
      } else
        xctx->rect[c][n].dash = 0;

      attr = get_tok_value(xctx->rect[c][n].prop_ptr,"ellipse", 0);
      if( strcmp(attr, "") ) {
        int a;
        int b;
        if(sscanf(attr, "%d%*[ ,]%d", &a, &b) != 2) {
          a = 0;
          b = 360;
        }
        xctx->rect[c][n].ellipse_a = a;
        xctx->rect[c][n].ellipse_b = b;
      } else {
        xctx->rect[c][n].ellipse_a = -1;
        xctx->rect[c][n].ellipse_b = -1;
      }

      attr = get_tok_value(xctx->rect[c][n].prop_ptr,"fill", 0);
      if(!strcmp(attr, "full")) xctx->rect[c][n].fill = 2;
      else if(!strboolcmp(attr, "false")) xctx->rect[c][n].fill = 0;
      else xctx->rect[c][n].fill = 1;

      if( (oldprop &&  xctx->rect[c][n].prop_ptr && strcmp(oldprop, xctx->rect[c][n].prop_ptr)) ||
          (!oldprop && xctx->rect[c][n].prop_ptr) || (oldprop && !xctx->rect[c][n].prop_ptr)) {
         modified = 1;
         /* pins full-redraw (their name view is a separate object); other rects use the
          * partial-bbox path below */
         if(c != PINLAYER) {
           if(!drw) {
             bbox(START, 0.0 , 0.0 , 0.0 , 0.0);
           }
           drw = 1;
           if( xctx->rect[c][n].flags & 1024) {
             draw_image(0, &xctx->rect[c][n], &xctx->rect[c][n].x1, &xctx->rect[c][n].y1,
                           &xctx->rect[c][n].x2, &xctx->rect[c][n].y2, 0, 0);
           }
           bbox(ADD, xctx->rect[c][n].x1 - width, xctx->rect[c][n].y1 - width,
                     xctx->rect[c][n].x2 + width, xctx->rect[c][n].y2 + width);
         }
      }
    }
    if(drw) {
      bbox(SET , 0.0 , 0.0 , 0.0 , 0.0);
      draw();
      bbox(END , 0.0 , 0.0 , 0.0 , 0.0);
    } else if(pin_full_redraw) {
      draw(); /* repaint the moved/renamed pin name view (separate object, not in a bbox) */
    }
  }
  my_free(_ALLOC_ID_, &oldprop);
  return modified;
}

static int edit_line_property(void)
{
  int i, c, n;
  const char *dash;
  int preserve, modified = 0;
  char *oldprop=NULL;
  double bus = 0.0, oldbus = 0.0;
  double width;

  my_strdup(_ALLOC_ID_, &oldprop, xctx->line[xctx->sel_array[0].col][xctx->sel_array[0].n].prop_ptr);
  if(oldprop && oldprop[0]) {
    tclsetvar("tctx::retval", oldprop);
  } else {
    tclsetvar("tctx::retval","");
  }
  xctx->semaphore++;
  tcleval("text_line {Input property:} 0 normal");
  xctx->semaphore--;
  preserve = tclgetboolvar("preserve_unchanged_attrs");
  if(strcmp(tclgetvar("tctx::rcode"),"") )
  {
    double y1, y2;
    xctx->push_undo();
    bbox(START, 0.0 , 0.0 , 0.0 , 0.0);
    for(i=0; i<xctx->lastsel; ++i) {
      if(xctx->sel_array[i].type != LINE) continue;
      c = xctx->sel_array[i].col;
      n = xctx->sel_array[i].n;
      oldbus = xctx->line[c][n].bus;
      if(oldprop && preserve == 1) {
        set_different_token(&xctx->line[c][n].prop_ptr, (char *) tclgetvar("tctx::retval"), oldprop);
      } else {
        my_strdup(_ALLOC_ID_, &xctx->line[c][n].prop_ptr,
               (char *) tclgetvar("tctx::retval"));
      }
      bus = xctx->line[c][n].bus = get_attr_val(get_tok_value(xctx->line[c][n].prop_ptr,"bus",0));

      if(bus > 0.0) width = XLINEWIDTH(bus) / 2.0;
      else width = INT_BUS_WIDTH(xctx->lw) / 2.0;
      if(oldbus / 2.0 > width) width = XLINEWIDTH(oldbus) / 2.0;

      dash = get_tok_value(xctx->line[c][n].prop_ptr,"dash",0);
      if( strcmp(dash, "") ) {
        int d = atoi(dash);
        xctx->line[c][n].dash = (short)(d >= 0? d : 0);
      } else
        xctx->line[c][n].dash = 0;
      if(xctx->line[c][n].y1 < xctx->line[c][n].y2) {
        y1 = xctx->line[c][n].y1 - width; y2 = xctx->line[c][n].y2 + width;
      } else {
        y1 = xctx->line[c][n].y1 + width; y2 = xctx->line[c][n].y2 - width;
      }
      bbox(ADD, xctx->line[c][n].x1 - width, y1, xctx->line[c][n].x2 + width, y2);
    }
    bbox(SET , 0.0 , 0.0 , 0.0 , 0.0);
    draw();
    bbox(END , 0.0 , 0.0 , 0.0 , 0.0);
    modified = 1;
  }
  my_free(_ALLOC_ID_, &oldprop);
  return modified;
}


static int edit_wire_property(void)
{
  int i, modified = 0;
  int preserve;
  char *oldprop=NULL;
  double bus = 0.0, oldbus = 0.0;
  double width;

  my_strdup(_ALLOC_ID_, &oldprop, xctx->wire[xctx->sel_array[0].n].prop_ptr);
  if(oldprop && oldprop[0]) {
    tclsetvar("tctx::retval", oldprop);
  } else {
    tclsetvar("tctx::retval","");
  }
  xctx->semaphore++;
  tcleval("text_line {Input property:} 0 normal");
  xctx->semaphore--;
  preserve = tclgetboolvar("preserve_unchanged_attrs");
  if(strcmp(tclgetvar("tctx::rcode"),"") )
  {
    xctx->push_undo();
    bbox(START, 0.0 , 0.0 , 0.0 , 0.0);
    for(i=0; i<xctx->lastsel; ++i) {
      double ov, y1, y2;
      int k = xctx->sel_array[i].n;
      if(xctx->sel_array[i].type != WIRE) continue;
      /* does not seem to be necessary */
     /*  xctx->prep_hash_wires=0;
      *  xctx->prep_net_structs=0;
      *  xctx->prep_hi_structs=0; */
      oldbus = xctx->wire[k].bus;
      if(oldprop && preserve == 1) {
        set_different_token(&xctx->wire[k].prop_ptr, (char *) tclgetvar("tctx::retval"), oldprop);
      } else {
        my_strdup(_ALLOC_ID_, &xctx->wire[k].prop_ptr,(char *) tclgetvar("tctx::retval"));
      }
      xctx->wire[k].bus = bus = get_attr_val(get_tok_value(xctx->wire[k].prop_ptr,"bus",0));
      set_wire_flags(&xctx->wire[k]);
      if(bus > 0.0) width = XLINEWIDTH(bus) / 2.0;
      else width = INT_BUS_WIDTH(xctx->lw) / 2.0;
      if(oldbus / 2.0 > width) width = XLINEWIDTH(oldbus) / 2.0;

      ov = width > xctx->cadhalfdotsize ? width : xctx->cadhalfdotsize;
      if(xctx->wire[k].y1 < xctx->wire[k].y2) { y1 = xctx->wire[k].y1-ov; y2 = xctx->wire[k].y2+ov; }
      else { y1 = xctx->wire[k].y1+ov; y2 = xctx->wire[k].y2-ov; }
      bbox(ADD, xctx->wire[k].x1-ov, y1 , xctx->wire[k].x2+ov , y2 );
    }
    bbox(SET , 0.0 , 0.0 , 0.0 , 0.0);
    draw();
    bbox(END , 0.0 , 0.0 , 0.0 , 0.0);
    modified = 1;
  }
  my_free(_ALLOC_ID_, &oldprop);
  return modified;
}

static int edit_arc_property(void)
{
  int old_fill;
  double x1, y1, x2, y2;
  int c, i, ii, old_dash, drw = 0;
  char *oldprop = NULL;
  const char *dash, *fill_ptr;
  int preserve, modified = 0;
  double bus = 0.0, oldbus = 0.0;
  double width;

  my_strdup(_ALLOC_ID_, &oldprop, xctx->arc[xctx->sel_array[0].col][xctx->sel_array[0].n].prop_ptr);
  if(oldprop && oldprop[0]) {
    tclsetvar("tctx::retval", oldprop);
  } else {
    tclsetvar("tctx::retval","");
  }
  xctx->semaphore++;
  tcleval("text_line {Input property:} 0 normal");
  xctx->semaphore--;
  preserve = tclgetboolvar("preserve_unchanged_attrs");
  if(strcmp(tclgetvar("tctx::rcode"),"") )
  {
   xctx->push_undo();
   for(ii=0; ii<xctx->lastsel; ii++) {
     if(xctx->sel_array[ii].type != ARC) continue;

     i = xctx->sel_array[ii].n;
     c = xctx->sel_array[ii].col;
     oldbus = xctx->arc[c][i].bus;
     if(oldprop && preserve == 1) {
        set_different_token(&xctx->arc[c][i].prop_ptr, (char *) tclgetvar("tctx::retval"), oldprop);

     } else {
        my_strdup(_ALLOC_ID_, &xctx->arc[c][i].prop_ptr, (char *) tclgetvar("tctx::retval"));
     }
     old_fill = xctx->arc[c][i].fill;
     fill_ptr = get_tok_value(xctx->arc[c][i].prop_ptr,"fill",0);
     if( !strcmp(fill_ptr,"full") )
       xctx->arc[c][i].fill = 2; /* bit 1: solid fill (not stippled) */
     else if( !strboolcmp(fill_ptr,"true") )
       xctx->arc[c][i].fill = 1;
     else
       xctx->arc[c][i].fill = 0;
     old_dash = xctx->arc[c][i].dash;
     dash = get_tok_value(xctx->arc[c][i].prop_ptr,"dash",0);
     if( strcmp(dash, "") ) {
       int d = atoi(dash);
       xctx->arc[c][i].dash = (short)(d >= 0 ? d : 0);
     } else
       xctx->arc[c][i].dash = 0;

     bus = xctx->arc[c][i].bus = get_attr_val(get_tok_value(xctx->arc[c][i].prop_ptr,"bus",0));
     if(bus > 0.0) width = XLINEWIDTH(bus) / 2.0;
     else width = INT_BUS_WIDTH(xctx->lw) / 2.0;
     if(oldbus / 2.0 > width) width = XLINEWIDTH(oldbus) / 2.0;

     if(oldbus != bus || old_fill != xctx->arc[c][i].fill || old_dash != xctx->arc[c][i].dash) {
       if(!drw) {
         bbox(START,0.0,0.0,0.0,0.0);
         drw = 1;
       }
       arc_bbox(xctx->arc[c][i].x, xctx->arc[c][i].y, xctx->arc[c][i].r, 0, 360, &x1,&y1,&x2,&y2);
       bbox(ADD, x1 - width, y1 - width, x2 + width, y2 + width);
     }
   }
   if(drw) {
     bbox(SET , 0.0 , 0.0 , 0.0 , 0.0);
     draw();
     bbox(END , 0.0 , 0.0 , 0.0 , 0.0);
   }
   modified = 1;
  }
  return modified;
}

static int edit_polygon_property(void)
{
  const char *fill_ptr;
  int old_fill;
  int oldbezier, bezier;
  int k;
  double x1=0., y1=0., x2=0., y2=0., oldbus = 0.0, bus = 0.0;
  int c, i, ii, old_dash;
  int drw = 0;
  char *oldprop = NULL;
  const char *dash;
  int preserve, modified = 0;
  double width;

  dbg(1, "edit_property(): input property:\n");
  my_strdup(_ALLOC_ID_, &oldprop, xctx->poly[xctx->sel_array[0].col][xctx->sel_array[0].n].prop_ptr);
  if(oldprop && oldprop[0]) {
    tclsetvar("tctx::retval", oldprop);
  } else {
    tclsetvar("tctx::retval","");
  }
  xctx->semaphore++;
  tcleval("text_line {Input property:} 0 normal");
  xctx->semaphore--;
  preserve = tclgetboolvar("preserve_unchanged_attrs");
  if(strcmp(tclgetvar("tctx::rcode"),"") )
  {
   xctx->push_undo();
   for(ii=0; ii<xctx->lastsel; ii++) {
     if(xctx->sel_array[ii].type != POLYGON) continue;

     i = xctx->sel_array[ii].n;
     c = xctx->sel_array[ii].col;

     oldbezier = !strboolcmp(get_tok_value(xctx->poly[c][i].prop_ptr,"bezier",0),"true") ;
     oldbus = xctx->poly[c][i].bus;
     if(oldprop && preserve == 1) {
        set_different_token(&xctx->poly[c][i].prop_ptr, (char *) tclgetvar("tctx::retval"), oldprop);
     } else {
        my_strdup(_ALLOC_ID_, &xctx->poly[c][i].prop_ptr, (char *) tclgetvar("tctx::retval"));
     }
     old_fill = xctx->poly[c][i].fill;
     old_dash = xctx->poly[c][i].dash;
     bezier = !strboolcmp(get_tok_value(xctx->poly[c][i].prop_ptr,"bezier",0),"true") ;
     xctx->poly[c][i].bus = bus = get_attr_val(get_tok_value(xctx->poly[c][i].prop_ptr,"bus",0));

     if(bus > 0.0) width = XLINEWIDTH(bus) / 2.0;
     else width = MAJOR(INT_BUS_WIDTH(xctx->lw) / 2.0, xctx->cadhalfdotsize);
     if(oldbus / 2.0 > width) width = XLINEWIDTH(oldbus) / 2.0;

     fill_ptr = get_tok_value(xctx->poly[c][i].prop_ptr,"fill",0);
     if( !strcmp(fill_ptr,"full") )
       xctx->poly[c][i].fill = 2; /* bit 1: solid fill (not stippled) */
     else if( !strboolcmp(fill_ptr,"true") )
       xctx->poly[c][i].fill = 1;
     else
       xctx->poly[c][i].fill = 0;
     dash = get_tok_value(xctx->poly[c][i].prop_ptr,"dash",0);
     if( strcmp(dash, "") ) {
       int d = atoi(dash);
       xctx->poly[c][i].dash = (short)(d >= 0 ? d : 0);
     } else
       xctx->poly[c][i].dash = 0;
     if(old_fill != xctx->poly[c][i].fill || old_dash != xctx->poly[c][i].dash ||
        oldbezier != bezier || oldbus != bus) {
       if(!drw) {
         bbox(START,0.0,0.0,0.0,0.0);
         drw = 1;
       }
       for(k=0; k<xctx->poly[c][i].points; ++k) {
         if(k==0 || xctx->poly[c][i].x[k] < x1) x1 = xctx->poly[c][i].x[k];
         if(k==0 || xctx->poly[c][i].y[k] < y1) y1 = xctx->poly[c][i].y[k];
         if(k==0 || xctx->poly[c][i].x[k] > x2) x2 = xctx->poly[c][i].x[k];
         if(k==0 || xctx->poly[c][i].y[k] > y2) y2 = xctx->poly[c][i].y[k];
       }
       bbox(ADD, x1-width, y1-width, x2+width, y2+width);
     }
   }
   if(drw) {
     bbox(SET , 0.0 , 0.0 , 0.0 , 0.0);
     draw();
     bbox(END , 0.0 , 0.0 , 0.0 , 0.0);
   }
   modified = 1;
  }
  return modified;
}


/* x=0 use text widget   x=1 use vim editor */
static int edit_text_property(int x)
{
  int rot, flip, modified = 0;
  #if HAS_CAIRO==1
  int customfont;
  #endif
  int sel, k, text_changed = 0, props_changed = 0, size_changed = 0, tmp;
  int c,l, preserve;
  double hsize = 0.4, vsize = 0.4, dtmp;
  double xx1,yy1,xx2,yy2;
  double pcx,pcy;      /* pin center 20070317 */
  char property[100];/* used for float 2 string conv (xscale  and yscale) overflow safe */
  /* const char *str; */
  char *oldprop = NULL;

  if(x < 0 || x > 2) {
    fprintf(errfp, "edit_text_property() : unknown parameter x=%d\n",x);
    return 0;
  }
  dbg(1, "edit_text_property(): entering\n");
  sel = xctx->sel_array[0].n;
  my_strdup(_ALLOC_ID_, &oldprop, xctx->text[sel].prop_ptr);
  if(oldprop && oldprop[0])
     tclsetvar("props", oldprop);
  else
     tclsetvar("props","");
  tclsetvar("tctx::retval",xctx->text[sel].txt_ptr);
  my_snprintf(property, S(property), "%.16g",xctx->text[sel].yscale);
  tclsetvar("tctx::vsize",property);
  my_snprintf(property, S(property), "%.16g",xctx->text[sel].xscale);
  tclsetvar("tctx::hsize",property);
  if(x==0) {
    const char *props;
    xctx->semaphore++;
    tcleval("enter_text {text:} normal");
    xctx->semaphore--;
    hsize =atof(tclgetvar("tctx::hsize"));
    vsize =atof(tclgetvar("tctx::vsize"));
    props = tclgetvar("props");
    if(xctx->text[sel].xscale != hsize || xctx->text[sel].yscale != vsize) {
      size_changed = 1;
    }
    if( (oldprop && strcmp(oldprop, tclgetvar("props"))) || (!oldprop && props[0]) ) props_changed = 1;
  }
  else if(x==2) tcleval("viewdata $tctx::retval");
  else tcleval("edit_vi_prop {Text:}"); /* x == 1 */
  preserve = tclgetboolvar("preserve_unchanged_attrs");
  if(x == 0 || x == 1) {
    if(strcmp(xctx->text[sel].txt_ptr, tclgetvar("tctx::retval") ) ) {
      dbg(1, "edit_text_property(): x=%d, text_changed=1\n", x);
      text_changed=1;
    }
  }
  if(strcmp(tclgetvar("tctx::rcode"),"") )
  {
    char *estr = NULL;
    dbg(1, "edit_text_property(): tctx::rcode !=\"\"\n");
    if(text_changed || size_changed || props_changed) {
      modified = 1;
      xctx->push_undo();
    }
    /* set_modify(-2); */ /* ? Not needed, overkill... clear text floater caches */
    for(k=0;k<xctx->lastsel; ++k)
    {
      if(xctx->sel_array[k].type!=xTEXT) continue;
      sel=xctx->sel_array[k].n;
      rot = xctx->text[sel].rot; /* calculate bbox, some cleanup needed here */
      flip = xctx->text[sel].flip;
      #if HAS_CAIRO==1
      customfont = set_text_custom_font(&xctx->text[sel]);
      #endif
      estr = my_expand(get_text_floater(sel), tclgetintvar("tabstop"));
      text_bbox(estr, xctx->text[sel].xscale,
                xctx->text[sel].yscale, (short)rot, (short)flip, xctx->text[sel].hcenter,
                xctx->text[sel].vcenter, xctx->text[sel].x0, xctx->text[sel].y0,
                &xx1,&yy1,&xx2,&yy2, &tmp, &dtmp);
      my_free(_ALLOC_ID_, &estr);
      #if HAS_CAIRO==1
      if(customfont) {
        cairo_restore(xctx->cairo_ctx);
      }
      #endif
      /* dbg(1, "edit_property(): text props=%s text=%s\n", tclgetvar("props"), tclgetvar("tctx::retval")); */
      if(text_changed) {
        my_free(_ALLOC_ID_, &xctx->text[sel].floater_ptr);
        /* Owned pin-name view (Option B): renaming the label renames its pin via the
         * robust owner_pin_id link (handled after txt_ptr is updated, below). For an
         * ordinary text keep the legacy name-match+proximity pin-rename heuristic. */
        if(!xctx->text[sel].owner_pin_id) {
          double cg = tclgetdoublevar("cadgrid");
          c = xctx->rects[PINLAYER];
          for(l=0;l<c; ++l) {
            if(xctx->text[sel].txt_ptr &&
                !strcmp( (get_tok_value(xctx->rect[PINLAYER][l].prop_ptr, "name",0)), xctx->text[sel].txt_ptr) ) {
              pcx = (xctx->rect[PINLAYER][l].x1+xctx->rect[PINLAYER][l].x2)/2.0;
              pcy = (xctx->rect[PINLAYER][l].y1+xctx->rect[PINLAYER][l].y2)/2.0;
              if(
                  /* 20171206 20171221 */
                  (fabs( (yy1+yy2)/2 - pcy) < cg/2 &&
                  (fabs(xx1 - pcx) < cg*3 || fabs(xx2 - pcx) < cg*3) )
                  ||
                  (fabs( (xx1+xx2)/2 - pcx) < cg/2 &&
                  (fabs(yy1 - pcy) < cg*3 || fabs(yy2 - pcy) < cg*3) )
              ) {
                my_strdup(_ALLOC_ID_, &xctx->rect[PINLAYER][l].prop_ptr,
                  subst_token(xctx->rect[PINLAYER][l].prop_ptr, "name",
                  (char *) tclgetvar("tctx::retval")) );
              }
            }
          }
        }
        my_strdup2(_ALLOC_ID_, &xctx->text[sel].txt_ptr, (char *) tclgetvar("tctx::retval"));
      }
      if(props_changed) {
        if(oldprop && preserve)
          set_different_token(&xctx->text[sel].prop_ptr, (char *) tclgetvar("props"), oldprop);
        else
          my_strdup(_ALLOC_ID_, &xctx->text[sel].prop_ptr,(char *) tclgetvar("props"));

        my_free(_ALLOC_ID_, &xctx->text[sel].floater_ptr);
        set_text_flags(&xctx->text[sel]);
      }
      if(text_changed || props_changed) {
        get_text_floater(sel); /* update xctx->text[sel].floater_ptr cache */
      }
      if(size_changed) {
        xctx->text[sel].xscale=hsize;
        xctx->text[sel].yscale=vsize;
      }
      /* P3 write-through: if this text is an owned pin-name view, fold edits back into
       * the pin tokens (content -> name=, size -> name_size). */
      if(xctx->text[sel].owner_pin_id) {
        if(text_changed) pin_rename_from_view(sel);
        if(size_changed) pin_view_writeback(sel);
      }
    } /* for(k=0;k<xctx->lastsel; ++k) */
    draw();
  }
  my_free(_ALLOC_ID_, &oldprop);
  return modified;
}

int drc_check(int i)
{
  int j, ret = 0;
  char *drc = NULL, *res = NULL;
  char *check_result = NULL;
  int start = 0;
  int end = xctx->instances;

  if(!tcleval("info procs fet_drc")[0]) {
    return ret;
  }
  if(i >= 0 && i < xctx->instances) {
    start = i;
    end = i + 1;
  }
  for(j = start; j < end; j++) {
    my_strdup(_ALLOC_ID_, &drc, get_tok_value(xctx->sym[xctx->inst[j].ptr].prop_ptr, "drc", 2));
    if(drc) {
      my_strdup(_ALLOC_ID_, &res, translate3(drc, 1,
                xctx->inst[j].prop_ptr, xctx->sym[xctx->inst[j].ptr].templ, NULL, NULL));
      dbg(1, "drc_check(): res = |%s|, drc=|%s|\n", res, drc);
      if(res) {
        const char *result;
        const char *replace_res;

        replace_res = str_replace(res, "@symname", xctx->sym[xctx->inst[j].ptr].name, '\\', -1);
        result = tcleval(replace_res);
        if(result && result[0]) {
          ret = 1;
          my_mstrcat(_ALLOC_ID_, &check_result,  result, NULL);
        }
      }
    }
  }
  if(drc) my_free(_ALLOC_ID_, &drc);
  if(res) my_free(_ALLOC_ID_, &res);
  if(check_result) {
    if(has_x) {
      /* tclvareval("alert_ {", check_result, "} {}", NULL); */
      statusmsg(check_result, 3);
      tcleval("show_infotext 1");
    } else {
      dbg(0, "%s\n", check_result);
    }
    my_free(_ALLOC_ID_, &check_result);
  }
  return ret;
}

/* Core apply: fan the change set (new_prop vs old_prop) out to the instances
 * named by <scope> relative to <displayed_inst>. Reads symbol / no_change_attrs
 * / user_wants_copy_cell globals. Changed-fields-only is the unconditional
 * contract; one undo is pushed for the whole call. Returns 1 if modified.
 * Shared by update_symbol() (the post-close path for the vim/legacy editor) and
 * apply_instance_properties() (the mid-session `xschem apply_properties`
 * command driving the slick form's Apply / OK).
 *   scope: "current"  -> only <displayed_inst>
 *          "selected" -> every selected ELEMENT (the multi-edit set)
 *          "all"      -> every instance of <displayed_inst>'s master this sheet */
/* Resolve <scope> (current|selected|all) relative to the displayed instance into
 * a list of instance indices written into the caller-provided targets[] (sized
 * at least xctx->instances+1); returns the count. The single source of truth for
 * "what an Apply/OK touches", shared by apply_symbol_prop() and the
 * `xschem highlight_scope` overlay so the outlined set == the applied set
 * (decision doc D3). Per D7 the displayed instance's MASTER defines the edited
 * kind: both 'selected' and 'all' are filtered to instances of that master, so a
 * mixed-master selection only fans the edit to the same-master instances. The
 * master is read at call time (callers that may reassign inst[].ptr must resolve
 * before mutating). */
int scope_targets(int displayed_inst, const char *scope, int *targets)
{
  int i, k, n = 0;
  int master = xctx->inst[displayed_inst].ptr;
  if(!strcmp(scope, "all")) {
    for(i = 0; i < xctx->instances; ++i) {
      if(xctx->inst[i].ptr == master) targets[n++] = i;
    }
  } else if(!strcmp(scope, "selected")) {
    for(k = 0; k < xctx->lastsel; ++k) {
      if(xctx->sel_array[k].type == ELEMENT &&
         xctx->inst[xctx->sel_array[k].n].ptr == master) targets[n++] = xctx->sel_array[k].n;
    }
  } else { /* current */
    targets[n++] = displayed_inst;
  }
  return n;
}

/* keep_name: when nonzero, do NOT rewrite the instance name's first character to the
 * new symbol's template prefix on a symbol change (the slick Edit Properties form treats
 * the dedicated Name field as authoritative -- an instance name is arbitrary and a source
 * change must not re-prefix it; issue 0058). All other behavior (re-point master, name
 * uniqueness, bbox) is unchanged. */
static int apply_symbol_prop(const char *new_prop, const char *old_prop,
                             int displayed_inst, const char *scope, int keep_name)
{
  int k, sym_number;
  int no_change_props=0;
  int only_different=1; /* changed-fields-only: the unconditional contract */
  int copy_cell=0;
  int prefix=0, old_prefix = 0;
  char *name = NULL, *ptr = NULL;
  char symbol[PATH_MAX], *translated_sym = NULL, *old_translated_sym = NULL;
  int changed_symbol = 0;
  int pushed=0;
  int *targets = NULL;       /* the instances this Apply touches (the scope) */
  int ntargets = 0;
  int *ii = &xctx->edit_sym_i; /* static var */
  int modified = 0;

  dbg(1, "apply_symbol_prop(): displayed_inst=%d scope=%s\n", displayed_inst, scope);
  *ii = displayed_inst;
  my_strncpy(symbol, (char *) tclgetvar("symbol") , S(symbol));
  no_change_props=tclgetboolvar("no_change_attrs");
  copy_cell=tclgetboolvar("user_wants_copy_cell");
  /* 20191227 necessary? --> Yes since a symbol copy has already been done
     in edit_symbol_property() -> tcl edit_prop, this ensures new symbol is loaded from disk.
     if for some reason a symbol with matching name is loaded in xschem this
     may be out of sync wrt disk version */
  if(copy_cell) {
   remove_symbols();
   link_symbols_to_instances(-1);
  }
  /* User edited the Symbol textbox */
  if(strcmp(symbol, xctx->inst[*ii].name)) {
    changed_symbol = 1;
  }

  /* Build the target instance list from <scope> via the shared resolver (the
   * single source of truth, also used by the `xschem highlight_scope` overlay so
   * the outlined set == the applied set by construction — decision doc D3/D7). */
  targets = my_malloc(_ALLOC_ID_, (xctx->instances + 1) * sizeof(int));
  ntargets = scope_targets(displayed_inst, scope, targets);

  for(k=0;k<ntargets; ++k) {
    dbg(1, "apply_symbol_prop(): for k loop: k=%d\n", k);
    *ii=targets[k];
    old_prefix=(get_tok_value(xctx->sym[xctx->inst[*ii].ptr].templ, "name",0))[0];
    /* 20171220 calculate bbox before changes to correctly redraw areas */
    /* must be recalculated as cairo text extents vary with zoom factor. */
    symbol_bbox(*ii, &xctx->inst[*ii].x1, &xctx->inst[*ii].y1, &xctx->inst[*ii].x2, &xctx->inst[*ii].y2);
    my_strdup2(_ALLOC_ID_, &old_translated_sym, translate(*ii, xctx->inst[*ii].name));
    /* update property string from tcl dialog */
    if(!no_change_props)
    {
      if(only_different) {
        char * ss=NULL;
        my_strdup(_ALLOC_ID_, &ss, xctx->inst[*ii].prop_ptr);
        if( set_different_token(&ss, new_prop, old_prop) ) {
          if(!pushed) { xctx->push_undo(); pushed=1;}
          my_strdup(_ALLOC_ID_, &xctx->inst[*ii].prop_ptr, ss);
        }
        my_free(_ALLOC_ID_, &ss);
      }
      else {
        if(new_prop) {
          if(!xctx->inst[*ii].prop_ptr || strcmp(xctx->inst[*ii].prop_ptr, new_prop)) {
            dbg(1, "apply_symbol_prop(): changing prop: |%s| -> |%s|\n",
                xctx->inst[*ii].prop_ptr, new_prop);
            if(!pushed) { xctx->push_undo(); pushed=1;}
            my_strdup(_ALLOC_ID_, &xctx->inst[*ii].prop_ptr, new_prop);
          }
        }  else {
          if(!pushed) { xctx->push_undo(); pushed=1;}
          my_strdup(_ALLOC_ID_, &xctx->inst[*ii].prop_ptr, "");
        }
      }
    }

    /* symbol reference changed? --> sym_number >=0, set prefix to 1st char
     * to use for inst name (from symbol template) */
    prefix = 0;
    sym_number = -1;
    my_strdup2(_ALLOC_ID_, &translated_sym, translate(*ii, symbol));
    dbg(1, "apply_symbol_prop: %s -- %s\n", translated_sym, old_translated_sym);
    if(changed_symbol ||
        ( !strcmp(symbol, xctx->inst[*ii].name) &&  strcmp(translated_sym, old_translated_sym) ) ) {
      sym_number=match_symbol(translated_sym); /* check if exist */
      if(sym_number>=0) {
        prefix=(get_tok_value(xctx->sym[sym_number].templ, "name",0))[0]; /* get new symbol prefix  */
      }
    }

    if(sym_number>=0) /* changing symbol ! */
    {
      if(!pushed) { xctx->push_undo(); pushed=1;}
      delete_inst_node(*ii); /* 20180208 fix crashing bug: delete node info if changing symbol */
                        /* if number of pins is different we must delete these data *before* */
                        /* changing ysmbol, otherwise *ii might end up deleting non allocated data. */
      my_strdup2(_ALLOC_ID_, &xctx->inst[*ii].name, rel_sym_path(symbol));
      xctx->inst[*ii].ptr=sym_number; /* update instance to point to new symbol */
    }
    my_free(_ALLOC_ID_, &translated_sym);
    my_free(_ALLOC_ID_, &old_translated_sym);

    /* if symbol changed ensure instance name (with new prefix char) is unique */
    /* preserve backslashes in name ---------0---------------------------------->. */
    my_strdup(_ALLOC_ID_, &name, get_tok_value(xctx->inst[*ii].prop_ptr, "name", 1));
    if(name && name[0] ) {
      char *old_name = NULL;
      dbg(1, "apply_symbol_prop(): prefix!='\\0', name=%s\n", name);
      /* change prefix if changing symbol type (unless the caller asked to keep the
       * instance name verbatim -- slick form, issue 0058) */
      if(!keep_name && prefix && old_prefix && old_prefix != prefix) {
        name[0]=(char)prefix;
        my_strdup(_ALLOC_ID_, &ptr, subst_token(xctx->inst[*ii].prop_ptr, "name", name) );
      } else {
        my_strdup(_ALLOC_ID_, &ptr, xctx->inst[*ii].prop_ptr);
      }
      /* set unique name of current inst */

      my_strdup2(_ALLOC_ID_, &old_name, xctx->inst[*ii].instname);



      if(strcmp(old_name, name)) {
        if(!pushed) { xctx->push_undo(); pushed=1;}
        if(!k) hash_names(-1, XINSERT);
        hash_names(*ii, XDELETE);
        dbg(1, "apply_symbol_prop(): delete %s\n", xctx->inst[*ii].instname);
        new_prop_string(*ii, ptr,               /* sets also inst[].instname */
           tclgetboolvar("disable_unique_names")); /* set new prop_ptr */
        hash_names(*ii, XINSERT);
        update_attached_floaters(old_name, *ii, 1);
        dbg(1, "apply_symbol_prop(): insert %s\n", xctx->inst[*ii].instname);
      }
      my_free(_ALLOC_ID_, &old_name);
    }
    set_inst_flags(&xctx->inst[*ii]);
  }  /* end for(k=0;k<ntargets; ++k) */

  if(pushed) modified = 1;
  /* new symbol bbox after prop changes (may change due to text length) */
  if(modified) {
    xctx->prep_hash_inst=0;
    xctx->prep_net_structs=0;
    xctx->prep_hi_structs=0;
    symbol_bbox(*ii, &xctx->inst[*ii].x1, &xctx->inst[*ii].y1, &xctx->inst[*ii].x2, &xctx->inst[*ii].y2);
    if(xctx->hilight_nets) {
      propagate_hilights(1, 1, XINSERT_NOREPLACE);
    }
    /* DRC check */
    drc_check(*ii);
  }
  /* redraw symbol with new props */
  set_modify(-2); /* reset floaters caches */
  draw();
  my_free(_ALLOC_ID_, &name);
  my_free(_ALLOC_ID_, &ptr);
  my_free(_ALLOC_ID_, &targets);
  return modified;
}

/* Mid-session apply for the slick form's Apply / OK (P2): resolve the displayed
 * instance by its session-stable id (so it survives any reindexing between
 * applies) and fan the change set to <scope>. Exposed as the Tcl command
 * `xschem apply_properties <scope> <displayed_id> <new_prop> <old_prop> [keep_name]`.
 * keep_name (default 0): preserve the instance name across a source change (issue 0058). */
int apply_instance_properties(const char *scope, unsigned int displayed_id,
                              const char *new_prop, const char *old_prop, int keep_name)
{
  int idx = inst_index_from_id(displayed_id);
  int modified;
  if(idx < 0) return 0;
  modified = apply_symbol_prop(new_prop, old_prop, idx, scope, keep_name);
  if(modified) set_modify(1);
  return modified;
}

/* The post-close apply path for the vim/legacy editor (x!=0). The slick form
 * (x==0) applies mid-session via apply_instance_properties instead and does not
 * route through here. x=0 use text widget   x=1 use vim editor */
static int update_symbol(const char *result, int x, int selected_inst)
{
  char *new_prop = NULL;
  int *netl_com = &xctx->netlist_commands; /* static var */
  int modified;

  dbg(1, "update_symbol(): entering, selected_inst = %d\n", selected_inst);
  if(!result) {
   dbg(1, "update_symbol(): edit symbol prop aborted\n");
   my_free(_ALLOC_ID_, &xctx->old_prop);
   return 0;
  }
  /* create new_prop updated attribute string */
  if(*netl_com && x==1) {
    my_strdup(_ALLOC_ID_,  &new_prop,
      subst_token(xctx->old_prop, "value", (char *) tclgetvar("tctx::retval") )
    );
  }
  else {
    my_strdup(_ALLOC_ID_, &new_prop, (char *) tclgetvar("tctx::retval"));
  }
  /* legacy/vim path keeps the prior "all selected" semantics, which combined
   * with changed-fields-only reproduces the old behavior. */
  modified = apply_symbol_prop(new_prop, xctx->old_prop, selected_inst, "selected", 0);
  my_free(_ALLOC_ID_, &new_prop);
  my_free(_ALLOC_ID_, &xctx->old_prop);
  return modified;
}

/* x=0 use text widget   x=1 use vim editor */
static int edit_symbol_property(int x, int first_sel)
{
   char *result=NULL;
   int *ii = &xctx->edit_sym_i; /* static var */
   int *netl_com = &xctx->netlist_commands; /* static var */
   int modified = 0;

   *ii=xctx->sel_array[first_sel].n;
   *netl_com = 0;
   if ((xctx->inst[*ii].ptr + xctx->sym)->type!=NULL)
     *netl_com =
       !strcmp( (xctx->inst[*ii].ptr+ xctx->sym)->type, "netlist_commands");
   if(xctx->inst[*ii].prop_ptr!=NULL) {
     if(*netl_com && x==1) {
       tclsetvar("tctx::retval",get_tok_value( xctx->inst[*ii].prop_ptr,"value",2));
     } else {
       tclsetvar("tctx::retval",xctx->inst[*ii].prop_ptr);
     }
   }
   else {
     tclsetvar("tctx::retval","");
   }
   my_strdup(_ALLOC_ID_, &xctx->old_prop, xctx->inst[*ii].prop_ptr);
   tclsetvar("symbol",xctx->inst[*ii].name);

   if(x==0) {
     /* Hand the slick form the displayed instance + the selected ELEMENT set
      * by session-stable id (P2 Next/Prev navigation + the mid-session
      * `xschem apply_properties` command). The form applies WHILE open (Apply
      * button) and on OK via that command, reporting back through tctx::applied,
      * so the post-close update_symbol path is NOT used for x==0. */
     char idbuf[30];
     char *sel_ids = NULL;
     int s;
     my_snprintf(idbuf, S(idbuf), "%u", xctx->inst[*ii].id);
     tclsetvar("tctx::edit_inst_id", idbuf);
     for(s=0; s<xctx->lastsel; ++s) {
       if(xctx->sel_array[s].type != ELEMENT) continue;
       my_snprintf(idbuf, S(idbuf), "%s%u",
         sel_ids ? " " : "", xctx->inst[xctx->sel_array[s].n].id);
       my_strcat(_ALLOC_ID_, &sel_ids, idbuf);
     }
     tclsetvar("tctx::edit_sel_ids", sel_ids ? sel_ids : "");
     my_free(_ALLOC_ID_, &sel_ids);
     tclsetvar("tctx::applied", "0");
     tcleval("edit_prop {Input property:}");
     modified = tclgetboolvar("tctx::applied");
     my_free(_ALLOC_ID_, &xctx->old_prop);
   }
   else {
     /* edit_vi_netlist_prop will replace \" with " before editing,
        replace back " with \" when done and wrap the resulting text with quotes
        ("text") when done */
     if(*netl_com && x==1)    tcleval("edit_vi_netlist_prop {Input property:}");
     else if(x==1)    tcleval("edit_vi_prop {Input property:}");
     else if(x==2)    tcleval("viewdata $tctx::retval");
     my_strdup(_ALLOC_ID_, &result, tclresult());
     dbg(1, "edit_symbol_property(): before update_symbol, modified=%d\n", xctx->modified);
     modified = update_symbol(result, x, *ii);
     my_free(_ALLOC_ID_, &result);
     dbg(1, "edit_symbol_property(): done update_symbol, modified=%d\n", modified);
   }
   *ii=-1;
   return modified;
}

void change_elem_order(int n)
{
  xInstance tmpinst;
  xRect tmpbox;
  xWire tmpwire;
  xText tmptext;
  char tmp_txt[50]; /* overflow safe */
  int c, new_n, modified = 0;

  rebuild_selected_array();
  if(xctx->lastsel==1)
  {
    if(n < 0) {
      my_snprintf(tmp_txt, S(tmp_txt), "%d",xctx->sel_array[0].n);
      tclsetvar("tctx::retval",tmp_txt);
      xctx->semaphore++;
      tclvareval("input_line {Object Sequence number} {} ", tmp_txt, NULL);
      xctx->semaphore--;
      if(strcmp(tclgetvar("tctx::retval"),"") )
      {
        int c = 0;
        xctx->push_undo();
        modified = 1;
        xctx->prep_hash_inst=0;
        xctx->prep_net_structs=0;
        xctx->prep_hi_structs=0;
        xctx->prep_hash_wires=0;
        c = sscanf(tclgetvar("tctx::retval"), "%d",&new_n);
        if(c != 1 ) return;
        if(new_n < 0) new_n = 0;
      } else {
        return; /* no data or Cancel */
      }
    } else {
      new_n = n;
      xctx->push_undo();
      modified = 1;
      xctx->prep_hash_inst=0;
      xctx->prep_net_structs=0;
      xctx->prep_hi_structs=0;
      xctx->prep_hash_wires=0;
    }

    if(xctx->sel_array[0].type==ELEMENT)
    {
      if(new_n>=xctx->instances) new_n=xctx->instances-1;
      tmpinst=xctx->inst[new_n];
      xctx->inst[new_n]=xctx->inst[xctx->sel_array[0].n];
      xctx->inst[xctx->sel_array[0].n]=tmpinst;
      dbg(1, "change_elem_order(): selected element %d\n", xctx->sel_array[0].n);
    }
    else if(xctx->sel_array[0].type==xRECT)
    {
      c=xctx->sel_array[0].col;
      if(new_n>=xctx->rects[c]) new_n=xctx->rects[c]-1;
      tmpbox=xctx->rect[c][new_n];
      xctx->rect[c][new_n]=xctx->rect[c][xctx->sel_array[0].n];
      xctx->rect[c][xctx->sel_array[0].n]=tmpbox;
      dbg(1, "change_elem_order(): selected rect %d\n", xctx->sel_array[0].n);
      if(c == GRIDLAYER) {
        if(xctx->graph_lastsel == new_n) xctx->graph_lastsel = xctx->sel_array[0].n;
        else if(xctx->graph_lastsel ==  xctx->sel_array[0].n) xctx->graph_lastsel = new_n;
      }
    }
    else if(xctx->sel_array[0].type==WIRE)
    {
      if(new_n>=xctx->wires) new_n=xctx->wires-1;
      tmpwire=xctx->wire[new_n];
      xctx->wire[new_n]=xctx->wire[xctx->sel_array[0].n];
      xctx->wire[xctx->sel_array[0].n]=tmpwire;
      dbg(1, "change_elem_order(): selected wire %d\n", xctx->sel_array[0].n);
    }
    else if(xctx->sel_array[0].type==xTEXT)
    {
      if(new_n>=xctx->texts) new_n=xctx->texts-1;
      tmptext=xctx->text[new_n];
      xctx->text[new_n]=xctx->text[xctx->sel_array[0].n];
      xctx->text[xctx->sel_array[0].n]=tmptext;
      dbg(1, "change_elem_order(): selected text %d\n", xctx->sel_array[0].n);
    }
    xctx->need_reb_sel_arr = 1;
    if(modified) set_modify(1);
  }
}


/* caller should free returned string */
char *str_chars_replace(const char *str, const char *replace_set, const char with)
{
  char *res = NULL;
  char *s;
  my_strdup(_ALLOC_ID_, &res, str);
  s = res;
  dbg(1, "*str_chars_replace(): %s\n", res);
  while( *s) {
    if(strchr(replace_set, *s)) {
      *s = with;
    }
    ++s;
  }
  return res;
}

/* x=0 use tcl text widget  x=1 use vim editor  x=2 only view data */
void edit_property(int x)
{
 int type, j, modified = 0;

 if(!has_x) return;
 rebuild_selected_array(); /* from the .sel field in objects build */
 /* D-split (cadence_pin_name_text.md): default to the pin-IDENTITY editor; the name-text
  * retarget below flips this so gfxform::selected_type picks the pin-NAME-TEXT editor. */
 tclsetvar("gfxform_via_name", "0");
 if(xctx->lastsel==0 )      /* the array of selected objs */
 {
   char *new_prop = NULL;

   if(x == 1) {
     if(xctx->netlist_type==CAD_SYMBOL_ATTRS) {
      if(xctx->schsymbolprop!=NULL)
        tclsetvar("tctx::retval",xctx->schsymbolprop);
      else
        tclsetvar("tctx::retval","");
     }
     else if(xctx->netlist_type==CAD_VHDL_NETLIST) {
      if(xctx->schvhdlprop!=NULL)
        tclsetvar("tctx::retval",xctx->schvhdlprop);
      else
        tclsetvar("tctx::retval","");
     }
     else if(xctx->netlist_type==CAD_VERILOG_NETLIST) {
      if(xctx->schverilogprop!=NULL)
        tclsetvar("tctx::retval",xctx->schverilogprop);
      else
        tclsetvar("tctx::retval","");
     }
     else if(xctx->netlist_type==CAD_SPECTRE_NETLIST) {
      if(xctx->schspectreprop!=NULL)
        tclsetvar("tctx::retval",xctx->schspectreprop);
      else
        tclsetvar("tctx::retval","");
     }
     else if(xctx->netlist_type==CAD_SPICE_NETLIST) {
      if(xctx->schprop!=NULL)
        tclsetvar("tctx::retval",xctx->schprop);
      else
        tclsetvar("tctx::retval","");
     }
     else if(xctx->netlist_type==CAD_TEDAX_NETLIST) {
      if(xctx->schtedaxprop!=NULL)
        tclsetvar("tctx::retval",xctx->schtedaxprop);
      else
        tclsetvar("tctx::retval","");
     }
   }

   if(x==0) {
     xctx->semaphore++;
     tcleval("text_line {Global schematic property:} 0");
     xctx->semaphore--;
   }
   else if(x==1) {
      dbg(1, "edit_property(): executing edit_vi_prop\n");
      tcleval("edit_vi_prop {Global schematic property:}");
   }
   else if(x==2)    tcleval("viewdata $tctx::retval");
   dbg(1, "edit_property(): done executing edit_vi_prop, result=%s\n",tclresult());
   dbg(1, "edit_property(): tctx::rcode=%s\n",tclgetvar("tctx::rcode") );

   my_strdup(_ALLOC_ID_, &new_prop, (char *) tclgetvar("tctx::retval"));
   tclsetvar("tctx::retval", new_prop);
   my_free(_ALLOC_ID_, &new_prop);


   if(x == 1 && strcmp(tclgetvar("tctx::rcode"),"") )
   {
     if(xctx->netlist_type==CAD_SYMBOL_ATTRS &&
        (!xctx->schsymbolprop || strcmp(xctx->schsymbolprop, tclgetvar("tctx::retval") ) ) ) {
        xctx->push_undo();
        modified = 1;
        my_strdup(_ALLOC_ID_, &xctx->schsymbolprop, (char *) tclgetvar("tctx::retval"));

     } else if(xctx->netlist_type==CAD_VERILOG_NETLIST &&
        (!xctx->schverilogprop || strcmp(xctx->schverilogprop, tclgetvar("tctx::retval") ) ) ) {
        modified = 1;
        xctx->push_undo();
        my_strdup(_ALLOC_ID_, &xctx->schverilogprop, (char *) tclgetvar("tctx::retval"));

     } else if(xctx->netlist_type==CAD_SPECTRE_NETLIST &&
        (!xctx->schspectreprop || strcmp(xctx->schspectreprop, tclgetvar("tctx::retval") ) ) ) {
        modified = 1;
        xctx->push_undo();
        my_strdup(_ALLOC_ID_, &xctx->schspectreprop, (char *) tclgetvar("tctx::retval"));

     } else if(xctx->netlist_type==CAD_SPICE_NETLIST &&
        (!xctx->schprop || strcmp(xctx->schprop, tclgetvar("tctx::retval") ) ) ) {
        modified = 1;
        xctx->push_undo();
        my_strdup(_ALLOC_ID_, &xctx->schprop, (char *) tclgetvar("tctx::retval"));

     } else if(xctx->netlist_type==CAD_TEDAX_NETLIST &&
        (!xctx->schtedaxprop || strcmp(xctx->schtedaxprop, tclgetvar("tctx::retval") ) ) ) {
        modified = 1;
        xctx->push_undo();
        my_strdup(_ALLOC_ID_, &xctx->schtedaxprop, (char *) tclgetvar("tctx::retval"));

     } else if(xctx->netlist_type==CAD_VHDL_NETLIST &&
        (!xctx->schvhdlprop || strcmp(xctx->schvhdlprop, tclgetvar("tctx::retval") ) ) ) {
        modified = 1;
        xctx->push_undo();
        my_strdup(_ALLOC_ID_, &xctx->schvhdlprop, (char *) tclgetvar("tctx::retval"));
     }
   }

   /* update the bounding box of vhdl "architecture" instances that embed */
   /* the xctx->schvhdlprop string. 04102001 */
   for(j=0;j<xctx->instances; ++j)
   {
    if( xctx->inst[j].ptr !=-1 &&
        (xctx->inst[j].ptr+ xctx->sym)->type &&
        !strcmp( (xctx->inst[j].ptr+ xctx->sym)->type, "architecture") )
    {
      dbg(1, "edit_property(): updating vhdl architecture\n");
      symbol_bbox(j, &xctx->inst[j].x1, &xctx->inst[j].y1,
                        &xctx->inst[j].x2, &xctx->inst[j].y2);
    }
   } /* end for(j...) */
   if(modified) set_modify(1);
   return;
 } /* if((xctx->lastsel==0 ) */

 /* Single instance pin selected: open a READ-ONLY viewer of its name, direction and
  * connected net (a pin on an instance is not editable). pin_selection.md D5 */
 if(xctx->lastsel == 1 && xctx->sel_array[0].type == INST_PIN) {
   int n = xctx->sel_array[0].n, p = xctx->sel_array[0].col;
   if(n >= 0 && n < xctx->instances && xctx->inst[n].ptr >= 0) {
     xSymbol *sym = xctx->inst[n].ptr + xctx->sym;
     if(p >= 0 && p < sym->rects[PINLAYER]) {
       const char *t;
       const char *net;
       /* get_tok_value() returns a SINGLE shared static buffer, and
        * prepare_netlist_structs() calls it many times, so do the heavy work FIRST,
        * then read name/dir one at a time, copying each into Tcl (tclsetvar) before
        * the next get_tok_value() call clobbers the buffer. net is the instance's own
        * node[] heap string, not the shared buffer, so it is read after prepare. */
       prepare_netlist_structs(0);
       net = (xctx->inst[n].node && xctx->inst[n].node[p]) ? xctx->inst[n].node[p] : "";
       tclsetvar("pin_view(inst)", xctx->inst[n].instname ? xctx->inst[n].instname : "");
       tclsetvar("pin_view(net)",  net[0] ? net : "(unconnected)");
       t = get_tok_value(sym->rect[PINLAYER][p].prop_ptr, "name", 0);
       tclsetvar("pin_view(name)", t[0] ? t : "(unnamed)");
       t = get_tok_value(sym->rect[PINLAYER][p].prop_ptr, "dir", 0);
       tclsetvar("pin_view(dir)",  t[0] ? t : "inout");
       tcleval("pin_property_viewer");
     }
   }
   return;
 }

 /* The old "force preserve_unchanged_attrs when multi-selected" default is gone:
  * selecting N instances no longer implies editing N. Changed-fields-only is now
  * the unconditional contract (forced in update_symbol) and the slick form's
  * sticky "Apply to" scope (::slickprop_apply_scope, default Only Current) is the
  * sole authority over which instances an Apply/OK touches. */

 j = set_first_sel(0, -2, 0);
 type = xctx->sel_array[j].type;

 /* Q on an owned pin-name view edits the pin's NAME TEXT (size/font/offset/rot/flip): the
  * name lives in the pin rect's tokens, so retarget the selection to the owning pin rect,
  * and flag it so gfxform picks the `pinname` editor (not the pin-identity `pin` editor).
  * D-split, doc/claude/specs/cadence_pin_name_text.md. */
 if(type == xTEXT && xctx->text[xctx->sel_array[j].n].owner_pin_id) {
   int pi = pin_idx_by_id(xctx->text[xctx->sel_array[j].n].owner_pin_id);
   if(pi >= 0) {
     unselect_all(0);
     select_box(PINLAYER, pi, SELECTED, 0, 0);
     xctx->ui_state |= SELECTION;
     rebuild_selected_array();
     j = set_first_sel(0, -2, 0);
     type = xctx->sel_array[j].type;
     tclsetvar("gfxform_via_name", "1");
   }
 }

 switch(type)
 {
  case ELEMENT:
   modified |= edit_symbol_property(x, j);
   while( x == 0 && tclgetvar("edit_symbol_prop_new_sel")[0] == '1') {
     unselect_all(1);
     select_object(xctx->mousex, xctx->mousey, SELECTED, 0, NULL);
     rebuild_selected_array();

     type = xctx->sel_array[0].type;
     for(j=0; j < xctx->lastsel; j++) {
       if(xctx->sel_array[j].type == ELEMENT) {
         type = ELEMENT;
         break;
       }
     }

     if(xctx->lastsel && type == ELEMENT) {
       modified |= edit_symbol_property(0, j);
     } else {
       break;
     }
   }
   tclsetvar("edit_symbol_prop_new_sel", "");
   break;
  case ARC:
   modified |= edit_arc_property();
   break;
  case xRECT:
   modified |= edit_rect_property(x);
   break;
  case WIRE:
   modified |= edit_wire_property();
   break;
  case POLYGON:
   modified |= edit_polygon_property();
   break;
  case LINE:
   modified |= edit_line_property();
   break;
  case xTEXT:
   modified |= edit_text_property(x);
   break;
 }
 if(modified) set_modify(1);
}


