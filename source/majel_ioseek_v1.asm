;
; MAJEL-1 I/O SEEK DRIVER V1
; 
; Identifies hardware using a 16-bit device ID and provides a utility for retrieving a hardware address by 
; that device ID. Hardware addresses, unlike device IDs, can be used directly by native I/O operations. Hardware that 
; does not conform to the standard I/O device ID protocol may respond unpredictably to being scanned.
;
; Standard I/O device ID protocol:
;  - Write command data=0xFE
;  - Read command data=0xAA
;  - Read command data=0x55
;  - Read command data=DID_LOW
;  - Read command data=DID_HI
;
; Devices which do not respond with the AA,55 sequence will not be polled for further data and will be issued the
; standard reset protocol: write command data=0xFF
;
; Author: Erik W. Greif
; Date: 2021-06-25
;


; ==============================================================================
; R_IO_SCANALL: Scan all I/O devices
;
; Sequentially queries each command port on the card backplane to derive the
; device IDs. Each device ID is recorded. 0x0000 and 0xFFFF are invalid device 
; IDs. If a port does not respond as expected, a standard reset command is sent
; to the device before proceeding, and it is treated as an empty slot.
; 
; MOD: HL, C, AF
; ==============================================================================
R_IO_SCANALL:
                ld C,_IO_PORTSTART
                ld HL,_IO_TBLSTART
__rio_begin:    ld A,_IO_CMD_DID
                out (C),A               ; Write I/O DID command
                in A,(C)
                cp _IO_RSP_SB1          ; Verify first static protocol byte
                jp nz,__rio_bad_rsp
                in A,(C)
                cp _IO_RSP_SB2          ; Verify second static protocol byte
                jp nz,__rio_bad_rsp
                in A,(C)
                ld (HL),A               ; Store lower device ID byte
                inc HL
                in A,(C)
                ld (HL),A               ; Store upper device ID byte
                inc HL
                
__rio_next:     ld A,_IO_PORTMAX
                cp C
                ret z                   ; Done once we've scanned the final port
                inc C
                inc C                   ; Next card is 2 hardware addresses up
                jp __rio_begin          ; Scan next card

__rio_bad_rsp:  ld A,0xFF
                out (C),A               ; Send standard reset command (just in case)
                ld A,0x00
                ld (HL),A               ; Zero out this device ID low
                inc HL
                ld (HL),A               ; Zero out this device ID high
                inc HL
                jp __rio_next


; ==============================================================================
; R_IO_FIND: Find an IO device
;
; Locates a device by device ID if it exists, and returns the data port. 
; Note that command ports are always immediately above their corresponding data
; port.
; 
; ARG: DE the desired device ID
; RET: B the hardware port, or junk if F.Z
; RET: F.Z if the device was not found
; MOD: HL, DE, FA, B
; ==============================================================================
R_IO_FIND:
                ld B,0
                ld HL,_IO_TBLSTART
__rio_fbegin:   ld A,(HL)
                inc HL
                cp E
                jp nz,__rio_findnext
                ld A,(HL)
                cp D
                jp nz,__rio_findnext
                
                ld A,B
                add B
                add 0xF0
                ld B,A                  ; B = B + B + 0xF0
                
                ld A,0x00
                cp B
                ret                     ; B points to the current port, Z flag unset
                
__rio_findnext: inc B
                inc HL
                ld A,_IO_SLOT_COUNT
                cp B
                jp nz,__rio_fbegin
                
                ret                     ; B should be ignored, Z flag is set
                
                









