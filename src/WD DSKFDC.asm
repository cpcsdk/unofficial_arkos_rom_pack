
;
;
;        Routine lecture FDC standard
;	 pour DSK2DISC
;
;
;
;
;Change  le lecteur
;A=no    lect (0 ou 1)
CHLECT   AND  %11
         LD   (LECTEUR),A
         RET  
;
;Change  tete de lect
;A=no    tete (0 ou 1)
CHHEAD   RL   A
         RL   A
         AND  %100
         LD   (TETE),A
         RET  
;
;Allume  le FDC et attends un peu
FDCON    LD   A,(MARCHE)
         OR   A
         RET  NZ
         INC  A
         LD   (MARCHE),A
         LD   BC,#FA7E
         LD   A,1
         OUT  (C),A
         CALL WAITABIT
         RET  
;
;Eteinds le FDC
FDCOFF   XOR  A
         LD   (MARCHE),A
         LD   BC,#FA7E
         XOR  A
         OUT  (C),A
         RET  
;
;Attends qq vbls
WAITABIT EI   
         LD   B,6*40
WAB2     HALT 
         DJNZ WAB2
         DI   
         RET  
;
;
;Attends qu'une instruction soit prete a etre envoyee (se sert de MSR)
;WTDATAOK
;         LD   BC,#FB7E
;         IN   A,(C)
;         JP   P,$-3
;         RET  
;
;Recalibre le lecteur en cours
RECALIBR
         LD   A,%00000111
         CALL PUTFDC
         LD   A,(TETE)
         LD   B,A
         LD   A,(LECTEUR)
         OR   B
         CALL PUTFDC
         CALL WAITEND
         RET  
;
;Attends la fin de l'instruction qui vient detre executee (se sert de ST0)
WAITEND
         LD   A,%00001000
         CALL PUTFDC
         CALL GETFDC                    ;Recoit ST0
         LD   (ST0),A
         CALL GETFDC                    ;Recoit no piste courante
         XOR  A
         LD   (ST1),A                   ;On reset ST1 et ST2
         LD   (ST2),A
;
         LD   A,(ST0)
         BIT  5,A                       ;Instruction finie ?
         JR   Z,WAITEND
         RET  
;
;Envoie  une data au FDC
;A=data  a envoyer
PUTFDC
         PUSH AF
         ;CALL WTDATAOK                  ;On attend FDC ok pour recev data
         LD   BC,#FB7E
         IN   A,(C)
         JP   P,$-3

         POP  AF
	 inc c
         OUT  (C),A
         RET  
;
;Recois  une data du FDC
;Ret =   A=data FDC
GETFDC
         LD   BC,#FB7E
         IN   A,(C)
         JP   P,$-3
 ;        CALL WTDATAOK

	 inc c
         IN   A,(C)
         RET  
;
;
;Change de piste.
;A=piste
GOTOPIST
	ld (GPNOP+1),a
         LD   A,%00001111
         CALL PUTFDC
         LD   A,(LECTEUR)
         LD   B,A
         LD   A,(TETE)
         OR   B
         CALL PUTFDC                    ;Envoie ID lecteur
GPNOP    LD   A,0	              ;Envoie no piste
         CALL PUTFDC
;
         CALL WAITEND
;
         RET  
;
;



;Effectue un SCANID. Les infos ne servent qu'a ReadDSK.
;Utilise pour le mode The Demo ou 5kb3, mais aussi par ReadDSK.
;RET=D=Taille E=piste H=ID L=Tete
.SCANID
	ld a,%01001010
	call PUTFDC
         LD   A,(LECTEUR)
         LD   B,A
         LD   A,(TETE)
         OR   B
	call PUTFDC

	call GETFDC
	ld (ST0),a
	call GETFDC
	call GETFDC

	call GETFDC	;get nopiste
	ld e,a
	call GETFDC	;tete
	ld l,a
	call GETFDC	;id
	ld h,a
	call GETFDC	;taille
	ld d,a
	ret

;
;
;
;
;
;
;
;
;Lis un secteur. UNIQUEMENT utilise par DOS. On peut donc se permettre de faire un amalgame entre
;SIDE et HEAD.
;Utilise aussi pour lire un secteur non trouve sur la piste, donc on s'en fout si c'est pas valable,
;c'est ce qu'on veut.
;A=piste
;B=nom secteur
;C=side
;D=taille
;E=GAP
;HL=ou le charger
;RETOUR=Erreur FDC. A=0=ok et carry=1
READSECTDOS
	ld (RSDPISTE+1),a
	ld a,b
	ld (RSDSECT+1),a
	ld a,c
	ld (RSDSIDE+1),a
	ld a,d
	ld (RSDSIZE+1),a
	ld a,e
	ld (RSDGAP+1),a
	ld (RSLOAD+1),hl

	ld a,(RSDPISTE+1)
	call GOTOPIST

         LD   A,%01000110
         CALL PUTFDC
         LD   A,(LECTEUR)
         LD   B,A
         LD   A,(RSDSIDE+1)
	 rla
	 rla
	 and %100
         OR   B                         ;ID lecteur
         CALL PUTFDC
RSDPISTE  LD   A,0              ;No piste
         CALL PUTFDC
RSDSIDE	 ld a,0				;head
         CALL PUTFDC
RSDSECT   LD   A,0              ;ID sect
         CALL PUTFDC
RSDSIZE   LD   A,0                       ;Taille sect
         CALL PUTFDC
	 LD   A,(RSDSECT+1)               ;dernier sect a lire
         CALL PUTFDC
RSDGAP    LD   A,0                   ;GAP
         CALL PUTFDC
         LD   A,#FF                     ;long eff sect
         CALL PUTFDC
;
;On      recupere les donnees du sect
RSREAD   LD   BC,#FB7E
	 ld c,%00100000
RSLOAD   LD   HL,0	              ;On le charge ds buffer
;
RSLOOP
         IN   A,(C)
         JP   P,$-3
         AND  C
         JR   Z,RSFIN
         INC  C
         INI
	 INC  B
         DEC  C

;	inc c
;	in a,(c)
;	ld (hl),a
;	inc hl
;	dec c

;	add a,e				;add to checksum
;	ld e,a
;	ld a,d
;	adc a,0
;	ld d,a

         JR   RSLOOP
;
RSFIN
         CALL GETFDC
         LD   (ST0),A
         CALL GETFDC
         LD   (ST1),A
         CALL GETFDC
         LD   (ST2),A
         CALL GETFDC
         CALL GETFDC
         CALL GETFDC
         CALL GETFDC

	call TESTERR
;
	ret

;
;



;Lis un secteur. Celle routine, a l'inverse de READSECTDOS, est utilisable pour une lecteur CPC
;normale.
;A=piste SUR DISC
;B=nom secteur
;C=tete
;D=taille
;E=piste de ID SECTOR
;HL=ou le charger
;RETOUR=Erreur FDC. A=0=ok Carry=1 et HL=pointe apres les donnees ecrites.
READSECT
	push af
	ld a,b
	ld (RSSECT+1),a
	ld a,c
	ld (RSSIDE+1),a
	ld a,d
	ld (RSSIZE+1),a
	ld a,e
	ld (RSPISTE+1),a
	ld (RSLOAD+1),hl

	pop af
	call GOTOPIST

;	ld de,0				;CHECKSUM

         LD   A,%01000110
         CALL PUTFDC
         LD   A,(LECTEUR)
         LD   B,A
	 ld a,(TETE)
	 or b
         CALL PUTFDC
RSPISTE  LD   A,0              ;No piste
         CALL PUTFDC
RSSIDE	 ld a,0				;head
         CALL PUTFDC
RSSECT   LD   A,0              ;ID sect
         CALL PUTFDC
RSSIZE   LD   A,0                       ;Taille sect
         CALL PUTFDC
	 LD   A,(RSSECT+1)               ;dernier sect a lire
         CALL PUTFDC
	LD   A,#4e
         CALL PUTFDC
         LD   A,#FF                     ;long eff sect
         CALL PUTFDC

	jp RSREAD



;




;Ecris un secteur
;IX=Donnees DATAS
;IY=Donnees SECTEUR (track, head, idsect, taillsect, FDC SECT1,2, actual data length)
;A=piste
;H=GAP
;L=side OU ECRIRE. Utile principalement pour double sided dsk.
;RET=IX pointe sur les DATA su prochain secteur SAUF si erreur disc !
WRITESECT
	call GOTOPIST

	ld a,%01000101		;Code instruction 'ecriture secteur'
	bit 6,(iy+5)		;Secteur efface a ecrire ?
	jr z,WRSENEFF
	ld a,%01001001		;Code instruction 'ecriture secteur efface'
WRSENEFF CALL PUTFDC
         LD   A,(LECTEUR)
	 sla l
	 sla l
         OR   L                         ;ID lecteur
         CALL PUTFDC
	LD   A,(iy+0)              ;No piste
         CALL PUTFDC
	ld a,(iy+1)				;head
         CALL PUTFDC
	ld a,(iy+2)              ;ID sect
         CALL PUTFDC
	ld a,(iy+3)                       ;Taille sect
         CALL PUTFDC
	ld a,(iy+2)               ;dernier sect a lire
         CALL PUTFDC
	ld a,h			;gap
         CALL PUTFDC
         LD   A,#ff                     ;long eff sect
         CALL PUTFDC
;
;On      recupere les donnees du sect
         LD   BC,#FB7E
;WSLOAD   ld   hl,0                        ;Ou on puisse les donnees
;
; Boucle qui ecrit les donnes du sect
WSLOOP
         IN   A,(C)
         JP   P,$-3
         AND  %00100000
         JR   Z,WSFIN
         INC  C
         LD   A,(ix+0)
         OUT  (C),A
         INC  IX
         DEC  C
         JR   WSLOOP
;
WSFIN
         CALL GETFDC
         LD   (ST0),A
         CALL GETFDC
         LD   (ST1),A
         CALL GETFDC
         LD   (ST2),A
         CALL GETFDC
         CALL GETFDC
         CALL GETFDC
         CALL GETFDC

	call TESTERR
;
	ret









;Formatte piste.
;IX=pointe sur data piste + ID sects. Utilise le format BUFFMAIN =
;db TrackNumber,   Side (0/1),   Sector size,   Nb sectors,   Gap#3,   Filler Byte.
;Pour chaque secteur =
;db TrackNumber,    Side,   SectorID,   Sector size
;db FDC R1, FDC R2
;dw ADL
.FORMAT
	 ld a,(ix+0)
         CALL GOTOPIST
;
         LD   A,%01001101
         CALL PUTFDC
         LD   A,(LECTEUR)
         LD   B,A
	ld a,(ix+1)
	rl a
	rl a
	and %100
;         LD   A,(TETE)
         OR   B                         ;ID lecteur
         CALL PUTFDC
	 LD   A,(ix+2)                  ;taille sect
         CALL PUTFDC
	 LD   A,(ix+3)                  ;Nb sects
         CALL PUTFDC
	 LD   A,(ix+4)                  ;GAP
         CALL PUTFDC
	 LD   A,(ix+5)                  ;Remplissage.
         CALL PUTFDC
;

;        ID sects pour chaq sect

	 LD   d,(ix+3)		;d=nb sects pour boucle

	ld bc,6
	add ix,bc

FRMSLP	 LD   A,(ix+0)                  ;Piste actuelle
         CALL PUTFDC
	 LD   A,(ix+1)			;side
         CALL PUTFDC
	 LD   A,(ix+2)			;nom sect
         CALL PUTFDC
	 LD   A,(ix+3)			;Taille
         CALL PUTFDC
;
	ld bc,8
	add ix,bc

	 dec d
         JR   NZ,FRMSLP
;
         CALL GETFDC
         LD   (ST0),A
         CALL GETFDC
         LD   (ST1),A
         CALL GETFDC
         LD   (ST2),A
         CALL GETFDC
         CALL GETFDC
         CALL GETFDC
         CALL GETFDC
;
         CALL TESTERR

;
         RET  






;Deformatte un piste donnee en C, side D.
;RET=Carry=1=ok
UNFORMAT
	ld a,c
	ld (TUFTRACK1),a
	ld (TUFTRACK2),a
	ld a,d
	ld (TUFSIDE1),a
	ld (TUFSIDE2),a

	add a,"0"
	ld (TXTUNFORMA3),a

	ld a,c
	call NBTODEC
	ld a,b
	ld (TXTUNFORMA2),a
	ld a,c
	ld (TXTUNFORMA2+1),a

	call CLEARITF

	ld hl,TXTUNFORMAT
	call PHRASE


	ld a,(DESTLECT)
	call CHLECT

	ld ix,TABUNFORMAT
	call FORMAT
	or a
	jp z,RESOK
	jp RESNOTOK








;
;
;
;Teste   les eventuelles erreurs
;retour= a=0=ok  a=1=disc missing  2=autre erreur
;utilise ST0, ST1, ST2
TESTERR
         LD   A,(ST0)
         BIT  7,A
         JR   NZ,TESTEJEC               ;Dsk absent ou ejecte
         BIT  3,A
         JR   NZ,TESTEJEC               ;Dsk absent ou ejecte
         BIT  4,A
         JR   NZ,TESTFAIL               ;Read fail
;
         LD   A,(ST1)
         AND  %00110111
         JR   NZ,TESTFAIL
;
         LD   A,(ST2)
         AND  %00110000
         JR   NZ,TESTFAIL
;
TESTNOE
	xor a
	scf
         RET  
TESTEJEC
TESTFAIL
	ld a,1
	or a
	ret

;
;FDCERR	di
;	ld bc,#7f10
;	out (c),c
;	ld a,#4c
;	out (c),a
;	jr FDCERR
;
;
;
;

;
	list
;**** Fin Code FDC CPC
	nolist
;     