%if 0
;----------------------------------------------------------------------------

DEFSPEED - configure AUX speed with default configuration (for NEC PC-98 MS-DOS with RSDRV.SYS)

author: lpproj (https://github.com/lpproj/)

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

; to enable aux1 and aux2 for PC-9861K/PC-9801-101... (not tested)
; %define ENABLE_AUX1 1


		CPU	8086
		BITS	16

; segment order
SEGMENT _TEXT align=16 public class=CODE
SEGMENT _STACK align=16 stack class=STACK	; note: the segment name "_STACK" and the qualifier "stack" are very important for the linker...
GROUP DGROUP  _TEXT _STACK

SEGMENT _TEXT

dev_header:
		dd	-1
dev_attr	dw	8000h
		dw	Strategy
dev_commands	dw	Init_Commands
dev_name	db	'$SPEED$$'

reqhdr		dd	0
seg_iosys	dw	0060h

Strategy:
		mov	[cs: reqhdr], bx
		mov	[cs: reqhdr + 2], es
		retf

put_c_0:
		push	dx
		mov	ah, 2
		mov	dl, al
		int	21h
		pop	dx
		ret

put_c:
		push	ax
		call	put_c_0
		pop	ax
		ret
put_sp:
		push	ax
		mov	al, ' '
		call	put_c_0
		pop	ax
		ret
put_n:
		push	ax
		mov	al, 13
		call	put_c_0
		mov	al, 10
		call	put_c_0
		pop	ax
		ret

put_s_si:
		push	ax
		push	dx
		mov	ah, 9
		mov	dx, si
		int	21h
		pop	dx
		pop	ax
		ret

%if 0
put_h16:
		xchg	al, ah
		call	put_h8
		xchg	al, ah
put_h8:
		push	ax
		shr	al, 1
		shr	al, 1
		shr	al, 1
		shr	al, 1
		call	put_h4s
		pop	ax
put_h4s:
		push	ax
		and	al, 0fh
		add	al, '0'
		cmp	al, '9'
		jbe	.l2
		add	al, 'A' - '9' - 1
.l2:
		call	put_c
		pop	ax
		ret

%endif


get_dos_aux_config:
		cmp	word [cs: dos_ver], 031eh	; check DOS 3.3 or later
		jb	.d31
		cmp	al, 0
		je	.d31
		push	bx
		push	cx
		push	dx
		xor	bx, bx
		cmp	al, 10h
		jae	.after_call
		mov	cl, 4
		mov	dl, al
		shl	dl, cl
		add	dl, 6
		mov	ax, -1
		mov	cl, 0eh
		int	0dch
.after_call:
		mov	al, bh
		mov	ah, bl
		pop	dx
		pop	cx
		pop	bx
		jmp	short .exit
.d31:
		push	ds
		mov	ds, [seg_iosys]
		cmp	al, 0
		jne	.l1
		mov	ax, [0068h]
		jmp	short .exit0_ds
		pop	ds
		ret
.l1:
		cmp	byte [dos_ver + 1], 3
		jb	.err
		cmp	al, 1
		jne	.l2
		mov	ax, [17eeh]
		jmp	short .exit_x
.l2:
		cmp	al, 2
		jne	.l3
		mov	ax, [17f0h]
		jmp	short .exit_x
.l3:
%if 0
		cmp	al, 3
		jne	.l4
		mov	ax, [17f2h]
		jmp	short .exit_x
.l4:
%endif
.err:
		xor	ax, ax
.exit_x:
		xchg	al, ah
.exit0_ds:
		pop	ds
.exit:
		cmp	ax, 1		; set CF=1 if ax == 0
		ret

set_dos_aux_config:
		push	bx
		push	cx
		push	dx
		mov	cl, 4
		mov	dl, al
		shl	dl, cl
		add	dl, 1
		call	get_dos_aux_config
		jc	.exit
		push	ax
		and	ax, 0fffh
		mov	bl, ah
		mov	bh, al
		mov	cl, 0eh
		mov	ax, -1
		int	0dch
		add	ax, 0ffffh	; set CF=1 if ax != 0
		pop	ax
.exit:
		pop	dx
		pop	cx
		pop	bx
		ret


check_rsdrv:
		mov	ax, [seg_iosys]
		cmp	byte [dos_ver + 1], 3
		jb	.found
		push	ds
		mov	ds, ax
		mov	ax, [1802h]
		pop	ds
		test	ax, ax
		stc
		jz	.exit
.found:
		clc
.exit:
		ret

put_speed_aux_n:
		push	ax
		mov	si, port_aux3
		cmp	al, 3
		je	.put_port
		mov	si, port_aux2
		cmp	al, 2
		je	.put_port
		cmp	al, 1
		mov	si, port_aux1
		je	.put_port
		mov	si, port_aux
.put_port:
		call	get_dos_aux_config
		jnc	.l1
		mov	si, port_unsupported
		call	put_s_si
		stc
		jmp	short .exit
.l1:
		mov	dx, ax
		call	put_s_si
		call	put_sp
		xor	bx, bx
		mov	bl, dh
		and	bl, 0fh
		add	bx, bx
		mov	si, [bx + bps_table]
		call	put_s_si
		mov	si, bits_p
		call	put_s_si
		mov	al, dl
		shr	al, 1
		shr	al, 1
		and	al, 3
		add	al, '5'
		call	put_c
		;xor	bx, bx
		mov	bl, dl
		and	bl, 00110000b
		shr	bx, 1
		shr	bx, 1
		shr	bx, 1
		mov	si, [bx + parity_table]
		call	put_s_si
		;xor	bx, bx
		mov	bl, dl
		and	bl, 11000000b
		mov	cl, 5
		shr	bx, cl
		mov	si, [bx + stop_table]
		call	put_s_si
		mov	si, xflow_none
		test	bl, 1
		jz	.put_xflow
		mov	si, xflow_xon
.put_xflow:
		call	put_s_si
		clc
.exit:
		pop	ax
		ret


;--------------------------------------

dos_ver		dw	0

init_common:
		push	bx
		push	cx
		push	dx
		push	si
		mov	ax, 3000h
		int	21h
		xchg	al, ah
		mov	[dos_ver], ax
		call	check_rsdrv
		mov	si, errNoRSDRV
		jc	.err
		; aux
		mov	si, msgAuxSpeed
		call	put_s_si
		mov	al, 0
		call	put_speed_aux_n
		call	put_n
		mov	cl, 0ah
		; for hi-res mode (undoc1:int DCh Function 0Ah)
		and	ah, 0fh
		mov	dh, al
		mov	dl, ah
		mov	al, 2
		cmp	al, [dos_ver + 1]
		sbb	ax, ax			; ax = (dos 3 or later) ? -1 : 0
		int	0dch
		mov	si, errRSsetup
		add	ax, 1			; error if ax == -1
		jc	.err
%ifdef ENABLE_AUX1
		; aux1 (DOS 3.3+ RSDRV with PC-9861K)
		mov	al, 1
		call	set_dos_aux_config
		jc	.aux2
		mov	al, 1
		call	put_speed_aux_n
		call	put_n
.aux2:
		; aux2 (DOS 3.3+ RSDRV with PC-9861K)
		mov	al, 2
		call	set_dos_aux_config
		jc	.aux3
		mov	al, 2
		call	put_speed_aux_n
		call	put_n
.aux3:
%endif
.aux_done:
		clc
		jmp	short .exit
.err:
		push	si
		mov	si, errPrefix
		call	put_s_si
		pop	si
		call	put_s_si
		call	put_n
		stc
.exit:
		pop	si
		pop	dx
		pop	cx
		pop	bx
		ret

Init_Commands:
		push	ax
		push	bx
		push	ds
		push	es

		push	cs
		pop	ds
		les	bx, [reqhdr]
		mov	word [es: bx + 3], 0100h
		mov	byte [es: bx + 13], 0
		mov	word [es: bx + 14], 0
		mov	word [es: bx + 16], cs
		call	init_common
		cmp	word [dos_ver], 0500h		; not considered OS/2 1.x
		jae	.exit
		xor	ax, ax
		mov	[dev_attr], ax
		mov	[dev_name], al
		mov	word [es: bx + 3], 810ch
.exit:
		pop	es
		pop	ds
		pop	bx
		pop	ax
		retf

..start:
		push	cs
		pop	ds
		call	init_common
		mov	ax, 4c00h
		adc	al, 0
		int	21h


;--------------------------------------
parity_table:
		dw	parity_none
		dw	parity_odd
		dw	parity_none
		dw	parity_even

stop_table:
		dw	stop_unknown
		dw	stop_1
		dw	stop_15
		dw	stop_2

bps_table:
		dw	bps_unknown
		dw	bps_75
		dw	bps_150
		dw	bps_300
		dw	bps_600
		dw	bps_1200
		dw	bps_2400
		dw	bps_4800
		dw	bps_9600
		dw	bps_19200
		dw	bps_38400	; just a stub (unsupported)
		dw	bps_57600	; ditto
		dw	bps_115200	; ditto
		dw	bps_unknown
		dw	bps_unknown
		dw	bps_unknown

port_unsupported	db	'(RS232C回線が存在しないか、初期化されていません)$'
port_aux	db	'  RS232C-0$'
port_aux1	db	'  RS232C-1$'
port_aux2	db	'  RS232C-2$'
port_aux3	db	'  RS232C-3$'
bits_p		db	' BITS-$'

bps_unknown	db	'???$'
bps_75		db	'75$'
bps_150		db	'150$'
bps_300		db	'300$'
bps_600		db	'600$'
bps_1200	db	'1200$'
bps_2400	db	'2400$'
bps_4800	db	'4800$'
bps_9600	db	'9600$'
bps_19200	db	'19200$'
bps_38400	db	'38400$'
bps_57600	db	'57600$'
bps_115200	db	'115200$'

parity_none	db	' PARITY-NONE$'
parity_odd	db	' PARITY-ODD$'
parity_even	db	' PARITY-EVEN$'

stop_unknown	db	' STOP-0$'
stop_1		db	' STOP-1$'
stop_15		db	' STOP-1.5$'
stop_2		db	' STOP-2$'

xflow_none	db	' NONE$'
xflow_xon	db	' XON$'

msgAuxSpeed	db	'現在のSPEED設定:', 13, 10, '$'
errPrefix	db	'ERROR: $'
errRSsetup	db	'設定失敗、もしくは'
errNoRSDRV	db	'RSDRV.SYSがインストールされていません$'

prog_bottom:
;--------------------------------------
SEGMENT _STACK
		resw	256

