;
; AboveRTC version 0.01
; Copyright (c) 1985 Intel Corporation
;
; Get or set time in Real-time clock chip of Intel Above Board ISA
; multifunction card
;
; This program is derivative work from disassembly of the original
; Intel clock.sys driver
;
; Created by Adrian Oboroc
;
; To build, use MASM 5.1:
;   masm.exe /V /Z /ZI abovertc,,,;
;   link.exe abovertc;
;
; TODO: undecided on coding style, need to find something good to
; follow/emulate
;

.model small
.stack
.data
IFDEF DEBUG
banner	DB	"DEBUG Detecting Intel Above Board RTC",13,10,"$"
ELSE
banner	DB	"Detecting Intel Above Board RTC",13,10,"$"
ENDIF
found	DB	"Found!",13,10,"$"
nfound	DB	"Not found.",13,10,"$"

RTC_CONTROL	EQU	2CDh

print	MACRO	msg
	mov	ax,SEG msg
	mov	ds,ax
	mov	dx,OFFSET msg
	mov	ah,09h
	int	21h
	ENDM

; quit to dos macro
; takes optional argument - return error code (0-255)
quit	MACRO	errcode
	IFNB	<errcode>	; if macro was passed an argument
	mov	ah,4ch
	mov	al,errcode
	ELSE
	mov	ax,4c00h
	ENDIF
	int 21h
	ENDM

.code
_start:
	print	banner

	xor	bl,bl

loop1:	mov	dx,RTC_CONTROL
	in	al,dx
	and	al,0Eh
	out	dx,al

        ; I/O delay
	nop
	nop
	nop

	in	al,dx
	or	al,1
	out	dx,al
        inc	bl
	mov	cx,100

loop2:	in	al,dx
	test	al,2
	jz	rtc_found
	loop	loop2

	cmp	bl,2
	jnz	loop1

	print	nfound
	quit	100

rtc_found:
	print	found

; >>> put something here <<<

	quit

end	_start
