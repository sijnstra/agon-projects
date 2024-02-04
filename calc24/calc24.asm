;------------------------------------------------------------------------
;
;  Agon light simple caclulator by Shawn Sijnstra
;  compiles natively using ez80asm
;  Copyright (c) 2024 Shawn Sijnstra, MIT license
;
;  Inspired by Kevin Boone's scalc for CP/M
;------------------------------------------------------------------------

	ASSUME	ADL=1
	ORG		0B0000h
;
; Start in mixed mode. Assumes MBASE is set to correct segment
;
			JP		_start		; Jump to start
_exec_name:		db	"CALC24.BIN", 0		; The executable name, only used in argv
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

	INCLUDE	"strings24.asm"
	INCLUDE	"arith24.asm"


; General storage - should be neater and all collected


; Token type codes return by next_token()
TOK_EOF: EQU    0
TOK_NUM: EQU	1	


;------------------------------------------------------------------------
;  Data area
;------------------------------------------------------------------------

; curpos and lastpos track the expression parsing. After
;   a successful token parse, lastpos is advanced to curpos.
;   If the parse fails part way, curpos can be rolled back.
;   this allows parse_term and parse_expr to roll back if needed.
; 24 bits are used for ease of coding when storing/retrieving.
curpos:	dw24	0

lastpos: dw24	0

syntax_error_string:
		db	17,9,"Syntax error",17,15,13,10,0

divide_by_0_string:
		db	17,9,"Divide by zero",17,15,13,10,0

prompt_string:
		db	17,9,"calc24",17,15,"> ",0

banner_string:
		db	13,10,17,9,"calc24",17,15," v0.5 for Agon Light by Shawn Sijnstra (c)2024 - MIT licnese",13,10
		db		"24-bit Agon super simple calculator. Interactive mode. Use '?' for help",13,10,0

help_text:
		db	13,10,17,9,"calc24",17,15," is a simple and algebraically correct calculator.",13,10,13,10
		db		"Enter your calculation to be evaluated interactively. e.g. calc24> 7 * (2+3)",13,10
		db		"The calculations are done as 24-bit int (unsigned) ignoring overflow errors.",13,10
		db		17,9,"Operators:",17,15,13,10
		db		"(), *, /, +, - have their usual meanings and are in order of precedence.",13,10
		db		"%	modulus (remainder after division; same precedence as /).",13,10
		db		"|	bitwise OR",13,10
		db		"&	bitwise AND",13,10
		db		"^	bitwise exclusive OR",13,10
		db		"<< bitwise shift left (up to 65535 places)",13,10
		db		">> bitwise shift right (up to 65535 places)",13,10
		db		17,9,"Numbers:",17,15,13,10
		db		"Numbers are decimal unless prepended with '$' or '0x' for hex.",13,10
		db		"e.g. '256' is the same as '$100'.",13,10
		db		"@ represents the previous result (interactive mode only)",13,10
		db		"Use a blank line to exit.",13,10,13,10,0

; error_done_flag is set to zero if parse_expr() has already produced an error
;   message, so the caller should not.
error_done_flag: db 0

cur_total:	dw24 	0	;this is the accumulator for current total

lastval: 	dw24 	0	;this is for '@' i.e. previous result

expr_buffer:		ds		127	;expression buffer
			db		0	;terminator in case of exactly 127 character input

;------------------------------------------------------------------------
;  nextchar 
;  Read the next character in the input expression into A and increments
;   (curpos).
;  Preserves all other registers.
;------------------------------------------------------------------------
nextchar:
	push	BC
	push	HL
	ld	BC,expr_buffer
	ld	HL, (curpos)
	inc	hl
	ld	(curpos),hl
	dec	hl
	add	HL, BC
	ld	A, (HL)
	pop	HL
	pop	BC
	ret

;------------------------------------------------------------------------
;  moveback 
;  Move the current parse position (curpos) back one.
;  Preserves all registers.
;------------------------------------------------------------------------
moveback:
	push	HL
	ld	HL, (curpos)
	DEC	HL	
	ld	(curpos), HL
	pop	HL
	ret

;------------------------------------------------------------------------
;  next_token
;  Gets the next token from the expression. The return value in A 
;  is TOK_EOF if we are at the end of input, TOK_NUM if the token is a 
;  number, and the actual token if anything else. If the token is a 
;  number, it's value is returned in HL.
;------------------------------------------------------------------------
next_token:
	push	DE
	; Reset the ASCII-to-binary conversion accumulator
	ld	HL, 0	
	ld 	(cur_total), HL	
	call	nextchar
next_token_next:
; A has next char
	or	A
	jr	NZ, next_token_not_null
	call	moveback	;stay on the terminator for the next fetch - don't overrun
	ld	A, TOK_EOF
	JP	next_token_done		; End of input - we are done

next_token_not_null:
	call	is_digit
	jr	nc, next_token_not_digit
	cp	'0'	;was it a zero as the first digit?
	jr	nz,next_token_dec_lp	;no, so proceed
	call	nextchar
	cp	'x'	;lower case x means the lead-in was '0x' so it's hex
	jr z,next_token_longhex
	call moveback	;move the pointer back and
    ld	a,'0'	;we know we read ascii '0' to get here so we don't need to re-read
	; If we get here, the character is a digit
	; Loop around, converting decimal digits to binary
next_token_dec_lp:
	ld	HL, (cur_total)
;Fast purpose-built times 10 routine. Burns BC
	add 	hl,hl	;HLU*2
	push	hl		;save it
	add 	hl,hl	;HLU*4
	add		hl,hl	;HLU*8
	pop		bc		;HLU*2
	add		hl,bc	;HLU*10

	sub	'0'
	ld	bc, 0		;make sure BCU = 0
	ld	C, A
	add	HL, BC
	ld	(cur_total), HL
 	call	nextchar
	call	is_digit
	jr	c, next_token_dec_lp
	call	moveback
	ld	HL, (cur_total)
	ld	A, TOK_NUM
	jr	next_token_done;

next_token_not_digit:
	; If we get here, the character is not a number or EOF 
	cp	'$'		;check for hex lead-in
	jr	NZ, next_token_not_hex

; either '$' or '0x' lead-in will arrive here to process as hex
;
next_token_longhex: 
	call	nextchar
	call	char2hex	;try converting from ASCII to hex nibble
	inc		a
	jr		nz, next_token_hex_lp
	ld		a, 'x'			;return invalid character for error
	jr      next_token_done 

	; Loop to read hex digits into (cur_total)
next_token_hex_lp:
	ld		HL, (cur_total)
	add		HL,HL	;shift 1 nibble
	add		HL,HL
	add		HL,HL
	add		HL,HL
	dec		a		;A is already char2hex value + 1
	ld		BC,0		;So we know that BCU is 0
	ld		C, A
	add		HL, BC
	ld		(cur_total), HL		;store the new result
 	call	nextchar
	call	char2hex
	inc		a
	jr		nz, next_token_hex_lp	;it's another hex value returned so keep processing
	call	moveback		;move back so we can process again
	ld	HL, (cur_total)		;retrieve the generated number
	ld	A, TOK_NUM			;confirm we have a number at this point
	jr	next_token_done
	
	; Character is not EOF or any kind of number that we understand
next_token_not_hex:
	cp	' '
	jr	NZ, next_token_not_spc

	call	nextchar	; Swallow the space and loop
	JP	next_token_next

next_token_not_spc:
	cp	'@'
	jr	NZ, next_token_not_at

	ld	HL, (lastval)
	ld	A, TOK_NUM
	jr	next_token_done

next_token_not_at:
	; The token should now be in A		
next_token_done:
	pop	DE
	ret

;------------------------------------------------------------------------
;  save_pos 
;  Save the value of (curpos) in case a parse fails, and we need to 
;    wind it back.
;------------------------------------------------------------------------
save_pos:
	push	HL
	ld	HL, (curpos)
	ld	(lastpos), HL	
	pop	HL
	ret

;------------------------------------------------------------------------
;  restpos 
;  Wind back (curpos) to (lastpos); used when a parse operation consumes
;    a token that it cannot parse
;------------------------------------------------------------------------
restpos:
	push	HL
	ld	HL, (lastpos)
	ld	(curpos), HL	
	pop	HL
	ret

;------------------------------------------------------------------------
; syntax_error
; Output:	displays the syntax error message string
; 			displays the contents of the expr_buffer
; 			points to the current position being evaluated
; All registers preserved.
;------------------------------------------------------------------------
syntax_error:
	push	AF
	push	HL
	ld		HL, syntax_error_string	;has built-in newline
	call	puts
	ld		HL, expr_buffer
	call	puts
	call	newline
	ld		HL, (curpos)

syntax_error_spc:
	ld		a,l
	or		h
	jr		z, syntax_error_here
	dec		HL
	ld		a,' '
	rst.LIL	10h	;print a space
	jr		syntax_error_spc

syntax_error_here:
	ld		a, '^'		;show location
	rst.LIL	10h
	call	newline
	pop		HL
	pop		AF
	ret

;------------------------------------------------------------------------
; divide_by_0 error
; Print the divide-by-zero error message string
; flag that error was returned
; preserves all registers
;------------------------------------------------------------------------
divide_by_0:
	push	HL
	push	AF	
	ld	HL, divide_by_0_string
	ld	A, 1
	ld	(error_done_flag), A
	call	puts
	pop	AF
	pop	HL
	ret

;------------------------------------------------------------------------
;  parse_num 
;  Returns:
;  A: 1 if number parsed, 0 otherwise
;  HLU: number result
;------------------------------------------------------------------------
parse_num:
	call	next_token
	cp	TOK_NUM
	jr	Z, parse_num_ret1
	xor	a
	ret
parse_num_ret1:
	ld	A, 1
	ret

;------------------------------------------------------------------------
;  parse_expr
;  Returns:
;  A: 1 if expression parsed, 0 otherwise
;  HLU: expression result
;------------------------------------------------------------------------
parse_expr:
	push	DE
	call	save_pos
	call	parse_term
	or	A
	JP	Z, parse_expr_none
; Move current result if any from HL to DE
parse_expr_lp:
	push	hl
	pop		de	;24 bit transfer
	call	save_pos
	call	next_token

	push	hl
	ld	hl,parse_exp_sym
	ld	c,0
	ld	b,parse_exp_table - parse_exp_sym
parse_exp_loop:
	cp	(hl)		;could use CPIR but then need to calculate c manually
	jr	z,parse_exp_jump
	inc	c
	inc	hl
	djnz	parse_exp_loop
	pop		hl
	jp	parse_nomatch
parse_exp_jump:
	ld	a,c
	add	a,a	;*2
	add	a,c	;*3
	ld	bc,0
	ld	c,a
	ld	hl,parse_exp_table
	add	hl,bc
	ld	hl,(hl)
	ex	(sp),hl	;restore HL and push the address on the stack
	ret			;jump to the location calculated above

do_plus:
	call	parse_term
	or	A
	jp	Z, parse_expr_syntax_err
	add	HL, DE
	call	save_pos
	jr	parse_expr_lp

do_minus:
	call	parse_term
	or	A
	jp	Z, parse_expr_syntax_err
	EX	DE,HL
	SBC	HL, DE
	call	save_pos
	jr	parse_expr_lp

do_tok_eof:
	ld	A, 1
	jp	parse_expr_done

do_or:
	call	parse_term
	or	A
	jp	Z, parse_expr_syntax_err
	call	or_hlu_deu	;perform OR
	call	save_pos
	jp	parse_expr_lp

do_and:
	call	parse_term
	or	A
	jp	z, parse_expr_syntax_err
	call	and_hlu_deu	;perform AND
	call	save_pos
	jp	parse_expr_lp

do_xor:
	call	parse_term
	or	A
	jp	z, parse_expr_syntax_err
	call	xor_hlu_deu	;perform XOR
	call	save_pos
	jp		parse_expr_lp

do_shl:
	call	nextchar
	cp		'<'			;check for second '<'
	jp		nz,parse_expr_syntax_err
	call	parse_term
	or		a
	jp		z, parse_expr_syntax_err
	ex		de,hl	;de now has RHS
	call	shl_hlu	;hlu << deu
	call	save_pos
	jp		parse_expr_lp	

do_shr:
	call	nextchar
	cp		'>'			;check for second '>'
	jp		nz,parse_expr_syntax_err
	call	parse_term
	or		a
	jp		z, parse_expr_syntax_err
	ex		de,hl	;de now has RHS
	call	shr_hlu	;hlu >> deu
	call	save_pos
	jp		parse_expr_lp	

parse_nomatch:
	call	restpos
	ld	A, 1
	jr	parse_expr_done

parse_expr_none:	;no expression to parse
	call	restpos
	ld	A, 0
parse_expr_syntax_err:	;syntax error encountered
parse_expr_done:	;expression parsing complete
	EX	de,hl
	pop	DE
	ret

parse_exp_sym:
	db		"+-",TOK_EOF,"|&^<>"
parse_exp_table:
	dw24	do_plus,do_minus,do_tok_eof,do_or,do_and,do_xor,do_shl,do_shr

;------------------------------------------------------------------------
;  parse_term
;  Returns:
;  A: 1 if term parsed, 0 otherwise
;  HLU: term result
;------------------------------------------------------------------------
parse_term:
	push	DE
	call	save_pos
	call	parse_factor
	or		a
	jr		Z, parse_term_none
; There is a term
; Move any current result from HL to DE
parse_term_lp:
	push	hl
	pop		de
	call	save_pos
	call	next_token
	cp	'*'
	jr	NZ, parse_term_not_mult

	call	parse_factor
	or	A
	jr	Z, parse_term_synerr
	call	umul24
	call	save_pos
	jr	parse_term_lp

parse_term_not_mult:
	cp	'/'
	jr	NZ, parse_term_not_div

	call	parse_factor
	or	A
	jr	Z, parse_term_synerr
	EX	DE,HL
	call	udiv24
	jr	nc, parse_term_div0	;carry clear on divide by 0
	;Result is in HLU, remainder in DEU WRONG
	ex	de,hl	;remainder now in HLU WRONG
	call	save_pos
	jr	parse_term_lp

parse_term_not_div:
	cp	'%'
	jr	NZ, parse_term_not_mod

	call	parse_factor
	or	A
	jr	Z, parse_term_synerr
	EX	DE,HL
	call	udiv24
	jr	nc, parse_term_div0	;carry clear on divide by 0	
	;Result is in HLU, remainder in DEU WRONG

	call	save_pos
	jr	parse_term_lp

parse_term_not_mod:
	cp	TOK_EOF
	jr	NZ, parse_term_not_eof
	ld	A, 1
	jr	parse_term_done

parse_term_not_eof:
	call	restpos
	ld	A, 1
	jr	parse_term_done

parse_term_none:
	call	restpos
	ld	A, 0
parse_term_synerr:
parse_term_done:
	EX	DE,HL
	pop	DE
	ret

parse_term_div0:
	call	divide_by_0
	jr	parse_term_done

;------------------------------------------------------------------------
;  parse_factor 
;  Returns:
;  A: 1 if factor parsed, 0 otherwise
;  HLU: factor result
;------------------------------------------------------------------------
parse_factor:
	push	DE
	call	next_token
	cp	TOK_NUM
	jr	NZ, parse_nonum
	ld	A, 1
	jr	parse_factor_done
parse_nonum:
	; If we get here, the last token was not a number
	cp	'('
	jr	NZ, parse_n_paren
	call	parse_expr
	or	A
	jr	Z, parse_factor_err
; We got an expression, and the result is in HL
; Check that the next is a ")"
	push	hl
	pop		de
	call	next_token
	cp		')'
	jr		NZ, parse_factor_err
	push	de
	pop		hl
	ld		A, 1
	jr		parse_factor_done

parse_n_paren:
	cp		'-'
	jr		NZ, parse_not_neg
	call	parse_factor
	or		A
	jr		Z, parse_factor_err
	call	neg24
	ld		A, 1
	jr		parse_factor_done	

parse_not_neg:
parse_factor_err:
	xor		a
parse_factor_done:
	pop		DE
	ret

;------------------------------------------------------------------------
; print_result
; Print the value in HLU in decimal and hex
;------------------------------------------------------------------------
print_result:
	push	DE
	push	HL
	call	print_HLU_u24
	ld	a,' '
	rst.LIL	10h
	ld	a, '0'
	rst.LIL	10h
	ld	a,'x'
	rst.LIL	10h
	pop	HL
	call	print_HLU_hex
	call	newline
	pop	DE
	ret

;------------------------------------------------------------------------
; reset_eval 
; Reset (curpos), (lastpos), error_done_flag for next evaluation.
;------------------------------------------------------------------------
reset_eval:
	XOR	A
	ld	(curpos), A
	ld	(lastpos), A
	ld	(error_done_flag), A
	ret

;------------------------------------------------------------------------
; eval
; evaluate the expression at expr_buffer
; and print the result
;   
;------------------------------------------------------------------------
eval:
	call	reset_eval
	ld		HL,expr_buffer
	ld		A, (HL)		; first char
	or		a
	ret		z	;done - no input was provided 

	call	parse_expr
	or		a
	jr		Z, eval_syntax_error

; After evaluation is finished, if the current character is not the null
; terminator, there was an error. This is why we back up one character
; after parsing the string.
	call	nextchar
	or		a
	jr		nz,eval_syntax_error
	ld		(lastval), HL	;store for '@' function
	jp		print_result	; Print result	

	ret			;done

eval_syntax_error:
	ld		a, (error_done_flag)	; Don't print error if we already did
	or		a
	ret		nz
	jp		syntax_error		;print syntax error and return.

;------------------------------------------------------------------------
;  loop 
;  Prompt for an expression, and evaluate it, in a loop.
;    Stop when the user enters and empty line
;------------------------------------------------------------------------
loop:
	ld	HL, prompt_string	; print the prompt
	call	puts
; Read the line
;	0x09: mos_editline
;Invoke the line editor

;Parameters:
;HL(U): Address of the buffer
;BC(U): Buffer length
;E: 0 to not clear buffer, 1 to clear
;Returns:
;A: Key that was used to exit the input loop (CR=13, ESC=27)

	ld 	hl, expr_buffer
	ld	BC,127
	ld	E,1			; Clear the line input buffer.
	ld	A,9			; mos_editline
	rst.lil	08h		; call API with readline

	; Check whether anything was entered. If it was, evaluate and
	;   go around again.
	ld	A, (expr_buffer)
	or	A
	ret	Z			;No input provided so return from input loop
	cp	'?'
	jr	z,show_help
	call	newline
	call 	eval
	jr	loop
show_help:
	ld	HL,help_text
	call	puts
	jr	loop



;------------------------------------------------------------------------
;  Main loop routine
; uses a recursive descent parser, defined by the following grammar:
;
;  expression = term {'+'|'-'|'|'|'&'|'^'|'<<'|'>>' term}...
;  term = factor {'*'|'/'|'%' factor}...  
;  factor = number | '(' expression ')' | '-' factor
;
; As this is recursive, there may be stack constraints for very large
; expressions. Currently limited to 127 characters below.
;
; For a recursive descent parser primer, see:
; https://en.wikipedia.org/wiki/Recursive_descent_parser
;------------------------------------------------------------------------
main:

	ld	A,(HL)		;test if there was a command-line expression
	or	A
	jr	Z, noargs	;nothing was on the command-line, go interactive
	ld	DE, expr_buffer
	ld	BC,127
	ldIR			;move the line input into the place to be evaluated

	call	eval
	jp		newline	;print newline and return to MOS wrapper

noargs:
	ld	HL, banner_string
	call	puts
	call	loop
	jp		newline	;print newline and return to MOS wrapper
