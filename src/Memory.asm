	nolist

;	Memory

;	Composant de la rom Arkos.

;	ùMM,[adr]




MM_STANDALONE equ 0

	if MM_STANDALONE
	org #1000
	endif


MM_Debut
	or a			;Pas de param, ok.
	jr z,MM_AvMainLoop
	cp 1
	jr nz,MM_BadParam
	ld l,(ix+0)
	ld h,(ix+1)
	ld (MM_Pointeur),hl

MM_AVMainLoop
	;Copie le code qui lit la mem en ram
	ld hl,MM_ReadMemCode
	ld de,MM_AdReadMemCode
	ld bc,MM_ReadMemCodeFin-MM_ReadMemCode
	ldir

	call #b912
	ld (MM_RMNoRom-MM_ReadMemCode+MM_AdReadMemCode+1),a


MM_MainLoop
	ld hl,(MM_Pointeur)
	call AFFNB16

	push hl

	ld d,8
MM_HexLoop 
	call MM_AdReadMemCode
	;ld a,(hl)
	inc hl
	call AFFNB
	ld a,#9
	call #bb5a
	dec d
	jr nz,MM_HexLoop

	pop hl
	ld d,8
MM_AscLoop
	call MM_AdReadMemCode
	;ld a,(hl)
	inc hl
	cp 32
	jr nc,MM_AscOk
	ld a,32
	call #bb5a
	jr MM_AscNext
	
MM_AscOk call #bb5a
MM_AscNext
	dec d
	jr nz,MM_AscLoop

	ld (MM_Pointeur),hl

	ld a,#d
	call #bb5a
	ld a,#a
	call #bb5a

	call #bb09
	jr nc,MM_MainLoop
	cp #fc
	ret z

	call #bb18
	cp #fc
	jr nz,MM_MainLoop


	ret


MM_BadParam ld hl,MM_TXT
	call PHRBB5A
	ret

MM_TXT	defb 124,"MM,[Address]",#d,#a
	defb 0

;Code copie en RAM. Ferme ROM, lit mem, Ouvre ROM
MM_ReadMemCode
	call #b903
	ld a,(hl)
	push af
MM_RMNoRom ld c,0
	call #b90f
	pop af	
	ret
MM_ReadMemCodeFin

MM_Pointeur equ #bdcb

MM_AdReadMemCode equ #bdf7		;Copie ici le ocde qui va lire la mem (en fermant la rom)






	if MM_STANDALONE


;Affiche un nb 8bits en hexa
AFFNB
	call HXTOASC
	ld a,b
	call #bb5a
	ld a,c
	call #bb5a
	ret

;Affiche un nb 16 bits, avec un & et un espace
AFFNB16
	ld a,'&'
	call #bb5a
	ld a,h
	call AFFNB
	ld a,l
	call AFFNB
	ld a,#9
	call #bb5a
	ret

;Transforme un nb hexa non signe 8 bits en ascii
;a=nb
;sortie=b=diz c=unite
HXTOASC
	push de
	push hl

	ld b,a
	and %00001111
	ld l,a
	ld h,0
	ld de,HXTAB
	add hl,de
	ld c,(hl)
;
	ld a,b
	rra
	rra
	rra
	rra
	and %00001111
	ld l,a
	ld h,0
	add hl,de
	ld b,(hl)

	pop hl
	pop de
	ret

HXTAB	defb "0123456789ABCDEF"


PHRBB5A	ld a,(hl)
	inc hl
	or a
	ret z
	call #bb5a
	jr PHRBB5A


	endif





	list
;**** Fin Memory
	nolist
