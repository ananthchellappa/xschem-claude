/* doc/codex/issues/0062 -- what totalreset() leaves the device table in.
 *
 * Prints the three values INPtypelook() and CKTmodCrt() read, before and
 * after ngSpice_Reset().  No circuit is ever loaded, so nothing here depends
 * on a deck.
 *
 * This one needs the generated config.h, so it takes an extra -I:
 *
 *     gcc -g -O0 -o /tmp/reset_devtable_probe \
 *         doc/claude/feedback/ngspice_upstream/repro/shared/reset_devtable_probe.c \
 *         -I build-shared/src/include -I src/include \
 *         -L build-shared/src/.libs -lngspice
 *     LD_LIBRARY_PATH=build-shared/src/.libs SPICE_SCRIPTS=build-shared/src \
 *         /tmp/reset_devtable_probe
 *
 * ngspice.h defines printf/fprintf away to the SendChar callback in a
 * SHARED_MODULE build, which is why the report goes out through write(2).
 */

#include <stdbool.h>
#include <stdio.h>
#include "ngspice/ngspice.h"
#include "ngspice/ifsim.h"
#include "ngspice/sharedspice.h"
#include <unistd.h>
#undef printf
#undef fprintf

extern IFsimulator *ft_sim;
extern void **DEVices;      /* SPICEdev **, but only its value is read here */

static int cb_char(char *s, int i, void *p) { (void) s; (void) i; (void) p; return 0; }
static int cb_exit(int s, NG_BOOL a, NG_BOOL b, int i, void *p)
{ (void) s; (void) a; (void) b; (void) i; (void) p; return 0; }

static void dump(const char *when)
{
    char b[256];
    int n = snprintf(b, sizeof b,
                     "%-12s DEVices=%p  ft_sim->devices=%p  ft_sim->numDevices=%d\n",
                     when, (void *) DEVices, (void *) ft_sim->devices,
                     ft_sim->numDevices);
    (void) !write(1, b, (size_t) n);
}

int main(void)
{
    ngSpice_Init(cb_char, NULL, cb_exit, NULL, NULL, NULL, NULL);
    dump("after Init");
    ngSpice_Reset();
    dump("after Reset");
    return 0;
}
