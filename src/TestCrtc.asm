; Test CRTC version 3.0
; (12/01/2005) par OffseT (Futurs')


; Réalisé entièrement sur un véritable CPC
; Plus aucun registre du CRTC n'est modifié durant les tests !

; L'historique...

; Test CRTC version 1.1
;   - Test originel (23.02.1992) par Longshot (Logon System)
;   ce test CRTC est celui cr{e par Longshot et utilisé dans la
;   plupart des démos du Logon System.

; Test CRTC version 1.2
;   - Amélioration de la d{tection Asic (02/08/1993) par OffseT
;   le test bas{ sur la d{tection de la page I/O Asic qui
;   imposait de d{locker l'Asic a été remplacé par un test
;   des vecteurs d'interruption (mode IM 2). Le d{lockage de
;   l'Asic n'est plus nécessaire.
;   bug connu ; ce test ne fonctionne pas nécessairement sur un
;   CPC customisé (notamment avec une interface gérant les
;   interruptions en mode vectoris{) ou sur un CPC+ dont le registre
;   Asic IVR a préalablement été modifié.
;   - Correction du bug de d{tection CRTC 1 (18/06/1996) par OffseT
;   sous certaines conditions de lancement le CRTC 1 était détecté
;   comme {tant un CRTC 0 (on peut constater ce bug dans The Demo
;   et S&KOH). La méthode de synchronisation pour le test de d{éection
;   VBL a été fiabilisée et ce problème ne devrait plus survenir.

; - Test CRTC version 2.0
;   - Ajout d'un test émulateur (03/01/1997) par OffseT
;   ce test est basé sur la détection d'une VBL médiane lors de
;   l'activation du mode entrelacé. Les émulateurs n'émulent pas
;   cette VBL.
;   limitation systématique ; ce test ne permet pas de distinguer
;   un véritable CRTC 2 d'un CRTC 2 émulé.

; - Test CRTC version 3.0
;   - Retrait du test émulateur (20/12/2004) par OffseT
;       ce test ne pr{sente aucun int{ret r{el et a le d{savantage
;   de provoquer une VBL parasite pendant une frame.
;   - Remplacement du test Asic (29/12/2004) par OffseT
;   le nouveau test est bas{ sur la d{tection du bug de validation
;   dans le PPI émulé par l'Asic plutot que sur les interruptions
;   en mode IM 2. C'est beaucoup plus fiable puisque \a ne d{pend
;   plus du tout de l'état du registre IVR ni des extensions g{rant
;   les interruptions connectées sur le CPC. Merci @ Ram7 pour  l'astuce.
;   Limitation systématique ; l'état courant de configuration des ports
;   du PPI est perdue, mais \a ne pose normalement aucun problème.
;   - Remplacement du test CRTC 1 et 2 (29/12/2004) par OffseT
;   le test originel de Longshot était basé sur l'inhibition de
;   la VBL sur Type 2 lorsque Reg2+Reg3>Reg0+1. Ce test modifiait
;   les réglages CRTC et l'{cran sautait pendant une frame. Il a été
;   remplacé par un test basé sur la détection du balayage du Border
;   spécifique au Type 1 qui n'a pas ces inconv{nients.
;   bug connu (rarissime) ; ce test renvoie un résultat erroné sur
;   CRTC 1 si reg6=0 ou reg6>reg4+1... ce qui est fort improbable.
;   - Modification du test CRTC 3 et 4 (29/12/2004) par OffseT
;   le test ne modifie plus la valeur du registre 12. Toutefois
;   il en teste la cohérence et vérifie également le registre 13.
;   limitation (rare) ; ce test ne fonctionne pas si reg12=reg13=0.
;   - Réorganisation générale des tests (29/12/2004) par OffseT
;   chaque test est désormais un module qui permet, par le biais
;   d'un système de masques de tests, de différencier les CRTC au
;   fur et @ mesure.
;   - Retrait des dépendances d'interruption (29/12/2004) par OffseT
;   plus aucun test ne fait usage des interruptions pour se synchroniser.
;   - Ajout d'un test de lecture du port 0xBFxx (29/12/2004) par OffseT
;   ce test permet de différencier les CRTC 1 et 2 des autres et vient
;   en complément du test (historique) sur le timing VBL.
;   limitation (rare) ; ce test ne fonctionne pas si reg12=re13=0.
;   - Ajout d'un test de lecture des registres 4 et 5 (30/12/2004) par OffseT
;   ce test donne théoriquement les memes r{éultats que le test
;   initial de d{tection 3 et 4 bas{ sur des lectures sur le port
;   0xBExx ; il consiste @ lire les registres 12 et 13 via leur miroir
;   sur l'adressage des registres 4 et 5 sur Type 3 et 4.
;   limitation (rare) ; ce test ne fonctionne pas si reg12=reg13=0.
;   - Ajout d'un test de lectures CRTC ill{gales (12/01/2005) par OffseT
;   ce test vérifie qu'on obtient bien la valeur 0 en retour
;   lors d'une tentative de lecture ill{gale d'un registre du
;   CRTC en ecriture seule. Ceci permet de différencier les Types
;   0, 1 et 2 des Types 3 et 4.
;   - Ajout d'un test du port B du PPI (12/01/2005) par OffseT
;   ce test vérifie si le port B peut-etre configuré en sortie.
;   Ceci permet d'identifier le Type 3.
;   Limitation systématique ; l'état courant de configuration des ports
;   du PPI est perdue, mais \a ne pose normalement aucun problème.
;   - Ajout d'un test de d{tection de fin de VBL (12/01/2005) par OffseT
;   ce test vérifie que le bit 5 du registre 10 du CRTC permet bien
;   de détecter la dernière ligne de VBL sur les CRTC 3 et 4. Ceci
;   permet de diff{rencier les Types 0, 1 et 2 des Types 3 et 4.
;   bug syst{matique ; si le bit 7 du registre 3 est @ zéro (double VBL)
;   le test renvoie un mauvais r{sultat.
;   - Ajout d'un test de lecture du registre 31 (12/01/2005) par OffseT
;   ce test vérifie sur la valeur en lecture renvoy{e pour ce registre
;   est non nulle. Si c'est le cas \a veut dire qu'on a lu soit un état
;   de haute impédance (cas du Type 1) soit le registre 15 qui était non
;   nul (cas des Types 3 et 4). On peut alors conclure que l'on a ni un
;   Type 0, ni un Type 2. Si la valeur est nulle on ne peut rien conclure
;   et le test est inopérant. 
;   limitation rarissime ; ce test ne fournit pas de résultat sur Type 1
;   si l'état de haute impédance est altéré
;   limitation courante ; ce test ne fournit pas de résultat sur Types 3
;   et 4 si le registre 15 est nul (ce qui est la valeur par défaut)
;   - Ajout d'un test de d{tection des blocs 0 et 1 (12/01/2005) par OffseT
;   ce test vérifie que la d{tection des blocs 0 et 1 est fonctionnelle
;   sur les Types 3 et 4 @ l'aide des flags du registre 11 du CRTC. Ceci
;   permet de différencier les Types 0,1,2 des 3,4.
;   limitation syst{matique ; le registre 9 doit valoir 7 sinon le
;   résultat est faux.

; Note ; une limitation décrit un cas dans lequel le test ne renvoie
; aucun résultat (il ne parvient pas @ distinguer les CRTC) alors qu'un
; bug connu décrit un cas dans lequel le test peut renvoyer une mauvaise
; réponse (ce qui est beaucoup plus grave !).

; Les différents Types de CRTC connus...

; 0 ; 6845SP        ; sur la plupart des CPC6128 sortis entre 85 et 87
; 1 ; 6845R     ; sur la plupart des CPC6128 sortis entre 88 et 89
; 2 ; 6845S     ; sur la plupart des CPC464 et CPC664
; 3 ; Emul{ (CPC+)  ; sur les 464 plus et 6128 plus
; 4 ; Emul{ (CPC old)   ; sur la plupart des CPC6128 sortis en 89 et 90.


; Le programme qui utilise le test CRTC...

; Le test CRTC...

; Attention ! Le CRTC doit etre dans une configuration
; rationnelle pour que les tests fonctionnent (VBL et
; HBL pr{sentes, registres 6 et 1 non nuls, bit 7 du
; registre 3 non nul, etc.)

; En sortie A contient le Type de CRTC (0 @ 4)
; A peut valoir 0xf si le CRTC n'est pas reconnu
; (mauvais émulateur CPC ou mauvaise configuration
; CRTC au lancement du test)

TestCRTC
    ld a,0xff
    ld (TypeCRTC),a
    di                      ; CRTC 0,1,2,3,4
    call TestLongueurVBL    ;      0,1,1,0,0
    ;call TestBFxx          ;      0,1,1,0,0,alien
    call TestBExx           ;      0,0,0,1,1,alien
    ;call TestFinVBL        ;      0,0,0,1,1,alien
    ;call TestR4R5          ;      0,0,0,1,1,alien
    call TestRegsWO         ;      0,0,0,1,1
    ;call TestBloc          ;      0,0,0,1,1,alien
    call TestBorder         ;      0,1,0,0,0
    call TestRAZPPI         ;      0,0,0,1,0,alien
    ;call TestPortBPPI      ;      0,0,0,1,0
    ;call TestReg31         ;      x,1,x,1,1
    ei
    ld a,(TypeCRTC)
   
     cp CRTC0
    jr z,Type_0
    
     cp CRTC1
    jr z,Type_1
   
     cp CRTC2
    jr z,Type_2
   
     cp CRTC3
    jr z,Type_3
   
     cp CRTC4
    jr z,Type_4
   
     ld a,0xf
    ret
   
Type_0  ld a,'0'
    ret

Type_1  ld a,'1'
    ret

Type_2  ld a,'2'
    ret

Type_3  ld a,'3'
    ret

Type_4  ld a,'4'
    ret



; Test basé sur la mesure de la longueur de VBL
; Permet de différencier les Types 1,2 des 0,3,4

; Bug systématique
;   si le bit 7 du registre 3 est @ zéro (double VBL)
;   le test renvoie un mauvais r{sultat

TestLongueurVBL
    ld b,0xf5    ; Boucle d'attente de la VBL
SyncTLV1
    in a,(c)
    rra
    jr nc,SyncTLV1
NoSyncTLV1
    in a,(c)    ; Pre-Synchronisation
    rra     ; Attente de la fin de la VBL
    jr c,NoSyncTLV1
SyncTLV2
    in a,(c)    ; Deuxième boucle d'attente
    rra     ; de la VBL
    jr nc,SyncTLV2

    ld hl,140   ; Boucle d'attente de
WaitTLV dec hl      ; 983 micro-secondes
    ld a,h
    or l
    jr nz,WaitTLV
    in a,(c)    ; Test de la VBL
    rra     ; Si elle est encore en cours
    jp c,Type12 ; on a un Type 1,2...
    jp Type034  ; Sinon on a un Type 0,3,4


    if 0
; Test basé sur la lecture des registres 12 et 13
; sur le port 0xBFxx
; Permet de différencier les Types 0,3,4 et 1,2

; Limitation rare
;   si reg12=reg13=0 le test est sans effet

TestBFxx
    ld bc,0xbc0c ; On sélectionne le reg12
    out (c),c
    ld b,0xbf    ; On lit sa valeur
    in a,(c)
    ld c,a      ; si les bits 6 ou 7 sont
    and 0x3f     ; non nuls alors on a un
    cp c        ; problème
    jp nz,TypeAlien
    ld a,c
    or a        ; si la valeur est non nulle
    jp nz,Type034   ; alors on a un Type 0,3,4
    ld bc,0xbc0d
    out (c),c   ; On sélectionne le reg13
    ld b,0xbf
    in a,(c)    ; On lit sa valeur
    or a        ; Si la valeur est non nulle
    jp nz,Type034   ; alors on a un Type 0,3,4
    ret

    endif


; Test basé sur la lecture des registres 12 et 13
; @ la fois sur les ports 0xBExx et 0xBFxx
; Permet de diff{rencier les Types 0,1,2 des 3,4

; Limitation rare
;   si reg12=reg13=0 le test est sans effet

TestBExx
    ld bc,0xbc0c ; On sélectionne le registre 12
    out (c),c   ; On compare les valeurs sur
    call CPBEBF ; les ports 0xBExx et 0xBFxx
    push af     ; (on sauve les flags)
    ld b,a      ; Si le bit 6 ou 7 de la valeur
    and 0x3f     ; lue pour 0xBFxx est non nul
        cp b        ; alors on a un probl}me
    call nz,TypeAlien
    pop af      ; (on récupère les flags)
    jp nz,Type012   ; Si elles sont diff{rentes
    xor a       ; on a un Type 0,1,2
    cp c        ; Si elles sont égales et
    jp nz,Type34    ; non nulles on a un Type 3,4
    ld bc,0xbc0d ; On sélectionne le registre 13
    out (c),c   ; On compare les valeurs sur
    call CPBEBF ; les ports 0xBExx et 0xBFxx
    jp nz,Type012   ; Si elles sont diff{rentes
    xor a       ; on a un Type 0,1,2
    cp c        ; Si elles sont {gales et
    jp nz,Type34    ; non nulles on a un Type 3,4
    ret

CPBEBF  ld b,0xbe    ; On lit la valeur sur 0xBExx
    in a,(c)
    ld c,a      ; On la stocke dans C
    inc b
    in a,(c)    ; On lit la valeur sur 0xBFxx
    cp c        ; On la compare @ C
    ret


; Test bas{ sur la RAZ du PPI
; Permet de différencier les Types 0,1,2,4 du 3

; Limitation systématique
;   l'état courant de configuration des ports
;   du PPI est perdu

TestRAZPPI
    ld bc,0xf782 ; On configure le port C
    out (c),c   ; en sortie
    dec b
    ld c,0xf     ; On place une valeur sur
    out (c),c   ; le port C du PPI
    in a,(c)    ; On v{rifie si la valeur est
    cp c        ; toujours l@ en retour
    jp nz,TypeAlien ; sinon on a un probl}me
    inc b
    ld a,0x82    ; On configure de nouveau
    out (c),a   ; le mode de fonctionnement
    dec b       ; des ports PPI
    in a,(c)    ; On teste si la valeur plac{e
    cp c        ; sur le port C est toujours l@
    jp z,Type3  ; Si oui on a un Type 3
    or a        ; Si elle a {t{ remise @ z{ro
    jp z,Type0124   ; on a un Type 0,1,2,4
    jp TypeAlien    ; Sinon on a un probl}me


; Test basé sur la d{tection du balayage des lignes
; hors Border
; Permet d'identifier le Type 1

; Bug connu rarissime
;   si reg6=0 ou reg6>reg4+1 alors le test est fauss{ !

TestBorder
    ld b,0xf5
NoSyncTDB1
    in a,(c)    ; On attend un peu pour etre
    rra     ; sur d'etre sortis de la VBL
    jr c,NoSyncTDB1 ; en cours du test pr{c{dent
SyncTDB1
    in a,(c)    ; On attend le d{but d'une
    rra     ; nouvelle VBL
    jr nc,SyncTDB1
NoSyncTDB2
    in a,(c)    ; On attend la fin de la VBL
    rra
    jr c,NoSyncTDB2

    ld ix,0     ; On met @ z{ro les compteurs
    ld hl,0     ; de Changement de valeur (IX),
    ld d,l      ; de ligne hors VBL (HL) et
    ld e,d      ; de ligne hors Border (DE)
    ld b,0xbe
    in a,(c)
    and 32
    ld c,a

SyncTDB2
    inc de      ; On attend la VBL suivante
    ld b,0xbe    ; en mettant @ jour les divers
    in a,(c)    ; compteurs
    and 32
    jr nz,Border
    inc hl      ; Ligne de paper !
    jr NoBorder
Border  ds 4
NoBorder
    cp c
    jr z,NoChange
    inc ix      ; Transition paper/Border !
    jr Change
NoChange
    ds 5
Change  ld c,a

    ds 27

    ld b,0xf5
    in a,(c)
    rra
    jr nc,SyncTDB2  ; On boucle en attendant la VBL

   
     db 0xdd
    ld a,l   ; Si on n'a pas eu juste deux
    
    cp 2        ; transitions alors ce n'est
    jp nz,Type0234  ; pas un Type 1
    jp Type1    ; Pour plus de fiabilit{ au
            ; regard de l'{tat de haute
            ; imp{dance sur les CRTC autres
            ; que le Type 1 on pourrait
            ; v{rifier ici que HL vaut
            ; reg6*(reg9+1) mais \a impose
            ; de connaitre au pr{alable la
            ; valeur de ces deux registres


    if 0
; Test bas{ sur la lecture des registres 4 et 5
; Permet de diff{rencier les Types 0,1,2 des 3,4

; Limitation rare
;   si reg12=reg13=0 le test est sans effet

TestR4R5
    ld bc,0xbc0c ; On s{lectionne le registre 12
    out (c),c   ; On compare les valeurs en
    call CPRHRL ; retour sur le port 0xBFxx
    push af     ; On sauve les flags
    ld b,a      ; Si le bit 6 ou 7 de la valeur
    and 0x3f     ; lue pour 0xBFxx est non nul
        cp b        ; alors on a un probl}me
    call nz,TypeAlien
    pop af      ; On r{cup}re les flags
    jp nz,Type012   ; Si elles sont diff{rentes
    xor a       ; on a un Type 0,1,2
    cp c        ; Si elles sont {gales et
    jp nz,Type34    ; non nulles on a un Type 3,4
    ld bc,0xbc0d ; On s{lectionne le registre 13
    out (c),c   ; On compare les valeurs en
    call CPRHRL ; retour sur le port 0xBFxx
    jp nz,Type012   ; Si elles sont diff{rentes
    xor a       ; on a un Type 0,1,2
    cp c        ; Si elles sont {gales et
    jp nz,Type34    ; non nulles on a un Type 3,4
    ret

CPRHRL  ld b,0xbf    ; On lit la valeur du registre
    in a,(c)    ; High sur 0xBFxx
    ld b,0xbc    ; S{lection du registre Low
    res 3,c     ; On passe sur le registre Low
    out (c),c
    ld c,a      ; On la stocke dans C
    ld b,0xbf
    in a,(c)    ; On lit la valeur sur 0xBFxx
    cp c        ; On la compare @ C
    ret

    endif


; Test bas{ sur la valeur de retour sur les registres
; CRTC en {criture seule
; Permet de diff{rencier les Types 0,1,2 des Types 3,4

; Aucune limitation/bug connus

TestRegsWO
    ld de,0     ; On lance le parcours des
    ld c,12     ; registres 0 @ 11 avec
    call CumuleReg  ; cumul de la valeur retour
    xor a       ; Si le r{sultat cumul{ de
    cp d        ; la lecture est non nul
    jp nz,Type34    ; alors on a un Type 3,4
    jp Type012  ; Sinon, c'est un Type 0,1,2
CumuleReg
LoopTRI ld b,0xbc    ; On s{lectionne le
    out (c),e   ; registre "E"
    ld b,0xbf    ; On lit la valeur
    in a,(c)    ; renvoy{e en retour
    or d        ; On la cumule dans D avec
    ld d,a      ; les lectures pr{c{dentes
    inc e       ; On boucle jusqu'au
    ld a,e      ; registre "C"
    cp c
    jr nz,LoopTRI
        ret


        if 0
; Test bas{ sur la possibilit{ de programmer le port B
; en sortie
; Permet d'identifier le Type 3

; Limitation syst{matique
;   l'{tat courant de configuration des ports
;   du PPI est perdu

TestPortBPPI
    ld b,0xf5
SyncTPBP1
    in a,(c)
    rra
    jr nc,SyncTPBP1
NoSyncTPBP1
    in a,(c)    ; Pre-Synchronisation
    rra     ; Attente de la fin de la VBL
    jr c,NoSyncTPBP1
    ld bc,0xf782 ; On configure le port B
    out (c),c   ; du PPI en entr{e
    ld b,0xf5    ; On lit la valeur pr{sente
    in a,(c)    ; sur le port B puis on
    xor 254     ; la modifie judicieusement
    ld e,a      ; et on la stocke dans E
    ld d,0xf5
    ld bc,0xf780 ; On configure le port B
    out (c),c   ; du PPI en sortie
    ld b,d      ; On y envoie la valeur
    out (c),e   ; stock{e dans E
    in a,(c)    ; On relit le port B
    ld bc,0xf782 ; On reconfigure le port B
    out (c),c   ; du PPI en entr{e
    cp e        ; Si la valeur E a {t{ lue
    jp z,Type0124   ; alors on a Type 0,1,2,4
    jp Type3    ; Sinon on a un Type 3

    endif


    if 0
; Test bas{ sur la d{tection de la derni}re
; ligne de VBL
; Permet de diff{rencier les Types 0,1,2 des 3,4

; Bug syst{matique
;   si le bit 7 du registre 3 est @ z{ro (double VBL)
;   le test renvoie un mauvais r{sultat)

TestFinVBL
    ld bc,0xbc0a ; On s{lectionne le
    out (c),c   ; registre 10 du CRTC
    ld b,0xf5
NoSyncTFV1
    in a,(c)    ; Pre-Synchronisation
    rra     ; Attente de la fin de la VBL
    jr c,NoSyncTFV1

    ld b,0xbf    ; On lit l'{tat du registre 10
    in a,(c)
    and 32      ; Si le bit5 est nul alors
    jp z,Type012    ; on a un Type 0, 1 ou 2

    ld b,0xf5
SyncTFV2
    in a,(c)    ; Boucle d'attente de la VBL
    rra
    jr nc,SyncTFV2

    ld hl,55    ; Boucle d'attente de
WaitTfV dec hl      ; 388 micro-secondes
    ld a,h
    or l
    jr nz,WaitTfV

    ld b,0xbf    ; On lit l'{tat du registre 10
    in a,(c)
    and 32      ; Si le bit5 est nul
    jp z,TypeAlien  ; on a un probl}me

    ld b,13     ; Boucle d'attente de
    djnz $      ; 54 micro-secondes

    ld b,0xbf    ; On lit l'{tat du registre 10
    in a,(c)
    and 32      ; Si le bit5 est non nul
    jp nz,TypeAlien ; on a un probl}me

    ld b,13     ; Boucle d'attente de
    djnz $      ; 54 micro-secondes

    ld b,0xbf    ; On lit l'{tat du registre 10
    in a,(c)
    and 32      ; Si le bit5 est non nul
    jp nz,Type34    ; on a un Type 3 ou 4
    jp TypeAlien    ; Sinon on a un probl}me

    endif


    if 0
; Test bas{ sur le statut particulier du registre 31
; Permet d'identifier les Types 1, 3 et 4

; Limitation rarissime
;   ce test ne fournit pas de r{sultat sur Type 1
;   si l'{tat de haute imp{dance est alt{r{
; Limitation courante
;   ce test ne fournit pas de r{sultat sur Types 3 et 4
;   si le registre 15 est nul (ce qui est la valeur par
;   d{faut)

TestReg31
    ld bc,0xbc1f ; On s{lectionne le registre 31
    out (c),c   ; et on fait une tentative de
    ld b,0xbf    ; lecture sur le port 0xbfxx
    in a,(c)    ; Si on a une valeur non nulle
    jp nz,Type134   ; alors c'est un Type 1,3,4
    ret     ; sinon on ne peut rien
            ; conclure

    endif

    if 0
; Test bas{ sur la d{tection des blocs 0 et 1
; Permet de diff{rencier les Types 0,1,2 des 3,4

; Limitation syst{matique
;   le registre 9 doit valoir 7 sinon le r{sultat
;   est faux

TestBloc
    ld bc,0xbc0b ; On s{lectionne le
    out (c),c   ; registre 10 du CRTC
    ld b,0xf5
NoSyncTB1
    in a,(c)    ; Pre-Synchronisation
    rra     ; Attente de la fin de la VBL
    jr c,NoSyncTB1
SyncTB2 in a,(c)    ; Boucle d'attente de la VBL
    rra
    jr nc,SyncTB2
NoSyncTB2
    in a,(c)
    rra     ; Attente de la fin de la VBL
    jr c,NoSyncTB2

    ld b,0xbf    ; On lit l'{tat du registre 11
    in a,(c)    ; (on est sur le bloc 1)
    ld d,a

    ld b,14     ; On attend 58 micro-secondes
    djnz $

    ld b,0xbf
    in a,(c)    ; On lit l'{tat du registre 11
    ld c,a      ; (on est sur le bloc 2)

    ld b,96     ; On attend 386 micro-secondes
    djnz $

    ld b,0xbf
    in a,(c)    ; On lit l'{tat du registre 11
    ld e,a      ; (on est sur le bloc 0)
    or d        ; Si on n'a pas lu une valeur
    or e        ; nulle @ chaque fois alors
    jr nz,TBActif   ; on peut continuer
    jp Type012  ; Sinon on a un Type 0, 1 ou 2
TBActif ld a,0xa0    ; Si pour le bloc 0 on n'a pas
    and e       ; bit7=0 et bit5=0
    jp nz,TypeAlien ; alors on a un probl}me
    ld a,0xa0    ; Si pour le bloc 1 on n'a pas
    and d       ; bit7=1 et bit5=1
    cp 0xa0      ; alors on a un probl}me
    jp nz,TypeAlien
    ld a,0xa0    ; Si pour le bloc 2 on n'a pas
    and c       ; bit7=0 et bit5=1
    cp 0x20      ; alors on a un probl}me
    jp nz,TypeAlien
    jp Type34   ; Sinon on a un Type 3 ou 4

    endif


; Routines de typage

CRTC0   EQU 1
CRTC1   EQU 2
CRTC2   EQU 4
CRTC3   EQU 8
CRTC4   EQU 16

Type012 ld a,(TypeCRTC)
    and CRTC0+CRTC1+CRTC2
    ld (TypeCRTC),a
    ret
Type0124
    ld a,(TypeCRTC)
    and CRTC0+CRTC1+CRTC2+CRTC4
    ld (TypeCRTC),a
    ret
Type0234
    ld a,(TypeCRTC)
    and CRTC0+CRTC2+CRTC3+CRTC4
    ld (TypeCRTC),a
    ret
Type034 ld a,(TypeCRTC)
    and CRTC0+CRTC3+CRTC4
    ld (TypeCRTC),a
    ret
Type1   ld a,(TypeCRTC)
    and CRTC1
    ld (TypeCRTC),a
    ret
Type12  ld a,(TypeCRTC)
    and CRTC1+CRTC2
    ld (TypeCRTC),a
    ret
Type134 ld a,(TypeCRTC)
    and CRTC1+CRTC3+CRTC4
    ld (TypeCRTC),a
    ret
Type3   ld a,(TypeCRTC)
    and CRTC3
    ld (TypeCRTC),a
    ret
Type34  ld a,(TypeCRTC)
    and CRTC3+CRTC4
    ld (TypeCRTC),a
    ret
TypeAlien
    xor a
    ld (TypeCRTC),a
    ret

; Variables

TypeCRTC equ #be37
