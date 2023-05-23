; STRINGS utility
;
;
; Written Agon native by Shawn Sijnstra
;
; Notable changes for reference:
; required colons on all labels
; labels are case sensitive
; code is a reserved word and can't be used as a label
; numeric evaluations are done differently - check results carefully
;


			.ASSUME	ADL = 0				

			INCLUDE	"equs.inc"
			INCLUDE "mos_api.inc"	; In MOS/src

			SEGMENT CODE
	
			XDEF	_main

			
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

_main:
	ld	a,c	;AGON - number of parameters
	dec	a
	jp	z,okusage
	cp	3	;too many parameters
	jp	nc,badusage

	LD.LIL		HL,(IX+3)		; HLU: pointer to first argument
	LD.LIL	a,(HL)				;24 bit
	cp	'-'
	jr	nz,openit
	INC.LIL	HL
	LD.LIL	a,(HL)				;24 bit
	cp	'n'
	jp	nz,badusage	
	INC.LIL	HL
	LD.LIL	a,(HL)				;24 bit
	cp	'1'
	jp	c,badusage
	cp	'9'+1
	jp	nc,badusage
	sub	'0'
	ld	(stringlength),a
	LD.LIL		HL,(IX+6)		; HLU: pointer to second argument
openit:
	ld	c,fa_read	;open read-only
	push.lil	ix
	MOSCALL	mos_fopen
	pop.lil		ix
	or	a
	jr	nz,open_ok
;	call	inline_print
;	db	"File not found.",CR,LF,0
;	jr	exit
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
stringlp:
	call	getbyte
	call	unprintable
	jr		z,noprint
;store character and check next is also printable
	ld		de,buffer
	ld		(de),a
	ld		b,1			;lets see if we can keep count in b for now
innerlp:
	ld		a,(stringlength)
	cp		b
	jr		z,printbuff	
	MOSCALL mos_feof	;check for end of file
	or		a
	jr		nz,donefile
	call	getbyte		;fetch next byte
	call	unprintable
	jr		z,noprint	;if unprintable, don't print either
	inc		de
	ld		(de),a
	inc		b
	jr		innerlp


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
noprint:
	MOSCALL mos_feof	;check for end of file
	or		a
	jr		z,stringlp
donefile:
	call	inline_print
	db		CR,LF,0
	jp		close


; Entry:
; A is a character to test
; Exit:
; Z flag is unprintable
unprintable:
	cp	' '
	jr	c,$f
	cp	127
	ret	c	;always nz
$$:	xor	a	;sets 0 flag
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
	db	CR,LF,'strings utility for Agon by Shawn Sijnstra 23-May-2023',CR,LF,CR,LF
	db	'Usage:',CR,LF
	db	'   strings [-nX] <file>',CR,LF
	db	'Optional parameter n specifies minimum string length X=1..9',CR,LF
	db  ' Default string length 4. Ctrl-C to abort.',CR,LF
	db 	'Store in /mos directory. Requires MOS 1.03 or later.',CR,LF,0
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
buffer:		DS	10	;Space to buffer incoming strings
curbyte:	DS	1	;current byte in the buffer
keycount:	DS	1	;current key count
	end
