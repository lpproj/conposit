#ifndef CONPOSIT_API
#define CONPOSIT_API

#include <limits.h>
#include <dos.h>

#if (UINT_MAX) > 65535UL
#error x86 16bit platform only
#endif

#if defined(__GNUC__) && defined(__ia16__)  /* gcc-ia16 */
#define CP_FAR_FUNC __far
#define CP_FAR_PTR  __far
#define CP_CDECL    __cdecl
#elif defined(_MSC_VER)
#define CP_FAR_FUNC _far
#define CP_FAR_PTR  _far
#define CP_CDECL    _cdecl
#else
#define CP_FAR_FUNC far
#define CP_FAR_PTR  far
#define CP_CDECL    cdecl
#endif

#if defined(__cplusplus)
extern "C" {
#endif

#if defined(__GNUC__)
typedef int CP_FAR_FUNC (*CONPOSIT_API_ASM)();
#else
typedef int (CP_FAR_FUNC *CONPOSIT_API_ASM)();
#endif

#if defined(LSI_C)
typedef int (CP_FAR_FUNC *CONPOSIT_API_CDECL)(int dummy_ax, int dummy_bx, int dummy_cx, int dummy_dx, unsigned r_ax, unsigned r_dx, void CP_FAR_PTR *r_esbx);
#elif defined(__GNUC__)
typedef int CP_FAR_FUNC (CP_CDECL * CONPOSIT_API_CDECL)(unsigned r_ax, unsigned r_dx, void CP_FAR_PTR *r_esbx);
#else
typedef int (CP_FAR_FUNC CP_CDECL *CONPOSIT_API_CDECL)(unsigned r_ax, unsigned r_dx, void CP_FAR_PTR *r_esbx);
#endif

typedef struct CONPOSIT_API_TABLE {
    CONPOSIT_API_ASM    cp_api_asm;
    CONPOSIT_API_CDECL  cp_api_c;
} CONPOSIT_API_TABLE;

#define CONPOSITE_API_GET_OPTION    0x1100
#define CONPOSITE_API_SET_OPTION    0x1200

int getConpositApiEntry(CONPOSIT_API_TABLE *api);
int callConpositApi(const CONPOSIT_API_TABLE *api, unsigned r_ax, unsigned r_dx, void CP_FAR_PTR *r_esbx);

#if defined(__cplusplus)
}
#endif
#endif
