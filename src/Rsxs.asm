	nolist
;	Init les RSXs pour WriteDSK et ReadDSK

;	Inclut les Wdsk et Rdsk

;	METTRE les standalone dans WDSK et RDSK !
;	(rom=0 et rsx=0)


	org #7f00

	ld bc,RSX1
	ld hl,RSX1BUF
	call #bcd1
	ld bc,RSX2
	ld hl,RSX2BUF
	call #bcd1
	ld bc,RSX3
	ld hl,RSX3BUF
	call #bcd1
	ld hl,RSXPHR
RSXBB5A	ld a,(hl)
	or a
	ret z
	call #bb5a
	inc hl
	jr RSXBB5A

RSXPHR	
	defb "WriteDSK 1.2 :",#d,#a
	defb 124,"WDSK,",34,"DskName",34,",",34,"[SrcDest][1]",34,#d,#a
	defb 124,"DIRDOS,[",34,"Src",34,"]",#d,#a
	defb "ReadDSK 1.0 :",#d,#a
	defb 124,"RDSK,",34,"DskName",34,",",34,"[Src][1/2]",34,",[NbTracks]",#d,#a
	defb 0

RSX1BUF	defs 4,0
RSX2BUF	defs 4,0
RSX3BUF	defs 4,0
NOMRSX1 defb "WDS","K"+#80,0
NOMRSX2 defb "DIRDO","S"+#80,0
NOMRSX3 defb "RDS","K"+#80,0
RSX1	defw NOMRSX1
	jp WR_CODEDEBUT
RSX2	defw NOMRSX2
	jp DIRDOS
RSX3	defw NOMRSX3
	jp RD_CODEDEBUT

	list
;*** fin init rsx
	nolist


	read "readdsk.asm"
;	read "writedsk.asm"

;	endif