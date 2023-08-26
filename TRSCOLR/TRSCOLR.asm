;	 TRSCOLR text colour changer for the Agon Light running TRS-OS/LS-DOS
;		Copyright (C) 2023 Shawn Sijnstra <shawn@sijnstra.com>
;
;
;
; Service call addresses
@GET	EQU	03H
@DSPLY	EQU	0AH
@PRINT	EQU	0EH	; output string to *PR
@INIT	EQU	3AH
@PUT	EQU	04H
@CLOSE	EQU	3CH
@ERROR	EQU	1AH
@ABORT	EQU	15H
@EXIT	EQU	16H
@PARAM	EQU	11H
@CLS	EQU	69H
@DSP	EQU	02H
@HIGH$	EQU	64H
@KEY	EQU	01H ; Obtain a character from the *KI device
@KBD	EQU	08H ; Scan the *KI device
@REW	EQU	44H	;This SVC will rewind a file to its beginning and reset the 3-byte NRN pointer to 0.
@KEYIN	EQU	09H	; Obtain a line of characters from *KI (or JCL)
@TIME	EQU	13H	; Obtain system time. This one needs 8 character buffer.
@SOUND	EQU	68H	; B has code-packed sound of tone and duration.

;UART0 addresses
;
UART0_PORT		EQU	0C0h		; UART0
				
UART0_REG_RBR:		EQU	UART0_PORT+0	; Receive buffer
UART0_REG_THR:		EQU	UART0_PORT+0	; Transmitter holding
UART0_REG_DLL:		EQU	UART0_PORT+0	; Divisor latch low
UART0_REG_IER:		EQU	UART0_PORT+1	; Interrupt enable
UART0_REG_DLH:		EQU	UART0_PORT+1	; Divisor latch high
UART0_REG_IIR:		EQU	UART0_PORT+2	; Interrupt identification
UART0_REG_FCT:		EQU	UART0_PORT+2;	; Flow control
UART0_REG_LCR:		EQU	UART0_PORT+3	; Line control
UART0_REG_MCR:		EQU	UART0_PORT+4	; Modem control
UART0_REG_LSR:		EQU	UART0_PORT+5	; Line status
UART0_REG_MSR:		EQU	UART0_PORT+6	; Modem status
UART0_REG_SCR:		EQU 	UART0_PORT+7	; Scratch

TX_WAIT			EQU	16384 		; Count before a TX times out

UART_LSR_ERR		EQU 	080h		; Error
UART_LSR_ETX		EQU 	040h		; Transmit empty
UART_LSR_ETH		EQU		020h		; Transmit holding register empty
UART_LSR_RDY		EQU		001h		; Data ready


		ORG	3000h

;
SVC	MACRO	#NUM
	LD	A,#NUM
	RST	28H
	ENDM
;
CR	EQU	0DH
LF	EQU	0AH
ESC	EQU	1BH
;
;
start:
	ld	a,(hl)	;Command arg pointer in HL from entry
	cp	'-'		;is is a valid parameter?
	jp	nz,usage	;print usage message

	inc	hl
	ld	a,(hl)
	sub	'0'
	jr	c,usage
	cp	9+1
	jr	c,col_store
	sub	'A'-'0'
	jr	c,usage
	add	10
	cp	16
	jr	nc,usage
col_store:
;    // Set foreground color
;    // Seq:
;    //   ESC FABGLEXT_STARTCODE FABGLEXTB_SETFGCOLOR COLORINDEX FABGLEXT_ENDCODE
;    // params:
;    //   COLORINDEX : 0..15 (index of Color enum)
; ESC _ l X $
; need to output straight to the port as @DSP doesn't do RAW, only cooked.
	ld	(colstring+3),a
	ld	hl,colstring
	ld	b,5	;string length
col_loop
	ld	a,(hl)
	call	UART0_serial_TX	;send raw
	inc	hl
	djnz	col_loop

	SVC	@EXIT

; Write a character to UART0
; Parameters:
; - A: Data to write
; Returns:
; - F: C if written
; - F: NC if timed out
;
UART0_serial_TX:
			PUSH		BC			; Stack BC
			PUSH		AF 			; Stack AF
			LD		BC,TX_WAIT		; Set CB to the transmit timeout
UART0_serial_TX1:
;			IN0		A,(UART0_REG_LSR)	; Get the line status register
			defb	0EDh,038h,UART0_REG_LSR		
			AND 		UART_LSR_ETX		; Check for TX empty
			JR		NZ, UART0_serial_TX2	; If set, then TX is empty, goto transmit
			DEC		BC
			LD		A, B
			OR		C
			JR		NZ, UART0_serial_TX1
			POP		AF			; We've timed out at this point so
			POP		BC			; Restore the stack
			OR		A			; Clear the carry flag and preserve A
			RET	
UART0_serial_TX2:
			POP		AF			; Good to send at this point, so
;			OUT0		(UART0_REG_THR),A	; Write the character to the UART transmit buffer
			defb	0EDh,039h,UART0_REG_THR
			POP		BC			; Restore BC
			SCF					; Set the carry flag
			RET


usage:
	ld	hl,usage_message
	SVC	@DSPLY
	SVC	@EXIT	;don't return an error - just gracefully exit

usage_message:
	defb	'TRS-OS Agon text colour changer',lf,'Copyright Shawn Sijnstra 2023',lf
	defb	'Usage: TRSCOLR -X where X is a hex digit from 0 (black)...F (bright white)',lf
	defb	'Source code available from https://github.com/sijnstra/agon-projects',lf,cr

; ESC _ l X $
colstring:
	defb	ESC,'_lX$'


	END		start