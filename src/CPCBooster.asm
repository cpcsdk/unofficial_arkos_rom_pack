    ;CPCBooster serial communication code.



;Initialise CPCB, baudrate etc...,
;RET=Carry=1=ok 0=non detectee.
CPCB_Init
    ld bc,#ff00
    in a,(c)
    cp 170
    jr nz,CPCBError
    inc c
    in a,(c)
    cp 85
    jr nz,CPCBError

    ld c,#04        ;Setting Baudrate to 115200.
    ld a,#05
    out (c),c
    out (c),a

    ld c,#07        ;Asynchronous, no Parity, 1 bit stop, 8 bits carac.
    ld a,%00000110
    out (c),c
    out (c),a

    ld c,#0b        ;Enables buffer.
    in a,(c)
    set 4,a
    out (c),a

    ld c,#1c        ;Reset buffer.
    xor a
    out (c),a

    scf
    ret



;Recoit un octet de la CPCB (avec flash de couleur. Activer encre d'abord !)
;RET=Carry=1=OK et A=byte   Carry=0=timeout
CPCB_GetByte
    ld bc,#7f55
    out (c),c
    ld bc,#ff1c
    ld de,CPCB_TimeoutValue
CPCBGBLp dec de
    ld a,d
    or e
    jr z,CPCBError  ;Timeout
    in a,(c)
    or a
    jr z,CPCBGBLp

    inc c
    in a,(c)
;
    ld bc,#7f44
    out (c),c
    scf
    ret



;Envoi un octet a la CPCB
;A=byte
CPCB_SendByte
    ld bc,#ff08
    out (c),a
    ret



