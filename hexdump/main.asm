; HEXDUMP utility
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
;
; DESIGN OF WIDTH:
; 6 chars for current byte
; dddddd: XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX |................|


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
	cp	3	;too many parameters
	jp	nc,badusage

	LD.LIL		HL,(IX+3)		; HLU: pointer to first argument
	ld	c,fa_read	;open read-only
	MOSCALL	mos_fopen
	or	a
	jr	nz,open_ok
	ld	hl,4	;file not found/could not find file - error opening file [not necessarily correct error though]
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
open_ok:

	ld	(in_handle),a	;store the file handle number
	MOSCALL	mos_sysvars	;get the sysvars location - consider saving IX for speed
	ld	a,(IX+sysvar_vkeycount)	;fetch keycount
	ld	(keycount),a	;store to compare against
	ld.lil	hl,0-16
	ld.lil	(counter+BASE),hl
printlp:


	ld.lil	hl,buffer+BASE
	ld.lil	de,16
	ld	a,(in_handle)
	ld	c,a
	MOSCALL	mos_fread
	ld		a,e
	or		a
	jp		z,donefile
	ld		b,a	;b will track length for next loop
	ld.lil	hl,(counter+BASE)
	ld.lil	de,16
	add.lil	hl,de
	ld.lil	(counter+BASE),hl
	push	bc
	call	Print_Hex24
	pop		bc
hexloop:
	ld		a,':'
	rst		10h
	ld		hl,buffer
	ld		c,0
hexlp1:
	ld		a,c
	and		3
	jr		nz,$f
	ld		a,' '
	push	hl
	push	bc
	rst		10h
	pop		bc
	pop		hl
$$:
	ld		a,(hl)

	push	hl
	push	bc
	call	Print_Hex8
	pop		bc
	pop		hl
	inc		hl
hexlp2:
	inc		c
	ld		a,c
	cp		16
	jp		z,hexend
	cp		b
	jr		c,hexlp1
	ld		a,' '
	rst		10h
	rst		10h
	ld		a,c
	and		3
	jr		nz,$f
	ld		a,' '
	rst		10h
$$:
	jr		hexlp2

hexend:
	ld		a,' '
	rst		10h

asciiloop:
	ld		a,'|'
	rst		10h
	ld		hl,buffer
	ld		c,0
asciilp1:
	ld		a,(hl)
	call	unprintable
asciilp2:
	push	hl
	push	bc
	rst		10h
	pop		bc
	pop		hl
	inc		hl
	inc		c
	ld		a,c
	cp		16
	jp		z,asciiend
	cp		b
	jr		c,asciilp1
	ld		a,' '
	jr		asciilp2

asciiend:
	call	inline_print
	db		'|',CR,LF,0	
	jp		printlp




printbuff:
;	push	bc		;preserve length
	ld		de,buffer
$$:
	ld		a,(de)	
	rst		10h
	inc		de
	djnz	$b
;	pop		bc
;now keep printing until unprintable again
allgood_lp
	call	getbyte
	call	unprintable
	jr		z,endstring
	rst		10h
	jr		allgood_lp	
endstring:
	call	inline_print
	db		CR,LF,0		;newline at end - TEST

donefile:
	call	inline_print
	db		CR,LF,0
	jp		close


; Entry:
; A is a character to test
; Exit:
; unprintable character converted to a '.'
unprintable:
	cp	' '
	jr	c,$f
	cp	127
	ret	c	;always nz
$$:	ld	a,'.'	;xor	a	;sets 0 flag
	ret
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
getbyte:
	call	ck_ctrlC
	ld	a,(in_handle)
	ld	c,a
	MOSCALL mos_fgetc	;carry flag on last byte not yet implemented.
	ret

; Check for ctrl-C. If so, clean stack and exit.
;
ck_ctrlC:
	ld	a,1		; modified below by self modifying code
	dec	a
	and	15
	ld	(ck_ctrlC+1),a	; update LD A instruction above
	ret	nz		; check every 16 calls only
	MOSCALL	mos_sysvars	;get the sysvars location - consider saving IX for speed
	ld.lil	a,(IX+sysvar_vkeycount)	;check if any key has been pressed
	ld	hl,keycount
	cp	(hl)	;compare against keycount for change
	ret	z
	ld	(hl),a	;update keycount
	ld.lil	a,(IX+sysvar_keyascii)	;fetch character in queue
	cp	3	;is it ctr-C
	ret	nz
	pop	hl		;clean up stack
	pop	hl
	jp	close

okusage:	call usage
	jp	exit

badusage:	call usage
	jp	_err_invalid_param
;
; usage -- show syntax
; 
usage:	call	inline_print
	db	CR,LF,'hexdump utility for Agon by Shawn Sijnstra 11-Jun-2023',CR,LF,CR,LF
	db	'Usage:',CR,LF
	db	'   hexdump <file>',CR,LF,CR,LF
	db 	'Store hexdump.bin in /mos directory. Minimum MOS version 1.03.',CR,LF,CR,LF,0
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
counter:	DS	4
buffer:		DS	100	;Space to buffer incoming strings
curbyte:	DS	1	;current byte in the buffer
keycount:	DS	1	;current key count
	end
