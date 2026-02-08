; PCX loader - buffer method
; PCX graphics format converter from 4bpp to 2bpp.
; Format checking is NOT thorough.
;
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
	cp	4	;too many parameters
	jp	nc,badusage

	cp	4
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
	db		"Input file not found:",0
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

	ld	(pcx_handle),a	;store the file handle number for pcx input file
;	call	inline_print
;	db		"Filename:",0
;	LD.LIL		HL,(IX+3)
;	call	print_HLU
;Now open PCM audio file
	LD.LIL		HL,(IX+6)		; HLU: pointer to first argument
	ld	c,fa_write + fa_create_always	;overwrite every time
	MOSCALL	mos_fopen
	or	a
	jr	nz,open_out_ok
	call	inline_print
	db		"Error creating:",0
	LD.LIL		HL,(IX+6)
	call	print_HLU
	ld	hl,4	;file not found/could not find file - error opening file [not necessarily correct error though]
	ret			;exit

open_out_ok:
	ld	(out_handle),a

;to convert:
;Copy first 128 bytes
;reduce byte 0x03 from 4 to 2 (bits per pixel)
;reduce word at 0x42 by 1/2 (it can't be odd - then we have to correct later!)

;Then for each row:
;read in row and expand it to expected length
;rewrite it to use 2 bpp, so it will halve in size
;compress the row by:
; check if current value is last value, if so, write and end
; compare current with next...until end or is different and count how many are the same
; write out encoded bytes straight to file as you go so you just need to track the total length.
;loop until end

;Use the blocked read to fetch bytes so 256 byte circular for fetching.
;Then you need 1 row to expand into = 1024 bytes max
;can halve it straight into the same spot
;then can write out from the same spot so only needs a 1k buffer on top.




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
	cp	4			;only 4 bits per pixel is supported
	jr	z,@F
	jp	bad_format
@@:					;format is good (still not 100% thorough check though)
; preserve the current video mode in case we change it
;;	moscall mos_sysvars		;I don't use IX so this should remain ok throughout
;;	ld		a,(ix + sysvar_scrMode)	;get mode
;;	ld		(return_screen_mode),a	;stash it in the restore mode
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
	ld		de,(pal_buffer+10)	;actual width in pixels

;	jp		nc,bad_format	;image is too large

;	ld		a,22	;VDU 22, mode
;	rst		10h
;	ld		a,3		;mode 3 = 640 x 240 x 64 - too many colours for current methods
;general plan will be to check the width and height to see which is the best size
;mode_9:
;	ld		a, 9		;mode  9 = 320 x 240 x 16

	ld		a,4	;don't need 16 - breaks the VDP if we have a 4 colour mode
				;for max_pal - could handle 64 but not sure how they are stored yet! 8bpp not working.
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
	cp		2			; 2 bits per pixel so 1 stored byte = 2 stored pixels
	jr		z,calc_width_done
	add		hl,hl		; double the result for 1 bit per pixel
calc_width_done:
	ex		de,hl		;keep the value in DE
	ret

; Ready to continue with calculations as we have now chosen the video mode.
video_mode_set:
;	ld		(max_pal),a	;store the maximum palette size

; This method is for cropping via the screen dimensions
;;	call	calc_width	;returns width in DE

; This method was for when we cropped the bitmap expansion:

;;	ld		(actual_max_x),de	;for the bitmap conversion

; new need to recalc how we do this bit
	inc		de			;suspect an off by 1 error below.
	ld		(pcx_max_y),de
	ld		de,(pal_buffer+8)


	ld		a,2
	ld		(pal_buffer+3),a	;set as 2 Bpp
	ld		hl,(pal_buffer+0x42)
	ld		(in_bytes_row),hl	;you'll need this later.
	srl		h
	rr		l
	jr		nc,done_hdrfix
	call	inline_print
	db		"PCX file insufficiently padded",0
	ld	hl,4	;file not found/could not find file - error opening file [not necessarily correct error though]
	ret			;exit


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

done_hdrfix:
	ld		(pal_buffer+0x42),hl
;	call	inline_print
;	db		CR,LF,0

;0x1B: mos_fwrite
;Write a block of data to a file (Requires MOS 1.03 or above)

;Parameters:

;C: File handle
;HLU: Pointer to a buffer that contains the data to write
;DEU: Number of bytes to write out

	ld		a,(out_handle)
	ld		c,a
	ld		hl,pal_buffer
	ld		de,128
	MOSCALL	mos_fwrite

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

; This setup is universal across all loops - the buffer is circular and unrelated to the loop workings
	ld	hl,scr_buffer	;Now full file buffer. page aligned buffer
	ld	(scr_curbyte),hl	;need to convert this into a fetch byte routine for de-blocking


scr_rows_lp:
; set up the intro code first to do the row dump
; Everything set up here needs to be set up for each row.


	ld	hl,exp_buffer
	ld	(buff_curbyte),hl

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
;	push	af	;testing by escaping all characters
;	ld		a,27
;	rst		10h
;	pop		af
;	rst		10h	;add it to the buffer.
	call	put_buff		;add to the output buffer!



	djnz	@b	;the correct number of times
	jr		scr_inner_chkwidth	;done

scr_inner_literal:
;	push	af	;testing by escaping all characters
;	ld		a,27
;	rst		10h
;	pop		af
	ld		hl,(pcx_x)	;get current width count
	inc		hl	;bytes sent
;	or		0x20	;debug
;	rst		10h	;add it to the buffer.

	call	put_buff	;add to the output buffer!

scr_inner_chkwidth:
;	ld	a,'+'
;	rst	10h
	ld	(pcx_x),hl	;updated width count
	ex	de,hl
	ld	hl,(in_bytes_row)	;because we've changed (pal_buffer+0x42)
	or	a	;reset carry flag
	sbc	hl,de
	jp	c,close	;debug
	jr	nz,scr_inner_lp
;	jp	close	;debug
;convert it to a bitmap now
; Command 72: Expand a bitmap
; VDU 23, 0, &A0, bufferId; 72, options, sourceBufferId; [width;] <mappingDataBufferId; | mapping-data...>

;Now we need to rewrite it to be half the length by cutting out bits 7,6,3,2 from every byte, and shifting everything left

	ld	bc,(pal_buffer+0x42)	;counter of new shorter length
	ld	hl,exp_buffer
	ld	de,exp_buffer

buff_4_to_2_lp:
	rl	(hl)	;throw away first 2 (bits 7,6)
	rl	(hl)
	rl	(hl)
	rla
	rl	(hl)
	rla
	rl	(hl)	;throw away these 2 (bits 3,2)
	rl	(hl)
	rl	(hl)
	rla
	rl	(hl)
	rla
	inc	hl		;next byte
	rl	(hl)	;throw away first 2 (bits 7,6)
	rl	(hl)
	rl	(hl)
	rla
	rl	(hl)
	rla
	rl	(hl)	;throw away these 2 (bits 3,2)
	rl	(hl)
	rl	(hl)
	rla
	rl	(hl)
	rla
	inc	hl
	ld	(de),a	;store result
	inc	de
	dec	bc
	ld	a,b
	or	c
	jr	nz,buff_4_to_2_lp	;loop until counter in zero	
; VDU 23, 27, &20, bufferId;              : REM Select bitmap (using a buffer ID)
; select_bitmap: (in HL)


;Now we need to RLE encoded and write out the new data

	ld	bc,(pal_buffer+0x42)	;counter of new shorter length
	ld	hl,exp_buffer
rle_out:
	ld	a,(hl)
	inc	hl
	dec	bc	;consumed 1 byte
	cp	0c0h	;needs encoding if it's this or higher anyway
	jr	nc,rle_encode
	ld	e,a		;in case it was the last byte
	ld	a,b
	or	c
	ld	a,e
	jr	z,rle_literal	;last solitary byte note compressible
	cp	(hl)
	jr	nz,rle_literal	;not compressible
rle_encode:
	ld	d,1	;there's currently 1 byte to encode
rle_enc_lp:
	cp	(hl)	;yes this is a repeat but solves the degerate case
	jr	nz,rle_write
	inc	hl
	inc	d

	bit	6,d
	jr	nz,rle_enc_back1
	dec	bc	;too many bytes?
	ld	e,a
	ld	a,b
	or	c
	ld	a,e
	jr	z,rle_write
	jr	rle_enc_lp

rle_enc_back1:	;roll back 1 byte so we start on the correct 1
	dec	hl
	dec	d

rle_write:
	ld	e,a
	ld	a,d
	or	0c0h
	call	put_byte
	ld	a,e
	call	put_byte
	jr	check_eol

rle_literal:
	call	put_byte	;push out the byte as it is
check_eol:
	ld	a,b			;already decremented - is it zero?
	or	c
	jr	nz,rle_out


	ld	a,'*'
	rst	10h

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

purge_buffers:
;no buffers to purge

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
;	MOSCALL	mos_getkey
__scr_done_exit:

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

put_buff:
	push	hl
	ld		hl,(buff_curbyte)
	ld		(hl),a
	inc		hl
	ld		(buff_curbyte),hl
	pop		hl
	ret	

put_byte:
	push	bc
	ld	b,a
	ld	a,(out_handle)
	ld	c,a
	moscall	mos_fputc
	pop		bc
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
	db	CR,LF,"PCX 4bpp to 2bpp converter utility for Agon by Shawn Sijnstra (c) 03-Feb-2026",CR,LF,CR,LF
	db	"Usage:",CR,LF
	db	"   PCX422 in_4bpp.PCX out_2bpp.PCX",CR,LF
	db 	"   Minimum VDP version 2.10.0.",CR,LF,CR,LF,0
	ret



; data storage . . .
;	
; uninitialized storage/BSS but can't use that terminology because it's all in ROM space
;
; RAM
; 
;pre-set value:
xpal_buffer:	equ	0x40000
xorg:			equ	0xb0000	;to offset all of the ld.lil that use this space.

timerfun:	db	0	;start initalised with a zero

argc:		DS	1	;store argc for later
pcx_handle:	DS	1	;Only needs 1 byte handle
out_handle:	DS	1	;one byte for the output file handle

scr_curbyte:	DS	2	;current byte location to display

;actual_max_x:	DS	2	;this is the actual width in pixels, i.e. 1024 or 640 etc
pcx_x:		DS	2	;current screen column in nibbles based on the raw data formats we can use
;pcx_max_x:	DS	2	;maximum screen column - i.e. image width in nibbles
pcx_y:		DS	2	;current screen row.
pcx_max_y:	DS	2	;maximum screen row - i.e. image height

in_bytes_row:	ds	2	;number of bytes per row on the input side.

buff_curbyte:	DS	2	;where are we in the screen buffer

pal_buffer:		DS	128	;Space to buffer header - could be overwritten by the screen buffer
		align	256
scr_buffer:		DS	256		;big enough for any file in this sequence
					;will be 256 bytes overlapping with previous buffer once ready
exp_buffer:		DS	2048	;enough for the biggest conversion of rows