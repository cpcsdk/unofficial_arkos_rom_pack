    nolist

;   READDSK 1.0


;   Transfert un disc en DSK par la CPCBooster.


;   ùRDSK,"FileName","[Src][1/2]",[nbtracks].
;               1=Lis face 1    2=double face



;   BUGS =
;   ameliorer la detection des secteurs identiques. (disco)
;   ameliorer detection nb de secteurs. Si 1 secteur, tres lent !

;   Mode Paranoia Desactive = inutile pour Disco6 car les deux sects #41 sont identiques !!



;   TODO=
;   Gerer tout seul le cas d'un taille 0 ?
;   Nouvelle gestion pour lire secteur. Vachement mieux ! ????? ...
;   Afficher secteur Retry/ignore/cancel ?



;   La 'side' du header track est toujours a mise 0, sauf si double face.
;   Astuce necessaire, si bit 0 de ST1 ou ST2, alors bit 5 de ST1 ou ST2 a 1
;   (=si taille 0 non lisible, bad checksum).




;   Algo lecture piste =

;   Test si piste formattee =
;   On fait un scan. On essaye de lire le secteur donne par le scan. Si on peut pas, piste
;   non formattee.

;   Test de nombre de secteur et ID =

;   On fait 2 scans.
;   Si no ids egaux, alors les secteurs ont des IDs identiques, type the demo (voir plus bas).
;   Si pas egaux, on fait une lecture de secteur inexistant.
;   On fait une lecteure foireuse, un scan, on note le no ID.
;   On fait d'autres scans jusqu'a tomber sur 1er secteur.
;   On connait ainsi le nb de secteurs et leurs noms.

;   Si type 'the demo' =
;   Lire secteur foireux. Faire 35 scans ID pour connaitre tous les noms de sects,
;   Lire secteur ID X. Faire un checksum Y 16 bits.
;   Lire secteurs suivants. Si checksum <>Y alors on NBsects++ et on continue.

;   Enfin, maintenant qu'on a les IDs et leur nombre, on lit le tout en mem.




RD_STANDALONE equ 0 ;+1     ;Si a 1, alors il faut que Writedsk aussi soit en stand alone !

RD_ADROM equ #d600      ;Adresse en rom. On la fixe car le placement dynamique fait chier.

RD_AD_CODENORMAL equ #7000




    if RD_STANDALONE
    include "WriteDSK.asm"
    org RD_AD_CODENORMAL
    endif



RDReadBuffer equ #1000      ;Buffer (6k max) ou on va lire des seteurs 'junks'.
                ;Il est ecrase pour la lecture veritable des pistes.
RDTrackBuffer equ #1000     ;Buffer contenant l'ensemble des secteurs de la piste. 
ADLSTSECTS equ #100     ;Adresse de LSTSECTS. Taille max = 35*8=#118





    if ISROM

    org RD_ADROM
    rorg RD_AD_CODENORMAL
    endif

RD_CODEDEBUT
;   ld b,a
;   xor a
;   jr RD_TESTPARAMS

;RDP_CODEDEBUT
;   ld b,a
;   ld a,1

RD_TESTPARAMS
;   ld (RD_PARANOIA+1),a
;   ld a,b
    ld (NBPARAMS),a
    cp 1
    jr z,RD_ROMNOPOK
    cp 2
    jr z,RD_ROMNOPOK
    cp 3
    jr z,RD_ROMNOPOK
RD_BADPARAM ld hl,RD_TXTBADPARAM
RD_ERRPARAM
    call PHRBB5A
    ret
RD_ROMNOPOK


;Donnees par defaut

    ld a,'A'
    ld (USERDRIVES),a
    ld a,42 ;+10            ;42 = de 0 a 41
    ld (DSKNBTRACKS),a
    ld a,1          ;1 ou 2
;    inc a
    ld (DSKNBSIDES),a
    xor a
;    inc a
    ld (NOWSIDE),a

    ld hl,RD_FILENAME
    ld de,RD_FILENAME+1
    ld bc,12-1
    ld (hl),32
    ldir


;   ùRDSK[P],"FileName","[Src][1/2]",[nbtracks].
;               1=Lis face 1    2=double face
    ld a,(NBPARAMS)
    cp 1
    jr z,RD_PARAM1
    cp 2
    jr z,RD_PARAM2
;3e param. Forcement Nbtracks.
    ld a,(ix+1)     ;Si poids fort non nul, trop gros pour etre une track !
    or a
    jr nz,RD_BADPARAM
    ld a,(ix+0)
    ld (DSKNBTRACKS),a
    inc ix
    inc ix



;Deux params. On soit un octet (drive ou face/doubleface) ou deux octets.
RD_PARAM2   
    ld l,(ix+0)
    ld h,(ix+1)
    inc ix
    inc ix

    push hl
    pop iy

    ld l,(iy+1)
    ld h,(iy+2)
    ld a,(iy+0)     ;si 1 carac alors forcedrive only
    cp 1
    jr z,RD_PARAM2ONEC
    cp 2
    jr z,RD_PARAM2TWOC
    jr RD_BADPARAM
RD_PARAM2ONEC
    ld a,(hl)       ;Octet est un param de side (1/2) ?
    call RD_IS_PARAM_SIDE
    jr c,RD_PARAM2Fin
    call ISUDROK        ;Octet est un drive ?
    jr nc,RD_BADPARAM
    ld (USERDRIVES),a
    jr RD_PARAM2Fin
;2 params dans le 2e param.
RD_PARAM2TWOC
    ld a,(hl)           ;1er octet est forcement un drive
    call ISUDROK
    jr nc,RD_BADPARAM
    ld (USERDRIVES),a
    inc hl
    ld a,(hl)           ;2e est forcement un side (1/2)
    call RD_IS_PARAM_SIDE
    jp nc,RD_BADPARAM

RD_PARAM2Fin



;1er param. Nom de fichier.
RD_PARAM1
    ld l,(ix+0)
    ld h,(ix+1)
    push hl
    pop ix

    ld a,(ix+0)     ;si longueur fichier trop long or vide, stoppe
    or a
    jp z,BADNAME
    cp 13
    jr c,RD_P1OK
    jp BADNAME
RD_P1OK
    ld c,a
    ld b,0
    ld l,(ix+1)
    ld h,(ix+2)
    ld de,RD_FILENAME
    ldir






;Si DSK double face, nowside=0. (inutile)
;   ld a,(DSKNBSIDES)
;   cp 2
;   jr nz,RD_NODDSIDED
;   xor a
;   ld (NOWSIDE),a
;RD_NODDSIDED



    xor a
;   ld a,30
    ld (NOWTRACK),a
    ld (USEBB5A),a







    ld a,(USERDRIVES)
    res 5,a
    ld (TXTRDDEBU2),a
    sub "A"
    ld (SRCLECT),a





    call INIT
    ld sp,PILE



    call FDCON


    xor a
    call CHLECT
    call RECALIBR
    call RECALIBR
    ld a,1
    call CHLECT
    call RECALIBR
    call RECALIBR


    ld hl,LSTTRACKSFORMATTED        ;Place les pistes en 'unformatted'=#ff
    ld de,LSTTRACKSFORMATTED+1      ;On mettra des 0 si elles le sont
    ld bc,LSTTRACKSFORMATTED2F-LSTTRACKSFORMATTED-1
    ld (hl),#ff
    ldir


    ld bc,#7f10     ;Select border (pour lecture CPCB)
    out (c),c


    ld hl,TXTREADDSK
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


;       jr CRAPCPCB ;**************

;Teste presence CPCBooster,
    call CPCB_Init
    jr c,RDCPCBPresente
    ld hl,TXTNOCPCB     ;Si CPCB non detectee, reset
    call PHRASE
    call SPACE
    jp 0
;CPCB presente. Test avec PC
RDCPCBPresente
    call CPCB_InitPC
    jr c,RDCPCBOk
;Test avec PC pas bon. Retry.
    ld hl,TXTPCCOMFailed
    call PHRASE
    call SPACE
    call CLEARBAS
    jr RDCPCBPresente

;CPCB branchee et communication etablie.
;Creation du fichier PC en sortie.
RDCPCBOk
;Creation du fichier cote PC.
    ld hl,RD_FILENAME
    call CPCB_CreateOutputFile
    jp nc,RD_CantCreatePCFile

;Initialise le DSK sur PC.
    ld a,(DSKNBTRACKS)
    ld h,a
    ld a,(DSKNBSIDES)
    ld l,a
    ld de,'1'*256+'0'
    call CPCB_InitDSK

CRAPCPCB


    ld hl,TXTRDDEBUT
    call PHRASE
    ld hl,TXTINSERTDISC ;TXTINSERTCPCB
    call PHRASE
    call SPACE
    call CLEARBAS
;   jr DOFOK



 
    ld a,(SRCLECT)
    call CHLECT

RD_MainLoop
    ld a,(NOWSIDE)          ;La side change si double face
    call CHHEAD


    ld a,(NOWTRACK)         ;get track number pour affichage ligne du bas
    call NBTODEC
    ld a,b
    ld (TXTTRAC2),a
    ld a,c
    ld (TXTTRAC2+1),a

    ld a,(NOWSIDE)          ;get side, forcee ou non
    add a,"0"
    ld (TXTTRAC3),a



    

; Test si piste formattee = On fait plusieurs scan. On essaye de lire le secteur donne par le scan.
;D=Taille E=piste H=ID L=Tete
RD_FrmAvScan
    ld hl,TXTTRACK
    call PHRASE

    ld a,4
RD_FrmScan
    ld (RD_FrmScanCnt+1),a

    ld a,(NOWTRACK)
    call GOTOPIST
    call SCANID     ;ret=D=Taille E=piste H=ID L=Tete
    ld a,(ST0)      ;disc missing ?
    bit 3,a
    jr z,RD_FrmScanOk
    ld ix,TXTRDERROR
    ld hl,RD_FrmAvScan
    ld de,0
    ld bc,PRGENDFAIL ;PRGEND
    jp RETRYIGNORECANCEL

RD_FrmScanOk
    ld a,(NOWTRACK)     ;A=piste physique B=nom secteur C=tete D=taille E=piste ID sect
    ld b,h
    ld c,l
    ld hl,RDReadBuffer
    call READSECT
    jr c,RD_TrackFormatted

RD_FrmScanCnt ld a,0
    dec a
    jr nz,RD_FrmScan

;Si erreur disc en lisant la track, c'est qu'elle est non formatee.
    call CLEARITF
    ld hl,TXTRDTRACKUNF
    call PHRASE
    jp RD_NextTrack

;Piste formatee
RD_TrackFormatted
    call SETTRACKASTREATED


;Test de nombre de secteur et ID.
;Type The demo ou non ?
;On fait 2 scans.
;Si no ids egaux, alors les secteurs ont des IDs identiques, type the demo.
;Si mode Paranoia, type The Demo obligatoirement
;RD_PARANOIA ld a,0
;   or a
;   jp nz,RD_TheDemoType

    call SCANID
    push hl
    call SCANID
    pop af
    cp h            ;si egaux, routine The Demo
    jp z,RD_TheDemoType

;Pas egaux, donc cas normal, on fait une lecture de secteur inexistant.
;On fait une lecteure foireuse, un scan, on note le no ID.
;On fait d'autres scans jusqu'a tomber sur 1er secteur.
;On connait ainsi le nb de secteurs et leurs noms.
    xor a
    ld (TRACKNBSECTS),a
    ld ix,LSTSECTS

    ld a,(NOWTRACK)
    call READFakeSECTOR
    call SCANID     ;D=Taille E=piste H=ID L=Tete
    ld (RD_W1+1),hl
    ld (RD_W2+1),de
    call RD_AddSectToList

;Fait des scans IDs tant qu'on est pas retombe sur le meme sect.
RD_CNTLoop
    ld hl,TRACKNBSECTS
    inc (hl)
    call SCANID

    call RD_AddSectToList       ;On code le sect meme s'il est identique. Grace a 
                    ;TRACKNBSECTS on ne le lira pas de toute facon.
RD_W1   ld bc,0             ;IDs sects identiques ? Si non, on lit le suivant.
    or a
    sbc hl,bc
    jr nz,RD_CNTLoop
    ex de,hl
RD_W2   ld bc,0
    or a
    sbc hl,bc
    jr nz,RD_CNTLoop

;On connait maintenant le nb de secteurs et leurs noms !



;On peut les lire...








    ld hl,RDTrackBuffer
    ld (RD_PTBUFF),hl

    ld a,(TRACKNBSECTS)
    ld (RDW_CptLoop+1),a



    ld iy,LSTSECTS
RDW_Loop
    ld hl,(RD_PTBUFF)       ;Code adresse ou lire les donnees.
    ld (iy+6),l
    ld (iy+7),h

;A=piste physique  B=nom secteur C=tete D=taille E=piste IDsect  HL=ou le charger
    ld a,(NOWTRACK)
    ld e,(iy+0)
    ld b,(iy+2)
    ld c,(iy+1)
    ld d,(iy+3)
    call READSECT
;   ld (RDW_Ignore+1),hl
;       jr RDW_WrOk ;*********
    jr c,RDW_WrOk
    ld ix,TXTERROR
    ld hl,RDW_Loop ;RDW_Retry
    ld de,RDW_Ignore
    ld bc,PRGENDFAIL ;PRGEND
    jp RETRYIGNORECANCEL
;RDW_Retry
;   call RECALIBR
;   call RECALIBR
;   jr RDW_Loop
RDW_Ignore ;ld hl,0 ;Si ignore, on passe qd meme au sect suivant. ST1 et ST2 noteront les err.
    ld hl,(RD_PTBUFF)   ;Le secteur est 'vide'.
    ld a,(iy+3)
    call RD_EmptySectorInMem
;   call RECALIBR
;   call RECALIBR
RDW_WrOk ld (RD_PTBUFF),hl

    ld a,(ST1)          ;Copie les regs ST1 et ST2.
    call RD_TreatST1
    ld (iy+4),a
    ld a,(ST2)
    call RD_TreatST2
    ld (iy+5),a



    ld bc,8
    add iy,bc

RDW_CptLoop ld a,0
    dec a
    ld (RDW_CptLoop+1),a
    jp nz,RDW_Loop

    jp RD_SendTrack





;Les secteurs ont memes IDs. Routines speciales.
RD_TheDemoType
;   Lire secteur foireux. Faire 35 scans ID pour connaitre tous les noms de sects,
;   Lire secteur ID X. Faire un checksum Y 16 bits.
;   Lire secteurs suivants. Si checksum <>Y alors on NBsects++ et on continue.
;   ld bc,#7f10
;   out (c),c
;   ld a,#5c
;   out (c),a
;   jr RD_TheDemoType


;RD_TDWholeLoop
;   Lire secteur foireux. Faire 35 scans ID pour connaitre tous les noms de sects,
    ld a,(NOWTRACK)
    call READFakeSECTOR

    ld ix,LSTSECTS

    ld a,35
RD_TDScan push af
    call SCANID
    call RD_AddSectToList
    pop af
    dec a
    jr nz,RD_TDScan



;   Lire secteur 1er Secteur. Faire un checksum Y 16 bits.
    ld iy,LSTSECTS
    ld hl,RDTrackBuffer
    ld (RD_PTBUFF),hl

    xor a
;   ld (TRACKERROR),a
    ld (TRACKNBSECTS),a

RD_TDRetry
    ld a,(NOWTRACK)
    call READFakeSECTOR



;A=piste physique  B=nom secteur C=tete D=taille E=piste IDsect  HL=ou le charger
    ld hl,(RD_PTBUFF)       ;Code adresse ou lire les donnees.
    ld (RDTD_AdFirstSect+1),hl  ;Sauve ad du 1er secteur pour cp avec les autres.
    ld (iy+6),l
    ld (iy+7),h
    ld a,(NOWTRACK)
    ld e,(iy+0)
    ld b,(iy+2)
    ld c,(iy+1)
    ld d,(iy+3)
    call READSECT
    jr c,RDTD_WrOk
;   ld a,1              ;Si erreur, on la testera en fin de piste.
;   ld (TRACKERROR),a
    ld ix,TXTERROR
    ld hl,RD_TDRetry
    ld de,RD_TDIgnore
    ld bc,PRGENDFAIL ;PRGEND
    jp RETRYIGNORECANCEL
RD_TDIgnore             ;Si Ignore, clear le secteur.
    ld hl,(RD_PTBUFF)       ;Les regs STx portent l'erreur.
    ld a,(iy+3)
    call RD_EmptySectorInMem

RDTD_WrOk ld (RD_PTBUFF),hl
    ld a,(ST1)          ;Copie les regs ST1 et ST2.
    call RD_TreatST1
    ld (iy+4),a
    ld a,(ST2)
    call RD_TreatST2
    ld (iy+5),a
;   ld (RD_Checksum),de     ;Sauve Checksum.

    ld bc,8
    add iy,bc

;   Lire secteurs suivants.
;   On compte d'abord 1++ scanid.
;   Si checksum <>Y alors on NBsects++ et on continue.
RDTD_LoadRemainingSectors

RDTD_LoadRemainingSectorsRETRY


    ld a,(NOWTRACK)
    call READFakeSECTOR
    ld a,(TRACKNBSECTS)
    inc a       ;On inc pour skipper le 1er.
RDTD_LoadRemainingSScan
    push af
    call SCANID
    pop af
    dec a
    jr nz,RDTD_LoadRemainingSScan


    ld hl,(RD_PTBUFF)       ;Code adresse ou lire les donnees
    ld (RDTD_AdSectNow+1),hl
    ld (iy+6),l
    ld (iy+7),h
    ld a,(NOWTRACK)
    ld e,(iy+0)
    ld b,(iy+2)
    ld c,(iy+1)
    ld d,(iy+3)
    call READSECT
    jr c,RDTD_LRSOk
;   ld a,1              ;Si erreur, on la testera en fin de piste.
;   ld (TRACKERROR),a
    ld ix,TXTERROR
    ld hl,RDTD_LoadRemainingSectorsRETRY
    ld de,RDTD_LoadRemainingSectorsIGNORE
    ld bc,PRGENDFAIL ;PRGEND
    jp RETRYIGNORECANCEL
RDTD_LoadRemainingSectorsIGNORE
    ld hl,(RD_PTBUFF)       ;Clear le secteur, au cas ou on fait Ignore.
    ld a,(iy+3)         ;Les regs STx portent l'erreur.
    call RD_EmptySectorInMem



RDTD_LRSOk ld (RD_PTBUFF),hl
    ld a,(ST1)          ;Copie les regs ST1 et ST2.
    call RD_TreatST1
    ld (iy+4),a
    ld a,(ST2)
    call RD_TreatST2
    ld (iy+5),a

    ld bc,8
    add iy,bc

    ld hl,TRACKNBSECTS
    inc (hl)

    ;Compare le 1er secteur et celui la.
    ld a,(iy+3-8)   ;Get taille en octets
    call GetSectorSizeByte

RDTD_AdFirstSect ld hl,0
RDTD_AdSectNow ld bc,0
RDTD_AdSectNLp
    ld a,(bc)
    cp (hl)
    jr nz,RDTD_LoadRemainingSectors
    inc hl
    inc bc
    dec de
    ld a,e
    or d
    jr nz,RDTD_AdSectNLp

;   ld hl,(RD_Checksum)     ;Compare les checksums. Si <>, on recommence !
;   or a
;   sbc hl,de
;   jr nz,RDTD_LoadRemainingSectors

    ;Teste les erreurs
;   ld a,(TRACKERROR)
;   or a
;   jr z,RDTD_NoError
;   ld ix,TXTERROR
;   ld hl,RD_TDWholeLoop
;   ld de,RDTD_NoError
;   ld bc,PRGENDFAIL ;PRGEND
;   jp RETRYIGNORECANCEL
;RDTD_NoError













;   ld bc,#7f10
;   out (c),c
;   ld a,#44
;   out (c),a

    jr RD_SendTrack
;TDEND jr TDEND
;   ret








RD_SendTrack
;Trouve la "taille secteur de la piste"
    ld a,(TRACKNBSECTS)
    call RD_FindBiggerSect
    ld (RD_Track_Size),a

;On trouve le GAP
;   ld a,(RD_Track_Size)
    ld b,a
    ld a,(TRACKNBSECTS)
    ld c,a
    ld d,MAXGAP
    call CORRECTGAP         ;b=sectsize c=nbsects d=gap dsk RET=A=gap a coder
    ld (RD_Track_Gap),a




;On affiche donnees Track.
    call CLEARITF
    call INITAFFIDSECT

    ld de,RD_InfoTrack
    ld hl,NOWTRACK
    ldi
    ld hl,NOWSIDE           ;???
    ldi
    ld hl,RD_Track_Size
    ldi
    ld hl,TRACKNBSECTS
    ldi
    ld hl,RD_Track_Gap
    ldi
    ld a,#e5
    ld (de),a
    ld ix,RD_InfoTrack
    ;TrackNumber,   Side (1/2),   Sector size,   Nb sectors,   Gap#3,   Filler Byte.
    call AFFINFOTRACK


    ld a,(TRACKNBSECTS)
    ld ix,LSTSECTS
RD_AFFIDS push af
    call AFFIDSECT
    ld bc,8
    add ix,bc
    pop af
    dec a
    jr nz,RD_AFFIDS
    

;           call SPACE  ;*********

;Lecture de piste finie.
;Commence l'envoi de la track vers le PC (et son header)
    ld hl,TXTTRACK      ;reecrit 'track x side x' au cas ou erreur, ca a ete efface.
    call PHRASE
    ld hl,TXTRDTRACKOK
    call PHRASE


    call CPCB_SendTrack

;Format = Track, Side (0/1), sect size, nb sects, Gap, filler
;Puis pour chaque sect =
;Track, side, sect id, sect size, fdcreg1, fdcreg2, DW data length
;puis les donnees du secteur.

    ld a,(NOWTRACK)
    call CPCB_SendByte
    ld a,(NOWSIDE)          ;Si double face on envoie NOWSIDE, sinon 0 tjs.
    ld b,a
    ld a,(DSKNBSIDES)
    cp 2
    jr z,RD_STSide
    ld b,0
RD_STSide ld a,b
    call CPCB_SendByte
    ld a,(RD_Track_Size)        ;Taille piste = plus grande taille des sects.
    call CPCB_SendByte
    ld a,(TRACKNBSECTS)
    call CPCB_SendByte

    ld a,(RD_Track_Gap)
    call CPCB_SendByte

    ld a,#e5
    call CPCB_SendByte


;Envoi des infos pour chaque secteur.
    ld ix,LSTSECTS

    ld a,(TRACKNBSECTS)
    ld (RDS_CptLoop+1),a
RDS_Loop
    ld a,(ix+0) ;track
    call CPCB_SendByte
    ld a,(ix+1) ;side
    call CPCB_SendByte
    ld a,(ix+2) ;sect id
    call CPCB_SendByte
    ld a,(ix+3) ;sect size
    call CPCB_SendByte
    ld a,(ix+4) ;fdc reg1
    call CPCB_SendByte
    ld a,(ix+5) ;fdc reg2
    call CPCB_SendByte

    ld a,(ix+3)     ;Envoi taille du secteur
    call GetSectorSizeByte
    ld a,e
    call CPCB_SendByte  ;Envoi de taille secteur
    ld a,d
    call CPCB_SendByte

;Envoi les donnees du secteur.
    ld l,(ix+6)     ;Get pointer on data.
    ld h,(ix+7)
;HL=donnees
;DE=taille
    call CPCB_SendXBytes

;Next sector.
    ld bc,8
    add ix,bc

RDS_CptLoop ld a,0
    dec a
    ld (RDS_CptLoop+1),a
    jr nz,RDS_Loop



;On passe a la piste suivante. Si le DSK est double face, on selectionne l'autre side !
RD_NextTrack
    call CLEARBAS

    ld a,(DSKNBSIDES)
    cp 1
    jr z,RD_NTSingleSided
    ld a,(NOWSIDE)      ;On avance d'une piste si on retombe sur side 0.
    xor 1
    ld (NOWSIDE),a
    jp nz,RD_MainLoop

RD_NTSingleSided
    ld a,(DSKNBTRACKS)
    ld b,a
    ld a,(NOWTRACK)
    inc a
    ld (NOWTRACK),a
    cp b
    jp nz,RD_MainLoop
    

;Transfert termine avec succes !
    call CLEARITF

    call CPCB_NoMoreTrack

    jp DSKFIN2


;En entree = D=Taille E=piste H=ID L=Tete
RD_AddSectToList
    ld (ix+0),e
    ld (ix+3),d
    ld (ix+1),l
    ld (ix+2),h
    ld bc,8     ;On saute les 4 db, mais aussi le pointeur
    add ix,bc
    ret



RD_CantCreatePCFile
    ld hl,RD_TXT_CantCreatePCFile
    call PHRASE
    jp PRGEND






;On trouve le plus grand secteur. Teste si bad cks.
;A=nbSects
;RET=A=taille
RD_FindBiggerSect
;+0 Piste, +1 Tete, +2 ID, +3 Taille, +4=fdcreg1 +5=fdcreg2 +6+7 pointeur
    ld ix,LSTSECTS
    ld de,8
    ld b,a
    ld c,0      ;Plus grand secteur.
RD_FBSLoop
    ld a,(ix+3)
    cp c
    jr c,RD_SmallerSect
    ld h,a
    ld a,(ix+4)     ;si Bad CKS alors ne prend pas en compte ce sect.
    or (ix+5)
    ld l,a
    ld a,h
    bit 5,l
    jr nz,RD_SmallerSect
    ld c,a
RD_SmallerSect
    add ix,de
    djnz RD_FBSLoop
    ld a,c
    ret






;Donne la taille en octet d'une taille de sect.
;A=taille
;RET=DE=Taille en octets.
GetSectorSizeByte
    add a,a
    ld hl,RD_SectsizeTab
    ld e,a
    ld d,0
    add hl,de
    ld e,(hl)
    inc hl
    ld d,(hl)
    ret


;Vide un secteur de la memoire, au cas ou un Ignore est fait apres une lecture foireuse (ou taille 0)
;HL=mem
;A=taille sect
;RET=HL=pointe apres le secteur
;BC et DE sauves, IX et IY non modif.
RD_EmptySectorInMem
    push bc
    push de
    push hl
    call GetSectorSizeByte
    pop hl
    ld c,e
    ld b,d
    ld (hl),#e5
    ld e,l
    ld d,h
    inc de
    ldir
    pop de
    pop bc
    ret



;Elimine les bits non utiles a ST1 avant de le mettre dans le DSK.
;Si bit 0 a 1, alors transfert sur bit 5
RD_TreatST1
    bit 0,a
    jr z,RD_TST1
    set 5,a
RD_TST1 and %00100100
    ret

RD_TreatST2
    bit 0,a
    jr z,RD_TST2
    set 5,a
RD_TST2 and %01100000
    ret




;Dis si le param est 1 ou 2. Modifie vars en consequence.
;A=param.
;RET=Carry=1=ok
RD_IS_PARAM_SIDE
    cp "1"
    jr z,RDIPS1
    cp "2"
    jr z,RDIPS2
    or a
    ret
RDIPS1  ld a,1              ;Side 1 a lire. Simple face
    ld (NOWSIDE),a
    scf
    ret
RDIPS2  ld a,2              ;Double face.
    ld (DSKNBSIDES),a
    scf
    ret

;Liste des secteurs de la track actuelle, AINSI que le pointeur que leur adresse memoire !
;Meme format que DSK.
;+0 Piste, +1 Tete, +2 ID, +3 Taille, +4=fdcreg1 +5=fdcreg2 +6+7 pointeur
LSTSECTS equ ADLSTSECTS

RD_PTBUFF defw 0    ;Pointeur sur buffer, pointe sur la ou charger les sects a la suite.

;Petit buffer pour affichage donnees track.
;TrackNumber,   Side (1/2),   Sector size,   Nb sectors,   Gap#3,   Filler Byte.
RD_InfoTrack defs 6,0

RD_Track_Gap defb 0
RD_Track_Size defb 0

;RD_Checksum defw 0
;RD_AdFirstSect defw 0  ;Utile pour THEDemoType.

;TRACKERROR defb 0  ;Utilise dans cas THEDEMO. On ne peut se permettre d'interrompre chargement.

TXTREADDSK defb 1,1,"ReadDSK V1.0 by Targhan/Arkos",10,0

TXTINSERTDISC defb 1,22,"Press Space to begin the transfert to PC...",10,0

TXTRDDEBUT defb 1,4,"Transfering DSK from "
TXTRDDEBU2 defb "X to CPCBooster...",10,10,0

TXTRDTRACKOK defb 1,24,2,19,"Read. Transfering...",10,0
TXTRDTRACKUNF defb 1,24,2,19,"Unformatted.",10,0

TXTRDERROR defb 1,YERR,"Read Error. Retry, Cancel ?",10,0

RD_FILENAME defs 13,0

RD_TXT_CantCreatePCFile defb 1,22,"Can't create PC file.",#d,#a,0

RD_TXTBADPARAM defb "Format :",10,13,124,"RDSK,",34,"DskName",34,",",34,"[Src][1/2]",34,",[NbTracks]",0


;Taille des secteurs en fct de la size.
RD_SectsizeTab dw #80,#100,#200,#400,#800,#1000,#1800

RD_CODEFIN
    list
;**** Fin ReadDSK
    nolist



    if ISROM
        rend
    endif





