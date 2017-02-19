    nolist

;   Burn

;   Composant de la rom Arkos.

;   ùBURN,"Filename",Rom




BN_LOADROM equ #4000
BN_AMSDOSBuffer equ #9000

BN_ADCopyPrg equ #a000          ;Ou on copie le programme.
BN_Diff equ BN_DebutCode-BN_ADCopyPrg

BN_STANDALONE equ 0

    if BN_STANDALONE
    org #a000
    endif


BN_Debut
;   Copie le prg en ram centrale
    ld hl,BN_DebutCode
    ld de,BN_ADCopyPrg
    ld bc,BN_Fin-BN_DebutCode
    ldir
    jp BN_ADCopyPrg

BN_DebutCode
;   push af
;   call #b903          ;Ram haute
;   pop af

    cp 2
    jr z,BN_NbParamsOk
BN_NbParamsNOk
    ld hl,BN_TXT
    call BN_PHRBB5A-BN_Diff
    call #b903
    ret

BN_NbParamsOk
    ld a,(ix+0)     ;Lis Rom
    ld (BN_Rom),a
;   inc ix
;   inc ix
    ld e,(ix+2)
    ld d,(ix+3)
    defb #dd 
  ld l,e
    defb #dd 
  ld h,d

    ld l,(ix+1)
    ld h,(ix+2)
    ld a,(ix+0)
    or a
    jr z,BN_NbParamsNOk

    ld de,BN_AMSDOSBuffer
    ld b,a
    call #bc77
    jr nc,BN_ErrorDisc

    ld hl,BN_LOADROM
    call #bc83
    jr nc,BN_ErrorDisc

    call #bc7a

    ld hl,BN_TXT_Switch
    call BN_PHRBB5A-BN_Diff
    call #bb18
    cp #fc
    jr z,BN_Quit

    ld a,(BN_Rom)
    ld c,a
    call #b90f      ;Ouvre ROM
;   ld (NB_OldRom+1),bc

    ld hl,#4000
    ld de,#c000
    ld c,l
    ld b,h
    ldir



    ld hl,#4000
    ld de,#c000
BN_Check
    ld a,(de)       ;Verification
    cp (hl)
    jr nz,BN_BadCopy
    inc hl
    inc de
    ld a,d
    or a
    jr nz,BN_Check

    ld c,#ff
    call #b90f      ;Ouvre ROM bidon (#ff, pas decr ds ramcard)

    call #bc11
    call #bc0e

    ld hl,BN_TXT_Success
    call BN_PHRBB5A-BN_Diff
    call #bb18
    jr BN_Quit


BN_BadCopy
    call #bc11
    call #bc0e
    ld hl,BN_TXT_BadCopy
    call BN_PHRBB5A-BN_Diff

BN_ErrorDisc
BN_Quit
    call #b903      ;Ram haute
    ret






BN_PHRBB5A
    ld de,BN_Diff
    or a
    sbc hl,de
BN_PHRBB5A2
    ld a,(hl)
    or a
    ret z
    inc hl
    call #bb5a
    jr BN_PHRBB5A2


BN_TXT  defb 124,"BN,",34,"Filename",34,",Rom",#d,#a
    defb 0
BN_TXT_Switch defb "Switch to Write mode and press a key.",#d,#a,0
BN_TXT_BadCopy defb "Burning failed !",#d,#a,0
BN_TXT_Success defb "Rom burnt successfully.",#d,#a
    defb "Remove Write mode and press a key.",#d,#a,0


BN_Fin



BN_Rom  equ #be3b

    list
;**** Fin Burn
    nolist




