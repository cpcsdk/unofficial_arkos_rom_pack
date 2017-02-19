    nolist

;   Header

;   Composant de la rom Arkos.

;   ùH,"fichier"



HD_STANDALONE equ 0



HD_Debut
;Regarde le nb de params.
    cp 1
    jr z,HD_NbParamsOk
HD_NbParamsNOk
    ld hl,HD_TXT
    call PHRBB5A
    ret




HD_NbParamsOk
    ld e,(ix+0)
    ld d,(ix+1)
    defb #dd 
  ld l,e
    defb #dd 
  ld h,d

    ld a,(ix+0)
    or a
    jr z,HD_NbParamsNOk
    ld b,a

;   ld c,a
;   ld b,0
    ld l,(ix+1)
    ld h,(ix+2)
;   ld de,HD_FILENAME
;   ldir
;   ld b,11
;   ld a,32
;HD_P12 ld (de),a
;   inc de
;   djnz HD_P12


;   ld hl,HD_FILENAME
    ld de,#c000
;   ld b,12
    call #bc77
    jr nc,HD_ErrorDisc
    cp #16
    jr nz,HD_TypeOk
;Fichier Ascii
    ld hl,HD_TXT_Ascii
    call PHRBB5A
    jr HD_Quit

HD_TypeOk
;   ld (HD_Type),a
    ld (HD_Length),bc

    ex de,hl
    defb #dd 
  ld l,e
    defb #dd 
  ld h,d

    ld l,(ix+#15)       ;get Start
    ld h,(ix+#16)
    ld (HD_Start),hl
    ld l,(ix+#1a)       ;get Exec
    ld h,(ix+#1b)
    ld (HD_Exec),hl

;Affiche Header.
    push af
    ld a,'&'
    call #bb5a
    pop af
    call AFFNB

    ld a,32
    call #bb5a
    call #bb5a

    ld hl,(HD_Start)
    call AFFNB16
    ld hl,(HD_Length)
    call AFFNB16
    ld hl,(HD_Exec)
    call AFFNB16

    ld a,#d
    call #bb5a
    ld a,#a
    call #bb5a

HD_Quit
HD_ErrorDisc
    call #bc7a
    ret

;Affiche un nb 8bits en hexa
AFFNB
    call HDNBTOHEX
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
HDNBTOHEX
    push de
    push hl

    ld b,a
    and %00001111
    ld l,a
    ld h,0
    ld de,HXTAB2
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

HXTAB2  defb "0123456789ABCDEF"


HD_TXT  defb 124,"HD,",34,"Filename",34,#d,#a
    defb 0

HD_TXT_Ascii defb "Ascii File.",#d,#a,0



;HD_Type equ #be3f
HD_Start equ #be3d
HD_Length equ #be3b
HD_Exec equ #be39

;HD_FILENAME equ #be20






    list
;**** Fin Header
    nolist





;*** AVIRER


;PHRBB5A    ld a,(hl)
;   inc hl
;   or a
;   ret z
;   call #bb5a
;   jr PHRBB5A

;***
