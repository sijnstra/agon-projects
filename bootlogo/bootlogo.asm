;------------------------------------------------------------------------
;
;  ASM port of Steve Lovejoy's boot banner by Shawn Sijnstra
;  compiles natively using ez80asm
;  Copyright (c) 2024 Shawn Sijnstra, MIT license
;
;  ICON BY ARNOLD MESZAROS
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
		db	23,238,255,255,255,255,255,255,255,255	;this is a solid block, not logo - don't need
		db	23,0,148,128							;fetch the foreground colour into the sysvar

boot_logo_icon_end:

icon_line_1:	db		 "  ",200,201,"     Agon Light 2 with eZ80 CPU",13,10 ;
icon_line_2:	db		 "  ",202,203,"   ",13,10;
icon_line_3:	db		 " ",204,205,206,207,"  ",13,10			; if available VDP version
icon_line_4:	db		 208,209,210,211,212,213," ",13,10 		; if available MOS version
icon_line_5:	db		 214,215,216,209,217,218," Screen mode: $";
icon_line_6:	db 13,10,219,220,221,222,223,224,"        Text: $";
icon_line_7:	db 13,10,225,226,227,228,229,230,"    Graphics: $";
icon_line_8:	db 13,10,231,232,233,234,235,236,"     Colours: $";
full_icon_end:

printby_str:	db	" x $"
reset_fontload:	db	23,0,145,13,10,"$"
;get_fgcol:		db	23,0,148,128,"$"
current_col:	db	0
args:			db	0

;------------------------------------------------------------------------
;
;------------------------------------------------------------------------
main:

	ld	A,(HL)		;test if there was a command-line expression
	ld	(args),a	;save for later

noargs:
	ld	hl,boot_logo_icon
	ld	bc,boot_logo_icon_end - boot_logo_icon
	rst.lil	18h		;too variable data to use a terminator character
	moscall mos_sysvars		;I don't use IX so this should remain ok throughout
	ld		a,(ix+sysvar_scrpixelIndex)	;preserve the current foreground colour fetched at the beginning
	ld		(current_col),a
	ld	hl,icon_line_1
	call	puts
	ld		hl,0
	ld		l,(ix+sysvar_scrMode)	;get mode
	call	print_HLU_u24
	ld	hl,icon_line_6
	call	puts
	ld		hl,0
	ld		l,(ix+sysvar_scrCols)
	call	print_HLU_u24
	ld		hl,printby_str
	call	puts
	ld		hl,0
	ld		l,(ix+sysvar_scrRows)
	call	print_HLU_u24	
	ld	hl,icon_line_7
	call	puts
	ld		hl,0
	ld		l,(ix+sysvar_scrWidth)
	ld		h,(ix+sysvar_scrWidth+1)
	call	print_HLU_u24
	ld		hl,printby_str
	call	puts
	ld		hl,0
	ld		l,(ix+sysvar_scrHeight)
	ld		h,(ix+sysvar_scrHeight+1)
	call	print_HLU_u24
	ld	hl,icon_line_8
	call	puts
	ld		hl,0
	ld		l,(ix+sysvar_scrColours)
	call	print_HLU_u24
	call	newline
	ld		a,(args)
	or		a
	jr		nz,unfont		;if there's an arg, don't show the colour banner
	ld		b,(ix+sysvar_scrColours)
	ld		c,0
barloop:
	ld		a,17
	rst.lil	10h
	ld		a,c
	rst.lil	10h
	ld		a,238	;solid block we have defined
	rst.lil	10h		;print it
	ld		a,c
	cp		31	;end of line
	call	z,newline
	inc		c
	djnz	barloop
reset_colour:
	ld		a,17
	rst.lil	10h
	ld		a,(ix+sysvar_scrColours)
	dec		a
	and		15		;should be bright white on all palettes. Need to replace with "current colour"
	rst.lil	10h
unfont:
	ld		hl,reset_fontload
	jp		puts		;reset font, print newline and return to MOS wrapper
