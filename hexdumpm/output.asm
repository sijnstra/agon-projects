;
; Title:	Memory Dump - Output functions
; Author:	Dean Belfield
; Created:	15/11/2022
; Last Updated:	15/11/2022
;
; Modinfo:

			INCLUDE	"equs.inc"

			.ASSUME	ADL = 0

			SEGMENT CODE
			
			XDEF	Print_Hex24
			XDEF	Print_Hex16
			XDEF	Print_Hex8
				
			
; Print a 24-bit HEX number
; HLU: Number to print
;
Print_Hex24:		PUSH.LIL	HL
			LD.LIL		HL, 2
			ADD.LIL		HL, SP
			LD.LIL		A, (HL)
			POP.LIL		HL

			CALL		Print_Hex8			
			
; Print a 16-bit HEX number
; HL: Number to print
;
Print_Hex16:		LD	A,H
			CALL	Print_Hex8
			LD	A,L

; Print an 8-bit HEX number
; A: Number to print
;
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
			RST	10h
			RET