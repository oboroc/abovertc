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

.model small
.stack
.data
banner	db "Detecting Intel Above Board RTC",13,10,"$"
found	db "Found!",13,10,"$"
nfound	db "Not found.",13,10,"$"

RTC_CONTROL	equ	2CDh

print MACRO msg
	mov ax,SEG msg
	mov ds,ax
	mov dx,OFFSET msg
	mov ah,09h
	int 21h
ENDM

.code
_start:

	print	banner

	call	rtc_detect

	; quit to dos
	mov ax,4c00h
	int 21h


rtc_detect PROC NEAR
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
	jmp	rtc_not_found

rtc_not_found:
	print	nfound
	ret

rtc_found:
	print	found
	ret

rtc_detect ENDP

end _start
