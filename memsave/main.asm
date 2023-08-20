; MEMSAVE utility
;
;
; Written Agon native by Shawn Sijnstra
;
; Notable changes for reference:
; required colons on all labels
; labels are case sensitive
; code is a reserved word and can't be used as a label
; numeric evaluations are done differently - check results carefully
; reserved word INCLUDE needs to be in upper case, and file needs to have inverted commas
; assembly source MUST be .asm, can't use e.g. .zsm
; supports defb as a synonym for db, but NOT defw. Must use dw. defs also missing - use ds.
; labels can't start with @



			.ASSUME	ADL = 0				

			INCLUDE	"equs.inc"
			INCLUDE "mos_api.inc"	; In MOS/src

			SEGMENT CODE
	
			XDEF	_main
			XREF	Print_Hex24
			XREF	Print_Hex16
			XREF	Print_Hex8
			
; Error: Invalid parameter
;
_err_invalid_param:	LD		HL, 19			; The return code: Invalid parameters
			RET


; ASCII
;
CtrlC:	equ	03h
CR:	equ	0Dh
LF:	equ	0Ah
CtrlZ:	equ	1Ah
;
BASE:	equ	0b0000h

_main:
	ld	a,c	;AGON - number of parameters
	dec	a
	jp	z,okusage
	cp	3	;requires exact number of parameters
	jp	nz,badusage

	LD.LIL		DE,(IX+6)		; DEU: pointer to second argument
	call		hexparse
	jp			nz,badusage
	push.lil		hl
;	call		Print_Hex24
	LD.LIL		DE,(IX+9)		; DEU: pointer to third argument
	call		hexparse
	jp			nz,badusage0
	push.lil	hl
;	call		Print_Hex24

	LD.LIL		HL,(IX+3)		; pointer to first argument - filename

openit:
	ld	c,fa_write+fa_create_new	;open create new file

	MOSCALL	mos_fopen
	pop.lil		de				;Length
	pop.lil		hl				;start
	or	a
	jr	nz,open_ok
;	ld	hl,4	;file not found/could not find file - error opening file [not necessarily correct error though]
	ld.lil	hl,0
	ld	l,a		;use the returned error code!
	ret			;exit

open_ok:
	ld		c,a			;filehand returned in A
	MOSCALL mos_fwrite
	
	push.lil	de
	call	inline_print
	db		'Bytes written: ',0
	pop.lil		hl
	call	Print_Hex24
	call	inline_print
	db		CR,LF,CR,LF,0
	jp		close


;0x02: mos_save
;Save a file to SD card
;Parameters:
;HL(U): Address of filename (zero terminated)
;DE(U): Address to save from
;BC(U): Number of bytes to save
;Returns:
;A: File error, or 0 if OK
;F: Carry set

	MOSCALL	mos_save
	ld.lil	hl,0
	ld		l,a		;return error/success code
	ret			;exit
;
;
; Close and exit routines
;

close:
;C: Filehandle, or 0 to close all open files
;returns number of still open files - how about we just always close all?

	ld	c,0
	MOSCALL	mos_fclose	

exit:
	ld	hl,0	;for Agon - successful exit
	ret
;
;
;
; Prints string directly after the call
;
inline_print:	pop	hl
	call	print_string
	jp	(hl)
;
; more efficient print string for strings > 1 character
$$:
	rst	10h	;Agon uses this to print the character in A. Preserves HL.
	inc	hl
print_string:	ld	a,(hl)
	or	a
	jr	nz,$b
	ret
;
;
$$:
	rst	10h	;Agon uses this to print the character in A. Preserves HL.
	inc	hl
print_HL:	ld	a,(hl)
	cp	32
	jr	nc,$b
	ret


okusage:	call usage
	jp	exit

badusage0:	pop.lil	hl	;even up stack 
badusage:	call	usage
	jp	_err_invalid_param
;
; usage -- show syntax
;

usage:	call	inline_print
	db	CR,LF,'memsave utility for Agon by Shawn Sijnstra (c) 20-Aug-2023',CR,LF,CR,LF
	db	'Usage:',CR,LF
	db	'   memsave <file> <start> <length>',CR,LF,CR,LF
	db	'	Saves memory to <file> where <start> and <length> are in hex.',CR,LF
	db 	'Store memsave.bin in /mos directory. Minimum MOS version 1.03.',CR,LF,CR,LF,0
	ret


;hexparse routine
; input
;DE(U): address of hex string
; returns
;HL(U): parsed hex address
hexparse:
	ld.lil	hl,0
	ld		b,6		;max char count
goto_loop:
	ld		a,(de)
	cp		' '+1
	jr		c,goto_valid
	sub		'0'	;30h
	jr		c,goto_invalid
	cp		9+1
	jr		c,goto_nextchar
	sub		10h
	jr		c,goto_invalid
	and		1fh
	jr		z,goto_invalid
	cp		7
	jr		nc,goto_invalid
	add		9
	cp		16
	jr		nc,goto_invalid	;fix it later

goto_nextchar
	add.lil	hl,hl
	add.lil	hl,hl
	add.lil	hl,hl
	add.lil	hl,hl
	or		l
	ld	l,a
	inc		de
	djnz	goto_loop

goto_valid:
	xor		a
	ret
goto_invalid:
	xor		a
	inc		a	;nz flag
	ret

;
; data storage . . .
;	
stringlength:
	db	4	;default of 4 characters
; uninitialized storage/BSS but can't use that terminology because it's all in ROM space
;
; RAM
; 
			DEFINE	LORAM, SPACE = ROM
;			ORDER	__VECTORS, CODE, LORAM
			SEGMENT LORAM
		
;			SEGMENT	BSS
;			SEGMENT CODE

in_handle:	DS	1	;Only needs 1 byte handle
counter:	DS	4	; current address counter for continuous
rows:		DS	4
input_buf:	DS	8	;up to 6 characters?
upcount:	DS	2	;upper 2 bytes for file location
buffer:		DS	512	;Space to buffer incoming file data
curbyte:	DS	1	;current byte in the buffer
keycount:	DS	1	;current key count
	end
