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
_SER_CMD_AVAIL  equ 0x01        ; Serial command, num bytes available
