    nolist

;   GetFile

;   Composant de la rom Arkos.

;   ùGF,"Filename",[start],[exec]
;   ùGFA,"Filename"         ;Sauvegarde en Ascii. 




GF_STANDALONE equ 0


GF_ADCopyPrg equ #9E00          ;Ou on copie le programme.
GF_Diff equ GF_DebutCode-GF_ADCopyPrg





    if GF_STANDALONE
    org GF_ADCopyPrg
    endif

;   jr GF_Debut

;
BufferAMSDOS equ #8000      ;size = #800
BufferGetBytes equ #3000
NbBytesToGet equ #1000




GF_Debut
    call GF_DoCopy
    jp GF_ADCopyPrg
GFA_Debut
    call GF_DoCopy
    jp GFA_DebutCode-GF_DebutCode+GF_ADCopyPrg


;   Copie le prg en ram centrale
GF_DoCopy ld hl,GF_DebutCode
    ld de,GF_ADCopyPrg
    ld bc,GF_Fin-GF_DebutCode
    ldir

    ld hl,CPCBooster_ADROM      ;Copie le code CPCB
    ld de,AD_CPCBooster
    ld bc,CPCB_CODEFIN-CPCB_CODEDEBUT
    ldir
    ret







;Debut RSX Binaire (normal)
GF_DebutCode
    push af

    ld hl,#4000     ;Valeurs par defaut
    ld (GF_Start-GF_Diff),hl
    ld (GF_Exec-GF_Diff),hl
    xor a
    ld (GF_IsStartGiven-GF_Diff),a
    ld (GF_IsExecGiven-GF_Diff),a
    ld (GF_SaveAsAscii-GF_Diff),a
    dec a
    ld (GF_OrigFileType-GF_Diff),a  ;indefini au depart. Si pas de header, basic non force.

    pop af

;Regarde Parametres.
    or a
    jr z,GF_PNok
    cp 4
    jr c,GF_ParamOk
GF_PNok ld hl,GF_TXT_ParamNok - GF_Diff
    call GF_PHRBB5A - GF_Diff
    ret

;Debut RSX ASCII
GFA_DebutCode
    cp 1
    jr nz,GF_PNok

    xor a
    ld (GF_IsStartGiven-GF_Diff),a
    ld (GF_IsExecGiven-GF_Diff),a
    inc a
    ld (GF_SaveAsAscii-GF_Diff),a
    jr GF_Param1



GF_ParamOk
    cp 1
    jr z,GF_Param1
    cp 2
    jr z,GF_Param2

;Get Param 3 (=exec)
GF_Param3
    ld l,(ix+0)
    ld h,(ix+1)
    inc ix
    inc ix
    ld (GF_Exec-GF_Diff),hl
    ld a,1
    ld (GF_IsExecGiven-GF_Diff),a

;Get Param 2 (=start)
GF_Param2
    ld l,(ix+0)
    ld h,(ix+1)
    inc ix
    inc ix
    ld (GF_Start-GF_Diff),hl
    ld a,2
    ld (GF_IsStartGiven-GF_Diff),a


;Get Param 1 (=filename)
GF_Param1
    ld e,(ix+0)
    ld d,(ix+1)
    defb #dd 
  ld l,e
    defb #dd 
  ld h,d
    ld a,(ix+0)
    or a
    jr z,GF_PNok
    ld c,a
    ld b,0
    ld l,(ix+1)
    ld h,(ix+2)
    ld de,GF_Filename - GF_Diff
    ldir
    ld b,11
    ld a,32
GF_P12  ld (de),a
    inc de
    djnz GF_P12




;   call #b903          ;rom haute

;Test CPCB
    di
    call CPCB_Init
    ei
    jr c,GF_CPCBDetected

    ld hl,GF_TXT_CPCBNotDetected - GF_Diff
    call GF_PHRBB5A - GF_Diff
    ret



GF_CPCBDetected

;Init communication avec PC
GF_InitComm
    di
    call CPCB_InitPC
    ei
    jr c,GF_CommOK
    ld hl,GF_TXT_NoComm - GF_Diff
    call GF_PHRBB5A - GF_Diff
    call #bb18
    cp #fc
    ret z
    jr GF_InitComm

GF_CommOK


;Transfert le fichier



;Recoit nom de fichier
;   ld hl,GF_Filename-GF_Diff
;   di
;   call CPCB_AskFileName
;   ei

;Ouvre le fichier en entree.
    ld hl,GF_Filename - GF_Diff
    call CPCB_OpenInputFile
    jr c,GF_FileOk
    ld hl,GF_TXT_CantOpenFile - GF_Diff
    call GF_PHRBB5A - GF_Diff
    ret
GF_FileOk



;Recoit la taille du fichier.
    ld hl,GF_Length-GF_Diff
    di
    call CPCB_AskFileSize
    ei

    ld hl,(GF_Length-GF_Diff+2)       ;Si taille<128 alors pas de header
    ld a,l
    or h
    jr nz, read_header              ; File is larger than 64K
    ld hl,(GF_Length-GF_Diff)       ;Si taille<128 alors pas de header
    ld de,128
    sbc hl,de
    or a
    jr c,GF_RHFin

read_header
;Lis le header
    ld hl,128
    ld de,BufferGetBytes
    call CPCB_GetXBytes

;Check Checksum
    ld hl,0     ;Total sum
    ld d,#a7e2-#a79f
    ld bc,BufferGetBytes
GF_CheckSum
    ld a,(bc)
    add a,l
    ld l,a
    ld a,h
    adc a,0
    ld h,a
    inc bc
    dec d
    jr nz,GF_CheckSum

    ld de,(BufferGetBytes+67)   ;checksum egal ?
    or a
    sbc hl,de
    jr z,GF_HeaderPresent

    call CPCB_RewindFile        ;Header non present, on revient au debut du fichier.
    jr GF_RHFin

GF_HeaderPresent
    ld hl,GF_HeaderFound - GF_Diff
    call GF_PHRBB5A - GF_Diff

    ld a,(BufferGetBytes+#12)   ;get Original FileType
    ld (GF_OrigFileType-GF_Diff),a

;Chope les valeurs
    ld a,(GF_IsStartGiven-GF_Diff)
    or a
    jr nz,GF_RHNoStart

    ld hl,(BufferGetBytes+#15)  ;get Start
    ld (GF_Start-GF_Diff),hl

GF_RHNoStart
    ld a,(GF_IsExecGiven-GF_Diff)
    or a
    jr nz,GF_RHNoExec

    ld hl,(BufferGetBytes+#1a)  ;get Exec
    ld (GF_Exec-GF_Diff),hl
GF_RHNoExec

    ld hl,(GF_Length-GF_Diff)       ;Taille=Taille-header
    ld de,128
    or a
    sbc hl,de
    ld (GF_Length-GF_Diff),hl
    jr nc, GF_RHFin

    ; Overflow of substraction, decrement second word of filesize
    ld hl,(GF_Length-GF_Diff+2)
    dec hl
    ld (GF_Length-GF_Diff+2),hl

GF_RHFin









;Ouvre le fichier en sortie
    ld hl,GF_Filename-GF_Diff
    ld de,BufferAMSDOS
    ld b,12
    call #bc8c
    jp nc,GF_ErrorDisc - GF_Diff

    ld (GF_FileHandle-GF_Diff),hl
    push hl
    pop ix

    ld a,(GF_SaveAsAscii-GF_Diff)
    or a
    jr nz,GF_AsciiFile
    ld b,2
    ld a,(GF_OrigFileType-GF_Diff)      ;Basic autorisé
    or a
    jr nz,GF_ForceType
    ld b,0
GF_ForceType
    ld (ix+#a7b1-#a79f),b       ;Force Binary Filetype

GF_AsciiFile
    ld hl,GF_TXT_Transf - GF_Diff
    call GF_PHRBB5A - GF_Diff


;Recoit les octets dans buffer.
GF_MainLoop
;Regarde si le fichier est assez grand pour remplir le buffer.

    ld hl,(GF_Length-GF_Diff)
    ld de,NbBytesToGet
    or a
    sbc hl,de
    jr nc,GF_NBBytesOk
    jr z,GF_NBBytesOk

    ; Not enough bytes in 16-bit filesize, see if there are more 64K blocks by decrementing the
    ; high part of the filesize
    push hl
    push de
    ld hl,(GF_Length-GF_Diff+2)

    ; DEC HL does not update the flags, so do it the complicated way...
    ld de,1
    or a
    sbc hl,de
    ld (GF_Length-GF_Diff+2),hl

    pop de
    pop hl
    jr nc,GF_NBBytesOk

;Pas assez d'octets dans fichier pour remplir buffer.
    ld de,(GF_Length-GF_Diff)
    ld hl,0
    ld (GF_Length-GF_Diff+2),hl

GF_NBBytesOk ld (GF_Length-GF_Diff),hl
    ld (GF_BytesWritten-GF_Diff),de


    di
    ld bc,#7f10
    out (c),c

    ld hl,(GF_BytesWritten-GF_Diff)
    ld de,BufferGetBytes
    call CPCB_GetXBytes
    ei

;Ecrit ce qu'on a ecrit dans le buffer sur disc.
    ld de,(GF_BytesWritten-GF_Diff)
    ld hl,BufferGetBytes
GF_WriteBytesLoop
    ld a,(hl)
    call #bc95
    jr nc,GF_ErrorDisc
    inc hl
    dec de
    ld a,e
    or d
    jr nz,GF_WriteBytesLoop


    ld hl,(GF_Length-GF_Diff)
    ld a,l
    or h
    ld hl,(GF_Length-GF_Diff+2)
    or l
    or h
    jr nz,GF_MainLoop



;Fin transfert.
    ld ix,(GF_FileHandle-GF_Diff)

    ld hl,(GF_Start-GF_Diff)            ;Force Start
    ld (ix+#a7b4-#a79f),l
    ld (ix+#a7b4-#a79f+1),h

    ld l,(ix+#a7df-#a79f)           ;Create Length
    ld h,(ix+#a7df-#a79f+1)
    ld (ix+#a7b7-#a79f),l
    ld (ix+#a7b7-#a79f+1),h
;   ld (ix+#a7b2-#a79f),l           ;length mod &800
;   ld (ix+#a7b2-#a79f+1),h


    ld hl,(GF_Exec-GF_Diff)         ;Force Exec
    ld (ix+#a7b9-#a79f),l
    ld (ix+#a7b9-#a79f+1),h

    ld hl,GF_TXT_Done - GF_Diff
    call GF_PHRBB5A - GF_Diff

GF_END
    call #bc8f
    di
    call CPCB_SendEndCommand
    ei
    ret


GF_ErrorDisc
    ld hl,GF_TXT_DiscError - GF_Diff
    call GF_PHRBB5A - GF_Diff
    jr GF_END

GF_IsStartGiven db 0
GF_IsExecGiven db 0
GF_OrigFileType db 0        ;Pratique pour permettre le basic
GF_Start dw 0
GF_Length dw 0,0        ;32 bits !
GF_Exec dw 0
GF_SaveAsAscii db 0

GF_BytesWritten defw 0      ;Bytes ecrit pour cette passe.
GF_FileHandle defw 0        ;Donne par creation de fichier.
GF_Filename defs 13,0



GF_TXT_ParamNok
    defb 124,"GF[A],",34,"Filename",34,",[start],[exec]",#d,#a
    defb 0

GF_HeaderFound defb "Header found. ",0

GF_TXT_CPCBNotDetected defb "CPC Booster not detected !",#d,#a,0
GF_TXT_NoComm defb "Unable to communicate. A Key to retry.",#d,#a,0
GF_TXT_CantOpenFile defb "Can't open the PC file !",#d,#a,0
GF_TXT_Transf defb "Transfering... ",0
GF_TXT_Done defb "Done !",#d,#a,0
GF_TXT_DiscError defb "Disc Error !",#d,#a,0

GF_PHRBB5A ld a,(hl)
    inc hl
    or a
    ret z
    call #bb5a
    jr GF_PHRBB5A


GF_Fin


    list
; *** Fin GetFile
    nolist



    if GF_STANDALONE

    read "cpcbooster.asm"

    endif




