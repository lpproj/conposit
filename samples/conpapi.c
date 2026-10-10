/*
    conpapi.c : a sample of conposit C API

    public domain
*/

#if defined(DEBUG) || defined(_DEBUG) || defined(TEST)
#include <stdio.h>
#include <string.h>
#endif

#include <dos.h>
#include <stdlib.h>

#include "conpapi.h"

#if !(defined(__TURBOC__) || defined(LSI_C))
#pragma pack(1)
#endif

struct cp_devhdr;

typedef struct cp_devhdr {
    struct cp_devhdr CP_FAR_PTR * next;
    unsigned short dev_attr;
    unsigned short strategy;
    unsigned short commands;
    char dev_name[8];
    char cp_id[10];
    char cp_api_sig[4];
    unsigned short cp_api_length;
    CONPOSIT_API_ASM cp_api_asm;
    CONPOSIT_API_CDECL cp_api_c;
} CP_DEVHDR;

#define CONPOSIT_ID_V0  "$CONPOSIT0"

#if !(defined(__TURBOC__) || defined(LSI_C))
#pragma pack()
#endif

/* old compilers (like tc2, tcpp101, MS-C 5.1...) don't have _fmemcpy... */
static int my_fmemcmp(const void CP_FAR_PTR *m1, const void CP_FAR_PTR *m2, unsigned len)
{
    int r = 0;

    while(len > 0) {
        r = (int)(*(unsigned char CP_FAR_PTR *)m1) - (int)(*(unsigned char CP_FAR_PTR *)m2);
        if (r != 0) break;
        m1 = (const unsigned char CP_FAR_PTR *)m1 + 1;
        m2 = (const unsigned char CP_FAR_PTR *)m2 + 1;
        --len;
    }

    return r;
}


const void CP_FAR_PTR * getNulDeviceHeader(void)
{
    union REGS r;
    struct SREGS sr;
    unsigned nul_off = 0x22;                    /* DOS 3.1 or later */

    r.x.ax = 0x3000;
    intdos(&r, &r);
    if (r.h.al <= 2) nul_off = 0x17;            /* DOS 2.x */
    else if (r.x.ax == 0x0003) nul_off = 0x28;   /* DOS 3.0 */
    r.h.ah = 0x52;
    intdosx(&r, &r, &sr);
    return MK_FP(sr.es, r.x.bx + nul_off);
}


int getConpositApiEntry(CONPOSIT_API_TABLE *api)
{
    int rc = -1;
    const CP_DEVHDR CP_FAR_PTR *ph;

    ph = getNulDeviceHeader();
    do {
        if ((ph->dev_attr & 0x8000U) && my_fmemcmp(ph->cp_id, CONPOSIT_ID_V0, sizeof(ph->cp_id)) == 0) {
            if (api) {
                api->cp_api_asm = ph->cp_api_asm;
                api->cp_api_c = ph->cp_api_c;
            }
            rc = 0;
            break;
        }
        ph = ph->next;
    } while (FP_OFF(ph) != 0xffffU);
    return rc;
}

int callConpositApi(const CONPOSIT_API_TABLE *api, unsigned r_ax, unsigned r_dx, void CP_FAR_PTR *r_esbx)
{
#if defined(LSI_C)
    return api->cp_api_c(-1, 0, 0, 0, r_ax, r_dx, r_esbx);
#else
    return api->cp_api_c(r_ax, r_dx, r_esbx);
#endif
}



#if defined(TEST)

int main(int argc, char **argv)
{
    int rc;
    CONPOSIT_API_TABLE capi;
    int i;

    rc = getConpositApiEntry(&capi);
    if (rc < 0) {
        fprintf(stderr, "ERROR: CONPOSIT not installed\n");
        return 1;
    }

    for (i = 'A'; i <= 'Z'; ++i) {
        rc = callConpositApi(&capi, CONPOSITE_API_GET_OPTION + i, 0, 0);
        if (rc >= 0) {
            printf("option /%c:%d\n", i, rc);
        }
    }

    return 0;
}
#endif

