; CPC Colour pic loader - buffer method
; Loads a CPC palette file and Screen file and displays it as it would have loaded
; in an interleaved wipe fashion. Only supports Mode 0. Supports with and without
; the AMS-DOS header, detected by file length. No checks are made for validity of
; file contents.
;
; No efficiency in the file I/O
;
; Written Agon native by Shawn Sijnstra
;


			.ASSUME	ADL = 0
			ORG		0

			INCLUDE "init.asm"		

			INCLUDE	"equs.inc"
			INCLUDE "mos_api.inc"	; In MOS/src

			
; Error: Invalid parameter
;
_err_invalid_param:	LD		HL, 19			; The return code: Invalid parameters
			RET


; ASCII
;
CtrlC:	equ	03h
;CR:	equ	0Dh
;LF:	equ	0Ah
CtrlZ:	equ	1Ah
;
;BASE:	equ	0b0000h - was using this for measuring the base compile but
;			have replaced it with using MB so it can work from either
;			/mos or /bin

_main:
	ld	a,c	;AGON - number of parameters
	dec	a
	ld	(argc),a
	jp	z,okusage
	cp	3	;too many parameters
	jp	nc,badusage

	LD.LIL		HL,(IX+3)		; HLU: pointer to first argument
;	ld.lil	hl,filetest + BASE
	ld.LIL	a,(HL)
	cp	'*'
;	jp	nz,open_pal
	jp	z,no_pal_file

open_pal:
;	rst	10h	;print first letter of filename - this is a debug
	ld	c,fa_read	;open read-only for straight through hex dump to the end
	MOSCALL	mos_fopen
	or	a
;	jr	open_ok
	jr	nz,open_ok
	call	inline_print
	db		"Not found:",0
	LD.LIL		HL,(IX+3)
	call	print_HLU
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

	ld	(pal_handle),a	;store the file handle number
;	call	inline_print
;	db		"Filename:",0
;	LD.LIL		HL,(IX+3)
;	call	print_HLU


; New Method:

; Command 72: Expand a bitmap
; VDU 23, 0, &A0, bufferId; 72, options, sourceBufferId; [width;] <mappingDataBufferId; | mapping-data...>
; This means you need to load a buffer with the 16 values for a 16 colour palette first.
;Bits	Description
;0-2	Number of bits per pixel in the source bitmap
;3	When set, the source bitmap is aligns to the next byte at a given width (in pixels)
;4	When set, mapping data is in a buffer
;5-7	Reserved for future use (set to zero)
;The number of bits per pixel in the source bitmap is specified by the bottom 3 bits of the options parameter. This can be any value from ;1 to 8 where a 0 is interpreted as 8.

; Command 0: Write block to a buffer
; VDU 23, 0, &A0, bufferId; 0, length; <buffer-data>
; embedded in code.

;Once you have a block that is ready to be used for a bitmap, the buffer must be selected, and then a bitmap created for that buffer using the bitmap and sprites API. This is done with the following commands:
; VDU 23, 27, &20, bufferId;              : REM Select bitmap (using a buffer ID)
; select_bitmap: (in HL)

; VDU 23, 27, &21, width; height; format  : REM Create bitmap from buffer
;Valid values for the format parameter are:
;Value	Meaning
;0	RGBA8888 (4-bytes per pixel)
;1	RGBA2222 (1-bytes per pixel)
;2	Mono/Mask (1-bit per pixel)
;3	Reserved for internal use by VDP ("native" format)
; This will always be 480 x 1; format 1.


; VDU 23, 27, 3, x; y;: Draw current bitmap on screen at pixel position x, y
; draw_bitmap
; Might do it inline - it's drawing at x=0, y = (c*8)+20

; map of used buffers:
; 256 + 64 = colour map
; 256 up to 256+25 = input buffers
; 256 + 32 up to 256 + 32 + 25 = output buffers that become the pixel map.

pal_load:

	LD		A, MB			; Segment base for HLU
	ld		hl,pal_buffer
	call	_set_ahl24
	ld.lil	de,224	+ 128	;this is the file length of the .PAL file + header
	ld	a,(pal_handle)
	ld	c,a
	MOSCALL	mos_fread

;first setup the colour buffer string
;This is needed for all of the use cases. Each sub-area then prints
; the 16 characters of the map.
; Command 0: Write block to a buffer
; VDU 23, 0, &A0, bufferId; 0, length; <buffer-data>
; Change of method - instead of buffer, use the colour map each time.

	ld	hl,256+64	;this is the buffer for the colour map
	call	clear_buffer	;ensure it's empty before you start.

	push	de
	ld		hl,write_to_buf
	ld		bc,8
	rst		18h	;write string, length is in BC
	pop		de

	ld	a,d		;check if > 256. This is extremely primative.
	or	a
	jr	nz,pal_has_ams
	ld	a,e
;check lower byte length. It's <256, so known options are:
;224 - has the full 12 frame colour map but no AMS header
;128+16 - has only a 16 colour map + AMS header
;16 - only has a 16 colour map
	cp		160
	jr		nc,pal_no_ams
	ld		hl,pal_buffer
	ld		iy,Amstrad_firmware	
	ld		bc,16
	cp		17
	jr		c,pal_short_noams
	ld		de,128
	add		hl,de
pal_short_noams:
	xor		a
	ld		de,1
	jr		PAL_lp1

pal_has_ams:	;has the header
	ld	hl,pal_buffer + 128 + 3
	jr	CPC_PALloop

pal_no_ams:
	ld	hl,pal_buffer+3	;palette entry 0: colours for 1 of 12 frames

;	jp	exit
;+0 is Screen Mode

CPC_PALloop:

	xor	a	;ld	a,0	;first colour to set - this is now a counter
	ld	de,12		;12 bytes to skip over as we don't support frames, only a single image
	ld	iy,AmstradCPC_table

;now fill the buffer
PAL_lp1:

	push	af	;preserve counter

	ld	a,(hl)
;	push	af
;	rst	10h		;testing
;	pop		af
	and	0x1f	;safety
	push	hl	;preserve file location
	ld	c,a
	ld	b,0
;	ld	hl,Amstrad_firmware	;AmstradCPC_table
;	ld	iy,AmstradCPC_table
	push	iy
	pop		hl
	add		hl,bc
	ld		a,(hl)
	pop		hl

	rst	10h	;print the RGBA2222 mapping from the table
			;might be ABGR2222 - need to check!

;	ld	a,c	;test routine
;	rst 10h	;print what is in A
;	ld	a,b
;	add	30h
;	rst	10h

	pop		af

	add	hl,de	;just to the next frame start
	inc	a
	cp	16
	jr	nz,PAL_lp1
	jr	done_SCR_cols

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Default colour palette here - this doesn't work on any known files.
; Left here for reference.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
no_pal_file:
;first setup the colour buffer string
; Command 0: Write block to a buffer
; VDU 23, 0, &A0, bufferId; 0, length; <buffer-data>
; Change of method - instead of buffer, use the colour map each time.

	ld	hl,256+64	;this is the buffer for the colour map
	call	clear_buffer	;ensure it's empty before you start.

	ld		hl,write_to_buf
	ld		bc,8
	rst		18h	;write string, length is in BC

	ld	hl,Amstrad_defaults	;This is a table arranged by default Ink/Paper colours
	ld	bc,16
	rst	18h	;first 16 characters off the default table for decoding


done_SCR_cols:
	call	inline_print
	db		CR,LF,0
;	jp		close
;	jp		testbuffs

get_scr_file:
	ld	a,(argc)
	dec	a
	jp	z,close

	LD.LIL		HL,(IX+6)		; HLU: pointer to second argument

open_scr:
;	rst	10h	;print first letter of filename - this is a debug
	ld	c,fa_read	;open read-only for straight through hex dump to the end
	MOSCALL	mos_fopen
	or	a
	jr	nz,scr_open_ok
	call	inline_print
	db		"Not found:",0
	LD.LIL		HL,(IX+6)
	call	print_HLU
	ld	hl,4	;file not found/could not find file - error opening file [not necessarily correct error though]
	ret			;exit

scr_open_ok:
	ld	(scr_handle),a	;store the file handle number
scr_load:

	LD		A, MB			; Segment base for HLU
	ld		hl,scr_buffer
	call	_set_ahl24
	ld.lil	de,16384+128		;this is the file length of the .SCR file + AMS header
	ld	a,(scr_handle)
	ld	c,a
	MOSCALL	mos_fread

	ld	a,d			;check if it's 16384 or lower
	cp	40h
	jr	c,scr_no_ams
	ld	a,e
	or	a
	jr	z,scr_no_ams
	ld	hl,scr_buffer + 128
	ld	de,scr_buffer
	ld	bc,16384
	LDIR

scr_no_ams:

;Setup steps
	call	physical_layout	;set up the coordinate system to be physical layout
; get mode when we update this
	xor	a	;ld	a,20	;row counter for total number of rows - count up to 200 + 20 oFfset and then end.
	ld	(scr_row),a	;	8 interleaved pixel row blocks

	ld	(byteslice),a	;track the odd/even bit number


;let's implement mode 0 and then fan out.


;loop needs to facilitate this:
;{
;	vdp_plot(0x40,x,y);
;}
;HL = x; DE = y where HL goes from 0 to 640, DE goes from 0 to 200, offset by 20.

scr_outer_lp:
; Need to count row number only now instead of column.
; may also need to count group of row number if we make it more fun by doing it as it would have shown on a real CPC
; so this level loop should do 8 loops to cover all the rows. Below does the 25 rows.


; here we set up 25 rounds to cover the rows. Let's just start with 1.
; set up counter for 25
; set up HL to be the start of the topmost of the current row set.

	ld	a,(scr_row)	;this calculated scr_row * 0x0800; where row = 0..7 for the outer loop.
	ld	d,8
	ld	e,a
	mlt	de
	ld	d,e
	ld	e,0
	ld	hl,scr_buffer	;current byte to read
	add	hl,de
	ld	(scr_curbyte),hl	;now this is set up we can read 25 x 640 sequentially.

	ld	c,0	;do it 25 times track in c?

scr_rows_lp:
; set up the intro code first to do the row dump
; we are going to use 25 buffers so that we can keep painting new buffers and not change a buffer before it's re-used.
; We should probably blank the buffer first? Using command 2? If so, make it a subroutine?
; Command 0: Write block to a buffer
; VDU 23, 0, &A0, bufferId; 0, length; <buffer-data>
; Command 2: Clear a buffer
; VDU 23, 0, &A0, bufferId; 2
	ld	l,c
	ld	h,1
	call	clear_buffer
	set	5,l
	call	clear_buffer

	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0a0h
	rst	10h
	ld	a,c	; use 256 + c. not (scr_row)	;dump data into buffer 256 + scr_row
	rst	10h
	ld	a,h
	rst	10h
	xor	a	;command 0
	rst	10h
	ld	a, 40h	;half of 640 - there are 2 pixels per byte
	rst	10h
	ld	a,1	;upper 16 bits of length.
	rst	10h	

	xor	a
	ld	(scr_col),a	;only 240 bytes to count because we do 2 per loop below. Start at 0.

scr_inner_lp:
	ld	hl,(scr_curbyte)
	ld	a,(byteslice)
	xor	1	;toggle
	ld	(byteslice),a
	jr	z,inner4_more	;second nibble - note the off by 1 due to the pre-increment
;inner is 0 so we ned to bump

	ld	b,(hl)


	xor	a

;    if(nColor & 1)
;      nByte |= 128;
;converted to allow expansion of bitmap so need the same byte twice now!
; ALSO - bit reveral in this method now!

	bit	7,b
	jr	nz,@f
	or	1 + 16
;	or	8 + 128
@@:

;    if(nColor & 2)
;      nByte |= 8;

	bit	3,b
	jr	nz,@f
	or	2 + 32
;	or	4 + 64
@@:

;    if(nColor & 4)
;      nByte |= 32;

	bit	5,b
	jr	nz,@f
	or	4 + 64
;	or	2 + 32
@@:

;    if(nColor & 8)
;      nByte |= 2;

	bit	1,b
	jr	nz,@f
	or	8 + 128
;	or	1 + 16
@@:
	jr	inner4_docolchange

inner4_more:
	ld	b,(hl)
	inc	hl
	ld	(scr_curbyte),hl
;	ld	a,(hl)
;	and	15
;	ld	a,b
;	and	15
	xor	a

;    if(nColor & 1)
;      nByte |= 64;

	bit	6,b
	jr	nz,@f
	or	1 + 16
;	or	8 + 128
@@:

;    if(nColor & 2)
;      nByte |= 4;

	bit	2,b
	jr	nz,@f
	or	2 + 32
;	or	4 + 64
@@:

;    if(nColor & 4)
;      nByte |= 16;

	bit	4,b
	jr	nz,@f
	or	4 + 64
;	or	2 + 32
@@:

;    if(nColor & 8)
;      nByte |= 1;

	bit	0,b
	jr	nz,@f
	or	8 + 128
;	or	1 + 16
@@:


inner4_docolchange:

	xor		255 	;- 8 - 128 -4 -64	;bits are reversed for some reason. 15
;	call	plotCol - just dump it in the buffer after a buffer select.
	rst		10h	;add it to the buffer.
	rst		10h	;add it to the buffer.

	ld	a,(scr_col)
	inc	a
	ld	(scr_col),a
	cp	160
	jp	c,scr_inner_lp

;convert it to a bitmap now
; Command 72: Expand a bitmap
; VDU 23, 0, &A0, bufferId; 72, options, sourceBufferId; [width;] <mappingDataBufferId; | mapping-data...>
	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0a0h
	rst	10h	;calculate destination buffer id = 256 + 32 + c
	ld	a,c
	add	32
	ld	l,a
	rst	10h
	ld	a,1
	ld	h,a	;HL now has the destination buffer ID - will use this below
	rst	10h
	ld	a,72
	rst	10h
	ld	a,4+16	;4 bits wide, mapping data is in a buffer - options.
;	ld	a,4		;4 bits wide
	rst	10h
	ld	a,c
	rst	10h
	ld	a,h
	rst	10h
	ld	a,64	;palette buffer
	rst	10h
	ld	a,h
	rst	10h


; VDU 23, 27, &20, bufferId;              : REM Select bitmap (using a buffer ID)
; select_bitmap: (in HL)

	call	select_bitmap

; VDU 23, 27, &21, width; height; format  : REM Create bitmap from buffer
;Valid values for the format parameter are:
;Value	Meaning
;0	RGBA8888 (4-bytes per pixel)
;1	RGBA2222 (1-bytes per pixel)
;2	Mono/Mask (1-bit per pixel)
;3	Reserved for internal use by VDP ("native" format)
; This will always be 480 x 1; format 1.
	push	bc
	ld	bc,8
	ld	hl,create_bitmap
	rst	18h
	pop	bc


; VDU 23, 27, 3, x; y;: Draw current bitmap on screen at pixel position x, y
; draw_bitmap
; Might do it inline - it's drawing at x=0, y = (c*8)+20 + scr_row
	ld	a,23
	rst	10h
	ld	a,27
	rst	10h
	ld	a,3
	rst	10h
	xor	a	;x = 0
	rst	10h
	rst	10h
	ld	hl,scr_row	;calculate y
	ld	a,c
	add	a,a	;*2
	add	a,a	;*4
	add	a,a	;*8
	add	a,(hl)	;plus scr_row
	add 20	;plus 20 (offset from top of screen)
	rst	10h
	xor	a
	rst	10h

;calculate vertical position to display it
;;	ld	hl,(scr_col)
;	ld	a,(scr_row)
;	add	20	;vertical offset
;	ld	e,a
;	ld	d,0
;	ld	b,4	;4 pixels per record in mode 0. Adjust for mode 1 and 2
;;;;;

	inc	c
	ld	a,c
	cp	25
	jp	nz,scr_rows_lp

	ld	a,(scr_row)
	inc	a
	ld	(scr_row),a
	cp	8
	jp	c,scr_outer_lp

scr_done:
	MOSCALL	mos_getkey

	jp	close

;
; Prints string directly after the call
;
inline_print:	pop	hl
	call	print_string
	jp	(hl)
;
; more efficient print string for strings > 1 character
@@:
	rst	10h	;Agon uses this to print the character in A. Preserves HL.
	inc	hl
print_string:	ld	a,(hl)
	or	a
	jr	nz,@b
	ret
;
;
@@:
	rst	10h	;Agon uses this to print the character in A. Preserves HL.
	inc	hl
print_HL:	ld	a,(hl)
	cp	32
;	ret	c
;	cp	127
;	jr	c,@b
	jr	nc,@b
	ret

@@:
	rst	10h	;Agon uses this to print the character in A. Preserves HL.
	inc.lil	hl
print_HLU:	ld.lil	a,(hl)
	cp	32
;	ret	c
;	cp	127
;	jr	c,@b
	jr	nc,@b
	ret


okusage:
	call usage
	call	CPC_tryloop
	jp	exit

badusage:	call usage
	jp	_err_invalid_param
;
; usage -- show syntax
; 
usage:	call	inline_print
	db	CR,LF,"CPCpic utility for Agon by Shawn Sijnstra (c) 26-Aug-2025",CR,LF,CR,LF
	db	"Usage:",CR,LF
;	db	"   CPCpic2 [file.PAL|*] [file.SCR]",CR,LF,"where:",CR,LF
;	db	"   you can specify a palette file [file.PAL] or an asterisk * to use the default palette",CR,LF
	db	"   CPCpic [file.PAL] [file.SCR]",CR,LF,"where:",CR,LF
	db	"   requires both a palette file [file.PAL] and the screen image file [file.SCR]",CR,LF
	db 	"Works in either /mos or /bin directory. Minimum VDP version 2.3.0.",CR,LF,CR,LF,0	;update minimum...
	ret


;TEST SEQUENCES

CPC_tryloop:
	ld	a,0
trylp1:
	ld	b,a
	ld	c,a
	push	af
	call	CPC_colset
	pop		af
	inc	a
	cp	16
	jr	nz,trylp1
	ret

testbuffs:
; set pixel layout
; clear the buffers
; put the palette colours into a buffer
; expand
; convert
; display
; exit
;	ld	a,43	;Print "*"
;	rst	10h
	call	physical_layout	;set up the coordinate system to be physical layout
	ld	a,43	;Print "*"
	rst	10h

; Command 2: Clear a buffer
; VDU 23, 0, &A0, bufferId; 2
	ld	hl,256+32
	call	clear_buffer
	ld	hl,256
	call	clear_buffer

	ld	a,43	;Print "*"
	rst	10h
; Command 0: Write block to a buffer
; VDU 23, 0, &A0, bufferId; 0, length; <buffer-data>
	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0a0h
	rst	10h
	ld	a,l	; use 256 + c. not (scr_row)	;dump data into buffer 256 + scr_row
	rst	10h
	ld	a,h
	rst	10h
	xor	a	;command 0
	rst	10h
	ld	a,8	;16	;replaced - only using the test sequence.
	rst	10h
	xor	a	;upper 8 bits of length.
	rst	10h	

;	xor	a
;	rst	10h

	push	hl
	call	inline_print
;	db	11h,22h,33h,44h,55h,66h,77h,88h,99h,0aah,0bbh,0cch,0ddh,0eeh,0ffh,42, 00
	db	01h,23h,45h,67h,89h,0abh,0cdh,0efh,00h 
	pop	hl

	ld	a,42	;Print "*"
	rst	10h

;convert it to a bitmap now
; Command 72: Expand a bitmap
; VDU 23, 0, &A0, bufferId; 72, options, sourceBufferId; [width;] <mappingDataBufferId; | mapping-data...>
	ld	c,l	;mimic the code style by putting this back into c
	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0a0h
	rst	10h	;calculate destination buffer id = 256 + 32 + c
	ld	a,c
	add	32
	ld	l,a
	rst	10h
	ld	a,1
	ld	h,a	;HL now has the destination buffer ID - will use this below
	rst	10h
	ld	a,72
	rst	10h
;	ld	a,4+16	;4 bits wide, mapping data is in a buffer - options.
	ld	a,4
	rst	10h
	ld	a,c
	rst	10h
	ld	a,h
	rst	10h
;	ld	a,64	;palette buffer
;	rst	10h
;	ld	a,h
;	rst	10h
	push	hl
	call	inline_print
;	db	03h,13h,23h,33h,43h,53h,63h,73h,83h,93h,0a3h,0b3h,0c3h,0d3h,0e3h,0f3h,0
	db	0C1h,0D1h,0E1h,0F1h,0C3h,0D3h,0E3h,0F3h,03Ch,03Ch,0ECh,0FCh,0cFh,0dFh,0efh,0ffh,0
	pop		hl

; VDU 23, 27, &20, bufferId;              : REM Select bitmap (using a buffer ID)
; select_bitmap: (in HL)

	call	select_bitmap

; VDU 23, 27, &21, width; height; format  : REM Create bitmap from buffer
;Valid values for the format parameter are:
;Value	Meaning
;0	RGBA8888 (4-bytes per pixel)
;1	RGBA2222 (1-bytes per pixel)
;2	Mono/Mask (1-bit per pixel)
;3	Reserved for internal use by VDP ("native" format)
; This will always be 480 x 1; format 1. - 16x1 for test.
	push	bc
	ld	bc,8
	ld	hl,create_bitmap_test
	rst	18h
	pop	bc

; VDU 23, 27, 3, x; y;: Draw current bitmap on screen at pixel position x, y
; draw_bitmap
; Might do it inline - it's drawing at x=0, y = (c*8)+20 + scr_row
	ld	a,23
	rst	10h
	ld	a,27
	rst	10h
	ld	a,3
	rst	10h
	xor	a	;x = 0
	rst	10h
	ld	a,1
	rst	10h
	ld	hl,scr_row	;calculate y
	ld	a,c
	add	a,a	;*2
	add	a,a	;*4
	add	a,a	;*8
	add	a,0	;(hl)	;plus scr_row
	add 20	;plus 20 (offset from top of screen)
	rst	10h
	xor	a
	rst	10h


	jp	close

;VDU 23, 0, &C0, n
;
;Turn logical screen scaling on and off, where 1=on and 0=off.
physical_layout:
	push	af
	ld		a,23
	rst		10h
	xor		a
	rst		10h
	ld		a,0c0h
	rst		10h
	xor		a
	rst		10h
	pop		af
	ret

;void vdp_clearGraphics()
;{
;    putch(16);    
;}
ClearGfx:
	push	af
	ld		a,16
	rst		10h
	pop		af
	ret


;void vdp_plotColour(unsigned char colorindex)
;{
;    putch(18); // GCOL
;    putch(1);
;	putch(colorindex);
;}
;uses A for plot colour
plotCol:
	push	af
	ld		a,18
	rst		10h
	ld		a,0
	rst		10h
	pop		af
	rst		10h
	ret



;void vdp_plot(unsigned char mode, unsigned int x, unsigned int y)
;{
;    putch(25); // PLOT
;    putch(mode);
;    putch(x & 0xFF);
;    putch(x >> 8);
;    putch(y & 0xFF);
;    putch(y >> 8);
;}

;void vdp_plotPoint(unsigned int x, unsigned int y)
;{
;	vdp_plot(0x40,x,y);
;}
;HL = x; DE = y
plotPoint:
	push	af
	ld		a,25
	rst		10h
	ld		a,45H	;Plot absolute in current foreground colour
	rst		10h
	ld		a,l
	rst		10h
	ld		a,h
	rst		10h
	ld		a,e
	rst		10h
	ld		a,d
	rst		10h
	pop		af
	ret

;void vdp_plotLine(unsigned int x, unsigned int y)
;{
;	&00-&07	0-7	Solid line, includes both ends
;}
;HL = x; DE = y
plotLine:
	push	af
	ld		a,25
	rst		10h
	ld		a,05H	;Plot absolute in current foreground colour
	rst		10h
	ld		a,l
	rst		10h
	ld		a,h
	rst		10h
	ld		a,e
	rst		10h
	ld		a,d
	rst		10h
	pop		af
	ret

; VDU 23, 27, 3, x; y;: Draw current bitmap on screen at pixel position x, y
;HL = x; DE = y
draw_bitmap:
	push	af
	ld		a,23
	rst		10h
	ld		a,27
	rst		10h
	ld		a,3
	rst		10h
	ld		a,l
	rst		10h
	ld		a,h
	rst		10h
	ld		a,e
	rst		10h
	ld		a,d
	rst		10h
	pop		af
	ret

; VDU 23, 27, &20, bufferId;              : REM Select bitmap (using a buffer ID)
; HL = bufferId
select_bitmap:
	push	af
	ld		a,23
	rst		10h
	ld		a,27
	rst		10h
	ld		a,20h
	rst		10h
	ld		a,l
	rst		10h
	ld		a,h
	rst		10h
	pop		af
	ret

; Command 2: Clear a buffer
; VDU 23, 0 &A0, bufferId; 2
; HL = bufferId
clear_buffer:
	push	af
	ld		a,23
	rst		10h
	xor		a
	rst		10h
	ld		a,0A0h
	rst		10h
	ld		a,l
	rst		10h
	ld		a,h
	rst		10h
	ld		a,2
	rst		10h
	pop		af
	ret

; Command 24: Reverse the order of data of blocks within a buffer
; VDU 23, 0, &A0, bufferId; 24, options, [valueSize;] [chunkSize;]
;HL = Buffer ID
;  4  option: Reverse data of the value size within chunk of data of the specified size
;  size (4 bytes)
rev_block_data:
	push	af
	ld		a,23
	rst		10h
	xor		a
	rst		10h
	ld		a,0a0h
	rst		10h
	ld		a,l
	rst		10h
	ld		a,h
	rst		10h
	pop		af
	ld		a,24
	rst		10h
	ld		a,4
	rst		10h
	rst		10h
	xor		a
	rst		10h
	ret

;for Agon: VDU 19, l, p, r, g, b: Define logical colour
;b = colour to reassign, c = Gate Array hardware number (should be from 0x40-0x5f but will use a mask for safety)
CPC_colset:
	push	hl
	push	bc
	ld	a,19	;VDU 19
	rst	10h	;print it
	ld	a,b
	rst	10h	;print it
	ld	a,c
	and	0x1f
	ld	c,a
	ld	b,0
	ld	hl,AmstradCPC_table
	add	hl,bc
	ld	a,(hl)
	rst	10h	;print it
	rst	10h	;print it
	rst	10h	;print it
	rst	10h	;print it
;	add	a,20h
;	rst	10h
	pop	bc
	pop	hl
	ret

;colour
AmstradCPC_table:
;On an actual Amstrad CPC, the half-intensity colour signal is measured to be closer to 40% rather than the expected 50%. 
;for Agon: VDU 19, l, p, r, g, b: Define logical colour
;If the physical colour number is given as 255 then the colour will be defined using the red, green, and blue values given.
;If the physical colour value is less than 64, the value is interpreted as a 6-bit colour number where the number in binary form is in the format RRGGBB.
;If the physical colour is not 255 then the red, green, and blue values must still be provided, but will be ignored.
;Hardware Colour Index	Colour Name	RGB
;R %	G %	B %
; taking into account the RRGGBB format and the 40%, the 3 colour levels in binary will be 00/01/11.
; so the R digit will be 0/1/3. G will be 0/4/C, B will be 0/1/3
; This is now version 2 - bits are in reverse order - it's RGBA but backwards. So top 2 bits always set.
; note brightness seems to be order preserved for 01 is 1/3 brightness.
; 
	db	11010101b	;015h	;0	White	50	50	50
	db	11010101b	;015h	;1	White	50	50	50
	db	11011100b	;00Dh	;2	Sea Green	0	100	50
	db	11011111b	;03Dh	;3	Pastel Yellow	100	100	50
	db	11010000b	;001h	;4	Blue	0	0	50
	db	11010011b	;031h	;5	Purple	100	0	50
	db	11010100b	;005h	;6	Cyan	0	50	50
	db	11010111b	;035h	;7	Pink	100	50	50
	db	11010011b	;031h	;8	Purple	100	0	50
	db	11011111b	;03Dh	;9	Pastel Yellow	100	100	50
	db	11001111b	;03Ch	;10	Bright Yellow	100	100	0
	db	11111111b	;03Fh	;11	Bright White	100	100	100
	db	11000011b	;030h	;12	Bright Red	100	0	0
	db	11110011b	;033h	;13	Bright Magenta	100	0	100
	db	11000111b	;034h	;14	Orange	100	50	0
	db	11110111b	;037h	;15	Pastel Magenta	100	50	100
	db	11010000b	;001h	;16	Blue	0	0	50
	db	11011100b	;00Dh	;17	Sea Green	0	100	50
	db	11001100b	;00Ch	;18	Bright Green	0	100	0
	db	11111100b	;00Fh	;19	Bright Cyan	0	100	100
	db	11000000b	;000h	;20	Black	0	0	0
	db	11110000b	;003h	;21	Bright Blue	0	0	100
	db	11000100b	;004h	;22	Green	0	50	0
	db	11110100b	;007h	;23	Sky Blue	0	50	100
	db	11010001b	;011h	;24	Magenta	50	0	50
	db	11101101b	;01dh	;25	Pastel Green	50	100	50
	db	11001101b	;01ch	;26	Lime	50	100	0
	db	11111101b	;01fh	;27	Pastel Cyan	50	100	100
	db	11000001b	;010h	;28	Red	50	0	0
	db	11110001b	;013h	;29	Mauve	50	0	100
	db	11000101b	;014h	;30	Yellow	50	50	0
	db	11110101b	;017h	;31	Pastel Blue	50	50	100

Amstrad_firmware:
;Colours by firmware:
	db	11000000b	;0	54h	Black	0	0	0	#000000	0/0/0	
	db	11010000b	;1	44h (or 50h)	Blue	0	0	50	#000080	0/0/128	
	db	11110000b	;2	55h	Bright Blue	0	0	100	#0000FF	0/0/255	
	db	11000001b	;3	5Ch	Red	50	0	0	#800000	128/0/0	
	db	11010001b	;4	58h	Magenta	50	0	50	#800080	128/0/128	
	db	11110001b	;5	5Dh	Mauve	50	0	100	#8000FF	128/0/255	
	db	11000011b	;6	4Ch	Bright Red	100	0	0	#FF0000	255/0/0	
	db	11010011b	;7	45h (or 48h)	Purple	100	0	50	#FF0080	255/0/128	
	db	11110011b	;8	4Dh	Bright Magenta	100	0	100	#FF00FF	255/0/255	
	db	11000100b	;9	56h	Green	0	50	0	#008000	0/128/0	
	db	11010100b	;10	46h	Cyan	0	50	50	#008080	0/128/128	
	db	11110100b	;11	57h	Sky Blue	0	50	100	#0080FF	0/128/255	
	db	11000101b	;12	5Eh	Yellow	50	50	0	#808000	128/128/0	
	db	11010101b	;13	40h (or 41h)	White	50	50	50	#808080	128/128/128	
	db	11110101b	;14	5Fh	Pastel Blue	50	50	100	#8080FF	128/128/255	
	db	11000111b	;15	4Eh	Orange	100	50	0	#FF8000	255/128/0	
	db	11010111b	;16	47h	Pink	100	50	50	#FF8080	255/128/128	
	db	11110111b	;17	4Fh	Pastel Magenta	100	50	100	#FF80FF	255/128/255	
	db	11001100b	;18	52h	Bright Green	0	100	0	#00FF00	0/255/0	
	db	11011100b	;19	42h (or 51h)	Sea Green	0	100	50	#00FF80	0/255/128	
	db	11111100b	;20	53h	Bright Cyan	0	100	100	#00FFFF	0/255/255	
	db	11001101b	;21	5Ah	Lime	50	100	0	#80FF00	128/255/0	
	db	11101101b	;22	59h	Pastel Green	50	100	50	#80FF80	128/255/128	
	db	11111101b	;23	5Bh	Pastel Cyan	50	100	100	#80FFFF	128/255/255	
	db	11001111b	;24	4Ah	Bright Yellow	100	100	0	#FFFF00	255/255/0	
	db	11011111b	;25	43h (or 49h)	Pastel Yellow	100	100	50	#FFFF80	255/255/128	
	db	11111111b	;26	4Bh	Bright White	100	100	100	#FFFFFF	255/255/255


Amstrad_defaults:
;This is the default INK/PAPER colours for mode 0, as taken from the manual.
; NOTE: Number scheme is different to the above chart, and the hardware numbers are different again.
; This is unhelpful, but left here as a record of what was tried.
	db	11010000b	; 1  Blue
	db	11001111b	; 24 Bright Yellow
	db	11111100b	; 20 Bright Cyan
	db	11000011b	; 6  Bright Red
	db	11111111b	; 26 Bright White
	db	11000000b	; 0  Black
	db	11110000b	; 2  Bright Blue
	db	11110011b	; 8  Bright Magenta
	db	11010100b	; 10 Cyan
	db	11000101b	; 12 Yellow
	db	11110101b	; 14 Pastel Blue
	db	11010111b	; 16 Pink
	db	11001100b	; 18 Bright Green
	db	11101101b	; 22 Pastel Green
	db	11001111b	; 24 (Flashing with 1) Bright Yellow
	db	11110100b	; 11 (Flashing with 16) Sky Blue


;Strings for VDU controls
; VDU 23, 0, &A0, bufferId; 0, length; <buffer-data>
write_to_buf:
	db		23,0,0A0h, 64,1, 0, 16,0
;buffer ID = 256 + 64
;command 0
; length = 16

create_bitmap:
;	db		23,27,021h,0e0h,01h,01,00,1
	db		23,27,021h,080h,02h,01,00,1	;640 length
create_bitmap_test:
	db		23,27,021h,010h,00h,01,00,1 ;16 length
; VDU 23, 27, &21, width; height; format  : REM Create bitmap from buffer
;Valid values for the format parameter are:
;Value	Meaning
;0	RGBA8888 (4-bytes per pixel)
;1	RGBA2222 (1-bytes per pixel)
;2	Mono/Mask (1-bit per pixel)
;3	Reserved for internal use by VDP ("native" format)
; This will always be 480 (1E0h) x 1; format 1. Nope. It's 640 (0240h) x 1.

;filetest:
;	db	"SCREEN.PAL",0

; data storage . . .
;	
;stringlength:
;	db	4	;default of 4 characters
; uninitialized storage/BSS but can't use that terminology because it's all in ROM space
;
; RAM
; 


argc:		DS	1	;store argc for later
pal_handle:	DS	1	;Only needs 1 byte handle
;counter:	DS	4	; current address counter for continuous
;rows:		DS	4
;input_buf:	DS	8	;up to 6 characters?
;upcount:	DS	2	;upper 2 bytes for file location
pal_buffer:		DS	512	;Space to buffer incoming file data
;curbyte:	DS	1	;current byte in the buffer
;keycount:	DS	1	;current key count

byteslice:	DS	1	;segment of the byte to show

buffer_map:	DS	16	;16 bytes for the colour map based on the CPC palette->AGON palette subset in .PAL file

scr_row:	DS	1	;current screen row.
scr_curbyte:	DS	2	;current byte location to display
scr_col:	DS	2	;column counter
scr_handle:	DS	1
scr_buffer:	DS	16384 + 128	;128 bytes for the AMS header (optional)
						;length of file = video ram for CPC = (assuming uncompressed)
						;160x200 in mode 0 OR
						;320x200 in mode 1 OR
						;640x200 in mode 2.
						;Each byte describes:
						;2 mode 0 pixels OR
						;4 mode 1 pixels OR
						;8 mode 2 pixels.
