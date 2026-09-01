/* Issue 0612, round 2: cairo's Render path goes through XCB, not Xlib, so the
 * Xlib-only counter could not see it. Count both. */
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <stdint.h>

static unsigned long c_pix, c_freepix, c_pict, c_freepict, c_glyph, c_freeglyph,
                     c_shmpix, c_shmseg, c_surf;
typedef struct { unsigned int sequence; } xcb_void_cookie_t;

static void report(void) {
  if(!(c_pix|c_pict|c_glyph|c_shmpix|c_surf)) return;   /* silence the helper forks */
  fprintf(stderr,
   "\n=== XCOUNT2 (xcb layer) ===\n"
   "  xcb_create_pixmap        %lu   freed %lu   outstanding %ld\n"
   "  xcb_shm_create_pixmap    %lu\n"
   "  xcb_shm_attach           %lu\n"
   "  xcb_render_create_picture %lu   freed %lu   outstanding %ld\n"
   "  xcb_render_create_glyph_set %lu  freed %lu\n",
   c_pix, c_freepix, (long)c_pix-(long)c_freepix,
   c_shmpix, c_shmseg,
   c_pict, c_freepict, (long)c_pict-(long)c_freepict,
   c_glyph, c_freeglyph);
  fflush(stderr);
}
__attribute__((constructor)) static void init(void){ atexit(report); }


/* variadic forwarding is fragile; use fixed prototypes instead */
xcb_void_cookie_t xcb_create_pixmap(void *c, uint8_t d, uint32_t pid, uint32_t drw,
                                    uint16_t w, uint16_t h) {
  static xcb_void_cookie_t (*real)(void*,uint8_t,uint32_t,uint32_t,uint16_t,uint16_t);
  if(!real) real = dlsym(RTLD_NEXT, "xcb_create_pixmap");
  c_pix++; return real(c,d,pid,drw,w,h);
}
xcb_void_cookie_t xcb_free_pixmap(void *c, uint32_t p) {
  static xcb_void_cookie_t (*real)(void*,uint32_t);
  if(!real) real = dlsym(RTLD_NEXT, "xcb_free_pixmap");
  c_freepix++; return real(c,p);
}
xcb_void_cookie_t xcb_shm_create_pixmap(void *c, uint32_t pid, uint32_t drw,
                                        uint16_t w, uint16_t h, uint8_t d,
                                        uint32_t shmseg, uint32_t off) {
  static xcb_void_cookie_t (*real)(void*,uint32_t,uint32_t,uint16_t,uint16_t,uint8_t,uint32_t,uint32_t);
  if(!real) real = dlsym(RTLD_NEXT, "xcb_shm_create_pixmap");
  c_shmpix++; return real(c,pid,drw,w,h,d,shmseg,off);
}
xcb_void_cookie_t xcb_shm_attach(void *c, uint32_t seg, uint32_t shmid, uint8_t ro) {
  static xcb_void_cookie_t (*real)(void*,uint32_t,uint32_t,uint8_t);
  if(!real) real = dlsym(RTLD_NEXT, "xcb_shm_attach");
  c_shmseg++; return real(c,seg,shmid,ro);
}
xcb_void_cookie_t xcb_render_create_picture(void *c, uint32_t pid, uint32_t drw,
                                            uint32_t fmt, uint32_t vm, const void *vl) {
  static xcb_void_cookie_t (*real)(void*,uint32_t,uint32_t,uint32_t,uint32_t,const void*);
  if(!real) real = dlsym(RTLD_NEXT, "xcb_render_create_picture");
  c_pict++; return real(c,pid,drw,fmt,vm,vl);
}
xcb_void_cookie_t xcb_render_free_picture(void *c, uint32_t p) {
  static xcb_void_cookie_t (*real)(void*,uint32_t);
  if(!real) real = dlsym(RTLD_NEXT, "xcb_render_free_picture");
  c_freepict++; return real(c,p);
}
xcb_void_cookie_t xcb_render_create_glyph_set(void *c, uint32_t gsid, uint32_t fmt) {
  static xcb_void_cookie_t (*real)(void*,uint32_t,uint32_t);
  if(!real) real = dlsym(RTLD_NEXT, "xcb_render_create_glyph_set");
  c_glyph++; return real(c,gsid,fmt);
}
xcb_void_cookie_t xcb_render_free_glyph_set(void *c, uint32_t gs) {
  static xcb_void_cookie_t (*real)(void*,uint32_t);
  if(!real) real = dlsym(RTLD_NEXT, "xcb_render_free_glyph_set");
  c_freeglyph++; return real(c,gs);
}
