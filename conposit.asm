%if 0
;----------------------------------------------------------------------------

CONPOSIT - mix MS-DOS AUX(serial) in/out into CON

author: lpproj (https://github.com/lpproj/)

target: MS-DOS version 2.1 or later (with "enough useful" AUX driver)

quick usage:
  1. Edit config.sys to install CONPOSIT.EXE as an additional console driver
     (e.g. device=C:\conposit.exe /I0 /O0 /DAUX)
     You can specify another AUX driver by the option /D. (default: /DAUX)

  2. You can control the driver to run CONPOSIT.EXE as a command.
     (e.g. C:\> conposit /i1 /o1)
     
command-line options:
     /I[1|0] enable/disable injecting AUX input into CON (default: /I1)
     /O[1|0] enable/disable dividing CON output into AUX (default: /O1)
     /C[1|0] do/don't send CSI6n (report cursor position) to AUX (default: /C0)
     /X[1|0] do/don't send Xon/Xoff characters to AUX (default: /X0)

to build with nasm and wlink:
	nasm -f obj -o composit.obj composit.asm
	wlink format dos option stack=256 disable 1172 name composit.exe file composit.obj

to build NEC PC-98 specific version:
	nasm -f obj -DNEC98 -o compos_n.obj composit.asm
	wlink format dos option stack=256 disable 1172 name compos_n.exe file compos_n.obj


This is free and unencumbered software released into the public domain.

Anyone is free to copy, modify, publish, use, compile, sell, or
distribute this software, either in source code form or as a compiled
binary, for any purpose, commercial or non-commercial, and by any
means.

In jurisdictions that recognize copyright laws, the author or authors
of this software dedicate any and all copyright interest in the
software to the public domain. We make this dedication for the benefit
of the public at large and to the detriment of our heirs and
successors. We intend this dedication to be an overt act of
relinquishment in perpetuity of all present and future rights to this
software under copyright law.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

For more information, please refer to <http://unlicense.org/>

;----------------------------------------------------------------------------
%endif

%define CONPOSITE_API_GET_OPTION 11h
%define CONPOSITE_API_SET_OPTION 12h

%ifdef NEC98
  %define PLATFORM_STR 'NEC PC-98'
%elifdef IBMPC
  %define PLATFORM_STR 'IBM PC'
%else
  %ifndef GENDOS
  %define GENDOS 1
  %endif
  %define PLATFORM_STR 'generic DOS'
%endif

%ifndef KEYBUF_MAX
%define KEYBUF_MAX 64
%endif

		CPU	8086
		BITS	16

; segment order
SEGMENT _TEXT align=2 public class=CODE
SEGMENT _STACK align=16 stack class=STACK	; note: the segment name "_STACK" and the qualifier "stack" are very important for the linker...
GROUP DGROUP  _TEXT _STACK

SEGMENT _TEXT

dev_header:
		dd	-1
%ifdef IBMPC
dev_attr	dw	8000h		; just a chardev, not a standard console
%else
dev_attr	dw	8013h		; stdin/stdout/int29h
%endif
		dw	Strategy
dev_commands	dw	Init_Commands
%ifdef IBMPC
dev_name	db	'CON$$$$$'
%else
dev_name	db	'CON     '
%endif
dev_id		db	'$CONPOSIT'
		db	'0'
dev_id_bottom:

%define DEV_API_BODY_LENGTH	(dev_api_body_end - dev_api_body_begin)
dev_api_header	db	'$cnp'
dev_api_length	dw	DEV_API_BODY_LENGTH
dev_api_body_begin:
dev_api_regs	dd	0
dev_api_cdecl	dd	0
dev_api_body_end:

dev_tsr_psp	dw	0
org_29		dd	0
org_kbios	dd	0	; (reserved for IBMPC; not implemented yet)
orgcon_strategy	dd	0
orgcon_commands	dd	0
aux_strategy	dd	0
aux_commands	dd	0

reqhdr		dd	0

options_table:
		db	'I'
allow_aux_in	db	1
		db	'O'
enable_aux_out	db	1
		db	'T'
allow_nullchar	db	1		; allow null char inputs from aux
		db	'C'
retry_aux_count	db	0		; 255=infinitely while aux output is in busy
		db	'N'
pass_csi6n	db	0		; report cursor position (ESC[6n)
		db	'X'
pass_xchar	db	0		; XON/XOFF
		db	'J'
home_after_clr	db	1		; move curpos to (0,0) after ESC[2J
;
option_term	db	0, 0

Strategy:
		mov	[cs: reqhdr], bx
		mov	[cs: reqhdr + 2], es
		retf


condev_fallback:
		push	bx
		push	es
condev_fallback2:
		call	call_orgcon_esbx
condev_fallback_exit:
		pop	es
		pop	bx
condev_retf:
		retf

Commands:
		push	bx
		push	es
		les	bx, [cs: reqhdr]
		cmp	byte [es: bx + 2], 20
%ifdef IBMPC
		jne	condev_fallback2
		mov	word [es: bx + 3], 8103h
		jmp	short condev_fallback_exit
%else ; not IBMPC
		je	.unknown
		cmp	byte [es: bx + 2], 12
		ja	condev_fallback2
		pushf
		push	ax
		push	si
		push	ds
		cld
		push	cs
		pop	ds
		mov	al, byte [es: bx + 2]
		cbw
		add	ax, ax
		xchg	ax, si
		call	[si + commands_table]
		pop	ds
		pop	si
		pop	ax
		popf
.pop_esbx_retf:
		pop	es
		pop	bx
		retf
.unknown:
		mov	word [es: bx + 3], 8103h
		jmp	short .pop_esbx_retf

commands_table:
		dw	cmd_unknown		;  0 init
		dw	cmd_fallthru		;  1 media check
		dw	cmd_fallthru		;  2 build bpb
		dw	cmd_ioctl_input		;  3 ioctl input
		dw	cmd_input		;  4 input
		dw	cmd_nd			;  5 non-destructive input no wait
		dw	cmd_input_status	;  6 input status
		dw	cmd_input_flush		;  7 input flush
		dw	cmd_output		;  8 output
		dw	cmd_output_verify	;  9 output with verify
		dw	cmd_output_status	; 10 output status
		dw	cmd_output_flush	; 11 output flush
		dw	cmd_ioctl_output	; 12 ioctl output

cmd_unknown:
		mov	ax, 8103h
		jmp	short cmd_set_status_ax
cmd_just_done:
		mov	ax, 0100h
cmd_set_status_ax:
		mov	word [es: bx + 3], ax
		ret

cmd_input_flush:
		call	kbuf_flush
		jmp	short cmd_fallthru

%ifdef GENDOS
cmd_nd:
		cmp	byte [allow_aux_in], 0
		je	call_orgcon_esbx
		call	push_aux_to_kbuf
		call	kbuf_peek
		jc	call_orgcon_esbx
		mov	[es: bx + 13], al
		jmp	short cmd_just_done

cmd_input:
		call	push_aux_to_kbuf
		push	cx
		push	dx
		push	di
		mov	cx, [es: bx + 18]
		mov	dx, 0100h
		mov	di, [es: bx + 14]
		jcxz	.brk
.lp:
		cmp	byte [allow_aux_in], 0
		je	.get_con
		call	kbuf_peekandget
		jnc	.writeone
.get_con:
		call	con_peek
		jc	.brk
		call	con_get
		jnc	.writeone
		mov	dx, [devio_lasterr]
		jmp	short .brk
.writeone:
		push	es
		mov	es, [es: bx + 16]
		stosb
		pop	es
		loop	.lp
.brk:
		sub	[es: bx + 18], cx
		mov	[es: bx + 3], dx
		pop	di
		pop	dx
		pop	cx
		ret
%else	; end of defined GENDOS
cmd_nd:
cmd_input:
		call	push_aux_to_kbuf
		;jmp	short cmd_fallthru
%endif ; end of not defined GENDOS

cmd_input_status:

cmd_ioctl_input:
cmd_ioctl_output:

cmd_output:
cmd_output_verify:
cmd_output_flush:
cmd_output_status:
;
%endif; end of not defined IBMPC
cmd_fallthru:
call_orgcon_esbx:
		push	si		; workaround for some driver(s)
		push	di		; (see FDOS/kernel/kernel/execrh.asm)
		call	far [cs: orgcon_strategy]
		call	far [cs: orgcon_commands]
		cld			; (to be safe)
		pop	di
		pop	si
		ret


call_aux_esbx:
		test	word [cs: aux_strategy + 2], 0ffffh
		jz	.nodev
		push	si		; workaround for some driver(s)
		push	di		; (see FDOS/kernel/kernel/execrh.asm)
		call	far [cs: aux_strategy]
		call	far [cs: aux_commands]
		cld			; (to be safe)
		pop	di
		pop	si
		ret
.nodev:
		mov	word [es: bx + 3], 81ffh	; return err if the device not exist
		ret


;
; al command
;
; return:
; dx status (word [bx + 3])
; es:bx aux_reqhdr
; ZF status bit15 (0=no error)
;

devio_lasterr	dw	0

call_aux_inout:
		mov	word [cs: devio_callee], call_aux_esbx
		jmp	short call_dev_inout
call_orgcon_inout:
		mov	word [cs: devio_callee], call_orgcon_esbx
call_dev_inout:
		mov	bx, devio_reqhdr
		push	cs
		pop	es
		mov	word [es: bx], 30	; [es:bx + 1] unitno = 0
		mov	[es: bx + 2], al
		mov	word [es: bx + 3], 0
		; note: some character devices (e.g. VJE) use actual pointer
		;       for scratchpad even in NON DESTRUCTIVE INPUT NO WAIT...
		mov	word [es: bx + 14], devio_pad
		mov	[es: bx + 16], cs
		mov	word [es: bx + 18], 1
		mov	word [es: bx + 20], 0
		call	word [cs: devio_callee]
		mov	dx, word [es: bx + 3]
		test	dh, 80h
		jnz	.err
		ret
.err:
		mov	[cs: devio_lasterr], dx
		ret

aux_peek:
		mov	word [cs: devio_callee], call_aux_esbx
		jmp	short devio_peek
con_peek:
		mov	word [cs: devio_callee], call_orgcon_esbx
devio_peek:
		push	bx
		push	dx
		push	es
		mov	al, 5
		call	call_dev_inout
		mov	al, [es: bx + 13]
		jnz	.nochar
		test	dh, 2
		jnz	.nochar
		clc
		jmp	short .exit
.nochar:
		stc
.exit:
		pop	es
		pop	dx
		pop	bx
		ret

aux_get:
		mov	word [cs: devio_callee], call_aux_esbx
		jmp	short devio_get
con_get:
		mov	word [cs: devio_callee], call_orgcon_esbx
devio_get:
		push	bx
		push	dx
		push	es
.try:
		mov	al, 4
		mov	byte [cs: devio_pad], 0
		call	call_dev_inout
		mov	al, [cs: devio_pad]
		jnz	.err
		test	dh, 1
		jz	.try
		clc
		jmp	short .exit
.err:
		stc
.exit:
		pop	es
		pop	dx
		pop	bx
		ret

aux_put:
		push	ax
		mov	word [cs: devio_callee], call_aux_esbx
		mov	ah, [cs: opt_T]
		mov	[cs: devio_put_retry], ah
		jmp	short devio_put.l1
devio_put:
		push	ax
.l1:
		push	bx
		push	cx
		push	dx
		push	es
		xor	cx, cx
		mov	[cs: devio_pad], al
		mov	cl, [cs: devio_put_retry]
.do_put:
		mov	al, 8
		call	call_dev_inout
		jnz	.err
%if 1
;		test	dh, 2
;		jnz	.do_put		; retry if BUSY
		test	dh, 2
		jz	.ok
		jcxz	.err
		cmp	cl, 255
		je	.do_put		; /T255 = initite loop until busy
		loop	.do_put
.err:
		stc
		jmp	short .exit
.ok:
		clc
%else
		clc
		jmp	short .exit
.err:
		stc
%endif
.exit:
		mov	byte [cs: devio_put_retry], 0
		pop	es
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		ret


aux_putready:
		push	ax
		push	bx
		push	dx
		push	es
		mov	al, 10
		call	call_aux_inout
		jnz	.busy			; .err
		test	dh, 2
		jnz	.busy
		clc
		jmp	short .exit
.busy:
		stc
.exit:
		pop	es
		pop	dx
		pop	bx
		pop	ax
		ret

		ALIGN	2

devio_callee	dw	call_aux_esbx
devio_pad	db	0		; in/out buffer for aux/con
devio_put_retry	db	0
devio_reqhdr:
		TIMES 32 db 0


;--------------------------------------
new_29:
		cmp	byte [cs: enable_aux_out], 0
		jne	new_29_to_aux
		jmp	far [cs: org_29]

new_29_to_aux:
		pushf
		call	far [cs: org_29]
;.put_aux:
		push	bx
		push	ds
		push	cs
		pop	ds
		xor	bx, bx
		cmp	bh, [pass_csi6n]	; is zero?
		jne	.c6n_unmatch
		mov	bl, [csi6n_index]
		cmp	al, [bx + csi6n_str]
		je	.c6n_match
.c6n_unmatch:
		mov	[csi6n_index], bh	; 0
		jmp	short .c2j
.c6n_match:
		inc	bl
		cmp	bl, (csi6n_str_end - csi6n_str)
		jb	.c6n_match_l2
		mov	[csi6n_index], bh	; 0
		mov	[csi2j_index], bh
		jmp	short .put_aux_exit
.c6n_match_l2:
		mov	[csi6n_index], bl
.c2j:
		cmp	bh, [home_after_clr]	; is zero?
		je	.c2j_unmatch
		mov	bl, [csi2j_index]
		cmp	al, [bx + csi2j_str]
		je	.c2j_match
.c2j_unmatch:
		test	bl, bl
		jz	.c2j_unmatch_put_al
		push	ax
		push	cx
		push	si
		mov	si, csi2j_str
		mov	cx, bx
.c2j_unmatch_lp:
		lodsb
		call	aux_put
		loop	.c2j_unmatch_lp
		pop	si
		pop	cx
		pop	ax
.c2j_unmatch_put_al:
		mov	[csi2j_index], bh
		cmp	bh, [pass_xchar]	; is zero?
		je	.put_al
		cmp	word [csi2j_index], 0
		jne	.put_aux_exit		; csi2j_index!=0 || csi6n_index!= 0
		cmp	al, 17			; XON
		je	.put_aux_exit
		cmp	al, 19			; XOFF
		je	.put_aux_exit
.put_al:
		call	aux_put
		jmp	short .put_aux_exit
.c2j_match:
		inc	bl
		cmp	bl, (csi2j_str_end - csi2j_str)
		jae	.c2j_clrhome
		mov	[csi2j_index], bl
		jmp	short .put_aux_exit
.c2j_clrhome:
		mov	[csi2j_index], bh	; 0
		mov	bx, csi2j_str
		push	ax
.c2j_clrhome_lp:
		mov	al, [bx]
		call	aux_put
		inc	bx
		cmp	bx, csi2j_clrhome_str_end
		jb	.c2j_clrhome_lp
		pop	ax
.put_aux_exit:
		pop	ds
		pop	bx
		iret

csi2j_str	db	1bh, '[2J'
csi2j_str_end:
		db	1bh, '[1;1H'
csi2j_clrhome_str_end:
;
csi6n_str	db	1bh, '[6n'
csi6n_str_end:

csi2j_index	db	0
csi6n_index	db	0


;--------------------------------------
; helper

get_option_entry:
		mov	bx, options_table
.lp:
		cmp	byte [bx], 0
		je	.not_found
		cmp	al, [bx]
		je	.found
		add	bx, 2
		jmp	short .lp
.found:
		add	bx, 1		; and set CF=0
		ret
.not_found:
		stc
		ret

api_entry_regs_far:
		push	bx
		push	ds
		push	cs
		pop	ds
		cmp	ah, CONPOSITE_API_GET_OPTION
		je	api_get_option
		cmp	ah, CONPOSITE_API_SET_OPTION
		je	api_set_option
api_entry_regs_unsupported:
		stc
		sbb	ax, ax
api_entry_regs_ret:
		pop	ds
		pop	bx
		retf
api_get_option:
		call	get_option_entry
		jc	api_entry_regs_unsupported
		xor	ah, ah
		mov	al, [bx]
		jmp	short api_entry_regs_ret
api_set_option:
		call	get_option_entry
		jc	api_entry_regs_unsupported
		xor	ah, ah
		mov	al, 0ffh	; al = (bool)dl
		add	al, dl
		mov	al, 0
		adc	al, 0
		xchg	al, [bx]
		jmp	short api_entry_regs_ret

; int cdecl far api_entry_cdecl_far(unsigned r_ax, unsigned r_dx, void far *r_esbx)
;
; [bp]		org bp
; [bp+2]	return address (far)
; [bp+6]	r_ax (word)
; [bp+8]	r_dx (word)
; [bp+10]	r_bx (word)
; [bp+12]	sr_es (word)
;
api_entry_cdecl_far:
		push	bp
		mov	bp, sp
		push	bx
		push	dx
		push	es
		mov	ax, [bp + 6]
		mov	dx, [bp + 8]
		les	bx, [bp + 10]
		push	cs
		call	near api_entry_regs_far
		pop	es
		pop	dx
		pop	bx
		pop	bp
		retf

push_aux_to_kbuf:
		cmp	byte [cs: allow_aux_in], 0
		jne	.l0
		ret
.l0:
		push	ax
		push	bx
		push	cx
		push	es
		mov	cx, KEYBUF_MAX
.lp:
		call	kbuf_isfull
		jc	.brk
		call	aux_peek
		jc	.brk
		call	aux_get
		jc	.brk
		cmp	al, 0
		jne	.add
		test	byte [cs: allow_nullchar], 0
		je	.next
.add:
		call	kbuf_add
.next:
		loop	.lp
.brk:
		pop	es
		pop	cx
		pop	bx
		pop	ax
		ret


%ifdef NEC98
;--------------------------------------
; injecting keystrokes into default CON driver (for NEC PC-98 MS-DOS)

%define IOSYS_SEG 0060h
seg_iosys	dw	IOSYS_SEG		; IO.SYS

%define CONBUF_TOP	00c0h
%define CONBUF_MAXLEN	64
%define CONBUF_PTR	0104h
%define CONBUF_LEN	0103h

kbuf_isfull:
		push	ax
		push	ds
		mov	ax, IOSYS_SEG
		mov	ds, ax
		mov	al, CONBUF_MAXLEN - 1
		cmp	al, [CONBUF_LEN]	; CF=1 if [VONBUF_LEN] >= CONBUF_MAXLEN
		pop	ds
		pop	ax
kbuf_flush:
		ret

kbuf_add:
		push	cx
		push	si
		push	di
		push	ds
		push	es
		mov	cx, IOSYS_SEG		; (assume CH=0)
		mov	ds, cx
		mov	es, cx
		mov	cl, [CONBUF_LEN]
		cmp	cl, CONBUF_MAXLEN
		jb	.copy_and_add
		stc				; buffer full (CF=1)
		jmp	short .exit
.copy_and_add:
		mov	di, CONBUF_TOP
		jcxz	.add			; (to be safe)
		mov	si, [CONBUF_PTR]
		rep	movsb
.add:
		stosb
		inc	byte [CONBUF_LEN]
		mov	word [CONBUF_PTR], CONBUF_TOP
		clc				; success (CF=0)
.exit:
		pop	es
		pop	ds
		pop	di
		pop	si
		pop	cx
		ret

;kbuf_peekandget:		; not needed


%else ; not NEC98
;--------------------------------------
; MS-DOS generic input buffer handler

kbuf_body	times (KEYBUF_MAX) db	0
kbuf_body_end:
kbuf_head	dw	kbuf_body
kbuf_tail	dw	kbuf_body
kbuf_count	dw	0

kbuf_flush:
		mov	word [cs: kbuf_head], kbuf_body
		mov	word [cs: kbuf_tail], kbuf_body
		mov	word [cs: kbuf_count], 0
		ret

kbuf_peek:
		cmp	word [cs: kbuf_count], 0
		ja	.peek
		mov	al, 0
		stc
		ret
.peek:
		push	bx
		mov	bx, [cs: kbuf_head]
		mov	al, [cs: bx]
		pop	bx
		clc
		ret

kbuf_peekandget:
		push	bx
		push	cx
		push	ds
		push	cs
		pop	ds
		mov	bx, [kbuf_head]
		mov	cx, [kbuf_count]
		mov	al, [bx]
		jcxz	.empty
		inc	bx
		dec	cx
		cmp	bx, kbuf_body_end
		jb	.get_l2
		mov	bx, kbuf_body
.get_l2:
		mov	[kbuf_count], cx
		mov	[kbuf_head], bx
		clc
		jmp	short .exit
.empty:
		stc
.exit:
		pop	ds
		pop	cx
		pop	bx
		ret

kbuf_add:
		push	bx
		push	cx
		push	ds
		push	cs
		pop	ds
		mov	cx, [kbuf_count]
		cmp	cx, KEYBUF_MAX
		jb	.add
		stc
		jmp	short .exit
.add:
		mov	bx, [kbuf_tail]
		mov	[bx], al
		inc	bx
		inc	cx
		cmp	bx, kbuf_body_end
		jb	.add_l2
		mov	bx, kbuf_body
.add_l2:
		mov	[kbuf_count], cx
		mov	[kbuf_tail], bx
		clc
.exit:
		pop	ds
		pop	cx
		pop	bx
		ret

kbuf_isfull:
		push	ax
		mov	ax, KEYBUF_MAX - 1
		sub	ax, [cs: kbuf_count]	; CF=1 if kbuf_count >= KEYBUF_MAX
		pop	ax
		ret
%endif	; end of not defined NEC98

%ifdef IBMPC
;--------------------------------------
; injecting keystrokes into keyboard bios (for IBM PC)

%define IBM_ENH_KBIOS	10000000b

NewKB_ibmpc:
		test	byte [cs: ibm_kbd_type], IBM_ENH_KBIOS
		jz	.f00
		cmp	ah, 10h
		je	ibm_kb_get
		cmp	ah, 11h
		je	ibm_kb_peek
.f00:
		cmp	ah, 0
		je	ibm_kb_get
		cmp	ah, 1
		je	ibm_kb_peek
newkb_ibmpc_fallback:
		jmp	short ibm_kb_fallback

ibm_kb_get:
		push	ax
		call	push_aux_to_kbuf
		cmp	byte [cs: allow_aux_in], 0
		je	ibm_kb_fallback_ax
		call	kbuf_peekandget
		jc	ibm_kb_fallback_ax
		add	sp, 2		; drop pushed ax
		xor	ah, ah
		iret

ibm_kb_fallback_ax:
		pop	ax
ibm_kb_fallback:
		jmp	far [cs: org_kbios]


ibm_kb_peek:
		push	ax
		call	push_aux_to_kbuf
		cmp	byte [cs: allow_aux_in], 0
		je	ibm_kb_fallback_ax
		call	kbuf_peek
		jc	ibm_kb_fallback_ax
		push	bp
		mov	bp, sp
		; word [bp+0]  bp
		; word [bp+2]  ax
		; dword [bp+4] return cs:ip
		; word [bp+8]  return flags
		and	byte [bp + 8], 0bfh	; clear flags bit6 (ZF=0)
		xor	ah, ah
		mov	[bp + 2], ax
		pop	bp
		pop	ax
		iret

ibm_kbd_type	db	0

%endif	; end of IBMPC

		align	16
tsr_bottom:
;=============================================================================

; machine specific codes 
%ifdef IBMPC
machine_specific_setup_init:
		push	ax
		; check enhanced keyboard function supported
		; see FIND_SYS_TYPE in MS-DOS KEYB source
		; (at https://github.com/microsoft/MS-DOS/blob/main/v4.0/src/CMD/KEYB/COMMSUBS.ASM)
		mov	ah, 92h
		int	16h
		cmp	ah, 80h
		ja	.l2
		or	byte [ibm_kbd_type], IBM_ENH_KBIOS
.l2:
		pop	ax
		clc
		ret

machine_specific_setup_tsr:
		push	ax
		mov	ax, 3516h
		int	21h
		mov	word [org_kbios], bx
		mov	word [org_kbios + 2], es
		mov	ax, 2516h
		mov	dx, NewKB_ibmpc
		int	21h
		pop	ax
		clc
		ret

%elifdef NEC98
machine_specific_setup_init:
machine_specific_setup_tsr:
		clc
		ret
%elifdef GENDOS
machine_specific_setup_init:
machine_specific_setup_tsr:
		clc
		ret
%endif


;--------------------------------------

struc optparam
	.op_char	resb	1
	.op_set		resb	1
	.op_value	resb	1
endstruc

%macro optentry 2
	istruc optparam
	at optparam.op_char, db %1
	at optparam.op_set, db 0
	at optparam.op_value, db %2
	iend
%endmacro

dos_ver		dw	0
env_seg		dw	0
do_verbose	db	1

opttable:
opt_I:		optentry 'I', 1
opt_O:		optentry 'O', 1
opt_T:		optentry 'T', 0
opt_N:		optentry 'N', 1
opt_C:		optentry 'C', 0
opt_X:		optentry 'X', 0
opt_J:		optentry 'J', 1
opttable_end:
%define opttable_count	((opttable_end - opttable) / optparam_size)

opt_Help	db	0
opt_D		db	0
opt_Doff	dw	0
opt_Dseg	dw	0

open_devname	db	'        ', 0
default_devname	db	'AUX', 0

;  [dos_ver] dos version (upper byte:major, lower byte: minor)
;  ds:si device name (8chars, padding with 0x20 space)
;  cx    count of chars of device name (8)
;  dx    attribute mask (repeat until (dev_attr & dx) == dx)
;  df=0  cld
; result
;  es:bx modified
;  cf=0  found (es:bx = device header)
;  cf=1  not found (bx = ffffh)
;
find_chardev:
		push	bp
		mov	bp, dev_name
		call	find_chardev2
		pop	bp
		ret

find_chardev2:
		push	ax
		push	di
		call	get_nul_header
.lp:
		mov	ax, [es: bx + 4]
		and	ax, dx
		cmp	ax, dx
		jne	.next
		mov	di, bx
		add	di, bp
		push	cx
		push	si
		repe	cmpsb
		pop	si
		pop	cx
		jne	.next
		mov	ax, cs
		mov	di, es
		cmp	ax, di		; ignore myself
		jne	.found
.next:
		les	bx, [es: bx]
		cmp	bx, 0ffffh
		jne	.lp
		stc
		jmp	short .exit
.found:
		clc
.exit:
		pop	di
		pop	ax
		ret

find_conposit:
		push	ax
		push	cx
		push	dx
		push	si
		push	bp
		mov	si, dev_id
		mov	bp, si
		mov	dx, 8000h
		mov	cx, dev_id_bottom - dev_id
		call	find_chardev2
		pop	bp
		pop	si
		pop	dx
		pop	cx
		pop	ax
		ret

get_nul_header:
		push	ax
		mov	ah, 52h
		int	21h
		mov	ax, 0017h
		cmp	word [dos_ver], 0300h
		jb	.l2
		mov	al, 28h
		je	.l2
		mov	al, 22h
.l2:
		add	bx, ax
		pop	ax
		ret

hook_condev:
		mov	ah, 52h
		int	21h
		les	bx, [es: bx + 12]	; get default CON device hdr
		mov	ax, cs
		cmp	ax, [es: bx + 14]	; check segment of CON
		jne	.l2
		stc				; maybe myself...
		ret
.l2:
		mov	ax, [es: bx + 6]
		mov	[orgcon_strategy], ax
		mov	[orgcon_strategy + 2], es
		mov	ax, [es: bx + 8]
		mov	[orgcon_commands], ax
		mov	[orgcon_commands + 2], es
		;
		; todo:
		; when install on command (wirhout adddrv), walk SFT tables (to replace CON device with the new one)
		;
		clc
		ret


;
mygetopt_next:
		inc	bx
mygetopt:
		mov	al, [es: bx]
		call	is_delim
		je	mygetopt_next
		call	is_crlf
		jne	.l1
.exit:
		ret
.l1:
		cmp	al, '-'
		je	.opt
		cmp	al, '/'
		je	.opt
.next:
		call	skip_token
		jmp	short mygetopt
.opt:
		inc	bx
		mov	al, [es: bx]
		cmp	al, '?'
		jne	.opt_l2
		mov	byte [opt_Help], 1
		jmp	short .next
.opt_l2:
		call	toupper
		cmp	al, 'D'
		je	.opt_d
		push	cx
		push	si
		mov	si, opttable
		mov	cx, opttable_count
		call	get_optparam_u8
		pop	si
		pop	cx
		jnc	.opt_end
.opt_end:
		jmp	short .next
;
.opt_d:
		inc	bx
		mov	al, [es: bx]
		cmp	al, ':'
		jne	.opt_d2
		inc	bx
.opt_d2:
		cmp	al, '='
		jne	.opt_d3
		inc	bx
.opt_d3:
		mov	al, [es: bx]
		call	is_delimcrlf
		je	.next

.lopt_d:
		mov	byte [opt_D], 1
		mov	[opt_Doff], bx
		mov	[opt_Dseg], es
		call	skip_token
.lopt4:
		jmp	short .next


skip_token_0:
		inc	bx
skip_token:
		mov	al, [es: bx]
		call	is_delimcrlf
		jne	skip_token_0
		ret

toupper:
		cmp	al, 'a'
		jb	.exit
		cmp	al, 'z'
		ja	.exit
		sub	al, 'a' - 'A'
.exit:
		ret

is_crlf:
		cmp	al, 13
		je	is_crlf_exit
		cmp	al, 10
is_crlf_exit:
		ret

is_delimcrlf:
		call	is_crlf
		je	is_crlf_exit
is_delim:
		cmp	al, ' '
		je	.exit
		cmp	al, 9
		je	.exit
		cmp	al, 0
.exit:
		ret


is_digit:
		cmp	al, '0'
		jb	.exit
		cmp	al, '9'
		ja	.exit
.digit:
		test	al, 0		; ZF=1
.exit:
		ret

get_decimal_u8:
		push	dx
		xor	dx, dx
		mov	ah, 10
.lp:
		mov	al, [es: bx]
		sub	al, '0'
		jb	.normal_brk
		cmp	al, 9
		ja	.normal_brk
		xchg	ax, dx
		mul	dh
		add	al, dl
		adc	ah, 0
		cmp	ax, 00ffh
		ja	.overflow
		xchg	ax, dx
		inc	bx
		jmp	short .lp
.overflow:
		stc
		jmp	short .exit
.normal_brk:
		mov	ax, dx
		clc
.exit:
		pop	dx
		ret

; es:bx pointer to cmdline
; ds:si pointer to optparams
; cx    count of optparams
get_optparam_u8:
		mov	al, [es: bx]
		call	toupper
		cmp	al, 0
		je	.exit
		jcxz	.exit
.lp:
		cmp	al, [si]	; [si + optparam.op_char]
		je	.match
		add	si, optparam_size
		loop	.lp
.exit:
		pushf
		call	skip_token
		popf
		ret
.match:
		inc	bx
		mov	al, [es: bx]
		cmp	al, '-'
		jne	.m_l2
		mov	al, 0
		jmp	short .set
.m_l2:
		call	is_delimcrlf
		je	.set1
		cmp	al, '+'
		jne	.m_l3
.set1:
		mov	al, 1
		jmp	short .set
.m_l3:
		call	is_digit
		jne	.m_l4
		call	get_decimal_u8
		jc	.paramerr
		jmp	short .set
.set:
		mov	byte [si + optparam.op_set], 1
		mov	[si + optparam.op_value], al
		clc
.m_l4:
.paramerr:
.m_end:
		jmp	short .exit


put_open_devname:
		push	ax
		push	si
		mov	si, open_devname
.lp:
		lodsb
		cmp	al, ' '
		jbe	.exit
		call	put_c
		jmp	short .lp
.exit:
		pop	si
		pop	ax
		ret

put_c:
		push	ax
		push	dx
		mov	ah, 2
		mov	dl, al
		int	21h
		pop	dx
		pop	ax
		ret

put_decimal_u8:
		push	ax
		push	dx
		mov	dx, 10		; dh = 0, dl = 10
.lp:
		xor	ah, ah
		div	dl
		push	ax
		inc	dh
		cmp	al, 0
		jne	.lp
.put:
		pop	ax
		mov	al, ah
		add	al, '0'
		call	put_c
		dec	dh
		jnz	.put
		pop	dx
		pop	ax
		ret


copy_open_devname:
		push	ax
		push	si
		push	di
		push	ds
		push	es
		mov	di, open_devname
		push	cs
		pop	es
		mov	si, [opt_Doff]
		mov	ax, [opt_Dseg]
		test	ax, ax
		jnz	.l2
		mov	si, default_devname
		mov	ax, cs
.l2:
		mov	ds, ax
		mov	ah, 8
.lp:
		lodsb
		cmp	al, ' '
		jbe	.brk
		cmp	al, '.'
		je	.brk
		call	toupper
		stosb
		dec	ah
		jne	.lp
.brk:
		pop	es
		pop	ds
		pop	di
		pop	si
		pop	ax
		ret


put_msg_0:
		push	ds
		push	cs
		pop	ds
		mov	ah, 9
		int	21h
		pop	ds
		ret

put_msg_n:
		cmp	byte [cs: do_verbose], 0	; do not print in quiet mode
		ja	put_err_n
		ret
put_err_n:
		push	ax
		push	dx
		call	put_msg_0
		mov	dx, msgCRLF
		call	put_msg_0
		pop	dx
		pop	ax
		ret


get_proper_dos_version:
		push	bx
		push	cx
		mov	ax, 3000h
		int	21h
		cmp	al, 10
		jne	.l2
		mov	ax, 1e03h	; OS/2 1.x : assume DOS 3.30
.l2:
		mov	cx, bx		; ch = OEM code
		mov	bx, ax
		mov	ax, 3306h
		push	dx
		int	21h
		pop	dx
		mov	ax, bx
		cmp	ax, 0007h
		jne	.l3
		test	ch, ch		; OEM == 0 (IBM) ?
		jnz	.l3
		mov	ax, 2806h	; IBM PC DOS 7/2000 : assume DOS 6.40
.l3:
		cmp	al, 20
		jne	.l4
		mov	ax, 0005h	; OS/2 V2+ MVDM : assume DOS 5.0
.l4:
		xchg	al, ah		; upper=major, lower=minor
		pop	cx
		pop	bx
		ret

;
device_api_entry	dd	0

set_device_options:
		cmp	word [device_api_entry + 2], 0
		jne	.l2
		stc
		ret
.l2:
		push	ax
		push	bx
		push	cx
		push	dx
		mov	bx, opttable
		mov	cx, opttable_count
.lp:
		cmp	byte [bx + optparam.op_set], 0
		je	.next
		mov	ah, CONPOSITE_API_SET_OPTION
		mov	al, [bx + optparam.op_char]
		mov	dl, [bx + optparam.op_value]
		call	far [device_api_entry]
.next:
		add	bx, optparam_size
		loop	.lp
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		clc
		ret

put_device_options:
		cmp	word [device_api_entry + 2], 0
		jne	.l1
		stc
		ret
.l1:
		cmp	byte [do_verbose], 0
		je	.exit
		push	ax
		push	bx
		push	cx
		push	dx
		mov	bx, opttable
		mov	cx, opttable_count
.lp:
		mov	ah, CONPOSITE_API_GET_OPTION
		mov	al, [bx + optparam.op_char]
		call	far [device_api_entry]
		jc	.next
		push	ax
		mov	al, ' '
		call	put_c
		mov	al, '/'
		call	put_c
		mov	al, [bx + optparam.op_char]
		call	put_c
		pop	ax
		call	put_decimal_u8
.next:
		add	bx, optparam_size
		loop	.lp
		pop	dx
		pop	cx
		pop	bx
		pop	ax
.exit:
		clc
		ret

;--------------------------------------
; initialize (device & app)
init_common:
		call	get_proper_dos_version
		mov	[dos_ver], ax
		mov	word [dev_api_regs], api_entry_regs_far
		mov	[dev_api_regs + 2], cs
		mov	word [dev_api_cdecl], api_entry_cdecl_far
		mov	[dev_api_cdecl + 2], cs
		call	mygetopt
		call	copy_open_devname
		call	machine_specific_setup_init
		ret

init_device_tsr:
		mov	word [device_api_entry], api_entry_regs_far
		mov	[device_api_entry + 2], cs
		call	find_conposit
		jc	.l2
		mov	dx, errAlreadyExist
		mov	ax, 1
		ret
.l2:
		mov	si, open_devname
		mov	cx, 8
		mov	dx, 8000h
		call	find_chardev
		jnc	.l3
		mov	dx, errDevNot
		call	put_msg_0
		call	put_open_devname
		mov	dx, errspcNotExist
		mov	ax, 1
		ret
.l3:
		mov	ax, [es: bx + 6]
		mov	[aux_strategy], ax
		mov	[aux_strategy + 2], es
		mov	ax, [es: bx + 8]
		mov	[aux_commands], ax
		mov	[aux_commands + 2], es

		call	set_device_options
		call	hook_condev
		call	machine_specific_setup_tsr

		mov	ax, 3529h
		int	21h
		mov	[org_29], bx
		mov	[org_29 + 2], es
		mov	dx, new_29
		mov	ax, 2529h
		int	21h

		xor	ax, ax
		ret


Init_Commands:
		push	ax
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	ds
		push	es

		push	cs
		pop	ds
		les	bx, [reqhdr]
		les	bx, [es: bx + 18]
.cmd_lp:
		mov	al, [es: bx]
		inc	bx
		cmp	al, ' '
		ja	.cmd_lp
		cmp	al, 0		; NEC PC-98 MS-DOS : sepatrator of device arguments from device filename
		je	.cmd_le
		dec	bx
.cmd_le:
		call	init_common
		call	init_device_tsr
		test	al, al
		jnz	.err
		mov	dx, msgInstalled
		call	put_msg_n
		mov	word [dev_commands], Commands
		lds	bx, [reqhdr]
		mov	word [bx + 3], 0100h
		mov	byte [bx + 13], 1
		mov	word [bx + 14], tsr_bottom
		mov	word [bx + 16], cs
		jmp	short .exit
.err:
		;mov	dx, errNotInstalled
		call	put_err_n
		les	bx, [reqhdr]
		xor	ax, ax
		mov	word [es: bx + 3], 810ch
		mov	[es: bx + 13], al
		mov	[es: bx + 14], ax
		mov	[es: bx + 16], cs
		cmp	word [dos_ver], 0500h
		jae	.exit
		mov	[dev_attr], ax		; be a block device (for older DOS 2.0~4.0)
		mov	[dev_name], al		; clear number of units (block device)
		mov	[es: bx + 20], al	; (to be safe)
.exit:
		pop	es
		pop	ds
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		retf


..start:
Init_App:
		push	cs
		pop	ds
		mov	[dev_tsr_psp], es
		xor	ax, ax
		xchg	ax, [es: 002ch]
		mov	[env_seg], ax
		mov	byte [es: 00ffh], 13		; to be safe
		mov	bx, 0081h
		call	init_common

		call	find_conposit
		mov	dx, errNotInstalled
		jnc	.l2
.err:
		call	put_err_n
		mov	al, 11
		jmp	short .exit
.l2:
		mov	ax, [es: bx + dev_api_regs]
		mov	[device_api_entry], ax
		mov	ax, [es: bx + dev_api_regs + 2]
		mov	[device_api_entry + 2], ax
		call	set_device_options
		cmp	byte [do_verbose], 0
		je	.noerr
		mov	dx, msgCureentOpts
		call	put_msg_0
		call	put_device_options
		mov	dx, msgNull
		call	put_msg_n
.noerr:
		mov	al, 0
.exit:
		mov	ah, 4ch
		int	21h

msgCRLF		db	13, 10
msgNull		db	'$'
msgCureentOpts	db	'Current options:$'
msgInstalled	db	'CONPOSIT installed$'
errAlreadyExist	db	'ERROR: CONPOSIT already installed$'
errNotInstalled	db	'ERROR: CONPOSIT not installed$'
errDevNot	db	'ERROR: device $'
errspcNotExist	db	' not exist$'

msgOpening	db	'CONPOSIT'
%ifdef PLATFORM_STR
		db	' for '
		db	PLATFORM_STR
%endif
		db	' (built at ', __DATE__, ')'
		db	'$'

SEGMENT _STACK
		resw	256
