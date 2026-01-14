; PCX loader - buffer method
; PCX graphics loader.
; Intended features:
; pause or wait
; Support as many 16 bit image formats as possible
; Support centring for smaller images
; No scaling
; loaded in a single sweep, not too clever.
; Format checking is NOT thorough.
; Will need to be in 24 bit mode when done.
; 
;
; No efficiency in the file I/O - NOT SURE WHAT THIS MEANS
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

; To add: turn off cursor and back on again when done.
; additional parameter for how many seconds to wait before auto-exiting.

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

	cp	2
	jr	c,open_fil
	ld.lil	hl,(IX+6)
	ld.lil	a,(hl)
	sub	'1'
	jp	c,badusage
	inc	a
	cp	10
	jp	nc,badusage
	ld	(timerfun),a

open_fil:
	LD.LIL		HL,(IX+3)		; HLU: pointer to first argument
	ld	c,fa_read	;open read-only for straight through hex dump to the end
	MOSCALL	mos_fopen
	or	a
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

;turn back on cursor first = VDU 23,1,1
	ld	a,23
	rst	10h
	ld	a,1
	rst	10h
	rst	10h

	ld	c,0
	MOSCALL	mos_fclose	

exit:
	ld	hl,0	;for Agon - successful exit
	ret


; bad file format for valid PCX files.
bad_format:
	call	inline_print
	db		"Not a supported PCX file format.",0
	call	close	;close files
	ld	hl,9	;file not found/could not find file - error opening file [not necessarily correct error though]
	ret			;exit - should have closed the files too?
;
;
open_ok:

	ld	(pcx_handle),a	;store the file handle number
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

; VDU 23, 27, 3, x; y;: Draw current bitmap on screen at pixel position x, y
; draw_bitmap
; Might do it inline - it's drawing at x=0, y = (c*8)+20

; map of used buffers:
; 256 + 64 = colour map
; 257 = input buffer
; 258 = output buffer that is split
; 259 = output split that becomes the pixel map.
; 260 = discarded end of the pixel map

; The EGA palette is within the same file as the rest of the file. The header is only 128 bytes.
; We could actually load that first, then load the whole picture file or load it in pages over the top.
; We are using 256 byte blocks, this means we can keep keep this utility to a minium size as a moslet
; rather than whole memory.


header_check:
	LD		A, MB			; Segment base for HLU
	ld		hl,pal_buffer
	call	_set_ahl24
	ld.lil	de,128	;this is the file length of the .PCX header
	ld	a,(pcx_handle)
	ld	c,a
	MOSCALL	mos_fread
	ld	a,(pal_buffer)
	cp	0x0A		;check magic number
	jp	nz,bad_format
	ld	a,(pal_buffer+2)
	cp	1		; 1 = RLE encoded, 0 = not encoded
	jp	nz,bad_format	;only support RLE
	ld	a,(pal_buffer+65)	;number of colour planes
	cp	1				;only support 1
	jp	nz,bad_format
	ld	a,(pal_buffer+3)	;The number of bits constituting one plane. Most often 1, 2, 4 or 8. 
							;would love to support 2, however, I have not seen it used yet so can't test it.
							;8 will require some more work to get the palette right.
	cp	4			;4 bits per pixel is supported
	jr	z,@F
;	cp	8			;8 bits per pixel will be supported
;	jr	z,@F
	cp	1			;1 bits per pixel is supported
	jr	z,@F
	jp	bad_format
@@:					;format is good (still not 100% thorough check though)
;	jp	close
;now we should check size and set screen size accordingly
;Setup steps
; 04 	4 	2 bytes 	The minimum x co-ordinate of the image position.
; 06 	6 	2 bytes 	The minimum y co-ordinate of the image position.
; 08 	8 	2 bytes 	The maximum x co-ordinate of the image position.
; 0A 	10 	2 bytes 	The maximum y co-ordinate of the image position. 
; Let's normalize the dimensions first to make the calculations easier below
	ld		hl,(pal_buffer+10)
	ld		de,(pal_buffer+6)
	or		a
	sbc		hl,de
	ld		(pal_buffer+10),hl

	ld		hl,(pal_buffer+8)
	ld		de,(pal_buffer+4)
	or		a
	sbc		hl,de
	ld		(pal_buffer+8),hl

;	call	calc_width	;DE = the width in stored pixels
	ld		de,(pal_buffer+8)	;actual width in pixels
	ld		hl,512
	or		a		;clear carry
	sbc		hl,de
	jr		nc,mode_20	;image is 512 wide
m20_too_tall:
	ld		hl,640
	or		a		;clear carry
	sbc		hl,de
	jr		nc,mode_0	;image is 640 wide
m0_too_tall:
	ld		hl,800
	or		a		;clear carry
	sbc		hl,de
	jr		nc,mode_16	;image is 800 wide
m16_too_tall:
	ld		hl,1024
	or		a		;clear carry
	sbc		hl,de
	jr		nc,mode_19	;image is 1024 wide

	jp		bad_format	;image is not a supported size
;	jp		nc,bad_format	;image is too large

;	ld		a,22	;VDU 22, mode
;	rst		10h
;	ld		a,3		;mode 3 = 640 x 240 x 64 - too many colours for current methods
;general plan will be to check the width and height to see which is the best size
;mode_9:
;	ld		a, 9		;mode  9 = 320 x 240 x 16
mode_20:
	ld		b,h		;save result of how many extra pixels we have
	ld		c,l
	ld		hl,(pal_buffer+10)
	ld		de,384		;max height
	ex		de,hl
	or		a
	sbc		hl,de
	jr		nc,@F
;	call	calc_width	;DE = the width in stored pixels
	ld		de,(pal_buffer+8)	;actual width in pixels
	jr		m20_too_tall	;try the larger mode although fewer colours
;	ld		de,384		;make sure it's no bigger than this
;	ld		hl,0		;screen is full
@@:

	ld		a,22	;VDU 22, mode
	rst		10h
	ld		a,20			;mode  20 = 512 x 384 x 64
	rst		10h
	ld		a,16	;for max_pal - could handle 64 but not sure how they are stored yet! 8bpp not working.
	jp		video_mode_set

mode_0:
	ld		b,h		;save result of how many extra pixels we have
	ld		c,l
	ld		hl,(pal_buffer+10)
	ld		de,480		;max height
	ex		de,hl
	or		a
	sbc		hl,de
	jr		nc,@F
;	call	calc_width	;DE = the width in stored pixels
	ld		de,(pal_buffer+8)	;actual width in pixels
	jr		m0_too_tall	;try the larger mode although fewer colours
;	ld		de,480		;make sure it's no bigger than this
;	ld		hl,0		;screen is full
@@:
	ld		a,22	;VDU 22, mode
	rst		10h
	xor		a			;mode  0 = 640 x 480 x 16
	rst		10h
	ld		a,16	;for max_pal
	jp		video_mode_set

mode_16:
	ld		b,h		;save result of how many extra pixels we have
	ld		c,l
	ld		hl,(pal_buffer+10)
	ld		de,600		;max height allowed
	ex		de,hl
	or		a
	sbc		hl,de		;HL = 600 - (max_y)
	jr		nc,@F
;	call	calc_width	;DE = the width in stored pixels
	ld		de,(pal_buffer+8)	;actual width in pixels
	jr		m16_too_tall	;maximise the vertical resolution
;	ld		de,600		;make sure it's no bigger than this
;	ld		hl,0		;screen is full

@@:
	ld		a,22	;VDU 22, mode
	rst		10h
	ld		a,16		;mode 16 = 800 x 600 x 4
	rst		10h
	ld		a,4		;for max_pal
	jp		video_mode_set

mode_19:
	ld		b,h		;save result of how many extra pixels we have
	ld		c,l
	ld		hl,(pal_buffer+10)
	ld		de,768		;max height
	ex		de,hl
	or		a
	sbc		hl,de		;HL = 768 - (max_y)
	jr		nc,@F
	ld		de,768		;make sure it's no bigger than this
	ld		hl,0		;screen is full
@@:
	ld		a,22	;VDU 22, mode
	rst		10h
	ld		a,19		;mode 19 = 1024 x 768 x 4 - requires 2.10.0+
	rst		10h
	ld		a,4		;for max_pal
	jp		video_mode_set

; This calculates the width of the image, including padding.
; We do not yet remove padding from images, so this may cause cosmetic issues.
; i.e. ignores coordinate issues but retains the padding in the image
; uses A, HL. returns value in DE
calc_width:
	ld		a,(pal_buffer+3)	;The number of bits constituting one plane. Most often 1, 2, 4 or 8. 
	ld		hl,(pal_buffer+0x42)
	cp		8			; 8 bits per pixel so 1 stored byte = 1 stored pixel
	jr		z,calc_width_done
	add		hl,hl		; double the result
	cp		4			; 4 bits per pixel so 1 stored byte = 2 stored pixels
	jr		z,calc_width_done
	add		hl,hl		; double the result for 2 bits per pixel
	add		hl,hl		; double the result for 1 bit per pixel
calc_width_done:
	ex		de,hl		;keep the value in DE
	ret

; Ready to continue with calculations as we have now chosen the video mode.
video_mode_set:
	ld		(max_pal),a	;store the maximum palette size
	srl		h			;halve the y difference to centre the image
	rr		l
	ld		(y_offset),hl
	srl		b			;halve the x difference to centre the image
	rr		c
	ld		(x_offset),bc
	ld		(pcx_max_y),de
;	ld		hl,(pal_buffer+8)	;re-fetch the total X
;	inc		hl			;offset of 1 for the inner loop below to work
;	ld		hl,(pal_buffer+0x42)
;	add		hl,hl		;number of stored pixels - note that it should be trimmed but not sure how to do that
;	call	calc_width	;returns width in DE
	ld		de,(pal_buffer+8)
	inc		de
	ld		(actual_max_x),de	;for the bitmap conversion
	ld		(actual_max_x2),de	;for the splitting
	call	physical_layout	;set up the coordinate system to be physical layout
; fix the expansion command to match the number of incoming bits
	ld		a,(pal_buffer+3)	;set up the expansion command - bits per pixel
	and		7		;8 is represented as 0 in the switch, otherwise 1 and 2 should work as is
	or		16
	ld		(bpp_patch),a
;turn off cursor first = VDU 23,1,0
	ld	a,23
	rst	10h
	ld	a,1
	rst	10h
	dec	a
	rst	10h
; hot patch the header if needed. Only works with 2 colours.
	ld	a,(pal_buffer+3)	;bits per pixel
	cp	1
	jr	nz,read_palette
	ld	hl,pal_buffer+0x10
	ld	a,(hl)
	ld	b,5		;5 more to check
@@:
	inc	hl
	or	(hl)
	djnz	@B
	or	a	;are they all zeros for the first 6?
	jr	nz,read_palette
	ld	a,255
	ld	(hl),a
	dec hl
	ld	(hl),a
	dec hl
	ld	(hl),a



;First we need to define the working palette (subset of the current)
;for Agon: VDU 19, l, p, r, g, b: Define logical colour
;b = colour to reassign, c = Gate Array hardware number (should be from 0x40-0x5f but will use a mask for safety)
read_palette:
	ld	hl,pal_buffer+0x10	; starts at byte 16 for 48 bytes 	The EGA palette for 16-color images in RGB order
	ld	b,16		;counter
max_pal:	equ	$-1
	ld	c,0			;current colour
@@:
	ld	a,19	;VDU 19
	rst	10h	;print it
	ld	a,c
	rst	10h	;print it - logcal
	ld	a,255
	rst	10h	;use RGB instead of physical map
	ld	a,(hl)
	rst	10h	;print it
	inc	hl
	ld	a,(hl)
	rst	10h	;print it
	inc	hl
	ld	a,(hl)
	rst	10h	;print it
	inc	hl
	inc	c
	djnz	@B


;setup the colour buffer string
;This is needed for all of the use cases. Each sub-area then prints
; the 16 characters of the map.
; Command 0: Write block to a buffer
; VDU 23, 0, &A0, bufferId; 0, length; <buffer-data>
; Change of method - instead of buffer, use the colour map each time.
pal_load:
	ld	hl,256+64	;this is the buffer number for the colour map
	call	clear_buffer	;ensure it's empty before you start.

	ld		hl,write_to_buf	;colour buffer location, 16 bytes buffer length
	ld		bc,8			;string length
	rst		18h	;write string, length is in BC



pal_no_ams:
	ld	hl,pal_buffer+0x10	; starts at byte 16 for 48 bytes 	The EGA palette for 16-color images. 

;	jp	exit
;+0 is Screen Mode

PAL_loop:

	ld	b,16	;number of colours to process

;now fill the buffer
PAL_lp1:
;	ld	a,27	;print next char literal
;	rst	10h		;for debugging
	ld	e,b
	ld	b,3	;6 bits for RBG, then need the AA at the end.
@@:
	ld	c,(hl)
	rl	c
	rla
	rl	c
	rla
	inc	hl
	djnz	@B
; Confirmed that the top 2 bits are A
	rla
	rla
	or	3	;set the bottom 2 bits
;	or	0c0h	;set top 2 bits - this will give ARGB 
;	rst	10h	;print the RGBA2222 mapping from the table
;reverse from RGBA to ABGR: - could build it backwards once we are confident this works
	ld	c,a
	ld	b,4
@@:
	rl	c
	rr	d	;temp to swap order
	rl	c
	rr	a
	rl	d	;pop it back out
;	rl	c
	rr	a
	djnz	@b

	ld	b,e	;restore outer loop counter.

	rst	10h	;print the RGBA2222 mapping from the table
			;might be ABGR2222 - then we need to do a little loop to reverse the order.

;	ld	a,c	;test routine
;	rst 10h	;print what is in A
;	ld	a,b
;	add	30h
;	rst	10h

	djnz	PAL_lp1


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

done_pal:
;	call	inline_print
;	db		CR,LF,0
;	jp		close
;	jp		testbuffs


scr_load:
;

;let's implement mode 19 and then fan out.
;this will need adjusting once we centre to add offsets
	ld	hl,0
	ld	(pcx_y),hl	;set up row count for number of rows to process

scr_outer_lp:
; We need to count the total number of rows, and make sure we havent exceeded the count.

;	ld	hl,(actual_max_x)		;this will be set for specific image width
;					;stored the width in create_bitmap string
;	srl	h			;halve it to get the number of bytes sent per row
;	rr	l			;noting we never use the real byte count, only the nibble count
;	inc	hl			;rounding up to the nearest even number as the file format
;	res	0,l			; pads out to an even number of nibbles.
;	ld	hl,(pal_buffer+0x42)	;number of stored bytes in the file allocated to the row
;	ld	(pcx_max_x),hl
	ld	hl,scr_buffer	;page aligned buffer
	ld	(scr_curbyte),hl	;need to convert this into a fetch byte routine for de-blocking

scr_rows_lp:
; set up the intro code first to do the row dump
; we are going to use 25 buffers so that we can keep painting new buffers and not change a buffer before it's re-used.
; We should probably blank the buffer first? Using command 2? If so, make it a subroutine?
; Command 0: Write block to a buffer
; VDU 23, 0, &A0, bufferId; 0, length; <buffer-data>
; Command 2: Clear a buffer
; VDU 23, 0, &A0, bufferId; 2
	ld	hl,0x0101	;buffer 257 for writing data to
	ld	c,l			;preseve it - might streamline later
	call	clear_buffer
	inc	l			;destination buffer = 258
	call	clear_buffer
	inc	l			;post split buffer = 259. 260 has the discard from the split.
	call	clear_buffer
	inc	l			;post split buffer = 259. 260 has the discard from the split.
	call	clear_buffer
	dec	l
	dec	l

;	jr	@F	;test by skipping over this buffer routine

	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0a0h
	rst	10h
	ld	a,c	; buffer for source address
	rst	10h
	ld	a,h
	rst	10h
	xor	a	;command 0
	rst	10h
	ld	hl,(pal_buffer+0x42)
;	ld	a, 40h	;half of 640 - there are 2 pixels per byte
	ld	a,l		;send row data width, little endian
	rst	10h
;	ld	a,1	;upper 16 bits of length.
	ld	a,h
	rst	10h	
@@:

	ld	hl,0
	ld	(pcx_x),hl	;set up row count for number of byte to send for the row

scr_inner_lp:
	call	fetch_byte
	cp	0xc0	;is it a literal byte or a flagged byte?
	jr	z,scr_inner_lp	;0xc0 is badly defined and can be skipped although other interpretations exist

	jr	c,scr_inner_literal
	and	0x3f	;loop count
	ld	b,a		;how many times to send next byte
	call	fetch_byte	;byte to repeat
	ld		hl,(pcx_x)	;get current width count
;	or		0x20	;debug
@@:
	inc		hl	;bytes sent
	rst		10h	;add it to the buffer.
	djnz	@b	;the correct number of times
	jr		scr_inner_chkwidth	;done

scr_inner_literal:
	ld		hl,(pcx_x)	;get current width count
	inc		hl	;bytes sent
;	or		0x20	;debug
	rst		10h	;add it to the buffer.

scr_inner_chkwidth:

	ld	(pcx_x),hl	;updated width count
	ex	de,hl
	ld	hl,(pal_buffer+0x42)
	or	a	;reset carry flag
	sbc	hl,de
;	jp	c,close	;debug
	jr	nz,scr_inner_lp
;	jp	close	;debug
;convert it to a bitmap now
; Command 72: Expand a bitmap
; VDU 23, 0, &A0, bufferId; 72, options, sourceBufferId; [width;] <mappingDataBufferId; | mapping-data...>
	ld	hl,258	;destination buffer
	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0a0h
	rst	10h
	ld	a,l	;destination buffer = 258
	rst	10h
	ld	a,h
	rst	10h
	ld	a,72
	rst	10h
	ld	a,4+16	;4 bits wide, mapping data is in a buffer - options.
bpp_patch:	equ	$-1	
;	ld	a,4		;4 bits wide
	rst	10h
	ld	a,l		;source buffer is HL - 1. L is fixed at 2 for now so this works.
	dec	a
	rst	10h
	ld	a,h
	rst	10h
	ld	a,64	;palette buffer - fixed buffer number 256+64
	rst	10h
	ld	a,1
	rst	10h

;Command 19: Split by width into blocks and spread across target buffers

;VDU 23, 0, &A0, bufferId; 19, width; [targetBufferId1;] [targetBufferId2;] ... 65535;

;This command essentially operates the same as command 18, but the block count is determined
; by the number of target buffers specified. The blocks are spread across the target buffers
; in the order they are specified, with one block placed in each target.

;Command 17: Split a buffer and spread across blocks, starting at target buffer ID

;VDU 23, 0, &A0, bufferId; 17, blockSize; targetBufferId;

	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0a0h
	rst	10h
	ld	a,l	;destination buffer = 258
	rst	10h
	ld	a,h
	rst	10h
	ld	a,17
	rst	10h
	ld	de,0000
actual_max_x2:	equ	$-2
	ld	a,e
	rst	10h
	ld	a,d
	rst	10h
	inc	hl
	ld	a,l		;Target 1 is HL 259 = HL + 1
	rst	10h
	ld	a,h
	rst	10h



; VDU 23, 27, &20, bufferId;              : REM Select bitmap (using a buffer ID)
; select_bitmap: (in HL)

	call	select_bitmap



; VDU 23, 27, &21, width; height; format  : REM Create bitmap from current buffer
;Valid values for the format parameter are:
;Value	Meaning
;0	RGBA8888 (4-bytes per pixel)
;1	RGBA2222 (1-bytes per pixel)
;2	Mono/Mask (1-bit per pixel)
;3	Reserved for internal use by VDP ("native" format)
; This will always be <pcx_width> x 1; format 1.
	push	bc
	ld	bc,8
	ld	hl,create_bitmap
	rst	18h
	pop	bc


; VDU 23, 27, 3, x; y;: Draw current bitmap on screen at pixel position x, y
; draw_bitmap
	call	draw_bitmap

; count the rows
	ld	hl,(pcx_y)
	inc	hl
	ld	(pcx_y),hl
	ex	de,hl
	ld	hl,(pcx_max_y)
	and	a
	sbc	hl,de
;	ld	a,(pcx_y)	;this should do 2 rows?
;	or	a

	jp	nz,scr_rows_lp
;	jp	c,scr_outer_lp

scr_done:
	ld		a,(timerfun)
	or		a
	jr		z,scr_done_waitkey

	ld  a, 8        ;0x08: mos_sysvars
	rst 08h         ;IX(U) now has sysvars
	ld	hl,timerfun	;how many seconds
	xor	a
	ld.lil  (ix+sysvar_vkeydown),a
; c is tickcount - 60 ticks = 1 sec @ 60Hz
; b is tickcheck
__keyloop_timerset:
	ld	c,60		;assume 60Hz
	ld.lil	b,(IX+sysvar_time)
__keyloop:
	ld.lil	a,(IX+sysvar_time)
	cp	b
	jr	z,__keyloop_notick
	ld	b,a
	dec	c
	jr	nz,__keyloop_notick
	dec	(hl)
	jr	z,__scr_done_exit
	jr	__keyloop_timerset

__keyloop_notick:

	ld.lil  a,(ix+sysvar_vkeydown)  ;Is a key down?
	or  a
	jr  z,__keyloop		;no key down
	ld.lil  a,(ix+sysvar_keyascii)  ;Is key down returning a character?
	or  a
	jr  z,__keyloop    ;if not, return no key down
	jr	__scr_done_exit


scr_done_waitkey:
	MOSCALL	mos_getkey
__scr_done_exit:
	ld		a,22	; VDU 22, mode - back to mode 0 on exit
	rst		10h
	xor		a
	rst		10h

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

;this will fetch byte from the rotating buffer.
;returns A
fetch_byte:
	push	hl
	ld	hl,(scr_curbyte)	;this will all be a getbyte routine
	ld	a,l
	or	a
	jr	nz,fetch_byte_ok
	push	hl	;preserve pointer
	ld		a, mb			; Segment base for HLU
	ld		hl,scr_buffer
	call	_set_ahl24
	ld.lil	de,256	;this is the size of the buffer
	ld	a,(pcx_handle)
	ld	c,a
	MOSCALL	mos_fread
	pop	hl
fetch_byte_ok:
	ld	a,(hl)			;fetch byte
	inc	l				;256 byte buffer!
	ld	(scr_curbyte),hl
	pop		hl
	ret

okusage:
	call usage
	jp	exit

badusage:	call usage
	jp	_err_invalid_param
;
; usage -- show syntax
; 
usage:	call	inline_print
	db	CR,LF,"PCXview utility for Agon by Shawn Sijnstra (c) 13-Jan-2026",CR,LF,CR,LF
	db	"Usage:",CR,LF
	db	"   PCXview file.PCX [1-9]",CR,LF,"where:",CR,LF
	db	"   1-9 is an optional parameter to wait for 1-9 seconds before exiting",CR,LF
	db	"   Supports images 640 wide in 16 colours, 800 and 1024 wide in 4 colours.",CR,LF
	db 	"   Minimum VDP version 2.10.0.",CR,LF,CR,LF,0
	ret



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

; VDU 23, 27, 3, x; y;: Draw current bitmap on screen at pixel position x, y
; Uses A, HL and DE
; Might do it inline - it's drawing at x=0, y = (c*8)+20 + scr_row
; Drawn at x = x_offset, y = pcx_y + y_offset but will later add offsets
draw_bitmap:
	ld	a,23
	rst	10h
	ld	a,27
	rst	10h
	ld	a,3
	rst	10h
;	xor	a	;x = 0 - this might get offset later when we do other widths
	ld	hl,0	;horizontal offset
x_offset:	equ	$-2
	ld	a,l
	rst	10h
	ld	a,h
	rst	10h
	ld	hl,(pcx_y)
	ld	de,0	;add vertical offset to row
y_offset:	equ	$-2
	add	hl,de
	ld	a,l		;little endian
	rst	10h
	ld	a,h
	rst	10h
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

;Strings for VDU controls
; VDU 23, 0, &A0, bufferId; 0, length; <buffer-data>
write_to_buf:
	db		23,0,0A0h, 64,1, 0, 16,0
;buffer ID = 256 + 64
;command 0
; length = 16

create_bitmap:
	db		23,27,021h,000h,04h,01,00,1	;1024 length default
actual_max_x:	equ	$-5	;why not store it in the string that needs length?

; VDU 23, 27, &21, width; height; format  : REM Create bitmap from buffer
;Valid values for the format parameter are:
;Value	Meaning
;0	RGBA8888 (4-bytes per pixel)
;1	RGBA2222 (1-bytes per pixel)
;2	Mono/Mask (1-bit per pixel)
;3	Reserved for internal use by VDP ("native" format)
; This will always be 480 (1E0h) x 1; format 1. Nope. It's 640 (0280h) x 1.
; nope - it's not width = 1024 = 0400h x 1. Width will need to be updated!

; data storage . . .
;	
; uninitialized storage/BSS but can't use that terminology because it's all in ROM space
;
; RAM
; 
;pre-set value:
timerfun:	db	0	;start initalised with a zero

argc:		DS	1	;store argc for later
pcx_handle:	DS	1	;Only needs 1 byte handle

scr_curbyte:	DS	2	;current byte location to display

;actual_max_x:	DS	2	;this is the actual width in pixels, i.e. 1024 or 640 etc
pcx_x:		DS	2	;current screen column in nibbles based on the raw data formats we can use
;pcx_max_x:	DS	2	;maximum screen column - i.e. image width in nibbles
pcx_y:		DS	2	;current screen row.
pcx_max_y:	DS	2	;maximum screen row - i.e. image height

pal_buffer:		DS	128	;Space to buffer header - could be overwritten by the screen buffer
		align	256
scr_buffer:		DS	256		;ultimately this is only a rotating buffer.
					;will be 256 bytes overlapping with previous buffer once ready
