/* xactivate.c -- send an EWMH _NET_ACTIVE_WINDOW (or _NET_WM_STATE_ABOVE) request to a
 * window, with configurable source indication and timestamp, to find out which combination
 * (if any) makes this WSLg/Weston WM actually RAISE an already-mapped window. No re-map, so
 * if it works there is zero position drift.  Build: see 0054-activate-probe.tcl.
 *
 *   xactivate <winid> active <source 0|1|2> <now|current>   # _NET_ACTIVE_WINDOW
 *   xactivate <winid> above                                 # add _NET_WM_STATE_ABOVE
 *   xactivate <winid> above-toggle                          # add then remove _NET_WM_STATE_ABOVE
 */
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

/* Fetch a fresh server timestamp via a zero-length property append on a throwaway window
 * (the canonical ICCCM trick) -- this is the "real timestamp" focus-stealing-prevention WMs
 * want, as opposed to CurrentTime/0 which they routinely reject. */
static Time server_time(Display *d) {
  Window r = DefaultRootWindow(d);
  Window w = XCreateSimpleWindow(d, r, -100, -100, 1, 1, 0, 0, 0);
  Atom a = XInternAtom(d, "_XACTIVATE_TS", False);
  XEvent e;
  Time t = CurrentTime;
  XSelectInput(d, w, PropertyChangeMask);
  XChangeProperty(d, w, a, XA_STRING, 8, PropModeAppend, (unsigned char *)"", 0);
  for (;;) {
    XNextEvent(d, &e);
    if (e.type == PropertyNotify && e.xproperty.window == w) { t = e.xproperty.time; break; }
  }
  XDestroyWindow(d, w);
  return t;
}

static void client_msg(Display *d, Window win, const char *msg,
                       long d0, long d1, long d2, long d3, long d4) {
  XEvent ev;
  memset(&ev, 0, sizeof ev);
  ev.xclient.type = ClientMessage;
  ev.xclient.send_event = True;
  ev.xclient.display = d;
  ev.xclient.window = win;
  ev.xclient.message_type = XInternAtom(d, msg, False);
  ev.xclient.format = 32;
  ev.xclient.data.l[0] = d0;
  ev.xclient.data.l[1] = d1;
  ev.xclient.data.l[2] = d2;
  ev.xclient.data.l[3] = d3;
  ev.xclient.data.l[4] = d4;
  XSendEvent(d, DefaultRootWindow(d), False,
             SubstructureRedirectMask | SubstructureNotifyMask, &ev);
  XFlush(d);
}

#define _NET_WM_STATE_REMOVE 0
#define _NET_WM_STATE_ADD    1

int main(int argc, char **argv) {
  Display *d;
  Window win;
  const char *mode;
  if (argc < 3) { fprintf(stderr, "usage: xactivate <winid> active <0|1|2> <now|current> | above | above-toggle\n"); return 2; }
  d = XOpenDisplay(NULL);
  if (!d) { fprintf(stderr, "cannot open display\n"); return 2; }
  win = (Window) strtoul(argv[1], NULL, 0);
  mode = argv[2];

  if (!strcmp(mode, "active")) {
    long source = argc > 3 ? atol(argv[3]) : 1;
    Time t = (argc > 4 && !strcmp(argv[4], "now")) ? server_time(d) : CurrentTime;
    client_msg(d, win, "_NET_ACTIVE_WINDOW", source, (long) t, 0, 0, 0);
    printf("sent _NET_ACTIVE_WINDOW win=0x%lx source=%ld time=%lu\n",
           (unsigned long) win, source, (unsigned long) t);
  } else if (!strcmp(mode, "above")) {
    Atom above = XInternAtom(d, "_NET_WM_STATE_ABOVE", False);
    client_msg(d, win, "_NET_WM_STATE", _NET_WM_STATE_ADD, (long) above, 0, 1, 0);
    printf("added _NET_WM_STATE_ABOVE win=0x%lx\n", (unsigned long) win);
  } else if (!strcmp(mode, "above-toggle")) {
    Atom above = XInternAtom(d, "_NET_WM_STATE_ABOVE", False);
    client_msg(d, win, "_NET_WM_STATE", _NET_WM_STATE_ADD, (long) above, 0, 1, 0);
    XSync(d, False); usleep(150000);
    client_msg(d, win, "_NET_WM_STATE", _NET_WM_STATE_REMOVE, (long) above, 0, 1, 0);
    printf("toggled _NET_WM_STATE_ABOVE win=0x%lx\n", (unsigned long) win);
  } else {
    fprintf(stderr, "unknown mode %s\n", mode); return 2;
  }
  XSync(d, False);
  return 0;
}
