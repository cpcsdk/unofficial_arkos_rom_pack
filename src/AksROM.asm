    org #c000
;   org #1000
    nolist





;   **** TODO
;   Bugs lock AFT ? 






AD_CPCBooster equ #9c00     ;Ad CPCB une fois copie en RAM. Ne pas deborder sur 9e00 ! Writedsk...



;OurCATHandle equ #bdc1     ;3 octets. Adresse+RomVa faire pointer CAT sur notre handle.
;SysPtCATHandle equ #bdc4   ;Les 2 octets de #bc9b+1



    defb 1      ;type ROM
    defb 0      ;mark number
    defb 0      ;version number
    defb 0      ;mod number
    defw TABINSTR
    jp AKSRomInit
    jp AKSRomHelp
    jp WD_Copy
    jp DIRDOS_Copy
    jp RD_Copy
;   jp RDP_Copy

    jp LD_Debut
    jp GF_Debut
    jp GFA_Debut
    jp HD_Debut
    jp SF_Debut
    jp SFN_Debut
    jp BN_Debut
    jp MM_Debut
    jp VW_Debut
    jp SetBoot_Debut
TABINSTR defb "aksro","m"+#80
    defb "AKS","H"+#80
    defb "WDS","K"+#80      ;WriteDSK
    defb "DIRDO","S"+#80        ;Dirdos
    defb "RDS","K"+#80      ;ReadDSK
;   defb "RDSK","P"+#80     ;ReadDSK Paranoia

    defb "L","D"+#80        ;LoaD
    defb "G","F"+#80        ;GetFile
    defb "GF","A"+#80       ;GetFile Ascii
    defb "H","D"+#80        ;HeaDer
    defb "S","F"+#80        ;SendFile
    defb "SF","N"+#80       ;SendFile no Header
    defb "B","N"+#80        ;BurN
    defb "M","M"+#80        ;MeMory
    defb "V","W"+#80        ;View
    defb "SETBOO","T"+#80       ;Set Boot
    defb 0


AKSRomInit
    push bc
    push de
    push hl
    push ix


    ld hl,TXTROM1
    call PHRBB5A
;
    call #b912
    push af

    ld b,a
    sub 10
    jr c,MKINI10
    ld a,"1"
    call #bb5a
    ld a,b
    add "0"-10
    call #bb5a
    jr MKINIF

MKINI10 ld a,b
    add a,"0"
    call #bb5a
MKINIF
    ld hl,TXTROM2
    call PHRBB5A

    call TestCRTC
    call #bb5a

    ld hl,TXTROM3
    call PHRBB5A


;Sauve Cat Handle Systeme
;   ld hl,(#bc9b+1)
;   ld (SysPtCATHandle),hl


;Patch le vecteur CAT pour qu'il pointe sur notre rom.
;   pop af      ;get no rom arkos
;   ld (OurCATHandle+2),a
;   ld hl,CATPrg
;   ld (OurCATHandle),hl
;
;   ld hl,OurCATHandle
;   ld (#bc9b+1),hl

    ld hl,AK_Patch
    ld de,#be7f
    ld bc,AK_PatchFin-AK_Patch
    ldir

    pop af
    ld (AK_PRom-AK_Patch+1+#be7f),a






MKINI2  
    pop ix
    pop hl
    pop de
    pop bc
    scf
    ret
TXTROM1 defb 255,"Rom ",0
TXTROM2 defb " : ",254,"Arkos Rom V1.0 : ",#f,1,124,"AKSH",254,". Crtc ",#f,1,0
TXTROM3 defb #d,#a,0

PHRBB5A ld a,(hl)
    inc hl
    cp 255      ;pen 3
    ld b,3
    jr z,PHRPEN
    cp 254      ;pen 2
    ld b,2
    jr z,PHRPEN
PHRBB5A2
    or a
    ret z
    call #bb5a
    jr PHRBB5A

;Change le PEN si mode <>2
PHRPEN
    call #bc11
    cp 2
    jr z,PHRBB5A
    ld a,b
    push hl
    call #bb90
    pop hl
    jr PHRBB5A2




;Aks HELP

AKSRomHelp
    ld hl,TXTHelp
    call PHRBB5A
    ret

TXTHelp
    defb #f,#1,"A",255,"r",#f,#1,"k",255,"o",#f,#1,"s",255," ROM V1.0 :",#d,#a
;   defb #f,#1,"A",254,"r",#f,#1,"k",254,"o",#f,#1,"s",254," ROM V1.0 ",#d,#a
;   defb 255,"A",254,"r",255,"k",254,"o",255,"s",254," ROM V1.0",#d,#a
    defb 254,"WriteDSK 1.2 :",#d,#a
    defb #f,#1,124,"WDSK,",34,"DskName",34,",",34,"[SrcDest][1]",34,#d,#a
    defb #f,#1,124,"DIRDOS,[",34,"Src",34,"]",#d,#a
    defb 254,"ReadDSK 1.0 :",#d,#a
    defb #f,#1,124,"RDSK,",34,"DskName",34,",",34,"[Src][1/2]",34,",[NbTracks]",#d,#a
    defb 254,"GetFile :",#d,#a
    defb #f,#1,124,"GF[A],",34,"Filename",34,",[Start],[Exec]",#d,#a
    defb 254,"SendFile : "
    defb #f,#1,124,"SF[N],[Filename]",#d,#a
    defb 254,"Load : ",#d,#a
    defb #f,#1,124,"LD,",34,"Filename",34,",[Adr],[Bank],[AdBuffer]",#d,#a
    defb 254,"Header : "
    defb #f,#1,124,"HD,",34,"Filename",34,#d,#a
    defb 254,"Burn : "
    defb #f,#1,124,"BN,",34,"Filename",34,",Rom",#d,#a
    defb 254,"Memory : "
    defb #f,#1,124,"MM,[Address]",#d,#a
    defb 254,"View : "
    defb #f,#1,124,"VW,[Address]",#d,#a
    defb 254,"SetBoot : "
    defb #f,#1,124,"SETBOOT,",34,"Filename",34,",0/1",#d,#a
    defb 0


;TXT_CPCBNotDetected defb "CPC Booster not detected !",#d,#a,0
;TXT_NoComm defb "Unable to communicate. A Key to retry.",#d,#a,0
;TXT_Transf defb "Transfering... ",0
;TXT_Done defb "Done !",#d,#a,0


AK_Patch
    push af
    ld a,(#40)
    cp #84
    jr nz,AK_PRet
    ld a,(#41)
    or a
    jr nz,AK_PRet
    ld a,(#42)
    or a
    jr nz,AK_PRet
    ld (#40),a
AK_PRom ld c,0
    call #b90f
    ld a,c
    ld (AK_OldRom),a
    jp CATPrg
AK_PRet pop af
    ret
AK_PatchFin




WD_Copy
    ld hl,WR_ADROM
    ld de,WR_ADCODENORMAL
    ld bc,WR_CODEFIN-WR_CODEDEBUT
    ldir
    ld hl,CPCBooster_ADROM
    ld de,AD_CPCBooster
    ld bc,CPCB_CODEFIN-CPCB_CODEDEBUT
    ldir
    jp WR_CODEDEBUT
DIRDOS_Copy ld hl,WR_ADROM
    ld de,WR_ADCODENORMAL
    ld bc,WR_CODEFIN-WR_CODEDEBUT
    ldir
    jp DIRDOS
RD_Copy
;   call RD_Copy2
;   jp RD_CODEDEBUT
;RDP_Copy
;   call RD_Copy2
;   jp RDP_CODEDEBUT

;RD_Copy2
    ld hl,RD_ADROM
    ld de,RD_AD_CODENORMAL
    ld bc,RD_CODEFIN-RD_CODEDEBUT
    ldir
    ld hl,WR_ADROM
    ld de,WR_ADCODENORMAL
    ld bc,WR_CODEFIN-WR_CODEDEBUT
    ldir
    ld hl,CPCBooster_ADROM
    ld de,AD_CPCBooster
    ld bc,CPCB_CODEFIN-CPCB_CODEDEBUT
    ldir
    jp RD_CODEDEBUT
;   ret




    list
;**** Fin Boot
    nolist


    include "TestCrtc.asm"

    include "GetFile.asm"
    include "SendFile.asm"
    include "Header.asm"
    include "Burn.asm"
    include "Memory.asm"
    include "View.asm"
    include "Load.asm"










    list
;**** Debut CATPrg
    nolist



CATPrg
;   ret
;   jp AKSRomHelp


CATBUFF equ #9000       ;#200

    push bc
    push de
    push hl
    push ix

    call AK_FINDBuffCAT




    di
    ld hl,(#38)
    ld (AK_SAVE38),hl
    ld hl,#c9fb
    ld (#38),hl


;   ld a,2+64       ;Si shift non enfonce, normal cat.
;   call VW_ROUTOUCH
;   bit 5,a
;   jr nz,NORMALCAT

;       jp NORMALCAT

    ld hl,(#be7d)       ;Chope lecteur actuel
    ld a,(hl)
    ld (AK_LECTEUR),a

    ld a,(#be5f)
    or a
    jr nz,FDCAlreadyOn
         LD   BC,#FA7E
         LD   A,1
         OUT  (C),A
     EI
         LD   B,6*40
AK_WAIT  HALT 
         DJNZ AK_WAIT
         DI


    ld a,255
    ld (#be5f),a        ;Lecteur=on pour systeme
    ld hl,#100
    ld (#be69),hl

FDCAlreadyOn


;Si flag Systeme Recalibrate est a 0, on recalibre
    ld hl,(#be7d)
    ld de,#1a7
    add hl,de
    ld a,(hl)
    cp #ff
    jr z,AK_NORecalibr
    ld (hl),#ff
    call AK_RECALIBRATE
    call AK_RECALIBRATE
AK_NORecalibr



;Lis les 4 1ers secteurs a la recherche 
;   ld hl,(AK_BUFFCAT)
;   ld e,l
;   ld d,h
;   inc de
;   ld bc,#1ff
;   ld (hl),0
;   ldir

    ld a,#c1
    ld (AK_BOOTSECT),a
BOOTLOOP    
    call AK_READSECT
    or a            ;si erreur disc, laisse tomber.
    jr nz,NORMALCAT

    ld ix,(AK_BUFFCAT)
    ld de,16*2
    ld b,16

BOOTFIND ld a,(ix+13)
    cp #aa
    jr z,BOOTFOUND
    add ix,de
    djnz BOOTFIND

    ld a,(AK_BOOTSECT)
    inc a
    cp #c5
    jr z,NORMALCAT
    ld (AK_BOOTSECT),a
    jr BOOTLOOP
    

;Catalogue normal (erreur disc ou pas de boot trouvé).
NORMALCAT
;   call FDCOFF
    ld hl,(AK_SAVE38)
    ld (#38),hl
    ei

    ld hl,AK_NormQuitCode
    ld de,#be00
    ld bc,AK_NormQuitCodeFin-AK_NormQuitCode
    ldir
    jp #be00
    
;   call REINITBC9B

;   ld de,(AK_BUFFCAT)      ;Buffer de 2k pour CAT (donne par systeme)
;   call #bc9b

;   ld hl,OurCATHandle
;   ld (#bc9b+1),hl

AK_NormQuitCode
    ld a,(AK_OldRom)
    ld c,a
    call #b90f
    pop ix
    pop hl
    pop de
    pop bc
    pop af
    ret
AK_NormQuitCodeFin

;REINITBC9B
;   ld hl,(SysPtCATHandle)
;   ld (#bc9b+1),hl
;   ret


BOOTFOUND
    ld a,(ix+0)         ;Get User
    ld hl,(#be7d)
    inc hl
    ld (hl),a           ;Set User

    ld hl,AK_BootRunCode
    ld de,#be00
    ld bc,AK_BootRunCodeFin-AK_BootRunCode
    ldir

    push ix
    pop hl
    inc hl
    ld de,FNAME-AK_BootRunCode+#be00            ;Copie nom fichier
    ld b,8
    call COPYFNAME
    ld de,FEXT-AK_BootRunCode+#be00
    ld b,3
    call COPYFNAME

;   call REINITBC9B


    ld a,2+64
    call VW_ROUTOUCH
;   jr nz,NORMALCAT

    ld hl,(AK_SAVE38)
    ld (#38),hl
    ei

    bit 5,a     ;Si shift enfonce, boot.
    jp z,#be00

;Boot trouve mais pas shift = on ecrit 'Bootable disc'.
    ld hl,AK_TXT_BOOTABLE
    call PHRBB5A

;Affiche fichier boot
    ld hl,FNAME-AK_BootRunCode+#be00
BF_AffName ld a,(hl)
    inc hl
    cp 32
    jr z,BF_AffExt
    cp '.'
    jr z,BF_AffExt
    call #bb5a
    jr BF_AffName
BF_AffExt ld a,'.'
    call #bb5a

    ld a,(FEXT-AK_BootRunCode+#be00)
    call #bb5a
    ld a,(FEXT-AK_BootRunCode+#be00+1)
    call #bb5a
    ld a,(FEXT-AK_BootRunCode+#be00+2)
    call #bb5a


    jp NORMALCAT


AK_BootRunCode
;   ld a,(AK_OldRom)
;   ld c,a

    ld c,0
    call #b90f

    pop ix
    pop hl
    pop de
    pop bc
    pop af

    ld hl,INSTR-AK_BootRunCode+#be00
    di
    exx
    ld b,#7f
    res 3,c
    out (c),c
    exx
    ei
    jp #c0b4
INSTR   defb "run"
    defb #22
FNAME   defs 8,32
    defb "."
FEXT    defb "   "
    defb #22
    defb 0
INSTRF
AK_BootRunCodeFin

COPYFNAME ld a,(hl)
    and %01111111
    ld (de),a
    inc hl
    inc de
    djnz COPYFNAME
    ret



AK_FINDBuffCAT
    ld hl,(#ae5e)           ;6128 ou 664
    ld a,(#bd38)
    cp #88
    jr nz,CAT6128
    ld hl,(#ae7b)           ;464
CAT6128 ld de,#800
    or a
    sbc hl,de
    ld (AK_BUFFCAT),hl
    ret





AK_READSECT

;Gotopist
    LD   A,%00001111
        CALL AK_PUTFDC
        LD   A,(AK_LECTEUR)
        CALL AK_PUTFDC                  ;Envoie ID lecteur
    xor a               ;piste 0
    CALL AK_PUTFDC
    call AK_WEND


         LD   A,%01000110
         CALL AK_PUTFDC
         LD   A,(AK_LECTEUR)
         CALL AK_PUTFDC
    xor a           ;piste
         CALL AK_PUTFDC
    xor a           ;head
         CALL AK_PUTFDC
    ld a,(AK_BOOTSECT)      ;ID sect
         CALL AK_PUTFDC
    ld a,2          ;Taille sect
         CALL AK_PUTFDC
    ld a,(AK_BOOTSECT)      ;dernier sect a lire
         CALL AK_PUTFDC
    LD   A,#4e
         CALL AK_PUTFDC
         LD   A,#FF                     ;long eff sect
         CALL AK_PUTFDC

    LD   BC,#FB7E
    ld hl,(AK_BUFFCAT)
;
AK_RSLOOP
         IN   A,(C)
         JP   P,$-3
         AND  %00100000
         JR   Z,AK_RSFIN
         INC  C
         INI
     INC  B
         DEC  C
         JR   AK_RSLOOP
AK_RSFIN
    call AK_GETFDC
    ld (AK_ST0),a
    call AK_GETFDC
    ld (AK_ST1),a
    call AK_GETFDC
    ld (AK_ST2),a

    ld l,4
AK_RSFI2 CALL AK_GETFDC
    dec l
    jr nz,AK_RSFI2

         LD   A,(AK_ST0)
    and %10011000
    ld b,a
         LD   A,(AK_ST1)
         AND  %00110111
    ld c,a
         LD   A,(AK_ST2)
         AND  %00110000
    or b
    or c
    ret


AK_RECALIBRATE
    LD   A,%00000111
         CALL AK_PUTFDC
         LD   A,(AK_LECTEUR)
         CALL AK_PUTFDC                    ;Envoie ID lecteur

;Waitend
AK_WEND  LD   A,%00001000
         CALL AK_PUTFDC
         CALL AK_GETFDC                    ;Recoit ST0
     ld l,a
         CALL AK_GETFDC                    ;Recoit no piste courante
         BIT  5,l                       ;Instruction finie ?
         JR   Z,AK_WEND
     ret



;A=data  a envoyer
AK_PUTFDC
    ld h,a
         LD   BC,#FB7E
         IN   A,(C)
         JP   P,$-3
     inc c
         OUT  (C),h
         RET  
;
;Recois  une data du FDC
;Ret =   A=data FDC
AK_GETFDC
         LD   BC,#FB7E
         IN   A,(C)
         JP   P,$-3
     inc c
         IN   A,(C)
         RET  









;Set un boot sur un fichier
;ùsetboot,"filename",0/1
SetBoot_Debut
    cp 2
    jr z,SB_NbPOk
SB_AffTXT ld hl,SB_TXT
SB_ErrAff ei
    call PHRBB5A
SB_Quit call #bc7a
    ret
SB_NbPOk

    call AK_FINDBuffCAT


;Get 0/1
    ld b,0
    ld a,(ix+0)
    or a
    jr z,SB_Val0
    ld b,#aa
    cp 1
    jr nz,SB_AffTXT
SB_Val0 ld a,b
    ld (AK_BootVal),a

;Get Filename
    ld e,(ix+2)
    ld d,(ix+3)
    defb #dd 
  ld l,e
    defb #dd 
  ld h,d

    ld l,(ix+1)
    ld h,(ix+2)
    ld b,(ix+0)
    ld de,#f000     ;Rien ne va etre ecrit, on peut mettre ca n'importe ou.
    call #bc77
    jp nc,SB_FileNotFound
;   ld (SB_PTFilename),hl
    
    di

;        LD   BC,#FA7E
;        LD   A,1
;        OUT  (C),A





;Lis les 4 1ers secteurs a la recherche du nom de fichier
    ld hl,(#be7d)       ;Chope lecteur actuel
    ld a,(hl)
    ld (AK_LECTEUR),a
    ld de,9         ;Chope nom de fichier Openin
    add hl,de
    ld (SB_PTFilename),hl

    ld a,#c1
    ld (AK_BOOTSECT),a

SB_FILELOOP
    call AK_READSECT
    or a
    jp nz,SB_ReadFail       ;si erreur disc, laisse tomber.

    ld ix,(AK_BUFFCAT)
    ld de,16*2
    ld b,16

SB_FILEFIND         ;Compare user+filename avec celui de cette ligne du secteur.
    ld hl,(SB_PTFilename)
    call SB_CompareNames
    jr c,SB_FILEFOUND
    add ix,de
    djnz SB_FILEFIND

    ld a,(AK_BOOTSECT)
    inc a
    cp #c5
    jr z,SB_FileNotFound
    ld (AK_BOOTSECT),a
    jr SB_FILELOOP



;On set le flag 'boot' dans l'entree du fichier.
;Puis on ecrit le secteur.
SB_FILEFOUND
;   ld bc,#7f10
;   out (c),c
;   ld a,#4b
;   out (c),a

    ld a,(AK_BootVal)
    ld (ix+13),a

    call SB_WriteSect
    jr nz,SB_WriteFail

    ei
    jp SB_Quit




SB_WriteSect
    ld a,%01000101      ;Code instruction 'ecriture secteur'
    CALL AK_PUTFDC
         LD   A,(AK_LECTEUR)
         CALL AK_PUTFDC
    xor a              ;No piste
         CALL AK_PUTFDC
    xor a       ;head
         CALL AK_PUTFDC
    ld a,(AK_BOOTSECT)              ;ID sect
         CALL AK_PUTFDC
    ld a,2                       ;Taille sect
         CALL AK_PUTFDC
    ld a,(AK_BOOTSECT)               ;dernier sect a lire
         CALL AK_PUTFDC
    ld a,#4e            ;gap
         CALL AK_PUTFDC
         LD   A,#ff                     ;long eff sect
         CALL AK_PUTFDC
;
;On      recupere les donnees du sect
         LD   BC,#FB7E
     ld hl,(AK_BUFFCAT)
;
; Boucle qui ecrit les donnees du sect
SB_WSLOOP
         IN   A,(C)
         JP   P,$-3
         AND  %00100000
         JP   Z,AK_RSFIN
         INC  C
         LD   A,(hl)
         OUT  (C),A
     inc hl
         DEC  C
         JR   SB_WSLOOP







;Compare le user+filename IX=header  HL=filename
SB_CompareNames
    push bc
    push ix

    ld b,13
;
SB_CNLoop
    ld a,(ix+0)
    and %01111111       ;enleve flag eventuel
    ld c,(hl)
    res 7,c         ;enleve flag eventuel
    cp c
    jr nz,SB_CNFail
;
    inc hl
    inc ix
    djnz SB_CNLoop

    pop ix
    pop bc
    scf
    ret
SB_CNFail
    pop ix
    pop bc
    or a
    ret

SB_FileNotFound ld hl,SB_TXT_FileNotFound
    jp SB_ErrAff
SB_ReadFail ld hl,SB_TXT_ReadFail
    jp SB_ErrAff
SB_WriteFail ld hl,SB_TXT_WriteFail
    jp SB_ErrAff


SB_TXT  defb 124,"SETBOOT,",34,"Filename",34,",0/1",#d,#a
    defb 0
SB_TXT_FileNotFound defb "File Not Found.",#d,#a,0
SB_TXT_ReadFail defb "Read Fail.",#d,#a,0
SB_TXT_WriteFail defb "Write Fail.",#d,#a,0

AK_TXT_BOOTABLE defb #d,#a,"Boot found : ",0








AK_SAVE38 equ #be3a ;word
AK_LECTEUR equ #be38
AK_BOOTSECT equ #be37
AK_BUFFCAT equ #be35    ;word
AK_OldRom equ #be34
AK_ST0  equ #be33
AK_ST1  equ #be32
AK_ST2  equ #be31
AK_BootVal equ #be30    ;0 ou #AA
SB_PTFilename equ #be2e ;word. Pointe sur User+filename (1+8+3)
;COUL equ #be2d


    list
;**** Fin code Rom
    nolist


CPCBooster_ADROM
    ; org AD_CPCBooster, CPCBooster_ADROM XXX Original code for winape
    org AD_CPCBooster
    include "CPCBooster.asm"

    include "WriteDSK.asm"
    include "ReadDsk.asm"




