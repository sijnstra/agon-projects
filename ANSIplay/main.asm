; ANSI player for Agon
;
;
; Written Agon native by Shawn Sijnstra
;
;
; Copyright 2024 MIT license
;


		.ASSUME	ADL = 0				

		INCLUDE	"equs.inc"
		INCLUDE "mos_api.inc"	; In MOS/src

		SEGMENT CODE
	
		XDEF	_main
		XREF	_set_ahl24

			
; Error: Invalid parameter
;
_err_invalid_param:
		ld		HL, 19			; The return code: Invalid parameters
		ret


; ASCII
;
CtrlC:	equ	03h
CR:	equ	0Dh
LF:	equ	0Ah
ESC:	equ	1Bh
CtrlZ:	equ	1Ah
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

; Get a GPIO register
; Parameters:
; - REG: Register to test
; - VAL: Bit(s) to test
;	
GET_GPIO:	MACRO	REG, VAL
		in0		A,(REG)
		tst		A, VAL
		ENDMACRO

_main:
		xor	a
		ld	(no_exit_wait),a	;off by default in case re-entrant

		ld	a,c	;AGON - number of parameters
		dec	a
		jp	z,okusage
		cp	3	;too many parameters
		jp	nc,badusage

		ld.LIL		HL,(IX+3)		; HLU: pointer to first argument
		ld.LIL	a,(HL)				;24 bit
		cp	'-'
		jr	nz,openit
		inc.LIL	HL
		ld.LIL	a,(HL)				;24 bit
		cp	'x'
		jp	nz,badusage	
		ld	(no_exit_wait),a	;off by default in case re-entrant
		ld.LIL		HL,(IX+6)		; HLU: pointer to second argument
openit:
		ld	c,fa_read	;open read-only
		push.lil	ix
		MOSCALL	mos_fopen
		pop.lil		ix
		or	a
		jp	nz,open_ok
		ld	hl,4	;file not found/could not find file - error opening file [not necessarily correct error though]
		ret			;exit
;
;
; Close sequence and exit routines
;

close:

		ld		a,(no_exit_wait)
		or		a
		jr		nz,deinit
exit_key_wait:
		call	UART0_serial_RX		;ask the serial port - we are in terminal mode now.
		jr		nc,exit_key_wait		;no key pressed

deinit:
		ld		hl,deinit_string	;turn off terminal mode
$$:
		ld		a,(hl)
		or		a
		jr		z,deinit_done
		call	UART0_serial_TX
		inc		hl
		jr		$B
deinit_done:
;turn interrupts back on
		ld		a, 7
		out0	(UART0_REG_FCT), a ; Enable and clear fifo
;#define UART_IER_RECEIVEINT			((unsigned char)0x01)		//!< Receive Interrupt bit in IER.
;#define UART_IER_TRANSMITINT			((unsigned char)0x02)		//!< Transmit Interrupt bit in IER.
;#define UART_IER_LINESTATUSINT			((unsigned char)0x04)		//!< Line Status Interrupt bit in IER.
;#define UART_IER_MODEMINT				((unsigned char)0x08)		//!< Modem Interrupt bit in IER.
;#define UART_IER_TRANSCOMPLETEINT		((unsigned char)0x10)		//!< Transmission Complete Interrupt bit in IER.
		ld a, 1
		out0 (UART0_REG_IER), a ; Enable receive interrupt	
sauce:
		ld		hl,(filinfo)	;for now.... 16 bits to test.
		ld		a,(filinfo+2)	;24 bit version
		call	_set_ahl24
		ld.lil	de,-128
		add.lil	hl,de			;128 bytes back from the end
		ld		e,0				;lazy for now - assume < 16MB ANSI file.
		MOSCALL	mos_flseek
		ld		hl,SAUCE_header
		ld		b,5
sauce_check
		call	getbyte
		cp		(hl)
		jp		nz,sauce_done
		inc		hl
		djnz	sauce_check
		call	inline_print
		db		'SAUCE signature:',CR,LF,'Title : ',0
		call	getbyte			;Version number - skipping as usually 00
		call	getbyte
		ld		b,35
		call	sauce_lp
		call	inline_print
		db		CR,LF,'Author: ',0
		ld		b,20
		call	sauce_lp
		call	inline_print
		db		CR,LF,'Group : ',0
		ld		b,20
		call	sauce_lp
		call	inline_print
		db		CR,LF,'Date  : ',0
		ld		b,8
		call	sauce_lp
		call	inline_print
		db		CR,LF,CR,LF,0

;check for SAUCE comments
		ld		hl,(filinfo)	;for now.... 16 bits to test.
		ld		a,(filinfo+2)	;24 bit version
		call	_set_ahl24
		ld.lil	de,-24
		add.lil	hl,de			;128 bytes back from the end
		ld		e,0				;lazy for now - assume < 16MB ANSI file.
		MOSCALL	mos_flseek
		call	getbyte
		or		a
		jr		z,sauce_done	;no COMNT field
		ld		c,a				;will need this later - number of rows

comment_calc:
		ld		hl,0
		ld		l,c
		add		hl,hl
		add		hl,hl
		add		hl,hl
		add		hl,hl
		add		hl,hl
		add		hl,hl		;64 characters per row.
		ex		de,hl
		ld		hl,(filinfo)	;for now.... 16 bits to test.
		ld		a,(filinfo+2)	;24 bit version
		call	_set_ahl24
		or		a
		sbc.lil	hl,de
		ld.lil	de,-128-5
		add.lil	hl,de
		ld		e,0				;lazy for now - assume < 16MB ANSI file.
		ld		d,c
		ld		a,(in_handle)
		ld		c,a
		MOSCALL	mos_flseek
		ld		hl,COMNT_header
		ld		b,5
comnt_check
		call	getbyte
		cp		(hl)
		jp		nz,sauce_done
		inc		hl
		djnz	comnt_check
		call	inline_print
		db		CR,LF,'Comment:',CR,LF,0
comnt_lp:
		ld		b,64
		call	sauce_lp
		call	inline_print
		db		CR,LF,0
		dec		d
		jr		nz,comnt_lp	
		call	inline_print
		db		CR,LF,0
sauce_done:
;C: Filehandle, or 0 to close all open files
;returns number of still open files - how about we just always close all?

		ld		c,0
		MOSCALL	mos_fclose

exit:
		ld		hl,0	;for Agon - successful exit
		ret
;
;
open_ok:

		ld		(in_handle),a	;store the file handle number
		ex		de,hl
		ld		hl,filinfo
		ld		a,MB
		call	_set_ahl24
		MOSCALL	ffs_stat

;TESTING CODE FOR CREDITS
;	jp	sauce
;END TESTING

;Disable interrupts from UART0 before switching (MOS 3 change to do this prior to terminal mode)
		xor		a
		out0 	(UART0_REG_IER), a ; Disable all interrupts on UART0.

		ld		a, 6
		out0	(UART0_REG_FCT), a ; Turn off flow control interrupt

;Turn on terminal mode
		ld		HL, init_80x25		; Address of text
		ld		BC, 0			; Set to 0, so length ignored...
		ld		A, '$'			; Use character in A as delimiter
		RST.LIS	18h			; This calls a RST in the eZ80 address space

;Consume the terminal mode-change success packet from VDP
$$:
		call	UART0_serial_RX
		jr		nc,$b		;no info received
		cp		11h			;wait for end of success packet from mode change
		jr		nz,$b

playlp:
		call	getbyte
		cp		1Ah			;code for SAUCE sig block at the end. 0x1A should not otherwise occur
		jp		z,close
		call	UART0_serial_TX	;print direct to port in terminal mode
;noprint:
		MOSCALL mos_feof	;check for end of file
		or		a
		jr		z,playlp
donefile:
		jp		close


; Entry:
; A is a character to test
; Exit:
; Z flag is unprintable
unprintable:
		cp		' '
		jr		c,$f
		cp		127
		ret		c	;always nz
$$:		xor		a	;sets 0 flag
		ret
;
; Prints string directly after the call
;
inline_print:
		pop		hl
		call	print_string
		jp		(hl)
;
; more efficient print string for strings > 1 character
$$:
		rst		10h	;Agon uses this to print the character in A. Preserves HL.
		inc		hl
print_string:	ld	a,(hl)
		or		a
		jr		nz,$b
		ret
;
;
getbyte:
		call	ck_ctrlC
		ld		a,(in_handle)
		ld		c,a
		MOSCALL mos_fgetc	;carry flag on last byte not yet implemented.
		ret

; Check for ctrl-C. If so, clean stack and exit.
;
ck_ctrlC:
		ld		a,1		; modified below by self modifying code
		dec		a
		and		15
		ld		(ck_ctrlC+1),a	; update ld A instruction above
		ret		nz		; check every 16 calls only
		call	UART0_serial_RX		;ask the serial port - we are in terminal mode now.
		ret		nc		;no key pressed
		cp		3	;is it ctr-C
		ret		nz
		pop		hl		;clean up stack
		pop		hl
		jp		deinit	;close

;
; Requires fixed length of B for how many bytes to print from files
;
sauce_lp:
		call	getbyte
		call	unprintable	;in case beyond EOF or unprintable chars - easier this way
		call	nz,	10h			;we are back in MOS land now
		djnz	sauce_lp
		ret

;
; Check whether we're clear to send (UART0 only)
;

UART0_wait_CTS:
		GET_GPIO	PD_DR, 8		; Check Port D, bit 3 (CTS)
		jr		NZ, UART0_wait_CTS
		ret

; Write a character to UART0
; Parameters:
; - A: Data to write
; Returns:
; - F: C if written
; - F: NC if timed out
;
UART0_serial_TX:
		push		BC			; Stack BC
		push		AF 			; Stack AF
		ld		BC,TX_WAIT		; Set CB to the transmit timeout
UART0_serial_TX1:	in0		A,(UART0_REG_LSR)	; Get the line status register
		and 		UART_LSR_ETX		; Check for TX empty
		jr		NZ, UART0_serial_TX2	; If set, then TX is empty, goto transmit
		dec		BC
		ld		A, B
		or		C
		jr		NZ, UART0_serial_TX1
		pop		AF			; We've timed out at this point so
		pop		BC			; Restore the stack
		or		A			; Clear the carry flag and preserve A
		ret	
UART0_serial_TX2:
		pop		AF			; Good to send at this point, so
		out0		(UART0_REG_THR),A	; Write the character to the UART transmit buffer
		pop		BC			; Restore BC
		scf					; Set the carry flag
		ret 

; Read a character from UART0
; Returns:
; - A: Data read
; - F: C if character read
; - F: NC if no character read
;
UART0_serial_RX:
		in0		A,(UART0_REG_LSR)	; Get the line status register
		and 		UART_LSR_RDY		; Check for characters in buffer
		ret		Z			; Just ret (with carry clear) if no characters
UART0_serial_RX2:
		in0		A,(UART0_REG_RBR)	; Read the character from the UART receive buffer
		scf 					; Set the carry flag
		ret


okusage:
		call 	usage
		jp		exit

badusage:
		call 	usage
		jp		_err_invalid_param
;
; usage -- show syntax
; 
usage:	call	inline_print
		db		CR,LF,'ANSI player for Agon (c) Shawn Sijnstra 16-Sep-2025 v0.8 - MIT license',CR,LF,CR,LF
		db		'Usage:',CR,LF
		db		'   ANSIplay [-x] <file>',CR,LF
		db  	'By default ANSIplay waits for any key to exit once done.',CR,LF
		db		'-x will exit immediately after file is played.',CR,LF
		db		'Ctrl-C to abort during play. SAUCE metadata shown where available.',CR,LF
		db 		CR,LF,0
		ret
;  Minimum MOS version 1.03, VDP 2.2.1
init_80x25:		defb	22,0	;turn on screen mode 0
init_string:	defb	23,0,255,'$'	;enable terminal mode and terminate with $
deinit_string:	defb	7fh,7fh,ESC,'_#Q!$',0	;disable terminal mode and terminate with NUL
											;hopefully leading delete character ends any other escape sequence processing
											;caught mid-stream
SAUCE_header:	defb	'SAUCE'
COMNT_header:	defb	'COMNT'
;
; data storage . . .

; uninitialized storage/BSS
;
; RAM
; 
			DEFINE	LORAM, SPACE = ROM
;			ORDER	__VECTORS, CODE, LORAM
			SEGMENT LORAM
		
;			SEGMENT	BSS
;			SEGMENT CODE
no_exit_wait:
			ds	1	;"no exit wait" feature is off by default, set at entry
in_handle:	DS	1	;Only needs 1 byte handle
filinfo:	ds	FILINFO_SIZE	;buffer for file info
	end
