; CHARIO hex utility
;
;
; Written Agon native by Shawn Sijnstra (c) January 2024
;
; Purpose: Demonstrate terminal mode entry and exit, and provide a simple test for
;			showing the hex values for input keys except:
;			Escape is captured and shown as an 'e', with the following 2 characters
;			displayed literally. This is mainly to show what arrow keys and function
;			keys return.
; Note: Exit requires Console8 vdp 2.2.1, and does not gracefully exit with MOS vdp 1.0.4
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

UART0_PORT		EQU	%C0		; UART0
				
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

UART_LSR_ERR		EQU 	%80		; Error
UART_LSR_ETX		EQU 	%40		; Transmit empty
UART_LSR_ETH		EQU	%20		; Transmit holding register empty
UART_LSR_RDY		EQU	%01		; Data ready

;For reference, these are the IER bits. MOS only uses Receive Interrupt today.
UART_IER_RECEIVEINT:				equ 01h		;Receive Interrupt bit in IER.
UART_IER_TRANSMITINT:				equ 02h		;Transmit Interrupt bit in IER.
UART_IER_LINESTATUSINT:				equ 04h		;Line Status Interrupt bit in IER.
UART_IER_MODEMINT:					equ 08h		;Modem Interrupt bit in IER.
UART_IER_TRANSCOMPLETEINT:			equ 10h		;Transmission Complete Interrupt bit in IER.

			.ASSUME	ADL = 0				

			INCLUDE	"equs.inc"
			INCLUDE "mos_api.inc"	; In MOS/src

			SEGMENT CODE
	
			XDEF	_main

			


; Get a GPIO register
; Parameters:
; - REG: Register to test
; - VAL: Bit(s) to test
;	
GET_GPIO:		MACRO	REG, VAL
			IN0	A,(REG)
			TST	A, VAL
			ENDMACRO

; ASCII
;
CtrlC:	equ	03h
cr:	equ	0Dh
lf:	equ	0Ah
esc:	equ	1Bh
CtrlZ:	equ	1Ah
;

_main:

	call	inline_print
	db		cr,lf,'Simple Character I/O test for terminal mode',cr,lf	;Prints to screen in case switch below
	db		'By Shawn Sijnstra 08-Jan-2024',cr,lf
	db		'Switching to Terminal Mode',cr,lf,0

	ld		a,17h	;outputting due to zero require mid-string.
	RST		10h		;VDU 23,
	xor		a
	RST		10h		;0,
	dec		a
	RST		10h		;255

;Disable interrupts from UART0


	xor	a
	out0 (UART0_REG_IER), a ; Disable all interrupts on UART0.

	ld a, 6
	out0 (UART0_REG_FCT), a ; Turn off flow control interrupt

	call	prt_msg
	db		'Terminal mode enabled. Press CTRL-C to exit.',cr,lf,0

io_loop:
;get characters
$$:			CALL 		UART0_serial_RX
			JR		NC,$B
			or		a
			jr		z,$b
			cp		3
			jr		z,exit
			cp		esc
			jp		z,esc_sequence
			call	Print_Hex8
			jr	io_loop

exit:
	call	inline_print
	db	cr,lf,'CTRL-C detected. Exit to Terminal mode. Press reset if prompt fails.',cr,lf
	db	esc,'_#Q!$'		;QUIT out of terminal mode
	db	0	;string terminator

	ld 		a, 7
	out0 	(UART0_REG_FCT), a ; Turn on flow control interrupt and clear FIFO

	ld		a,1				; Restore IER status
	out0	(UART0_REG_IER),a

	ld		hl,0	;for Agon = successful exit
	ret

esc_sequence:
	ld	a,' '			;print ' e' instead of the hex for ESCAPE as it makes the sequences easier to read.
	call	printA
	ld	a,'e'
	call	printA
$$:	CALL 		UART0_serial_RX	;Assumes 2 characters follow. This should be true for arrows and function keys.
	JR		NC,$B
	call	printA
$$:	CALL 		UART0_serial_RX
	JR		NC,$B
	call	printA
	jp		io_loop

printA:
			PUSH	AF
			CALL	NZ, UART0_wait_CTS		; Wait for clear to send signal
			POP	AF
$$:			CALL	UART0_serial_TX			; Send the character
			JR	NC, $B				; Repeat until sent
			ret
;
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
prt_msg:	pop	hl
	call	uart0_string
	jp	(hl)
; more efficient print string for strings > 1 character
$$:
			PUSH	AF
			CALL	UART0_wait_CTS		; Wait for clear to send signal
			POP	AF
inlp:			CALL	UART0_serial_TX			; Send the character
			JR	NC, inlp				; Repeat until sent
	inc	hl
uart0_string:	ld	a,(hl)
	or	a
	jr	nz,$b
	ret

Print_Hex8:		LD	C,A
			RRA 
			RRA 
			RRA 
			RRA 
			CALL	$F 
			LD	A,C 
$$:			AND	0Fh
			ADD	A,90h
			DAA
			ADC	A,40h
			DAA
			PUSH	AF
			CALL	UART0_wait_CTS		; Wait for clear to send signal
			POP	AF
$$:			CALL	UART0_serial_TX			; Send the character
			JR	NC, $B				; Repeat until sent
			RET
;
; Check whether we're clear to send (UART0 only)
;

UART0_wait_CTS:		GET_GPIO	PD_DR, 8		; Check Port D, bit 3 (CTS)
			JR		NZ, UART0_wait_CTS
			RET

; Write a character to UART0
; Parameters:
; - A: Data to write
; Returns:
; - F: C if written
; - F: NC if timed out
;
UART0_serial_TX:	PUSH		BC			; Stack BC
			PUSH		AF 			; Stack AF
			LD		BC,TX_WAIT		; Set CB to the transmit timeout
UART0_serial_TX1:	IN0		A,(UART0_REG_LSR)	; Get the line status register
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
UART0_serial_TX2:	POP		AF			; Good to send at this point, so
			OUT0		(UART0_REG_THR),A	; Write the character to the UART transmit buffer
			POP		BC			; Restore BC
			SCF					; Set the carry flag
			RET 
; Read a character from UART0
; Returns:
; - A: Data read
; - F: C if character read
; - F: NC if no character read
;
UART0_serial_RX:	IN0		A,(UART0_REG_LSR)	; Get the line status register
			AND 		UART_LSR_RDY		; Check for characters in buffer
			RET		Z			; Just ret (with carry clear) if no characters
UART0_serial_RX2:
			IN0		A,(UART0_REG_RBR)	; Read the character from the UART receive buffer
			SCF 					; Set the carry flag
			RET



;
; data storage . . .
;	

; uninitialized storage/BSS but can't use that terminology because it's all in ROM space
;
; RAM
; 
			DEFINE	LORAM, SPACE = ROM
;			ORDER	__VECTORS, CODE, LORAM
			SEGMENT LORAM
		
;			SEGMENT	BSS
;			SEGMENT CODE

	end
