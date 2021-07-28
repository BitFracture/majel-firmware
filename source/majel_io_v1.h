;
; MAJEL-1 BASIC I/O HEADER V1
;
; Used by routines that wish to statically address hardware. For dynamic hardware
; addressing, see IOSEEK library and use compliant hardware. 
; 
; Author: Erik W. Greif
; Date: 2021-06-25
;

IFNDEF IODAT0

; I/O backplane hardware addresses
IODAT0:         equ 0xF0        ; IO card 0 data channel
IOCMD0:         equ 0xF1        ; IO card 0 command channel
IODAT1:         equ 0xF2        ; IO card 1 data channel
IOCMD1:         equ 0xF3        ; IO card 1 command channel
IODAT2:         equ 0xF4        ; IO card 2 data channel
IOCMD2:         equ 0xF5        ; IO card 2 command channel
IODAT3:         equ 0xF6        ; IO card 3 data channel
IOCMD3:         equ 0xF7        ; IO card 3 command channel
IODAT4:         equ 0xF8        ; IO card 4 data channel
IOCMD4:         equ 0xF9        ; IO card 4 command channel
IODAT5:         equ 0xFA        ; IO card 5 data channel
IOCMD5:         equ 0xFB        ; IO card 5 command channel
IODAT6:         equ 0xFC        ; IO card 6 data channel
IOCMD6:         equ 0xFD        ; IO card 6 command channel
IODAT7:         equ 0xFE        ; IO card 7 data channel
IOCMD7:         equ 0xFF        ; IO card 7 command channel

ENDIF
