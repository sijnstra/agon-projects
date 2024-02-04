;------------------------------------------------------------------------
;  strings24.asm 
;
; 24-bit native ez80 strings routines for numerical processing
;  Copyright (c) Shawn Sijnstra 2024
;  MIT license
;------------------------------------------------------------------------

;------------------------------------------------------------------------
;Full print and buffer routine so you can adjust behaviour
; Double-Dabble AKA shift-and-add-3 algorithm
; breakdown at https://en.wikipedia.org/wiki/Double_dabble
;Print value in HLU in decimal with leading 0s removed
; Uses HLU, DEU, BCU
;------------------------------------------------------------------------

print_HLU_u24:
	ld	(hex_temp),hl
	ld	b,8	;8 digits max here with 24 bit unsigned
	ld	de,outbuf
	push	de
	ld	hl,7
	add	hl,de
	push	hl
	pop	de	;copy HLU to DEU
	xor	a
_pde_u_zerobuf:
	ld	(hl),a	;zero out the output
	dec	hl
	djnz	_pde_u_zerobuf

	ld c,3 * 8	;4 * 8	; number of loops through NUM_SRC_BYTES * 8
_bcd_Convert:

	ld hl,hex_temp
;
	sla (hl)
	inc hl
	rl (hl)
	inc hl
	rl (hl)		;24 bits rolled right


        ld	b,8	;8 digits max for 24 bit decimal output
	push	de
	pop	hl

_bcd_Add3:
	ld	a,(hl)
	adc	a
        daa		;this is add 3 after shifting left; i.e. add 6.
	cp	10h	;did we roll over nibble?
	ccf
	res	4,a

        ld (hl),a
	dec	hl
        djnz	_bcd_Add3	;loop for decimal digits
        dec c
        jr nz, _bcd_Convert	;loop around


	pop	hl
	push	hl
        ld	b,8-1		;one less than total in case output is '0'
_pde_u_make_ascii:
	ld	a,(hl)
	or	a
	jr	nz,_pde_u_make_ascii2
	ld	(hl),' '
	inc	hl
	djnz	_pde_u_make_ascii
_pde_u_make_ascii2:
	inc	b
_pde_u_make_ascii3:
	ld	a,(hl)
	or	30h
	ld	(hl),a
	inc	hl
	djnz	_pde_u_make_ascii3

	pop	hl
	ld	b,8
_pde_u_final_out:		
	ld	a,(hl)
	inc	hl
	cp	' '
	jr	z,_pde_u_final_out_strip
	rst.lil	10h
_pde_u_final_out_strip:
	djnz	_pde_u_final_out
	ret

;------------------------------------------------------------------------
; is_digit 
; C flag set if A is a digit
; preserves all registers
;------------------------------------------------------------------------
is_digit:
	cp	'0'
	ccf
	ret	nc	;less that '0'
	cp	'9' + 1
	ret


;------------------------------------------------------------------------
; char2hex 
; Input: ASCII nibble in A
; Returns: if valid nibble value in A; else 0FFh in A
;------------------------------------------------------------------------
char2hex:
	CP	'0'
	JR	C, char_not_hex
	CP	'9' + 1
	JR	NC, char_not_09
	sub	'0'
	ret

char_not_09:
	; char is not 0 to 9. Try upper case
	CP	'A'
	JR	C, char_not_hex
	CP	'F' + 1
	JR	NC, char_not_AF
	sub	'A'-10
	ret

char_not_AF:
	; char is not upper case A-F. Try lower
	CP	'a'
	JR	C, char_not_hex
	CP	'f' + 1
	JR	NC, char_not_hex	
	sub	'a' - 10
	RET	

char_not_hex:
 	ld	a,0FFh	;return -1 for not a valid hex digit
	RET

;------------------------------------------------------------------------
;  newline
;  Output CR+LF; all registers preserved
;------------------------------------------------------------------------
newline:
       push   AF
       LD     A, 13
       RST.LIL    10h
       LD     A, 10
       RST.LIL    10h
       POP    AF
       RET

;------------------------------------------------------------------------
;  put_nibble
;  Output a single hex nibble in A
;  All registers preserved 
;------------------------------------------------------------------------
put_nibble:
	push   AF
	add    a,090h ;Neat trick to convert hex nibble in A to ASCII
	daa
	adc    a,040h
	daa
	RST.LIL    10h	;output character in A
	pop    AF
	ret

;------------------------------------------------------------------------
;  print_A
;  Output the 8-bit hex number A
;  All registers preserved
;------------------------------------------------------------------------
print_A:
	push 	AF
	push 	AF	;save for second nibble
	rrca
	rrca
	rrca
	rrca
	and	0Fh	;first nibble
	call	put_nibble
	pop 	AF
	and	0Fh	;second nibble
	call	put_nibble
	pop 	AF
	ret

;------------------------------------------------------------------------
;  print_HLU_hex
;  Output the 24-bit hex number HLU; other registers preserved 
;------------------------------------------------------------------------
print_HLU_hex:
       push   AF
       ld     (hex_temp),hl
       ld     a,(hex_temp+2)
       call   print_A
       ld     a,(hex_temp+1)
       call   print_A
       ld     a,(hex_temp)
       call   print_A
       POP    AF
       RET

;------------------------------------------------------------------------
;  puts 
;  Output a zero-terminated string whose address is in HL; all 
;  registers preserved.
;------------------------------------------------------------------------
puts:
       push   AF
       push   BC
       ld     BC, 0                ; Set to 0, so length ignored...
       ld     A, 0                 ; Use character in A as delimiter
       RST.LIL    18h                  ; This calls a RST in the eZ80 address space
       pop    BC 
       pop    AF
       ret

;------------------------------------------------------------------------
; Data area
; Storage for 24 bit conversion
;------------------------------------------------------------------------
hex_temp:
       dw24     0      ;3 bytes for HL used for both hex and decimal temp

outbuf:
	db	"16777215 "	;largest number with an extra space
