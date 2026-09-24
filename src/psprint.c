/* File: psprint.c
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
#define X_TO_PS(x) ( (x+xctx->xorigin)* xctx->mooz )
#define Y_TO_PS(y) ( (y+xctx->yorigin)* xctx->mooz )

char *utf8_enc[]={
  "/recodedict 24 dict def\n",
  "/recode {recodedict begin /nco&na exch def\n",
  "/nfnam exch def /basefontname exch def /basefontdict basefontname findfont def\n",
  "/newfont basefontdict maxlength dict def basefontdict {exch dup /FID ne\n",
  "{dup /Encoding eq {exch dup length array copy newfont 3 1 roll put} {exch\n",
  "newfont 3 1 roll put} ifelse} {pop pop} ifelse } forall newfont\n",
  "/FontName nfnam put nco&na aload pop nco&na length 2 idiv {newfont\n",
  "/Encoding get 3 1 roll put} repeat nfnam newfont definefont pop end } def\n",
};

char *utf8[]={
"/chararr [\n",
/* 0xC2 2-byte characters */
" 161 /exclamdown\n", " 162 /cent\n", " 163 /sterling\n", " 164 /currency\n",
" 165 /yen\n", " 166 /bar\n", " 167 /section\n", " 168 /dieresis\n",
" 169 /copyright\n", " 170 /ordfeminine\n", " 171 /guillemotleft\n", " 172 /logicalnot\n",
" 173 /emdash\n", " 174 /registered\n", " 175 /macron\n", " 176 /degree\n",
" 177 /plusminus\n", " 178 /twosuperior\n", " 179 /threesuperior\n", " 180 /acute\n",
" 181 /mu\n", " 182 /paragraph\n", " 183 /periodcentered\n", " 184 /cedilla\n",
" 185 /onesuperior\n", " 186 /ordmasculine\n", " 187 /guillemotright\n", " 188 /onequarter\n",
" 189 /onehalf\n", " 190 /threequarters\n", " 191 /questiondown\n",
/* 0xC3 2-byte characters */
" 192 /Agrave\n", " 193 /Aacute\n", " 194 /Acircumflex\n", " 195 /Atilde\n",
" 196 /Adieresis\n", " 197 /Aring\n", " 198 /AE\n", " 199 /Ccedilla\n",
" 200 /Egrave\n", " 201 /Eacute\n", " 202 /Ecircumflex\n", " 203 /Edieresis\n",
" 204 /Igrave\n", " 205 /Iacute\n", " 206 /Icircumflex\n", " 207 /Idieresis\n",
" 208 /Eth\n", " 209 /Ntilde\n", " 210 /Ograve\n", " 211 /Oacute\n",
" 212 /Ocircumflex\n", " 213 /Otilde\n", " 214 /Odieresis\n", " 215 /multiply\n",
" 216 /Oslash\n", " 217 /Ugrave\n", " 218 /Uacute\n", " 219 /Ucircumflex\n",
" 220 /Udieresis\n", " 221 /Yacute\n", " 222 /Thorn\n", " 223 /germandbls\n",
" 224 /agrave\n", " 225 /aacute\n", " 226 /acircumflex\n", " 227 /atilde\n",
" 228 /adieresis\n", " 229 /aring\n", " 230 /ae\n", " 231 /ccedilla\n",
" 232 /egrave\n", " 233 /eacute\n", " 234 /ecircumflex\n", " 235 /edieresis\n",
" 236 /igrave\n", " 237 /iacute\n", " 238 /icircumflex\n", " 239 /idieresis\n",
" 240 /eth\n", " 241 /ntilde\n", " 242 /ograve\n", " 243 /oacute\n",
" 244 /ocircumflex\n", " 245 /otilde\n", " 246 /odieresis\n", " 247 /divide\n",
" 248 /oslash\n", " 249 /ugrave\n", " 250 /uacute\n", " 251 /ucircumflex\n",
" 252 /udieresis\n", " 253 /yacute\n", " 254 /thorn\n", " 255 /ydieresis\n",
" ] def\n"};

static FILE *fd;

typedef struct {
 unsigned int red;
 unsigned int green;
 unsigned int blue;
} Ps_color;

static Ps_color *ps_colors;
static char ps_font_name[80] = "Helvetica"; /* Courier Times Helvetica Symbol */
static char ps_font_family[80] = "Helvetica"; /* Courier Times Helvetica Symbol */

static int ps_embedded_image(xRect* r, double x1, double y1, double x2, double y2, int rot, int flip)
{
  #if defined(HAS_LIBJPEG) && HAS_CAIRO==1
  int i, jpg = -1;
  int size_x, size_y;
  unsigned char *ptr = NULL;
  int invertImage;
  unsigned char* ascii85EncodedJpeg;
  char *attr = NULL;
  unsigned char *buffer = NULL;
  cairo_surface_t *surface = NULL, *orig_sfc = NULL;
  xEmb_image *emb_ptr;
  unsigned char* jpgData = NULL;
  size_t fileSize = 0;
  int quality=40;
  const char *quality_attr, *filter;
  size_t oLength, attr_len, buffer_size;
  cairo_t *ct;
  double sx1, sy1, sx2, sy2;

  /* screen position */
  sx1=X_TO_SCREEN(x1);
  sy1=Y_TO_SCREEN(y1);
  sx2=X_TO_SCREEN(x2);
  sy2=Y_TO_SCREEN(y2);
  if(RECT_OUTSIDE(sx1, sy1, sx2, sy2,
                  xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2)) return 0;

  invertImage = !strboolcmp(get_tok_value(r->prop_ptr, "InvertOnExport", 0), "true");
  if(!invertImage)
    invertImage = !strboolcmp(get_tok_value(r->prop_ptr, "ps_invert", 0), "true");
  quality_attr = get_tok_value(r->prop_ptr, "jpeg_quality", 0);
  if(quality_attr[0]) quality = atoi(quality_attr);
  else {
    quality_attr = get_tok_value(r->prop_ptr, "jpg_quality", 0);
    if(quality_attr[0]) quality = atoi(quality_attr);
  }
  attr_len = my_strdup2(_ALLOC_ID_, &attr, get_tok_value(r->prop_ptr, "image_data", 0));
  filter = get_tok_value(r->prop_ptr, "filter", 0);
  buffer = base64_decode(attr, attr_len, &buffer_size);
  if(attr_len > 5) {
    if(!strncmp(attr, "/9j/", 4)) jpg = 1; /* jpg */
    else if(!strncmp(attr, "iVBOR", 5)) jpg = 0; /* png */
    else if(my_memmem(buffer, buffer_size, "<svg", 4) &&
            my_memmem(buffer, buffer_size, "xmlns", 5)) {
      if(filter) {
        jpg = 2; /* svg */
      }
    }
    else jpg = -1; /* some invalid data */
  } else {
    jpg = -1;
  }
  emb_ptr = r->extraptr;
  if(jpg == -1 || !(emb_ptr && emb_ptr->image)) {
    my_free(_ALLOC_ID_, &buffer);
    my_free(_ALLOC_ID_, &attr);
    return 0;
  }
  orig_sfc = emb_ptr->image;
  cairo_surface_flush(orig_sfc);
  /* create a copy of image surface with no alpha */
  size_x = cairo_image_surface_get_width(orig_sfc);
  size_y = cairo_image_surface_get_height(orig_sfc);
  surface = cairo_surface_create_similar_image(orig_sfc, CAIRO_FORMAT_RGB24, size_x, size_y);
  ct = cairo_create(surface);
  cairo_set_source_surface(ct, orig_sfc, 0, 0);
  cairo_set_operator(ct, CAIRO_OPERATOR_SOURCE);
  cairo_paint(ct);
  cairo_destroy(ct);

  ptr = cairo_image_surface_get_data(surface);

  for (i = 0; i < (size_x * size_y * 4); i += 4)
  {
    unsigned char a = ptr[i + 3];
    unsigned char r = ptr[i + 2];
    unsigned char g = ptr[i + 1];
    unsigned char b = ptr[i + 0];
    /* invert colors */
    if(invertImage) {
      r = a - r;
      g = a - g;
      b = a - b;
    }
    /* blend with white, remove alpha */
    r += (unsigned char)(0xff - a);
    g += (unsigned char)(0xff - a);
    b += (unsigned char)(0xff - a);
    a  = (unsigned char) 0xff;
    /* write result back */
    ptr[i + 3] = a;
    ptr[i + 2] = r;
    ptr[i + 1] = g;
    ptr[i + 0] = b;
  }
  cairo_surface_mark_dirty(surface);
  if(invertImage || jpg != 1) {
    cairo_image_surface_write_to_jpeg_mem(surface, &jpgData, &fileSize, quality);
  } else {
    jpgData = base64_decode(attr, attr_len, &fileSize);
  }
  cairo_surface_destroy(surface);
  ascii85EncodedJpeg = ascii85_encode(jpgData, fileSize, &oLength);
  fprintf(fd, "gsave\n");
  fprintf(fd, "save\n");
  fprintf(fd, "/RawData currentfile /ASCII85Decode filter def\n");
  fprintf(fd, "/Data RawData << >> /DCTDecode filter def\n");
  fprintf(fd, "%g %g translate\n", X_TO_PS(x1), Y_TO_PS(y1));
  if(rot==1) fprintf(fd, "90 rotate\n");
  if(rot==2) fprintf(fd, "180 rotate\n");
  if(rot==3) fprintf(fd, "270 rotate\n");
  fprintf(fd, "%g %g scale\n", (X_TO_PS(x2) - X_TO_PS(x1))*1., (Y_TO_PS(y2) - Y_TO_PS(y1))*1.);
  fprintf(fd, "/DeviceRGB setcolorspace\n");
  fprintf(fd, "{ << /ImageType 1\n");
  fprintf(fd, "     /Width %g\n", (double)size_x);
  fprintf(fd, "     /Height %g\n", (double)size_y);

  if(!flip)
  {
    if(rot==1) fprintf(fd, "     /ImageMatrix [%g 0 0 %g 0 %g]\n",
           (double)size_y, (double)size_x, (double)size_y);
    else if(rot==2) fprintf(fd, "     /ImageMatrix [%g 0 0 %g %g %g]\n",
           (double)size_x, (double)size_y, (double)size_x, (double)size_y);
    else if(rot==3) fprintf(fd, "     /ImageMatrix [%g 0 0 %g %g 0]\n",
           (double)size_y, (double)size_x, (double)size_x);
    else fprintf(fd, "     /ImageMatrix [%g 0 0 %g 0 0]\n", (double)size_x, (double)size_y);
  }
  else
  {
    if(rot==1) fprintf(fd, "     /ImageMatrix [%g 0 0 %g %g %g]\n",
          -(double)size_y, (double)size_x, (double)size_x, (double)size_y);
    else if(rot==2) fprintf(fd, "     /ImageMatrix [%g 0 0 %g 0 %g]\n",
          -(double)size_x, (double)size_y, (double)size_y);
    else if(rot==3) fprintf(fd, "     /ImageMatrix [%g 0 0 %g 0 0]\n",
          -(double)size_y, (double)size_x);
    else fprintf(fd, "     /ImageMatrix [%g 0 0 %g %g 0]\n",
          -(double)size_x, (double)size_y, (double)size_x);
  }
  fprintf(fd, "     /DataSource Data\n");
  fprintf(fd, "     /BitsPerComponent 8\n");
  fprintf(fd, "     /Decode [0 1 0 1 0 1]\n");
  fprintf(fd, "  >> image\n");
  fprintf(fd, "  Data closefile\n");
  fprintf(fd, "  RawData flushfile\n");
  fprintf(fd, "  restore\n");
  fprintf(fd, "} exec\n");

  #if 1  /* break lines */
  for (i = 0; i < oLength; ++i)
  {
    fputc(ascii85EncodedJpeg[i],fd);
    if(i > 0 && (i % 64) == 0)
    {
      fputc('\n',fd);
      /* if (ascii85Encode[i+1]=='%') idx=63; imageMagic does this for some reason?!
       *  Doesn't seem to be necesary. */
    }
  }
  #else
  fprintf(fd, "%s", ascii85EncodedJpeg);
  #endif
  fprintf(fd, "~>\n");

  fprintf(fd, "grestore\n");
  my_free(_ALLOC_ID_, &ascii85EncodedJpeg);
  free(jpgData);
  my_free(_ALLOC_ID_, &buffer);
  my_free(_ALLOC_ID_, &attr);
  #endif
  return 1;
}

static int ps_embedded_graph(int i, double rx1, double ry1, double rx2, double ry2)
{
  #if defined(HAS_LIBJPEG) && HAS_CAIRO==1
  xRect *r = &xctx->rect[GRIDLAYER][i];
  Zoom_info zi;
  double  rw, rh, scale;
  cairo_surface_t* png_sfc;
  int save, save_draw_window, save_draw_grid, rwi, rhi;
  const double max_size = 2500.0;
  int d_c;
  unsigned char* jpgData = NULL;
  size_t fileSize = 0;
  /*
   * FILE* fp;
   * static char str[PATH_MAX];
   */
  unsigned char *ascii85EncodedJpeg;
  int quality=40;
  const char *quality_attr;
  size_t oLength;
  int j;
  double sx1, sy1, sx2, sy2;

  /* screen position */
  sx1=X_TO_SCREEN(rx1);
  sy1=Y_TO_SCREEN(ry1);
  sx2=X_TO_SCREEN(rx2);
  sy2=Y_TO_SCREEN(ry2);
  if(RECT_OUTSIDE(sx1, sy1, sx2, sy2,
                  xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2)) return 0;

  quality_attr = get_tok_value(r->prop_ptr, "jpeg_quality", 0);
  if(quality_attr[0]) quality = atoi(quality_attr);
  else {
    quality_attr = get_tok_value(r->prop_ptr, "jpg_quality", 0);
    if(quality_attr[0]) quality = atoi(quality_attr);
  }
  if(quality_attr[0]) quality = atoi(quality_attr);
  if (!has_x) return 0;

  rw = fabs(rx2 - rx1);
  rh = fabs(ry2 - ry1);
  scale = 3.0;
  if (rw > rh && rw * scale  > max_size) {
    scale = max_size / rw;
  }
  else if (rh * scale  > max_size) {
    scale = max_size / rh;
  }
  rwi = (int)(rw * scale + 1.0);
  rhi = (int)(rh * scale + 1.0);
  dbg(1, "graph size, saving zoom : %dx%d\n", rwi, rhi);
  save_restore_zoom(1, &zi);
  xctx->lw *= scale;
  set_viewport_size(rwi, rhi, xctx->lw);

  /* zoom_box(rx1 - xctx->lw, ry1 - xctx->lw, rx2 + xctx->lw, ry2 + xctx->lw, 1.0); */

  xctx->xorigin = -rx1;
  xctx->yorigin = -ry1;
  xctx->zoom=(rx2-rx1)/(rwi - 1);
  xctx->mooz = 1 / xctx->zoom;

  resetwin(1, 1, 1, rwi, rhi);
  dbg(1, "lw=%g\n", xctx->lw);
  save_draw_grid = tclgetboolvar("draw_grid");
  tclsetvar("draw_grid", "0");
  save_draw_window = xctx->draw_window;
  xctx->draw_window = 0;
  xctx->draw_pixmap = 1;
  save = xctx->do_copy_area;
  xctx->do_copy_area = 0;
  d_c = tclgetboolvar("dark_colorscheme");
  tclsetboolvar("dark_colorscheme", 0);
  build_colors(0, 0);
  setup_graph_data(i, 0, &xctx->graph_struct);
  draw_graph(i, 8 + (xctx->graph_flags & (4 | 2 | 128 | 256)), &xctx->graph_struct, NULL);

  dbg(1, "width=%d, rwi=%d height=%d rhi=%d\n", xctx->xrect[0].width, rwi, xctx->xrect[0].height, rhi);
  #ifdef __unix__
  png_sfc = cairo_xlib_surface_create(display, xctx->save_pixmap, visual,
     xctx->xrect[0].width, xctx->xrect[0].height);
  #else
  /* pixmap doesn't work on windows
       Copy from cairo_save_sfc and use cairo
       to draw in the data points to embed the graph */
  png_sfc = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, xctx->xrect[0].width, xctx->xrect[0].height);
  cairo_t* ct = cairo_create(png_sfc);
  cairo_set_source_surface(ct, xctx->cairo_save_sfc, 0, 0);
  cairo_set_operator(ct, CAIRO_OPERATOR_SOURCE);
  cairo_paint(ct);
  setup_graph_data(i, 0, &xctx->graph_struct);
  draw_graph(i, 8 + (xctx->graph_flags & (4 | 2 | 128 | 256)), &xctx->graph_struct, (void *)ct);
  #endif
  cairo_image_surface_write_to_jpeg_mem(png_sfc, &jpgData, &fileSize, quality);

  ascii85EncodedJpeg = ascii85_encode(jpgData, fileSize, &oLength);
  free(jpgData);

  cairo_surface_destroy(png_sfc);
  xctx->draw_pixmap = 1;
  tclsetboolvar("draw_grid", save_draw_grid);
  save_restore_zoom(0, &zi);
  resetwin(1, 1, 1, xctx->xrect[0].width, xctx->xrect[0].height);
  dbg(1, "restore zoom + resetwin: %dx%d\n", xctx->xrect[0].width, xctx->xrect[0].height);
  change_linewidth(xctx->lw);
  tclsetboolvar("dark_colorscheme", d_c);
  build_colors(0, 0);
  draw();
  xctx->do_copy_area = save;
  xctx->draw_window = save_draw_window;
  fprintf(fd, "gsave\n");
  fprintf(fd, "save\n");
  fprintf(fd, "/RawData currentfile /ASCII85Decode filter def\n");
  fprintf(fd, "/Data RawData << >> /DCTDecode filter def\n");
  fprintf(fd, "%f %f translate\n", X_TO_PS(rx1), Y_TO_PS(ry1));
  fprintf(fd, "%f %f scale\n", X_TO_PS(rx2) - X_TO_PS(rx1), Y_TO_PS(ry2) - Y_TO_PS(ry1));
  fprintf(fd, "/DeviceRGB setcolorspace\n");
  fprintf(fd, "{ << /ImageType 1\n");
  fprintf(fd, "     /Width %d\n", rwi);
  fprintf(fd, "     /Height %d\n", rhi);
  fprintf(fd, "     /ImageMatrix [%d 0 0 %d 0 0]\n", rwi, rhi);
  fprintf(fd, "     /DataSource Data\n");
  fprintf(fd, "     /BitsPerComponent 8\n");
  fprintf(fd, "     /Decode [0 1 0 1 0 1]\n");
  fprintf(fd, "  >> image\n");
  fprintf(fd, "  Data closefile\n");
  fprintf(fd, "  RawData flushfile\n");
  fprintf(fd, "  restore\n");
  fprintf(fd, "} exec\n");

  #if 1 /* break lines */
  for (j = 0; j < oLength; ++j)
  {
    fputc(ascii85EncodedJpeg[j],fd);
    if(j > 0 && (j % 64) == 0)
    {
      fputc('\n',fd);
      /* if (ascii85Encode[i+1]=='%') idx=63; imageMagic does this for some reason?!
       *  Doesn't seem to be necesary. */
    }
  }
  #else
  fprintf(fd, "%s", ascii85EncodedJpeg);
  #endif
  fprintf(fd, "~>\n");

  fprintf(fd, "grestore\n");

  my_free(_ALLOC_ID_, &ascii85EncodedJpeg);

  #endif
  return 1;
}
/* ISSUE 1342/1343 -- A LINE WIDTH THIS BACK END CANNOT MEAN MUST NOT REACH THE DISTILLER.
 *
 * ⚠ READ THE SCOPE OF THAT SENTENCE. It used to read "A NUMBER ...", which promised a
 * guarantee this file does not make: `set_lw()` is ONE of about a dozen sinks that take a
 * double straight out of a `.sch` and print it with `%g`. Every numeric field a schematic
 * carries reaches PostScript unchecked, and `fscanf("%lf")` accepts `inf` and `nan`.
 * Measured on the FIXED binary: `hsize=inf` emits `inf SCF` -> `/undefined`; `hsize=nan`
 * -> `/undefined`; `hsize=1e40` -> `/limitcheck`; and an arc radius, an arc angle, a
 * line/poly/rect coordinate or `dash=2147483647` each kill a document the same way. A
 * 5-page fixture with one `inf` text size distils to 2 pages, exactly as 1342 did. That
 * family is issue **1354** and it is NOT fixed here. This function guards line widths.
 * PostScript reals are SINGLE precision, so any value past ~3.4e38 is a hard
 * /limitcheck: measured against gs 10.06, `1e38 setlinewidth` distils and
 * `1e39 setlinewidth` kills the job. And a /limitcheck kills the WHOLE document, not
 * the one line -- ps2pdf exits 1 and every page after the offending one is lost.
 * Measured on the shipped xschem_library/examples/0_examples_top.sch: 99 correct pages
 * and 305 correct links in the PostScript, TEN pages and 67 links after ps2pdf, because
 * page 11 carries `9.78375e+160 setlinewidth`. Seven of 325 swept sheets died this way,
 * including sky130_tests/top (86 pages -> 39).
 *
 * THIS CLAMP IS THE SECOND LINE OF DEFENCE, NOT THE FIX. The garbage is an uninitialised
 * read and it is fixed at source: add_pinlayer_boxes() (save.c) synthesises the PINLAYER
 * rect of an LCC pin into freshly my_realloc'd storage and set every field of it EXCEPT
 * `bus`, which ps_filledrect() then turns into `width = bus * xctx->mooz` and hands here.
 * Confirmed with valgrind --track-origins (the origin is that realloc, verbatim). The
 * clamp stays because an export that DIES is worse than a hairline, because the same sink
 * is fed by four other call sites, and because NaN/Inf would print as the bare tokens
 * `nan`/`inf` -- which PostScript reads as executable names, i.e. /undefined.
 *
 * C89: no isfinite(). `w != w` is NaN; +Inf fails the upper bound and -Inf the lower.
 * The bound is 1e6. Once the source is fixed the LARGEST width the whole 325-sheet corpus
 * emits is **7.96** -- the 197 / 222 / 287 / 348 values the unfixed binary wrote were
 * garbage too, merely garbage small enough to distil -- so 1e6 is five orders clear of
 * anything a page can mean and twenty-two clear of nothing. Measured: over the fixed
 * corpus this clamp fires ZERO times (sabotage: removing it leaves all 325 sheets clean and
 * reddens only row V21, the user-written `bus=1e300`). */
/* --------------------------------------------------------------------------
 * ⚠ THE ISSUE NUMBERS IN THIS FILE'S HIERARCHICAL-PDF COMMENTS ARE THE `op-wcard`
 * BRANCH'S NUMBERING, NOT THIS TREE'S.  DO NOT FOLLOW ONE INTO doc/claude/issues/.
 *
 * This code was ported to `fluid-editing` on 2026-09-24 from a finished batch on the
 * `op-wcard` branch. That batch's directory (doc/claude/hier_pdf_links_batch/) and its
 * eighteen issue files stayed there and are NOT in this clone -- deliberately, because
 * EVERY number they use, 1333 through 1360, is already taken HERE by a completely
 * unrelated defect: 1333 here is an op-dump reader with no caller, 1342 a simcaps
 * count, 1350 an annotation-order dump. A reader who follows one of these numbers into
 * this tree's doc/claude/issues/ will find a real file about something else entirely.
 * Read the real ones on the branch that has them:
 *     git -C <an op-wcard clone> show op-wcard:doc/claude/issues/1334-*.md
 *     git -C <an op-wcard clone> show \
 *         op-wcard:doc/claude/hier_pdf_links_batch/DECISIONS.md
 * Nothing has been renumbered, on purpose: the eighteen colliding files are committed
 * in both trees and cited from source comments and commit messages in both. Who moves,
 * if anyone, is the USER'S ruling -- carried as issue 1400 in this tree and issue 1347
 * on op-wcard, both still open.
 * ------------------------------------------------------------------------ */
#define PS_LW_MAX 1e6
#define PS_LW_HAIRLINE 0.5
static void set_lw(double lw)
{
 double w;

 if(lw==0.0) w = PS_LW_HAIRLINE;
 else        w = lw / 1.2;
 if(w != w || w < 0.0 || w > PS_LW_MAX) w = PS_LW_HAIRLINE;
 fprintf(fd, "%g setlinewidth\n", w);
}

/* ISSUE 1353 -- THE OTHER HALF OF 1342: `ps_colors[cadlayers]` IS OFF THE END OF THE ARRAY.
 * `ps_colors` is `my_calloc(cadlayers, sizeof(Ps_color))`, but create_ps() calls
 * `ps_draw_symbol(c + 1, i, c + 1, ...)` for the text pass when c == cadlayers - 1, and that
 * pass ends with `if(textlayer != c) set_ps_colors(c)` -- restoring the colour of a layer
 * index that is not a layer. Confirmed with valgrind: "Invalid read of size 4 ... 8 bytes
 * after a block of size 264", the block being this array. It is heap garbage, so the RGB
 * emitted moves with heap layout: three runs of one binary on greycnt.sch printed 136 / 67
 * / 136 triples like `0.566406 0 1.27608e+07 RGB` (blue = 1.3e7 on a 0..1 scale), and this
 * item's OTHER change shifted pcb_test2's from a dark blue to a clamped magenta -- which is
 * how it was found, in the rendered-page comparison rather than in a distiller error.
 *
 * It never killed a document, because setrgbcolor CLAMPS to [0,1] rather than raising, so
 * this is a wrong COLOUR and an invalid READ, not a truncation. Fixed by declining to claim
 * a colour for a pseudo-layer. The restore is redundant for correctness in any case: every
 * drawing site sets its own colour before drawing (ps_draw_string_line() opens with
 * set_ps_colors(layer)), which is why suppressing it is render-identical on 313 of the 314
 * sheets that distilled cleanly before this item -- measured, gs -r100 -sDEVICE=pgmraw,
 * page by page. */
static void set_ps_colors(unsigned int pixel)
{

   dbg(1, "set_ps_colors(): setting color %u\n", pixel);
   if(pixel >= (unsigned int)cadlayers) return;                       /* issue 1353 */
   if(color_ps) fprintf(fd, "%g %g %g RGB\n",
     (double)ps_colors[pixel].red/256.0, (double)ps_colors[pixel].green/256.0,
     (double)ps_colors[pixel].blue/256.0);

}

/* Custom-RGB hilight color override for export (issue 0044), the PS analog of svgdraw's. set_ps_colors
 * emits an inline RGB per color change, so temporarily repointing ps_colors[layer] to the style's RGB
 * just before the highlighted wire/symbol is drawn (and restoring after) paints it in the custom color
 * instead of the fallback layer get_color() maps a custom style to. Returns 1 (with *saved filled) if it
 * overrode that layer's palette entry, else 0; the caller restores with ps_pop_hilight(). */
static int ps_push_hilight(int value, int layer, Ps_color *saved)
{
  unsigned char r, g, b;
  if(layer < 0 || layer >= cadlayers) return 0;
  if(value < 0 || !hilight_custom_rgb8(value, &r, &g, &b)) return 0;
  *saved = ps_colors[layer];
  ps_colors[layer].red = r; ps_colors[layer].green = g; ps_colors[layer].blue = b;
  return 1;
}
static void ps_pop_hilight(int layer, int did, Ps_color *saved)
{
  if(did && layer >= 0 && layer < cadlayers) ps_colors[layer] = *saved;
}

static void ps_xdrawarc(int layer, int fillarc, double x, double y, double r, double a, double b)
{
 if(xctx->fill_pattern && xctx->fill_type[layer]  && fillarc)
   fprintf(fd, "%g %g MT %g %g %g %g %g A %g %g LT C F S\n",
                 x, y,  x, y, r, -a, -a-b, x, y);
 else
   fprintf(fd, "%g %g %g %g %g A S\n", x, y, r, -a, -a-b);

}

static void ps_xdrawline(int layer, double x1, double y1, double x2,
                  double y2)
{
 fprintf(fd, "%.6g %.6g %.6g %.6g L\n", x2, y2, x1, y1);
}

static void ps_xdrawpoint(int layer, double x1, double y1)
{
 fprintf(fd, "%g %g %g %g L\n", x1, y1,x1,y1);
}

/* fill_pattern:
 * 0 : no fill
 * 1 : stippled fill
 * 2 : solid fill
 *
 * fill_type[i]:
 * 0 : no fill
 * 1 : patterned (stippled) fill
 * 2 : solid fill
 *
 * fill:
 * 0 : no fill
 * 1 : stippled fill
 * 2 : solid fill
 */

static void ps_xfillrectangle(int layer, double x1, double y1, double x2,
                  double y2, int fill)
{
 fprintf(fd, "%g %g %g %g R\n", x1,y1,x2-x1,y2-y1);
 if(xctx->fill_pattern && xctx->fill_type[layer] && fill) {
   fprintf(fd, "%g %g %g %g RF\n", x1,y1,x2-x1,y2-y1);
   /* fprintf(fd,"fill\n"); */
 }
 /*fprintf(fd,"stroke\n"); */
}

static void ps_drawbezier(double *x, double *y, int points)
{
  const double bez_steps = 1.0/32.0; /* divide the t = [0,1] interval into 32 steps */
  int b, i;
  double t;
  double xp, yp;
  double x0, x1, x2, y0, y1, y2;

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
      if(i==0) fprintf(fd, "NP\n%g %g MT\n",  X_TO_PS(xp), Y_TO_PS(yp));
      else fprintf(fd, "%g %g LT\n",  X_TO_PS(xp), Y_TO_PS(yp));
      i++;
    }
  }
}

/* Convex Nonconvex Complex */
#define Polygontype Nonconvex
static void ps_drawpolygon(int c, int what, double *x, double *y, int points,
                           int poly_fill, int dash, int flags, double bus)
{
  double x1,y1,x2,y2;
  double xx, yy;
  double psdash;
  int i, bezier;
  double width;

  if(bus == -1.0) width = BUS_WIDTH * xctx->lw;
  else if(bus > 0.0) width = bus * xctx->mooz;
  else width = -1.0;

  polygon_bbox(x, y, points, &x1,&y1,&x2,&y2);
  x1=X_TO_PS(x1);
  y1=Y_TO_PS(y1);
  x2=X_TO_PS(x2);
  y2=Y_TO_PS(y2);
  if( !rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) ) {
    return;
  }
  psdash = dash / xctx->zoom;
  if(bus > 0.0) {
    fprintf(fd, "0 setlinejoin 2 setlinecap\n");
  }
  if(dash) {
    fprintf(fd, "[%g %g] 0 setdash\n", psdash, psdash);
  }
  if(width >= 0.0) set_lw(1.2 * width);
  bezier = flags && (points > 2);
  if(bezier) {
    ps_drawbezier(x, y, points);
  } else {
    for(i=0;i<points; ++i) {
      xx = X_TO_PS(x[i]);
      yy = Y_TO_PS(y[i]);
      if(i==0) fprintf(fd, "NP\n%g %g MT\n", xx, yy);
      else fprintf(fd, "%g %g LT\n", xx, yy);
    }
  }
  if(xctx->fill_pattern && xctx->fill_type[c] && poly_fill) {
    fprintf(fd, "GS C F GR S\n");
  } else {
    fprintf(fd, "S\n");
  }
  if(dash) {
    fprintf(fd, "[] 0 setdash\n");
  }
  if(width >= 0.0) set_lw(xctx->lw);
  if(bus > 0.0) {
    fprintf(fd, "1 setlinejoin 1 setlinecap\n");
  }
}


static void ps_filledrect(int gc, double rectx1,double recty1,double rectx2,double recty2,
     double bus, int dash, int fill, int e_a, int e_b)
{
 double x1,y1,x2,y2;
 double psdash;
 double width;

 if(bus == -1.0) width = BUS_WIDTH * xctx->lw;
 else if(bus > 0.0) width = bus * xctx->mooz;
 else width = -1.0;

  x1=X_TO_PS(rectx1);
  y1=Y_TO_PS(recty1);
  x2=X_TO_PS(rectx2);
  y2=Y_TO_PS(recty2);
  if(rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2))
  {
    psdash = dash / xctx->zoom;

    if(bus > 0.0) {
      fprintf(fd, "0 setlinejoin 2 setlinecap\n");
    }
    if(dash) {
      fprintf(fd, "[%g %g] 0 setdash\n", psdash, psdash);
    }
    if(width >= 0.0) set_lw(1.2 * width);

    if(e_a != -1) {
      double rx = (x2 - x1) / 2.0;
      double ry = (y2 - y1) / 2.0;
      double cx = (x2 + x1) / 2.0;
      double cy = (y2 + y1) / 2.0;

      if(xctx->fill_pattern && xctx->fill_type[gc] && fill) {
        fprintf(fd, "%g %g MT %g %g %g %g %d %d E %g %g LT C F S\n",
                    cx, cy, cx, cy, rx, ry, -e_a, -e_a-e_b, cx, cy);
      } else {
        fprintf(fd, "%g %g %g %g %d %d E S\n", cx, cy, rx, ry, -e_a, -e_a-e_b);
      }
    } else {
      ps_xfillrectangle(gc, x1,y1,x2,y2, fill);
    }
    if(dash) {
      fprintf(fd, "[] 0 setdash\n");
    }
    if(width >= 0.0) set_lw(xctx->lw);
    if(bus > 0.0) {
      fprintf(fd, "1 setlinejoin 1 setlinecap\n");
    }
  }
}

static void ps_drawarc(int gc, int fillarc, double x,double y,double r,double a, double b, double bus, int dash)
{
 double xx,yy,rr;
 double x1, y1, x2, y2;
 double psdash;
 double width;

 if(bus == -1.0) width = BUS_WIDTH * xctx->lw;
 else if(bus > 0.0) width = bus * xctx->mooz;
 else width = -1.0;

  if(b < 0.0) {
    a = a + b;
    b = -b;
  }

  xx=X_TO_PS(x);
  yy=Y_TO_PS(y);
  rr=r*xctx->mooz;
  arc_bbox(x, y, r, a, b, &x1,&y1,&x2,&y2);
  x1=X_TO_PS(x1);
  y1=Y_TO_PS(y1);
  x2=X_TO_PS(x2);
  y2=Y_TO_PS(y2);

  if( rectclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,&x1,&y1,&x2,&y2) )
  {
    psdash = dash / xctx->zoom;
    if(bus > 0.0) {
      fprintf(fd, "0 setlinejoin 2 setlinecap\n");
    }
    if(dash) {
      fprintf(fd, "[%g %g] 0 setdash\n", psdash, psdash);
    }
    if(width >= 0.0) set_lw(1.2 * width);
    ps_xdrawarc(gc, fillarc, xx, yy, rr, a, b);
    if(dash) {
      fprintf(fd, "[] 0 setdash\n");
    }
    if(width >= 0.0) set_lw(xctx->lw);
    if(bus > 0.0) {
      fprintf(fd, "1 setlinejoin 1 setlinecap\n");
    }
  }
}


static void ps_drawline(int gc, double linex1,double liney1,double linex2,double liney2, int dash, double bus)
{
 double x1,y1,x2,y2;
 double psdash;
 double width;

 if(bus == -1.0) width = BUS_WIDTH * xctx->lw;
 else if(bus > 0.0) width = bus * xctx->mooz;
 else width = -1.0;


  x1=X_TO_PS(linex1);
  y1=Y_TO_PS(liney1);
  x2=X_TO_PS(linex2);
  y2=Y_TO_PS(liney2);
  if( clip(&x1,&y1,&x2,&y2) )
  {
    psdash = dash / xctx->zoom;
    if(bus > 0.0) {
      fprintf(fd, "0 setlinejoin 2 setlinecap\n");
    }
    if(dash) {
      fprintf(fd, "[%g %g] 0 setdash\n", psdash, psdash);
    }
    if(width >= 0.0) set_lw(1.2 * width);
    ps_xdrawline(gc, x1, y1, x2, y2);
    if(dash) {
      fprintf(fd, "[] 0 setdash\n");
    }
    if(width >= 0.0) set_lw(xctx->lw);
    if(bus > 0.0) {
      fprintf(fd, "1 setlinejoin 1 setlinecap\n");
    }
  }
}



/* ISSUE 1352 -- A PostScript NAME LITERAL BUILT FROM USER DATA.
 * `/foo` ends at the first whitespace or delimiter; PostScript names have NO escape
 * mechanism (`#xx` is PDF, not PostScript), so the only way to make an arbitrary string
 * into a name is to substitute the bytes that cannot appear in one. The delimiters are
 * ( ) < > [ ] { } / % (PLRM 3.1) and whitespace is NUL HT LF FF CR SP.
 *
 * Two sites feed this: the page anchor `/Dest /<cell> /DEST` and the annotation the Link
 * emitter below writes, both minted from a file basename by the same
 * get_cell_w_ext(sanitize(...)) call. (The literal subtype name is deliberately NOT spelled
 * here: row S65 of tests/headless/test_hier_pdf_links_1333.tcl counts it in this file and
 * requires exactly ONE occurrence, because a second copy that happens to agree passes every
 * behavioural row. It caught this comment on its first draft, which is the row doing its job
 * for the second time.) A schematic named `my cell.sch` emitted
 * `/Dest /my cell.sch` and gs died with `/undefined in cell.sch`, taking the whole
 * document -- measured, exit 1, zero pages. sanitize() does NOT cover this: it rewrites
 * only generator names (`is_generator()`), so an ordinary file name goes through raw.
 *
 * Everything that IS legal in a name passes through byte for byte, high bytes included,
 * so no cell whose export works today changes its destination spelling. `_` is the
 * substitute because it is already the character sanitize() uses for the same job.
 *
 * The substitution is not injective, so two cells whose names differ only in an illegal
 * byte would now share one destination -- which is the shape already filed as issues
 * 1348 and 1349 (a PDF /Dests name tree binds one object per name), reached by a new
 * route rather than created here: before this change those two cells produced a document
 * that did not open at all. */
static const char *ps_name_token(const char *s)
{
  static char buf[PATH_MAX];
  size_t i;

  if(!s) return "";
  for(i = 0; s[i] && i < sizeof(buf) - 1; i++) {
    unsigned char c = (unsigned char) s[i];
    if(c <= ' ' || c == 0x7f ||
       c == '(' || c == ')' || c == '<' || c == '>' || c == '[' || c == ']' ||
       c == '{' || c == '}' || c == '/' || c == '%') buf[i] = '_';
    else buf[i] = (char) c;
  }
  buf[i] = '\0';
  if(!buf[0]) { buf[0] = '_'; buf[1] = '\0'; }
  return buf;
}

/* ISSUE 1351 -- THE `font=` ATTRIBUTE IS A PostScript NAME AND A FORMAT STRING, AND IT
 * WAS NEITHER CHECKED NOR QUOTED.
 *
 * Two defects at one site. (a) `my_snprintf(ps_font_family, S(...), textfont)` passed
 * user data as the FORMAT STRING, so `font=%s` read a vararg that was never pushed.
 * (b) the value went straight into `/<name> FF`, and a name ends at the first delimiter:
 * the shipped xschem_library/ngspice_verilog_cosim/counter.sym carries
 * `font="courier new"`, which with the TEXT_BOLD suffix emits `/courier new-Bold FF` --
 * gs pushes the name /courier and then EXECUTES `new-Bold`, /undefined, document over.
 * Measured: xschem_library/examples/0_examples_top.sch stops at page 37 of 99 on this
 * alone, once the other two defects are out of the way.
 *
 * WHAT THIS MAPS, AND WHY IT IS NOT EVERYTHING. Only the GENERIC family names -- the
 * Cairo/CSS aliases xschem's own on-screen renderer resolves through fontconfig, which
 * PostScript has never heard of -- plus the two Microsoft "X New" spellings whose space
 * is the very thing that breaks the token. A real face name (Garamond, DejaVu Sans,
 * FreeMono) is deliberately NOT mapped: the distiller may actually have it, and
 * substituting Helvetica for a font gs could resolve would LOSE fidelity. Unmapped names
 * are only made into a legal token and handed to findfont exactly as before.
 *
 * THE MAPPING CHANGES PIXELS ON SHEETS THAT ALREADY WORKED, and that is disclosed rather
 * than buried: gs substitutes EVERY unknown name with Courier (measured -- /Monospace,
 * /monospace and /serif all resolve to /Courier), so `font=serif` renders monospaced
 * today and renders as Times after this change. That is the user's stated intent being
 * honoured rather than silently discarded, but it IS a typeface change and it is
 * recorded as a `rule` debt, not decided here. `font=monospace` moves from gs's
 * substituted Courier to the prolog's RECODED Courier: same face, same metrics, and the
 * accented glyphs above 127 start working.
 *
 * The suffixing below (`-Bold`, `-Oblique`, `-BoldOblique`) then composes on a base-14
 * base name, so `font="courier new"` + bold reaches the real Courier-Bold instead of
 * losing its weight to a substitution. */
static const char *ps_font_token(const char *s)
{
  static char buf[80];
  static const char *alias[] = {
    "monospace",  "Courier",
    "mono",       "Courier",
    "couriernew", "Courier",
    "courier",    "Courier",
    "serif",      "Times",
    "timesnewroman", "Times",
    "times",      "Times",
    "sansserif",  "Helvetica",
    "sans",       "Helvetica",
    "helvetica",  "Helvetica",
    "symbol",     "Symbol",
    NULL, NULL
  };
  char key[80];
  size_t i, k;

  if(!s || !s[0]) return "Helvetica";
  /* normalisation key: lower case, letters and digits only, so "Courier New",
   * "courier new" and "CourierNew" are one name and a stray space cannot hide an alias */
  for(i = 0, k = 0; s[i] && k < sizeof(key) - 1; i++) {
    unsigned char c = (unsigned char) s[i];
    if(c >= 'A' && c <= 'Z') key[k++] = (char)(c - 'A' + 'a');
    else if((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')) key[k++] = (char) c;
  }
  key[k] = '\0';
  for(i = 0; alias[i]; i += 2) {
    if(!strcmp(key, alias[i])) return alias[i + 1];
  }
  /* not a generic family: keep the name the user wrote, minus anything that would end
   * the PostScript name token, and let findfont resolve or substitute it as before */
  for(i = 0, k = 0; s[i] && k < sizeof(buf) - 1; i++) {
    unsigned char c = (unsigned char) s[i];
    if(c <= ' ' || c == 0x7f ||
       c == '(' || c == ')' || c == '<' || c == '>' || c == '[' || c == ']' ||
       c == '{' || c == '}' || c == '/' || c == '%') continue;
    buf[k++] = (char) c;
  }
  buf[k] = '\0';
  if(!buf[0]) return "Helvetica";
  return buf;
}

/* ISSUE 1350 -- THE BODY OF A PostScript `(...)` STRING LITERAL, ESCAPED.
 * A PostScript string literal ends at its matching `)`, and `\` is its escape
 * introducer (PLRM 3.2.2), so BOTH must be escaped and so must `(`. This loop escaped
 * `(` and `)` and NOT `\`, which means schematic text containing a single backslash
 * emitted the four bytes `(\)` -- a string whose only content is an escaped `)` and
 * which therefore never terminates. gs then reads the rest of the document as string
 * data until something unbalances, and dies with /syntaxerror.
 *
 * Not hypothetical, and not rare: THREE of 325 swept sheets die on it, one of them
 * sky130_tests/top -- the largest real design in the tree, 86 pages, truncated to 39
 * at `(tier_tcl\(@lab\\)`. xschem_library/devices/intuitive_interface_cheatsheet.sym
 * carries a lone `\` as its own text and is instantiated by the shipped
 * xschem_library/examples/0_examples_top.sch, which is why THAT export stops at
 * page 34 once the /limitcheck above is out of the way.
 *
 * ONE COPY OF THE RULE. The small page title (create_ps(), `(%s) show` from
 * xctx->current_name) wrote a FILENAME into a string literal with no escaping at all,
 * so a schematic called `foo(bar).sch` broke the same way. It calls this.
 *
 * The high-byte path is unchanged, deliberately: it is the UTF-8 -> chararr recoding the
 * prolog installs. Verified byte-for-byte over the 325-sheet corpus: the only PostScript
 * that moves is the sheets that used to carry a bare `\`.
 *
 * ⚠ AN EARLIER VERSION OF THIS COMMENT CLAIMED `c + offset` CANNOT EXCEED 255, BY
 * REASONING RATHER THAN MEASUREMENT, AND IT IS WRONG. The argument was that `offset` is 64
 * only for the byte after a 0xC3 lead, which is 0x80..0xBF. But `offset` is NOT reset when
 * that following byte is itself >= 0xC0: a text containing the bytes `C3 C0` emits
 * `(\400)` and `C3 FF` emits `(\477)`, both past `\377`, which PLRM leaves undefined.
 * Measured, not reasoned. Ghostscript tolerates them -- ps2pdf still exits 0 -- so this is
 * a wrong glyph on malformed UTF-8, not a dead document, which is why it is recorded here
 * rather than fixed inside an item whose subject is documents that die.
 *
 * ITEM H6 -- IT ALSO COUNTS, and the two modes are the same traversal on purpose.
 * The navigation strip below draws parent sheet names in Courier and has to size a
 * clickable rect around each one, which means it needs the number of GLYPHS the
 * string will show -- not strlen(). Those differ here in both directions: `(`
 * becomes two bytes and shows one glyph, and a two-byte UTF-8 sequence becomes one
 * `\\ddd` and shows one glyph. A rect sized from the escaped bytes is too wide and
 * pushes the next parent's hotspot under this one's ink. Rather than write a second
 * copy of the escaping rule to count with -- which is DD-2's exact prohibition, and
 * the shape of issue 1334 -- `f == NULL` runs the loop and emits nothing. Row N20. */
static int ps_string_body(FILE *f, const char *s)
{
  unsigned char c, offset = 0;
  int n = 0;

  if(!s) return 0;
  while( (c = (unsigned char) *s) ) {
    if(c > 127) {
      if(c == 195) {offset = 64; s++; continue;}
      if(c == 194) {s++; continue;}
      if(f) fprintf(f, "\\%03o", c + offset);
      ++n;
      offset = 0;
    } else {
      switch(c) {
        case '(':
          if(f) fputs("\\(", f);
          break;
        case ')':
          if(f) fputs("\\)", f);
          break;
        case '\\':
          if(f) fputs("\\\\", f);
          break;
        default:
         if(f) fputc(c, f);
      }
      ++n;
    }
    ++s;
  }
  return n;
}

/* ITEM H6 -- THE ONE /Link ANNOTATION fprintf IN THIS FILE, and it is one fprintf
 * because DD-2 says a rule two sites must agree on is written once, and because row
 * S65 of tests/headless/test_hier_pdf_links_1333.tcl counts the subtype literal in
 * this source and requires exactly ONE occurrence. Three callers now write a Link
 * annotation -- the symbol hotspot, the Back button and a parent reference -- and
 * they differ only in the keys between the /Rect and the subtype: a /Dest for the
 * two that go somewhere by name, a /Action for the one that goes back by history.
 *
 * It does NOT normalise the four numbers, and that is deliberate rather than an
 * omission. ps_link_pdfmark() emits in the page's own flipped user space, where the
 * CTM's negative y scale means the LARGER PostScript y becomes the SMALLER PDF y
 * (ruling DD-5, issue 1336); the nav strip emits before that CTM is established, in
 * plain page points, where it does not. One ordering rule applied to both would put
 * one of them upside down. Each caller hands in its own convention already ordered,
 * and rows S60/S61 and N5 assert the result on the PDF, which is the only place the
 * question has one answer. */
static void ps_annot_link(FILE *f, double llx, double lly, double urx, double ury,
                          const char *keys)
{
  fprintf(f,
    "[ "
    "/Rect [ %g %g %g %g ] "
    "%s"
    "/Subtype /Link "
    "/ANN pdfmark\n",
    llx, lly, urx, ury, keys);
}

static void ps_draw_string_line(int layer, char *s, double x, double y, double size,
           short rot, short flip, int lineno, double fontheight, double fontascent,
           double fontdescent, int llength, int no_of_lines, double longest_line)
{
  double ix, iy;
  short rot1;
  double line_delta;
  double lines;
  dbg(1, "ps_draw_string_line(): drawing |%s| on layer %d\n", s, layer);
  if(s==NULL) return;
  if(llength==0) return;
  fprintf(fd, "GS\n");
  set_ps_colors(layer);

  line_delta = lineno*fontheight;
  lines = (no_of_lines-1)*fontheight;

  ix=X_TO_PS(x);
  iy=Y_TO_PS(y);
  if(rot&1) {
    rot1=3;
  } else rot1=0;

  if(     rot==0 && flip==0) {iy+=line_delta+fontascent;}
  else if(rot==1 && flip==0) {ix=ix-fontheight+fontascent-lines+line_delta;}
  else if(rot==2 && flip==0) {iy=iy-fontheight-lines+line_delta+fontascent;}
  else if(rot==3 && flip==0) {ix+=line_delta+fontascent;}
  else if(rot==0 && flip==1) {iy+=line_delta+fontascent;}
  else if(rot==1 && flip==1) {ix=ix-fontheight+line_delta-lines+fontascent;}
  else if(rot==2 && flip==1) {iy=iy-fontheight-lines+line_delta+fontascent;}
  else if(rot==3 && flip==1) {ix+=line_delta+fontascent;}

  fprintf(fd, "/%s", ps_font_family);
  fprintf(fd, " FF\n");
  fprintf(fd, "%g SCF\n", size * xctx->mooz);
  fprintf(fd, "SF\n");
  fprintf(fd, "NP\n");
  fprintf(fd, "%g %g MT\n", ix, iy);
  if(rot1) fprintf(fd, "%d rotate\n", rot1*90);
  fprintf(fd, "1 -1 scale\n");
  fprintf(fd, "(");
  ps_string_body(fd, s);
  fprintf(fd, ")\n");
  if     (rot==1 && flip==0) {fprintf(fd, "dup SW pop neg 0 RMT\n");}
  else if(rot==2 && flip==0) {fprintf(fd, "dup SW pop neg 0 RMT\n");}
  else if(rot==0 && flip==1) {fprintf(fd, "dup SW pop neg 0 RMT\n");}
  else if(rot==3 && flip==1) {fprintf(fd, "dup SW pop neg 0 RMT\n");}

  fprintf(fd, "show\n");
  fprintf(fd, "GR\n");
}



static void ps_draw_string(int layer, const char *str, short rot, short flip, int hcenter, int vcenter,
                 double x,double y, double xscale, double yscale)
{
  char *tt, *ss, *sss=NULL;
  double textx1,textx2,texty1,texty2;
  char c;
  char *estr = NULL; /* expanded string: TABs replaced with spaces */
  int lineno=0;
  double size, height, ascent, descent;
  int llength=0, no_of_lines;
  double longest_line;

  if(str==NULL) return;
  size = xscale*53. * cairo_font_scale;
  height =  size*xctx->mooz * 1.147; /* was 1.147 */
  ascent =  size*xctx->mooz * 0.808; /* was 0.908 */
  descent = size*xctx->mooz * 0.219; /* was 0.219 */

  estr = my_expand(str, tclgetintvar("tabstop"));
  text_bbox(estr, xscale, yscale, rot, flip, hcenter, vcenter,
          x,y, &textx1,&texty1,&textx2,&texty2, &no_of_lines, &longest_line);

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
  llength=0;
  my_strdup2(_ALLOC_ID_, &sss, estr);
  tt=ss=sss;
  for(;;) {
    c=*ss;
    if(c=='\n' || c==0) {
      *ss='\0';
      ps_draw_string_line(layer, tt, x, y, size, rot, flip, lineno,
              height, ascent, descent, llength, no_of_lines, longest_line);
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

static void old_ps_draw_string(int gctext,  const char *str,
                 short rot, short flip, int hcenter, int vcenter,
                 double x1,double y1,
                 double xscale, double yscale)

{
 double a,yy,curr_x1,curr_y1,curr_x2,curr_y2,rx1,rx2,ry1,ry2;
 int pos=0,cc,pos2=0;
 int i, no_of_lines;
 double longest_line;
 char *estr = NULL;

 if(str==NULL) return;
 estr = my_expand(str, tclgetintvar("tabstop"));
 #if HAS_CAIRO==1
 text_bbox_nocairo(estr, xscale, yscale, rot, flip, hcenter, vcenter,
                   x1,y1, &rx1,&ry1,&rx2,&ry2, &no_of_lines, &longest_line);
 #else
 text_bbox(estr, xscale, yscale, rot, flip, hcenter, vcenter,
           x1,y1, &rx1,&ry1,&rx2,&ry2, &no_of_lines, &longest_line);
 #endif

 if(!textclip(xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2,rx1,ry1,rx2,ry2)) {
   my_free(_ALLOC_ID_, &estr);
   return;
 }
 xscale*=tclgetdoublevar("nocairo_font_xscale") * cairo_font_scale;
 yscale*=tclgetdoublevar("nocairo_font_yscale") * cairo_font_scale;
 set_ps_colors(gctext);
 x1=rx1;y1=ry1;
 if(rot&1) {y1=ry2;rot=3;}
 else rot=0;
 flip = 0; yy=y1;
 while(estr[pos2])
 {
  cc = (unsigned char)estr[pos2++];
  if(cc>127) cc= '?';
  if(cc=='\n')
  {
   yy+=(FONTHEIGHT+FONTDESCENT+FONTWHITESPACE)*
    yscale;
   pos=0;
   continue;
  }
  a = pos*(FONTWIDTH+FONTWHITESPACE);
  for(i=0;i<character[cc][0]*4;i+=4)
  {
   curr_x1 = ( character[cc][i+1]+ a ) * xscale + x1;
   curr_y1 = ( character[cc][i+2] ) * yscale+yy;
   curr_x2 = ( character[cc][i+3]+ a ) * xscale + x1;
   curr_y2 = ( character[cc][i+4] ) * yscale+yy;
   ROTATION(rot, flip, x1,y1,curr_x1,curr_y1,rx1,ry1);
   ROTATION(rot, flip, x1,y1,curr_x2,curr_y2,rx2,ry2);
   ORDER(rx1,ry1,rx2,ry2);
   ps_drawline(gctext,  rx1, ry1, rx2, ry2, 0, 0);
  }
  ++pos;
 }
 my_free(_ALLOC_ID_, &estr);
}

static void ps_drawgrid()
{
 double x,y;
 double delta,tmp;
 if( !tclgetboolvar("draw_grid")) return;
 delta=tclgetdoublevar("cadgrid")* xctx->mooz;
 while(delta<CADGRIDTHRESHOLD) delta*=CADGRIDMULTIPLY;  /* <-- to be improved,but works */
 x = xctx->xorigin* xctx->mooz;y = xctx->yorigin* xctx->mooz;
 set_ps_colors(GRIDLAYER);
 if(y>xctx->areay1 && y<xctx->areay2)
 {
  ps_xdrawline(GRIDLAYER,xctx->areax1+1,(int)y, xctx->areax2-1, (int)y);
 }
 if(x>xctx->areax1 && x<xctx->areax2)
 {
  ps_xdrawline(GRIDLAYER,(int)x,xctx->areay1+1, (int)x, xctx->areay2-1);
 }
 tmp = floor((xctx->areay1+1)/delta)*delta-fmod(-xctx->yorigin* xctx->mooz,delta);
 for(x=floor((xctx->areax1+1)/delta)*delta-fmod(-xctx->xorigin* xctx->mooz,delta);x<xctx->areax2;x+=delta)
 {
  for(y=tmp;y<xctx->areay2;y+=delta)
  {
   ps_xdrawpoint(GRIDLAYER,(int)(x), (int)(y));
  }
 }
}



/* THE ONE /Link pdfmark EMITTER. ps_draw_symbol() has to write this annotation from TWO
 * places -- the normal path, and the sub-3px branch that draws an instance as a blob and used
 * to return before ever reaching the normal path (ISSUE 1337) -- and DD-2 of
 * the op-wcard branch's doc/claude/hier_pdf_links_batch/DECISIONS.md forbids a second copy: two copies of a rule that
 * must agree IS issue 1334, the defect this batch exists to close. So there is exactly one
 * fprintf of a /Link pdfmark in this file and it is here. Item H2.
 *
 * The four tests below are the ones H1a/H1b measured into the call site, in this order, and
 * BOTH callers get all four: `type` guarded (1333), subcircuit OR primitive (1335), the
 * destination resolved from the INSTANCE via get_sch_from_sym() (route 4), and looked up in the
 * set of pages this export will actually contain (1334). Anything that reaches the fprintf has
 * passed all four.
 *
 * The rest of this comment is H1a's and H1b's, moved out of ps_draw_symbol() with their
 * emission and otherwise unchanged. It records why this site asks the one question it asks --
 * ruling DD-6. (Where it says "the local at the top of this function", that local now lives
 * here, in `type` below; it is the same field and the same guard.)
 *
 * ISSUE 1333 -- THE GUARD. `type` is xctx->sym[xctx->inst[n].ptr].type, i.e. the very value
 * this test used to dereference raw; in ps_draw_symbol() the same field is read as
 * nullable a few lines after it is loaded (`if( type &&
 * strcmp(type, "launcher") && ...`). So one reader of the field guarded it and this one
 * did not, and a symbol with no `type=` attribute segfaulted the ENTIRE hierarchical
 * export -- not one link, the whole document, mid-write. That symbol ships:
 * xschem_library/devices/bindkeys_cheatsheet.sym carries `K {}` with no type at all, it is
 * instantiated by intuitive_interface_cheatsheet.sch, and that in turn by the shipped
 * example xschem_library/examples/0_examples_top.sch, which died with
 *     EMERGENCY SAVE DIR: /tmp/xschem_emergencysave_intuitive_interface_cheatsheet_...
 *     FATAL: signal 11
 *     while editing: intuitive_interface_cheatsheet
 * on the binary before this line changed. Use the already-loaded local, guarded.
 *
 * ISSUE 1335 -- THE PRIMITIVE. hier_psprint() gives a page to `subcircuit` OR `primitive`
 * (spice_netlist.c:96); this emitter tested only `subcircuit`, so a primitive WITH a
 * schematic got a page that nothing linked to -- reachable only by scrolling the PDF.
 *
 * EXTENDING THE TYPE TEST ALONE IS NOT A FIX, AND THAT IS MEASURED. Most `type=primitive`
 * symbols have no schematic at all -- they are defined by their `format=` string (a
 * B-source, a macromodel subckt pulled from a file). The bare one-line extension put a
 * link on every one of them: the sweep over the 59 shipped examples caught five new dead
 * NAMES in eight annotations on three shipped sheets -- inv_bsource / an2 / nr2-1 / or2 on
 * flop.sch and sr_flop.sch, lm324 on test_lm324.sch -- none of which has a .sch anywhere.
 * A dead link IS issue 1334, so "fixing" 1335 by manufacturing eight instances of 1334 is
 * not a fix. H1a shipped an interim `stat` gate on the primitive arm for exactly this;
 * H1b's dest test below SUBSUMES it and the gate is gone, verified by measurement --
 * removing it changed no link on any of 75 sheets, because a primitive with no schematic
 * gets no page and therefore names no dest. That is why these two items are ONE commit:
 * the primitive arm without H1b's test ships the eight dead links above.
 *
 * ISSUE 1334 -- THE DEAD LINKS, and the ONE question this site is allowed to ask.
 * A link whose /Dest names no page in the document is a silent no-op click:
 * Ghostscript neither warns nor drops the annotation, so the PDF simply reads as
 * broken. Two earlier attempts suppressed those by RE-DERIVING hier_psprint()'s page
 * filter here -- type / noprint_libs / default_schematic read off the instance's BASE
 * symbol -- and both were refuted on that axis, because get_additional_symbols()
 * (actions.c:5451) MINTS a separate symbol for every instance-level `schematic=` and
 * deletes its default_schematic (actions.c:5583-5587), and it is the MINTED symbol
 * hier_psprint() pages. Reading one object while vetting the other fails in BOTH
 * directions, and it DELETED live links from shipped sheets
 * (xschem_library/examples/tb_test_evaluated_param.sch: 2 live links -> 0, both its
 * pages still printed). See ruling DD-6.
 *
 * So this site no longer asks "would that cell get a page?". It asks the question
 * that is true by construction -- "does this export CONTAIN a page of that name?" --
 * of hier_psprint_dest_exists(), whose set was built by the same walk that prints the
 * pages, keyed by the same get_cell_w_ext(sanitize(...)) call that mints the /DEST
 * anchor at psprint.c's `Add anchor for pdfmarks`. There is no second copy of the
 * filter to drift, and no way to ask about the wrong symbol object.
 *
 * It also SUBSUMES the primitive file test H1a needed here: a `type=primitive`
 * defined only by its `format=` string has no schematic, so hier_psprint() gives it
 * no page, so its name is not in the set. Same answer, one rule instead of two, and
 * this one is right for subcircuits too. (Measured: deleting that test changes no
 * link on any of 75 swept sheets.)
 *
 * The set is keyed on the flat /Dest basename because that is what a PDF destination
 * IS -- so two same-named cells from different libraries share one destination, and
 * if either gets a page the click really does navigate. The lookup therefore cannot
 * suppress a link that works; the failure it can have is keeping a link it might have
 * dropped, which is the safe side.
 *
 * ISSUE 1336 -- WHY THE FOUR NUMBERS COME OUT IN THIS ORDER, AND WHY THAT IS NOT COSMETIC.
 * PDF 32000-1 s12.5.2 defines /Rect as [lower-left-x lower-left-y upper-right-x upper-right-y].
 * s7.9.5 tells CONSUMERS to normalise a rectangle given the other way round, which is the only
 * reason Acrobat, poppler and pdf.js all worked on this file before H2: xschem was emitting
 *     /Rect [385.366 316.502 446.853 281.367]        <- lly 316.502 > ury 281.367
 * on every one of greycnt's 14 links. Out of spec, and dependent on reader leniency.
 *
 * The numbers handed in here are X_TO_PS()/Y_TO_PS() values, i.e. PostScript USER space, and
 * the annotation is transformed by the PAGE CTM the distiller reads out of create_ps()'s page
 * block below:
 *     -scale*bbox.x1+margin  ...  translate
 *     scale  -scale  scale                      <- see the `%g %g scale` fprintf in create_ps()
 * `scale` is (pagey - 2*margin)/dy or (pagex - 2*margin)/dx, which is POSITIVE for every page
 * size a user can plausibly ask for, so the y factor is NEGATIVE and the mapping is
 *     x' = tx + scale*x        (order preserving)
 *     y' = ty - scale*y        (order REVERSING)
 * Therefore the PDF's lower-left y is the image of the LARGER PostScript y, and its upper-right
 * y the image of the smaller. Hence lly = max(y1,y2) and ury = min(y1,y2) below, while x is
 * taken in the natural order. DD-5: that y flip is a fact about THIS CTM, not an invariant, so
 * the reordering is written against the CTM by name and it is asserted on the distilled PDF --
 * rows S60/S61/S62 of tests/headless/test_hier_pdf_links_1333.tcl -- never on the PostScript
 * byte order, which is inverted with respect to the page and correctly so.
 *
 * THE ONE CONFIGURATION WHERE THAT SIGN FLIPS IS ISSUE 1344, AND IT IS NOT FIXED HERE. `margin`
 * is a hardcoded 10, so a `ps_paper_size` with a dimension of 20 pt or less makes `scale`
 * NEGATIVE and create_ps() emits e.g. `-0.0141243 0.0141243 scale` -- negative x, POSITIVE y.
 * In that configuration the reordering below inverts the y pair instead of normalising it, i.e.
 * it is worse than the pre-change binary (measured: 12/12 y-inverted after, 0/12 before). The
 * whole page is drawn mirrored on the unchanged binary in that configuration, annotations or
 * not, so 1344 is the page-scale defect and this reordering is downstream of it. No row here
 * varies `ps_paper_size`, so S60/S61/S62 cannot see it -- said out loud because the crew's
 * receipt claimed the S60/S62 pair would catch a positive y CTM and it does not.
 *
 * min/max rather than a bare swap because nothing here promises x1<=x2 and y1<=y2; today
 * symbol_bbox() does deliver them ordered, so on every measured sheet this is exactly the old
 * four numbers reordered and no value moves (measured over 76 sheets, rect-value multisets
 * identical).
 *
 * ISSUE 1337 -- the caller in the sub-3px branch passes THE SAME BOX the normal path passes,
 * inst.x1..y2, not the inst.xx1..yy2 body box ps_filledrect() draws the blob from. Two reasons:
 * there is one rect rule in this file rather than two, which is what lets H3 switch it in one
 * place when it ships `ps_link_bbox` (issue 1339); and select.c:730-778 builds x1..y2 by
 * storing the body box and THEN unioning every symbol text into it, so x1..y2 strictly contains
 * the blob and the annotation covers what was drawn. At the zoom that triggers the small branch
 * the body box is a fraction of a point across, so the text-inflated box is also the only one
 * with a hotspot a reviewer could hit. Row S64 asserts the containment on the PDF. */
static void ps_link_pdfmark(FILE *fd, int n, int what, double x1, double y1, double x2, double y2)
{
  const char *bbox_pref;
  const char *border;
  const char *d;
  char dest[PATH_MAX];
  char keys[PATH_MAX + 96];
  double llx, lly, urx, ury;

  if(what == 7) return;                 /* single-page `xschem print` emits no pdfmarks */
  /* ITEM H4 moved the FIRST THREE of those four tests -- the `type` guard (1333), the
   * subcircuit-or-primitive test (1335) and the instance-resolved destination name -- into
   * hier_psprint_inst_dest() in spice_netlist.c, unchanged and in the same order. They are
   * shared, not duplicated: the collect pass needs the very same "what would this instance's
   * link name?" answer to decide which pages are worth descending into (RULE-1, condition A),
   * and DD-2's rule is that a test two sites must agree on is written once. If they drifted,
   * the emitter would link one cell while the scope reasoned about another -- which is DD-6's
   * base-vs-minted confusion in a new costume. */
  d = hier_psprint_inst_dest(n);
  if(!d) return;                                                 /* issues 1333 and 1335 */
  my_strncpy(dest, d, S(dest));
  if(!hier_psprint_dest_exists(dest)) return;                           /* issue 1334 */

  /* ISSUE 1339 -- WHICH BOX THE HOTSPOT IS, and why it is a preference rather than a fix.
   * The four numbers handed in are inst.x1..y2, which symbol_bbox() builds by storing the
   * symbol's drawn body box into inst.xx1..yy2 (select.c:730-740; sym->minx..maxy EXCLUDE
   * symbol text, actions.c:2528) and THEN unioning every EXPANDED symbol text into x1..y2
   * (select.c:742-778). `@name` is one of those texts, so the clickable area of a cell grows
   * with the instance name a user happened to type: measured on two instances of one symbol,
   * `name=x1` gave a 51.6 pt link rect and `name=xLONGLONGLONGLONGNAME` a 269.3 pt one. On a
   * dense sheet that gives overlapping hotspots. It is also internally inconsistent: the
   * sub-3px branch a few lines below draws its blob from inst.xx1..yy2 while the link it emits
   * covers x1..y2. `ps_link_bbox body` takes the body box instead.
   *
   * DD-4: the DEFAULT IS `full`, which is exactly today's behaviour, and it stays `full` until
   * the user rules (RULE-2). tclgetvar() returns NULL for an unset variable, and NULL takes
   * the default path -- so this file landing without src/xschem.tcl's `set_ne` line changes no
   * output. Row S76.
   *
   * THE SWITCH IS HERE, INSIDE THE ONE EMITTER, NOT AT EITHER CALL SITE. Both callers pass the
   * text-inflated box; doing this at the normal call site would silently leave the sub-3px
   * branch on the old box (H2's sabotage variant E is that mistake). Row S75.
   *
   * AND IT DOES NOT FIRE ON A DEGENERATE BODY -- WHERE "DEGENERATE" MEANS NO AREA, NOT NO
   * EXTENT, AND THE DIFFERENCE IS THE WHOLE OF THIS PARAGRAPH. `body` is a request for a
   * SMALLER hotspot, never for a missing one: "this batch removes no link from any sheet" is
   * the control every item in it has been judged on, and an unclickable zero-area rect is a
   * removed link wearing an annotation. Two shapes reach that:
   *
   *   - no graphics but WITH text: xx1==xx2 AND yy1==yy2, while the text-inflated box is
   *     perfectly good. A symbol drawn entirely out of text IS its text.
   *   - graphics that collapse to ONE axis plus text -- a bare vertical or horizontal line.
   *     xx1==xx2 XOR yy1==yy2. This one was SHIPPED BROKEN in H3's first draft, whose test
   *     was `bx1 != bx2 || by1 != by2` -- "has an extent". A vline passed that test, took the
   *     body box, and produced `/Rect [15 692.488 15 663.271]`: 0.000 x 29.217 pt, no
   *     interior, unclickable in every viewer, and NOT caught by the guard below because that
   *     one is deliberately AND (a fully degenerate rect) for reasons of its own. Measured on
   *     an hline too: 43.825 x 0.000 pt. The item's own LINKS-LOST control read zero the whole
   *     time, because the annotation is still emitted -- it is just dead.
   *
   * So the body box is used only when it has AREA, and either degeneracy falls back to the
   * text-inflated box. Row S74. A symbol with neither graphics nor text is degenerate either
   * way and still gets no link, which is S66 unchanged.
   *
   * Scanned to be sure the fallback is not load-bearing on real work: of 2436 `.sym` files in
   * xschem_library and the sky130 libraries, ZERO are bodyless-but-texted and ZERO are
   * one-axis degenerate, and a 325-sheet `body` sweep is byte-identical with and without this
   * test. It fences a shape a user can draw, not one that ships. */
  bbox_pref = tclgetvar("ps_link_bbox");
  if(bbox_pref && !strcmp(bbox_pref, "body")) {
    double bx1, by1, bx2, by2;
    bx1 = X_TO_PS(xctx->inst[n].xx1);
    bx2 = X_TO_PS(xctx->inst[n].xx2);
    by1 = Y_TO_PS(xctx->inst[n].yy1);
    by2 = Y_TO_PS(xctx->inst[n].yy2);
    if(bx1 != bx2 && by1 != by2) {   /* AREA, not extent -- see above; `||` here ships a dead link */
      x1 = bx1; y1 = by1; x2 = bx2; y2 = by2;
    }
  }

  llx = (x1 <= x2) ? x1 : x2;
  urx = (x1 <= x2) ? x2 : x1;
  lly = (y1 >= y2) ? y1 : y2;   /* the LARGER PostScript y is the SMALLER PDF y: see above */
  ury = (y1 >= y2) ? y2 : y1;

  /* A ZERO-AREA ANNOTATION IS NOT A LINK, and issue 1337's new call site is the only thing
   * that can produce one. A `type=subcircuit` symbol with no graphics and no text has
   * inst.x1==x2 and y1==y2, so it is ALWAYS under the 3-px floor and the pre-1337 binary
   * returned before ever reaching this emitter -- there was no link to lose. Now there is a
   * call, and without this test it writes `/Rect [ 985 611.062 985 611.062 ]`: a rect with no
   * interior, unclickable in every viewer, and a violation of the very llx<urx && lly<ury
   * property rows S60/S61 assert two lines from here. Row S66 fences it.
   *
   * The test is deliberately AND, not OR. A symbol that is zero-WIDE but tall -- a bare
   * vertical line, no text -- clears the 3-px floor on its y extent, takes the normal path,
   * and got a (zero-width, spec-legal, merely empty) link from the pre-change binary too.
   * `||` here would delete that link, and "H2 removes no link from any sheet" is this item's
   * whole control. So only the fully degenerate case, which is exactly the case 1337 created. */
  if(llx == urx && lly == ury) return;

  /* ISSUE 1338 -- A LINK NOBODY CAN SEE. The third element of /Border is the border WIDTH
   * (PDF 32000-1 s12.5.4), so the `[0 0 0]` xschem has always written draws nothing: a reviewer
   * opening a hierarchical export has no cue that any symbol on the sheet is clickable, and
   * finds out only by moving the pointer over one. At `ps_link_border 1` the annotation gets
   * `/Border [0 0 1] /C [0 0 1]` -- a solid 1-unit-wide rectangle on the /Rect, coloured in
   * DeviceRGB blue. Row S71 asserts both keys on the distilled PDF.
   *
   * DD-4: the DEFAULT IS 0, byte-for-byte today's annotation -- the branch substitutes the
   * literal string "/Border [0 0 0] " that used to be in the format -- and it stays 0 until the
   * user rules (RULE-1, which needs eyes on a real sheet: a green suite cannot say whether a
   * blue box on every subcircuit helps a reviewer or clutters the page). Row S70.
   *
   * ONE fprintf, not two: DD-2's rule is that this file emits the Link annotation from exactly
   * one place, and row S65 asserts it STATICALLY -- by counting the subtype literal in this
   * source -- because a second copy that happens to agree passes every behavioural row. Hence a
   * string substitution rather than an if/else over two fprintf()s. (That row caught this very
   * comment when it quoted the literal, which is the row doing its job.)
   *
   * ITEM H4 -- RULE-1, AND THE FIRST DEFAULT IN THIS BATCH THAT CHANGES A USER'S OUTPUT. H3
   * shipped the border at 0, invisible, PENDING A RULING, and the user ruled on 2026-09-10:
   *     "Only a symbol for a non-PDK cell that has real hierarchy (worth descending into)
   *      should have the clickable link highlight in the PDF"
   * So `ps_link_border` is now three states -- `none` (H3's shipped behaviour and the way
   * back), `hier` (the ruling, THE NEW DEFAULT), `all` (H3's `ps_link_border 1`) -- and `0`
   * and `1` still parse as `none` and `all`, so an xschemrc written against H3 keeps its
   * meaning.
   *
   * The decision is NOT made here. Which links are advertised is a question about the
   * DOCUMENT -- does the target page have a paged child, and is it in an excluded library --
   * and the only thing that knows the document is the walk that builds it. So the scope lives
   * beside that walk, in spice_netlist.c, and this site does a hash lookup. Two consequences
   * worth writing down: there is ONE copy of the rule (DD-2), and this line no longer calls
   * Tcl at all, so the per-link Tcl round trips issue 1346 complains about go from two to one
   * (`ps_link_bbox` above is still read per link; that is 1346's, untouched here).
   *
   * DD-4's byte-identity control DOES NOT APPLY TO THIS ITEM and no row should pretend it
   * does -- a default that changes the output is the point. What still holds, and what every
   * H4 row asserts, is that the LINK set and the PAGE set do not move: the ruling scopes the
   * highlight, never the link. Dropping the unadvertised links would recreate issue 1335 and
   * break H1b's link-iff-page invariant, which is the control every item in this batch has
   * been judged on. */
  border = hier_psprint_link_border(dest);

  /* ITEM H6 moved the fprintf itself into ps_annot_link() -- the Back button and the parent
   * references above the drawing area are Link annotations too, and DD-2 (and row S65) allow
   * exactly one emission of the subtype literal in this file. What differs between the three
   * is only the keys, so that is what each caller builds. */
  my_snprintf(keys, S(keys), "%s/Dest /%s ", border, ps_name_token(dest)); /* issue 1352 */
  ps_annot_link(fd, llx, lly, urx, ury, keys);
}

/* ITEM H6 -- THE PAGE NAVIGATION STRIP.  The half of the user's original request that was
 * never built:
 *
 *     "How difficult to add references on a child cell to have links to parent schematics?"
 *     "did we succeed in putting Back buttons? I know Alt-Left is a back button, but a
 *      clickable button means user can keep one hand on the mouse"
 *
 * Two things, because they answer different questions, and both are wanted:
 *
 *   THE BACK BUTTON is a PDF NAMED ACTION, `/Action << /S /Named /N /GoBack >>`, which
 *     Ghostscript distils to `/A<</S/Named /N/GoBack>>`. It is the viewer's own history
 *     Back -- the same operation Alt-Left performs in a viewer that implements it -- so it
 *     returns the reader wherever they came FROM with
 *     no knowledge of the hierarchy. ⚠ THAT IS ALSO ITS LIMIT, AND IT IS NOT HIDDEN: a
 *     reader who SCROLLED to this page rather than clicking into it gets sent back to
 *     wherever they scrolled from, or nowhere. It is a button for the flow the user
 *     described -- click into a cell, look, come back -- and nothing more.
 *   THE PARENT REFERENCE is structural and answers the other question: which sheet contains
 *     this cell, however the reader arrived. It is a LIST because a cell instantiated in
 *     five places has five parents -- measured on the user's own design, sky130_tests_ase/
 *     tb_bandgap, where `not` is instantiated in `bandgap` AND in `bandgap_opamp`. The TOP
 *     page has no parent and shows no `Up:` line; a page reached through an instance-level
 *     `schematic=` override names the OVERRIDING sheet, because the edge is minted from the
 *     instance (hier_psprint_inst_dest(), ruling DD-6); a truly recursive cell names itself.
 *
 * WHERE IT SITS, AND WHY THAT IS A PROOF RATHER THAN A HOPE. create_ps() draws the page
 * inside `margin` (10 pt): the translate below puts the top of the drawing at
 * pagey - (scaley-scale)*dy - margin, and (scaley-scale)*dy is never negative, so NO part of
 * the drawing -- and therefore no symbol hotspot -- can reach above pagey - margin. The strip
 * is emitted BEFORE that translate, so it is in plain page points, and it lives entirely in
 * that band. A reviewer clicking a symbol cannot hit the Back button, and the suite proves it
 * by intersecting the two rect sets on the distilled PDF rather than by repeating this
 * paragraph (rows N6 and N7). The strip does NOT reserve space by shrinking the drawing:
 * that would move every link rect on every page and break DD-3's control.
 *
 * COURIER, AND THAT IS THE ONE PLACE THIS FUNCTION IS OPINIONATED ABOUT TYPE. Every Courier
 * glyph advances exactly 0.6 em, so a rect computed as glyphs x 0.6 x size matches the ink to
 * the point with no font-metric table in this file. In Helvetica it would need one, and a
 * guess would give a hotspot that does not line up with the words under it.
 *
 * The strip is drawn only when a hierarchical print owns a destination set -- the same gate
 * the /Link emitter uses -- so a single-page `xschem print` is untouched (row N16). */
static void ps_hier_nav_strip(FILE *f, const char *pagedest,
                              double pagex, double pagey, double margin)
{
  const double fs = 7.0;          /* Courier 7 pt: 3.9 pt of cap in a 10 pt band */
  const double cw = 4.2;          /* 0.6 em, exactly, for every Courier glyph */
  const char *lc, *tc;
  const char *parents;
  const char *p;
  double x, base, ry0, ry1, right, bw, reserve = 0.0;
  int mode, total = 0, drawn = 0;
  char buf[PATH_MAX];
  char keys[PATH_MAX + 96];
  char cnt[32];

  mode = hier_psprint_nav_mode();
  if(mode == 0) return;
  /* THE BAND HAS TO EXIST. `margin` is 0 when create_ps() sets the media size to the drawing
   * bbox (fullzoom == 2), and then there is no free band and the small page title is skipped
   * too. The page-size guards are issue 1354's rule applied to this function's own sinks:
   * ps_paper_size comes from Tcl through my_atod(), so pagex/pagey can be nan, inf or 1e40,
   * and every number below is derived from them. !(x > 0) is false for nan. */
  if(!(margin >= 8.0) || !(pagey > 60.0) || !(pagex > 140.0)) return;
  if(pagey > 1.0e5 || pagex > 1.0e5) return;

  parents = hier_psprint_page_parents(pagedest);
  if(!(mode & 1) && (!(mode & 2) || !parents)) return;

  /* a monochrome print asked for no colour; the drawn box and underline are then the whole
   * cue, which is the same trade `color_ps 0` makes everywhere else in this file. */
  if(tclgetboolvar("color_ps")) { lc = "0 0 0.55 RGB"; tc = "0 0 0 RGB"; }
  else                          { lc = "0 0 0 RGB";    tc = "0 0 0 RGB"; }

  ry0   = pagey - margin + 0.4;
  ry1   = pagey - 0.4;
  base  = pagey - margin + 3.0;
  x     = margin + 10.0;                 /* the small page title's own indent */
  right = pagex - margin - 4.0;

  fprintf(f, "%% xschem hier nav begin\n");
  fprintf(f, "GS\n0.4 setlinewidth\n/Courier FF %g SCF SF\n", fs);
  if(mode & 1) {
    bw = 6.0 * cw + 6.0;                 /* "< Back", 3 pt of padding each side */
    fprintf(f, "%s\nNP %g %g MT (< Back) show\n", lc, x + 3.0, base);
    fprintf(f, "NP %g %g %g %g R\n", x, ry0, bw, ry1 - ry0);
    my_snprintf(keys, S(keys),
      "/Border [0 0 0] /F 4 /Action << /S /Named /N /GoBack >> ");
    ps_annot_link(f, x, ry0, x + bw, ry1, keys);
    x += bw + 10.0;
  }
  if((mode & 2) && parents) {
    for(p = parents; *p; ) {
      const char *e = strchr(p, '\n');
      ++total;
      if(!e) break;
      p = e + 1;
    }
    fprintf(f, "%s\nNP %g %g MT (Up: ) show\n", tc, x, base);
    x += 4.0 * cw;
    /* RESERVE THE `+N` COUNT'S WIDTH BEFORE DRAWING, NOT AFTER. `+N` used to be emitted at
     * whatever x the loop happened to stop at, with no right-margin test of its own -- every
     * NAME was bounded and the COUNT was not. On a page whose last drawn parent ends just
     * short of `right`, the count is then drawn past the page edge and CLIPPED by the media
     * box, so `+32` renders as `+3`: a readable, believable, wrong number, which is worse
     * than no number at all and is exactly what the truncation exists to prevent. Measured
     * by this batch's adversary on a 50-parent fixture: ink to 846.6 pt on an 842 pt page,
     * `+32` shown as `+3`.
     *
     * A post-hoc clamp is NOT the fix and was measured too: pulling the count back inside the
     * margin lands it on top of the last name's ink. The width has to be taken out of the
     * budget the names are fitted against, and only while more entries remain -- if every
     * remaining name fits there is no count to draw. `total` bounds the printed value, so
     * its own decimal width is knowable before the loop runs. The cost is at most one fewer
     * name drawn on a page that was going to truncate anyway. */
    my_snprintf(cnt, S(cnt), "+%d", total);
    reserve = cw * (double) strlen(cnt) + 2.0 * cw;
    for(p = parents; *p; ) {
      const char *e = strchr(p, '\n');
      size_t len = e ? (size_t)(e - p) : strlen(p);
      double w;
      if(len >= sizeof(buf)) len = sizeof(buf) - 1;
      memcpy(buf, p, len);
      buf[len] = '\0';
      w = cw * (double) ps_string_body(NULL, buf);   /* GLYPHS, not bytes -- row N20 */
      /* Stop at the right margin rather than running off the page, and say how many were
       * not drawn: a silently truncated list is a lie about the hierarchy -- and so is a
       * truncation count that does not fit on the page, which is why `reserve` is in this
       * test whenever another entry follows. */
      if(x + w + (e ? reserve : 0.0) > right) break;
      if(hier_psprint_dest_exists(buf)) {            /* issue 1334, asked backwards */
        fprintf(f, "%s\nNP %g %g MT (", lc, x, base);
        ps_string_body(f, buf);
        fprintf(f, ") show\n");
        fprintf(f, "NP %g %g %g %g L\n", x, base - 1.6, x + w, base - 1.6);
        my_snprintf(keys, S(keys), "/Border [0 0 0] /F 4 /Dest /%s ", ps_name_token(buf));
        ps_annot_link(f, x, ry0, x + w, ry1, keys);
        x += w + 2.0 * cw;
        ++drawn;
      }
      if(!e) break;
      p = e + 1;
    }
    if(drawn < total) fprintf(f, "%s\nNP %g %g MT (+%d) show\n", tc, x, base, total - drawn);
  }
  fprintf(f, "GR\n");
  fprintf(f, "%% xschem hier nav end\n");
}

static void ps_draw_symbol(int c, int n,int layer, int what, short tmp_flip, short rot,
        double xoffset, double yoffset)
                            /* draws current layer only, should be called within  */
{                           /* a "for(i=0;i<cadlayers; ++i)" loop */
  int j, hide = 0, disabled = 0;
  double x0,y0,x1,y1,x2,y2;
  short flip;
  int textlayer;
  xLine *line;
  xRect *rect;
  xText text;
  xArc *arc;
  xPoly *polygon;
  xSymbol *symptr;
  char *type;
  int lvs_ignore = 0;
  char *textfont;
  int c_for_text;

  /* issue 0498: guard BEFORE the dereference, not after. The `ptr == -1` test that used to
   * sit below these lines was written to prevent exactly the xctx->sym[-1] read the next
   * line performs; upstream commit 40fd937d hoisted the `type =` assignment above it and
   * silently disarmed it. draw.c draw_temp_symbol() is the correct in-tree ordering. */
  if(INST_UNBOUND(n)) return;
  type = xctx->sym[xctx->inst[n].ptr].type;
  lvs_ignore=tclgetboolvar("lvs_ignore");
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
    disabled = 2;
  }
  else if(xctx->inst[n].flags & IGNORE_INST) {
    c = GRIDLAYER;
    disabled = 1;
  }
  if(xctx->inst[n].color != -10000) c = get_color(xctx->inst[n].color);

  if( (xctx->inst[n].flags & HIDE_INST) || ((xctx->inst[n].ptr + xctx->sym)->flags & HIDE_INST) ||
      ((xctx->hide_symbols==1 && (xctx->inst[n].ptr + xctx->sym)->type &&
      !strcmp( (xctx->inst[n].ptr+ xctx->sym)->type, "subcircuit") )) ||
      (xctx->hide_symbols == 2) ) {
    hide = 1;
  } else {
    hide = 0;
  }
  if(layer==0)
  {
    x1=X_TO_PS(xctx->inst[n].x1);
    x2=X_TO_PS(xctx->inst[n].x2);
    y1=Y_TO_PS(xctx->inst[n].y1);
    y2=Y_TO_PS(xctx->inst[n].y2);
    if(RECT_OUTSIDE(x1,y1,x2,y2,xctx->areax1,xctx->areay1,xctx->areax2,xctx->areay2))
    {
      xctx->inst[n].flags|=1;
      return;
    }
    #if 0
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
    #endif
    else if((xctx->inst[n].x2 - xctx->inst[n].x1) * xctx->mooz < 3 &&
                       (xctx->inst[n].y2 - xctx->inst[n].y1) * xctx->mooz < 3) {
      /* ISSUE 1337. The instance is too small to draw, so it becomes a blob and nothing else on
       * this sheet is emitted for it -- but it is still THERE, it still has a bounding box, and
       * on a dense top-level sheet the small subcircuit instances are precisely the ones a
       * reviewer needs to click through. This `return` used to be reached BEFORE the pdfmark
       * block, so all of them silently lost their link. Emit it here, from the same one emitter
       * the normal path uses (ps_link_pdfmark(), above -- DD-2 forbids a second copy), and only
       * THEN return.
       * The sibling `RECT_OUTSIDE(...) return;` above is CORRECT and is deliberately left alone:
       * an instance entirely off the page must get no link. (Measured with an instrumented
       * build: under hier_psprint() that branch never fires at all, because ps_draw(2,
       * fullzoom=1) zoom_full()s every page at 0.97 fill. Row S65 fences it statically for the
       * same reason.) */
      set_ps_colors(SYMLAYER);
      ps_filledrect(SYMLAYER, xctx->inst[n].xx1, xctx->inst[n].yy1, xctx->inst[n].xx2, xctx->inst[n].yy2,
                   0.0,  0, 0, -1, -1);
      xctx->inst[n].flags|=1;
      ps_link_pdfmark(fd, n, what, x1, y1, x2, y2);
      return;
    }
    else {
      xctx->inst[n].flags&=~1;
    }
    if(hide) {
      int color = (disabled==1) ? GRIDLAYER : (disabled == 2) ? PINLAYER : SYMLAYER;
      set_ps_colors(color);
      ps_filledrect(color, xctx->inst[n].xx1, xctx->inst[n].yy1, xctx->inst[n].xx2, xctx->inst[n].yy2,
                    0.0, 2, 0, -1, -1);
    }
    /* ISSUE 1337: the ONE /Link emitter, see ps_link_pdfmark() above. It is called from
     * exactly two places -- here, and from the sub-3px branch a few lines up, which used to
     * `return` before ever reaching this point. */
    ps_link_pdfmark(fd, n, what, x1, y1, x2, y2);
  }
  else if(xctx->inst[n].flags&1)
  {
   dbg(1, "ps_draw_symbol(): skipping inst %d\n", n);
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
    if(symptr->lines[layer] || symptr->polygons[layer] || symptr->arcs[layer]) {
      set_ps_colors(c);
    }
    for(j=0;j< symptr->lines[layer]; ++j)
    {
     int dash;
     line =  &(symptr->line[layer])[j];
     dash = (disabled == 1) ? 3 : line->dash;
     ROTATION(rot, flip, 0.0,0.0,line->x1,line->y1,x1,y1);
     ROTATION(rot, flip, 0.0,0.0,line->x2,line->y2,x2,y2);
     ORDER(x1,y1,x2,y2);
     ps_drawline(c, x0+x1, y0+y1, x0+x2, y0+y2, dash, line->bus);
    }
    for(j=0;j< symptr->polygons[layer]; ++j)
    {
      int dash;
      int bezier;
      polygon = &(symptr->poly[layer])[j];
      bezier = !strboolcmp(get_tok_value(polygon->prop_ptr, "bezier", 0), "true");
      dash = (disabled == 1) ? 3 : polygon->dash;
      {   /* scope block so we declare some auxiliary arrays for coord transforms. 20171115 */
        int k;
        double *x = my_malloc(_ALLOC_ID_, sizeof(double) * polygon->points);
        double *y = my_malloc(_ALLOC_ID_, sizeof(double) * polygon->points);
        for(k=0;k<polygon->points; ++k) {
          ROTATION(rot, flip, 0.0,0.0,polygon->x[k],polygon->y[k],x[k],y[k]);
          x[k]+= x0;
          y[k] += y0;
        }
        ps_drawpolygon(c, NOW, x, y, polygon->points, polygon->fill, dash, bezier, polygon->bus);
        my_free(_ALLOC_ID_, &x);
        my_free(_ALLOC_ID_, &y);
      }
    }
    if(symptr->arcs[layer]) fprintf(fd, "NP\n"); /* newpath */
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
      ROTATION(rot, flip, 0.0,0.0,arc->x,arc->y,x1,y1);
      ps_drawarc(c, arc->fill, x0+x1, y0+y1, arc->r, angle, arc->b, arc->bus, dash);
    }
  } /* if(!hide) */

  if( (!hide && xctx->enable_layer[layer]) ||
      (hide && layer == PINLAYER && xctx->enable_layer[layer]) ) {
    if(symptr->rects[layer]) {
      fprintf(fd, "NP\n"); /* newpath */
      set_ps_colors(c);
    }

    for(j=0;j< symptr->rects[layer]; ++j)
    {
       int dash;
       rect = &(symptr->rect[layer])[j];
       dash = (disabled == 1) ? 3 : rect->dash;
       ROTATION(rot, flip, 0.0,0.0,rect->x1,rect->y1,x1,y1);
       ROTATION(rot, flip, 0.0,0.0,rect->x2,rect->y2,x2,y2);
       RECTORDER(x1,y1,x2,y2);
       if (layer == GRIDLAYER && rect->flags & 1024) /* image */
       {
         ps_embedded_image(rect, x0 + x1, y0 + y1, x0 + x2, y0 + y2, rot, flip);
       } else {
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
         ps_filledrect(c, x0+x1, y0+y1, x0+x2, y0+y2, rect->bus, dash, rect->fill, ellipse_a, ellipse_b);
       }
    }
  } /* if( (!hide && xctx->enable_layer[layer]) || ... */

  draw_texts:
  if(xctx->sym_txt && !(xctx->inst[n].flags & HIDE_SYMBOL_TEXTS) && (layer == cadlayers)) {
    const char *txtptr;
    if(c != layer) c_for_text = c;
    else if(xctx->inst[n].flags & PIN_OR_LABEL) c_for_text = TEXTWIRELAYER;
    else c_for_text = TEXTLAYER;
    for(j=0;j< (xctx->inst[n].ptr+ xctx->sym)->texts; ++j)
    {
      double xscale, yscale;

      get_sym_text_size(n, j, &xscale, &yscale);
      text = symptr->text[j];
      /* if(xscale*FONTWIDTH* xctx->mooz<1) continue; */
      if(text_hidden_inst(text.flags, n)) continue;
      /* 1249: ONE keep-name predicate for all three back ends (invariant I1). The
       * three byte-identical strcmp pairs this replaces missed `@spiceprefix@name`,
       * so at hide_symbols=2 gf180's whole FET family lost its names. */
      if( hide && text.txt_ptr && !annot_name_token(text.txt_ptr) ) continue;
      txtptr= translate(n, text.txt_ptr);
      ROTATION(rot, flip, 0.0,0.0,text.x0,text.y0,x1,y1);
      textlayer = c_for_text;
      /* do not allow custom text color on hilighted instances */
      if(disabled == 1) textlayer = GRIDLAYER;
      else if(disabled == 2) textlayer = PINLAYER;
      else if( xctx->inst[n].color == -10000) {
        int lay, alay;
        get_sym_text_layer(n, j, &lay);
        /* 0615: see the identical site in draw.c. THIS BACK END IS THE ONE A PARTIAL
         * FIX LEAVES OUT (0615's sharpest landmine: "an override in draw.c alone means
         * the schematic on screen and the exported PDF disagree"). Only the VALUE of
         * `textlayer` moves -- no new set_ps_colors call is added, so the existing
         * push below and its asymmetric pop (issue 0619) are neither fixed nor
         * deepened here. */
        if(lay != -1) textlayer = lay;
        else if((alay = annot_text_layer(text.flags, TEXT_CTX_INSTANCE)) != -1) textlayer = alay;
        else textlayer = symptr->text[j].layer;
      }
      if(textlayer < 0 || textlayer >= cadlayers) textlayer = c_for_text;
      if(textlayer != c_for_text) set_ps_colors(textlayer);

       /* display PINLAYER colored instance texts even if PINLAYER disabled */
      if(xctx->inst[n].color == -PINLAYER || xctx->enable_layer[textlayer]) {
        my_snprintf(ps_font_family, S(ps_font_name), "Helvetica");
        my_snprintf(ps_font_name, S(ps_font_name), "Helvetica");
        textfont = symptr->text[j].font;
        if( (textfont && textfont[0])) {                              /* issue 1351 */
          my_snprintf(ps_font_family, S(ps_font_family), "%s", ps_font_token(textfont));
          my_snprintf(ps_font_name, S(ps_font_name), "%s", ps_font_token(textfont));
        }
        if( symptr->text[j].flags & TEXT_BOLD) {
          if( (symptr->text[j].flags & TEXT_ITALIC) || (symptr->text[j].flags & TEXT_OBLIQUE) ) {
            my_snprintf(ps_font_family, S(ps_font_family), "%s-BoldOblique", ps_font_name);
          } else {
            my_snprintf(ps_font_family, S(ps_font_family), "%s-Bold", ps_font_name);
          }
        }
        else if( symptr->text[j].flags & TEXT_ITALIC)
          my_snprintf(ps_font_family, S(ps_font_family), "%s-Oblique", ps_font_name);
        else if( symptr->text[j].flags & TEXT_OBLIQUE)
          my_snprintf(ps_font_family, S(ps_font_family), "%s-Oblique", ps_font_name);
        if(text_ps) {
          ps_draw_string(textlayer, txtptr,
            (text.rot + ( (flip && (text.rot & 1) ) ? rot+2 : rot) ) & 0x3,
            flip^text.flip, text.hcenter, text.vcenter,
            x0+x1, y0+y1, xscale, yscale);
        } else {
          old_ps_draw_string(textlayer, txtptr,
            (text.rot + ( (flip && (text.rot & 1) ) ? rot+2 : rot) ) & 0x3,
            flip^text.flip, text.hcenter, text.vcenter,
            x0+x1, y0+y1, xscale, yscale);
        }
      }
      if(textlayer != c) set_ps_colors(c);
    }

    /* P6 (doc/claude/specs/cadence_pin_name_text.md §4.2): pin names from the symbol's pin
     * tokens -- PostScript/PDF export mirror of the draw.c draw_symbol pass.
     *
     * 1253 (item A5-b) / RULING D-1, in the user's own words: "even pin labels can be
     * hidden when user is hiding other things that are not @name. We are only
     * interested in name and annotation of OP info." The declutter's rung lives in
     * text_hidden(), which gates the loop over a SYMBOL's text[] records -- this pass
     * walks symptr->rect[PINLAYER] instead, so the rung never saw it and a symbol
     * spelling show_pinname=true kept its pin names on a fully decluttered device, in
     * all three back ends. Hence the guard below. It is the SHARED instance-aware
     * predicate, not a pin-specific one -- a fourth gate would be exactly the drift
     * invariant I1 forbids -- and flags 0 carries no annotation class and no explicit
     * hide= bit, so the call falls straight through to the declutter rung and returns 0
     * whenever the bit is clear. It sits immediately after pin_name_visible() and
     * BEFORE get_pin_name_layout(), so the pnm/pfont malloc/free pair is never reached
     * for a pin the declutter hides, and it is byte-identical in draw.c, svgdraw.c and
     * psprint.c. Rows A36..A39 of tests/headless/test_annot_declutter_1244.tcl. */
    if(!hide) for(j = 0; j < symptr->rects[PINLAYER]; ++j) {
      xRect *pin = &(symptr->rect[PINLAYER])[j];
      Pin_name_layout lay;
      char *pnm = NULL, *pfont = NULL;
      double pcx, pcy, tx, ty;
      int plw;
      if(!pin_name_visible(pin->prop_ptr)) continue;
      if(text_hidden_inst(0, n)) continue;    /* 1253 / D-1, see above */
      if(!get_pin_name_layout(pin->prop_ptr, &lay, &pnm, &pfont)) continue;
      plw = c_for_text;
      if(disabled == 1) plw = GRIDLAYER;
      else if(disabled == 2) plw = PINLAYER;
      if(plw < 0 || plw >= cadlayers) plw = c_for_text;
      if(plw != c_for_text) set_ps_colors(plw);
      if(xctx->inst[n].color == -PINLAYER || xctx->enable_layer[plw]) {
        pcx = (pin->x1 + pin->x2) / 2.0;
        pcy = (pin->y1 + pin->y2) / 2.0;
        tx = pcx + lay.dx; ty = pcy + lay.dy;
        ROTATION(rot, flip, 0.0, 0.0, tx, ty, x1, y1);
        my_snprintf(ps_font_family, S(ps_font_family), "%s", ps_font_token(pfont)); /* 1351 */
        my_snprintf(ps_font_name,   S(ps_font_name),   "%s", ps_font_token(pfont));
        if(text_ps)
          ps_draw_string(plw, pnm,
            ((short)lay.rot + ((flip && ((short)lay.rot & 1)) ? rot+2 : rot)) & 0x3,
            flip ^ (short)lay.flip, 0, 0, x0+x1, y0+y1, lay.size, lay.size);
        else
          old_ps_draw_string(plw, pnm,
            ((short)lay.rot + ((flip && ((short)lay.rot & 1)) ? rot+2 : rot)) & 0x3,
            flip ^ (short)lay.flip, 0, 0, x0+x1, y0+y1, lay.size, lay.size);
      }
      if(plw != c) set_ps_colors(c);
      my_free(_ALLOC_ID_, &pnm);
      my_free(_ALLOC_ID_, &pfont);
    }
  }
}


/* S9: the draw-time OP-annotation overlay, POSTSCRIPT/PDF back end -- the exact
 * mirror of draw.c draw_annot_overlay() and svg_draw_annot_overlay(), with every
 * decision in the shared reader get_annot_overlay() (actions.c). This is the
 * SECOND of the two "call sites nobody looks at" and it has its own test row,
 * because a stubbed PS site is invisible to every SVG check.
 *
 * Called from the export instance loop, NOT from ps_draw_symbol(): psprint.c's
 * text loop holds `txtptr = translate(n, ...)` LIVE across its body and
 * translate()'s result is one static buffer. Unlike SVG this back end also has
 * to bracket the write with set_ps_colors(), exactly as the P6 pin pass does. */
static void ps_draw_annot_overlay(int n, int c)
{
  const char *txt = NULL;
  double x, y, size;
  int layer;
  if(!get_annot_overlay(n, &txt, &x, &y, &size, &layer)) return;
  if(layer < 0 || layer >= cadlayers) layer = TEXTLAYER;
  if(!xctx->enable_layer[layer]) return;
  set_ps_colors(layer);
  my_snprintf(ps_font_family, S(ps_font_family), "%s", ANNOT_OVERLAY_FONT);
  my_snprintf(ps_font_name,   S(ps_font_name),   "%s", ANNOT_OVERLAY_FONT);
  /* upright, top-left anchored: rot 0, flip 0, hcenter 0, vcenter 0 (decision D7) */
  if(text_ps)
    ps_draw_string(layer, txt, 0, 0, 0, 0, x, y, size, size);
  else
    old_ps_draw_string(layer, txt, 0, 0, 0, 0, x, y, size, size);
  if(layer != c) set_ps_colors(c);
}

static void fill_ps_colors()
{
 char s[200]; /* overflow safe 20161122 */
 unsigned int i,c;
 /* if(debug_var>=1) {
  *   tcleval( "puts $ps_colors");
  * }
  */
 for(i=0;i<cadlayers; ++i) {
   my_snprintf(s, S(s), "lindex $ps_colors %u", i);
   tcleval( s);
   sscanf(tclresult(),"%x", &c);
   ps_colors[i].red   = (c & 0xff0000) >> 16;
   ps_colors[i].green = (c & 0x00ff00) >> 8;
   ps_colors[i].blue  = (c & 0x0000ff);
 }

}
/* fullzoom:
 *   0: Print area displayed in window
 *   1: Do a full zoom before generating ps/pdf
 *   2: set paper size to bounding box instead of a4/letter
 */
void create_ps(char **psfile, int what, int fullzoom, int eps)
{
  double dx, dy, scale, scaley;
  int landscape=1;
  static int numpages = 0;
  double margin=10; /* in postscript points, (1/72)". No need to add margin as xschem zoom full already has margins.*/
  char papername[80] = "a4";
  double pagex = 842;
  double pagey = 595;
  char pagedest[PATH_MAX];             /* ITEM H6: this page's /Dest name, raw */
  xRect boundbox;
  int c,i, textlayer;
  int old_grid;
  const char *textfont;
  static Zoom_info zi;
  Hilight_hashentry *entry;

  dbg(1, "create_ps(): what = %d, fullzoom=%d\n", what, fullzoom);
  /* S7/S9: freshened at the callee, for the reason svg_draw() records. */
  annot_show_sync_cache();
  annot_overlay_sync();
  if(tcleval("info exists ps_paper_size")[0] == '1') {
    double tmp;
    my_strncpy(papername, tcleval("lindex $ps_paper_size 0"), S(papername));
    pagex = my_atod(tcleval("lindex $ps_paper_size 1"));
    pagey = my_atod(tcleval("lindex $ps_paper_size 2"));
    if(pagex < pagey) { /* start with landscape; later we decide paper orientation */
      tmp = pagex;
      pagex = pagey;
      pagey = tmp;
    }
  }
  if(what & 1) { /* prolog */
    numpages = 0;
    if(!(fd = open_tmpfile("psplot_", ".ps", psfile)) ) {
      fprintf(errfp, "ps_draw(): can not create tmpfile %s\n", *psfile);
      return;
    }
    /* setbuf(fd, NULL); */ /* To prevent buffer errors, still investigating cause. */
  }
  ps_colors=my_calloc(_ALLOC_ID_, cadlayers, sizeof(Ps_color));
  if(ps_colors==NULL){
    fprintf(errfp, "create_ps(): calloc error\n");
    return;
  }

  fill_ps_colors();
  old_grid=tclgetboolvar("draw_grid");
  tclsetvar("draw_grid", "0");

  /* xschem window aspect ratio decides if portrait or landscape */
  boundbox.x1 = xctx->areax1;
  boundbox.x2 = xctx->areax2;
  boundbox.y1 = xctx->areay1;
  boundbox.y2 = xctx->areay2;
  dx=boundbox.x2-boundbox.x1;
  dy=boundbox.y2-boundbox.y1;

  /* xschem drawing bbox decides if portrait or landscape */
  if(fullzoom == 1) {
    calc_drawing_bbox(&boundbox, 0);
    dx=boundbox.x2-boundbox.x1;
    dy=boundbox.y2-boundbox.y1;
  }
  if(dx >= dy) {
    landscape = 1;
  } else {
    landscape = 0;
  }
  dbg(1, "dx=%g, dy=%g\n", dx, dy);


  if(fullzoom == 1) {
    /* save size and zoom factor */
    save_restore_zoom(1, &zi);
    /* this zoom only done to reset lw */
    zoom_full(0, 0, 1 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
    /* adjust aspect ratio to paper size */
    if(landscape)
      xctx->xrect[0].height = (short unsigned int) (xctx->xrect[0].width * pagey / pagex);
    else
      xctx->xrect[0].width = (short unsigned int) (xctx->xrect[0].height * pagey / pagex);
    dbg(1, "create_ps(): save zoom, r.width=%d, r.height=%d\n", xctx->xrect[0].width, xctx->xrect[0].height);
    xctx->areax1 = -2*INT_LINE_W(xctx->lw);
    xctx->areay1 = -2*INT_LINE_W(xctx->lw);
    xctx->areax2 = xctx->xrect[0].width+2*INT_LINE_W(xctx->lw);
    xctx->areay2 = xctx->xrect[0].height+2*INT_LINE_W(xctx->lw);
    xctx->areaw = xctx->areax2-xctx->areax1;
    xctx->areah = xctx->areay2 - xctx->areay1;
    dbg(1, "create_ps(): areax1=%d areay1=%d areax2=%d areay2=%d\n",
       xctx->areax1, xctx->areay1, xctx->areax2, xctx->areay2);
    dbg(1, "create_ps(): dx=%g, dy=%g\n", dx, dy);
    /* fit schematic into adjusted size */
    zoom_full(0, 0, 0 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
    boundbox.x1 = xctx->areax1;
    boundbox.x2 = xctx->areax2;
    boundbox.y1 = xctx->areay1;
    boundbox.y2 = xctx->areay2;
    dx=boundbox.x2-boundbox.x1;
    dy=boundbox.y2-boundbox.y1;
  }

  if(!landscape) { /* decide paper orientation for best schematic fit */
    double tmp;
    tmp = pagex;
    pagex = pagey;
    pagey = tmp;
  }
  if(fullzoom == 2) { /* set media size to bbox */
    double sc;
    my_strncpy(papername, "bbox", S(papername));
    pagex = xctx->xrect[0].width;
    pagey = xctx->xrect[0].height;
    if(pagex > pagey) {
      sc = 842. / pagex;
      pagex = my_round(pagex * sc);
      pagey = my_round(pagey * sc);
    } else {
      sc = 842. / pagey;
      pagex = my_round(pagex * sc);
      pagey = my_round(pagey * sc);
    }
    margin = 0.0;
  }

  if(what & 1) {/* prolog */
    dbg(1, "ps_draw(): bbox: x1=%g y1=%g x2=%g y2=%g\n", boundbox.x1, boundbox.y1, boundbox.x2, boundbox.y2);
    if(!eps) {
      fprintf(fd, "%%!PS-Adobe-3.0\n");
    } else {
      fprintf(fd, "%%!PS-Adobe-2.0 EPSF-2.0\n");
      fprintf(fd, "%%%%BoundingBox: 0 0 %g %g\n",  pagex, pagey);
    }
    /* fprintf(fd, "%%%%DocumentMedia: %s %g %g 80 () ()\n", landscape ? "a4land" : "a4", pagex, pagey); */
    fprintf(fd, "%%%%DocumentMedia: %s %g %g 80 () ()\n", papername, pagex, pagey);
    fprintf(fd, "%%%%PageOrientation: %s\n", landscape ? "Landscape" : "Portrait");
    fprintf(fd, "%%%%Title: xschem plot\n");
    fprintf(fd, "%%%%Creator: xschem\n");
    if(!eps) fprintf(fd, "%%%%Pages: (atend)\n");
    fprintf(fd, "%%%%EndComments\n");

    if(eps) {
      fprintf(fd, "%%%%BeginProlog\n");
      fprintf(fd, "save\n");
      fprintf(fd, "countdictstack\n");
      fprintf(fd, "mark\n");
      fprintf(fd, "newpath\n");
      fprintf(fd, "/showpage {} def\n");
      fprintf(fd, "/setpagedevice {pop} def\n");
      fprintf(fd, "%%%%EndProlog\n");
      fprintf(fd, "%%%%Page 1 1\n");
    }
    fprintf(fd, "%%%%BeginProlog\n\n");

    for(i = 0; i < sizeof(utf8_enc)/sizeof(char *); ++i) {
      fprintf(fd, "%s", utf8_enc[i]);
    }
    for(i = 0; i < sizeof(utf8)/sizeof(char *); ++i) {
      fprintf(fd, "%s", utf8[i]);
    }

    fprintf(fd, "/Times /Times chararr recode\n");
    fprintf(fd, "/Times-Bold /Times-Bold chararr recode\n");
    fprintf(fd, "/Times-Oblique /Times-Oblique chararr recode\n");
    fprintf(fd, "/Times-BoldOblique /Times-BoldOblique chararr recode\n");
    fprintf(fd, "/Helvetica /Helvetica chararr recode\n");
    fprintf(fd, "/Helvetica-Bold /Helvetica-Bold chararr recode\n");
    fprintf(fd, "/Helvetica-Oblique /Helvetica-Oblique chararr recode\n");
    fprintf(fd, "/Helvetica-BoldOblique /Helvetica-BoldOblique chararr recode\n");
    fprintf(fd, "/Courier /Courier chararr recode\n");
    fprintf(fd, "/Courier-Bold /Courier-Bold chararr recode\n");
    fprintf(fd, "/Courier-Oblique /Courier-Oblique chararr recode\n");
    fprintf(fd, "/Courier-BoldOblique /Courier-BoldOblique chararr recode\n");

    fprintf(fd,"/cm {28.346457 mul} bind def\n");
    fprintf(fd,"/LT {lineto} bind def\n");
    fprintf(fd,"/MT {moveto} bind def\n");
    fprintf(fd,"/RMT {rmoveto} bind def\n");
    fprintf(fd,"/L {moveto lineto stroke} bind def\n");
    fprintf(fd,"/RGB {setrgbcolor} bind def\n");
    fprintf(fd,"/FF {findfont} bind def\n");
    fprintf(fd,"/SF {setfont} bind def\n");
    fprintf(fd,"/SCF {scalefont} bind def\n");
    fprintf(fd,"/SW {stringwidth} bind def\n");
    fprintf(fd,"/GS {gsave} bind def\n");
    fprintf(fd,"/GR {grestore} bind def\n");
    fprintf(fd,"/NP {newpath} bind def\n");
    fprintf(fd,"/A {arcn} bind def\n");
    fprintf(fd,"/R {rectstroke} bind def\n");
    fprintf(fd,"/S {stroke} bind def\n");
    fprintf(fd,"/C {closepath} bind def\n");
    fprintf(fd,"/F {fill} bind def\n");
    fprintf(fd,"/RF {rectfill} bind def\n");
    fprintf(fd,"/E {\n"); /* function for drawing ellipses */
    fprintf(fd,"/endangle exch def\n");
    fprintf(fd,"/startangle exch def\n");
    fprintf(fd,"/yrad exch def\n");
    fprintf(fd,"/xrad exch def\n");
    fprintf(fd,"/y exch def\n");
    fprintf(fd,"/x exch def\n");
    fprintf(fd,"/savematrix matrix currentmatrix def\n");
    fprintf(fd,"x y translate\n");
    fprintf(fd,"xrad yrad scale\n");
    fprintf(fd,"0 0 1 startangle endangle arcn\n");
    fprintf(fd,"savematrix setmatrix\n");
    fprintf(fd,"} def %% ellipse\n");
    fprintf(fd, "%%%%EndProlog\n");
  }


  if(what & 2) { /* page */
    ++numpages;

    if(!eps) {
      fprintf(fd, "%%%%BeginSetup\n");
      fprintf(fd, "<< /PageSize [%g %g] /Orientation 0 >> setpagedevice\n", pagex, pagey);
      fprintf(fd, "%%%%EndSetup\n");
      fprintf(fd, "%%%%Page: %d %d\n\n", numpages, numpages);
      fprintf(fd, "%%%%BeginPageSetup\n");
      fprintf(fd, "%%%%EndPageSetup\n");
    }
    /* add small page title.
     * ISSUE 1350: the title is a FILENAME going into a PostScript string literal, so it
     * goes through the same escaper the schematic texts use -- `foo(bar).sch` used to
     * emit `(foo(bar).sch)`, which survives only because those parens happen to balance,
     * and `foo).sch` did not survive at all. */
    if(tclgetboolvar("ps_page_title") && fullzoom != 2) {
       fprintf(fd, "/Helvetica FF 10 SCF SF NP 20 %g MT (", pagey - 20);
       ps_string_body(fd, xctx->current_name);
       fprintf(fd, ") show\n");
    }

    /* Add anchor for pdfmarks. ISSUE 1352: a /Dest is a PostScript NAME, and a name ends
     * at the first whitespace or delimiter -- so a cell whose file name contains a space
     * emitted `/Dest /my cell.sch`, gs read `/my` and then tried to EXECUTE `cell.sch`,
     * and the whole export died with /undefined. ps_name_token() is applied HERE and at
     * the /Link emitter and nowhere else, so the page anchor and the annotation that
     * points at it cannot disagree about the spelling (DD-2). */
    my_strncpy(pagedest, get_cell_w_ext(sanitize(xctx->current_name), 0), S(pagedest));
    fprintf(fd,
      "[ "
      "/Dest /%s "
      "/DEST pdfmark\n", ps_name_token(pagedest));
    /* ITEM H6 -- the navigation strip, in the margin band ABOVE the drawing, and therefore
     * emitted HERE: everything below this point is inside the page CTM the translate/scale
     * two lines down establish. The raw destination name is passed rather than re-derived,
     * so the anchor and the strip's parent lookup cannot disagree about the page's identity. */
    ps_hier_nav_strip(fd, pagedest, pagex, pagey, margin);
    scaley = scale = (pagey-2 * margin) / dy;
    dbg(1, "scale=%g pagex=%g pagey=%g dx=%g dy=%g\n", scale, pagex, pagey, dx, dy);
    if(dx * scale > (pagex - 2 * margin)) {
      scale = (pagex - 2 * margin) / dx;
      dbg(1, "scale=%g\n", scale);
    }
    fprintf(fd, "%g %g translate\n",
      -scale * boundbox.x1 + margin, pagey - (scaley - scale) * dy - margin + scale * boundbox.y1);
    fprintf(fd, "%g %g scale\n", scale, -scale);
    fprintf(fd, "1 setlinejoin 1 setlinecap\n");

    set_lw(xctx->lw);
    ps_drawgrid();

    for(c=0;c<cadlayers; ++c)
    {
      if(xctx->lines[c] || xctx->rects[c] || xctx->arcs[c] || xctx->polygons[c]) {
        set_ps_colors(c);
      }
      for(i=0;i<xctx->lines[c]; ++i)
        ps_drawline(c, xctx->line[c][i].x1, xctx->line[c][i].y1,
          xctx->line[c][i].x2, xctx->line[c][i].y2, xctx->line[c][i].dash, xctx->line[c][i].bus);
      if(xctx->rects[c]) fprintf(fd, "NP\n"); /* newpath */
      for(i=0;i<xctx->rects[c]; ++i)
      {

        if (c == GRIDLAYER && (xctx->rect[c][i].flags & 1024)) { /* image */
          xRect* r = &xctx->rect[c][i];
          /* PNG Code Here */
          ps_embedded_image(r, r->x1, r->y1, r->x2, r->y2,0 ,0);
          continue;
        }
        if (c == GRIDLAYER && (xctx->rect[c][i].flags & 1)) { /* graph */
          xRect *r = &xctx->rect[c][i];
          ps_embedded_graph(i, r->x1, r->y1, r->x2, r->y2);
        }
        if(c != GRIDLAYER || !(xctx->rect[c][i].flags & 1) )  {
          ps_filledrect(c, xctx->rect[c][i].x1, xctx->rect[c][i].y1,
            xctx->rect[c][i].x2, xctx->rect[c][i].y2,
            xctx->rect[c][i].bus, xctx->rect[c][i].dash, xctx->rect[c][i].fill,
            xctx->rect[c][i].ellipse_a, xctx->rect[c][i].ellipse_b);
        }
      }
      if(xctx->arcs[c]) fprintf(fd, "NP\n"); /* newpath */
      for(i=0;i<xctx->arcs[c]; ++i)
      {
        ps_drawarc(c, xctx->arc[c][i].fill, xctx->arc[c][i].x, xctx->arc[c][i].y,
          xctx->arc[c][i].r, xctx->arc[c][i].a, xctx->arc[c][i].b, xctx->arc[c][i].bus, xctx->arc[c][i].dash);
      }
      for(i=0;i<xctx->polygons[c]; ++i) {
        int bezier = !strboolcmp(get_tok_value(xctx->poly[c][i].prop_ptr, "bezier", 0), "true");
        ps_drawpolygon(c, NOW, xctx->poly[c][i].x, xctx->poly[c][i].y, xctx->poly[c][i].points,
          xctx->poly[c][i].fill, xctx->poly[c][i].dash, bezier, xctx->poly[c][i].bus);
      }
      dbg(1, "create_ps(): starting drawing symbols on layer %d\n", c);
    } /* for(c=0;c<cadlayers; ++c) */

    /* bring outside previous for(c=0...) loop since ps_embedded_graph() calls ps_draw_symbol() */
    for(c=0;c<cadlayers; ++c) {
      for(i=0;i<xctx->instances; ++i) {
        Ps_color sv; int did = 0, hlayer = 0;
        /* a highlighted symbol (label/pin) drawn with a custom-RGB style takes the style's color, not
         * the fallback layer get_color() maps it to inside ps_draw_symbol (0044) */
        if(xctx->inst[i].color != -10000) {
          hlayer = get_color(xctx->inst[i].color);
          did = ps_push_hilight(xctx->inst[i].color, hlayer, &sv);
        }
        ps_draw_symbol(c, i, c, what, 0,0, 0.0, 0.0);
        if(c == cadlayers - 1) {
          ps_draw_symbol(c + 1 , i, c + 1, what, 0, 0, 0.0, 0.0); /* ... draw texts */
        }
        ps_pop_hilight(hlayer, did, &sv);
        /* S9: the OP-annotation overlay, once per instance per export (decision D3) */
        if(c == cadlayers - 1) ps_draw_annot_overlay(i, c);
      }
    }
    prepare_netlist_structs(0); /* NEEDED: data was cleared by trim_wires() */
    for(i=0;i<xctx->wires; ++i)
    {
      int color = WIRELAYER, hval = -1, did;
      Ps_color sv;
      if(xctx->hilight_nets && (entry=bus_hilight_hash_lookup( xctx->wire[i].node, 0, XLOOKUP))) {
        color = get_color(entry->value); hval = entry->value;
      }
      did = ps_push_hilight(hval, color, &sv);   /* a custom-RGB hilight overrides the fallback layer (0044) */
      set_ps_colors(color);
      ps_drawline(color, xctx->wire[i].x1,xctx->wire[i].y1,xctx->wire[i].x2,xctx->wire[i].y2,
                  0 ,xctx->wire[i].bus);
      ps_pop_hilight(color, did, &sv);
    }

    {
      double x1, y1, x2, y2;
      Wireentry *wireptr;
      int i;
      int first = 1;
      Iterator_ctx ctx;
      update_conn_cues(WIRELAYER, 0, 0);
      /* draw connecting dots */
      x1 = X_TO_XSCHEM(xctx->areax1);
      y1 = Y_TO_XSCHEM(xctx->areay1);
      x2 = X_TO_XSCHEM(xctx->areax2);
      y2 = Y_TO_XSCHEM(xctx->areay2);
      for(init_wire_iterator(&ctx, x1, y1, x2, y2); ( wireptr = wire_iterator_next(&ctx) ) ;) {
        if(first) {
          fprintf(fd, "NP\n"); /* newpath */
          first = 0;
        }
        i = wireptr->n;
        if( xctx->wire[i].end1 >1 ) {
          ps_drawarc(WIRELAYER, 1, xctx->wire[i].x1, xctx->wire[i].y1, xctx->cadhalfdotsize, 0, 360, 0.0, 0);
        }
        if( xctx->wire[i].end2 >1 ) {
          ps_drawarc(WIRELAYER, 1, xctx->wire[i].x2, xctx->wire[i].y2, xctx->cadhalfdotsize, 0, 360, 0.0, 0);
        }
      }
    }

    for(i=0;i<xctx->texts; ++i)
    {
      int alay;
      textlayer = xctx->text[i].layer;
      if(text_hidden(xctx->text[i].flags, TEXT_CTX_SCHEMATIC)) continue;
      /* 0615: the schematic-own-text mirror of the instance-text site above. The
       * colour itself is applied inside ps_draw_string_line() (psprint.c:748), so
       * moving `textlayer` here is the whole override. */
      if((alay = annot_text_layer(xctx->text[i].flags, TEXT_CTX_SCHEMATIC)) != -1) textlayer = alay;
      if(textlayer < 0 ||  textlayer >= cadlayers) textlayer = TEXTLAYER;

      my_snprintf(ps_font_family, S(ps_font_name), "Helvetica");
      my_snprintf(ps_font_name, S(ps_font_name), "Helvetica");
      textfont = xctx->text[i].font;
      if( (textfont && textfont[0])) {                                /* issue 1351 */
        my_snprintf(ps_font_family, S(ps_font_family), "%s", ps_font_token(textfont));
        my_snprintf(ps_font_name, S(ps_font_name), "%s", ps_font_token(textfont));
      }
      if( xctx->text[i].flags & TEXT_BOLD) {
        if( (xctx->text[i].flags & TEXT_ITALIC) || (xctx->text[i].flags & TEXT_OBLIQUE) ) {
          my_snprintf(ps_font_family, S(ps_font_family), "%s-BoldOblique", ps_font_name);
        } else {
          my_snprintf(ps_font_family, S(ps_font_family), "%s-Bold", ps_font_name);
        }
      }
      else if( xctx->text[i].flags & TEXT_ITALIC)
        my_snprintf(ps_font_family, S(ps_font_family), "%s-Oblique", ps_font_name);
      else if( xctx->text[i].flags & TEXT_OBLIQUE)
        my_snprintf(ps_font_family, S(ps_font_family), "%s-Oblique", ps_font_name);

      if(text_ps) {
        ps_draw_string(textlayer, get_text_floater(i),
          xctx->text[i].rot, xctx->text[i].flip, xctx->text[i].hcenter, xctx->text[i].vcenter,
          xctx->text[i].x0,xctx->text[i].y0,
          xctx->text[i].xscale, xctx->text[i].yscale);
      } else {
        old_ps_draw_string(textlayer, get_text_floater(i),
          xctx->text[i].rot, xctx->text[i].flip, xctx->text[i].hcenter, xctx->text[i].vcenter,
          xctx->text[i].x0,xctx->text[i].y0,
          xctx->text[i].xscale, xctx->text[i].yscale);
      }
    }

    dbg(1, "ps_draw(): INT_LINE_W(lw)=%d plotfile=%s\n",INT_LINE_W(xctx->lw), xctx->plotfile);
    fprintf(fd, "showpage\n\n");
  }
  if(what & 4) { /* trailer */
    fprintf(fd, "%%%%trailer\n");
    fprintf(fd, "%%%%Pages: %d\n", numpages);
    if(eps) {
      fprintf(fd, "cleartomark\n");
      fprintf(fd, "countdictstack\n");
      fprintf(fd, "exch sub { end } repeat\n");
      fprintf(fd, "restore\n");
    }
    fprintf(fd, "%%%%EOF\n");
    fclose(fd);
  }
  tclsetboolvar("draw_grid", old_grid);
  my_free(_ALLOC_ID_, &ps_colors);


  /* restore original size and zoom factor */
  if(fullzoom == 1) {
    save_restore_zoom(0, &zi);
    resetwin(1, 1, 1, xctx->xrect[0].width, xctx->xrect[0].height);
    change_linewidth(xctx->lw);
    zoom_full(1, 0, 0 + 2 * tclgetboolvar("zoom_full_center"), 0.97);
  }

}

int ps_draw(int what, int fullzoom, int eps)
{
 char tmp[2*PATH_MAX+40];
 static char lastdir[PATH_MAX] = "";
 const char *r;
 static char *psfile;

 if(what & 1) { /* prolog */
   if(!lastdir[0]) my_strncpy(lastdir, pwd_dir, S(lastdir));
   if(has_x && !xctx->plotfile[0]) {
     /* tclvareval("tk_getSaveFile -title {Select destination file} -initialfile {",
      *   get_cell(xctx->sch[xctx->currsch], 0) , ".pdf} -initialdir {", lastdir, "}", NULL); */
     tclvareval("save_file_dialog {Select destination file} *.{ps,pdf} INITIALLOADDIR {", pwd_dir, "/",
       get_cell(xctx->sch[xctx->currsch], 0), eps ? ".eps}": ".pdf}", NULL);
     r = tclresult();
     if(r[0]) {
       my_strncpy(xctx->plotfile, r, S(xctx->plotfile));
       tclvareval("file dirname {", xctx->plotfile, "}", NULL);
       my_strncpy(lastdir, tclresult(), S(lastdir));
     }
     else return 0;
   }
 }
 create_ps(&psfile, what, fullzoom, eps);
 if(what & 4) { /* trailer */
   if(xctx->plotfile[0]) {
     my_snprintf(tmp, S(tmp), "convert_to_pdf {%s} {%s}", psfile, xctx->plotfile);
   } else {
     my_snprintf(tmp, S(tmp), "convert_to_pdf {%s} plot.pdf", psfile);
   }
   my_strncpy(xctx->plotfile,"", S(xctx->plotfile));
   tcleval( tmp);
   Tcl_SetResult(interp,"",TCL_STATIC);
 }
 return 1;
}

