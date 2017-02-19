

;   Catalogue Pour DSKtoDISK



;Affiche le catalogue PC.
;RET=Carry=1=ok
;Carry=0=pas ok (read fail)
DIRDOS
;   if ISTRY
;   xor a
;   ld (NBPARAMS),a
;   endif


    ld (NBPARAMS),a
    ld (PARAMIX),ix

    ld hl,USEBB5A
    ld (hl),1

    or a
    jr z,DDPOK
    cp 1
    jp nz,BADPARAM
DDPOK
;   ld sp,PILE

    ld a,'B'
    ld (USERDRIVES),a



    ld a,(NBPARAMS)
    or a
    jr z,CATPCNOPARAM
;Un parametre entré
    ld ix,(PARAMIX)     ;Get lecteur en param
    ld l,(ix+0)
    ld h,(ix+1)
    inc hl
    ld e,(hl)
    inc hl
    ld d,(hl)
    ld a,(de)
    
    ld (USERDRIVES),a
    
    call ISUDROK
    jp nc,BADDRIVE

CATPCNOPARAM

    call INIT

    call DODIRDOS
    jr c,DDEND
    ld hl,TXTREADFAILCRITIC
    call PHRASE

DDEND
;   jp PRGEND
    call FDCOFF

    ld hl,$+6   ;Remets le systeme avant de partir
    jp STARTSYS
    ret




DODIRDOS

    call FDCON


;   ld a,(SRCLECT)
;   call CHLECT
;   call RECALIBR
;   call RECALIBR

    xor a
    call CHLECT
    call RECALIBR
    call RECALIBR
    ld a,1
    call CHLECT
    call RECALIBR
    call RECALIBR



    ld a,(USERDRIVES)
    res 5,a
    sub 'A'
    ld (SRCLECT),a
    call CHLECT

    ld a,(LECTEUR)
    add a,"A"
    ld (TXTCA2),a

    ld hl,TXTCAT
    call PHRASE

    ;call FDCON


    call READBOOT
    ret nc
    ;jp nc,DOOFNOK


CPRBOK

;L'ecriture du DIR ROOT pour chercher le fichier. On a DIRROOTSIZE secteurs a scanner.
    ld a,DIRROOTSIZE
    ld (DOSCPTLOOP),a
    ld hl,(NOSECTDIRROOT)
    ;inc hl
    ;inc hl
    ld (ODSSECT),hl

CPFNSLP ld hl,(ODSSECT)
    ld de,BUFLOAD
    call LOADDOSSECT
    or a
    ;jp nz,ODFREADFAIL
    ret nz

    ld a,DOSSECTSIZEBYTES/32    ;Nb entrees par secteur
    ld ix,BUFLOAD
CPFELP
    defb #dd 
  ld e,l
    defb #dd 
  ld d,h
    ex de,hl
    ld de,CATFILENAME
    ld bc,8
    ldir
    inc de          ;skip the point
    ldi
    ldi
    ldi

    push ix
    push af

    ld a,(ix+11)        ;get file type
    ld (DOSFILETYPE),a

    ld a,(CATFILENAME)
    or a
    jr z,CPNOWRIT
    cp #e5          ;fichier efface, on n'affiche pas
    jr z,CPNOWRIT


    ld a,(DOSFILETYPE)      ;fichier ou dir ?
    and %110000
    jr z,CPNOFILE
;
CPNBLIGNES ld a,0
    inc a
    cp 22
    jr nz,CPNBL2
    ld hl,CATSPACE
    call PHRASE
    call SPACE
    xor a
CPNBL2  ld (CPNBLIGNES+1),a
    
;
    ld hl,CATFILENAME
    call PHRASE


    ld hl,TXTDIRECTORY
    ld a,(DOSFILETYPE)      ;fichier ou dir ?
    bit 4,a             ;bit 4=dir
    jr nz,CPFIL2
    bit 5,a             ;bit 5=fichier
    jr nz,CPFILE
    jr CPFIL2           ;autre (sys)    
    
CPFILE  ld hl,TXTNEXTLINE
CPFIL2  call PHRASE
CPNOFILE
CPNOWRIT pop af
    pop ix

    ld de,32        ;Passe a entree suivante
    add ix,de
    dec a
    jr nz,CPFELP
;Plus d'entree pour ce secteur. Passe au suivant si on peut
    ld hl,(ODSSECT)
    inc hl
    ld (ODSSECT),hl
    ld a,(DOSCPTLOOP)
    dec a
    ld (DOSCPTLOOP),a
    jp nz,CPFNSLP

    scf
    ret

;   if ISRSX
;RSX1BUF    defs 4,0
;RSX2BUF    defs 4,0
;NOMRSX1 defb "WRITEDS","K"+#80,0
;NOMRSX2 defb "DIRDO","S"+#80,0
;RSX1   defw NOMRSX1
;   jp CODEDEBUT
;RSX2   defw NOMRSX2
;   jp DIRDOS
;   endif


WR_CODEFIN

    list
;**** Fin CatPC
    nolist
