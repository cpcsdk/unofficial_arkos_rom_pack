    ; This file implements the AFT protocol. It includes the low-level serial
    ; port (or socket) routines.
    ;V1.0 by Targhan/Arkos.


CPCB_InitCommand equ #f0
CPCB_ReceiveCommand equ #f1
CPCB_OpenInputFileCommand equ #fc
CPCB_EndCommand equ #f2
CPCB_RewindCommand equ #f3
CPCB_AskFileSizeCommand equ #f4
CPCB_AskFileNameCommand equ #f5
CPCB_CreateOutputFileCommand equ #f6
CPCB_AddDataToOutputFileCommand equ #f7
CPCB_CloseOutputFileCommand equ #f8

CPCB_InitDSKCommand equ #f9
CPCB_SendTrackCommand equ #fa
CPCB_NoMoreTrackCommand equ #fb

CPCB_InitConfirmedFromPC equ #80
CPCB_FileCreated equ #80

CPCB_TimeoutValue equ #4000

    list
;**** Debut CPCBooster
    nolist

CPCB_CODEDEBUT

    ; NOTE --------------------------------------------------------------------
    ; Each driver must provide the following routines:
    ; CPCB_Init      - Initialize the hardware (baudrate, etc)
    ;                  Sets carry if ok, clears it on error.
    ; CPCB_GetByte   - Reads 1 byte from the serial port/socket
    ;                  Sets carry if ok, clears on timeout
    ;                  Read byte is returned in A.
    ;                  This routine is also responsible for flashing an ink
    ;                  (which must be selected before in the GA) to show activity.
    ; CPCB_SendByte  - Sends 1 byte to the serial port/socket
    ;                  Byte to send is passed in A.
    ;                  This may not fail, but you may just not send the byte.
    ;                  The next read will then likely timeout.

    ifdef FLAVOR_CPCWIFI
        fail "[ERROR] This code cannot be used for the CPC wifi. It is necessary to use specific code"
    endif

    ifdef FLAVOR_CPCBOOSTER
        include CPCBooster.asm
    endif

    ifdef FLAVOR_ALBIREO
        include Albireo.asm
    endif


;Essaye de communiquer l'init avec le PC. Il y a un timeout pour reessayer si erreur.
;RET=Carry=1=ok 0=communication failed.
CPCB_InitPC
    ld a,CPCB_InitCommand
    call CPCB_SendByte

    call CPCB_GetByte
    jr nc,CPCBError         ;Not carry=timeout
    cp CPCB_InitConfirmedFromPC
    jr nz,CPCBError
    scf
    ret


;Envoi un paquet d'octet a la CPCB.
;Cette routine ne fait qu'envoyer ces octets. Il faut lancer une commande avant si on veut que le PC
;comprenne.
;HL=donnees
;DE=taille
CPCB_SendXBytes
    ld a,(hl)
    call CPCB_SendByte
    inc hl
    dec de
    ld a,e
    or d
    jr nz,CPCB_SendXBytes
    ret

;Recoit X octets de la CPCB vers MEMOIRE LINEAIRE.
;Cette routine prepare l'envoi et demande au PC de lui envoyer ces octets grace a la commande Receive.
;HL=Nombre d'octets a recevoir
;DE=Destination
CPCB_GetXBytes
    ld a,CPCB_ReceiveCommand
    call CPCB_SendByte
    ld a,l              ;Send the size to receive.
    call CPCB_SendByte
    ld a,h
    call CPCB_SendByte
CPCB_GetXBLoop
    push de
CPCB_GetXBL2 call CPCB_GetByte
    jr nc,CPCB_GetXBL2      ;Si Timeout, on recommence
    pop de
    ld (de),a
    inc de
    dec hl
    ld a,l
    or h
    jr nz,CPCB_GetXBLoop
    ret


CPCBError or a
    ret

;Ouvre un fichier en entree.
;Envoi 12 octets (filename)
;Recoit octet de confirmation.
;HL=filename
;RET=Carry=1=ok  0=pas ok
CPCB_OpenInputFile
    ld a,CPCB_OpenInputFileCommand
    jr CPCB_OIF2


;Quand transfert termine, envoi de commande de fin. Ferme tous les fichiers en sortie et entree.
CPCB_SendEndCommand
    ld a,CPCB_EndCommand
    call CPCB_SendByte
    ret



;Demande de nom fichier. Recoit 12 bytes (nom+point+ext)
;HL=Destination
CPCB_AskFileName
    ld a,CPCB_AskFileNameCommand
    call CPCB_SendByte
    ld d,12
CPCB_AFNLoop
    push de
    call CPCB_GetByte
    pop de
    ld (hl),a
    inc hl
    dec d
    jr nz,CPCB_AFNLoop
    ret


;Demande de filesize. Recoit 4 bytes, du point faible au point fort
;HL=Destination
CPCB_AskFileSize
    ld a,CPCB_AskFileSizeCommand
    call CPCB_SendByte
    ld d,4
    jr CPCB_AFNLoop


;Le pointeur PC du fichier est remis au debut du fichier.
CPCB_RewindFile
    ld a,CPCB_RewindCommand
    call CPCB_SendByte
    ret



;Cree un fichier PC
;HL=filename (8+point+3)
;RET=Carry=1=Ok 0=Echec
CPCB_CreateOutputFile
    ld a,CPCB_CreateOutputFileCommand
CPCB_OIF2
    call CPCB_SendByte

    ld de,12
    call CPCB_SendXBytes

    call CPCB_GetByte
    jp nc,CPCBError         ;Not carry=timeout
    cp CPCB_FileCreated
    jp nz,CPCBError
    scf
    ret



;Envoi une commande pour ajouter des datas a un fichier PC deja ouvert.
;HL=donnees
;DE=taille
CPCB_AddDataToOutputFile
    ld a,CPCB_AddDataToOutputFileCommand
    call CPCB_SendByte
    ld a,e
    call CPCB_SendByte
    ld a,d
    call CPCB_SendByte

    call CPCB_SendXBytes
    ret



;Fermeture du fichier PC en sortie.
CPCB_CloseOutputFile
    ld a,CPCB_CloseOutputFileCommand
    call CPCB_SendByte
    ret


;Dis au PC de generer un DSK vide, pour l'instant.
;Demande les 2 chars du createur (10 pour 1.0 par ex), nb tracks, nb sides
;H=NBTracks L=NBSides
;D=1er char E=2e char
CPCB_InitDSK
    ld a,CPCB_InitDSKCommand
    call CPCB_SendByte
    ld a,d
    call CPCB_SendByte
    ld a,e
    call CPCB_SendByte
    ld a,h
    call CPCB_SendByte
    ld a,l
    call CPCB_SendByte
    ret


;Previens le PC que les donnees d'une track (info+donnees) vont arriver
CPCB_SendTrack
    ld a,CPCB_SendTrackCommand
    call CPCB_SendByte
    ret

;Dis au PC qu'il n'y a plus de track a recevoir. Il peut donc ecrire le DSK sur le DD.
CPCB_NoMoreTrack
    ld a,CPCB_NoMoreTrackCommand
    call CPCB_SendByte
    ret


    list
;**** Fin CPCBooster
    nolist


CPCB_CODEFIN
