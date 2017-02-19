	nolist
	list
;*** Debut Prg Snarkos
	nolist

;	        d8888         888
;	       d88888         888
;	      d88P888         888
;	     d88P 888 888d888 888  888  .d88b.  .d8888b
;	    d88P  888 888P"   888 .88P d88""88b 88K
;	   d88P   888 888     888888K  888  888 "Y8888b.
;	  d8888888888 888     888 "88b Y88..88P      X88
;	 d88P     888 888     888  888  "Y88P"   88888P'
;
;    SNARKOS v1.3 (February 2006) by Grim

;	 REQUIRE A CPCBOOSTER WITH BIOS V1.6 (BIOS WITH RAM READ/WRITE)

;	 check out at these web page for latest information about SNArkos and CPCBooster
;	 dirtyminds.cpcscene.com
;	 arkos.cpcscene.com

; Notes:
;			-The CPC's PPI configuration is not updated

;			-The FDC's Track information is not used

;			-There's NO hardware detection, you can send 572Kb CRTC 4 SNA DATA on a 64Kb CPC CRTC 2, it will just crash.
;			Don't be stupid :

;				-DO NOT SEND ANY SNA WITH CPC+ CHUNK ON A CLASSIC CPC (IT WILL TRASH RAM &4000 TO &7FFF)

;				-If CPC+ Chunk is present in the SNA's data, the ASIC will be unlocked (whatever there's one or not !!),
;				updated then, according to the ASIC synchronisation data (offset &8F6), it will remain unlocked or not.
;				Beware of DMA, it may start working before the SNA is executed !

;			-The synchronisation data (in SNAv3 specifications) are not used, the SNA will be launched as soon it is ready.

;			-Masquable interruption are disabled while the transfert then, according to the IFF0 flag, they will be enabled
;			just before the JUMP to the PC address.

;			-16 bytes of ram are used to store the SNA boot routine (&FFF0 to &FFFF).
;			These bytes will be written into the RAM according to the MMU configuration of the SNA (so they can be in the
;			64Kb chip ram or the extended RAM if it is mapped by the MMU).
;			Beware of ROM configuration to avoid conflict.

;			-While the transfert, if you get a red screen then it's because a timeout occured. Reset, same player play again.	


;	How to make a proper, reliable and working SNA :

;			Configure correctly the RAM and CPC models settings in your emulator or SNA generator to match the
;			real CPC configuration in which it will be loaded.

;			When dealing with splitscreen or anything requiring very high synchro accuracy, avoid to snapshot that while
;			it is running, do it just before in your init code for exemple.

;			WinAPE versions prior to 2.0Alpha6 produce a corrupted .SNA file (CRTC value are stored as word and then overwritten
;			with PPI data... a complete mess).


SNA_BUILDBETA	EQU 	0 ; enable/disable unstable feature

SNA_Timeout_R16	EQU		&4000
SNA_Timeout_H16	EQU		&4000

SNA_HeaderAdr	EQU 	&BE00 ;must be outside ROM/BANK space

SNA_ID_STRING	EQU		SNA_HeaderAdr+&00		;-&07	8	The identification string "MV - SNA". This must exist for the snapshot to be valid.	

SNA_VERSION		EQU		SNA_HeaderAdr+&10		;		1	snapshot version
SNA_Z80_AF		EQU		SNA_HeaderAdr+&11		;		2	Z80 register AF
SNA_Z80_BC		EQU		SNA_HeaderAdr+&13		;		2	Z80 register BC
SNA_Z80_DE		EQU		SNA_HeaderAdr+&15		;		2	Z80 register DE
SNA_Z80_HL		EQU		SNA_HeaderAdr+&17		;		2	Z80 register HL	
SNA_Z80_R		EQU		SNA_HeaderAdr+&19		;		1	Z80 register R	
SNA_Z80_I		EQU		SNA_HeaderAdr+&1a		;		1	Z80 register I	
SNA_Z80_IFF0	EQU		SNA_HeaderAdr+&1b		;		1	Z80 interrupt flip-flop IFF0
SNA_Z80_IFF1	EQU		SNA_HeaderAdr+&1c		;		1	Z80 interrupt flip-flop IFF1	
SNA_Z80_IX		EQU		SNA_HeaderAdr+&1d		;		2	Z80 register IX
SNA_Z80_IY		EQU		SNA_HeaderAdr+&1f		;		2	Z80 register IY
SNA_Z80_SP		EQU		SNA_HeaderAdr+&21		;		2	Z80 register SP
SNA_Z80_PC		EQU		SNA_HeaderAdr+&23		;		2	Z80 register PC
SNA_Z80_IM		EQU		SNA_HeaderAdr+&25		;		1	Z80 interrupt mode (0,1,2)
SNA_Z80_AFx		EQU		SNA_HeaderAdr+&26		;		2	Z80 register AF'	
SNA_Z80_BCx		EQU		SNA_HeaderAdr+&28		;		2	Z80 register BC'
SNA_Z80_DEx		EQU		SNA_HeaderAdr+&2a		;		2	Z80 register DE'
SNA_Z80_HLx		EQU		SNA_HeaderAdr+&2c		;		2	Z80 register HL'

SNA_GA_SELPEN	EQU 	SNA_HeaderAdr+&2e		;		1	GA index of selected pen
SNA_GA_PALETTE 	EQU 	SNA_HeaderAdr+&2f 		;-&3f	17	GA current palette
SNA_GA_MISC		EQU		SNA_HeaderAdr+&40		;		1	GA multi configuration
SNA_GA_RAMMU	EQU		SNA_HeaderAdr+&41		;		1	current RAM configuration

SNA_CRTC_SELREG	EQU		SNA_HeaderAdr+&42		;		1	CRTC index of selected register
SNA_CRTC_REGVAL	EQU		SNA_HeaderAdr+&43		;-&54	18	CRTC register data (0..17)

SNA_ROM_UPPER	EQU		SNA_HeaderAdr+&55		;		1	current ROM selection

SNA_PPI_A		EQU		SNA_HeaderAdr+&56		;		1	PPI port A
SNA_PPI_B		EQU		SNA_HeaderAdr+&57		;		1	PPI port B
SNA_PPI_C		EQU		SNA_HeaderAdr+&58		;		1	PPI port C
SNA_PPI_CTRL	EQU		SNA_HeaderAdr+&59		;		1	PPI control port

SNA_AY3_SELREG	EQU		SNA_HeaderAdr+&5a		;		1	PSG index of selected register
SNA_AY3_REGVAL	EQU		SNA_HeaderAdr+&5b		;-&6a	16	PSG register data (0,1,....15)

SNA_RAM_SIZE	EQU		SNA_HeaderAdr+&6b		;-&6c	1	memory dump size in Kilobytes

SNA_FDD_MOTOR	EQU 	SNA_HeaderAdr+&9C		;		1	FDD Motor flipflop




					di
					; Fix FDC bugs
					; initialize FDC parameters
					ld a,%00000011	;Specify Command.
					call SNA_FDC_put
					ld a,&AF		;Step rate = #A  Unload Time=#F
					call SNA_FDC_put
					ld a,&3			;Head Load time = #3
					call SNA_FDC_put
					
					; recalibrate FDC
					; SNA flags (&BE0F / &FF)
					; bit 2  init drive
					; bit 1  drive 0/1
					ld a,(&BE0F)
					bit 2,a
					jr z,SNA_skipFDC_init
					; recalibrate floppy drive
					ld a,(&BE0F)
					ld d,0
					bit 1,a
					jr nz,SNA_skipFDC_init-3
					inc d
					call SNA_FDC_recalibrate
SNA_skipFDC_init


SNA_Retry
					ld a,3	; how many attempt to openfile
					ld (&BE10),a
SNA_RetryOpenin
					; flush CPCB RX buffer
					; just in case the previous transfert failed and some data remains in the Serial buffers
					ld bc,&FF1C
SNA_RX_flush
					defw &70ED
					jr z,SNA_RX_flushed
					inc c ; &FF1D
					defw &70ED
					dec c
					jr SNA_RX_flush
SNA_RX_flushed

					; close AFT.EXE connection
					; just in case the previous transfert failed and AFT didn't closeout the file
					ld bc,#ff08
					ld a,CPCB_EndCommand
					out (c),a

					; open filename
					; fetch it from SNARAM
					call SNA_ROM_Get_SNARAM

					; open it with AFT
					ld bc,#ff08
					ld a,&FC
					out (c),a
					ld hl,&BE03
					ld d,12
SNA_SendFileName
					ld a,(hl)
					and &7F
					out (c),a
					inc hl
					dec d
					jr nz,SNA_SendFileName
					
					; wait for AFT-ACK
					call CPCB_GetByte
					jp nc,SNA_file_openfail
					cp &80
					jp z,SNA_file_ready
SNA_file_openfail
					ld hl,&BE10
					dec (hl)
					jr nz,SNA_RetryOpenin
					; Can not open the file after several retry
					jp SNA_RSX_CantOpenFile
SNA_file_ready
					
					; get SNA Header & hardware registers
					ld hl,&100
					ld bc,#ff08
					ld a,&F1
					out (c),a			;Send the size to receive.
					out (c),l
					out (c),h
					
					; wait for the firsts bytes of header
					; this can take some time (filling PC's UART buffer before it start sending data)
					; 16bit Timeout counter
					ld c,#1c
					ld de,SNA_Timeout_H16
SNA_GetHeader_warm
					DEFW &70ED
					jr nz,SNA_GetHeader_ready
					dec de
					ld a,d
					or e
					jp z,SNA_GetHeaderFailled	;Timeout
					jr SNA_GetHeader_warm
SNA_GetHeader_ready
					ld de,SNA_HeaderAdr
					jr SNA_GetHeader_byte

					; data are now being sent
					; 8bit Timeout counter
SNA_GetHeaderLoop
					ld c,#1c
					ld a,b
SNA_GetHeader_wait 	
					DEFW &70ED
					jr nz,SNA_GetHeader_byte
					dec a
					jp z,SNA_GetHeaderFailled	;Timeout
					jr SNA_GetHeader_wait
SNA_GetHeader_byte
					inc c
					in a,(c)
							
					ld (de),a
					inc de
					dec hl
					ld a,l
					or h
					jr nz,SNA_GetHeaderLoop
					
					; Check SNA header
					ld hl,SNA_ID_STRING
					ld de,SNA_CHUNK_ID_STR
					ld bc,8
SNA_ScanIdString
					ld a,(de)
					inc de
					cpi
					jp nz,SNA_BadDataType
					jp po,SNA_ScanIdString
					
					; Break if an upper ROM is enabled
					ld a,(SNA_GA_MISC)
					bit 3,a
					jp z,SNA_UpperROM_enabled
					
					; SAVE SNA HEADER IN THE CPCBOOSTER'S RAM FOR LATER USE
					;28		IN/OUT	00-$FF		RAM ADDRESS
					;29		IN/OUT	00-$FF		RAM DATA
					;2A		IN/OUT	00-$FF		RAM DATA POST INCREMENT

					; Write the SNA header in the booster RAM
					ld bc,&ff28
					defw &71ED
					ld bc,&ff2A
					ld hl,SNA_HeaderAdr
					ld d,&F0
SNA_BoostHeader
					ld a,(hl)
					out (c),a
					inc hl
					dec d
					jr nz,SNA_BoostHeader
					
				
					; *******************************
					; * PreInitialize CPC registers *
					; *******************************
					
					; **********
					; * FDC765 *
					; **********
					
					; Setup motor flip/flop
					;ld bc,&FA7E
					;ld a,(SNA_FDD_MOTOR)
					;out (c),a
					
					; *************
					; * GateArray *
					; *************
					
					; Setup pen colors 0 to 15 and border color
					ld hl,SNA_GA_PALETTE+16
					ld bc,&7F10
SNA_SetupGA
					out (c),c
					inc b
					set 6,(hl) ;pfff
					outd
					dec c
					jp p,SNA_SetupGA
					; Select last active pen
					inc b
					outi					
					
					; ********
					; * CRTC *
					; ********
					
					; Setup CRTC registers
					ld hl,SNA_CRTC_REGVAL+17
					ld bc,&BD00+17
SNA_SetupCRTC
					dec b
					out (c),c
					ld b,&BE
					outd
					dec c
					jp p,SNA_SetupCRTC
					; Select active CRTC register
					; HL = Offset &42
					; B  = &BD
					outd
					
					; ************
					; * AY3-8912 *
					; ************
					
					; Setup AY3 registers

					ld hl,SNA_AY3_REGVAL+15
					ld a,15
SNA_SetupAY3
					ld bc,&f4c0
					out (c),a
					ld b,&f6
					out (c),c
					db &ED,&71
					dec b
					outd
					ld bc,&f680
					out (c),c
					db &ED,&71
					dec a
					jp p,SNA_SetupAY3
					; Select last active AY3 register
					ld bc,&f5c0
					outd
					ld b,&f6
					out (c),c
					db &ED,&71
					
					
					; ***********
					; * CPU Z80 *
					; ***********
					
					; Restore Z80 interruption mode
					im 1
					ld a,(SNA_Z80_IM)
					or a
					jr nz,$+3
					im 0
					cp 2
					jr nz,$+3
					im 2

					; Restore some Z80 registers
					ld a,(SNA_Z80_I)
					ld i,a
					ld sp,SNA_Z80_AFx
					pop af
					pop bc
					pop de
					pop hl
					exx
					ex af,af'
					ld iy,(SNA_Z80_IY)


					; =================================================================================
					; Now we do not have to write in the CPC RAM anything else than the received datas.
					; So... INT, PUSH/POP, CALL are forbiden. Use inlines CPCBooster routines.
					; =================================================================================
					

					; Fill the RAM with 64Kb pages
					ld de,(SNA_RAM_SIZE)
					rl e
					rl d
					rl e
					rl d ; nb of 64Kb page to load (include base 64Kb)
					
					ld a,&C0
					ld e,&C2-8
SNA_Get64KBytes
					ld b,&7F
					out (c),a
					ld bc,#ff08
					ld a,CPCB_ReceiveCommand
					out (c),a
					defw &71ED ;out (c),0 ; lo
					defw &71ED ;out (c),0 ; hi => &10000 bytes requested
					ld c,#1c
					ld hl,SNA_Timeout_R16
SNA_Get64KB_warm
					defw &70ED
					jr nz,SNA_Get64KB_ready
					dec hl
					ld a,h
					or l
					jr nz,SNA_Get64KB_warm
					jp SNA_ERROR_RAM_TIMEOUT

SNA_Get64KB_ready
					ld hl,#0000 ; start RAM address
					jr SNA_GotByte
SNA_Get64KBLoop
					dec c ; &FF1C
					ld a,b
SNA_GetByteLoop
					dw &70ED ; in (c) opcode non documenté, affecte seulement les flags celon la valeur du port
					jr nz,SNA_GotByte
					dec a
					jr nz,SNA_GetByteLoop
					jp SNA_ERROR_RAM_TIMEOUT
SNA_GotByte				
					inc c ; &FF1D
					ini ; (hl),(c) / hl++ / b--
					inc b
					ld a,h
					or l
					jr nz,SNA_Get64KBLoop
					ld a,e
					add a,8
					ld e,a
					dec d
					jr nz,SNA_Get64KBytes
					
					; close AFT.EXE connection
					ld bc,#ff08
					ld a,CPCB_EndCommand
					out (c),a

					
					; Read back data stored in the booster RAM
					
					; **********
					; * FDC765 *
					; **********
					
					; Setup motor flip/flop
					ld bc,&FF28
					ld a,&9C
					out (c),a
					inc c
					in a,(c)
					ld bc,&FA7E
					out (c),a
					
					; restore Z80 registers and prepare bootrout

					; restore RAM config
					ld bc,&FF28
					ld a,&41
					out (c),a
					inc c
					in a,(c)
					ld b,&7F
					or &C0 ; EMUCPC suxx
					out (c),a
					
					; current state 
					; already restored I, AF', HL', DE', BC', IY
					; not yet restored HL, DE, BC, AF, IX, SP, PC, INT, ROMMU


					; Prepare boot code
					; AF, ROMU, BC, INT, PC
					ld hl,SNA_BOOTCHUNK
					ld d,h
					ld e,l
					ld bc,&10
					ldir
					
					; poke AF
					ld bc,&FF28
					ld a,&11
					out (c),a
					ld c,&2A
					ld hl,SNA_BOOTCHUNK_AF ; &FFFD
					ld sp,SNA_BOOTCHUNK_AF
					ini:inc b
					ini:inc b
					
					; poke BC
					;ld bc,&FF28
					;ld a,&13
					;out (c),a
					;ld c,&2A
					ld hl,SNA_BOOTCHUNK_BC+1 ; &FFF7
					ini:inc b
					ini:inc b
					
					; poke INT
					ld bc,&FF28
					ld a,&1B
					out (c),a
					inc c
					in a,(c)
					and 1
					jr nz,$+4
					ld (SNA_BOOTCHUNK_EI),a ; &FFF9
					
					; poke SP
					ld bc,&FF28
					ld a,&21
					out (c),a
					ld c,&2A
					ld hl,SNA_BOOTCHUNK_SP+1 ; &FFF4
					ini:inc b
					ini:inc b
					
					; poke PC
					ld bc,&FF28
					ld a,&23
					out (c),a
					ld c,&2A
					ld hl,SNA_BOOTCHUNK_PC+1 ; &FFFB
					ini:inc b
					ini:inc b
					
				
					; restore IX
					ld bc,&FF28
					ld a,&1D
					out (c),a
					ld c,&2A
					in a,(c)
					DEFB &DD:ld l,a ; ld ixl,a
					in a,(c)
					DEFB &DD:ld h,a ; ld ixh,a
					
					; restore DE
					ld bc,&FF28
					ld a,&15
					out (c),a
					ld c,&2A
					in e,(c)
					in d,(c)
					
					; restore HL
					ld bc,&FF28
					ld a,&17
					out (c),a
					ld c,&2A
					in l,(c)
					in h,(c)
					
					; restore ROMMU
					ld bc,&FF28
					ld a,&40
					out (c),a
					inc c
					in c,(c)
					
					; execute boot code
					ld b,&7F
					jp SNA_BOOTCHUNK

SNA_ERROR_RAM_TIMEOUT
					di
					
					; close AFT.EXE connection
					ld bc,#ff08
					ld a,CPCB_EndCommand
					out (c),a
					
					ld bc,&bc06
					out (c),c
					inc b
					defw &71ED
					ld bc,&7F10
					out (c),c
					ld c,&4C
					out (c),c
					jr SNA_ERROR_RAM_TIMEOUT


SNA_CHUNK_ID_STR
					defm "MV - SNA"
					
					
					; FDC CODE (adapted from AmsDOS FDC' routs by Targhan)
					
					; Power on and wait for motor to spin at correct speed
;SNA_FDC_motorOn
;					ld bc,#FA7E
;					ld a,1
;					out (c),a

;					ld de,600 ; wait 600*16 rasterline => 30 VBL
;SNA_FDC_motorWait	djnz SNA_FDC_motorWait
;					dec de
;					ld a,d
;					or e
;					jr nz,SNA_FDC_motorWait
					ret
					
					;Recalibrate drive
					; d=drive id
SNA_FDC_recalibrate
					ld bc,#FA7E
					ld a,1
					out (c),a
					
 					call SNA_FDC_recalibrate2
SNA_FDC_recalibrate2
			        ld a,%00000111
			        call sna_fdc_put
			  		ld a,d
			        call sna_fdc_put
			        call sna_fdc_waitend
			        ret
			        
					;Wait for the end of the current instruction (using ST0).
SNA_FDC_waitEnd
					ld a,%00001000
					call sna_fdc_put
					call sna_fdc_get		;get st0
					ex af,af' ;ld   (st0),a
					call sna_fdc_get
					;xor  a
					;ld   (st1),a	;reset st1 and st2
					;ld   (st2),a
					;ld   a,(st0)
					ex af,af'
					bit 5,a		;instruction over ?
					jr z,sna_fdc_waitend
					ret
					
					;Send data to FDC
					;A=data
SNA_FDC_put
        			ex af,af'
 					ld bc,#FB7E
SNA_FDC_put2 		in a,(C)
        			jp p,SNA_FDC_put2
        			ex af,af'
 					inc c
 					out(c),a
        			ret
        			
					;Get data from FDC
					;Ret = A=FDC data
SNA_FDC_get
					ld bc,#FB7E
SNA_FDC_get2		in a,(c)
					jp p,sna_fdc_get2
					inc c
			        in a,(c)
			        ret  
					

	list
;*** FIN Prg Snarkos
	nolist

			       
         
					ORG &FFF0
SNA_BOOTCHUNK
					out (c),c 	; restore ROMMU configuration
					pop af		; restore AF
SNA_BOOTCHUNK_SP	ld sp,0
SNA_BOOTCHUNK_BC	ld bc,0		; restore BC
SNA_BOOTCHUNK_EI	ei			; restore INT status
SNA_BOOTCHUNK_PC	jp 0		; Jump to PC
SNA_BOOTCHUNK_AF	DEFW 0		; AF
SNA_BOOTCHUNK_END


					
;#F0 = Test Communication (send #80 to CPC to confirm).
;#F1 + Word = Asked to send 'word' bytes to the CPC. 0=#10000
;#F2 = End Tranfer. Close all file in output and input.
;#F3 = Rewind. Return to the beginning of the file.
;#F4 = Ask Filesize (send DWord to CPC).
;#F5 = Ask Filename (send 12 bytes to CPC).
 
;#F6 = Create file on PC  Get 12 bytes (filename), Send byte (#80=ok autre=echec)
;#F7 = Add data  Get 2 bytes (size of data chunck, little endian) + Data
;#F8 = Close output file.
 
;#F9 = Initialise the DSK. Empty it, set some vars. Header creation done when all the tracks are given.
;      Ask for 2 chars for the Creator (10 for 1.0), Nb tracks, nb sides.
;#FA = Wait for a track from the CPC, header included.
;#FB = Warn that no more track is to be transfered. The DSK can be completed and closed. This command closes the file.
 
;#FC = Open a file in input on PC. Get 12 bytes (filename). Send byte (#80=ok autre=echec)


	list
;*** FIN Prg Snarkos2
	nolist