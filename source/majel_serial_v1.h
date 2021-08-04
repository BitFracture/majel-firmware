;
; MAJEL-1 SERIAL LIB V1 HEADER
;
; Author: Erik W. Greif
; Date: 2021-07-27
;

_SER_BYTESIZE   equ 1

IFNDEF SER_MAX_ADDR
SER_MAX_ADDR    equ 0x0100      ; Start at byte 255 on down (default)
ENDIF

_SER_IOCMD:     equ SER_MAX_ADDR - _SER_BYTESIZE ; Pointer to serial I/O command port
_SER_IODAT:     equ _SER_IOCMD   - _SER_BYTESIZE ; Pointer to serial I/O data port

SER_CACHE_LOC   equ _SER_IODAT                   ; Always points to last allocation

; Commands for serial card
_SER_CMD_AVAIL  equ 0x01        ; Get num bytes available
_SER_CMD_SETINT equ 0x02        ; Set interrupt vector
_SER_CMD_CLRINT equ 0x03        ; Clear interrupt vector

; Important characters
_SER_CH_CR      equ 0x0D
_SER_CH_LF      equ 0x0A
_SER_CH_LOWEST  equ 0x20
_SER_CH_HIGHEST equ 0x7E
_SER_CH_DEL     equ 0x7F
_SER_CH_BCK     equ 0x08
