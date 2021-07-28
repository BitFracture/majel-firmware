;
; MAJEL-1 I/O SEEK DRIVER HEADER V1
; 
; 16-byte memory footprint designed to be allocated above the stack. Provides a location input and a location output
; for packing memory.
;
; Author: Erik W. Greif
; Date: 2021-06-25
;

                include "majel_io_v1.h"

IFNDEF IOTBL_MAX_ADDR
IOTBL_MAX_ADDR  equ 0x0200          ; Start at byte 511 on down (default)
ENDIF

; Size vars
_IO_WORDSIZE    equ 2

; Gen vars
_IO_TBLSTART    equ IOTBL_MAX_ADDR - (_IO_WORDSIZE * 8)    ; Lowest addr of I/O DID table

; We can calculate exact buffer size (for compact allocation)
IOTBL_LOC       equ _IO_TBLSTART    ; ALways point at last chained variable
IOTBL_SIZE      equ IOTBL_MAX_ADDR - IOTBL_LOC

; Other variables
_IO_PORTSTART   equ IOCMD0          ; Start at slot 0's command port
_IO_PORTMAX     equ IOCMD7          ; Stop after slot 7's command port
_IO_CMD_DID     equ 0xFE            ; Command for getting device ID
_IO_RSP_SB1     equ 0xAA            ; First DID static response byte
_IO_RSP_SB2     equ 0x55            ; Second DID static response byte
_IO_SLOT_COUNT  equ 8               ; 8 IO slots
