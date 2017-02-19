	Nolist

; Test CRTC version 3.0 lite d{di{ @ Targhan (01/03/2005)




; R{alis{ enti}rement sur un v{ritable CPC
; Plus aucun registre du CRTC n'est modif{ durant les tests !

; L'historique...

; Test CRTC version 1.1
;   - Test originel (23.02.1992) par Longshot (Logon System)
;	ce test CRTC est celui cr{e par Longhost et utilis{ dans la
;	plupart des d{mos du Logon System.

; Test CRTC version 1.2
;   - Am{lioration de la d{tection Asic (02/08/1993) par OffseT
;	le test bas{ sur la d{tection de la page I/O Asic qui
;	imposait de d{locker l'Asic a {t{ remplac{ par un test
;	des vecteurs d'interruption (mode IM 2). Le d{lockage de
;	l'Asic n'est plus n{cessaire.
;	bug connu ; ce test ne fonctionne pas n{cessairement sur un
;	CPC customis{ (notamment avec une interface g{rant les
;	interruptions en mode vectoris{) ou sur un CPC+ dont le registre
;	Asic IVR a pr{alablement {t{ modifi{.
;   - Correction du bug de d{tection CRTC 1 (18/06/1996) par OffseT
;	sous certaines conditions de lancement le CRTC 1 {tait d{tect{
;	comme {tant un CRTC 0 (on peut constater ce bug dans The Demo
;	et S&KOH). La m{thode de synchronisation pour le test de d{tection
;	VBL a {t{ fiabilis{e et ce probl}me ne devrait plus survenir.

; - Test CRTC version 2.0
;   - Ajout d'un test {mulateur (03/01/1997) par OffseT
;	ce test est bas{ sur la d{tection d'une VBL m{diane lors de
;	l'activation du mode entrelac{. Les {mulateurs n'{mulent pas
;	cette VBL.
;	limitation syst{matique ; ce test ne permet pas de distinguer
;	un v{ritable CRTC 2 d'un CRTC 2 {mul{.

; - Test CRTC version 3.0 lite
;   - Retrait du test {mulateur (20/12/2004) par OffseT
;       ce test ne repr{sente aucun int{ret r{el et a le d{savantage
;	de provoquer une VBL parasite pendant une frame.
;   - Remplacement du test Asic (29/12/2004) par OffseT
;	le nouveau test est bas{ sur la d{tection du bug de validation
;	dans le PPI {mul{ par l'Asic plutot que sur les interruptions
;	en mode IM 2. C'est beaucoup plus fiable puisque \a ne d{pend
;	plus du tout de l'{tat du registre IVR ni des extensions g{rant
;	les interruptions connect{es sur le CPC. Merci @ Ram7 pour	l'astuce.
;	Limitation syst{matique ; l'{tat courant de configuration des ports
;	du PPI est perdue, mais \a ne pose normalement aucun probl}me.
;   - Remplacement du test CRTC 1 et 2 (29/12/2004) par OffseT
;	le test originel de Longshot {tait bas{ sur l'inhibition de
;	la VBL sur type 2 lorsque Reg2+Reg3>Reg0+1. Ce test modifiait
;	les r{glages CRTC et l'{cran sautait pendant une frame. Il a {t{
;	remplac{ par un test bas{ sur la d{tection du balayage du border
;	sp{cifique au type 1 qui n'a pas ces inconv{nients.
;	bug connu (rarissime) ; ce test renvoie un r{sultat erron{ sur
;	CRTC 1 si reg6=0 ou reg6>reg4+1... ce qui est fort improbable.
;   - Modification du test CRTC 3 et 4 (29/12/2004) par OffseT
;	le test ne modifie plus la valeur du registre 12. Toutefois
;	il en teste la coh{rence et v{rifie {galement le registre 13.
;	limitation (rare) ; ce test ne fonctionne pas si reg12=reg13=0.
;   - R{organisation g{n{rale des tests (29/12/2004) par OffseT
;	chaque test est d{sormais un module qui permet, par le biais
;	d'un syst}me de masques de tests, de diff{rencier les CRTC au
;	fur et @ mesure.
;   - Retrait des d{pendances d'interruption (29/12/2004) par OffseT
;	plus aucun test ne fait usage des interruptions pour se synchroniser.
;   - Ajout d'un test de lectures CRTC ill{gales (12/01/2005) par OffseT
;	ce test v{rifie qu'on obtient bien la valeur 0 en retour
;	lors d'une tentative de lecture ill{gale d'un registre du
;	CRTC en ecriture seule. Ceci permet de diff{rencier les types
;	0, 1 et 2 des types 3 et 4.

; Note ; une limitation d{crit un cas dans lequel le test ne renvoie
; aucun r{sultat (il ne parvient pas @ distinguer les CRTC) alors qu'un
; bug connu d{crit un cas dans lequel le test peut renvoyer une mauvaise
; r{ponse (ce qui est beaucoup plus grave !).

; Les diff{rents types de CRTC connus...

; 0 ; 6845SP		; sur la plupart des CPC6128 sortis entre 85 et 87
; 1 ; 6845R		; sur la plupart des CPC6128 sortis entre 88 et 89
; 2 ; 6845S		; sur la plupart des CPC464 et CPC664
; 3 ; Emul{ (CPC+)	; sur les 464 plus et 6128 plus
; 4 ; Emul{ (CPC old)	; sur la plupart des CPC6128 sortis en 89 et 90.


; Le programme qui utilise le test CRTC...

;	Org &9000

;	call testcrtc	; On lance le test CRTC !

;	add a,48	; On affiche le type de CRTC
;	call &bb5a

;	ret		; On rend la main

; Le test CRTC...
; Attention ! Le CRTC doit etre dans une configuration rationnelle
; pour que les tests fonctionnent (VBL et HBL pr{sentes, reg6 et 1 non nuls,
; bit 7 du registre 3 non nul, etc.)
; En sortie A contient le type de CRTC (0 @ 4)
; A peut valoir &f si le CRTC n'est pas reconnu
; (mauvais {mulateur CPC, mauvaise configuration CRTC au lancement du test)

TestCRTC
	ld a,&ff
	ld (typecrtc),a
	di                      ; CRTC 0,1,2,3,4
	call testlongueurvbl	;      0,1,1,0,0
	call testbexx		;      0,0,0,1,1 / Alien
	call testregswo		;      0,0,0,1,1
	call testborder		;      0,1,0,0,0
	call testrazppi		;      0,0,0,1,0 / Alien
	ei
	ld a,(typecrtc)
	cp crtc0:jr z,type_0
	cp crtc1:jr z,type_1
	cp crtc2:jr z,type_2
	cp crtc3:jr z,type_3
	cp crtc4:jr z,type_4
	ld a,'?' ;5 ;&f		;si inconnu on renvoie 5.
	ret
Type_0	ld a,'0':ret
Type_1	ld a,'1':ret
Type_2	ld a,'2':ret
Type_3	ld a,'3':ret
Type_4	ld a,'4':ret


; Test bas{ sur la mesure de la longueur de VBL
; Permet de diff{rencier les types 1,2 des 0,3,4
; (bug syst{matique ; si le bit 7 du registre 3 est @ z{ro (double VBL)
;                     le test renvoie un mauvais r{sultat)

TestLongueurVBL
	ld b,&f5	; Boucle d'attente de la VBL
SyncTLV1
	in a,(c)
	rra
	jr nc,synctlv1
NoSyncTLV1
	in a,(c)	; Pre-Synchronisation
	rra		; Attente de la fin de la VBL
	jr c,nosynctlv1
SyncTLV2
	in a,(c)	; Deuxi}me boucle d'attente de la VBL
	rra
	jr nc,synctlv2

	ld hl,140	; Boucle d'attente de 983 micro-secondes
WaitTLV	dec hl
	ld a,h
	or l
	jr nz,waittlv
	in a,(c)	; Test de la VBL
	rra		; Si elle est encore en cours
	jp c,type12	; on a un type 1,2...
	jp type034	; Sinon on a un type 0,3,4


; Test bas{ sur la lecture des registres 12 et 13
; @ la fois sur les ports &BExx et &BFxx
; Permet de diff{rencier les types 0,1,2 des 3,4
; (Limitation rare ; si reg12=reg13=0 le test est sans effet)

TestBExx
	ld bc,&bc0c	; On s{lectionne le registre 12
	out (c),c	; On compare les valeurs en
	call cpbebf	; retour sur les ports &BExx et &BFxx
	push af		; On sauve les flags
	ld b,a		; Si les bits 6 ou 7 de la valeur lue
	and &3f		; pour &BFxx sont nons nuls alors
        cp b		; on a un probl}me
	call nz,typealien
	pop af		; On r{cup}re les flags
	jp nz,type012	; Si elles sont diff{rentes on a un type 0,1,2
	xor a
	cp c		; Si elles sont {gales et non nulles
	jp nz,type34	; on a un type 3,4
	ld bc,&bc0d	; On s{lectionne le registre 13
	out (c),c	; On compare les valeurs en
	call cpbebf	; retour sur les ports &BExx et &BFxx
	jp nz,type012	; Si elles sont diff{rentes on a un type 0,1,2
	xor a
	cp c		; Si elles sont {gales et non nulles
	jp nz,type34	; on a un type 3,4
	ret

CPBEBF	ld b,&be	; On lit la valeur sur &BExx
	in a,(c)
	ld c,a		; On la stocke dans C
	inc b
	in a,(c)	; On lit la valeur sur &BFxx
	cp c		; On la compare @ C
	ret


; Test bas{ sur la RAZ du PPI
; Permet de diff{rencier les types 0,1,2,4 du 3
; (Limitation syst{matique ; l'{tat courant de configuration des ports
;                            du PPI est perdu)

TestRAZPPI
	ld bc,&f782	; On configure le port C
	out (c),c	; en sortie
	dec b
	ld c,&f		; On place une valeur sur
	out (c),c	; le port C du PPC
	in a,(c)	; On v{rifie si la valeur est
	cp c		; toujours l@ en retour
	jp nz,typealien ; sinon on a un probl}me
	inc b
	ld a,&82	; On configure de nouveau
	out (c),a	; le mode de fonctionnement
	dec b		; des ports PPI
	in a,(c)	; On teste si la valeur plac{e sur
	cp c		; le port C est toujours l@ retour
	jp z,type3	; Si oui on a un type 3
	or a		; Si elle a {t{ remise @ z{ro
	jp z,type0124	; on a un type 0,1,2,4
	jp typealien	; Sinon on a un probl}me


; Test bas{ sur la d{tection du balayage des lignes hors border
; Permet d'identifier le type 1
; (Bug connu rarissime ; si reg6=0 ou reg6>reg4+1 alors le test est fauss{ !)

TestBorder
	ld b,&f5
NoSyncTDB1
	in a,(c)	; On attend un peu pour etre
	rra		; sur d'etre sortis de la VBL
	jr c,nosynctdb1	; en cours du test pr{c{dent
SyncTDB1
	in a,(c)	; On attend le d{but d'une
	rra		; nouvelle VBL
	jr nc,synctdb1
NoSyncTDB2
	in a,(c)	; On attend la fin de la VBL
	rra
	jr c,nosynctdb2

	ld ix,0		; On met @ z{ro les compteurs
	ld hl,0		; de changement de valeur (IX),
	ld d,l		; de ligne hors VBL (HL) et
	ld e,d		; de ligne hors border (DE)
	ld b,&be
	in a,(c)
	and 32
	ld c,a

SyncTDB2
	inc de		; On attend la VBL suivante
	ld b,&be	; en mettant @ jour les divers
	in a,(c)	; compteurs
	and 32
	jr nz,border
	inc hl		; Ligne de paper !
	jr noborder
Border	ds 4
NoBorder
	cp c
	jr z,nochange
	inc ix		; Transition paper/border !
	jr change
NoChange
	ds 5
Change	ld c,a

	ds 27

	ld b,&f5
	in a,(c)
	rra
	jr nc,synctdb2	; On boucle en attendant la VBL

	db &dd:ld a,l	; Si on n'a pas eu juste deux transitions
	cp 2		; alors ce n'est pas un type 1
	jp nz,type0234
	jp type1	; Pour plus de fiabilit{ au regard de l'{tat
			; de haute imp{dance sur les CRTC autres que
			; le type 1 on pourrait v{rifier ici que HL
			; vaut reg6*(reg9+1) mais \a impose de
			; connaitre au pr{alable la valeur de ces
			; deux registres


; Test bas{ sur la valeur de retour sur les registres CRTC en {criture seule
; Permet de diff{rencier les types 0,1,2 des types 3,4
; (aucune limitation/bug connus)

TestRegsWO
	ld de,0		; On lance le parcours des
	ld c,12		; registres 0 @ 11 avec
	call cumulereg	; cumul de la valeur retour
	xor a		; Si le r{sultat cumul{ de
	cp d		; la lecture est non nul
	jp nz,type34	; alors on a un type 3 ou 4
	jp type012	; Sinon, c'est un type 0, 1 ou 2
CumuleReg
LoopTRI	ld b,&bc	; On s{lectionne le
	out (c),e	; registre "E"
	ld b,&bf	; On lit la valeur
	in a,(c)	; renvoy{e en retour
	or d		; On la cumule dans D avec
	ld d,a		; les lectures pr{c{dentes
	inc e		; On boucle jusqu'au
	ld a,e		; registre "C"
	cp c
	jr nz,looptri
        ret


; Routines de typage

CRTC0	Equ 1
CRTC1	Equ 2
CRTC2	Equ 4
CRTC3	Equ 8
CRTC4	Equ 16

Type012	ld a,(typecrtc)
	and crtc0+crtc1+crtc2
	ld (typecrtc),a
	ret
Type0124
	ld a,(typecrtc)
	and crtc0+crtc1+crtc2+crtc4
	ld (typecrtc),a
	ret
Type0234
	ld a,(typecrtc)
	and crtc0+crtc2+crtc3+crtc4
	ld (typecrtc),a
	ret
Type034	ld a,(typecrtc)
	and crtc0+crtc3+crtc4
	ld (typecrtc),a
	ret
Type1	ld a,(typecrtc)
	and crtc1
	ld (typecrtc),a
	ret
Type12	ld a,(typecrtc)
	and crtc1+crtc2
	ld (typecrtc),a
	ret
Type3	ld a,(typecrtc)
	and crtc3
	ld (typecrtc),a
	ret
Type34	ld a,(typecrtc)
	and crtc3+crtc4
	ld (typecrtc),a
	ret
TypeAlien
	xor a
	ld (typecrtc),a
	ret

; Variables

;	List
TypeCRTC equ #be37


	list
;**** Fin Test CRTC
	nolist