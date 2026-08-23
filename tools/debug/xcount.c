/* Issue 0612: count the calls that mint a SERVER-SIDE drawable, so we can
 * compare "what XSCHEM+cairo ask for" against VcXsrv's CreateDIBSection
 * failures. Display-independent -- the request stream is the same on any server. */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <X11/Xlib.h>

static unsigned long n_pix, n_freepix, n_win, n_swin, n_pict, n_glyph, n_freepict;

static void report(void) {
  fprintf(stderr,
    "\n=== XCOUNT ===\n"
    "  XCreatePixmap        %lu\n"
    "  XFreePixmap          %lu   (outstanding %ld)\n"
    "  XCreateWindow        %lu\n"
    "  XCreateSimpleWindow  %lu\n"
    "  XRenderCreatePicture %lu\n"
    "  XRenderFreePicture   %lu\n"
    "  XRenderCreateGlyphSet %lu\n",
    n_pix, n_freepix, (long)n_pix - (long)n_freepix,
    n_win, n_swin, n_pict, n_freepict, n_glyph);
  fflush(stderr);
}
__attribute__((constructor)) static void init(void) { atexit(report); }

#define REAL(f, ret, args) static ret (*real_##f)args; \
  if(!real_##f) real_##f = dlsym(RTLD_NEXT, #f);

Pixmap XCreatePixmap(Display *d, Drawable dr, unsigned w, unsigned h, unsigned dep) {
  REAL(XCreatePixmap, Pixmap, (Display*,Drawable,unsigned,unsigned,unsigned))
  n_pix++;
  return real_XCreatePixmap(d, dr, w, h, dep);
}
int XFreePixmap(Display *d, Pixmap p) {
  REAL(XFreePixmap, int, (Display*,Pixmap))
  n_freepix++;
  return real_XFreePixmap(d, p);
}
Window XCreateWindow(Display *d, Window par, int x, int y, unsigned w, unsigned h,
                     unsigned bw, int dep, unsigned cls, Visual *v,
                     unsigned long vm, XSetWindowAttributes *a) {
  REAL(XCreateWindow, Window, (Display*,Window,int,int,unsigned,unsigned,unsigned,int,
                               unsigned,Visual*,unsigned long,XSetWindowAttributes*))
  n_win++;
  return real_XCreateWindow(d, par, x, y, w, h, bw, dep, cls, v, vm, a);
}
Window XCreateSimpleWindow(Display *d, Window par, int x, int y, unsigned w, unsigned h,
                           unsigned bw, unsigned long b, unsigned long bg) {
  REAL(XCreateSimpleWindow, Window, (Display*,Window,int,int,unsigned,unsigned,
                                     unsigned,unsigned long,unsigned long))
  n_swin++;
  return real_XCreateSimpleWindow(d, par, x, y, w, h, bw, b, bg);
}
/* XRender: cairo's Xlib backend and Xft go through these */
typedef unsigned long Picture_t;
Picture_t XRenderCreatePicture(Display *d, Drawable dr, const void *fmt,
                               unsigned long vm, const void *a) {
  REAL(XRenderCreatePicture, Picture_t, (Display*,Drawable,const void*,unsigned long,const void*))
  n_pict++;
  return real_XRenderCreatePicture(d, dr, fmt, vm, a);
}
void XRenderFreePicture(Display *d, Picture_t p) {
  REAL(XRenderFreePicture, void, (Display*,Picture_t))
  n_freepict++;
  real_XRenderFreePicture(d, p);
}
unsigned long XRenderCreateGlyphSet(Display *d, const void *fmt) {
  REAL(XRenderCreateGlyphSet, unsigned long, (Display*,const void*))
  n_glyph++;
  return real_XRenderCreateGlyphSet(d, fmt);
}
