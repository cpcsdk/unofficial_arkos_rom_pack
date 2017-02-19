

;
;        Lecture de fichier PC, format FAT 12.
;    pour DSK2DISC
;
;   Disc PC = 80 pistes, double faces, 9 secteurs par piste.

;   Assez limité, ne lit que le repertoire Root.
;   Ne teste pas tous les formats.


;   NORMALISATION =
;   Mes numeros de secteur ABSOLUS commencent a 0. Donc, BOOT=secteur 0.


DOSNBSECTS equ 9    ;1-9
DOSSECTSIZE equ 2
DOSSECTSIZEBYTES equ 512
DOSGAP  equ #4e

DIRNBENTRIES equ 112    ;Nb entrees max.
DIRROOTSIZE equ 7   ;Taille en secteur du DIR ROOT. Hardcode mais bon... 32*DIRNBENTRIES/512




;Ouvre un fichier DOS. Verifie la validité du format, ecrit les nos de clusters dans BUFFLOAD
;HL=nom fichier (11 caracs), bien formatte, majuscule.
;RET=Carry=1=ok
;Carry=0=pas ok  A=0=format disc mauvais    1=fichier non trouve.  2=read fail.
OPENDOSFILE
    ld de,DOSFILENAME
    ld bc,11
    ldir

    ld hl,BUFENTRIES    ;Clear le buffer des entrees.
    ld de,BUFENTRIES+1
    ld bc,BUFENTRIESSIZE-1
    ld (hl),0
    ldir

    ;ld hl,$+6
    ;jp STOPSYS

    ;call FDCON

    ld a,(SRCLECT)
    call CHLECT
;   xor a
;   call CHHEAD

    call READBOOT
    ret nc

;Lecture du DIR ROOT pour chercher le fichier. On a DIRROOTSIZE secteurs a scanner.
    ld a,DIRROOTSIZE
    ld (DOSCPTLOOP),a
    ld hl,(NOSECTDIRROOT)
    ld (ODSSECT),hl

ODFNSLP ld hl,(ODSSECT)
    ld de,BUFLOAD
    call LOADDOSSECT
    or a
    jp nz,ODFREADFAIL

    ld c,DOSSECTSIZEBYTES/32    ;Nb entrees par secteur
    ld ix,BUFLOAD
ODFELP  push bc
    defb #dd 
  ld e,l
    defb #dd 
  ld d,h
    ld hl,DOSFILENAME   ;Compare entree avec nom fichier
    ld bc,11
    call CPTSTRINGS
    pop bc
    jr c,ODFFOUND
ODEDIR  ld de,32        ;Passe a entree suivante
    add ix,de
    dec c
    jr nz,ODFELP
;Plus d'entree pour ce secteur. Passe au suivant si on peut
    ld hl,(ODSSECT)
    inc hl
    ld (ODSSECT),hl
    ld a,(DOSCPTLOOP)
    dec a
    ld (DOSCPTLOOP),a
    jr nz,ODFNSLP
    jp ODFNOTFOUND      ;Pas de fichier trouve dans les secteurs !

ODFFOUND

;Trouve ! IX pointe sur l'entree. Est-ce bien un fichier ?
    bit 5,(ix+11)
    jr z,ODEDIR     ;Si non, alors on retourne cherche !

    ld l,(ix+26)        ;Get entry cluster
    ld h,(ix+27)
    ld (DOSENTRY),hl


;On va lire la FAT dans le BUFMAIN (on passe par le BUFLOAD car READSECT l'utilise).
    ld hl,(NOSECTFAT)
    ld de,BUFMAIN
    ld a,(ONEFATSIZE)
    ld b,a
ODFREADFAT
    push bc
    push hl

    push de
    ld de,BUFLOAD
    call LOADDOSSECT
    or a
    jr nz,ODFRFAV
    pop de
    ld hl,BUFLOAD       ;Copie buffer dans BUFMAIN.
    ld bc,DOSSECTSIZEBYTES
    ldir

    pop hl
    inc hl          ;Charge le secteur suivant

    pop bc
    djnz ODFREADFAT



;Remplit le buffer des entrees.
    ld ix,BUFENTRIES
    ld hl,(DOSENTRY)    ;Remplit deja la 1ere entree qu'on connait...
    ld (ix+0),l
    ld (ix+1),h
    inc ix
    inc ix


;Calcul de l'entree suivante
ODFFELP ld hl,(DOSENTRY)
    ld e,l
    ld d,h
    xor a           ;is carry?
    rr h
    rr l
    adc a,0         ;si carry, a=1
    add hl,de
    ld b,a

    ld de,BUFMAIN
    add hl,de
    ld e,(hl)       ;de=next entry
    inc hl
    ld d,(hl)
;
    bit 0,b         ;y avait-il une carry ?
    jr z,ODFNOC
    srl d           ;carry. On decale d'un digit
    rr e
    srl d
    rr e
    srl d
    rr e
    srl d
    rr e
    jr ODFNOF
ODFNOC  ld a,d          ;pas de carry. DE AND #fff
    and %00001111
    ld d,a
ODFNOF  
    ld a,d
    cp #f           ;Si entry = #fff alors fin.
    jr nz,ODFNOE
    ld a,e
    cp #ff
    jr nz,ODFNOE
    ld (ix+0),e     ;code #ffff pour marquer la fin de la liste.
    ld (ix+1),e
    jr ODFFIN

ODFNOE  ld (DOSENTRY),de
    ld (ix+0),e
    ld (ix+1),d
    inc ix
    inc ix
    jr ODFFELP

ODFRFAV pop bc
    pop hl
    pop de
    jr ODFREADFAIL

;Fini ! On a maintenant la liste des clusters.
ODFFIN
    ld hl,0         ;Ainsi, qd besoin octet de DSK, on force la lecture secteur.
    ld (BUFLOADFREE),hl
    ld hl,BUFLOAD
    ld (PTBUFLOAD),hl
    ld hl,BUFENTRIES
    ld (PTBUFENTRIES),hl


    scf
    ret



;Lis Boot secteur, verifie le boot
;RET=Carry=1=ok
;Carry=0=pas ok  A=0=format disc mauvais    1=fichier non trouve.  2=read fail.
READBOOT
;Lis Boot secteur
    ld hl,0
    ld de,BUFLOAD
    call LOADDOSSECT
    or a
    jp nz,ODFREADFAIL
;
;Verifie les octets de boot
    ld hl,BUFLOAD+11
    ld de,DOSBOOTSTR1
    ld bc,DOSBOOTSTR1F-DOSBOOTSTR1
    call CPTSTRINGS
    jp nc,ODFBADFORMAT

;Petit calcul pour positionner les differentes parties de la disc.

    ld a,(BUFLOAD+22)       ;get ONEFATSIZE
    ld (ONEFATSIZE),a
    add a,a
    add a,1
    ld (NOSECTDIRROOT),a        ;On obtient le secteur de debut de la SECTOR TABLE. FATSIZE*2+1
    add a,DIRROOTSIZE       ;En ajoutant la taille du DIRROOT
    ld (NOSECTDATA),a

    ld a,1
    ld (NOSECTFAT),a        ;la FAT se trouve sur le 2e secteur
    scf
    ret




ODFBADFORMAT ;ld hl,TXTBADFORMAT
    xor a
    ret
ODFNOTFOUND ;ld hl,TXTNOTFOUND
    or a
    inc a
    ret
ODFREADFAIL ;ld hl,TXTREADFAIL      ;Read fail
    or a
    ld a,2
    ret







DOSBOOTSTR1 defb 0,2,  2,   1,0,  2,   DIRNBENTRIES,0,   #a0,5  ;chaine de cmp, offset 11.
;             *** bizarre !
DOSBOOTSTR1F














;Lis un octet du DSK.
;RET=A=octet.   Carry=1=ok  0=pas ok.A=0=read fail 1=EOF.
READBYTEFROMDSK
    push hl
    push de
    push bc
;   ld a,(USERDRIVES)
;   cp "C"
;   jr nz,READBYTEFROMDSKNormal
;   ld hl,1
;   ld de,RBFDByte+1
;   call CPCB_GetXBytes
;RBFDByte ld a,0
;   jr RBFDOK
;READBYTEFROMDSKNormal
    ld hl,(BUFLOADFREE) ;S'il reste des octets non lus dans buffer, on les lit.
    ld a,l
    or h
    jr z,RBFDENDSECT
RBFDOB  dec hl          ;Prend octet du buffer
    ld (BUFLOADFREE),hl
    ld hl,(PTBUFLOAD)
    ld a,(hl)
    inc hl
    ld (PTBUFLOAD),hl
RBFDOK  pop bc
    pop de
    pop hl
    scf
    ret

RBFDENDSECT         ;On doit lire un nouveau secteur.
    ld a,(SRCLECT)
    call CHLECT
    ;xor a
    ;call CHHEAD


    ld hl,(PTBUFENTRIES)
    ld e,(hl)
    inc hl
    ld d,(hl)
    inc hl
    ld (PTBUFENTRIES),hl

    ld a,d          ;#ff=fin fichier
    cp #ff
    jr z,RBFDESEOF

    ex de,hl
    dec hl          ;On soustrait 2. C'est comme ca !
    dec hl
    add hl,hl       ;On multiplie par 2 car un cluster=1 sect
    ld de,(NOSECTDATA)  ;Positionne le no secteur au debut des secteurs data
    add hl,de
    ld (TEMP),hl
    ld de,BUFLOAD
    call LOADDOSSECT
;   ld (ISERROR),a

;   ld a,(DESTLECT)
;   call CHLECT

;   ld a,(ISERROR)
    or a
    jr nz,RBFDESNOK

;   ld hl,$+6
;   jp STOPSYS

    ld hl,(TEMP)        ;Lis le secteur suivant, inclue dans le meme cluster
    inc hl
    ld de,BUFLOAD2
    call LOADDOSSECT
    ld (ISERROR),a

;   ld hl,$+6
;   jp STARTSYS

    ld a,(ISERROR)
    or a
    jr nz,RBFDESNOK

    ld hl,BUFLOAD
    ld (PTBUFLOAD),hl

    ld hl,BUFLOADSIZE   ;Lis un octet
    jr RBFDOB

RBFDESEOF or a      ;EOF.
    ld a,1
    pop bc
    pop de
    pop hl
    ret
RBFDESNOK xor a     ;read fail
    pop bc
    pop de
    pop hl
    ret





;Charge un secteur du DOS dans BUFLOAD. Le numero est ABSOLU, donc la FAT est a prendre en compte.
;HL=no secteur ABSOLU
;DE=Ou charger
;RET=A=0=ok 1=erreur fdc.
LOADDOSSECT
    ld (LOADWHERE),de

    ld a,(SRCLECT)
    call CHLECT

;Calcul du numero de sect/piste, en fct du numero de sect. Methode violente.
    ld de,#0001 ;D=piste (0-80)  E=Secteur (1-9)
    ld c,0      ;C=head (0-1)
LDSLP   ld a,l
    or h
    jr z,LDSCNF ;Si HL=0 alors on a fini
    call NEXTDOSSECTOR
    dec hl
    jr LDSLP
LDSCNF

    ld a,d
    ld b,e
;Lis un  secteur
;A=piste
;B=nom secteur
;C=side
;D=taille
;E=GAP
;HL=ou le charger
    ld d,DOSSECTSIZE
    ld e,DOSGAP
    ld hl,(LOADWHERE)
    call READSECTDOS

    ret



;D=piste (0-80)  E=Secteur (1-9)    B=head (0-1)
NEXTDOSSECTOR
    inc e
    ld a,e
    cp DOSNBSECTS+1
    ret nz
;Piste finie
    ld e,1

    inc c       ;si head a 0, on passe a 1
    ld a,c
    cp 1
    ret z
    ld c,0      ;si head a 1, on passe a 0 et on passe a piste suivante.
    inc d

    ret





    list
;**** Fin ReadPCFile
    nolist
