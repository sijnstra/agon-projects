;----------------------------------------------------------------------------
;ca1dagon.asm
; Agon version by Shawn Sijnstra August 2025 of:
;ca1dcpm.asm
;1-Dimensional Cellular Automaton
;For CP/M, 8080
;Use CA1D.ASM for the Intellec MDS888 (8080) running ISIS/OSIRIS
;By Roger Arrick
;9/4/2020
;Edit 23
;V1.1
;
;----------------------------------------------------------------------------
;To build on Agon:
;  ez80asm ca1dagon.asm
;----------------------------------------------------------------------------
;Operation:
;There are two 1-dim arrays -
;  ROW 1 is the new one being calculated and for display
;  ROW 2 is the previous row used for calculation.
;Starts with a single * in the middle of ROW 1.
;ROW 2 is built by applying the rule to ROW 1.
;ROW 2 is transferred to ROW 1 then sent to the console.
;ROW 2 is cleared for the next loop.
;Pressing SPACE pauses/continues display, any other character stops program.
;
;A rule is a 2 character hexidecimal byte value.
;
;Interesting rules:
;  1E Wolfram's rule 30
;  12 stacked pyramids
;  16 pyramids
;  99 right triangles
;  89 small upside triangles
;  E1, C3, 3C, 55, 66
;----------------------------------------------------------------------------

	ASSUME	ADL=0
	ORG		0	;0B0000h
;
; Start in mixed mode. Assumes MBASE is set to correct segment
;
			JP		_start		; Jump to start
			DS		5

RST_08:			RST.LIS		08h		; API call
			RET
			DS 		5
			
RST_10:			RST.LIS 	10h		; Output
			RET
			DS		5
			
RST_18:			RST.LIS 	18h		; Output string
			RET
			DS		5
		
RST_20:			DS		8
RST_28:			DS		8
RST_30:			DS		8	
;	
; The NMI interrupt vector (not currently used by AGON)
;
RST_38:				RST.LIS 	38h		; Output string

;
; The header stuff is from byte 64 onwards
;
			ALIGN	64
			
			db	"MOS"				; Flag for MOS - to confirm this is a valid MOS command
			db	00h				; MOS header version 0
			db	00h				; Flag for run mode (0: Z80, 1: ADL)

_exec_name:		db	"CA1DAGON.BIN", 0		; The executable name, only used in argv

;
; And the code follows on immediately after the header
;
_start:
			PUSH.LIL	IY			; Preserve IY
			LD		IY, 0			; Preserve SPS
			ADD		IY, SP
			PUSH.LIL	IY
			PUSH		AF			; Preserve the rest of the registers
			PUSH.LIL	BC
			PUSH.LIL	DE
			PUSH.LIL	IX

			call		main			; Start user code
			ld			HL,0		; successful exit
			
			POP.LIL		IX			; Restore the registers
			POP.LIL		DE
			POP.LIL		BC
			POP		AF

			POP.LIL		IY			; Get the preserved SPS
			LD		SP, IY			; Restore the SP
			
			POP.LIL		IY			; Restore IY
			RET.L					; Return to MOS

;	INCLUDE	"mos_api.inc"

COLS:	EQU 126	;78		;# of columns on screen.
				;Usually 80 or 132. -2 if terminal wraps automatically. - let's see if we can make this read off SYSVARS
halfcols:	equ	63	;39

BDOS:	EQU 0005h		;CP/M BDOS calls.
mos_getkey:		EQU	00h
mos_sysvars:		EQU	08h
sysvar_keyascii:        EQU 05h ; 1: ASCII keycode, or 0 if no key is pressed
sysvar_vkeydown:		EQU	18h	; 1: Virtual key state from FabGL (0=up, 1=down)
;RST 08h: Execute a MOS command
;RST 10h: Output a single character to the VDP
;RST 18h: Output a stream of characters to the VDP (MOS 1.03 or above)
;RST 38h: Outputs a crash report (MOS 2.3.0 or above)

CR:	EQU 0DH
LF:	EQU 0AH
STOP:	EQU 0		;String terminator for type routine.
BS:	EQU 5fh	;7fh	;08H
SPACE:	EQU 20H


main: 	;Assume stack is okay

	ld	a,mos_sysvars
	rst	08h	;IX(U) now has sysvars

	;Sign-on message.
	call	type
	DB 22,18	;set screen mode 18 - 1024x768 = 128x96 text
	DB CR,LF,"One-Dimensional Cellular Automaton",CR,LF
	DB	CR,LF,"Agon Version by Shawn Sijnstra 2025 adapted",CR,LF
	DB "from CP/M-80 version by Roger Arrick 2020 V1.1",CR,LF
	DB	CR,LF,"During display use spacebar to pause"
	DB	CR,LF,"any other key to return to this menu"
	DB	CR,LF,CR,LF
	DB "Some interesting rule examples are:"
	DB CR,LF,"1E, 12, 16, 55, 66, 89, 99, E1, C3",STOP

	;Set blob char.
	ld	a,'*'		;Default blob.
	ld	(BLOB),a
	;call	blobg		;Ask user to enter blob.

	;User enters rule.
	call	ruleg

	;Load initial conditions into Row 1.
	call	r1clr
	ld	a,(BLOB)
	ld	(ROW1+halfcols),a	;Put blob in middle of line.

;Main Loop -----------------------------------------------------
;
main1:
	;Display Row 1.
	call	rout

	;Calculate Row 2 from rule.
	call	rulee

	;Move Row 2 into Row 1.
	call	rmov

	;If user enters a space then pause, any other key then quit, else loop.
;	call	const		;Has user pressed a key?
	ld.lil	a,(ix+sysvar_vkeydown)	;is a key down?
	or	a
	jr	z,main1		;No - loop.
	ld.lil	a,(ix+sysvar_keyascii)	;get current key in A
	or	a			;is it a real key?
	jr	z,main1		;No (might just be shift or something) - loop.
;	call	conin		;Yes - Get character.
	cp	SPACE		;Space bar pause
;needs an exit key
	jp	nz,main		;Any other char stops.
	call	conin		;Wait for another char to resume.
wait_lp:
	ld.lil	a,(ix+sysvar_vkeydown)	;is a key down?
	or	a
	jr	nz,wait_lp		;loop around until the key is released
						;otherwise the user will be permanently caught up
	jp	main1		;Loop forever.

;----------------------------------------------------------------------------
;Rule Execute.  Calculate Row 2 by using rule on Row 1.
;Pseudo code.
;b=column counter, c=pattern, hl=row1, de=row2 being built.
;If b counter zero then done
;Get row 1 left into bit 2 of c.
;Get row 1 center into bit 1 of c.
;Get row 1 right into bit 0 of c.
;If pattern = 000 then
;  If rule bit 0 = 1 then set blob in row 2
;If pattern = 001 then
;  If rule bit 1 = 1 then set blob in row 2
;If pattern = 010 then
;  If rule bit 2 = 1 then set blob in row 2
;If pattern = 011 then
;  If rule bit 3 = 1 then set blob in row 2
;If pattern = 100 then
;  If rule bit 4 = 1 then set blob in row 2
;If pattern = 101 then
;  If rule bit 5 = 1 then set blob in row 2
;If pattern = 110 then
;  If rule bit 6 = 1 then set blob in row 2
;If pattern = 111 then
;  If rule bit 7 = 1 then set blob in row 2
;Increment row1 pointer and row2 pointer, decrement column counter.
;Loop
;
rulee:	;Setup variables.
	ld	hl,ROW1		;HL = Row 1 cell pointer.
	ld	de,ROW2		;DE = Row 2 cell pointer.
	ld	b,COLS		;B = Column count-down counter.

ruleel:	;Check for done.
	ld	a,b		;Column counter.
	cp	0		;If B=0 then done.
	ret	z

	;Create bit pattern in C according to row 1 cells.
	ld	c,0		;C = bit2=left, bit1=center, bit0=right

	;Get row 1 left into bit 2 of c.
	;If left is less than zero then wrap around and get far right.
	ld	a,b		;If counter = cols then at 0.
	cp	COLS
	jp	z,ruleex		;At left edge.
	dec	hl		;Get left of current cell.
	ld	a,(hl)
	inc	hl
	jp	ruleez
	;If left is beyond zero then wrap around and get far right edge.
ruleex:	ld	a,(ROW1+COLS-1)	;Get far right edge (wraparound).
	;Now set the bit.
ruleez:	cp	SPACE
	jp	z,rulee2		;If space then empty, don't set bit.
	ld	a,00000100b	;Set the bit.
	or	c
	ld	c,a		;Save in c.

rulee2:	;Get row 1 center into bit 1 of c.
	ld	a,(hl)
	cp	SPACE
	jp	z,rulee3		;If space then empty, don't set bit.
	ld	a,00000010b	;Set the bit.
	or	c
	ld	c,a		;Save in c.

rulee3:	;Get row 1 right into bit 0 of c.
	;If right is beyond cols then wrap around and get far left edge.
	ld	a,b		;if counter = 1 then at end.
	cp	1
	jp	z,ruleey
	inc	hl		;Get right of current cell.
	ld	a,(hl)
	dec	hl
	jp	ruleew
	;At far right edge, get far left edge (wrap around).
ruleey:	ld	a,(ROW1)		;Get far left edge (wraparound).
	;Now set the bit
ruleew:	cp	SPACE
	jp	z,rulee4		;If space then empty, don't set bit.
	ld	a,00000001b	;Set the bit.
	or	c
	ld	c,a		;Pattern bits in c.

	;Set row 2 cells according to row 1 pattern and rule bits.
rulee4:
	;Start by clearing the cell.
	ld	a,SPACE
	ld	(de),a

	;If cell pattern 000 then
	ld	a,c		;C=pattern bits.
	cp	00000000b
	jp	nz,rulee5
	;then if rule bit = 1 then
	ld	a,(RULE)		;Get the rule.
	and	00000001b
	jp	z,rulee5
	;Set row 2 cell
	ld	a,(BLOB)
	ld	(de),a

rulee5:	;If cell pattern 001 then
	ld	a,c		;C=pattern bits.
	cp	00000001b
	jp	nz,rulee6
	;then if rule bit = 1 then
	ld	a,(RULE)		;Get the rule.
	and	00000010b
	jp	z,rulee6
	;Set row 2 cell
	ld	a,(BLOB)
	ld	(de),a

rulee6:	;If cell pattern 010 then
	ld	a,c		;C=pattern bits.
	cp	00000010b
	jp	nz,rulee7
	;then if rule bit = 1 then
	ld	a,(RULE)	;Get the rule.
	and	00000100b
	jp	z,rulee7
	;Set row 2 cell
	ld	a,(BLOB)
	ld	(de),a

rulee7:	;If cell pattern 011 then
	ld	a,c		;C=pattern bits.
	cp	00000011b
	jp	nz,rulee8
	;then if rule bit = 1 then
	ld	a,(RULE)	;Get the rule.
	and	00001000b
	jp	z,rulee8
	;Set row 2 cell
	ld	a,(BLOB)
	ld	(de),a

rulee8:	;If cell pattern 100 then
	ld	a,c		;C=pattern bits.
	cp	00000100b
	jp	nz,rulee9
	;then if rule bit = 1 then
	ld	a,(RULE)	;Get the rule.
	and	00010000b
	jp	z,rulee9
	;Set row 2 cell
	ld	a,(BLOB)
	ld	(de),a

rulee9:	;If cell pattern 101 then
	ld	a,c		;C=pattern bits.
	cp	00000101b
	jp	nz,ruleea
	;then if rule bit = 1 then
	ld	a,(RULE)	;Get the rule.
	and	00100000b
	jp	z,ruleea
	;Set row 2 cell
	ld	a,(BLOB)
	ld	(de),a

ruleea:	;If cell pattern 110 then
	ld	a,c		;C=pattern bits.
	cp	00000110b
	jp	nz,ruleeb
	;then if rule bit = 1 then
	ld	a,(RULE)	;Get the rule.
	and	01000000b
	jp	z,ruleeb
	;Set row 2 cell
	ld	a,(BLOB)
	ld	(de),a

ruleeb:	;If cell pattern 111 then
	ld	a,c		;C=pattern bits.
	cp	00000111b
	jp	nz,ruleec
	;then if rule bit = 1 then
	ld	a,(RULE)	;Get the rule.
	and	10000000b
	jp	z,ruleec
	;Set row 2 cell
	ld	a,(BLOB)
	ld	(de),a

ruleec:	;Update pointers and counters for next loop.
	inc	hl		;Next row 1 cell location.
	inc	de		;Next row 2 cell location.
	dec	b		;Down count.

	jp	ruleel		;Loop until done with all cells in row

;----------------------------------------------------------------------------
;Get rule code from console as a 2-char hex word 0-FF (0-255) into RULE.
;Backspace restarts program.
;Destroys A.
;
ruleg:	call	type		;Ask
	db	CR,LF,"Enter Rule (00-ff, q/Q=quit): ",STOP
	call	hexin		;Get 2-char hex word from console into A
	ld	(RULE),a
	call	type
	db	CR,LF,STOP
ruleg_lp:
	ld.lil	a,(ix+sysvar_vkeydown)	;is a key down?
	or	a
	jr	nz,ruleg_lp		;loop around until the key is released
						;otherwise the user will be permanently caught up
	ret

;----------------------------------------------------------------------------
;Get blob char from user.
;Destroys A.
;
blobg:	call	type		;Ask
	db	CR,LF,"Enter blob char in hex (2A=*): ",STOP
	call	hexin		;Get 2-char hex word from console into A.
	ld	(BLOB),a
	ret

;----------------------------------------------------------------------------
;Display row 1.
;Destroys A.
;
rout:	push	hl		;Save regs.
	push	bc
	ld	hl,ROW1		;HL = Row.
	ld	b,COLS		;B = Columns counter.
	call	type
	db	CR,LF,STOP
routl:
	ld	a,(hl)		;Get char.
;	call	conout		;Display it.
	rst	10h		;display character
	inc	hl		;Point to next column.
	djnz	routl
routx:	pop	bc		;Restore regs.
	pop	hl
	ret

;----------------------------------------------------------------------------
;Clear row 1.
;Destroys A.
;
r1clr:	push	hl		;Save regs.
	push	bc
	ld	hl,ROW1		;HL = Row.
	ld	b,COLS		;B = Columns counter.
r1clrl:
	ld	(hl),SPACE		;Clear char.
	inc	hl		;Point to next column.
	djnz	r1clrl
r1clrx:	pop	bc		;Restore regs.
	pop	hl
	ret

;----------------------------------------------------------------------------
;Clear row 2.
;Destroys A.
;
r2clr:	push	hl		;Save regs.
	push	bc
	ld	hl,ROW2		;HL = Row.
	ld	b,COLS		;B = Columns counter.
r2clrl:
	ld	(hl),SPACE		;Clear char.
	inc	hl		;Point to next column.
	djnz	r2clrl
r2clrx:	pop	bc		;Restore regs.
	pop	hl
	ret

;----------------------------------------------------------------------------
;Move ROW 2 to ROW 1.
;Destroys A.
;
rmov:	push	hl		;Save regs.
	push	de
	push	bc
	ld	hl,ROW1		;HL = Row 1.
	ld	de,ROW2		;DE = Row 1.
	ld	b,COLS		;B = Columns counter.
rmov1:
	ld	a,(de)		;get row 2.
	ld	(hl),a		;put in row 1.
	inc	hl		;Point to next column.
	inc	de
	djnz	rmov1
rmovx:	pop	bc		;Restore regs.
	pop	de
	pop	hl
	ret

;----------------------------------------------------------------------------
;Type string following call to CO.
;
type:
	ex	(sp),hl			;Get pointer to string.
	push	bc		;Don't destroy BC.
type_lp:
	ld	a,(hl)		;Get the char.
	inc	hl		;Point to next char.
	cp	STOP		;Stop?
	jr	z,type1
	rst	10h
	jr	type_lp		;Next char.
type1:	pop	bc
	ex	(sp),hl			;Get return address back to caller.
	ret

;----------------------------------------------------------------------------
;Read 4-char hex byte from console.
;No validation.
;Return in HL.
;
hexinw:
	call	hexin		;Get hex byte
	ld	h,a		;High byte.
	call	hexin		;Get hex byte
	ld	l,a		;Low byte.
	ret

;----------------------------------------------------------------------------
;Read 2-char hex byte from console.
;No validation.
;Return in A.
;
hexin:	push	bc		;Don't destroy regs.
	call	hexine		;Get 1st char and echo.
	call	hexinc		;Convert char into value.
	ld	b,a		;Save temp.
	call	hexine		;Get 2nd char and echo.
	call	hexinc		;Convert char into value.
	ld	c,a		;Save temp.
	ld	a,b		;Put 1st value in high nibble.
	rlca
	rlca
	rlca
	rlca
	and	0f0h
	or	c		;Put 2nd value in low nibble.
	pop	bc		;Don't destroy regs.
	ret			;All done.
;Get char and echo, into A.
hexine:
	call	conin
	cp	BS		;BS restarts program.
	jp	z,main
	rst	10h	;display the character
	cp	'Q'		;Q=quit - note it's all coverter to upper case
	jp	z,done
;	ld	c,a
;	cp	BS		;BS restarts program.
;	jp	z,main
;	ld	a,c
	ret
;Convert ASCII char in A to a 4 bit value. 0-F = 0-15.
hexinc:	sub	'0'
	cp	10
	ret	m
	sub	7
	and	0fh
	ret

;----------------------------------------------------------------------------
;Console input.
;Returns character in A.
;
conin:
;	push	bc		;Save registers from destruction.
;	push	de
;	push	hl
;	ld	c,1		;Console input code.
;	call	BDOS
	ld	a,mos_getkey
	rst	08h
	or	a
	jr	z,conin	;this is in case you press shift
;	push	af
;	ld.lil	(ix+sysvar_keyascii),0
;	pop	af
	cp	96
	ret	c
	sub	32	;enforce upper case text characters
;	pop	hl
;	pop	de
;	pop	bc
	ret

;----------------------------------------------------------------------------
;Return to OS.
;
done:
	call	type		;New line.
	DB CR,LF,STOP
	pop	hl	;hexine
	pop	hl	;BC preserved in hexin
	pop	hl	;hexin
	pop	hl	;ruleg
	ret			;return from main to wrapper

;----------------------------------------------------------------------------
;Storage
;
BLOB:	ds	1		;Blob character.
RULE:	ds	1		;Rule low byte.
ROW1:	ds	COLS		;Row of elements displayed.
ROW2:	ds	COLS		;Row of elements being worked on.
;----------------------------------------------------------------------------
;	end
