	nolist

;	SendFile

;	Composant de la rom Arkos.

;	ùSF,"Filename"		Transfert avec header
;	ùSFN,"Filename"		Transfert sans header


;	Pas de test d'erreur en lecture. Bah.




SF_ADCopyPrg equ #a000			;Ou on copie le programme.
SF_Diff equ SF_DebutCode-SF_ADCopyPrg

;Code CPCB en #9c00 ! 

SF_BufferAMSDOS equ #9000		;size = #800
SF_BufferData equ #8000
SF_BDataSize equ #500

;		

SF_STANDALONE equ 0

	if SF_STANDALONE
	org #1000
	endif

SF_Debut
	call SF_DoCopy
	jp SF_ADCopyPrg
SFN_Debut
	call SF_DoCopy
	jp SFN_DebutCode-SF_DebutCode+SF_ADCopyPrg


;	Copie le prg en ram centrale
SF_DoCopy ld hl,SF_DebutCode
	ld de,SF_ADCopyPrg
	ld bc,SF_Fin-SF_DebutCode
	ldir

	ld hl,CPCBooster_ADROM		;Copie le code CPCB
	ld de,AD_CPCBooster
	ld bc,CPCB_CODEFIN-CPCB_CODEDEBUT
	ldir
	ret









SF_DebutCode
	push af
	ld a,1
SF_Deb2	ld (SF_IsHeader),a
	xor a
	ld (SF_IsAscii),a
	ld (SF_IsTransfOver),a
	call #b903			;ram haute
	pop af

	cp 1
	jr z,SF_NbParamsOk
SF_NbParamsNOk
	ld hl,SF_TXT - SF_Diff
	call SF_PHRBB5A - SF_Diff
	ret

;Debut SFN. (no header)
SFN_DebutCode
	push af
	xor a
	jr SF_Deb2

SF_NbParamsOk
	ld e,(ix+0)
	ld d,(ix+1)
	defb #dd : ld l,e
	defb #dd : ld h,d
	ld a,(ix+0)
	or a
	jr z,SF_NbParamsNOk
	ld c,a
	ld b,0
	ld l,(ix+1)
	ld h,(ix+2)
	ld de,SF_FILENAME
	ldir
	ld b,11
	ld a,32
SF_P12	ld (de),a
	inc de
	djnz SF_P12





;Test CPCB
	di
	call CPCB_Init
	ei
;	jr SF_CPCBDetected			;***********************
	jr c,SF_CPCBDetected

	ld hl,SF_TXT_CPCBNotDetected - SF_Diff
	call SF_PHRBB5A - SF_Diff
	ret



SF_CPCBDetected

;Init communication avec PC
SF_InitComm
	di
	call CPCB_InitPC
	ei
;	jr SF_CommOK				;*****************
	jr c,SF_CommOK
	ld hl,SF_TXT_NoComm - SF_Diff
	call SF_PHRBB5A - SF_Diff
	call #bb18
	cp #fc
	ret z
	jr SF_InitComm

SF_CommOK











	ld hl,SF_BufferData
	ld de,SF_BufferData+1
	ld bc,127
	ld (hl),0
	ldir

	ld hl,SF_FILENAME
	ld de,SF_BufferAMSDOS
	ld b,12
	call #bc77
	jp nc,SF_ErrorDisc - SF_Diff

	ld (SF_Size),bc
	cp #16
	jr nz,SF_NoAscii
	xor a
	ld (SF_IsHeader),a
	inc a
	ld (SF_IsAscii),a


SF_NoAscii
	ld a,(SF_IsHeader)
	or a
	jr z,SF_HeaderFin

	ld de,SF_BufferData		;copie le header original du fichier
	ld bc,67
	ldir

	ld a,#ff			;First bloc a #ff. Utile ?
	ld (SF_BufferData+#17),a

;	Creation du checksum
	ld hl,0				;Somme totale
	ld de,SF_BufferData
	ld b,67
SF_HeadLoop
	ld a,(de)
	add a,l
	ld l,a
	ld a,h
	adc a,0
	ld h,a
	inc de
	djnz SF_HeadLoop
	ld (SF_BufferData+67),hl



SF_HeaderFin

;Creation du fichier cote PC.
	ld hl,SF_FILENAME
	call CPCB_CreateOutputFile
	jp nc,SF_CantCreatePCFile - SF_Diff	;****************



	ld hl,SF_TXT_Transf - SF_Diff
	call SF_PHRBB5A - SF_Diff


;Envoi du header au PC
	ld hl,SF_BufferData
	ld de,128
	di
	ld a,(SF_IsHeader)
	or a
	call nz,CPCB_AddDataToOutputFile
	ei


;Envoi du reste des donnees.
;On remplit d'abord un buffer interne autant qu'on peut, puis on le balance au PC.
SF_NewPasse
	ld a,(SF_IsAscii)		;Si ascii, remplissage special
	or a
	jr z,SF_SendBinary

SF_NewPasseAscii
	ld hl,SF_BufferData		;Dest
	ld bc,SF_BDataSize		;Taille buffer, diminue
	ld ix,0				;Nb octets ecrits
SF_SALoop
	call #bc80
	jr c,SF_SALOk
	cp #1a				;'Erreur' trouvee ds fichier ascii. Si #1a, octet normal
	jr z,SF_SALOk
	ld a,1
	ld (SF_IsTransfOver),a
	jr SF_SALOver

SF_SALOk ld (hl),a
	inc hl
	dec bc
	inc ix

	ld a,c				;Si buffer plein, passe finie
	or b
	jr nz,SF_SALoop

;Passe ASCII finie. On envoie le buffer sur PC
SF_SALOver
	ld hl,SF_BufferData
	push ix
	pop de
	di
	call CPCB_AddDataToOutputFile
	ei

	ld a,(SF_IsTransfOver)
	or a
	jr nz,SF_SendOver
	jr SF_NewPasseAscii





;Remplissage Buffer avec fichier Binaire.
SF_NewPasseBinary

SF_SendBinary
	ld hl,SF_BufferData		;Dest
	ld de,(SF_Size)			;Taille fichier BINAIRE
	ld bc,SF_BDataSize		;Taille buffer, diminue
	ld ix,0				;Nb octets ecrits
SF_SBLoop
	call #bc80
	ld (hl),a
	inc hl
	dec de
	dec bc
	inc ix
;
	ld a,e				;Si fichier fini, passe finie
	or d
	jr z,SF_SBPasseOver

	ld a,c				;Si buffer plein, passe finie
	or b
	jr nz,SF_SBLoop

;Passe Binaire finie. On envoi le buffer sur PC
SF_SBPasseOver
	ld (SF_Size),de

	ld hl,SF_BufferData
	push ix
	pop de
	di
	call CPCB_AddDataToOutputFile
	ei

	ld hl,(SF_Size)
	ld a,l
	or h
	jr z,SF_SendOver

	jr SF_NewPasseBinary




SF_SendOver 
	call CPCB_CloseOutputFile

	ld hl,SF_TXT_Done - SF_Diff
	call SF_PHRBB5a - SF_Diff

SF_ErrorDisc
SF_Quit	call #bc7a
	di
	call CPCB_SendEndCommand
	ei
	ret





SF_CantCreatePCFile
	ld hl,SF_TXT_CantCreatePCFile - SF_Diff
	call SF_PHRBB5A - SF_Diff
	ret







SF_TXT	defb 124,"SF[N],",34,"Filename",34,#d,#a
	defb 0

SF_TXT_CantCreatePCFile defb "Can't create PC file.",#d,#a,0

;SF_TXT_Deb defb "Transfering... ",0
;SF_TXT_Over defb "Done !",#d,#a,0

;SF_TXT_CPCBNotDetected defb "CPC Booster not detected !",#d,#a,0
;SF_TXT_NoComm defb "Unable to communicate. A Key to retry.",#d,#a,0





SF_TXT_CPCBNotDetected defb "CPC Booster not detected !",#d,#a,0
SF_TXT_NoComm defb "Unable to communicate. A Key to retry.",#d,#a,0
SF_TXT_Transf defb "Transfering... ",0
SF_TXT_Done defb "Done !",#d,#a,0



SF_PHRBB5A ld a,(hl)
	inc hl
	or a
	ret z
	call #bb5a
	jr SF_PHRBB5A


SF_Fin

	list
; *** Fin SendFile
	nolist


SF_IsHeader equ #be3f
SF_Size	equ #be3d
SF_IsAscii equ #be3c
SF_IsTransfOver equ #be3b

SF_FILENAME equ #be20







	if SF_STANDALONE
	read "cpcbooster.asm"
	endif


