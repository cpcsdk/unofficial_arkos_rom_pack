; ----------------------- ROM Shell ----------------------------------------------------------------------------
        nolist
                        ORG &C000

SNA_ROMVersion              EQU "1"
SNA_ROMRevision             EQU "4"

                        ;ROM Prefix
                        DEFB 1 ;ROM type ... background
                        DEFB 1 ;mark 1
                        DEFB SNA_ROMVersion     ;version
                        DEFB SNA_ROMRevision    ;modification

                        ;RSX Define
                        DEFW ROM_RSX
                        JP ROM_init
                        JP SNA_RSX_sna
                        JP SNA_RSX_snahv
                        JP SNA_RSX_snafdc
ROM_RSX
                        DEFB "ARKOS RO","M"+&80
                        DEFB "SN","A"+&80   ;ùSNA,@a$,b
                        DEFB "SNA","H"+&80  ;ùSNAH
                        DEFB "SNAFD","C"+&80    ;ùSNAFDC,opt
                        DEFB 0
ROM_init
                        PUSH DE
 PUSH HL
                        
                        ; initialise SNArkos
                        CALL SNA_ROM_Autoboot
                        jr c,ROM_skip_init_msg
                        
                        ; display bullshit
                        CALL SNA_ROM_print_ntstr
                        DEFB " SNArkos v",SNA_ROMVersion,".",SNA_ROMRevision," [05/2006]"
                        DEFB 13,10,10
                        DEFB 0
ROM_skip_init_msg
                        ; system craps
                        POP HL
 POP DE
                        AND A
                        LD BC,32
 SBC HL,BC ;grab 32 bytes from top of memory
                        SCF
                        RET 

; --------------------------------------------------------------------------------------------------------------

                            ; must be called when the rom is initialised
                            ; required for snautoboot
SNA_ROM_Autoboot:
                            ; Check CPCBooster
                            call SNA_ROM_CPCB_Check
                            ret c ; do nothing at boot if something is wrong
                            
                            ; Fetch SNARAM
                            call SNA_ROM_Get_SNARAM
                            
                            ; Check if a snautoboot is enabled
                            ld hl,&BE0F ; flagbyte address
                            bit 0,(hl)  ; if bit0=1 then snautoboot is enabled
                            ret z
                            
                            ; keyboardscan
                            ld bc,&F782
                            out (c),c
                            ld bc,&F40E
                            out (c),c
                            ld bc,&F6C0
                            out (c),c
                            defw &71ED
                            ld bc,&F792
                            out (c),c
                            ld bc,&F642
                            out (c),c
                            ld b,&F4
                            in d,(c)
                            ld bc,&F782
                            out (c),c
                            dec b
                            defw &71ED
                            
                            bit 0,d ; CLR
                            jp z,SNA_ROM_Disable_Autoboot
                            bit 7,d ; CTRL
                            jp z,SNA_ROM_Skip_Autoboot
                            
                            ; Check AFT Link
                            call SNA_ROM_AFT_Check
                            ret c ; do nothing if no answer from AFT

                            CALL SNA_ROM_print_ntstr
                            DEFB " SNArkos AutoBoot : ",0
                            
                            ld hl,&BE03
                            ld b,12
                            call SNA_ROM_print_bchr

                            ld a,13
                            call &BB5A
                            ld a,10
                            call &BB5A
                            ld a," "
                            call &BB5A
                            
                            ; start SNArkos
                            jp SNA_ROM_snarkos
                            
                            
                            ; Disable SNA autoboot
SNA_ROM_Disable_Autoboot:
                            res 0,(hl)  ; if bit0=1 then snautoboot is enabled
                            
                            ; update SNARAM with provided filename and flags
                            call SNA_ROM_Set_SNARAM

                            CALL SNA_ROM_print_ntstr
                            DEFB " SNArkos autoboot disabled"
                            DEFB 13,10
                            DEFB 0
                            ret
                            
                            ; Skip SNA autoboot and
SNA_ROM_Skip_Autoboot:
                            CALL SNA_ROM_print_ntstr
                            DEFB " SNArkos autoboot skipped"
                            DEFB 13,10
                            DEFB 0
                            ret



                            ; require a filename            - Use "SNARKOS.SNA" by default
                            ; optional string parameters
                            ; Update the CPCBooster's RAM
SNA_RSX_sna
                            ; save RSX call-in parameters
                            ld (&BE10),a
                            
                            ; Check if CPCBooster & AFT are ok
                            call SNA_ROM_CPCB_Check
                            jp c,SNA_ROM_SystemError
                            call SNA_ROM_AFT_Check
                            jp c,SNA_ROM_SystemError
                            
                            ; fetch SNARAM
                            call SNA_ROM_Check_SNARAM
                            
                            ; check RSX's parameters
                            ld a,(&BE10)
                            cp 3
                            jp nc,SNA_RSX_UsageError
                            
                            ; Check if autoboot provided
                            cp 2
                            jr nz,SNA_RSX_noParamStr
                            ld hl,&BE0F
                            set 0,(hl)  ; set snautoboot flag
                            inc ix
                            inc ix
SNA_RSX_noParamStr
                            cp 1
                            ld hl,&BE03             ; sna filename from SNARAM
                            jp c,SNA_ROM_snarkos    ; no parameters, use filename from SNARAM as default
                            
                            ; clear filename
                            ld hl,&BE03
                            ld de,&BE04
                            ld (hl)," "
                            ld bc,11
                            ldir
                            
                            ld l,(ix+0)
                            ld h,(ix+1)
                            ld a,(hl) ; string size
                            or a
                            jp z,SNA_RSX_Badfilename ; string empty
                            cp 13
                            jp nc,SNA_RSX_filename_toolong ; string too long, bad filename
                            
                            ; filename lenght
                            ld b,a
                            ld c,9
                            ; filename address
                            inc hl
                            ld a,(hl)
                            inc hl
                            ld h,(hl)
                            ld l,a
                            ; read filename until "." is meet
                            ld de,&BE03
SNA_RSX_filename_parse
                            ld a,(hl)
                            cp "."
                            jr nz,SNA_RSX_filename_noext
                            ld c,d ; big value to cancel autodetection
SNA_RSX_filename_noext
                            dec c
                            jr nz,SNA_RSX_filename_noautoext
SNA_RSX_filename_addext
                            ld hl,SNA_ROM_default_SNAEXT
                            ld b,4
                            ld c,d ; big value to cancel autodetection
                            ld a,(hl)
SNA_RSX_filename_noautoext
                            ld (de),a
                            inc de
                            inc hl
                            dec b
                            jr nz,SNA_RSX_filename_parse
                            
                            ; check if fileext was added
                            ld a,13
                            cp c
                            jr nc,SNA_RSX_filename_addext
                            
                            
                            ; update SNARAM with provided filename and flags
                            call SNA_ROM_Set_SNARAM

                            ; start SNArkos
                            jp SNA_ROM_snarkos




SNA_ROM_CPCB_Check
                            ; Try to initialize CPCBooster
                            call CPCB_Init
                            jr nc,SNA_ROM_SystemFail_BoosterInit
    
                            ; BIOS version 1.5+ only
                            ; check if the Read/Write RAM functions are available
                            ld bc,&FF28
                            defw &71ED
                            inc c
                            ld de,&55AA
                            out (c),d
                            in a,(c)
                            cp d
                            jr nz,SNA_ROM_SystemFail_NoRAM_RW
                            out (c),e
                            in a,(c)
                            cp e
                            jr nz,SNA_ROM_SystemFail_NoRAM_RW
                            
                            xor a
                            ret

SNA_ROM_AFT_Check
                            ; Check AFT link
                            call CPCB_InitPC
                            jr nc,SNA_ROM_SystemFail_AftInit
                            xor a
                            ret


SNA_ROM_SystemFail_BoosterInit
                            ld a,1
                            scf
                            ret
SNA_ROM_SystemFail_NoRAM_RW
                            ld a,2
                            scf
                            ret
SNA_ROM_SystemFail_AftInit
                            ld a,3
                            scf
                            ret
                            
                            
                            ; **********
                            ; * ERRORS *
                            ; **********
SNA_ROM_SystemError
                            cp 1
                            jr z,SNA_BoosterInitFailled
                            cp 2
                            jr z,SNA_ROM_NoRAM_RW
                            cp 3
                            jp z,SNA_AftInitFailled
                            
                            ; unknow error
                            di
                            ld a,&4C
SNA_ColorCode       
                            ld bc,&7F10
                            out (c),c
                            out (c),a
                            defw &71ED
                            out (c),a
                            jr SNA_ColorCode

                        
                            ; what to do if CPCBooster's BIOS can not work with SNA
SNA_ROM_NoRAM_RW
                            call SNA_ROM_print_ntstr
                            DEFB "Update your CPCBooster's BIOS !"
                            DEFB 13,10
                            DEFB 0
                            RET
                        
                            ; what to do if SNA is used and CPCBooster failled to initialize
SNA_BoosterInitFailled
                            call SNA_ROM_print_ntstr
                            DEFB "No CPCBooster found !"
                            DEFB 0
                            RET
                        
                            ; what to do if we get no AFT anwser
SNA_AftInitFailled
                            call SNA_ROM_print_ntstr
                            DEFB "Can not link with AFT !"
                            DEFB 13,10
                            DEFB 0
                            RET
                    

                            ; Wrong RSX usage, display help
SNA_RSX_UsageError
                            call SNA_ROM_print_ntstr
                            DEFB "RSX usage :"
                            DEFB 13,10
                            DEFB 124,"SNA,filename[,autoboot]"
                            DEFB 0
                            ret

                            ; Bad SNA Filename
SNA_RSX_Badfilename
                            call SNA_ROM_print_ntstr
                            DEFB "Bad filename"
                            DEFB 13,10
                            DEFB 0
                            ret
                            
                            ; Bad SNA Filename, too long
SNA_RSX_filename_toolong
                            call SNA_ROM_print_ntstr
                            DEFB "Bad filename (Too long)"
                            DEFB 13,10
                            DEFB 0
                            ret
                            
                            ; Can not open file
SNA_RSX_CantOpenFile
                            call SNA_ROM_print_ntstr
                            DEFB "AFT can not open ",0
                            ld hl,&BE03
                            ld b,12
                            jp SNA_ROM_print_bchr

SNA_GetHeaderFailled
                            call SNA_AFT_CloseLink
                            call SNA_ROM_print_ntstr
                            DEFB 13,10,"Failled to receive SNA Header (Timeout)"
                            DEFB 13,10,"[R]etry ? (any other key to cancel) ",13,10
                            DEFB 0
                            ei
                            call &bdde
                            call &BB18
                            cp "R"
                            jp z,SNA_Retry
                            cp "r"
                            jp z,SNA_Retry
                            ; Cancel
                            ret
SNA_BadDataType
                            call SNA_AFT_CloseLink
                            call SNA_ROM_print_ntstr
                            DEFB "File is not a SNA"
                            DEFB 13,10
                            DEFB 0
                            ret
                            
SNA_UpperROM_enabled
                            call SNA_AFT_CloseLink
                            call SNA_ROM_print_ntstr
                            DEFB 15,3,"ERROR : Upper ROM enabled !",15,1,13,10
                            DEFB "This SNA can't be executed.",13,10
                            DEFB 0
                            ret
                            
SNA_AFT_CloseLink
                            ld bc,#ff08
                            ld a,&F2
                            out (c),a ; close
                            ret


                            ; display snapshot header in SNARAM
SNA_RSX_snahv
                            di
                            call SNA_ROM_CPCB_Check
                            jp c,SNA_ROM_SystemError
                            ei
                            
                            ld hl,SNA_RSX_snahv_gui
SNA_RSX_snahv_loop
                            ld a,(hl)
                            inc hl
                            cp 255  ; end code
                            ret z
                            
                            cp 254  ; display offset hex code
                            jp z,SNA_RSX_snahv_hex
                            cp 253  ; display offset enable/disable code
                            jp z,SNA_RSX_snahv_diei
                            cp 252  ; display snapshot name
                            jp z,SNA_RSX_snahv_name
                            
                            call &BB5A
                            jr SNA_RSX_snahv_loop
                            
SNA_RSX_snahv_hex
                            ld a,(hl)
                            inc hl
                            call SNA_RSX_snahv_getValue
                            call SNA_RSX_8bit_hex_str
                            jr SNA_RSX_snahv_loop
                            
SNA_RSX_snahv_diei
                            ld a,(hl)
                            inc hl
                            push hl
                            call SNA_RSX_snahv_getValue
                            ld hl,SNA_RSX_snahv_di_txt
                            ld b,8
                            or a
                            jr z,SNA_RSX_snahv_diei_txt
                            ld hl,SNA_RSX_snahv_ei_txt
                            ld b,7
SNA_RSX_snahv_diei_txt
                            call SNA_ROM_print_bchr
                            pop hl
                            jr SNA_RSX_snahv_loop
                            
SNA_RSX_snahv_di_txt        defb "disabled"
SNA_RSX_snahv_ei_txt        defb "enabled"
                            
                            
SNA_RSX_snahv_ink
                            
                            jr SNA_RSX_snahv_loop
SNA_RSX_snahv_name
                            ld a,&F3
SNA_RSX_snahv_name_loop
                            push af
                            call SNA_RSX_snahv_getValue
                            call &bb5A
                            pop af
                            inc a
                            cp &FF
                            jr nz,SNA_RSX_snahv_name_loop
                            jr SNA_RSX_snahv_loop

SNA_RSX_snahv_getValue
                            di
                            ld bc,&FF28
                            out (c),a
                            ld bc,&FF2A
                            in a,(c)
                            ei
                            ret

                            ; enable/disable FDC recalibration on a specified drive
                            ; disable FDC init if no parameters provided
SNA_RSX_snafdc
                            di
                            push af
                            call SNA_ROM_CPCB_Check
                            jp c,SNA_ROM_SystemError
                            call SNA_ROM_Check_SNARAM
                            ld hl,&BE0F ; SNA flags addr
                            ; defaults settings
                            res 2,(hl) ; default no FDC init
                            res 1,(hl) ; default drive 0
                            pop  af
                            
                            ; check rsx params
                            or a
                            jr z,SNA_RSX_snafdc_default
                            cp 1
                            jr nz,SNA_RSX_snafdc_error
                            
                            ; read parameter
                            ex de,hl
                            ld l,(ix+0)
                            ld h,(ix+1)
                            inc hl ; skip string size
                            ld a,(hl)
                            inc hl
                            ld h,(hl)
                            ld l,a
                            ld a,(hl)
                            ex de,hl
                            
                            ; A is the default drive
                            cp "A"
                            jr z,SNA_RSX_snafdc_enable
                            cp "a"
                            jr z,SNA_RSX_snafdc_enable
                            
                            cp "B"
                            jr z,SNA_RSX_snafdc_B
                            cp "b"
                            jr nz,SNA_RSX_snafdc_default
SNA_RSX_snafdc_B
                            set 1,(hl)
SNA_RSX_snafdc_enable
                            set 2,(hl)
                            call SNA_ROM_print_ntstr
                            DEFB "FDC SeekTrack0 enabled"
                            DEFB 0
                            jr SNA_RSX_snafdc_apply
SNA_RSX_snafdc_default
                            call SNA_ROM_print_ntstr
                            DEFB "FDC SeekTrack0 disabled"
                            DEFB 0
SNA_RSX_snafdc_apply
                            call SNA_ROM_Set_SNARAM
                            ei
                            ret

SNA_RSX_snafdc_error
                            ei
                            call SNA_ROM_print_ntstr
                            DEFB "RSX usage :"
                            DEFB 13,10
                            DEFB 124,"SNAFDC[,",34,"drive",34,"] (drive = A or B)",13,10
                            DEFB "No drive argument disable seekTrack0"
                            DEFB 0
                            ret
                            

SNA_RSX_8bit_hex_str                
                            push af
                            call SNA_RSX_8bit_hex_str_1
                            pop af
                            jr SNA_RSX_8bit_hex_str_2
SNA_RSX_8bit_hex_str_1      rra
                            rra
                            rra
                            rra
SNA_RSX_8bit_hex_str_2      or &F0
                            daa
                            add a,&A0
                            adc a,&40
                            jp &BB5A
                            


SNA_RSX_snahv_gui
                            defb 4,2,"SNArkos Header Viewer for ",252,13,10,10
                            defb "Z80  : Interrupts ",253,&1b," in mode ",254,&25," (I=",254,&1a,")",13,10
                            defb " HL =",254,&18,254,&17,"  DE =",254,&16,254,&15,"  BC =",254,&14,254,&13,"  AF =",254,&12,254,&11,"  IX=",254,&1E,254,&1D,"  SP=",254,&22,254,&21, 13,10
                            defb " HL'=",254,&2D,254,&2C,"  DE'=",254,&2B,254,&2A,"  BC'=",254,&29,254,&28,"  AF'=",254,&27,254,&26,"  IY=",254,&20,254,&1F,"  PC=",254,&24,254,&23, 13,10,10
                            
                            defb "CRTC : Register ",254,&42," is selected",13,10
                            defb " R0 =",254,&43,"  R1 =",254,&44,"  R2 =",254,&45,"  R3 =",254,&46,"  R4 =",254,&47,"  R5 =",254,&48,"  R6 =",254,&49,"  R7 =",254,&4A,"  R8 =",254,&4B,13,10
                            defb " R9 =",254,&4C,"  RA =",254,&4d,"  RB =",254,&4e,"  RC =",254,&4f,"  RD =",254,&50,"  RE =",254,&51,"  RF =",254,&52,"  R10=",254,&53,"  R11=",254,&54, 13,10,10
                            
                            defb "AY3  : Register ",254,&5a," is selected",13,10
                            defb " R0=",254,&5b,"  R1=",254,&5c,"  R2=",254,&5d,"  R3=",254,&5e,"  R4=",254,&5f,"  R5=",254,&60,"  R6=",254,&61,"  R7=",254,&62,13,10
                            defb " R8=",254,&63,"  R9=",254,&64,"  RA=",254,&65,"  RB=",254,&66,"  RC=",254,&67,"  RD=",254,&68,"  RE=",254,&69,"  RF=",254,&6a,13,10,10
                            
                            defb "Palette ink ",254,&2e," is selected",13,10
                            defb " HARD: ",254,&2f,",",254,&30,",",254,&31,",",254,&32,",",254,&33,",",254,&34,",",254,&35,",",254,&36,",",254,&37,",",254,&38,",",254,&39,",",254,&3A,",",254,&3B,",",254,&3C,",",254,&3D,",",254,&3E,"   BORDER ",254,&3F, 13,10,10
                            
                            defb "GA RAM Configuration  : ",254,&41,13,10
                            defb "GA Misc Configuration : ",254,&40,13,10,10
                            
                            defb "Selected Upper ROM    : ",254,&55,13,10,10
                            defb 255
                            
                            
                            
                            ; edit sna header value
                            ; once the header has been changed, snarkos wont use the one in the loaded SNA file anymore
                            ; but the one modified
                            ; ùsnaw,"CRTC",7,35
                            ; ùsnaw,"AY3",7,63
                            ; ùsnaw,"PAL",3,5
                            ; ùsnaw,"RAM",&C0
                            ; ...
;SNA_RSX_snahw

                            ; reset header
                            ; go back to normal mode after using snaw
                            ; header is automatically reseted when a different snapshot file is loaded
;SNA_RSX_snahr
                            
                            ; **********
                            ; * SNARAM *
                            ; **********
                            
                            ; SNARAM is 16 bytes in the CPCBooster RAM from &F0 to &FF
                            ; used to store the SNA filename and SNA flags (autoboot).

                            ; ZeroFill SNARAM and &BE00
SNA_ROM_Clear_SNARAM
                            ld hl,&BE00
                            ld de,&BE01
                            ld bc,&10
                            ld (hl),l
                            ldir
                            jr SNA_ROM_Set_SNARAM

SNA_ROM_Check_SNARAM
                            call SNA_ROM_Get_SNARAM
                            ld hl,&BE00
                            ld de,SNA_ROM_default_SNARAM
                            ld b,3
SNA_ROM_Check_SNARAM_loop
                            ld a,(de)
                            cp (hl)
                            jr nz,SNA_ROM_Check_SNARAM_fail
                            inc de
                            inc hl
                            dec b
                            jr nz,SNA_ROM_Check_SNARAM_loop
                            
                            ; check successfull
                            ; SNARAM already 
                            ret
                            
SNA_ROM_Check_SNARAM_fail
                            ; check failled
                            ; Initialize SNARAM with default values
SNA_ROM_Init_SNARAM
                            ld hl,SNA_ROM_default_SNARAM
                            ld de,&BE00
                            ld bc,&10
                            ldir

                            ; &BE00 to SNARAM
SNA_ROM_Set_SNARAM
                            ld bc,&FF28
                            ld l,&F0
                            out (c),l
                            ld bc,&FF2A
                            ld hl,&BE00
SNA_ROM_Set_SNARAM_loop
                            ld a,(hl)
                            out (c),a
                            inc hl
                            bit 4,l
                            jr z,SNA_ROM_Set_SNARAM_loop
                            ret

                            ; SNARAM to &BE00
SNA_ROM_Get_SNARAM
                            ld bc,&FF28
                            ld l,&F0
                            out (c),l
                            ld bc,&FF2A
                            ld hl,&BE00
SNA_ROM_Get_SNARAM_loop
                            ini
                            inc b
                            bit 4,l
                            jr z,SNA_ROM_Get_SNARAM_loop
                            ret

                            ; Default 16 bytes SNARAM
                            ; "Aks" is a tag to detect if SNARAM is already initialized or not
SNA_ROM_default_SNARAM      
                            defb "Aks","SNARKOS"
SNA_ROM_default_SNAEXT
                            defb ".SNA ",0


                            
                            ; display a null terminated text string located
                            ; after the CALL to this routine.
SNA_ROM_print_ntstr
                            pop hl
                            ld a,(hl)
                            inc hl
                            call &BB5A
                            or a
                            jr nz,SNA_ROM_print_ntstr+1
                            jp (hl)
SNA_ROM_print_bchr
                            ld a,(hl)
                            inc hl
                            call &BB5A
                            dec b
                            jr nz,SNA_ROM_print_bchr
                            ret
                            
    list
    ;*** debut cpcb
    nolist
                            ; CPCBooster device
                            include "serial.asm"

SNA_ROM_snarkos:                        
                            ; Booster & AFT are OK
                            ; proceed with the SNA
                            include "SNArkos.asm"
