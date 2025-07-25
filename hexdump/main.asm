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
; dddddd:XXXXXXXX XXXXXXXX XXXXXXXX XXXXXXXX|.... .... .... ....|


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
	ld.LIL	a,(HL)
	cp	'-'
	jp	nz,interactive
	INC.LIL	HL
	LD.LIL	a,(HL)				;24 bit
	cp	'c'
	jp	nz,badusage
;	jp	interactive
	LD.LIL		HL,(IX+6)		; HLU: pointer to first argument
openit:
	ld	c,fa_read	;open read-only for straight through hex dump to the end
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
;	call	unprintable
asciilp2:
	push	hl
	push	bc
	push	af
	ld		a,27
	rst		10h
	pop		af
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
	call	ck_ctrlC	;check at the end of the row for ctrl-C to exit
	jp		printlp



donefile:
	call	inline_print
	db		CR,LF,0
	jp		close

hit_EOF:
	call	inline_print
	db		'Past end of file',CR,LF,0
	ret

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
$$:
	rst	10h	;Agon uses this to print the character in A. Preserves HL.
	inc	hl
print_HL:	ld	a,(hl)
	cp	32
	jr	nc,$b
	ret


; Check for ctrl-C. If so, clean stack and exit.
;
ck_ctrlC:
;	ld	a,1		; modified below by self modifying code
;	dec	a
;	and	7
;	ld	(ck_ctrlC+1),a	; update LD A instruction above
;	ret	nz		; check every 8 calls only
	MOSCALL	mos_sysvars	;get the sysvars location - consider saving IX for speed
	ld.lil	a,(IX+sysvar_vkeycount)	;check if any key has been pressed
	ld	hl,keycount
	cp	(hl)	;compare against keycount for change
	ret	z
	ld	(hl),a	;update keycount
	ld.lil	a,(IX+sysvar_keyascii)	;fetch character in queue
	cp	27	;accept an ESC as well
	jr	z,$f
	cp	'q'	;accept 'q' for consistency
	jr	z,$f
	cp	3	;is it ctr-C
	ret	nz
$$:
	pop	hl		;clean up stack
;	pop	hl
	jp	close

okusage:	call usage
	jp	exit

badusage:	call usage
	jp	_err_invalid_param
;
; usage -- show syntax
; 
usage:	call	inline_print
	db	CR,LF,'hexdump utility for Agon by Shawn Sijnstra (c) 23-Jul-2025',CR,LF,CR,LF
	db	'Usage:',CR,LF
	db	'   hexdump [-c] <file>',CR,LF,CR,LF
	db	'	optional paramter c uses hexdump in continuous mode.',CR,LF
	db 	'Store hexdump.bin in /mos directory. Minimum MOS version 2.3.0.',CR,LF,CR,LF,0
	ret

;
;
; Arrow key mapping
; 8,11,10,21 = L,U,D,R
;
;
interactive:
;	LD.LIL		HL,(IX+6)		; HLU: pointer to first argument
	ld	c,fa_read	;open read-only for straight through hex dump to the end
	MOSCALL	mos_fopen
	or	a
	jr	nz,iopen_ok
	ld	hl,4	;file not found/could not find file - error opening file [not necessarily correct error though]
	ret			;exit	
iopen_ok:
	ld		(in_handle),a
	ld.lil	hl,0
	ld.lil	(counter+BASE),hl
main_loop:
	call	inline_print
	db		12,17,10,'hexdump utility - interactive mode',17,15,CR,LF
	db		'Filename:',0
	LD.LIL		HL,(IX+3)
	call	print_HL
	call	inline_print
	db		CR,LF,CR,LF,'Usage instructions:',CR,LF
	db		'p - previous 100h bytes  - - previous byte',CR,LF
	db		'n - next 100h bytes      + - next byte',CR,LF
	db		'g - go to hex location   arrows - navigate',CR,LF
	db		'q - quit',CR,LF,CR,LF,CR,LF,0
	ld.lil	hl,0	
	call	sectorlp
	ld.lil	hl,256
	call	sectorlp
key_invalid:
	ld		a,31
	rst		10h
	ld		a,0
	rst		10h
	ld		a,43
	rst		10h
	MOSCALL	mos_getkey
	LD		HL,key_options
	LD		BC,key_table-key_options
	CPIR
	jr		nz,key_invalid
	ld		a,c
	add		a,a
	ld		bc,0
	ld		c,a
	ld		hl,key_table
	add		hl,bc
	ld		a,(hl)
	inc		hl
	ld		h,(hl)
	ld		l,a
	jp		(hl)

;table below has keys and jumps for each keypress. Note the key_table is backwards.
key_options:
	db		'np+-',8,11,10,21,'gq'
key_table:
	dw		exit,goto,next_byte,go_down,go_up,prev_byte,prev_byte,next_byte,prev_sector,next_sector


sectorlp:

;	ld.lil	(counter+BASE),hl
	ld.lil	(rows+BASE),hl
	ld.lil	de,buffer+BASE
	add.lil	hl,de
	ld.lil	de,256
	ld	a,(in_handle)
	ld	c,a
	MOSCALL	mos_fread
	ld		a,e
	or		d
	jp		z,hit_EOF		;zero length (DE=0) means past end of file
	ld		b,e	;b will track length for next loop
	ld		c,0	;c will track current value in sector - but we need to do this twice in parallel

seclp2:
;	push	bc
		

iprintlp:

	ld.lil	hl,(counter+BASE)
	ld.lil	de,(rows+BASE)
	add.lil	hl,de
;	ld.lil	de,16
;	add.lil	hl,de
;	ld.lil	(counter+BASE),hl
	push	bc
	call	Print_Hex24
	pop		bc
	push	bc
;	ld		d,0		;ignore 2nd 100h block offset - hopefully fixed
ihexloop:
	ld		a,':'
	push	bc
	rst		10h
	pop		bc
	ld		hl,buffer
	add		hl,de
;	ld		c,0
ihexlp1:
	ld		a,c
	and		3
	jr		nz,$f
	ld		a,' '
;	push	hl
	push	bc
	rst		10h
	pop		bc
;	pop		hl
$$:

	ld		a,b
	or		a
	jr		z,ihexlp2
;	ld		a,b
	cp		c
	jr		z,$F
	jr		nc,ihexlp2
$$:
	ld		a,' '
	push	bc
	rst		10h
	rst		10h
	pop		bc
	jr		ihexlp3
ihexlp2:
	ld		a,(hl)

;	push	hl
	push	bc
	call	Print_Hex8
	pop		bc
;	pop		hl
	inc		hl
ihexlp3:
	inc		c
	ld		a,c
	and		15
	jp		z,ihexend
	jr		ihexlp1

ihexend:
	ld		a,' '
	rst		10h
	pop		bc		;recover c register.
iasciiloop:
	ld		a,'|'
	push	bc
	rst		10h
	pop		bc
	ld		hl,buffer
	add		hl,de
;	ld		c,0
iasciilp1:
	ld		a,b
	or		a
	jr		z,iasciilp2
;	ld		a,b
	cp		c
	jr		z,$F
	jr		nc,iasciilp2
$$:
	ld		a,' '
	jr		iasciilp3
iasciilp2:
	ld		a,(hl)
;	call	unprintable
iasciilp3:
	push	hl
	push	bc
	push	af
	ld		a,27
	rst		10h
	pop		af
	rst		10h
	pop		bc
	pop		hl
	inc		hl
	inc		c
	ld		a,c
	and		15
	jr		nz,iasciilp1	;until you get to the 16th for end of row.

iasciiend:
	call	inline_print
	db		'|',CR,LF,0
	ld.lil	hl,(rows+BASE)
	ld.lil	de,16
	add.lil	hl,de
	ld.lil	(rows+BASE),hl
	ld		a,l
	or		a
	jp		nz,iprintlp
	ret

go_down:
	ld.lil	hl,(counter+BASE)
	ld.lil	de,16
	add.lil	hl,de
	jr		next_b2
next_byte:
	ld.lil	hl,(counter+BASE)
	inc.lil	hl
next_b2:
	ld		e,0
	jr		seekit
next_sector:
	ld.lil	hl,(counter+BASE)
	ld.lil	de,256
	add.lil	hl,de
seekit:
	ld.lil	(counter+BASE),hl
	ld		a,(in_handle)
	ld		c,a
	MOSCALL	mos_flseek
	jp		main_loop

prev_sector:
	ld.lil	hl,(counter+BASE)
	ld.lil	de,256
	or		a
	sbc.lil	hl,de
	jr		nc,seekit
	ld.lil	hl,0
	jr		seekit

prev_byte:
	ld.lil	hl,(counter+BASE)
	ld.lil	de,1
prev_b2:
	or		a
	sbc.lil	hl,de
	ld		e,0
	jr		nc,seekit
	ld.lil	hl,0
	jr		seekit

go_up:
	ld.lil	hl,(counter+BASE)
	ld.lil	de,16
	jr		prev_b2

;goto routine
goto:
;position cursor + prompt
	call	inline_print
	db		31,1,9,'Go to [hex]?',0
;0x09: mos_editline - Invoke the line editor
;HL(U): Address of the buffer
;BC(U): Buffer length
;E: 0 to not clear buffer, 1 to clear
;Returns:
;A: Key that was used to exit the input loop (CR=13, ESC=27)
	ld		hl,input_buf
	ld		bc,7
	ld		e,1
	MOSCALL	mos_editline
	cp		27
	jr		z,goto_abort
	ld		de,input_buf
	ld.lil	hl,0
	ld		b,6		;max char count
goto_loop:
	ld		a,(de)
	or		a
	jp		z,seekit
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

goto_invalid:
	call	inline_print
	db		31,1,9,17,128+8+1,'  Invalid  ',17,128,'       ',0
	jp		key_invalid

goto_abort:
	call	inline_print
	db		31,1,9,'                  ',0
	jp		key_invalid

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
