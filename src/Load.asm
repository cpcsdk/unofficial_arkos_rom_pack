	nolist

;	Load

;	Composant de la rom Arkos.

;	ùLD,"fichier",[adr],[cx],[Adbuffer]  (c0,2,4,5,6,7) C1 et C3 interdits.
;	Charge un fichier n'importe ou en mem 

;	Si ouvre une bank, la laisse ouverte en sortie. Sauf pour C2.
;	Si buffer <0 alors buffer too low.




LD_ADCopyPrg equ #a000			;Ou on copie le programme.
LD_Diff equ LD_DebutCode-LD_ADCopyPrg





LD_Debut
;	Copie le prg en ram centrale
;	ld hl,LD_DebutCode
;	ld de,LD_ADCopyPrg
;	ld bc,LD_Fin-LD_DebutCode
;	ldir
;	jp LD_ADCopyPrg



LD_DebutCode
;Regarde le nb de params.
	or a
	jr z,LD_NbParamsNOk
	cp 5
	jr c,LD_NbParamsOk
LD_NbParamsNOk			;Bad Nb Params
	ld hl,LD_TXT
	call LD_PHRBB5A ;-LD_Diff
	ret




LD_NbParamsOk
	ld (LD_NBPARAMS),a

	xor a				;Params par defaut.
	ld (LD_IsLoadAdrGiven),a
	ld (LD_IsLoadBankGiven),a
	ld (LD_IsAdBufferGiven),a
	ld a,#c0
	ld (LD_LoadBank),a
	ld hl,#4000
	ld (LD_LoadAdr),hl

	ld a,(LD_NBPARAMS)
	cp 1
	jr z,LD_Param1
	cp 2
	jr z,LD_Param2
	cp 3
	jr z,LD_Param3

;Get Param 4 (=adbuffer)
	ld l,(ix+0)
	ld h,(ix+1)
	inc ix
	inc ix
	ld (LD_BufferAdr),hl
	ld a,1
	ld (LD_IsAdBufferGiven),a


;Get Param 3 (=Bank)
LD_Param3
	ld a,(ix+0)
	cp #c1
	jr z,LD_NbParamsNOk
	cp #c3
	jr z,LD_NbParamsNOk
	inc ix
	inc ix
	ld (LD_LoadBank),a
	ld a,1
	ld (LD_IsLoadBankGiven),a


;Get Param 2 (=adr)
LD_Param2
	ld l,(ix+0)
	ld h,(ix+1)
	inc ix
	inc ix
	ld (LD_LoadAdr),hl
	ld a,1
	ld (LD_IsLoadAdrGiven),a

;Get Param 1 (filename)
LD_Param1
	ld e,(ix+0)
	ld d,(ix+1)
	defb #dd : ld l,e
	defb #dd : ld h,d
	ld a,(ix+0)
	or a
	jr z,LD_NbParamsNOk
	ld b,a
	ld l,(ix+1)
	ld h,(ix+2)
	
	




;Ouvre fichier
	ld de,(LD_BufferAdr)		;Si buffer donne, on ne le calcule pas
	ld a,(LD_IsAdBufferGiven)
	or a
	jr nz,LD_BufGiven
	
	push hl
	ld hl,(#ae5e)			;6128 ou 664
	ld a,(#bd38)
	cp #88
	jr nz,LD_CAT6128
	ld hl,(#ae7b)			;464
LD_CAT6128 ld de,#800			;Si on descend sous 0, buffer too low.
	or a
	sbc hl,de
	jr c,LD_BufferLow
	jr z,LD_BufferLow
	ex de,hl
	pop hl

LD_BufGiven

	call #bc77
	jr nc,LD_ErrorDisc
;	xor a
	ld (LD_FileType),a
	ld l,c
	ld h,b

	ld a,(LD_IsLoadAdrGiven)	;Si address pas donnee, on utilise celle par defaut
	or a
	jr z,LD_AdrGiven
	ld de,(LD_LoadAdr)
LD_AdrGiven

	ld a,(LD_LoadBank)		;On ouvre la bank maintenant, sauf si c'est #c2
	cp #c2				;Si bank #c2, byte par byte
;	jr LD_ByteByByte
	jr z,LD_ByteByByte
	ld a,(LD_IsLoadBankGiven)	;Ouvre bank uniquement si elle est donnee.
	or a
	jr z,LD_BkNotGiven
	ld a,(LD_LoadBank)
	ld b,#7f
	out (c),a	
LD_BkNotGiven


	ld a,(LD_FileType)
	cp #16				;fichier ascii ?
	jr z,LD_AsciiFile






;Load normal.
	ex de,hl
	call #bc83
;	call #bc7a

LD_ErrorDisc
LD_Quit
	ld a,(LD_LoadBank)
	cp #c2
	jr z,LD_Qui2
	ld a,(LD_IsLoadBankGiven)
	or a
	jr nz,LD_Qui3
LD_Qui2	ld bc,#7fc0
	out (c),c
LD_Qui3	call #bc7a
	ret



LD_BufferLow
	pop hl
	ld hl,LD_TXTBufferLow
	call PHRBB5A
	jr LD_Qui2




;Fichier Ascii. Adr doit etre donnee.
LD_AsciiFile
	ld a,(LD_IsLoadAdrGiven)
	or a
	jr nz,LD_ByteByByte

	ld hl,LD_TXTAdrNeeded
	call LD_PHRBB5A		;-LD_Diff
	jr LD_Quit




;Lecture octet par octet (fichier ascii et/ou C2)
;DE=loadwhere
;HL=taille si necessaire (=non ascii)
LD_ByteByByte
	inc hl

LD_ByteByByteLoop
	ld a,(LD_FileType)
	cp #16
	jr nz,LD_BBBNoAscii
;Lecture octet par octet, fichier ASCII.
	call #bc80
	jr c,LD_BBBCodeByte
	cp #1a				;'Erreur' trouvee ds fichier ascii. Si #1a, octet normal
	jr z,LD_BBBCodeByte
	jr LD_Quit

;Lecture octet par octet, fichier binaire.
LD_BBBNoAscii
	call #bc80
	ld c,a
	dec hl
	ld a,l
	or h
	jr z,LD_Quit
	ld a,c


;Code l'octet qu'on vient de lire. Si #c2, cas particulier.
LD_BBBCodeByte
	ld c,a
	ld a,(LD_LoadBank)
	cp #c2
	jr z,LD_BBBCByteC2

	ld a,c
	ld (de),a
	inc de	
	jr LD_ByteByByteLoop


;Place A en bank #c2
;C=octet DE=dest HL=long
LD_BBBCByteC2
	push hl
	push de
	ld h,c
	ld a,d			;Transforme une adresse 
	or a
	rla
	rla
	rla
	and %00000011
	or %11000100
	ld b,#7f
	out (c),a

	res 7,d			;ramene l'adr en #40xx
	set 6,d

	ld a,h
	ld (de),a

	ld a,#c0
	out (c),a

	pop de
	pop hl

	inc de	
	jr LD_ByteByByteLoop








LD_PHRBB5A
;	ld de,LD_Diff
;	or a
;	sbc hl,de
LD_PHRBB5A2
	ld a,(hl)
	or a
	ret z
	inc hl
	call #bb5a
	jr LD_PHRBB5A2



LD_TXTAdrNeeded defb "Ascii File. Please enter Start Address.",#d,#a,0
LD_TXTBufferLow defb "Buffer too low.",#d,#a,0
LD_TXT	defb 124,"LD,",34,"Filename",34,",[Adr],[Bank],[AdBuffer]",#d,#a
	defb "Bank = &c0,&c2,&c4-&c7",#d,#a
	defb 0



LD_Fin






;LD_FILENAME defb "DINOLOAD.SCR"
;	defs 5,0
;LD_IsLoadAdrGiven defb 1		;0=pas donnee, utilise celle du fichier
;LD_LoadAdr defw #c000			;Adresse de chargement donnee.
;ID_IsLoadBankGiven defb 1
;LD_LoadBank defb #c2
;LD_FileType defb 0
;NBPARAMS defb 0
;PARAMIX defw 0

LD_IsLoadAdrGiven equ #be3f		;0=pas donnee, utilise celle du fichier
LD_LoadAdr equ #be3d			;Adresse de chargement donnee.
LD_IsLoadBankGiven equ #be3c
LD_LoadBank equ #be3a
LD_FileType equ #be39
LD_NBPARAMS equ #be38
LD_IsAdBufferGiven equ #be37
LD_BufferAdr equ #be35			;word. Adr Buffer amsdos forcee.
;LD_AMSDOSBuffer5 equ #be36
;PARAMIX equ #be36

;LD_FILENAME equ #be20

	list
;**** Fin Load
	nolist
