;
; clock.asm - a DOS clock driver for Intel Above Board PS/PC multi-function card
;
; Copyright (c) 1985 Intel Corporation
;
; Disassembled using Ghidra
;
; Build with MASM 5.10:
;  masm clock;
;  link clock;
;  exe2bin clock.exe clock.sys
;

code		segment

		assume cs:code,ds:code,es:code,ss:code

		org 0

; DOS driver header

;   next driver offset and segment, for a single driver sys file it should be 0FFFFh
ndrv_ofs	dw	-1
ndrv_seg	dw	-1

;   DOS driver attributes:
CURRENT_STDOUT	equ	0000000000000001b	; current standard output device
CURRENT_STDIN	equ	0000000000000010b	; current standard input device
CURRENT_CLOCK	equ	0000000000000100b	; current clock device
CURRENT_NUL	equ	0000000000001000b	; current NUL device
						; bits 4-10 are reserved, should be 0
MEDIA_CHANGE	equ	0000100000000000b	; media change recognized (DOS 3.0+?)
						; bit 12 is reserved, should be 0
OUTPUT_UNTIL	equ	0010000000000000b	; "output until instructed" for character device driver
NON_IBM		equ	0010000000000000b	; "non-IBM format" for block device driver
IOCTL		equ	0100000000000000b	; IOCTL support
CHAR_DRV	equ	1000000000000000b	; 1 - characted device driver, 0 - block device driver

drv_attr	dw	CURRENT_NUL + CHAR_DRV

;   offset to strategy routine
		dw	offset strategy

;   offset to interrupt routine
		dw	offset interrupt

;   driver name for character device driver or number of devices supported for block device driver
driver_name	db	8 dup (0)
; end of DOS driver header

; misc constants
RTC_OK		equ	0FFh
RTC_BAD		equ	0
NIBBLE		equ	0Fh	; 4 lower bits in a byte

RTC_SEC1	equ	2C0h
RTC_SEC10	equ	2C1h
RTC_MIN1	equ	2C2h
RTC_MIN10	equ	2C3h
RTC_HOUR1	equ	2C4h
RTC_HOUR10	equ	2C5h
RTC_DAY1	equ	2C6h
RTC_DAY10	equ	2C7h
RTC_MONTH1	equ	2C8h
RTC_MONTH10	equ	2C9h
RTC_YEAR1	equ	2CAh
RTC_YEAR10	equ	2CBh


; Strategy routine - DOS calls it to initialize the driver and then repeatedly before
; each subsequent I/O request from the driver interrupt routine.
; DOS passes the address to a data structure in ES:BX. It describes the requested operation
; for driver to perform. The address is stores and control is returned to DOS immediately.
; DOS then calls the interrupt routine of the driver to execute the operation.
strategy	proc	far
		mov	cs:request,bx		; store offset and
		mov	cs:request + 2,es	; segment of the pointer to request header
         	ret
request	dw	0,0				; pointer to request header provided by DOS
; The request data structure passed by DOS to strategy routine is at least 13 bytes
; and tells the driver what it should do. Some operations can use additional data past
; 13 bytes. Here is the data structure format:
;   +00h - data block length in bytes		(word)
;   +01h - device number in commnunication	(word)
;   +02h - command code				(word)
;   +05h - reserved				(qword)
;   +0Dh - media descriptor			(byte)
;   +0Eh - buffer offset address		(word)
;   +10h - buffer segment address		(word)
;   +12h - number				(word)
;   +14h - starting sector			(qword)
strategy	endp


; Interrupt routine - DOS calls it immediately after calling the strategy routine.
; It first pushes to stack all the registers that may get modified by the driver routines.
; Next it gets the command code from the data block + 2 and then calls required
; command routine. After the command routine returns, interrupt routine sets
; status field in request header and pops register values from the stack.
; It then returns control to DOS.
interrupt	proc	far
		; clear interrupt flag (no interrupts until sti)
		cli			
		mov	word ptr cs:[store_ss],ss
		mov	word ptr cs:[store_sp],sp
		mov	ax,cs
		; set ss to driver code segment
		mov	ss,ax		
		lea	sp,[stack_bottom]
		sti
		; push flags
		pushf			
		; this is wonky, as we just messed with ax above to copy cs to ss
		push	ax		
		push	bx
		push	cx
		push	dx
		push	si
		push	di
		push	bp
		push	ds
		push	es
		mov	ax,cs
		; set ds to driver code segment
		mov	ds,ax
		les	bx,dword ptr [request]
		; read command code from DOS request header
		mov	al,byte ptr es:[bx + 02h]
		cmp	al,15
		jbe	no_bump_al	; jump if al is lower or equal to 15 (0Fh)
		mov	al,10h		; if al > 15 (0Fh), set it to 16 (10h)
no_bump_al:	xor	ah,ah		; ah = 0
		shl	ax,1		; convert routine number to offset: ax = ax * 2
		mov	si,ax
		call	word ptr [si + jump_table]
		pop	es
		pop	ds
		pop	bp
		pop	di
		pop	si
		pop	dx
		pop	cx
		pop	bx
		pop	ax
		popf
		cli
		mov	ss,word ptr cs:[store_ss]
		mov	sp,word ptr cs:[store_sp]
		sti
		ret
interrupt	endp


; jump table for DOS driver functions
jump_table	dw	init
		dw	dummy
		dw	dummy
		dw	dummy
		dw	read
		dw	dummy
		dw	dummy
		dw	dummy
		dw	write
		dw	write
		dw	dummy
		dw	dummy
		dw	dummy
		dw	dummy
		dw	dummy
		dw	dummy
		dw	dummy
; jump table end

; this should be at 94h offset
read		proc	near
		les	bx,dword ptr [request]
		call	rtc_get_time
		les	bx,es:[bx + 0Eh]		; request header +0Eh - buffer offset address
		mov	al,[second]
		mov	byte ptr es:[bx + 05h],al	; request header +05h - reserved?
		mov	al,[minute]
		mov	byte ptr es:[bx + 02h],al	; request header +02h - command code
		mov	al,[hour]
		mov	byte ptr es:[bx + 03h],al	; request header +03h - status
		mov	al,0
		mov	byte ptr es:[bx + 04h],al	; request header +04h - reserved?
		call	rtc_get_date
		les	bx,dword ptr [request]
		cmp	word ptr es:[bx + 03h],100h
		jnz	l0cc
		call	set_days_total
l0cc:		les	bx,dword ptr [request]
		les	bx,es:[bx + 0Eh]		; request header +0Eh - buffer offset address
		mov	dx,word ptr [days_total]
		dec	dx
		mov	word ptr es:[bx],dx
		ret
read		endp


; this should be at 0DDh offset
rtc_detect	proc	near
		xor	bl,bl

l0df:		mov	dx,02CDh
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

l0f2:		in	al,dx
		test	al,2
		jz	rtc_found
		loop	l0f2

		cmp	bl,2
		jnz	l0df
		jmp	rtc_not_found

rtc_not_found:	mov	byte ptr [rtc_status],RTC_BAD
		nop
		ret

rtc_found:	mov	byte ptr [rtc_status],RTC_OK
		nop
		ret
rtc_detect	endp


; this should be at 10Fh offset
rtc_init	proc	near
		mov	dx,2CDh
		in	al,dx
		and	al,0Eh
		out	dx,al
		ret
rtc_init	endp


; this should be at 117h offset
rtc_get_time	proc	near
		call	rtc_detect
		mov	dx,RTC_SEC1
		in	al,dx
		and	al,NIBBLE
		cmp	al,9
		jbe	sec1
		jmp	bad_time
; set lower digit of second, for example for 47 seconds it will be 7
sec1:		mov	[second],al

		mov	dx,RTC_SEC10
		in	al,dx
		and	al,NIBBLE
		cmp	al,5
		jbe	sec10
		jmp	bad_time
; set higher digit of second, for example for 47 seconds, al is 4
sec10:		mul	byte ptr [ten]
		add	byte ptr [second],al
; now al is seconds from 0 to 59

		mov	dx,RTC_MIN1
		in	al,dx
		and	al,NIBBLE
		cmp	al,9
		jbe	min1
		jmp	bad_time
min1:		mov	[minute],al
		mov	dx,RTC_MIN10
		in	al,dx
		and	al,NIBBLE
		cmp	al,5
		jbe	min10
		jmp	bad_time
min10:		mul	byte ptr [ten]
		add	byte ptr [minute],al
; now al is minutes from 0 to 59

		mov	dx,RTC_HOUR1
		in	al,dx
		and	al,NIBBLE
		cmp	al,9
		jbe	hour1
		jmp	bad_time
hour1:		mov	[hour],al

		mov	dx,RTC_HOUR10
		in	al,dx
		and	al,NIBBLE
		cmp	al,2
		jbe	hour10
		jmp	bad_time
hour10:		mul	byte ptr [ten]
		add	byte ptr [hour],al
		mov	ah,byte ptr [hour]
		cmp	ah,24
		ja	bad_time
; now al is hour from 0 to 23

		call	rtc_init
		les	bx,dword ptr [request]
		mov	word ptr es:[bx + 03h],0100h	; request header +03h - status
		ret

bad_time:	call	rtc_init
		les	bx,dword ptr [request]
		mov	word ptr es:[bx + 03h],810Ch	; request header +03h - status
		xor	ax,ax
		mov	[second],al
		mov	[minute],al
		mov	[hour],al
		ret
rtc_get_time	endp


; this should be at 1B9h offset
rtc_get_date	proc	near
		call	rtc_detect
		mov	dx,RTC_DAY1
		in	al,dx
		and	al,NIBBLE
		cmp	al,9
		jbe	day1
		jmp	bad_date
day1:		mov	[day],al

		mov	dx,RTC_DAY10
		in	al,dx
		and	al,NIBBLE
		cmp	al,3
		jbe	day10
		jmp	bad_date
day10:		mul	byte ptr [ten]
		add	byte ptr [day],al
; now al is day from 1 to 31

		mov	dx,RTC_MONTH1
		in	al,dx
		and	al,NIBBLE
		cmp	al,9
		jbe	month1
		jmp	bad_date
month1:		mov	[month],al

		mov	dx,RTC_MONTH10
		in	al,dx
		and	al,NIBBLE
		cmp	al,1
		jbe	month10
		jmp	bad_date
month10:	mul	byte ptr [ten]
		add	byte ptr [month],al
		mov	al,[month]
		cmp	al,12
		ja	bad_date
; now al is month from 1 to 12

		call	month_to_days
		mov	ax,[days_in_month]
; check if current day is less or equal to the number of days in the current month
; i.e. detect things like February 30 or April 31 as bad
		cmp	al,byte ptr [day]
		jc	bad_date

		mov	dx,RTC_YEAR1
		in	al,dx
		and	al,NIBBLE
		cmp	al,9
		ja	bad_date
		mov	[year],al

		mov	dx,RTC_YEAR10
		in	al,dx
		and	al,NIBBLE
		cmp	al,9
		ja	bad_date
		mul	byte ptr [ten]
		add	byte ptr [year],al
; now al is year from 0 to 99

		call	rtc_init
		les	bx,dword ptr [request]
		mov	word ptr es:[bx + 03h],100h	; request header +03h - status
		ret

bad_date:	call	rtc_init
		les	bx,dword ptr [request]
		mov	word ptr es:[bx + 03h],810Ch	; request header +03h - status
		xor	ax,ax
		inc	ax
		mov	[days_total],ax	; if the RTC date is invalid, set days_total to 1
		ret
rtc_get_date	endp


; this should be at 25Ah offset
set_days_total	proc	near
		call	year_to_days
		; take days from previous years
		mov	[days_total],ax
		call	pm_to_days
		; add days from previous months this year
		add	word ptr [days_total],ax
		xor	ax,ax
		; add day of the current month
		mov	al,[day]
		add	word ptr [days_total],ax
		ret
set_days_total	endp


; this should be at 271h offset
; convert past months this year to days
pm_to_days	proc	near
		test	byte ptr [year],3
		jnz	not_leap_year

		mov	bx,offset table_leap
		jmp short	lookup
		nop

not_leap_year:	mov	bx,offset table_non_leap
lookup:		xor	ax,ax
		mov	al,[month]
		shl	ax,1	; ax = ax * 2
		mov	si,ax	; an offset to word?
		mov	ax,word ptr [bx + si]
		ret
pm_to_days	endp


; this should be at 28Dh offset
month_to_days	proc	near
		push	ax
		xor	ax,ax
		mov	al,[month]
		mov	bx,offset table_days_in_month	; it should be 4B4h
; al = days in current month, no leap year correction for february
		xlat	bx

; if year & 3 <> 0, consider it leap - this is probably limited to 1980s
; TODO: check relevant leap years: 1984, 1988, 1992
;
; Proper method for checking if year is leap:
;   if the year is evenly divisible by 4 and
;   if the year is evenly divisible by 100 and
;   if the year is evenly divisible by 400 then
;   the year is a leap year and has 366 days
;   otherwise it is not a leap year and has 365 days
		test	byte ptr [year],3
		jnz	not_leap_year2

		mov	cl,2
; check if month = 2 (february)
		cmp	byte ptr [month],cl
		jnz	not_leap_year2

; add one day if it is february and it's a leap year: 28 + 1 = 29
		inc	al

not_leap_year2:	mov	[days_in_month],ax
		pop	ax
		ret
month_to_days	endp


; this should be at 2ADh offset
year_to_days	proc	near
		xor	ax,ax
		mov	al,[year]
		mul	word ptr [days_per_year]
		xor	cx,cx
		mov	cl,[year]
		cmp	byte ptr [year],0
		jz	year0
		dec	cl
		shr	cx,1
		shr	cx,1	; cx = cx / 4
		inc	cx
		add	ax,cx	; add a day every four years
year0:		ret
year_to_days	endp


; this should be at 2CDh offset
write		proc	near
		les	bx,dword ptr [request]
		les	bx,es:[bx + 0Eh]	; request header +0Eh - buffer offset address
		mov	ax,word ptr es:[bx]
		inc	ax
		cmp	ax,08EADh
		jc	l2ef
		cmp	ax,0AB35h
		jbe	l2e6
		jmp	l3ab

l2e6:		mov	ax,08EADh
		mov	[days_total],ax
		jmp	l30e

l2ef:		mov	[days_total],ax
		cmp	word ptr [days_total],0
		jnz	l30e
		mov	byte ptr [year],0
		nop
		mov	byte ptr [month],1
		nop
		mov	byte ptr [day],1
		nop
		jmp	l311

l30e:		call	calc_day

l311:		call	rtc_detect
		xor	ax,ax
		mov	al,[day]
		div	byte ptr [ten]
		mov	dx,RTC_DAY10
		out	dx,al
		mov	dx,RTC_DAY1
		xchg	ah,al
		out	dx,al
		xor	ax,ax
		mov	al,[month]
		div	byte ptr [ten]
		mov	dx,RTC_MONTH10
		out	dx,al
		mov	dx,RTC_MONTH1
		xchg	ah,al
		out	dx,al
		xor	ax,ax
		mov	al,[year]
		div	byte ptr [ten]
		mov	dx,RTC_YEAR10
		out	dx,al
		mov	dx,RTC_YEAR1
		xchg	ah,al
		out	dx,al
		les	bx,dword ptr [request]
		les	bx,es:[bx + 0Eh]		; request header +0Eh - buffer offset address
		xor	ax,ax
		mov	al,byte ptr es:[bx + 03h]	; request header +03h - status
		cmp	al,24
		jnc	l3ab
		div	byte ptr [ten]
		mov	dx,RTC_HOUR10
		out	dx,al
		mov	dx,RTC_HOUR1
		xchg	ah,al
		out	dx,al
		xor	ax,ax
		mov	al,byte ptr es:[bx + 02h]	; request header +02h - command code
		cmp	al,3Ch
		jnc	l3ab
		div	byte ptr [ten]
		mov	dx,RTC_MIN10
		out	dx,al
		mov	dx,RTC_MIN1
		xchg	ah,al
		out	dx,al
		xor	ax,ax
		mov	al,byte ptr es:[bx + 05h]	; request header +05h - reserved?
		cmp	al,3Ch
		jnc	l3ab
		div	byte ptr [ten]
		mov	dx,RTC_SEC10
		out	dx,al
		mov	dx,RTC_SEC1
		xchg	ah,al
		out	dx,al
		call	rtc_init
		les	bx,dword ptr [request]
		mov	word ptr es:[bx + 03h],100h
		ret

l3ab:		call	rtc_init
		les	bx,dword ptr [request]
		mov	word ptr es:[bx + 03h],810ch
		ret
write		endp


; this should be at 3B9h offset
calc_day	proc	near
		xor	dx,dx
		mov	ax,[days_total]
		div	word ptr [days_per_year]
		mov	[year],al
		call	year_to_days
		cmp	ax,word ptr [days_total]
		jnc	l3d1
		jmp	l3d8

l3d1:		dec	byte ptr [year]
		call	year_to_days

l3d8:		mov	cx,word ptr [days_total]
		sub	cx,ax
		mov	word ptr [days_total],cx
		call	calc_month
		mov	ax,[days_total]
		mov	[day],al
		ret
calc_day	endp


; this should be at 3ECh offset
calc_month	proc	near
		mov	ax,[days_total]
		xor	si,si
		test	byte ptr [year],3
		jnz	not_leap_year3
		mov	bx,offset table_leap
		jmp short leap_year3
		nop

not_leap_year3:	mov	bx,offset table_non_leap

leap_year3:	cmp	ax,word ptr [bx + si + 2]	; check if it is before leap day?
		jle	before_leap_d
		add	si,2
		jmp	leap_year3

before_leap_d:	mov	ax,word ptr [bx + si]
		sub	word ptr [days_total],ax
		shr	si,1				; si = si / 2
		mov	ax,si
		mov	[month],al
		ret
calc_month	endp

; this should be at 419h offset
dummy		proc	near
		; setup status in request header before returing to DOS
		mov	word ptr es:[bx + 3],8103h
		ret
dummy		endp

; this should be at 420h offset
second		db	0	; 0 to 59
minute		db	0	; 0 to 59
hour		db	0	; 0 to 23
day		db	0	; 1 to 31
month		db	0	; 1 to 12
year		db	0

; this should be at 426h offset
rtc_status	db	RTC_BAD

; this should be at 427h offset
days_total	dw	0
days_in_month	dw	0
		dw	0

; this should be at 42Dh offset
ten		db	10
days_per_year	dw	365

; this should be at 430h offset, but it's at 431h for some reason***
store_ss	dw	0
store_sp	dw	0

; reserve some space for stack
		db	128 dup (5Eh)
stack_bottom:	; this should be at 4B4h offset

table_days_in_month:
		db	0	; 0 - no such month, unused
		db	31	; 1 - january has 31 days
		db	28	; 2 - february has 28 days (TODO: what about 29 on leap year?)
		db	31	; 3 - march has 31 days
		db	30	; 4 - april has 30 days
		db	31	; 5 - may has 31 days
		db	30	; 6 - june has 30 days
		db	31	; 7 - july has 31 days
		db	31	; 8 - august has 31 days
		db	30	; 9 - september has 30 days
		db	31	; 10 - october has 31 days
		db	30	; 11 - november has 30 days
		db	31	; 12 - december has 31 days

; this should be at 4C1h offset
table_non_leap:
		dw	0	; 0 - no such month, unused
		dw	0	; 1 - days in year before january
		dw	31	; 2 - days in year before february
		dw	59	; 3 - days in year before match
		dw	90	; 4 - days in year before april
		dw	120	; 5 - days in year before may
		dw	151	; 6 - days in year before june
		dw	181	; 7 - days in year before july
		dw	212	; 8 - days in year before august
		dw	243	; 9 - days in year before september
		dw	273	; 10 - days in year before october
		dw	304	; 11 - days in year before november
		dw	334	; 12 - days in year before december
		dw	365	; 13 - total days in year, probably this is never unused

; this should be at 4DDh offset
table_leap:
		dw	0	; 0 - no such month, unused
		dw	0	; 1 - days in leap year before january
		dw	31	; 2 - days in leap year before february
		dw	60	; 3 - days in leap year before match
		dw	91	; 4 - days in leap year before april
		dw	121	; 5 - days in leap year before may
		dw	152	; 6 - days in leap year before june
		dw	182	; 7 - days in leap year before july
		dw	213	; 8 - days in leap year before august
		dw	244	; 9 - days in leap year before september
		dw	274	; 10 - days in leap year before october
		dw	305	; 11 - days in leap year before november
		dw	335	; 12 - days in leap year before december
		dw	366	; 13 - total days in leap year, probably this is never unused

		db	7 dup (0)


write_char	MACRO	arg1
		push	ax
		push	dx
		mov	dl,al	; this is not neccessary if arg1 is passed
		IFNB	<arg1>	; if macro was passed an argument
		mov	dl,arg1
		ENDIF
		mov	ah,2
		int	21h	; int 21h, ah = 2 - write character from dl to standard output
		pop	dx
		pop	ax
		ENDM


; this should be at 500h
init		proc	near	; initialization routine
		cli
		mov	ax,cs
		mov	ds,ax
		mov	es,ax
		mov	dx,2CFh
		mov	al,1
		out	dx,al
		mov	al,5
		out	dx,al
		mov	al,4
		out	dx,al
		mov	dx,2CDh
		mov	al,0
		out	dx,al
		mov	dx,2CEh
		mov	al,3
		out	dx,al
		push	si
		lea	si,[banner]
		call	print_str
		pop	si
		call	rtc_detect
		call	rtc_init
		cmp	byte ptr [rtc_status],RTC_OK
		jz	l538
		jmp	l6d1

l538:		mov	dx,RTC_SEC1
		in	al,dx
		and	al,NIBBLE
		add	al,1
		daa			; adjusts the sum of two packed BCD values to create a packed BCD result
		and	al,NIBBLE
		mov	[second],al
		mov	cx,0FFFFh

l549:		push	cx
		mov	cx,12

l54d:		loop	l54d	; delay loop? skip something?

		pop	cx
		mov	dx,RTC_SEC1
		in	al,dx
		and	al,NIBBLE
		cmp	byte ptr [second],al
		jz	l561
		loop	l549
		jmp	l6d1

l561:		call	rtc_get_time
		les	bx,dword ptr [request]
		cmp	word ptr es:[bx + 03h],100h	; request header +03h - status
		jz	l573
		jmp	l719

l573:		push	si
		lea	si,[cur_time]
		call	print_str
		pop	si
		xor	ax,ax
		mov	al,[hour]
		div	byte ptr [ten]
		add	al,byte ptr [device_name]

		write_char

		xchg	ah,al
		add	al,byte ptr [device_name]	; mmm, wtf?

		write_char

		write_char ':'

		xor	ax,ax
		mov	al,[minute]
		div	byte ptr [ten]
		add	al,byte ptr [device_name]

		write_char

		xchg	ah,al
		add	al,byte ptr [device_name]

		write_char

		write_char ':'

		xor	ax,ax
		mov	al,[second]
		div	byte ptr [ten]	; divide by 10 to convert BCD to normal byte?
		add	al,byte ptr [device_name]

		write_char

		xchg	ah,al
		add	al,byte ptr [device_name]

		write_char

		call	rtc_get_date
		les	bx,dword ptr [request]
		cmp	word ptr es:[bx + 03h],100h	; request header +03h - status
		jz	l61b
		jmp	l719

l61b:		push	si
		lea	si,[cur_date]
		call	print_str
		pop	si
		xor	ax,ax
		mov	al,month
		div	byte ptr [ten]
		add	al,byte ptr [device_name]

		write_char

		xchg	ah,al
		add	al,byte ptr [device_name]

		write_char

		write_char '-'

		xor	ax,ax
		mov	al,day
		div	byte ptr [ten]
		add	al,byte ptr [device_name]

		write_char

		xchg	ah,al
		add	al,byte ptr [device_name]

		write_char

		write_char '-'

		xor	ax,ax
		mov	al,[year]
		cmp	al,20	; could it be? y2k
		jc	l6a1
		push	si
		lea	si,[twenty]
		call	print_str
		pop	si
		sub	al,20
		jmp	l6a3

l6a1:		add	al,80	; start from 1980?

l6a3:		div	byte ptr [ten]
		add	al,byte ptr [device_name]

		write_char

		xchg	ah,al
		add	al,byte ptr [device_name]

		write_char

		push	si
		lea	si,[eol]
		call	print_str
		pop	si
		jmp	l731

l6d1:		push	si
		lea	si,[msg101]
		call	print_str
		pop	si
		push	si
		lea	si,[anykey]
		call	print_str
		pop	si
		mov	al,07h
		mov	ah,0Ch
		int	21h	; int 21h, ah = 0Ch, al = 07h - flush buffer and read from stdin
		call	rtc_init
		les	bx,dword ptr [request]
		; are we ditchign init part here? to save some memory?
		mov	es:[bx + 0Eh],offset init		; +0Eh - buffer offset address
		mov	ax,cs
		mov	word ptr es:[bx + 10h],ax	; +10h - buffer segment address
		mov	word ptr es:[bx + 03h],810Ch	; +03h - status
		mov	ax,cs	; unnecessary
		mov	es,ax
		xor	al,al
		lea	di,[driver_name]
		mov	cx,8
		stosb	;es:di
		; change character device attributes to 1010000000000000b:
		mov	word ptr [drv_attr],CHAR_DRV + OUTPUT_UNTIL
		jmp	l75e

l719:		push	si
		lea	si,[msg100]
		call	print_str
		pop	si
		push	si
		lea	si,[anykey]
		call	print_str
		pop	si
		mov	al,07h
		mov	ah,0Ch
		int	21h	; int 21h, ah = 0Ch, al = 07h - flush buffer and read from stdin

l731:		les	bx,dword ptr [request]
		mov	word ptr es:[bx + 03h],100h	; +03h - status
		les	bx,dword ptr [request]		; unnecessary
		mov	es:[bx + 0Eh],offset init	; +0Eh - buffer offset address
		mov	ax,cs
		mov	word ptr es:[bx + 10h],ax	; +10h - buffer segment address
		mov	ax,cs	; unnecessary
		mov	es,ax	; unnecessary
		mov	ds,ax	; unnecessary

		; set device name to 0CLOCK, 1CLOCK etc.
		lea	si,[device_name + 1]
		lea	di,[driver_name]
		mov	cx,8
		rep movsb

l75e:		ret
init		endp


print_str	proc	near
		push	ax
		push	dx
		push	si
		push	ds
		push	cs
		pop	ds	; ds = cs

l765:		lodsb
		cmp	al,'$'
		jz	l772
		mov	dl,al
		mov	ah,2
		int	21h
		jmp	l765

l772:		pop	ds
		pop	si
		pop	dx
		pop	ax
		ret
print_str	endp


device_name	db	"0CLOCK$"
		dw	0

banner		db	13,10
		db	10,10,"Clock Device Driver       Ver 1.2"
		db	13,10,"Copyright 1985  Intel Corporation","$"

msg100		db	13,10,10,10,"Clock Msg 100"
		db	13,10,"   The clock contains an invalid date or time. Most likely"
		db	13,10,"   your battery has failed or you haven't yet set the date or time."
		db	13,10,"   But there are other possible causes."
		db	13,10,10,"   The clock software has been installed. See Appendix C in the Intel manual.",13,10,"$"

msg101		db	13,10,10,10,"Clock Msg 101"
		db	13,10,"   The clock hardware isn't working. There are many possible causes."
		db	13,10,10,"   The clock software has not been installed."
		db	13,10,"   See Appendix C in the Intel manual.",13,10,"$"

anykey		db	13,10,10,"   Press any key to continue",13,10,"$"

cur_time	db	13,10,10,"Current time is $"
cur_date	db	13,10,10,"Current date is $"
twenty		db	"20$"
eol		db	13,10,"$"

code		ends
		end
