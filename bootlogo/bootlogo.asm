;------------------------------------------------------------------------
;
;  ASM port of Steve Lovejoy's boot banner by Shawn Sijnstra
;  compiles natively using ez80asm
;  Enhanced version allows for Console8 logi instead of Agon
;  Copyright (c) 2024-5 Shawn Sijnstra, MIT license
;
;  Seated warrior ICON BY ARNOLD MESZAROS
;  Console 8 Icon rendered by Shawn Sijnstra
;------------------------------------------------------------------------

	ASSUME	ADL=1
	ORG		0B0000h
;
; Start in mixed mode. Assumes MBASE is set to correct segment
;
			JP		_start		; Jump to start
_exec_name:		db	"BOOTLOGO.BIN", 0		; The executable name, only used in argv
;
; The header stuff is from byte 64 onwards
;
			ALIGN	64
			
			db	"MOS"				; Flag for MOS - to confirm this is a valid MOS command
			db	00h				; MOS header version 0
			db	01h				; Flag for run mode (0: Z80, 1: ADL)



;
; And the code follows on immediately after the header
;
_start:
			push	AF			; Preserve the registers
			push	BC
			push	DE
			push	IX
			push	IY

			call		main			; Start user code
			ld			HL,0		; successful exit
			
			pop	IY			; Restore registers
			pop	IX
			pop	DE
			pop	BC
			pop	AF
			ret

	INCLUDE	"mos_api.inc"
	INCLUDE	"strings24.asm"
	INCLUDE	"arith24.asm"


; General storage - should be neater and all collected


;------------------------------------------------------------------------
;  Data area
;------------------------------------------------------------------------

boot_logo_icon:
		db	23,200,7,15,31,31,31,31,31,63
		db	23,201,192,224,240,240,240,240,240,248
 		db	23,202,63,63,31,15,15,15,7,7
		db	23,203,248,248,240,224,224,224,192,192
		db	23,204,0,1,7,15,31,63,127,127
		db	23,205,7,199,199,195,227,225,240,240
		db	23,206,192,195,195,135,135,15,15,31
		db	23,207,0,0,224,240,248,252,252,254
		db	23,208,0,0,1,1,3,3,7,7
		db	23,209,255,255,255,255,255,255,255,255
		db	23,210,248,248,248,240,224,225,193,195
		db	23,211,63,63,127,255,255,255,255,255
		db	23,212,255,255,255,255,255,255,223,223
		db	23,213,0,0,128,128,128,192,192,192
		db	23,214,7,7,15,15,15,15,15,31
		db	23,215,255,247,231,231,231,199,135,130
		db	23,216,199,135,135,143,15,15,31,31
		db	23,217,207,207,207,199,199,195,129,1
		db	23,218,224,224,224,240,240,240,240,240
		db	23,219,31,31,31,31,15,15,15,31
		db	23,220,128,128,128,128,129,143,135,143
		db	23,221,31,63,15,0,128,224,224,195
		db	23,222,252,240,128,0,3,7,35,243
		db	23,223,1,1,1,129,193,225,241,241
		db	23,224,240,240,240,240,240,240,240,240
		db	23,225,31,31,3,3,3,3,7,15
		db	23,226,223,255,255,255,255,255,254,254
		db	23,227,199,135,135,7,15,15,31,31
		db	23,228,241,241,241,248,248,248,248,248
		db	23,229,253,255,255,255,255,255,255,127
		db	23,230,240,248,248,224,224,224,240,248
		db	23,231,31,63,63,63,31,31,15,0
		db	23,232,254,252,252,252,248,248,224,0
		db	23,233,31,60,32,0,0,0,0,0
		db	23,234,120,28,12,12,0,0,0,0
		db	23,235,127,127,127,127,127,63,15,0
		db	23,236,248,252,252,252,252,248,240,0
		db	23,237,255,254,252,248,240,224,192,128
		db	23,238,255,255,255,255,255,255,255,255	;this is a solid block, not logo
boot_logo_icon_end:

boot_logo_c8:
		db	23,200,0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x06, 0x08
		db	23,201,0x00, 0x00, 0x00, 0x00, 0x7E, 0x81, 0x00, 0x7E
		db	23,202,0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x40, 0x30
		db	23,203,0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0x07, 0x0F
		db	23,204,0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0xFF, 0xC1
		db	23,205,0x00, 0x00, 0x00, 0x00, 0x00, 0xC0, 0xF0, 0xF8

		db	23,206,0x19, 0x22, 0x24, 0x48, 0x48, 0x90, 0x90, 0x90
		db	23,207,0x81, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
		db	23,208,0x88, 0x44, 0x24, 0x1E, 0x0E, 0x07, 0x07, 0x03
		db	23,209,0x1F, 0x3E, 0x1C, 0x08, 0x00, 0x00, 0x80, 0x80
		db	23,210,0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
		db	23,211,0xF8, 0x3C, 0x3C, 0x1E, 0x0E, 0x0F, 0x07, 0x07

		db	23,212,0x90, 0x90, 0x90, 0x90, 0x48, 0x48, 0x2C, 0x22
		db	23,213,0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
		db	23,214,0x03, 0x01, 0x01, 0x00, 0x00, 0x10, 0x28, 0x44
		db	23,215,0xC0, 0xE0, 0xE0, 0xF0, 0x70, 0x78, 0x3C, 0x1E
		db	23,216,0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
		db	23,217,0x07, 0x07, 0x07, 0x0F, 0x0E, 0x0E, 0x1E, 0x3C

		db	23,218,0x11, 0x08, 0x06, 0x01, 0x00, 0x00, 0x00, 0x00
		db	23,219,0x81, 0xFE, 0x00, 0x03, 0xFE, 0x00, 0x00, 0x00
		db	23,220,0x88, 0x10, 0x60, 0x80, 0x00, 0x00, 0x00, 0x00
		db	23,221,0x0F, 0x07, 0x03, 0x01, 0x00, 0x00, 0x00, 0x00
		db	23,222,0x00, 0xC3, 0xFF, 0xFF, 0x3E, 0x00, 0x00, 0x00
		db	23,223,0xF8, 0xF0, 0xE0, 0x80, 0x00, 0x00, 0x00, 0x00

		db	23,224,0x00, 0x00, 0x00, 0x1C, 0x26, 0x42, 0x40, 0x40
		db	23,225,0x00, 0x00, 0x00, 0x00, 0x00, 0x31, 0x49, 0x85
		db	23,226,0x00, 0x00, 0x00, 0x00, 0x00, 0x63, 0x94, 0x14
		db	23,227,0x00, 0x00, 0x00, 0x00, 0x00, 0x86, 0x49, 0x10
		db	23,228,0x00, 0x00, 0x00, 0x20, 0x20, 0x23, 0x24, 0xA8
		db	23,229,0x00, 0x00, 0x1c, 0x22, 0x22, 0x24, 0x88, 0x48

		db	23,230,0x40, 0x42, 0x26, 0x1C, 0x00, 0x00, 0x00, 0x00
		db	23,231,0x85, 0x85, 0x49, 0x31, 0x00, 0x00, 0x00, 0x00
		db	23,232,0x13, 0x10, 0x14, 0x13, 0x00, 0x00, 0x00, 0x00
		db	23,233,0x90, 0x50, 0x49, 0x86, 0x00, 0x00, 0x00, 0x00
		db	23,234,0xAF, 0xA8, 0x24, 0x13, 0x00, 0x00, 0x00, 0x00
		db	23,235,0x92, 0x22, 0xA2, 0x1C, 0x00, 0x00, 0x00, 0x00

		db	23,238,255,255,255,255,255,255,255,255	;this is a solid block, not logo

boot_logo_c8_end:

get_fgcol:
		db	23,0,148,128							;fetch the foreground colour into the sysvar

		db	'$'

icon_line_1:	db		 "  ",200,201,"     Agon Light 2 with eZ80 CPU",13,10 ;
icon_line_2:	db		 "  ",202,203,"   ",13,10;
icon_line_3:	db		 " ",204,205,206,207,"  ",13,10			; if available VDP version
icon_line_4:	db		 208,209,210,211,212,213," ",13,10 		; if available MOS version
icon_line_5:	db		 214,215,216,209,217,218," Screen mode: $";
icon_line_6:	db 13,10,219,220,221,222,223,224,"        Text: $";
icon_line_7:	db 13,10,225,226,227,228,229,230,"    Graphics: $";
icon_line_8:	db 13,10,231,232,233,234,235,236,"     Colours: $";
full_icon_end:

icc8_line_1:	db		 "        Agon Console8 with eZ80 CPU",13,10 ;
icc8_line_2:	db		 200,201,202,203,204,205,13,10;
icc8_line_3:	db		 206,207,208,209,210,211,13,10			; if available VDP version
icc8_line_4:	db		 212,213,214,215,216,217,13,10 		; if available MOS version
icc8_line_5:	db		 218,219,220,221,222,223," Screen mode: $";
icc8_line_6:	db 13,10,224,225,226,227,228,229,"        Text: $";
icc8_line_7:	db 13,10,230,231,232,233,234,235,"    Graphics: $";
icc8_line_8:	db 13,10,"           Colours: $";
full_icc8_end:

printby_str:	db	" x $"
reset_fontload:	db	23, 0, 0C3h	; Swap the screen buffer and/or wait for VSYNC **
				db	23, 0, 0C3h	; twice in case of double-buffer
				db	23,0,145,13,10,"$"
current_R:		db	0
current_B:		db	0
current_G:		db	0
current_index:	db	15
args:			db	0

;------------------------------------------------------------------------
;
;------------------------------------------------------------------------
main:
;parse any args
;-x = no colour banner
;-8 = console 8
;anything else = help
	ld	A,(HL)		;test if there was a command-line expression
	ld	(args),a	;save for later

	cp	'8'
	jr	z,console8	;testing first!

	ld	hl,boot_logo_icon
	ld	bc,boot_logo_icon_end - boot_logo_icon
	jr	logo_font

console8:
	ld	hl,boot_logo_c8
	ld	bc,boot_logo_c8_end - boot_logo_c8

logo_font:
	rst.lil	18h		;too variable data to use a terminator character


	moscall mos_sysvars		;I don't use IX so this should remain ok throughout
	res		2,(ix + sysvar_vpd_pflags)
	ld		hl,get_fgcol
	call	puts
	ld		hl,current_R	;preload where to store the RGB
current_col_wait:
	bit		2,(ix + sysvar_vpd_pflags)
	jr		z,current_col_wait		;wait for the update to have occurred
	ld		a,(ix + sysvar_scrpixel_R)	;preserve the current foreground colour fetched at the beginning
	ld		(hl),a
	inc		hl
	ld		a,(ix + sysvar_scrpixel_G)
	ld		(hl),a
	inc		hl
	ld		a,(ix + sysvar_scrpixel_B)
	ld		(hl),a
	ld		a,(args)
	cp		'8'
	jr		z,c8l1
	ld		hl,icon_line_1
	jr		agl1
c8l1:
	ld		hl,icc8_line_1
agl1:
	call	puts
	ld		hl,0
	ld		l,(ix + sysvar_scrMode)	;get mode
	call	print_HLU_u24
	ld		a,(args)
	cp		'8'
	jr		z,c8l6
	ld		hl,icon_line_6
	jr		agl6
c8l6:
	ld		hl,icc8_line_6
agl6:
	call	puts
	ld		hl,0
	ld		l,(ix + sysvar_scrCols)
	call	print_HLU_u24
	ld		hl,printby_str
	call	puts
	ld		hl,0
	ld		l,(ix + sysvar_scrRows)
	call	print_HLU_u24	
	ld		a,(args)
	cp		'8'
	jr		z,c8l7
	ld		hl,icon_line_7
	jr		agl7
c8l7:
	ld		hl,icc8_line_7
agl7:
	call	puts
	ld		hl,0
	ld		l,(ix + sysvar_scrWidth)
	ld		h,(ix + sysvar_scrWidth+1)
	call	print_HLU_u24
	ld		hl,printby_str
	call	puts
	ld		hl,0
	ld		l,(ix + sysvar_scrHeight)
	ld		h,(ix + sysvar_scrHeight+1)
	call	print_HLU_u24
	ld		a,(args)
	cp		'8'
	jr		z,c8l8
	ld		hl,icon_line_8
	jr		agl8
c8l8:
	ld		hl,icc8_line_8
agl8:
	call	puts
	ld		hl,0
	ld		l,(ix + sysvar_scrColours)
	call	print_HLU_u24
	call	newline
	ld		a,(args)
	cp		'8'
	jr		z,not_on_c8
	or		a
	jr		nz,unfont		;if there's an arg, don't show the colour banner
not_on_c8:
	ld		b,(ix + sysvar_scrColours)
	ld		c,0
barloop:
	ld		a,17
	rst.lil	10h
	ld		a,c
	rst.lil	10h
	ld		a,238	;solid block we have defined
	rst.lil	10h		;print it
	call	check_colour
	ld		a,c
	cp		31	;end of line
	call	z,newline
	inc		c
	djnz	barloop
reset_colour:
	ld		a,17
	rst.lil	10h
	ld		a,(current_index)
	rst.lil	10h
unfont:
	ld		hl,reset_fontload
	jp		puts		;reset font, print newline and return to MOS wrapper

;This routine checks whether the current colour matches the originally fetched colour
check_colour:
	res		2,(ix + sysvar_vpd_pflags)
	ld		hl,get_fgcol
	call	puts	;send the instruction
check_col_wait:
	bit		2,(ix + sysvar_vpd_pflags)
	jr		z,check_col_wait

	ld		hl,current_R
	ld		a,(ix + sysvar_scrpixel_R)	;lets check R
	cp		(hl)
	ret		nz
	inc		hl
	ld		a,(ix + sysvar_scrpixel_G)
	cp		(hl)
	ret		nz
	inc		hl
	ld		a,(ix + sysvar_scrpixel_B)
	cp		(hl)
	ret		nz
	ld		a,c
	ld		(current_index),a
	ret
