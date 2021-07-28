;
; MAJEL-1 FILE SYSTEM DRIVER HEADER V1
;
; MajelFS is designed to run with almost no memory footprint when used with
; onboard buffer of the SD card interface. It should use significantly less
; than 200 bytes. The Majel-1 onboard firmware allocates this space directly
; above the stack, so that it is not overwritten while loading programs to 
; memory. This driver is optimized for that use case, and more efficient 
; implementations may be feasible for other use cases. 
;
; Author: Erik W. Greif
; Date: 2021-06-16
;


IFNDEF MFS_MAX_ADDR
MFS_MAX_ADDR    equ 0x0100      ; Start at byte 255 on down (default)
ENDIF

; Size vars
_MFS_LABELMAX   equ 31
_MFS_LABELSIZE  equ 32
_MFS_LONGSIZE   equ 8
_MFS_BYTESIZE   equ 1

; Gen vars
_MFS_BFFRLBL    equ MFS_MAX_ADDR  - _MFS_LABELSIZE  ; FS label buffer
_MFS_GENLONG0   equ _MFS_BFFRLBL  - _MFS_LONGSIZE   ; General purpose num
_MFS_GENLONG1   equ _MFS_GENLONG0 - _MFS_LONGSIZE   ; General purpose num
_MFS_GENLONG2   equ _MFS_GENLONG1 - _MFS_LONGSIZE   ; General purpose num
_MFS_GENLONG3   equ _MFS_GENLONG2 - _MFS_LONGSIZE   ; General purpose num
_MFS_ZEROLONG   equ _MFS_GENLONG3 - _MFS_LONGSIZE   ; Always 0
_MFS_GENBYTE0   equ _MFS_ZEROLONG - _MFS_BYTESIZE   ; Current dir index
_MFS_BLOCK      equ _MFS_GENBYTE0 - _MFS_LONGSIZE   ; Current loaded block
_MFS_OFFSET     equ _MFS_BLOCK    - _MFS_BYTESIZE   ; Current block offset
_MFS_ADDRESS    equ _MFS_OFFSET
                ; NOTE: reading offset as a 64-bit number yields a 
                ; full address by overflowing into block. This is intentional.
_MFS_TRUNC      equ _MFS_OFFSET   - _MFS_BYTESIZE   ; Current block truncation
_MFS_IOCMD      equ _MFS_TRUNC    - _MFS_BYTESIZE   ; IO addr SD cmd channel
_MFS_IODAT      equ _MFS_IOCMD    - _MFS_BYTESIZE   ; IO addr SD data channel

_MFS_FLAGS      equ _MFS_IODAT    - _MFS_BYTESIZE   ; Flags related to FS state

_MFSFLG_CONN    equ 0                               ; _MFS_FLAGS.0 = MFS is connected
_MFSFLG_OPEN    equ 1                               ; _MFS_FLAGS.1 = File is open
_MFSFLG_WR      equ 2                               ; _MFS_FLAGS.2 = The open file permits writing
_MFSFLG_DIR     equ 3                               ; _MFS_FLAGS.3 = Directory is open
_MFSFLG_IDLE    equ 4                               ; _MFS_FLAGS.4 = Nothing is open

; We can calculate exact buffer size (for compact allocation)
MFS_CACHE_LOC   equ _MFS_FLAGS ; Always point at last chained variable
MFS_CACHE_SIZE  equ MFS_MAX_ADDR - MFS_CACHE_LOC

MFS_ERRCD_IO_NOT_FOUND  equ 0xFF
MFS_ERRCD_NO_CARD       equ 0xFE
MFS_ERRCD_NO_FORMAT     equ 0xFD
MFS_ERRCD_BAD_VERSION   equ 0xFC
MFS_ERRCD_CONNECTED     equ 0xFB

_CMD_OPEN       equ 0x00        ; SD card open command
_CMD_SETADDR    equ 0x04        ; SD card set full 64-bit address

_MFS_OFFSET_DIR0        equ 0x02 ; Calculated using 2 + (1 * 82)
_MFS_OFFSET_DIR1        equ 0x54 ; Calculated using 2 + (2 * 82)
_MFS_OFFSET_DIR2        equ 0xA6 ; Calculated using 2 + (3 * 82)

_MFS_OFFSET_FSLBL       equ 0x40
_MFS_OFFSET_FSDIRBLK    equ 0x18
_MFS_OFFSET_DIRLBL      equ 0x00
_MFS_OFFSET_DIRBLK      equ 0x20
_MFS_OFFSET_NXTBLK      equ 0xF8









