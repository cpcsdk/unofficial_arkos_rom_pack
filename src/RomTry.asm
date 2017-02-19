	org #c000
	nolist





	defb 1		;type ROM
	defb 0		;mark number
	defb 0		;version number
	defb 0		;mod number
	defw TABINSTR
	jp TRY
TABINSTR defb 0

TRY	push af
	push hl
	ld hl,#bc9b
	ld (hl),#c9
	pop hl
	pop af
	scf
	ret