/* issue 0058 / decision 0016 decision 3 -- the one part of the case-mode
 * announcement no deck can reach.
 *
 * inp_case_announce_reset() is called from totalreset() (src/sharedspice.c),
 * so it runs only in a --with-ngshared build.  build-ver_50 is not one, which
 * means make check never executes that line; this is the probe that does.
 *
 * Build (from the repo root):
 *
 *     mkdir -p build-shared && cd build-shared && ../configure --with-ngshared
 *     make -j8 && cd ..
 *     gcc -o /tmp/casemode_reset_probe \
 *         doc/claude/feedback/ngspice_upstream/repro/shared/casemode_reset_probe.c \
 *         -I src/include -L build-shared/src/.libs -lngspice
 *     LD_LIBRARY_PATH=build-shared/src/.libs SPICE_SCRIPTS=build-shared/src \
 *         /tmp/casemode_reset_probe          # latch probe, exit 0 on success
 *     LD_LIBRARY_PATH=build-shared/src/.libs SPICE_SCRIPTS=build-shared/src \
 *         /tmp/casemode_reset_probe --reset  # the ngSpice_Reset() path
 *
 * Default mode, the latch probe.  The mode variable is set once and never
 * changed, and the same deck is read three times:
 *
 *     READ1 1   the outcome changes from the initial fold, so it announces
 *     READ2 0   same outcome as READ1, so it is silent
 *     READ3 1   after inp_case_announce_reset(), announced again
 *
 * Measured 2026-08-13 on ver_50: READ1 1  READ2 0  READ3-AFTER-CLEAR 1.
 * READ2 is what the latch buys and READ3 is what totalreset()'s call buys.
 * The function is called directly rather than through ngSpice_Reset() for the
 * reason --reset exists.
 *
 * --reset drives the path totalreset() actually sits on, and does not work on
 * this tree for reasons that have nothing to do with casemode.  Measured the
 * same day, with and without the inp_case_announce_reset() line compiled in,
 * identically both ways:
 *
 *     phase 1  ngSpice_Command("set casemode=distinguish") + ngSpice_Circ()
 *              -> one banner on the SendChar callback, prefixed "stderr ",
 *                 which is criterion 3's move working in the shared build
 *     reset    ngSpice_Reset() -> "Note: Resetting ngspice"
 *     phase 2  ngSpice_Command("echo ... $casemode") produces NO output at
 *              all -- the command does not run -- and the following
 *              ngSpice_Circ() segfaults:
 *
 *                  #0 CKTmodCrt ()
 *                  #1 INP2V ()
 *                  #2 INPpas2 ()
 *                  #3 if_inpdeck ()
 *                  #4 inp_dodeck ()
 *                  #5 inp_spsource ()
 *                  #6 create_circbyline ()
 *                  #7 ngSpice_Circ ()
 *
 * So a host cannot today observe the re-announcement end to end: it cannot
 * re-set the variable after a reset, and the read crashes in the device model
 * layer before the analysis. That is a pre-existing defect in the shared
 * build's reset path, unrelated to this issue and worth one of its own; the
 * casemode line is correct, is exercised by the default mode above, and is
 * not what crashes.
 */

#include <stdbool.h>
#include <stdio.h>
#include <string.h>
#include "ngspice/sharedspice.h"

extern void inp_case_announce_reset(void);

static int banners;

static int cb_char(char *out, int id, void *p)
{
    (void) id; (void) p;
    if (strstr(out, "is experimental"))
        banners++;
    return 0;
}

static int cb_stat(char *s, int id, void *p)
{
    (void) s; (void) id; (void) p;
    return 0;
}

static int cb_exit(int status, NG_BOOL immediate, NG_BOOL quit, int id, void *p)
{
    (void) immediate; (void) quit; (void) id; (void) p;
    fprintf(stderr, "HOST: controlled exit %d\n", status);
    return 0;
}

static int cb_bg(NG_BOOL running, int id, void *p)
{
    (void) running; (void) id; (void) p;
    return 0;
}

static char l0[] = "* issue 0058 shared-build probe";
static char l1[] = "Vs In 0 DC 3";
static char l2[] = "Rl In MidNode 1k";
static char l3[] = "Rg MidNode 0 3k";
static char l4[] = ".end";
static char *deck[] = { l0, l1, l2, l3, l4, NULL };

int main(int argc, char **argv)
{
    bool by_reset = (argc > 1 && strcmp(argv[1], "--reset") == 0);
    int a, b, c;

    ngSpice_Init(cb_char, cb_stat, cb_exit, NULL, NULL, cb_bg, NULL);
    ngSpice_Command("set casemode=distinguish");

    if (by_reset) {
        banners = 0;
        ngSpice_Circ(deck);
        printf("PHASE1-BANNERS %d\n", banners);
        fflush(stdout);

        banners = 0;
        ngSpice_Reset();
        ngSpice_Command("echo PROBE-CASEMODE-AFTER-RESET $casemode");
        fprintf(stderr, "HOST: about to re-read; this is where it dies\n");
        ngSpice_Circ(deck);
        printf("PHASE2-BANNERS %d\n", banners);
        return 0;
    }

    banners = 0; ngSpice_Circ(deck); a = banners;
    banners = 0; ngSpice_Circ(deck); b = banners;
    inp_case_announce_reset();
    banners = 0; ngSpice_Circ(deck); c = banners;

    printf("READ1 %d  READ2 %d  READ3-AFTER-CLEAR %d\n", a, b, c);
    return (a == 1 && b == 0 && c == 1) ? 0 : 1;
}
