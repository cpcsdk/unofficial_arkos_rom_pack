    nolist

;   WRITEDSK
 
;   Interpretation de DSKS, Ecriture sur disk des pistes et secteurs contenus dedans.
;   Et Catalogue du disc DOS.



;   V1.2
;   Support CPCB.
;   Gestion secteurs IDs identiques.
;   Gestion 64k.
;   Permet "1" uniquement au lieu de "BA1"


;   V1.1
;   Interface graphique plus elaboree.
;   Gestion complete deformattage double face
;   Permet "BA1" ou 1 est la side de dest.
;   Resolution bug CAT.
;   Resolution bug file not found.
;   Interface graphique sans passer par le systeme pour avoir plus gros buffer.
;   Nouvelle gestion ecriture de secteurs, en passant par ACTUAL SECT LENGTH. Ainsi on est sur de
;   toujours retomber sur ses pattes.
;   Gestion secteurs effaces.
;   Quand regarde quel est le secteur le plus grand d'une piste, ne prends pas si ST1/2 bad cheksum.
;   Ctrl+shift+esc pour resetter
;   Buffer plus gros.


;   TODO ?
;   Pas de gestion d'erreur FDC au niveau de PUT_DSK_TRACK_IN_BUFFMAIN.
;   A part pour InitPC, Si Timeout CPCB, on recommence infiniment.



;   ùWDSK,"filename",["SDh"]    defaut = BA
;   ùDIRDOS,["S"]           defaut = B

WD_STANDALONE equ 0 ;+1
ISROM   equ 1 ;-1
;ISRSX  equ 0

;WR_ADROM equ #dcb0 ;#e000   ;Adresse en rom. On la fixe car le placement dynamique fait chier. ; XXX Mandatory ?
WR_ADROM equ $ ;#e000   ;Adresse en rom. On la fixe car le placement dynamique fait chier.

WR_ADCODENORMAL equ #8080   ;Adresse du code.
ADINITRSX equ #8000 ;Petit lanceur RSX.








;   A SAVOIR
;   ********
;   Nouvelle gestion ecriture de secteurs =
;   EXTENDED = utiliser l'actual sector size pour ecrire le bon nombre d'octets.
;   (utile ?? sachant que les sect size peuvent varier dans format EXTENDED...)
;   En pratique, on ecrit autant que le FDC en demande, mais on ADD au pointeur de donnees
;   la valeur Actual Data Length pour etre sur de retomber sur ses pattes.

;   STANDARD = utiliser le sector size (ID sect) pour ecrire le bon nombre d'octets, MAIS
;   lire dans le vide les X octets restant selon le 'sector size' contenu dans TRACK INFO.
;   DE PLUS, en STANDARD, des qu'on lit TRACKNBBYTESTOREAD dans le header DSK,
;   on DECREMENTE de #100 car le header est lu a part.

;   TOUTES les tracks en Standard possedent un Header track, on se sert du nb sects pour
;   savoir la piste doit etre ecrite ou non. Cela permet d'avoir un compte de track utilisable.


;   On n'utilise PAS le SECTOR SIZE de la piste ! Pas fiable, car winape ne l'update pas.
;   On regarde quel est le secteur le plus grand d'une piste (pour savoir quelle taille donner
;   au formattage, ne pas prendre en compte les sects dont ST1 et ST2 sont 'erreur checksum' (disco).


;   Le HEAD correspond a la TETE utilisee quand on ECRIT. Une SIDE correspond au header secteur.
;   Technique utilisee pour forcage de face (BAh) = Si non-double-sided-DSK alors on force
;   la head a 0 ou 1 quand on lit header piste.

;   Nouvelle technique pour detecter fin de dsk (en plus des autres),
;   Compte le nb de pistes valides (taille >0) dans la table des poids fort des tailles pistes.
;   Quand compteur=0 alors fin dsk.

;   Si on trouve la fin du dsk au moment de lire le header piste, on considere que le DSK
;   est fini.
;   On considere que le sector size a mettre dans le HEADER PISTE est le plus grand trouvé
;   parmi ceux des sectors size. Ainsi, les protections fonctionnent ainsi que la MP.
;   Quand on lit une track du DSK, se servir du tableau dans le header DSK
;   pour lire le bon paquet de donnees (Leaderboard), ou si STANDARD, de TRACKSIZE donnée dans header DSK.




;   Les headers (DSK/tracks) utilisent le meme buffer, BUFWRITE (egalement utilise pour ecriture trk)
;   Une fois les infos connues, on les stocke a la suite dans un gros buffer, suivi des datas
;   de la track. Ce gros buffer commence en ram centrale et fini en bank.
;   On remplit ce buffer octet par octet directement du fichier PC.

;   Les routines qui ecrivent sur le disk ont besoin de données lineaires
;   accessibles directement. On leur reserve donc un buffer de #1a00 (taille 6+id sects).
;   Ce buffer (BUFWRITE) est rempli quand on a besoin de faire le transfert d'une piste.
;   On y chope les infos IDs et les datas pistes que l'on copie dans le BUFWRITE.


;   Si on teste la validité des pistes (taille, etc...) pendant qu'on lit le header piste/sects,
;   On place un flag dans le buffmain. Une fois qu'on s'apprete a les ecrire, on lit mais on
;   n'ecrit pas dans le buffmain. Qd on voudra ecrire sur disc, on verra le flag et on passera
;   a la piste suivante.

;

;   CPCB = on peut se passer des gros buffers, car on sauve une piste a chaque fois.
;   le BUFMAIN ne contient plus que le header de la piste+info secteurs.
;   A l'origine on chargeait les datas sects dans BUFWRITE, mais on le charge directement
;   dans un buffer CPCB, BUFWRITECPCB que l'on place en plein milieu de la mem, car des trucs comme
;   DISCO6 ont des pistes de plus de 6k !! (declarations de gros secteurs avec bad cks). Avant ca
;   n'arrivait pas car ca bufferisait, mais avec le CPCB, ca bufferise plus.


;   Format buffer MAIN =

;   Db TrackNumber,   Side (1/2),   Sector size,   Nb sectors,   Gap#3,   Filler Byte.

;   Pour chaque secteur =
;   [ db TrackNumber,    Side,   SectorID,   Sector size,  FDC R1,  FDC R2,  DW ACTUAL DT LGT] * nbsects
;   +DB GOODTRACK ? (1=ok 0=non)



LOWESTGAP equ #20
MAXGAP  equ #4e

NBMAXTRACKS equ 82  ;Nb maximum de pistes.82=de 0 a 81.
NBTRACKSINMEM equ 40    ;Ne sert qu'a definir la taille du buffer contenant les adrs des pistes dans
            ;le BUFMAIN. Par securite, on l'utilise aussi comme nb max de pistes chargees
            ;dans le BUFMAIN, meme si on teste deja la fin du buffer avant de charger une
            ;autre piste

PILE    equ #50

NBKOBUFFC0 equ 32   ;Nb de ko dispo dans le buffer en ram centrale.


BUFMAIN equ #50     ;Buffer principal ou on stocke les IDs sects/trks/datas a la suite.
BUFMMAX equ WR_ADCODENORMAL ;Adresse la plus haut en memoire centrale pour le buffer principal.
            ;Apres, il va en bank.
            ;ON SE SERT de BUFMAIN egalement pour charger la FAT entiere en vue de construire
            ;la liste des entrees facilement.

BUFWRITECPCB equ #4000  ;Buffer CPCB. On y mets les DATAs sects de la track. On place ca ici en bourrin
            ;car il n'y a pas de bufferisation, la mem est a nous, mais il faut faire attention
            ;car DISCO declare des gros sects avec bad cks !!

BUFLOAD equ #9e00   ;#400. Utilise qd chargement secteur PC. 1 cluster = 2 secteurs
BUFLOAD2 equ BUFLOAD+#200
BUFLOADSIZE equ #400

BUFWRITE equ #a200  ;#1800 Buffer pour ecriture track OU traitement headers.
BUFMAINSIZE equ #1800   ;Liste IDs tr/sec + datas. 1 track, taille 5 max. puisque t6 non supporte.

BUFENTRIES equ #ba00    ;#600. Contient les nos clusters du fichier. 
BUFENTRIESSIZE equ #600

;FONTE  equ #bd00   ;#2f0



;   if ISRSX
;   org ADINITRSX
;   list
;*** debut init rsx
;   nolist
;   ld bc,RSX1
;   ld hl,RSX1BUF
;   call #bcd1
;   ld bc,RSX2
;   ld hl,RSX2BUF
;   call #bcd1
;   ld hl,RSXPHR
;RSXBB5A    ld a,(hl)
;   or a
;   ret z
;   call #bb5a
;   inc hl
;   jr RSXBB5A

;RSXPHR defb 124,"W,",34,"dsk",34,",",34,"[SRCDriveDESTDrive][1]",34," ",13,10,124,"Dirdos,[",34,"SRCDrive",34,"]",#d,#a
;   defb 0

;   list
;*** fin init rsx
;   nolist
;   endif







    if ISROM
;   org #c000
    else
    org WR_ADCODENORMAL
    endif




;   if ISROM
;   defb 1      ;type ROM
;   defb 1      ;mark number
;   defb 2      ;version number
;   defb 0      ;mod number
;   defw TABINSTR
;   JP MKINIT
;   jp MKDSK
;   jp JPDIRDOS
;TABINSTR defb "wdsk","m"+#80
;   defb "WDS","K"+#80
;   defb "DIRDO","S"+#80
;   defb 0


;MKINIT
;   push bc
;   push de
;   push hl

;   ld hl,TXTROM1
;   call PHRBB5A
;
;   call #b912

;   ld b,a
;   sub 10
;   jr c,MKINI10
;   ld a,"1"
;   call #bb5a
;   ld a,b
;   add "0"-10
;   call #bb5a
;   jr MKINIF

;MKINI10 ld a,b
;   add a,"0"
;   call #bb5a
;MKINIF
;   ld hl,TXTROM2
;   call PHRBB5A

;MKINI2 
;   pop hl
;   pop de
;   pop bc
;   scf
;   ret
;TXTROM1 defb #f,3,"Rom ",0
;TXTROM2    ;defb " ; ",#f,2,"Wdsk",#f,1,",dsk,[",34,"BA",34,"] ",#f,2,"Dirdos",#f,1,",[",34,"B",34,"]",#d,#a
;   defb " ; ",#f,2,"Wdsk",#f,1,",dsk,",34,"[BA][1]",34," ",#f,2,"Dirdos",#f,1,",",34,"B",34,#d,#a
;   defb 0

;PHRBB5A    ld a,(hl)
;   or a
;   ret z
;   call #bb5a
;   inc hl
;   jr PHRBB5A

;   endif





    if ISROM
;   org ADCODENORMAL,MKDK2
 ;   org WR_ADCODENORMAL,WR_ADROM ; XXX Winape stuff converted
  ;  org WR_ADROM
    rorg WR_ADCODENORMAL
    endif

WR_CODEDEBUT
;    jp DIRDOS          ;****** TEST CATALOGUE

    ld (NBPARAMS),a
    ld (PARAMIX),ix

    ld d,0
    ld hl,#4000
    ld bc,#7fc7
    out (c),c
    ld (hl),#aa
    ld c,#c4
    out (c),c
    ld (hl),#cc
    ld c,#c7
    out (c),c
    ld a,(hl)
    cp #aa
    jr z,Found128K
    ld d,1
Found128K ld a,d
    ld (IS64K),a
    ld c,#c0
    out (c),c

;   if ISTRY
;   jr ROMNOPOK
;   endif
    
    ld a,(NBPARAMS)
    cp 1
    jr z,ROMNOPOK
    cp 2
    jr z,ROMNOPOK
BADPARAM ld hl,TXTBADPARAM
ERRPARAM
    call PHRBB5A
    ret
ROMNOPOK

    ld hl,'A'*256+'B'       ;****
    ld (USERDRIVES),hl
    xor a               ;Par defaut, on ecrit sur la side 0.
    ld (DESTHEAD),a


;   if ISRSX
;   jr DOPARAMS
;   endif

;   if ISTRY
;   jr SKIPPARAMS
;   endif


;   if ISROM
;   else
;   jr SKIPPARAMS
;   endif
;DOPARAMS
    ld a,(NBPARAMS)
    cp 1
    jr z,PARAM1
;BADPARAM ld hl,TXTBADPARAM
;   call PHRASE
;   jp PRGEND
;Deux params. On copie les deux drives donnes dans USERDRIVES.
PARAM2  
    ld ix,(PARAMIX)     ;get drives
    ld l,(ix+0)
    ld h,(ix+1)
    inc ix
    inc ix
    ld (PARAMIX),ix
    push hl
    pop ix

    ld l,(ix+1)
    ld h,(ix+2)
    ld a,(ix+0)     ;si 1 carac alors forcedrive only
    cp 1
    jr z,PARAMFH

PARAM223 ld de,USERDRIVES
    ldi
    ldi
    
    cp 3
    jr nz,PARAM1
PARAMFH ld a,(hl)
    sub '0'
    ld (DESTHEAD),a
    ld a,1
    ld (FORCEHEAD),a    ;On a force la head de dest.

;Un seul param. Forcement le nom du fichier.
PARAM1  ld ix,(PARAMIX)     ;get filename
    ld l,(ix+0)
    ld h,(ix+1)
    push hl
    pop ix

    ld a,(ix+0)     ;si longueur fichier trop long or vide, stoppe
    or a
    jp z,BADNAME
    cp 13
    jr c,P1LNGOK
    jp BADNAME
P1LNGOK ld c,a
    ld b,0
    ld l,(ix+1)
    ld h,(ix+2)
    ld de,USERFILENAME
    ldir

    ld hl,USERFILENAME  ;Transforme le nom donne par l'utilisateur en champ utilisable
    ld a,USERFILENAMEF-USERFILENAME
    call TREATFILENAME
    jp nc,BADNAME


SKIPPARAMS
    ld hl,BUFMAIN
    ld (PTBUFMAIN),hl
    ld a,#c0
    ld (BKBUFMAIN),a

;Verifie l'authenticite des parametres

    ld a,(FORCEHEAD)
    or a
    jr z,DHEADOK
    ld a,(DESTHEAD)     ;Si on force la tete a 0, erreur (securite)
    cp 1
    jp nz,BADHEAD
DHEADOK
    ld a,(USERDRIVES)
    res 5,a
    cp "C"          ;CPCBooster authorisee sur src
    jr z,DHSRCC
    call ISUDROK
    jp nc,BADDRIVE
DHSRCC  ld a,(USERDRIVES+1)
    call ISUDROK
    jp nc,BADDRIVE
    jr UDREND
ISUDROK res 5,a
    cp "A"
    jr z,UDROK
    cp "B"
    jr z,UDROK
    or a
    ret
UDROK   scf
    ret

UDREND  ld a,(DESTHEAD)
    add a,"0"
    ld (TXTDEBU4),a

    ld a,(USERDRIVES)
    res 5,a
    ld (USERDRIVES),a
    ld (TXTDEBU2),a
    ld (TXTINSERTSR2),a
    sub "A"
    ld (SRCLECT),a

    ld a,(USERDRIVES+1)
    res 5,a
    ld (USERDRIVES+1),a
    ld (TXTDEBU3),a
    ld (TXTINSERTDES2),a
    sub "A"
    ld (DESTLECT),a

    ld b,a
    ld a,(SRCLECT)
    xor b
    ld (DIFFDRIVE),a
    

    call INIT
    ld sp,PILE


;   xor a
;   ld (DESTLECT),a
;   ld a,1
;   ld (SRCLECT),a

    xor a
    ld (EOFMET),a
    ld (USEBB5A),a

;   call GETFNT

    call FDCON


    xor a
    call CHLECT
    call RECALIBR
    call RECALIBR
    ld a,1
    call CHLECT
    call RECALIBR
    call RECALIBR


;*****************
;OUVERTURE FICHIER
;*****************

    ld bc,#7f10     ;Select border (pour lecture CPCB)
    out (c),c

    ld a,(IS64K)
    or a
    jr z,TXT128K
    ld hl,'0'*256+'3'
    ld (TXTBUFFE3),hl
TXT128K

    ld hl,TXTWRITEDSK
    call PHRASE
    ld hl,TXTSOULIGNE
    call PHRASE

    ld a,8
    call SETAFFY
    ld hl,TXTSOULIGNE
    call PHRASE
    ld hl,TXTSOULIGNE
    call PHRASE
    ld hl,TXTSOULIGNE
    call PHRASE

    ld hl,TXTITF1
    call PHRASE
    ld hl,TXTITF2
    call PHRASE

        ld hl,TXTITFTRK
    call PHRASE
        ld hl,TXTITFSIDE
    call PHRASE
    ld hl,TXTITFGAP
    call PHRASE
    ld hl,TXTITFFILL
    call PHRASE
    ld hl,TXTITFNBS
    call PHRASE
    ld hl,TXTITSSIZE
    call PHRASE

    ld a,21
    call SETAFFY
    ld hl,TXTSOULIGNE
    call PHRASE
    ld hl,TXTSOULIGNE
    call PHRASE
    ld hl,TXTSOULIGNE
    call PHRASE


    ;ld hl,TXTSOULIGN3
    ;call PHRASE


    ;ld hl,TXTWARNING
    ;call PHRASE

;Si CPCBooster, teste sa presence
    ld a,(USERDRIVES)
    cp "C"
    jr nz,OVNOCPCB

    call CPCB_Init
    jr c,OVCPCBPresente
    ld hl,TXTNOCPCB     ;Si CPCB non detectee, reset
    call PHRASE
    call SPACE
    jp 0
;CPCB presente. Test avec PC
OVCPCBPresente
    call CPCB_InitPC
    jr c,OVCPCBOk
;Test avec PC pas bon. Retry.
    ld hl,TXTPCCOMFailed
    call PHRASE
    call SPACE
    call CLEARBAS
    jr OVCPCBPresente

;CPCB branchee et communication etablie.
OVCPCBOk
    ld hl,TXTDEBUT      
    call PHRASE
    ld hl,TXTINSERTCPCB
    call PHRASE
    call SPACE
    call CLEARBAS


;On ouvre le fichier DSK sur PC.
    ld hl,USERFILENAME
    call CPCB_OpenInputFile
    jr c,DOFOK
    ld hl,TXTINPUTFILENOK       ;Impossible d'ouvrir le fichier. Reset.
    call PHRASE
    call SPACE
    jp 0    




;Pas de CPCB, fonctionnement normal
OVNOCPCB
    ld hl,TXTDEBUT
    call PHRASE

    ;ld hl,TXTOPENING
    ;call PHRASE

    ld hl,TXTINSERTSRC
    call PHRASE
    call SPACE

    call CLEARBAS

DOOPENFILE
    ld hl,DOSFILENAME
    call OPENDOSFILE
    jr c,DOFOK
DOOFNOK or a
    jr z,DOFBADFORMAT
    cp 1
    jr z,DOFNOTFOUND
    jp READFAILCRITIC
    ;ld ix,TXTREADFAIL  ;Read fail critique
    ;ld hl,DOOPENFILE
    ;ld de,0
    ;ld bc,PRGEND
    ;jp RETRYIGNORECANCEL


DOFNOTFOUND ld hl,TXTNOTFOUND   ;File not found. Critique
DOFEXIT call PHRASE
    jp PRGEND
DOFBADFORMAT ld hl,TXTBADFORMAT ;Bad format. Critique
    jr DOFEXIT

DOFOK



;Fichier trouve (ou cpcb en action). On affiche resume de l'action, apres un warning.

;**************
;LECTURE HEADER
;**************

    ld a,(SRCLECT)
    call CHLECT
    xor a
    call CHHEAD

;Lance interpretation header du DSK.
    ld hl,BUFWRITE          ;Charge header de #100
    ld bc,#100
    call READBYTESFROMDSK

    ld ix,BUFWRITE          ;Interprete header DSK.
    call INTERPRET_DSK_HEADER
    jp nc,BADDSKHEADER





;Affiche resultat interpretation header.
    ld hl,TXTFORMATEXT      ;Affiche format DSK.
    ld a,(DSKFORMAT)
    or a
    jr nz,EXTDETECTED
    ld hl,TXTFORMATSTD
EXTDETECTED call PHRASE

    ld a,(DSKNBTRACKS)      ;Affiche nb tracks et sides
    call NBTODEC
    ld a,b
    ld (TXTDSKTRACK2),a
    ld a,c
    ld (TXTDSKTRACK2+1),a

    ld hl,TXTDSKTRACKS
    call PHRASE

    ld hl,TXTSINGLESIDED
    ld a,(DSKNBSIDES)       ;Affiche nb tracks et sides
    cp 2
    jr nz,DOUBLESIDED
    xor a               ;si double sided, on ignore le forcage de HEAD.
    ld (FORCEHEAD),a
    ld hl,TXTDOUBLESIDED
DOUBLESIDED
    call PHRASE
;   call HEXTOASC
;   ld a,c
;   ld (TXTDSKSIDE2),a


;Si FORCEHEAD alors DSKLASTSIDE devient DESTHEAD.
    ld a,(FORCEHEAD)
    or a
    jr z,CLFRMTB
    ld a,(DESTHEAD)
    ld (DSKLASTSIDE),a

;Remplir le buffer des etats des pistes pour deformattage.
CLFRMTB ld hl,LSTTRACKSFORMATTED        ;Place les pistes en 'ne pas toucher'
    ld de,LSTTRACKSFORMATTED+1      ;On clear les 2 buffers d'un coup.
    ld bc,LSTTRACKSFORMATTED2F-LSTTRACKSFORMATTED-1
    ld (hl),#ff
    ldir
;   ld hl,LSTTRACKSFORMATTED2       ;Meme chose pour les pistes de SIDE 1.
;   ld de,LSTTRACKSFORMATTED2+1
;   ld bc,LSTTRACKSFORMATTED2F-LSTTRACKSFORMATTED2-1
;   ld (hl),#ff
;   ldir

;Remplir de 1 (=a DEformatter) les pistes a traiter. Elles seront marquees 'formattées' a la fin du
;traitement piste, et ne seront donc pas deformattees
;Attention, si on force, ne mettre des 1 que sur la face forcee.
    ld a,(DSKNBSIDES)
    cp 2
    jr nz,FBSTRSINGLE
    call FBSTRH0                ;Double face. On mets les 2 a deformatter.
FBSTRDH1 call FBSTRH1
    jr FBSTREND
FBSTRSINGLE                 ;Simple face. On formatte celle qui est designee
    ld a,(DESTHEAD)             ;en RSX (ou celle par defaut).
    or a
    jr nz,FBSTRDH1
    call FBSTRH0
    jr FBSTREND

FBSTRH0 ld hl,LSTTRACKSFORMATTED
    call FBSTTRDO
    ret
FBSTRH1 ld hl,LSTTRACKSFORMATTED2
    call FBSTTRDO
    ret
FBSTTRDO ld a,(DSKNBTRACKS)         ;Sous routine qui remplit la liste pointee par HL       
FBSTTRLP ld (hl),1              ;de 1 '=a deformatter'.
    inc hl
    dec a
    jr nz,FBSTTRLP
    ret

FBSTREND















;On revient ici quand le BUFMAIN a ete entierement traite et qu'on va traiter les autres pistes.
NEWPASS
    call CLEARBAS

    ld hl,TXTREADPCDSK
    call PHRASE

;Si CPCB, pas la peine d'effacer le bufmain, c'est lent. On se contente d'en effacer une petite partie.
        ld a,(USERDRIVES)
        cp "C"
        jr nz,NPNOCPCB
        ld hl,BUFMAIN
        ld de,BUFMAIN+1
        ld bc,#500
        ld (hl),c
        ldir
        jr NEWPASS2

NPNOCPCB
    call CLEARBUFMAIN
NEWPASS2 ld hl,BUFMAIN
    ld (PTBUFMAIN),hl
    ld a,#c0
    ld (BKBUFMAIN),a




;*******************
;GESTION D'UNE PISTE
;*******************

;***************************************************************************************
;Lire NBTRACKSINMEM de pistes venant du DSK. On NOTE en memoire le debut des infos piste/ids/datas
;grace a PTBUFMAIN/BKBUFMAIN.
    ld hl,LSTPTTRACKSINMEM
    ld (PTLSTPTTRACKSINMEM),hl
    ld a,NBTRACKSINMEM      ;On gere plus de cette maniere. On regarde s'il reste de
    ld (CPTLOOP),a          ;la place dans buffer. Mais on le garde par securite.

GRTLOOP
    call CALCBUFFER

    ld hl,TXTBUFFER
    ld a,(USERDRIVES)
    cp "C"
    call nz,PHRASE

    call ISRESET

    ld hl,(PTLSTPTTRACKSINMEM)  ;Sauvegarde l'adr du debut de la piste+bank
    ld de,(PTBUFMAIN)       ;dans liste des infos+data tracks en mem.
    ld (hl),e
    inc hl
    ld (hl),d
    inc hl
    ld a,(BKBUFMAIN)
    ld (hl),a
    inc hl
    ld (PTLSTPTTRACKSINMEM),hl

;Lis et interprete Header PISTE DSK
    ld hl,BUFWRITE      ;Lis #100 octets du DSK
    ld bc,#100
    call READBYTESFROMDSK
    jr c,GRTNOERR
    or a            ;A=0=read fail. Critique.
    jp z,READFAILCRITIC
GRTERROF
;   ld a,(NOWTRACK)     ;A=1=EOF. Si c'est le cas, on arrete de lire et on passe
;   ld b,a          ;a l'ecriture de notre buffer.
;   ld a,(DSKNBTRACKS)
;   dec a
;   cp b
;   jp nz,ERROREOFMET       ;Unexpected eof. NON Critique maintenant DANS CE CAS.
    ld a,1              ;On ecrit ce qu'on a en mem.
    ld (EOFMET),a
    ld hl,(PTLSTPTTRACKSINMEM)  ;Elimine le traitement de cette piste en virant
    dec hl              ;ce qu'il y a dans 'bank'.
    ld (hl),0
    jr AVCDWLOOP        ;Ecriture des pistes.


GRTNOERR ld ix,BUFWRITE     ;Interpretation PISTE.
    call READ_DSK_TRACK_HEADER
    jp nc,GRTERROF


;Si la piste a 0 secteurs alros on ne l'ecrit pas (Cas uniquement utile dans STANDARD)
;Permet le deformattage.
    ld a,(TRACKNBSECTS)
    or a
    jr nz,GRTNOER2
    ld hl,(PTLSTPTTRACKSINMEM)  ;On efface l'entree de la piste dans les pointeurs
    xor a               ;de tracks. Plus propre...
    dec hl
    ld (hl),a
    dec hl
    ld (hl),a
    dec hl
    ld (hl),a
    ld (PTLSTPTTRACKSINMEM),hl
    jr GRTDCPT


;Lis les octets de la track du DSK et les place dans le BUFFMAIN, lit TRACKNBBYTESTOREAD octets.
;Si CPCB, la routine place la track dans BUFWRITE puis la copie dans BUFFMAIN.
GRTNOER2 call PUT_DSK_TRACK_IN_BUFFMAIN
;** tester erreur disc ?

;Marque la piste comme 'traitee' pour pas qu'on la deformatte !
    call SETTRACKASTREATED


        ;*** test CPCB. Si presente, on ne lit qu'une seule track, pas de bufferisation !
        ld a,(USERDRIVES)
        cp "C"
        jr z,GRTEND



GRTDCPT ld a,(CPTLOOP)  ;Juste une securite pour ne pas lire trop de pistes, ca ferait deborder
    dec a       ;le buffer LSTPTTRACKSINMEM.
    ld (CPTLOOP),a
    jr z,GRTEND
;Autre methode = tant qu'il reste de la place dans le buffer, on continue
    ld a,(IS64K)
    or a
    jr z,GRTD128

    ld hl,(PTBUFMAIN)   ;sur 64k, on teste le pointeur du buffer en #c0
    ld de,BUFMMAX-BUFMAINSIZE
    or a
    sbc hl,de
    jp c,GRTLOOP
    jr GRTEND

GRTD128
    ld a,(BKBUFMAIN)
    cp #c7          ;Si on a pas atteint encore bank c7, on peut continuer
    jp nz,GRTLOOP
    ld hl,(PTBUFMAIN)
    ld de,#8000-BUFMAINSIZE
    or a
    sbc hl,de
    jp c,GRTLOOP

;***************************************************************BOUCLER ICI
GRTEND



;*******************************************************************************
;Lire #1a00 octets (on s'en fout de la taille exacte) selon le debut des infos piste/ids/datas sauves
;precedemment, les interpreter et les ecrire, boucler, et voila.

;Ecrit une piste sur disquette CPC.
;Tout d'abord, copie les donnees de la piste qui arrive, de PTBUFMAIN vers le BUFWRITE lineaire.
AVCDWLOOP
    call CLEARBAS

    ld a,(DIFFDRIVE)
    or a
    jr nz,IDDIFF
    ld hl,TXTINSERTDEST
    call PHRASE
    call SPACE
    call CLEARBAS
IDDIFF

    ld hl,LSTPTTRACKSINMEM
    ld (PTLSTPTTRACKSINMEM),hl


        ;*** test CPCB. Si presente, on balance directement ce qu'on a lu dans BUFWRITE
        ld a,(USERDRIVES)
        cp "C"
        jr nz,CDWLOOP
        ld ix,BUFMAIN
        jr CDWTRK2


CDWLOOP
    call ISRESET

    ld ix,(PTLSTPTTRACKSINMEM)
    ld l,(ix+0)         ;get adinfos+data track
    ld h,(ix+1)
    ;ld (PTBUFMAINALT),hl
    ld a,(ix+2)         ;get bank. 0=fin buffer.
    or a
    jp z,CWDEND2
    ld c,a
    ;ld (BKBUFMAINALT),a
    inc ix
    inc ix
    inc ix
    ld (PTLSTPTTRACKSINMEM),ix

    ld iy,BUFWRITE

;Copie de trackinfos+data de BUFMAIN vers BUFWRITE. On copie la taille max en bourrin...
    ld b,#7f
    ld de,BUFMAINSIZE       ;Nb d'octets a copier.

CDWCLP  out (c),c
    ld a,(hl)
    ld (iy),a
    inc iy
    push de
    call INCPTBUFMAIN
    pop de
    dec de
    ld a,e
    or d
    jr nz,CDWCLP
    ld c,#c0
    out (c),c

;Ecriture de la track qui se trouve dans BUFWRITE avec ses infos.
CDWTRK  ld ix,BUFWRITE
CDWTRK2
    ld a,(ix+0) ;get track number pour affichage ligne du bas
    call NBTODEC
    ld a,b
    ld (TXTTRAC2),a
    ld a,c
    ld (TXTTRAC2+1),a

    ld a,(ix+1) ;get side, forcee ou non
    add a,"0"
    ld (TXTTRAC3),a

    ld hl,TXTTRACK
    call PHRASE


    call DSK_WRITE_TRACK
    ;push af
    ;ld a,(WTSIDE)
    ;add a,"0"
    ;ld (TXTTRAC3),a
    ;pop af

    jr c,CDWTOK

    or a
    jr z,CDWTBAD
    ;ld hl,TXTTRACK     ;Error disc. Non critique
    ;call PHRASE
    ;ld hl,TXTERROR
    ;call PHRASE
    ld ix,TXTERROR
    ld hl,CDWTRK
    ld de,CDWEND
    ld bc,PRGENDFAIL ;PRGEND
    jp RETRYIGNORECANCEL

CDWTBAD ;ld hl,TXTTRACK
    ;call PHRASE
    ld hl,TXTBADTRACK   ;Bad format. Skip.
    call PHRASE
    jr CDWEND

CDWTOK  ld hl,TXTTRACK
    call PHRASE
    ld hl,TXTTRACKOK    ;Tout va bien.
    call PHRASE


CDWEND  ld hl,DSKNBPISTESCODEES ;Fin track, reussi ou non (si non, on passe a la suivante).
    dec (hl)        ;Cette variable n'est valable que pour EXTENDED.

;       ld bc,#7f10
;       out (c),c
;       ld a,#4b
;       out (c),a
;       call SPACE
;       ld bc,#7f10
;       out (c),c
;       ld a,#44
;       out (c),a


        ;**** Test CPCB. Si presente, on n'a qu'une track en mem donc on passe a la suite.
        ld a,(USERDRIVES)
        cp "C"
        jr z,CWDEND2

    jp CDWLOOP      ;Track suivant en memoire !

;Toutes les tracks valides en memoire ont été ecrites.
CWDEND2 
    ;call CLEARITF

    ld a,(EOFMET)
    or a
    jr nz,DSKFINI

    ld a,(DSKNBPISTESCODEES)
    or a
    jr z,DSKFINI

    ld a,(DSKFORMAT)
    or a
    jr nz,CWDEND3
    ld a,(DSKLASTSIDE)  ;Si STANDARD alors on compare derniere piste ecrite avec LASTvals
    ld b,a
    ld a,(WTSIDE)
    cp b
    jr nz,CWDEND3
    ld a,(DSKLASTTRACK)
    ld b,a
    ld a,(WTTRACK)
    cp b
    jr z,DSKFINI        ;si les 2 vals egales alors derniere piste ecrite, fini !

CWDEND3
    ld a,(DIFFDRIVE)
    or a
    jr nz,ISDIFF
    call CLEARBAS
    ld hl,TXTINSERTSRC
    call PHRASE
    call SPACE
    call CLEARBAS
ISDIFF

    jp NEWPASS



;EOF Trouve. Fin du DSK !
;Si des pistes sont non formattees, il faut les deformatter.
DSKFINI
    ld hl,LSTTRACKSFORMATTED
    ld b,NBMAXTRACKS
    ld c,0      ;No Piste
    ld a,0      ;No side
    ld (NOWSIDE),a
    call DFUTLP ;Teste cette side

    ld hl,LSTTRACKSFORMATTED2   ;On passe sur liste side 1.
    ld b,NBMAXTRACKS
    ld c,0      ;No Piste
    ld a,1      ;No side
    ld (NOWSIDE),a
    call DFUTLP ;Teste cette side

    jr DSKFIN2


DFUTLP  ld (TEMP2),hl
    ld (TEMP),bc
DFUTL2  ld a,(hl)
    cp 1            ;Track a deformatter ?
    jp nz,DFNEXTUT
    ld a,(NOWSIDE)
    ld d,a
    call UNFORMAT
    jr c,DFNEXTUT       ;Carry, tout va bien.
    ld ix,TXTERRFORMAT  ;Error disc. retry ignore or Cancel
    ld hl,DFUTRETRY
    ld de,0
    ld bc,PRGENDFAIL ;PRGEND
    jp RETRYIGNORECANCEL
DFUTRETRY ld hl,(TEMP2)
    ld bc,(TEMP)
    jr DFUTL2

DFNEXTUT
    ld hl,(TEMP2)
    ld bc,(TEMP)
    inc hl
    inc c
    djnz DFUTLP

    ret


    
DSKFIN2
    call CLEARBAS

    ld hl,TXTFINISH
    call PHRASE


PRGEND
;   ld hl,ENDDRIVE  ;ùa ou ùb a la fin.
;   call #bcd4
;   ld a,1
;   call #1B

    call FDCOFF

    call CPCB_SendEndCommand

ENDLESS call SPACE
    jp 0

;Fin, mais le DSK est mal transfere (erreur disc).
PRGENDFAIL
    call CLEARBAS
    ld hl,TXTFINERR
    call PHRASE
    jr PRGEND


;   ld hl,$+6   ;Remets le systeme avant de partir
;   jp STARTSYS
;   di
;   exx
;CRAPO  ld bc,0
;   exx

;   ld bc,#7fc0
;   out (c),c
;   ld bc,#7f8d
;   out (c),c

;   ret

;ENDDRIVE defb 0



BADDSKHEADER ld hl,TXTBADHEADER     ;Bad DSK header. Unknown format.
BSKHPHR ;call GETFNT        ;Au cas ou on ne l'a pas deja fait (deja prg).
    call PHRASE
    jr PRGEND
READFAILCRITIC ld hl,TXTREADFAILCRITIC  ;Read fail critique. Ne propose pas de retry.
    jr BSKHPHR
ERROREOFMET ld hl,TXTEOFMET     ;EOF Met critique.
    jr BSKHPHR

;Erreur paramatres. Liees au systeme.
BADNAME ld hl,TXTBADNAME        ;Nom filename incorrect.
    jp ERRPARAM
BADDRIVE ld hl,TXTBADDRIVE  ;mauvais lecteurs
    jp ERRPARAM
BADHEAD ld hl,TXTBADHEAD    ;mauvais dest head
    jp ERRPARAM

;TXTWARNING defb 1,4,"WARNING ! All data on destination will be erased.",10,10,0
TXTWRITEDSK defb 1,1,"WriteDSK V1.2 by Targhan/Arkos",10,0
TXTSOULIGNE defb "----------------------------",0

TXTDEBUT defb 1,4,"Transfering DSK from "
TXTDEBU2 defb "X to "
TXTDEBU3 defb "X Head "
TXTDEBU4 defb "X...",10,10,0

YINT equ 9
TXTITF1 defb 1,YINT,"               TR SD ID SZ  Info      TR SD ID SZ  Info      TR SD ID SZ  Info",10,0
TXTITF2 defb "               -- -- -- -- ------     -- -- -- -- ------     -- -- -- -- ------",10,0
TXTITFTRK defb 1,YINT+3,"Track :",10,0
TXTITFSIDE defb "Side :",10,0
TXTITFGAP defb "Gap :    &",10,0
TXTITFFILL defb "Filler : &",10,10,0
TXTITFNBS defb "Nb Scts :",10,0
TXTITSSIZE defb "Size :     ",0

TXTFORMATEXT defb 1,6,"Extended DSK Format.",10,0
TXTFORMATSTD defb 1,6,"MV-DSK Format.",10,0
TXTBADHEADER defb 1,6,"DSK Format unknown.",10,0
TXTDSKTRACKS defb 1,6,2,28,"Nb Tracks : "
TXTDSKTRACK2 defb "00.    ",0
;TXTDSKSIDES  defb "    Nb Sides = "
;TXTDSKSIDE2 defb "0.",10,0
TXTSINGLESIDED defb 1,6,2,50,"Single sided.",10,0
TXTDOUBLESIDED defb 1,6,2,50,"Double sided.",10,0
TXTNOCPCB defb 1,22,"** CPC Booster not detected ** Please connect it.",0
TXTPCCOMFailed defb 1,22,"** PC Not ready. Press Space to retry. **",0
TXTINPUTFILENOK defb 1,22,"** Couldn't open the PC file. **",0
TXTTRACK defb 1,24,"Track "
TXTTRAC2 defb "XX Side "
TXTTRAC3 defb "X...                  ",0
TXTTRACKOK defb 1,24,2,19,"Written.",10,0

YERR equ 23 ;Y des messages d'erreur

TXTBADTRACK defb 1,YERR,"Format not supported.",10,0
TXTERROR defb 1,YERR,"Disc Error. Retry,Ignore,Cancel ?",10,0

;TXTREADFAIL defb "Read Fail. Retry, Cancel ?",10,0
TXTERRFORMAT defb 1,YERR,"Format failed. Retry, Cancel ?",10,0
TXTREADFAILCRITIC defb 1,YERR,"Read Fail.",10,0
TXTBADFORMAT defb 1,YERR,"Bad DOS format. Retry, Cancel?",10,0
TXTNOTFOUND defb 1,YERR,"DOS file not found.",10,0
TXTEOFMET defb 1,YERR,"Unexpected End Of File !",10,0

TXTFINISH defb 1,22,"DSK Transfered !",10,0
TXTFINERR defb 1,22,"DSK Transfer failed.",10,0

;TXTOPENING defb "Opening the PC file...",10,0



TXTINSERTSRC defb 1,22,"Insert PC-disc DSK in "
TXTINSERTSR2 defb "X and press Space.",10,0

TXTINSERTCPCB defb 1,22,"Press Space to begin the transfert from PC...",10,0

TXTINSERTDEST defb 1,22,"Insert DESTINATION disc in "
TXTINSERTDES2 defb "X and press Space.",10,0

TXTBADNAME defb "Bad filename.",13,10,0
TXTBADDRIVE defb "Unkown drive letter.",13,10,0
TXTBADHEAD defb "Head number should be 1 or null.",13,10,0
TXTBADPARAM defb "Format :",10,13,124,"WDSK,",34,"DSKName",34,",",34,"[SRCdrvDESTdrv][1]",34,13,10
        defb 124,"DIRDOS,[",34,"drive",34,"]",0

TXTCAT  defb "Catalogue on DOS Drive "
TXTCA2  defb "X :",10,10,0

TXTREADPCDSK defb 1,22,"Reading DSK...",10,0
TXTBUFFER defb 1,22,2,60,"Buffer : "
TXTBUFFE2 defb "XX/"
TXTBUFFE3 defb "96",10,0

TXTUNFORMAT defb 1,24,"Unformatting Track "
TXTUNFORMA2 defb "XX Side "
TXTUNFORMA3 defb "X ...",10,0

CATSPACE defb "Space...",13,0


PHRASE ;ld a,(GETFNT+1)    ;si fonte non cree on utilise BB5A (utile pour CAT)
    ld a,(USEBB5A)
    or a
    jr z,PHRNOSYS

    ld (ADTXT),hl
    ld hl,$+6
    jp STARTSYS
    ld hl,(ADTXT)
PHRSALP ld a,(hl)
    inc hl
    or a
    jr z,PHRSEND
    cp 1
    jr z,PHRSPOSXY
    cp 2
    jr z,PHRSPOSXY
    cp 10       ;saut de ligne
    jr z,PHRSA10
    call #bb5a
    jr PHRSALP

PHRSPOSXY inc hl    ;on ignore les X et Y.
    jr PHRSALP
PHRSA10 ld a,13
    call #bb5a
    ld a,10
    call #bb5a
    jr PHRSALP
PHRSEND ld hl,$+6
    jp STOPSYS
    ret

PHRNOSYS
    ld (ADTXT),hl
PHRALP  ld a,(hl)
    or a
    ret z
    cp 1
    jr z,PHRPOSY
    cp 2
    jr z,PHRPOSX
    cp 10       ;saut de ligne
    jr z,PHRA10
    call AFFLETTRE
PHRAL2  inc hl
    jr PHRALP
;Setting de Y.
PHRPOSY inc hl
    ld a,(hl)
    call SETAFFY
    inc hl
    jr PHRALP
;Setting de X.
PHRPOSX inc hl
    ld a,(hl)
    call SETAFFX
    inc hl
    jr PHRALP

;Saut de ligne, on recupere valeur de debut de ligne et on passe a la suivante.
PHRA10  push hl
    ld hl,(ADECRLINE)

    ld a,(ADTXTNOLINE)
    inc a
;   cp 26
;   jr nz,PHRA102
;Ecran du bas atteint, on scroll vers le haut.
;   ld hl,#c050
;   ld de,#c000
;   call PHRSCR
;   ld hl,#c850
;   ld de,#c800
;   call PHRSCR
;   ld hl,#d050
;   ld de,#d000
;   call PHRSCR
;   ld hl,#d850
;   ld de,#d800
;   call PHRSCR
;   ld hl,#e050
;   ld de,#e000
;   call PHRSCR
;   ld hl,#e850
;   ld de,#e800
;   call PHRSCR
;   ld hl,#f050
;   ld de,#f000
;   call PHRSCR
;   ld hl,#f850
;   ld de,#f800
;   call PHRSCR 

;   ld hl,24*#50+#c000
;   ld a,8
;
;PHREFF push hl
;   ld e,l
;   ld d,h
;   inc de
;   ld (hl),0
;   ld bc,#4f
;   ldir
;
;   pop hl
;   ld bc,#800
;   add hl,bc
;   dec a
;   jr nz,PHREFF



;   ld hl,(ADECRLINE)
;   jr PHRA10F
    
PHRA102 ld (ADTXTNOLINE),a
    ld de,#50
    add hl,de
    ld (ADECRLINE),hl
PHRA10F ld (ADECRTXT),hl
    pop hl
    jp PHRAL2

PHRSCR  ld bc,#800
    ldir
    ret




;Positionne le curseur graphique.
;A=no ligne (1-25)
SETAFFY push hl
    ld (ADTXTNOLINE),a
    ld hl,#c000-#50
    ld de,#50
PHRPYLP add hl,de
    dec a
    jr nz,PHRPYLP
    ld (ADECRTXT),hl
    ld (ADECRLINE),hl
    pop hl
    ret

;Mets un X au curseur graphique.
;Attention, il faut le faire APRES avoir fait un setY !
;A=X (0-79)
SETAFFX push hl
    ld hl,(ADECRTXT)
    ld e,a
    ld d,0
    add hl,de
    ld (ADECRTXT),hl
    ld (ADECRLINE),hl
    pop hl
    ret



;Affiche une lettre.
;A=lettre.
;Sauver HL
AFFLETTRE
    push hl
    sub 32
    ld l,a
    ld h,0
    add hl,hl
    add hl,hl
    add hl,hl
    ld de,#3900 ;FONTE
    add hl,de
;
    ld bc,#7f8a     ;ouvre ROM basse systeme
    out (c),c

    ld de,(ADECRTXT)
    ld b,8

AFLLP   ld a,(hl)
    ld (de),a
    ld a,d
    add a,8
    ld d,a
    inc hl
    djnz AFLLP

    ld hl,(ADECRTXT)
    inc hl
    ld (ADECRTXT),hl

    ld bc,#7f8e
    out (c),c

    pop hl
    ret




ADECRTXT defw #c000
ADECRLINE defw #c000    ;Adresse ou on sauve l'adr du debut de ligne.
ADTXTNOLINE defb 1  ;No ligne, utile pour savoir quand scroller.


;A=nb
;RET=B=diz C=unite en decimal
NBTODEC
    ld bc,#ffff
    ld d,a
;
HTAD    inc b
    sub 10
    jr nc,HTAD
    add 10
    add a,"0"
    ld c,a
;
    ld a,b
    add a,"0"
    ld b,a
;
    ret



;Transforme un nb hexa non signe 8 bits en ascii
;a=nb
;sortie=b=diz c=unite
NBTOHEX
    push hl
    push de

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

    pop de
    pop hl
    ret

HXTAB   defb "0123456789ABCDEF"








;Marque la piste comme 'traitee' pour pas qu'on la deformatte !
SETTRACKASTREATED
    ld hl,LSTTRACKSFORMATTED    ;Il faut pointer la bonne liste selon la SIDE traitee !
    ld a,(NOWSIDE)
    or a
    jr z,GRTS0
    ld hl,LSTTRACKSFORMATTED2

GRTS0   ld a,(NOWTRACK)
    ld e,a
    ld d,0
    add hl,de
    ld (hl),d
    ret








;Place un octet dans le buffer principal, et fait avancer le pointeur.
;Ouvre bank, et referme ensuite.
;La fin du buffer n'est pas testee ici, car on s'arrete toujours bien avant,
;quand le buffer n'est pas assez grand pour contenir une piste entiere.
;A=octet
PUTBYTEBUFMAIN
    push hl
    push de
    push bc

    ld c,a

    ld b,#7f
    ld a,(BKBUFMAIN)
    out (c),a

    ld hl,(PTBUFMAIN)
    ld (hl),c

    ld c,a
    call INCPTBUFMAIN
    ld a,c
    ld (PTBUFMAIN),hl
    ld (BKBUFMAIN),a

    ld bc,#7fc0
    out (c),c
    pop bc
    pop de
    pop hl
    ret


;Fais avancer le pointeur BUFMAIN, ou un autre (genre, celui qui lit une track pour le mettre dans
;BUFWRITE). Prends en compte la fin du buffer en mem centrale et jump en bank.
;HL=adresse pointee
;C=Bank (c0c4c5c6c7)
;RET=HL/C actualises
INCPTBUFMAIN
    inc hl

    ld a,c
    cp #c0
    jr z,PBBMC0

    ld a,h
    cp #80
    ret nz
    ld hl,#4000     ;Si fin bank atteinte, passe a bank suivante
    inc c
    ret

PBBMC0  ld a,l
    ;cp BUFMMAX AND 255 ; XXX Original Winape  code
    cp BUFMMAX & 255 ; XXX Original Winape  code
    ret nz
    ld a,h
    cp BUFMMAX/256  ; XXX doubt it works with vasm
    ret nz

    ld hl,#4000     ;Si oui, on passe en bank.
    ld c,#c4

    ret












;Lis DES octets du DSK.
;Carry=1=ok  0=pas ok.A=0=read fail 1=EOF..
;HL=ou ranger les octets
;BC=nb d'octets a lire
READBYTESFROMDSK
    ld a,(USERDRIVES)
    cp "C"
    jr nz,READBYTESFROMDSKLoop
    ex de,hl    ;DE=Destination
    ld l,c      ;HL=Nombre d'octets a recevoir
    ld h,b
    call CPCB_GetXBytes

    scf
    ret

READBYTESFROMDSKLoop
    call READBYTEFROMDSK
    ret nc
    ld (hl),a
    inc hl
    dec bc
    ld a,c
    or b
    jr nz,READBYTESFROMDSKLoop
    scf
    ret








;***********************************************
;Routine interpretation DSK.
;***********************************************





;Interprete le Header prealablement chargé d'un DSK.
;Mets a jour tous les flags concernant le DSK.
;IX=adr header
;RET=Carry=1=ok 0=format non reconnu
INTERPRET_DSK_HEADER

    defb #dd 
  ld e,l       ;Extended ou Standard ?
    defb #dd 
  ld d,h
    ld hl,STREXTENDED
    ld de,BUFWRITE
    ld bc,8
    call CPTSTRINGS
    jr c,IDHEXT

    defb #dd 
  ld e,l
    defb #dd 
  ld d,h
    ld hl,STRSTANDARD
    ld de,BUFWRITE
    ld bc,8
    call CPTSTRINGS
    jr nc,RESNOTOK

IDHSTD  xor a
    jr IDHEX2

IDHEXT  ld a,1
IDHEX2  ld (DSKFORMAT),a

    ;ld ix,BUFWRITE

    ld a,(ix+#30)           ;Get Nb Tracks
    ld (DSKNBTRACKS),a
    dec a
    ld (DSKLASTTRACK),a     ;Pour detecter fin STANDARD.

    ld a,(ix+#31)           ;Get Nb Sides
    ld (DSKNBSIDES),a
    dec a               ;Pour detecter fin STANDARD. -1 car dans header,
    ld (DSKLASTSIDE),a      ;side = 1 ou 2.

;Remplit la table du poids fort des tailles de pistes.
;Si STANDARD, on lit la taille generale SIZETRACK
    ld a,(DSKFORMAT)
    or a
    jr nz,IDHTSE
    ld l,(ix+#32)           ;recupere SIZETRACK si format STANDARD.
    ld h,(ix+#33)
    dec h               ;On DECREMENTE de #100 car le header est lu a part.
    ld (TRACKNBBYTESTOREAD),hl
    jr RESOK
IDHTSE
    ld de,#34           ;On se place sur taille des pistes.
    add ix,de
    push ix
    pop hl

    ld de,LSTTRACKSSIZE
    ld bc,NBMAXTRACKS*2
    ldir

;On scanne la LSTTRACKSIZE et on compte combien de pistes CODEES (=taille >0) le DSK contient
;On pourra ainsi obtenir une condition de fin valable.
;Si STANDARD, on place ce nb a 255, car la liste n'existe pas !

    ld a,(DSKFORMAT)
    cp 1
    jr z,IDHCPVD
    
    ld a,255            ;DSK STANDARD.
    ld (DSKNBPISTESCODEES),a
    jr RESOK

IDHCPVD
    ld hl,LSTTRACKSSIZE
    ld bc,NBMAXTRACKS*2*256+0   ;B=boucle C=nb pistes codees.
;
IDHCPVL ld a,(hl)
    inc hl
    or a
    jr z,IDHCPVC
    inc c
IDHCPVC djnz IDHCPVL
    ld a,c
    ld (DSKNBPISTESCODEES),a
;
    jr RESOK

STREXTENDED defb "EXTENDED"
STRSTANDARD defb "MV - CPC"

;Retour generiques. Carry=ok.
RESOK   scf
    ret
RESNOTOK or a
    ret



;Compare deux chaines
;HL=chaine 1
;DE=chaine 2
;BC=taille (>0)
;RETOUR=Carry=1=egales
CPTSTRINGS

CPTSTRLP ld a,(de)
    cp (hl)
    jr nz,RESNOTOK
    inc hl
    inc de
    dec bc
    ld a,c
    or b
    jr nz,CPTSTRLP
    jr RESOK





;Interprete Header d'une PISTE, remplit le MAINBUFFER avec les infos track+sects de cette track.
;IX=pointe sur header
;RET=Carry=1=ok/erreur format 0=eof
READ_DSK_TRACK_HEADER

    defb #dd 
  ld e,l       ;Track-Info trouve ? Si non, alors fin de DSK.
    defb #dd 
  ld d,h

    ld hl,STRTRACKINFO
;   ld de,BUFWRITE
    ld bc,10
    call CPTSTRINGS
    jr nc,RESNOTOK

;Lis les infos pistes et les place dans le gros buffer
;Db tracknumber,   Side (1/2),   Sector size,   Nb sectors,   Gap#3,   Filler Byte.

;   ld ix,BUFWRITE

    ld a,(ix+#10)           ;get TrackNumber
    ld (NOWTRACK),a
    call PUTBYTEBUFMAIN
    ld a,(FORCEHEAD)        ;get HEAD. Si Forcage alors on force celle qu'on a mis en RSX
    or a
    jr z,RDTHNOFORC
    ld a,(DESTHEAD)
    jr RDTHFORCE
RDTHNOFORC ld a,(ix+#11)        ;Pas de forcage de HEAD.
RDTHFORCE ld (NOWSIDE),a
    call PUTBYTEBUFMAIN
    ;ld a,(ix+#14)          ;get Sector size. On va ecraser cette valeur avec la nouvelle
;***** A FAIRE, scanner sect le plus grand !
    ld a,(ix+#18+3)
    ld (TRACKSECTSSIZE),a       ;on n'utilise PLUS cette info pour avoir le SECTOR SIZE ! Pas fiable
                    ;On se sert plutot des IDs lecteurs.
    call PUTBYTEBUFMAIN
    ld a,(ix+#15)           ;get Nb sectors
    ld (TRACKNBSECTS),a
    call PUTBYTEBUFMAIN

;AVANT de coder le GAP, on regarde si on doit le corriger en regardant dans notre table de gap
;en fct du NBsects et de leur taille ! Si le gap3 du dsk est superieur, on le corrige.
    ld a,(TRACKSECTSSIZE)
    ld b,a
    ld a,(TRACKNBSECTS)
    ld c,a
    ld d,(ix+#16)           ;get gap#3
    call CORRECTGAP
;   ld a,(ix+#16)           ;ecrit le gap, corrige ou non.
    call PUTBYTEBUFMAIN
    ld a,(ix+#17)           ;get Filler byte
    call PUTBYTEBUFMAIN


;Lis la Sectors info List et remplis. On teste la validite des pistes (taille 6?)
;db TrackNumber,    Side,   SectorID,   Sector size,  FDC R1,  FDC R2,  DW ACTUAL DT LGT
    ld de,#18
    add ix,de

    ld c,0      ;Taille totale des secteurs
    ld h,0      ;h=Taille du PLUS GRAND secteur. Permet de setter SECTOR SIZE dans le header TRACK
    ;ld a,(TRACKSECTSSIZE)
    ;ld l,a
    ;ld a,(ix+3)    ;On prends la taille du 1er secteur pour le comparer aux autres
    ;ld (TRACKSECTSSIZE),a  ;Cette taille est la SECTOR SIZE du 1er secteur !
    ;ld l,a
    ld a,(TRACKNBSECTS)
    ld b,a

RDTHLP  ld a,(ix+0) ;get TrackNumber
    call PUTBYTEBUFMAIN
    ld a,(ix+1) ;get Side
    call PUTBYTEBUFMAIN
    ld a,(ix+2) ;get SectorID
    call PUTBYTEBUFMAIN
    ld a,(ix+3) ;get Sector size
;   cp 6
;   jr z,RDRH6
    cp h        ;SECTsectsize < thisSECTsize alors SECTsectsize=thisSECTsize
    jr c,RDTHSS
;           ;Attention, thisSECTsize ne devient pas la reference si le checksum est foireux !
    bit 5,(ix+4)    ;Checksum foireux sur ST1 ?
    jr nz,RDTHSS
    bit 5,(ix+5)    ;Checksum foireux sur ST2 ?
    jr nz,RDTHSS
    ld h,a      ;Checksum ok.
RDTHSS  ld d,a
    ld l,1      ;taille 0=1*128
    sub 1
    jr c,RDTHS2
    ld l,2      ;t1=2*128
    sub 1
    jr c,RDTHS2
    ld l,4      ;t2*4*128
    sub 1
    jr c,RDTHS2
    ld l,8      ;t3*8*128
    sub 1
    jr c,RDTHS2
    ld l,16     ;t4=16*128
    sub 1
    jr c,RDTHS2
    ld l,32     ;t5=32*128
    sub 1
    jr c,RDTHS2
    ld l,64
RDTHS2  ld a,l
    add a,c     ;c=c+a +1 pour la multiplication avec #80.
    ld c,a
    ld a,d
    call PUTBYTEBUFMAIN

    ld a,(ix+4) ;get FDC R1
    call PUTBYTEBUFMAIN
    ld a,(ix+5) ;get FDC R2
    call PUTBYTEBUFMAIN
    ld a,(ix+6) ;get Actual Data Length LB
    call PUTBYTEBUFMAIN
    ld a,(ix+7) ;get Actual Data Length HB
    call PUTBYTEBUFMAIN

;
    ld de,8
    add ix,de
    djnz RDTHLP

    ld l,1
    ld a,h          ;Le format est bon ? Si =6 alors stoppe !
    cp 6
    jr nz,RDTGF
    ld l,0
RDTGF   ld a,l
    ld (TRACKGOODFORMAT),a
    call PUTBYTEBUFMAIN



;On cherche TRACKNBBYTESTOREAD dans table des tailles pistes.
    ld a,(DSKFORMAT)    ;Si le format est STANDARD, pas la peine de setter TRACKNBBYTESTOREAD car
    or a            ;il a deja ete calcule et est tjs le meme !
    jp z,RESOK

    ld a,(NOWTRACK)
    ld l,a
    ld h,0
    ld a,(DSKNBSIDES)
    cp 2
    jr nz,RTDSINGLE
    add hl,hl       ;Si double face, on *2 pour bien tomber sur une valeur entrelacee dans table.
    ld a,(NOWSIDE)
    or a
    jr z,RTDSIDE0
    inc hl          ;Si on est sur side 2, on +1 pour aller sur octet entrelacé
RTDSINGLE
RTDSIDE0 ld de,LSTTRACKSSIZE
    add hl,de
    ld h,(hl)
    dec h           ;get poids fort de size track-1 car elle contient le #100 du header !
    ld l,0
    ld (TRACKNBBYTESTOREAD),hl
    jp RESOK

STRTRACKINFO defb "Track-Info"


;Corrige le gap en fct de sectsize et du nb sect dans la piste. Si gap<gap de table, on corrige.
;b=sectsize
;c=nbsects
;d=gap dsk
;RET=A=gap a coder
CORRECTGAP
    ld hl,GAPTABLE
CGLOOP  ld a,(hl)
    inc hl
    cp #ff      ;#ff=fin table. Si on arrive la, on a rien a corriger.
    jr z,CGNOCORR
    cp b        ;sectsize correspondante ?
    jr nz,CGSKIP2
    
    ld a,(hl)   ;nbsects pareil ?
    cp c
    jr nz,CGSKIP2
    inc hl

    ld a,(hl)   ;get gap
    cp d        ;si gapdsk > gap alors gapdsk=gap
    ret c
CGNOCORR ld a,d     ;si nb pas dans notre table, on verifie qd meme qu'il n'est pas en dessous
    cp LOWESTGAP    ;d'un certain nombre.
    ret nc
    ld a,LOWESTGAP
    ret

CGSKIP2 inc hl
    inc hl
    jr CGLOOP

    ret



;Initialise l'affichage des infos ID (au niveau variables).
INITAFFIDSECT
    xor a
    ld (AFFNOSECT),a
    ld a,15
    ld (AFFADDXSECT),a

;   call CLEARITF
    ret


;Affiche dans le tableau les infos ID sect.
;IX=pointe sur info sect.
AFFIDSECT
    push hl
    push de
    push bc

    ld a,(AFFNOSECT)
    add a,YINT+2
    call SETAFFY
    ld a,(AFFADDXSECT)
    call SETAFFX

;Affiche Track
    ld a,(ix+0)
    call NBTOHEX
    ld a,b
    ld (INFOTOAFF),a
    ld a,c
    ld (INFOTOAFF+1),a

;Affiche Side
    ld a,(ix+1)
    call NBTODEC
    ld a,c
    ld (INFOTOAFF+4),a

;Affiche SectID
    ld a,(ix+2)
    call NBTOHEX
    ld a,b
    ld (INFOTOAFF+6),a
    ld a,c
    ld (INFOTOAFF+7),a

;Affiche Size
    ld a,(ix+3)
    call NBTODEC
    ld a,c
    ld (INFOTOAFF+10),a

;Secteur Erased ?
    ld hl,INFONOTHING
    bit 6,(ix+5)
    jr z,AFFISNOER
    ld hl,INFOERASED
AFFISNOER ld de,INFOTOAF2
    ldi
    ldi
    ldi

;Bad Checksum ?
    ld hl,INFOBADCHECK
    bit 5,(ix+4)
    jr nz,AFFISNOBC
    bit 5,(ix+5)
    jr nz,AFFISNOBC
    ld hl,INFONOTHING
AFFISNOBC ld de,INFOTOAF3
    ldi
    ldi
    ldi


    ld hl,INFOTOAFF
    call PHRASE

    ld a,(AFFNOSECT)
    inc a
    cp 10           ;Nb sects par colonne
    jr nz,AFFISNONC
    ld a,(AFFADDXSECT)  ;nouvelle colonne
    add a,23        ;ecartement colonne
    ld (AFFADDXSECT),a
    xor a
AFFISNONC ld (AFFNOSECT),a

    pop bc
    pop de
    pop hl
    ret

AFFNOSECT defb 0    ;Numero du secteur en cours (0-x). Juste pour affichage. Cyclique qd new colonne.
AFFADDXSECT defb 0  ;Offset en X que l'on add selon la colonne du secteur.
INFOTOAFF defb "XX  X XX  X "   ;track, skide, id, size
INFOTOAF2 defb "YYY "   ;erased ?
INFOTOAF3 defb "YYY",0  ;bad checksum ?
INFOERASED defb "ERA"
INFOBADCHECK defb "CKS"
INFONOTHING defb "   "


;Affiche les infos de la piste a gauche dans l'interface.
;IX pointe sur info piste, format BUFFMAIN (+0 = no track)
AFFINFOTRACK
    ld a,YINT+3
    call SETAFFY
    ld a,10
    call SETAFFX

    ld a,(ix+0) ;track
    call NBTODEC
    ld a,b
    ld (IINTTRACK),a
    ld a,c
    ld (IINTTRACK+1),a

    ld a,(ix+1) ;side
    add a,"0"
    ld (IINTSIDE),a

    ld a,(ix+2) ;sectsize
    add a,"0"
    ld (IINTSIZE),a

    ld a,(ix+3) ;nbsects
    call NBTODEC
    ld a,b
    ld (IINTNBSECTS),a
    ld a,c
    ld (IINTNBSECTS+1),a

    ld a,(ix+4) ;gap
    call NBTOHEX
    ld a,b
    ld (IINTGAP),a
    ld a,c
    ld (IINTGAP+1),a

    ld a,(ix+5) ;fill
    call NBTOHEX
    ld a,b
    ld (IINTFILL),a
    ld a,c
    ld (IINTFILL+1),a

    ld hl,IINTTRACK
    call PHRASE

    ret

IINTTRACK defb "XX",10," "
IINTSIDE defb "X",10
IINTGAP defb "XX",10
IINTFILL defb "XX",10,10
IINTNBSECTS defb "XX",10," "
IINTSIZE defb "X",10
    defb 0



;Ecrit une piste sur la disquette.
;IX=header track/sects+datas selon format decrit en haut du source.
;RET=Carry=1=ok Carry=0=erreur (A=0=piste non valide. 1=erreur disc).
;   Format buffer MAIN =

;   Db TrackNumber,   Side (0/1),   Sector size,   Nb sectors,   Gap#3,   Filler Byte

;   Pour chaque secteur =
;   [ db TrackNumber,    Side,   SectorID,   Sector size, FDC R1, FDC R2, ADL LB/HB ] * nbsects
;   +DB GOODTRACK ? (1=ok 0=non)
DSK_WRITE_TRACK
    call INITAFFIDSECT
    call CLEARITF

    ld a,(ix+0) ;get track number
    ld (WTTRACK),a


;D'abord on regarde si la track est good.
    defb #dd 
  ld e,l
    defb #dd 
  ld d,h
    ex de,hl
    ld de,3
    add hl,de
    ld b,(hl)   ;get Nb sectors
    add hl,de
    ld (WTSECTIDS),hl
    ld de,8     ;On va a la fin de la liste des secteurs.
DWTLIS  add hl,de
    djnz DWTLIS
;
    ld a,(hl)
    or a
    jp z,RESNOTOK   ;Retour si piste non correcte. Pas d'erreur signalee.
    inc hl
        ld a,(USERDRIVES)       ;**** SI CPCB alors pointeur sur data=Debut BufWrite
        cp "C"
        jr nz,DWTSWD
        ld hl,BUFWRITECPCB      ;BUFWRITE ??????????
DWTSWD  ld (WTTRACKDATA),hl
;

    ld a,(ix+1) ;side, forcee ou non.
    ld (WTSIDE),a
    ld a,(ix+2) ;sectsize. Si STD, utile pour savoir intervalle entre chaque secteur.
    ld (WTSIZE),a
    ld a,(ix+3) ;nbsects
    ld (WTNBSECTS),a
    ld a,(ix+4) ;gap
    ld (WTGAP),a
    ld a,(ix+5) ;fill
    ld (WTFILL),a


    call AFFINFOTRACK

;Affiche les infos sects
    push ix
    ld b,(ix+3)
    ld de,6
    add ix,de
DWTAFFLP push bc
    call AFFIDSECT
    pop bc
    ld de,8
    add ix,de
    djnz DWTAFFLP
    pop ix


;Scanne info sects, on regarde si certains IDs sects sont utilises 2x. (format 5kb3 et the demo)
;Dans le meme temps, on recherche d'un sect ID non utilise.
;On fait 256 passes, on s'arrete des qu'on remarque qu'un sect est present + d'une fois.
    push ix
    ld c,0  ;ID recherché
    xor a
    ld (ISSAMESECTUSED),a

DWTSSLP ld ix,(WTSECTIDS)
    ld a,(WTNBSECTS)
    ld b,a
    ld h,0  ;nb it de ce sect dans la piste.

DWTSSS  ld a,(ix+2)
    cp c
    jr nz,DWTSS2
    inc h       ;On vient de trouver l'id de ce secteur
DWTSS2  ld de,8
    add ix,de
    djnz DWTSSS
;
    ld a,h
    or a
    jr z,DWTSS4
    cp 1
    jr z,DWTSS4
    ld a,1      ;On declare le fait qu'un secteur ID est utilise plus d'une fois.
    ld (ISSAMESECTUSED),a
    jr DWTSSF
DWTSS4  dec c       ;Ok, ce sect n'apparait pas plus d'une fois.
    jr nz,DWTSSLP

DWTSSF  pop ix


;
;En avant ! On coupe le systeme
    ;ld hl,$+6
    ;jp STOPSYS

    ;call FDCON

;FORMATAGE
    ld a,(DESTLECT)
    call CHLECT
;   ld a,(DESTHEAD)
;   call CHHEAD
FORMRETRY
    call FORMAT ;IX pointe sur les donnees header track+sects
    or a
    jr z,FRMOK
    ld ix,TXTERRFORMAT
    ld hl,FORMRETRY
    ld de,0
    ld bc,PRGENDFAIL ;PRGEND
    jp RETRYIGNORECANCEL

FRMOK
;

;On ecrit les secteurs. Si ISSAMESECTUSED a 1 alors =
;1 On charge le un secteur bidon (erreur, normal)
;2 On fait X READ ID, X++ a chaque fois. Si X=0 on fait rien.
;3 On ecrit le bon secteur
;Retour a 1.


    xor a
    ld (WTINDEX+1),a



    ld ix,(WTTRACKDATA)
    ld iy,(WTSECTIDS)
    ld a,(WTNBSECTS)
WTSLP   push af

    ld a,(ISSAMESECTUSED)
    or a
    jr z,WRNORMAL
    push ix
    push iy

;1 On charge un secteur bidon (erreur, normal, on s'en fout)
;A=piste actuelle
    ld a,(WTTRACK)
    call READFakeSECTOR


;2 On fait X READ ID, X++ a chaque fois. Si X=0 on fait rien.
WTINDEX ld a,0
    or a
    jr z,WTINDEF
WTINDE2 push af
    call SCANID
    pop af
    dec a
    jr nz,WTINDE2

WTINDEF ld hl,WTINDEX+1
    inc (hl)


    pop iy
    pop ix
WRNORMAL

    ld a,(WTGAP)
    ld h,a
    ld a,(WTSIDE)
    ld l,a
    ld a,(WTTRACK)
    call WRITESECT
;
    ld a,(DSKFORMAT)
    or a
    jr z,WTSSTD
    ld ix,(WTTRACKDATA)
    ld e,(iy+6)         ;get ACTUAL DATA LENGTH dans secteur ID.
    ld d,(iy+7)
                    ;Si EXTENDED, le secteur suivant se trouve obligatoirement
    add ix,de           ;ACTUAL DATA LENGTH octets plus loin.
    ld (WTTRACKDATA),ix
    jr WTSLPNEXT
WTSSTD  ld a,(WTSIZE)           ;Si STD, le secteur suivant se trouve a intervalle regulier du
    ld hl,#80           ;plus grand secteur de la piste.
    or a
    jr z,WTSST3
WTSST2  add hl,hl
    dec a
    jr nz,WTSST2
WTSST3  ld ix,(WTTRACKDATA)
    ex de,hl
    add ix,de
    ld (WTTRACKDATA),ix

WTSLPNEXT
    ld de,8     ;On passe sur les IDs du secteur suivant.
    add iy,de

    pop af
    dec a
    jr nz,WTSLP
    


;   ld hl,$+6
;   jp STARTSYS
;

    jp RESOK


;Lis secteur bidon
;A=Piste actuelle
READFakeSECTOR
;   ld a,(NOWTRACK)
    ld b,#ff
    ld c,0
    ld d,#fa
    ld e,a
    ld hl,#c000
    call READSECT
    ret



;Remplit de #ff le buffer principal. D'abord la ram centrale, puis les banks.
;Clear aussi la liste des pointeurs sur tracks en mem
CLEARBUFMAIN
    ld hl,BUFMAIN
    ld de,BUFMAIN+1
    ld bc,BUFMMAX-BUFMAIN-1
    ld (hl),0
    ldir

    ld hl,LSTPTTRACKSINMEM
    ld de,LSTPTTRACKSINMEM+1
    ld bc,LSTPTTRACKSINME2-LSTPTTRACKSINMEM-1
    ld (hl),0
    ldir

    ld a,(IS64K)
    or a
    jr nz,CBM64

    ld bc,#7fc4
    call CBMCLB
    ld bc,#7fc5
    call CBMCLB
    ld bc,#7fc6
    call CBMCLB
    ld bc,#7fc7
    call CBMCLB
CBM64   ld bc,#7fc0
    out (c),c
    ret
CBMCLB  out (c),c
    ld hl,#4000
    ld de,#4001
    ld bc,#3fff
    ld (hl),l
    ldir
    ret













;Copie les datas des sects d'une track dans le buffer principal.
;UTILISE TRACKNBBYTESTOREAD.
;SI TRACKGOODFORMAT=0, on avance mais on n'ecrit pas ! Permets d'avancer dans le DSK.
;IX=datas des sects
PUT_DSK_TRACK_IN_BUFFMAIN
    ld a,(USERDRIVES)
    cp "C"
    jr nz,PDTIBNormal
;Comportement CPCB. On lit les octets en blocs, que l'on place dans BUFWRITE. Puis on copie les octets
;dans maniere non lineaire dans BUFFMAIN.
    ld hl,(TRACKNBBYTESTOREAD)
    ld de,BUFWRITECPCB      ;BUFWRITE ???
    call CPCB_GetXBytes

;   ld hl,BUFWRITE
;   ld bc,(TRACKNBBYTESTOREAD)
;LOKASS ld a,(hl)
;   call PUTBYTEBUFMAIN
;   inc hl
;   dec bc
;   ld a,c
;   or b
;   jr nz,LOKASS
    ret


;Comportement 'normal', sans CPCBooster. On lit les octets un un, peut pratique si CPCB.
PDTIBNormal
    ld bc,(TRACKNBBYTESTOREAD)
    ld a,(TRACKGOODFORMAT)
    ld h,a
PDTIBLP call READBYTEFROMDSK        ;Lis UN octet du DSK
    bit 0,h
    call nz,PUTBYTEBUFMAIN      ;si Track GOOD alors on ecrit dans le mainbuffer.
    dec bc
    ld a,c
    or b
    jr nz,PDTIBLP
    ret





;Attends qu'espace soit pressee (teste qu'elle soit non pressee d'abord).
SPACE
    ld a,5+64
    call ROUTOUCH
    cp %11111111
    jr nz,SPACE

SPAC2   
    call ISRESET

    ld a,5+64
    call ROUTOUCH
    cp %01111111
    jr nz,SPAC2
    ret

;Si ctrl+shift+esc, reset
ISRESET
    ld a,2+64
    call ROUTOUCH
    cp %01011111
    ret nz

    ld a,8+64
    call ROUTOUCH
    cp %11111011
    jp z,0
    ret


;Gere le Retry/ignore/cancel
;ix=texte a afficher
;hl=go si Retry
;de=go si Ignore (0=pas le choix)
;bc=go si Cancel
RETRYIGNORECANCEL
    push hl
    push de
    push bc

    push ix

    call CLEARBAS

    pop hl
    call PHRASE

RICKEY
    ld a,6+64   ;R
    call ROUTOUCH
    cp %11111011
    jr z,RICRETRY

    ld a,7+64   ;C
    call ROUTOUCH
    cp %10111111
    jr z,RICCANCEL

    ld a,4+64   ;I
    call ROUTOUCH
    cp %11110111
    jr z,RICIGNORE

    jr RICKEY

RICRETRY call CLEARBAS
    pop de
    pop de
    pop hl
    jp (hl)
RICCANCEL call CLEARBAS
    pop hl
    pop bc
    pop bc
    jp (hl)
RICIGNORE call CLEARBAS
    pop bc
    pop de
    pop hl
    ld a,d
    or a
    jr nz,RICIGNOR2
    push hl
    push de
    push bc
    jr RICKEY
RICIGNOR2 ex de,hl
    jp (hl)


ROUTOUCH
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



STOPSYS
    di
    ld de,#c9fb
    ld (#38),de
    exx
    ld (SVSYSBC),bc
    exx
    ex af,af'
    push af
    pop de
    ld (SVSYSAF),de
    ex af,af'

    jp (hl)

STARTSYS ld (SASHL+1),hl
    ;ld sp,(SVSYSSP)
    ld hl,(SAVE38)
    ld (#38),hl
    ld ix,(SVSYSIX)
    ld iy,(SVSYSIY)
    exx
    ld bc,(SVSYSBC)
    exx
    ld hl,(SVSYSAF)
    push hl
    ex af,af'
    pop af
    ex af,af'
    ei
SASHL   jp 0






;Transforme le filename entre par l'utilisateur en champ utilisable place dans FILENAME
;HL=nom utilisateur
;A=nb lettres
;RET=Carry=1=ok
TREATFILENAME
    cp 13
    jp nc,RESNOTOK

    push hl
    ld hl,DOSFILENAME
    ld de,DOSFILENAME+1
    ld bc,11-1
    ld (hl),32
    ldir

    ld hl,TEMPFILENAME
    ld de,TEMPFILENAME+1
    ld bc,16-1
    ld (hl),32
    ldir

    ld c,a
    ld b,0
    pop hl
    ld de,TEMPFILENAME
    ldir

    ld hl,DOSFILENAME
    ld de,TEMPFILENAME
    ld b,8      ;nb lettres max
;Algo simple =
;- Si A>12 alors stop
;- On copie ce qu'on trouve directement dans la FILENAME (par la meme occasion,
;  si on trouve une minuscule, on passe en majuscule). Si fin de chaine, stop.
;  Si on trouve un point, on copie 3 octets max a moins de trouver fin de chaine.

TFNLP   ld a,(de)
    inc de
    cp '.'
    jr z,TFNPOINT
    cp "a"-1        ;Minuscule ?
    jr c,TFNLP2
    cp "z"+1
    jr nc,TFNLP2
    sub #20

TFNLP2  ld (hl),a
    inc hl
    djnz TFNLP

    ld a,(de)
    inc de
    cp "."
    jr z,TFNPOINT   

    jp RESOK

TFNPOINT ld hl,DOSFILENAMEEXT
    ld b,3
    jr TFNLP
    







;Sauve les RST, get les params...
INIT
;   ld hl,(#be7d)       ;Chope lecteur, pour le reactiver a la fin.
;   ld a,(hl)
;   add a,'A'+#80       ;+#80 car ca va etre utilise RSX.
;   ld (ENDDRIVE),a


    ld a,2
    call #bc0e


;Eteinds le lecteur AMSDOS.
    ld hl,#be67 ;Kill Ticker block de l'amsdos
    call #bcec
;   ld bc,#fa7e ;Coupe lecteur
    xor a
;   out (c),a
    ld (#be5f),a    ;Lecteur=off pour systeme
    ld l,a
    ld h,a
    ld (#be69),hl   ;Timer off=0.


    ld hl,(#38)
    ld (SAVE38),hl

    di
    ld (SVSYSIX),ix
    ld (SVSYSIY),iy
    exx
    ld (SVSYSBC),bc
    ex af,af'
    push af
    ex af,af'
    exx
    pop hl
    ld (SVSYSAF),hl
    ;ld (SVSYSSP),sp

    ld hl,$+6
    jp STOPSYS

    ld bc,#7f8e     ;ram haute et basse
    out (c),c

    ret





SVSYSBC defw 0
SVSYSAF defw 0
SVSYSIX defw 0
SVSYSIY defw 0
;SVSYSSP defw 0


WTTRACK defb 0      ;Track actuelle
WTSIDE  defb 0      ;0/1
WTSIZE  defb 0
WTNBSECTS defb 0
WTGAP   defb 0
WTFILL defb 0
WTTRACKDATA defw 0  ;Pointe sur data track
WTSECTIDS defw 0    ;Pointe sur liste IDs sects
;WTACTUALDATALENGTH defw 0 ;Actual Data Length d'un secteur codé en DSK. EXTENDED only. Pas sauve en mem
            ;car tire directement des IDS sects.


PTBUFMAIN defw 0        ;Pointe sur bufmain
BKBUFMAIN defb 0        ;#c0 ou #c4/5/6/7


;PTBUFMAINALT defw 0        ;meme chose mais utilise en temporaire (qd ecriture piste)
;BKBUFMAINALT defw 0


SAVE38 defw 0
SRCLECT defb 0      ;Lecteur source (DSK). 0,1,2,3
DESTLECT defb 0     ;Lecteur destination (disc CPC). 0,1,2,3
DESTHEAD defb 0     ;Tete destination (nouvelle option V1.1). 0,1.
FORCEHEAD defb 0    ;Si a 1 alors on a force la HEAD grace au param RSX.
DIFFDRIVE defb 0    ;1=different drive  0=meme drive, donc test touche

DSKFORMAT defb 0    ;Format du DSK. 0=MV 1=EXT
DSKNBTRACKS defb 0  ;Nb tracks. (41=de 0 a 40)
DSKNBSIDES defb 0   ;Nb sides (1 ou 2)
DSKNBPISTESCODEES defb 0    ;On compte dans la table des tailles du DSK le nb pistes codees
            ;(=taille>0), afin d'avoir une condition de fin valable.

DSKLASTTRACK defb 0 ;Permet de detecter la fin pour STANDARD.
DSKLASTSIDE defb 0  ;On compare la derniere track ecrite avec ca, si = alors fini.

EOFMET defb 0       ;0=on continue
NOWTRACK defw 0     ;Track traitee. Utile pour savoir si on lit la derniere piste du DSK.
NOWSIDE defb 0      ;Side traitee. Utile quand interprete track. 0/1
TRACKNBSECTS defb 0 ;Nb sectors dans ID track actuelle.
TRACKSECTSSIZE defb 0   ;Sectors size dans ID track actuelle.
TRACKNBBYTESTOREAD defw 0 ;Nb d'octets a lire dans la piste du DSK pour lire tous les DATAs des sects.
TRACKGOODFORMAT defb 0 ;1=Bon format  0*=pas bon (sect pas bonne taille, etc)...

ISSAMESECTUSED defb 0   ;1 si un id secteur est utilise plus d'une fois.


;LSTTRACKSTATE defs NBMAXTRACKS,0  ;Liste a 0 au debut et qui se remplit au fur et a mesure. 1=piste ok
                  ;0=piste pas ok=pas formattee, secteurs trop grands, taille 6...
ADTXT defw 0
CPTLOOP defb 0      ;compteur general de boucle.

PTLSTPTTRACKSINMEM defw 0 ;Pointeur actuel sur liste en dessous.

USEBB5A defb 0      ;Si a un, on utilise le vecteur BB5A pour afficher (CAT)

DOSCPTLOOP defb 0   ;Compteur generique
ODSSECT defw 0      ;Numero de secteur generique
ONEFATSIZE defb 0   ;Nb de secteur que contient UNE FAT.

NOSECTFAT defw 0    ;Numero du secteur ABSOLU de la FAT (SECTOR TABLE)
NOSECTDIRROOT defw 0    ;Num de sect ABS du DIRECTORY ROOT
NOSECTDATA defw 0   ;Num de sect ABS des DATA des fichiers

DOSENTRY defw 0     ;Contient la prochaine entree sur 12 bits lue.
PTBUFENTRIES defw 0 ;Pointe sur la prochaine entree a lire.

LOADWHERE defw 0    ;On charge ou ? Important car si on charge deux secteurs (clusters)
PTBUFLOAD defw 0    ;Pointe sur le prochain octet a lire dans le buffer LOAD du DSK.
BUFLOADFREE defw 0  ;Nb d'octets encore dispo dans le buffer. 0=lire secteur.
ISERROR defb 0
TEMP defw 0
TEMP2 defw 0

DOSFILETYPE defb 0

CATFILENAME defs 8,32
    defb "."
CATFILEEXT defs 3,32
    defb 0
TXTNEXTLINE defb 10,0
TXTDIRECTORY defb "  <DIR>",10,0

MARCHE   DEFB 0                         ;Lecteur en route ou non
LECTEUR  DEFB 0                         ;Lecteur actif
TETE     DEFB 0                         ;Tete active
ST0      DEFB 0                         ;Registre ST0
ST1      DEFB 0
ST2      DEFB 0
;ERROR    DEFB 0                         ;0=rien 1=disc miss 2=autre


USERFILENAME defs 12,0
USERFILENAMEF

USERDRIVES defb "BA"    ;src dest. Par defaut. Ecrasés par userdrive donnes user si params donnés.
            ;1ere lettre egalement utilisée par CAT.
NBPARAMS defb 1     ;nb param donnees en rsx. 0,>2=erreur !
PARAMIX defw 0
IS64K defb 0        ;0=128k de mem   1=64.

    if ISROM
DOSFILENAME defs 8,0    ;Nom du fichier.
DOSFILENAMEEXT defs 3,0 ;Extension
    else
DOSFILENAME defb "ASTEP   " ;"BALLS   " ;"FF_AB   " ;"THEDEM~1"  ;"DISCO6P " ;"LEADERBO" ;"QD3A    " ;"SUBTERRA"  
    ;"HKM     "   ;"ASTEP   " ;"MIDLIN~1"   ;"BIGOFULL"
DOSFILENAMEEXT defb "DSK"   ;Extension
    endif

TEMPFILENAME defs 16,0  ;Nom temp.

;Table piste pour deformattage.
;Attentin a donner la no de piste et side.
TABUNFORMAT
TUFTRACK1 defb 0
TUFSIDE1 defb 0, 6, 1, #20, 0
TUFTRACK2 defb 0
TUFSIDE2 defb 0, #c1, 6

;Contient l'etat des pistes.
;On deformattera les pistes restees a 1.
;#ff=ne pas toucher (etat initial)
;1=a deformatter (etat place apres l'init, en fct du nb de pistes)
;0=formatté (setté a la fin d'un write sur une piste
LSTTRACKSFORMATTED defs NBMAXTRACKS,0   ;Pour SIDE 0. 
LSTTRACKSFORMATTEDF

LSTTRACKSFORMATTED2 defs NBMAXTRACKS,0  ;Meme chose, mais pour SIDE 1
LSTTRACKSFORMATTED2F            ;LAISSER CES 2 BUFFERS CONSECUTIFS, on les clear en une fois.

;Liste qui contient le nb d'octets a *256 de la piste a charger
;La side 1 est entrelacee avec la side 2 si double face.
;La table contient #100 en trop car la taille contient aussi le header piste.
LSTTRACKSSIZE defs NBMAXTRACKS*2,0
LSTTRACKSSIZ2



;Liste de pointeur de debut de donnes tracks (header/idsects/data) dans le buffer main.
;Format = DW ptmain DB bank (Cx)
LSTPTTRACKSINMEM defs NBTRACKSINMEM*3,0
LSTPTTRACKSINME2 defw 0,0

;Table des gaps maximum.
;sectsize, nbsects, gap.
GAPTABLE
    defb 2,10,#24
    defb 2,9,MAXGAP ;#68
    defb 2,8,MAXGAP ;#bc
    defb 2,7,MAXGAP ;#ff

    defb 3,5,MAXGAP ;#80

    defb 1,19,#3
    defb 1,18,#15
    defb 1,17,#29
    defb 1,16,#3f
    defb 1,15,MAXGAP ;#58
    defb 1,14,MAXGAP ;#75
    defb 1,13,MAXGAP ;#80
    defb 1,12,MAXGAP ;#80
    defb 1,11,MAXGAP ;#80
    defb 1,10,MAXGAP ;#80


    defb 0,28,#20
    defb 0,27,#29
    defb 0,26,#32
    defb 0,25,#3c
    defb 0,24,#47
    defb 0,23,MAXGAP ;#52
    defb 0,22,MAXGAP ;#60
    defb 0,21,MAXGAP ;#6e

    defb #ff



;Capture la police Systeme
;GETFNT ld a,0          ;Petite securite pour ne la generer qu'une fois.
;   or a
;   ret nz
;   inc a
;   ld (GETFNT+1),a

;   ld bc,#7f8a
;   out (c),c
;   ld hl,#3900
;   ld de,FONTE
;   ld bc,#2f0
;   ldir
;   ld bc,#7f8e
;   out (c),c
;   ret



;Efface la partie interface
CLEARITF
    ld hl,YINT+1*#50+#c000+10
    ld bc,69
    ld a,8*10
    call CLEARPART
    ret

;Efface la partie du bas
CLEARBAS
    ld hl,21*#50+#c000
    ld bc,79
    ld a,8*4
    call CLEARPART
    ret

;Efface une partie de l'ecran
;HL=adecr
;BC=Larg en octet
;A=hauteur en ligne
CLEARPART
CLPLOOP push hl
    push bc
    ld e,l
    ld d,h
    inc de
    ld (hl),0 ;123
    ldir
    pop bc
    pop hl

    ld de,#800
    add hl,de
    jr nc,CLPBC26
    ld de,#c050
    add hl,de
CLPBC26 dec a
    jr nz,CLPLOOP

    ret



;Calcul la place occupee dans le buffer BUFMAIN et update le texte buffer.
CALCBUFFER
    ld hl,(PTBUFMAIN)
    ld a,(BKBUFMAIN)
    cp #c0
    jr z,CALCBC0
    ld b,NBKOBUFFC0
    cp #c4
    jr z,CALCBC4567
    ld b,16+NBKOBUFFC0
    cp #c5
    jr z,CALCBC4567
    ld b,32+NBKOBUFFC0
    cp #c6
    jr z,CALCBC4567
    ld b,48+NBKOBUFFC0
CALCBC4567
    ld a,h
    sub #40
    call DIV1024
    add a,b

CALCBEND
    call NBTODEC
    ld a,b
    ld (TXTBUFFE2),a
    ld a,c
    ld (TXTBUFFE2+1),a
    ret

CALCBC0 ld de,BUFMAIN
    or a
    sbc hl,de
    ld a,h
    call DIV1024
;
    jr CALCBEND

;Division par 1024
;A=poids fort du nb 16 bits
;A=res
DIV1024
;   rra
;   rra
    rra
    rra
    and %111111
    ret



    include "WD_DSKFDC.asm"
    include "WD_ReadPCFile.asm"
    include "WD_CatPC.asm"

    list
;**** Fin WriteDSK Main code
    nolist


    if WD_STANDALONE

PHRBB5A ld a,(hl)
    or a
    ret z
    call #bb5a
    inc hl
    jr PHRBB5A

    include "CPCBooster.asm"

    endif


    if ISROM
        rend
    endif
