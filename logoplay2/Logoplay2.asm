; Console8 logo player
; Assets converted by Shawn Sijnstra from original Console8 Heber logo
; Software built by Shawn Sijnstra
; Audio file is preloaded
; Video frames are full 256 dots across, 16 colours, 12 frames per second
;	cut down version for last 4.4 seconds of video to  fit in ram
;    stored as Turbo Vega compressed PCX, loaded in real time into the VDP to display as a bitmap.
;
; Written Agon native by Shawn Sijnstra



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

;Now open PCM audio file
	LD.LIL		HL,(IX+6)		; HLU: pointer to first argument
	ld	c,fa_read	;open read-only for straight through hex dump to the end
	MOSCALL	mos_fopen
	or	a
	jr	nz,open_pcm_ok
	call	inline_print
	db		"Not found:",0
	LD.LIL		HL,(IX+6)
	call	print_HLU
	ld	hl,4	;file not found/could not find file - error opening file [not necessarily correct error though]
	ret			;exit

open_pcm_ok:
	push	af
; Command 5, 1: Clear sample
; VDU 23, 0, &85, sample, 5, 1
	ld		a,23
	rst		10h
	xor		a
	rst		10h
	ld		a,085h
	rst		10h
	ld		a,-1
	rst		10h
	ld		a,5
	rst		10h
	ld		a,1
	rst		10h
	pop		af
	call.sil	full_file_slurp + xorg	;read in the full audio file.
;	ex		DE,HL		;HLU now has amount of loaded data
	push.lil	de
	pop.lil		hl		;HLU now has length of sample
	call	_get_ahl24	;now A has the MSB
	ld		b,a			;save it in B

; Command 5, 0: Load sample
; VDU 23, 0, &85, sample, 5, 0, length; lengthHighByte, <sampleData>
	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0x85
	rst	10h
	ld	a,-1	;sample -1
	rst	10h
	ld	a,5
	rst	10h
	xor	a
	rst	10h
	ld	a,l
	rst	10h
	ld	a,h
	rst	10h
	ld	a,b
	rst	10h

;	ex	de,hl	;only care about the bottom 16 bits for counting but all 24 are swapped
	inc	b	;make it easier to count
	ld.lil	hl,xpal_buffer

send_pcm_lp:
	ld	a,d
	or	e
	jr	z,send_pcm_outer	;check the outer loops
send_pcm_lp2:
	ld.lil	a,(hl)
	rst	10h
	inc.lil	hl
	dec	de
	jr	send_pcm_lp
send_pcm_outer:
	djnz	send_pcm_lp2

;Command 4: Set waveform
;VDU 23, 0, &85, channel, 4, waveformOrSample, [bufferId;]

	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0x85
	rst	10h
	ld	a,1		;channel
	rst	10h
	ld	a,4
	rst	10h
	ld	a,-1	;sample -1
	rst	10h

; Enable channel
; Command 8: Enable Channel
; VDU 23, 0, &85, channel, 8

	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0x85
	rst	10h
	ld	a,1		;channel
	rst	10h
	ld	a,8
	rst	10h



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
; 512 up to 512 + height = each row of the image (freed at the end)

; The EGA palette is within the same file as the rest of the file. The header is only 128 bytes.
; We could actually load that first, then load the whole picture file or load it in pages over the top.
; We are using 256 byte blocks, this means we can keep keep this utility to a minium size as a moslet
; rather than whole memory.

	ld	a,(pcx_handle)
	call.sil	full_file_slurp + xorg
	ld.lil	hl,xpal_buffer
	ld.lil	(cur_ptr_24+xorg),hl
	ld		a,46	;150
	ld		(frame_counter),a
;turn off cursor first = VDU 23,1,0
	ld	a,23
	rst	10h
	ld	a,1
	rst	10h
	dec	a
	rst	10h
	call	physical_layout	;set up the coordinate system to be physical layout once only
	jr		grab_next_header

	.ASSUME	adl=1
full_file_slurp:
;	ret
	ld	c,a	;handle
	ld.lil	hl,xpal_buffer
	ld.lil	de,0x06ffff		;grab the entire file up to 448k	;this is the file length of the .PCX header
;	ld	a,(pcx_handle)		;already in A
	ld	a,MB
	push	AF
	xor	a
	ld	mb,a
;	MOSCALL	mos_fread
	ld	a,mos_fread		;24 bit call
	rst.lil	08h
	pop	AF
	ld	mb,a

	ret.L

file_slurp_128:
;	ret

	ld	c,a	;handle
	ld.lil	hl,xpal_buffer
	ld.lil	de,128		;this is the file length of the .PCX header
;	ld	a,(pcx_handle)		;already in A
	ld	a,MB
	push	AF
	xor	a
	ld	mb,a
;	MOSCALL	mos_fread
	ld	a,mos_fread		;24 bit call
	rst.lil	08h
	pop	AF
	ld	mb,a

	ret.L

file_slurp_16:
;	ret

	ld	c,a	;handle
	ld.lil	hl,xpal_buffer
	ld.lil	de,256	;16		;this is the file length of the .PCX header
;	ld	a,(pcx_handle)		;already in A
	ld	a,MB
	push	AF
	xor	a
	ld	mb,a
;	MOSCALL	mos_fread
	ld	a,mos_fread		;24 bit call
	rst.lil	08h
	pop	AF
	ld	mb,a

	ret.L

file_slurp_frame:
;	ret

	ld	c,a	;handle
	ld.lil	hl,xpal_buffer
	ld.lil	de,9788	;8128	;7168	;12288		;size of a single frame
;	ld	a,(pcx_handle)		;already in A
	ld	a,MB
	push	AF
	xor	a
	ld	mb,a
;	MOSCALL	mos_fread
	ld	a,mos_fread		;24 bit call
	rst.lil	08h
	pop	AF
	ld	mb,a

	ret.L

	.ASSUME	adl=0
;copy 128 byte header into the old header location
;Note this has been rewritten so the header is only stored once in the data file now.
grab_next_header:
;	jp		close
; just grab the header first
	ld	a,(pcx_handle)
;	call.sil	file_slurp_128 + xorg
;	ld.lil	hl,xpal_buffer
;	ld.lil	(cur_ptr_24+xorg),hl

	ld.lil	hl,(cur_ptr_24+xorg)
	ld.lil	de,pal_buffer+xorg
	ld.lil	bc,128
	ldir.lil
	ld.lil	(cur_ptr_24+xorg),hl

header_check:
;	LD		A, MB			; Segment base for HLU
;	ld		hl,pal_buffer
;	call	_set_ahl24

	ld	a,(pal_buffer)
	cp	0x0A		;check magic number
	jp	nz,bad_format
	ld	a,(pal_buffer+2)
	cp	0		; 1 = RLE encoded, 0 = not encoded - this will help detect the right file
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
	cp	2			;2 bits per pixel - not implemented by zsoft
	jr	z,@F
	cp	1			;1 bits per pixel is supported
	jr	z,@F
	jp	bad_format
@@:					;format is good (still not 100% thorough check though)
; Not going to preserve the current video mode for this version
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

	ld		de,(pal_buffer+8)	;actual width in pixels
	ld		hl,320
	or		a		;clear carry
	sbc		hl,de
	jr		nc,mode_8	;image is 512 wide
m8_too_tall:

	jp		bad_format	;image is not a supported size

mode_8:
	ld		b,h		;save result of how many extra pixels we have
	ld		c,l
	ld		hl,(pal_buffer+10)
	ld		de,240		;max height
	ex		de,hl
	or		a
	sbc		hl,de
	jr		nc,@F
	ld		de,(pal_buffer+8)	;actual width in pixels
	jr		m8_too_tall	;bad file for this purpose

@@:
; Currently not setting video mode in here although we could. This means the preferred resolution
; needs to be set in the script.
;;	ld		a,22	;VDU 22, mode
;;	rst		10h
;;	ld		a,8			;mode  8 = 320 x 240 x 64
;;	rst		10h
	ld		a,16

	jp		video_mode_set


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


; new need to recalc how we do this bit
	ld		de,(pal_buffer+8)


; fix the expansion command to match the number of incoming bits
	ld		a,(pal_buffer+3)	;set up the expansion command - bits per pixel
	and		7		;8 is represented as 0 in the switch, otherwise 1 and 2 should work as is
	or		16
	ld		(bpp_patch),a

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


;all set up now so do the audio!
;Command 0: Play note
;VDU 23, 0, &85, channel, 0, volume, frequency; duration;
;Additionally using a duration of zero on a channel that has been set to playback a sample, the sample will be played for its full duration. 

	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0x85
	rst	10h
	ld	a,1		;channel
	rst	10h
	ld	a,0		;play
	rst	10h
	ld	a,127	;Full volume
	rst	10h
	ld	a,100	;frequency
	rst	10h
	xor	a
	rst	10h		;frequency MSB
	rst	10h		;duration
	rst	10h



scr_load:
;Set up the pointer for the loops. We are now pushing control back to the byte fetch to interleave the operations.
;	ld.lil	hl,xpal_buffer
;	ld.lil	(cur_ptr_24+xorg),hl


grab_next_frame:
;	grab the next frame


	ld	hl,0
	ld	(pcx_y),hl	;set up row count for number of rows to process


scr_rows_lp:
; 
; we are going to use 16 buffers so that we can keep painting new buffers and not change a buffer before it's re-used.
; We are processing an entire frame at a time
; Command 0: Write block to a buffer
; VDU 23, 0, &A0, bufferId; 0, length; <buffer-data>
; Command 2: Clear a buffer
; VDU 23, 0, &A0, bufferId; 2
;	ld	hl,0x0101	;buffer 257 for writing data to
;	ld	hl,(pcx_y)	;row+512 for the buffer. Now we are only using a single buffer.
;	inc	h
;	inc	h
	ld	h,2			;buffer is 512+frame number for each frame. Will need to add erase at the end!
	ld	a,(frame_counter)
	and	15			;cycle through them but give them time to recover
	ld	l,a
	call	clear_buffer
;	inc	l			;destination buffer = 258
;;	ld	(destfix),hl
;	call	clear_buffer


;	jr	@F	;test by skipping over this buffer routine

	ld	a,23
	rst	10h
	xor	a			; write a buffer
	rst	10h
	ld	a,0a0h
	rst	10h
	ld	a,l	; buffer for source address
	rst	10h
	ld	a,h
	rst	10h
	xor	a	;command 0
	rst	10h
;;	ld	hl,3600	;7200	;80 bytes per row, 90 rows = 8800 bytes total. (pal_buffer+0x42)
	ld	hl,9788	;8128	;7168	;2e80h	;28800	;2a09h	;2b00h - 080h	;	-77 ;We are experimenting with having a totally standard size that we send over.2A0Ah	;
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
;scr_inner_literal:
;	push	af	;testing by escaping all characters
;	ld		a,27
;	rst		10h
;	pop		af
	ld		hl,(pcx_x)	;get current width count
	inc		hl	;bytes sent
;	or		0x20	;debug
	rst		10h	;add it to the buffer.

;scr_inner_chkwidth:

	ld	(pcx_x),hl	;updated width count
	ex	de,hl
	ld	hl,9788	;8128	;7168	;2e80h	;28800	;2a09h	;2b00h - 080h	;	-77 ;	3600	;7200		;It's actually 2A0Ah
					;64 bytes per row. 96 rows, so total is 6144. (pal_buffer+0x42)
	or	a	;reset carry flag
	sbc	hl,de
;	jp	c,close	;debug
	jr	nz,scr_inner_lp
;	jp	close	;debug

;Now we need to decompress this buffer. Let's keep the same buffer for this.

;Command 65: Decompress a buffer
;VDU 23, 0, &A0, targetBufferId; 65, sourceBufferId;

	ld	h,2			;buffer is 512+frame number for each frame. Will need to add erase at the end!
	ld	a,(frame_counter)
	and	15			;cycle through them but give them time to recover
	ld	l,a
;	jr	@F
	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0a0h
	rst	10h
	ld	a,l	;destination buffer from above
;;	inc	a
	rst	10h
	ld	a,h
	rst	10h
	ld	a,65
	rst	10h
	ld	a,l	;source buffer from above
	rst	10h
	ld	a,h
	rst	10h

;;	inc l
@@:
;	jp	close	;debug
;	jr	drawtest
;convert it to a bitmap now
; Command 72: Expand a bitmap
; VDU 23, 0, &A0, bufferId; 72, options, sourceBufferId; [width;] <mappingDataBufferId; | mapping-data...>

	ld	a,23
	rst	10h
	xor	a
	rst	10h
	ld	a,0a0h
	rst	10h
	ld	a,l	;destination buffer from above
	rst	10h
	ld	a,h
	rst	10h
	ld	a,72
	rst	10h
	ld	a,4+16	;4 bits wide, mapping data is in a buffer (default). Adjusted for bit width.
bpp_patch:	equ	$-1	
	rst	10h
	ld	a,l		;source buffer is HL - write to the same buffer.
	rst	10h
	ld	a,h
	rst	10h
	ld	a,64	;palette buffer - fixed buffer number 256+64
	rst	10h
	ld	a,1
	rst	10h

;	jp	close	;debug

; VDU 23, 27, &20, bufferId;              : REM Select bitmap (using a buffer ID)
; select_bitmap: (in HL)

drawtest:
	call	select_bitmap



; VDU 23, 27, &21, width; height; format  : REM Create bitmap from current buffer
;Valid values for the format parameter are:
;Value	Meaning
;0	RGBA8888 (4-bytes per pixel)
;1	RGBA2222 (1-bytes per pixel)
;2	Mono/Mask (1-bit per pixel)
;3	Reserved for internal use by VDP ("native" format)
; This will always be <pcx_width> x 1; format 1. When converting a single row.
	push	bc
	ld	bc,8
	ld	hl,create_bitmap
	rst	18h
	pop	bc


; VDU 23, 27, 3, x; y;: Draw current bitmap on screen at pixel position x, y
; draw_bitmap
	call	draw_bitmap



; VDU 23, 0, &CA: Flush current drawing commands §§§§§
;;	ld	a,23
;;	rst	10h
;;	xor	a
;;	rst	10h
;;	ld	a,0cah
;;	rst	10h


;	MOSCALL	mos_getkey	;testing
;	jp		close
	ld		a,(frame_counter)
	dec		a
	ld		(frame_counter),a
	jp		nz,grab_next_frame

purge_buffers:
	ld	hl,512	;first buffer to purge from the large set. Ignoring the palette at the moment.
;	ld	b,16	;150	;number of buffers to purge
	ld	b,150
purge_loop:
	call	clear_buffer
	inc		hl
	djnz	purge_loop

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
;	MOSCALL	mos_getkey	;for the waiting key exit version only
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

;this will fetch the next byte from ram
;returns A
fetch_byte:
	push	hl
	ld.lil	hl,(cur_ptr_24+xorg)
fetch_byte_ok:
	ld.lil	a,(hl)			;fetch byte
	inc.lil	hl				;linear buffer as all files are now short
	ld.lil	(cur_ptr_24+xorg),hl
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
	db	CR,LF,"PCZview utility for Agon by Shawn Sijnstra (c) 04-May-2026",CR,LF,CR,LF
	db	"Usage:",CR,LF
	db	"   Customised PCXview file.PCX.blob audio.PCM [1-9]",CR,LF
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
; Bitmap plots (PLOT codes &E8-&EF)
; 5 (D) 	Plot absolute in current foreground colour
; VDU 25, code, x; y;
draw_bitmap:
;	ld	a,23
;	rst	10h
;	ld	a,27
;	rst	10h
;	ld	a,3
;	rst	10h
	ld	a,25
	rst	10h
	ld	a,0xED
	rst	10h
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
;	db		23,27,021h,000h,04h,01,00,1	;1024 length default
;actual_max_x:	equ	$-5	;why not store it in the string that needs length?
	db		23,27,021h
;	dw		128,72
;	dw		160,90
;	dw		320,180
;	dw		240,136
	dw		256,144
	db		1
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
xpal_buffer:	equ	0x40000
xorg:			equ	0xb0000	;to offset all of the ld.lil that use this space.

timerfun:	db	0	;start initalised with a zero

argc:		DS	1	;store argc for later
pcx_handle:	DS	1	;Only needs 1 byte handle

scr_curbyte:	DS	2	;current byte location to display

;actual_max_x:	DS	2	;this is the actual width in pixels, i.e. 1024 or 640 etc
pcx_x:		DS	2	;current screen column in nibbles based on the raw data formats we can use
;pcx_max_x:	DS	2	;maximum screen column - i.e. image width in nibbles
pcx_y:		DS	2	;current screen row.
pcx_max_y:	DS	2	;maximum screen row - i.e. image height

frame_counter:	DS	1
cur_ptr_24:	ds	3	;3 bytes to store the current RAM pointer
		align	256	;lets try to align these buffers now
pal_buffer:		DS	128	;Space to buffer header - could be overwritten by the screen buffer
		align	256
scr_buffer:		DS	4096		;big enough for any file in this sequence
					;will be 256 bytes overlapping with previous buffer once ready
