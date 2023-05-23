;
; Title:	Memory Dump - Macros
; Author:	Dean Belfield
; Created:	15/11/2022
; Last Updated:	15/11/2022
;
; Modinfo:
	
ADD8U_HL:		MACRO 	reg
			ADD	A, L 
			LD	L, A 
			ADC	A, H
			SUB	L
			LD	H, A 
			ENDMACRO 
		
ADD8U_DE:		MACRO 	reg
			ADD	A, E 
			LD	E, A 
			ADC	A, D
			SUB	E
			LD	D, A 
			ENDMACRO 		