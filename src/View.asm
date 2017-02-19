    nolist

;   View

;   Composant de la rom Arkos.

;   ùVW,["adr"]




VW_STANDALONE equ 0

    if VW_STANDALONE
    org #1000
    endif


VW_Debut
    or a            ;Pas de param, ok.
    jr z,VW_Init
    cp 1
    jp nz,VW_BadParam
    ld l,(ix+0)
    ld h,(ix+1)
    ld (VW_Pointeur),hl

VW_Init
;Verifie que les vals ne sont pas erronnees
    xor a
    ld (VW_Larg+1),a
    ld a,(VW_Larg)
    ld h,0
    ld l,a
    or a
    jr z,VW_LFake
    cp 81
    jr c,VW_LOk
VW_LFake ld hl,40
VW_LOk  ld (VW_Larg),hl


    ld a,(VW_Haut)
    or a
    jr z,VW_HFake
    cp 201
    jr c,VW_HOk
VW_HFake ld a,200
VW_HOk  ld (VW_Haut),a


    ;Copie le code qui lit la mem en ram
    ld hl,VW_CopyCode
    ld de,VW_ADCopyCode
    ld bc,VW_CopyCodeFin-VW_CopyCode
    ldir

    call #b912
    ld (VW_RMNoRom-VW_CopyCode+VW_ADCopyCode+1),a



    call #bc11
    ld (VW_Mode),a
    ld (VW_IntroMode),a
    call #bc0e

    call VW_AffWin

VW_MainLoop

VW_Key
    call #bd19
    di
    ld a,0+64
    call VW_ROUTOUCH
    ld (VW_KeyL0),a

    ld a,1+64
    call VW_ROUTOUCH
    ld (VW_KeyL1),a

    ld a,5+64
    call VW_ROUTOUCH
    ld (VW_KeyL5),a

    ld a,8+64
    call VW_ROUTOUCH
    ld (VW_KeyL8),a

    ld a,2+64       ;get Shift et Control
    call VW_ROUTOUCH
    and %10100000
    ld b,a


    ei

    ld a,(VW_KeyL8)     ;esc
    cp %11111011
    jp z,VW_Quit

    ld a,(VW_KeyL0)     ;droite
    cp %11111101
    jr z,VW_Droite
    cp %11111011
    jp z,VW_Bas
    cp %11111110
    jr z,VW_GoHaut


    ld a,(VW_KeyL1)     ;gauche
    cp %11111110
    jr z,VW_Gauche
    cp %01111111
    jr z,VW_Mode0
    cp %10111111
    jr z,VW_Mode2
    cp %11011111
    jr z,VW_Mode1

    ld a,(VW_KeyL5)
    cp %01111111
    jp z,VW_Space



    jr VW_Key

VW_Mode0 xor a
    jr VW_ModeX
VW_Mode2 ld a,2
    jr VW_ModeX

VW_Mode1 ld a,1
VW_ModeX ld (VW_Mode),a
    call #bc0e
    jr VW_EndKe2
    

VW_Droite
    ld a,b
    cp %10100000
    jr z,VW_DroiteLarg
    or a
    jr z,VW_LargMax

    ld hl,(VW_Pointeur)
    inc hl
VW_EndKey
    ld (VW_Pointeur),hl
VW_EndKe2 call VW_AffWin
    jp VW_KWait

VW_DroiteLarg
    ld a,(VW_Larg)
    cp 80
    jp z,VW_MainLoop
    inc a
    ld (VW_Larg),a
    jr VW_EndKe2
VW_LargMax
    ld a,80
    ld (VW_Larg),a
    jr VW_EndKe2



VW_Gauche
    ld a,b
    cp %10100000
    jr z,VW_GaucheLarg
    or a
    jr z,VW_LargMin
    ld hl,(VW_Pointeur)
    dec hl
    jr VW_EndKey

VW_GaucheLarg
    ld a,(VW_Larg)
    cp 1
    jp z,VW_MainLoop
    dec a
    ld (VW_Larg),a
    jr VW_EndKe2

VW_LargMin
    ld a,1
    ld (VW_Larg),a
    call #bc14
    jr VW_EndKe2






VW_GoHaut
    ld d,1

    ld a,(VW_Larg)
    ld l,a
    ld h,0

    ld a,b
    cp %10100000
    jr z,VW_HautHauteur
    jr VW_Bas2

;rien = modifie hauteur
;shift= une ligne
;control= plusieurs
;c+s=page
VW_Bas
    ld d,0      ;d=bas 1=haut

    ld a,(VW_Larg)
    ld l,a
    ld h,0

    ld a,b
    cp %10100000
    jr z,VW_BasHauteur
VW_Bas2
    cp %10000000
    jr z,VW_BasGoto
    add hl,hl
    add hl,hl
    add hl,hl
    add hl,hl
;   add hl,hl
    cp %00100000
    jr z,VW_BasGoto
;Page complete
    ld a,(VW_Larg)
    ld c,a
    ld hl,0
    ld b,h
    ld a,(VW_Haut)
VW_BHPage add hl,bc
    dec a
    jr nz,VW_BHPage




VW_BasGoto
    ld bc,(VW_Pointeur)
    ld a,d
    or a
    jr nz,VW_HautGoto
    add hl,bc
    jp VW_EndKey

VW_HautGoto
    ld e,c
    ld d,b
    ex de,hl
    or a
    sbc hl,de
    jp VW_EndKey


VW_BasHauteur
    ld a,(VW_Haut)
    cp 200
    jp z,VW_MainLoop
    inc a
    ld (VW_Haut),a
    jp VW_EndKe2
    
VW_HautHauteur
    ld a,(VW_Haut)
    cp 1
    jp z,VW_MainLoop
    dec a
    ld (VW_Haut),a
    jp VW_EndKe2

;Attends que certaines lignes soient lachees
VW_KWait
    ld h,3
VW_KWa2 call #bd19
    dec h
    jr nz,VW_KWa2


    jp VW_MainLoop



VW_AffWin
    ld a,(VW_Haut)

    ld hl,(VW_Pointeur)
    ld de,#c000
    ld bc,(VW_Larg)
VW_AffLoop
    push hl
    push de
;   ldir
    call VW_ADCopyCode

    ld b,a
    ld a,(VW_Larg)
    cp 80
    jr z,VW_AffLarg80
    ld a,0              ;Ajoute une derniere colonne vide (sauf si larg=80)
    ld (de),a
VW_AffLarg80 ld a,b

    pop hl
    ld bc,#800
    add hl,bc
    jr nc,VW_BC26
    ld bc,#c050
    add hl,bc
VW_BC26 ex de,hl

    pop hl
    ld bc,(VW_Larg)
    add hl,bc

    dec a
    jr nz,VW_AffLoop

    ld a,(VW_Haut)
    cp 200
    ret z
    ex de,hl            ;Ajoute derniere ligne sauf si haut=200
    ld a,(VW_Larg)
    ld b,0
VW_LastLine ld (hl),b
    inc hl
    dec a
    jr nz,VW_LastLine
    
    ret
VW_AffWinFin



VW_Quit
    ld a,(VW_IntroMode)
    call #bc0e
    call #bb00
    ret



VW_Space
    ld a,2
    call #bc0e

    ld hl,VW_TXT_Adr
    call PHRBB5A
    ld hl,(VW_Pointeur)
    call AFFNB16

    ld hl,VW_TXT_Larg
    call PHRBB5A
    ld a,(VW_Larg)
    call AFFNB

    ld hl,VW_TXT_Haut
    call PHRBB5A
    ld a,(VW_Haut)
    call AFFNB

    ld hl,VW_TXT_Mode
    call PHRBB5A
    ld a,(VW_Mode)
    call AFFNB


    di
VW_SKey ld a,5+64
    call VW_ROUTOUCH
    cp #7f
    jr nz,VW_SKey
    ei

    ld a,(VW_Mode)
    jp VW_ModeX

VW_ROUTOUCH     ;58 avec le ret
    LD BC,#F782
    OUT (C),C
    LD BC,#F40E
    OUT (C),C
    LD BC,#F6C0
    OUT (C),C
    DEFB #ed,#71
    LD BC,#F792
    OUT (C),C
    DEC B
    OUT (C),A
    LD B,#F4
    IN A,(C)
    LD BC,#F782
    OUT (C),C
    DEC B
    DEFB #ed,#71
    RET



VW_BadParam ld hl,VW_TXT
    call PHRBB5A
    ret


;Code copie en RAM. Ferme ROM, ldir, Ouvre ROM
VW_CopyCode
    push af
    call #b903

    ldir

VW_RMNoRom ld c,0
    call #b90f

    pop af
    ret
VW_CopyCodeFin


VW_TXT  defb 124,"VW,[Address]",#d,#a
    defb 0

VW_TXT_Adr defb  "Address : ",0
VW_TXT_Larg defb #d,#a,"Width   : &",0
VW_TXT_Haut defb #d,#a,"Heigth  : &",0
VW_TXT_Mode defb #d,#a,"Mode  :    ",0

VW_Larg equ #be3e       ;word
VW_Haut equ #be3d
VW_KeyL0 equ #be3b
VW_KeyL1 equ #be3a
VW_KeyL5 equ #be39
VW_KeyL8 equ #be38
VW_Mode equ #be37
VW_IntroMode equ #be36
VW_Pointeur equ #bdcb       ;Meme que Memory


VW_ADCopyCode equ #bdf7     ;Copie ici le ocde qui va lire la mem (en fermant la rom)



    if VW_STANDALONE

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

HXTAB   defb "0123456789ABCDEF"




PHRBB5A ld a,(hl)
    inc hl
    or a
    ret z
    call #bb5a
    jr PHRBB5A


    endif




    list
;**** Fin View
    nolist
