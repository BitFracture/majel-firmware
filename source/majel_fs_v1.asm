;
; MAJEL-1 FILE SYSTEM DRIVER V1
; 
; This library consists of a file system driver for MAJEL FS. This driver 
; depends critically on the Majel-1 SD card adapter board, which may be 
; configured for any of the 8 available IO slots at runtime. 
;
; Author: Erik W. Greif
; Date: 2021-06-16
;


; ==============================================================================
; R_MFS_SETUP: Majel setup
;
; Format variables to known-good state. 
;
; MOD: NONE
; ==============================================================================
R_MFS_SETUP:    
                push AF
                push BC
                
                ; Zero-write longs
                ld BC,_MFS_BLOCK
                call R_ZINT64
                ld BC,_MFS_ZEROLONG
                call R_ZINT64
                
                ; Zero-write bytes
                ld A,0x00
                ld (_MFS_OFFSET),A
                ld (_MFS_BLKTRUNC),A
                ld (_MFS_IOCMD),A
                ld (_MFS_IODAT),A
                ld (_MFS_FLAGS),A
                
                ; Blank-terminate string buffer
                ld (_MFS_BFFRLBL),A
                
                pop BC
                pop AF
                ret


; ==============================================================================
; M_SENDN: Sends N bytes from a memory pointer to I/O (C)
; 
; ARG: C I/O address
; ARG: HL memory address
; MOD: AF, HL, BC
; ==============================================================================
MACRO M_SENDN BYTES,POINTER
        ld B,{BYTES}
        ld HL,{POINTER}
        otir
MEND


; ==============================================================================
; M_RECVN: Receives N bytes from I/O (C) to a memory pointer
; 
; ARG: C I/O address
; ARG: HL memory address
; MOD: AF, HL, BC
; ==============================================================================
MACRO M_RECVN BYTES,POINTER
        ld B,{BYTES}
        ld HL,{POINTER}
        inir
MEND


; ==============================================================================
; R_MFS_CONNECT: Find SD card reader, find the card, and find the file system
;
; RET: A status of the connection
;      0x00 = connected, ready to read
;      MFS_ERRCD_IO_NOT_FOUND = The SD card reader I/O hardware was not found
;      MFS_ERRCD_NO_CARD      = SD card not inserted
;      MFS_ERRCD_NO_FORMAT    = SD card not formatted with MajelFS
;      MFS_ERRCD_BAD_VERSION  = MajelFS version not supported
;      MFS_ERRCD_CONNECTED    = File system already connected, disconnect first
; MOD: AF
; ==============================================================================
R_MFS_CONNECT:  
                push HL
                push DE
                push BC

                ; We won't connect if we're already connected
                call R_MFS_ISCONNECT
                jp nz,__fsc_errac

                ; Find the hardware card
                call _R_INIT_SD     ; Is the I/O card present?    
                jp z,__fsc_errhw    ; Zero flag means card not found    
                
                ; Find the SD card
                ld BC,(_MFS_IOCMD)
                ld A,_CMD_OPEN
                out (C),A           ; Open an SD card
                in A,(C)            ; Get status
                bit 0,A
                jp z,__fsc_errsd    ; Zero A.0 means card not inserted
                
                ; Reset the file system address
                ld BC,_MFS_BLOCK
                call R_ZINT64
                ld BC,_MFS_OFFSET
                call R_ZINT8
                ld BC,(_MFS_IOCMD)
                ld A,_CMD_SETADDR   ; Set full 8-bit SD card address
                out (C),A
                M_SENDN 8,_MFS_ADDRESS ; Send address
                
                ; Read Majel-FS header string
                ld BC,(_MFS_IODAT)
                M_RECVN 7,_MFS_BFFRLBL ; Read FS header
                ld (HL),0x00        ; Null terminate!
                
                ; Check for correct header string
                ld DE,_mfs_st_header
                ld HL,_MFS_BFFRLBL
                call R_STRCMP
                jp nz,__fsc_errfs   ; Non-zero means header didn't match
                
                ; Check for correct FS version
                in A,(C)            ; The next byte is version
                cp A,0x00           ; We only support version 0
                jp nz,__fsc_errfv   ; Non-zero means unsupported version
                
                ld A,(_MFS_FLAGS)   
                set _MFSFLG_CONN,A  ; Indicate we are connected
                set _MFSFLG_IDLE,A  ; Indicate we are idling
                ld (_MFS_FLAGS),A
                ld A,0              ; Success code!

__fsc_done      pop BC
                pop DE
                pop HL
                ret
                
__fsc_errhw     ld A,MFS_ERRCD_IO_NOT_FOUND
                jp __fsc_done
__fsc_errsd     ld A,MFS_ERRCD_NO_CARD
                jp __fsc_done
__fsc_errfs     ld A,MFS_ERRCD_NO_FORMAT
                jp __fsc_done
__fsc_errfv     ld A,MFS_ERRCD_BAD_VERSION
                jp __fsc_done
__fsc_errac     ld A,MFS_ERRCD_CONNECTED
                jp __fsc_done

                
; ==============================================================================
; R_MFS_ISCONNECT: Checks whether FS is already connected
;
; RET: F.Z means not connected
; MOD: AF
; ==============================================================================
R_MFS_ISCONNECT:
                ld A,(_MFS_FLAGS)
                bit _MFSFLG_CONN,A
                ret

                
; ==============================================================================
; R_MFS_ISFILEOPEN: Checks whether a file is open
;
; RET: F.Z means not open
; MOD: AF
; ==============================================================================
R_MFS_ISFILEOPEN:
                ld A,(_MFS_FLAGS)
                bit _MFSFLG_OPEN,A
                ret


; ==============================================================================
; R_MFS_ISDIROPEN: Checks whether the directory is open
;
; RET: F.Z means not open
; MOD: AF
; ==============================================================================
R_MFS_ISDIROPEN:
                ld A,(_MFS_FLAGS)
                bit _MFSFLG_DIR,A
                ret


; ==============================================================================
; R_MFS_ISIDLE: Checks whether nothing is open, state is idle
;
; RET: F.Z means not idle
; MOD: AF
; ==============================================================================
R_MFS_ISIDLE:
                ld A,(_MFS_FLAGS)
                bit _MFSFLG_IDLE,A
                ret


; ==============================================================================
; _R_INIT_SD: Finds the SD card and initializes our I/O pointers
;
; RET: F.Z indicates card controller not found
; ==============================================================================
_R_INIT_SD:     
                call R_IO_SCANALL   ; Scan for all hardware device IDs
                ld DE,0x0002        ; SD card device ID
                call R_IO_FIND      ; Find the serial card!
                ret, z              ; SD was not found!
__insd_fin:     ld C,B              ; Put data channel in C
                inc B               ; Put command channel in B
                ld (_MFS_IODAT),BC  ; Store in RAM for other methods to use
                ret                 ; F.Z will be FALSE since inc B cannot be 0


; ==============================================================================
; R_MFS_GETLBL: Get volume label
;
; Only works if file system is connected and at idle. Examples of not being at 
; idle include having a file or the directory open.
; 
; RET: HL contains a temporary pointer to a null term string
; MOD: HL
; ==============================================================================
R_MFS_GETLBL:
                push BC
                push AF
                ld HL,_MFS_BFFRLBL
                ld (HL),0x00        ; Blank the buffer
                
                ; Ensure we're in a good state
                call R_MFS_ISIDLE
                jp z,__fslbl_done   ; Abort if not idle
                
                ; Go to block 0 offset 64
                ld BC,_MFS_BLOCK
                call R_ZINT64
                ld A,_MFS_OFFSET_FSLBL
                ld (_MFS_OFFSET),A
                
                ld BC,(_MFS_IOCMD)
                ld A,_CMD_SETADDR
                out (C),A
                M_SENDN 8,_MFS_ADDRESS
                
                ; Get label
                ld BC,(_MFS_IODAT)
                M_RECVN _MFS_LABELMAX,_MFS_BFFRLBL
                ld (HL),0x00        ; Null term it
                
__fslbl_done:   ld HL,_MFS_BFFRLBL
                pop AF
                pop BC
                ret


; ==============================================================================
; R_MFS_OPENFILE: Open a file for reading
;
; Seeks the directory sequentially to find a file with a matching label to (HL).
; If one is found, that file is loaded 
; 
; ARG: HL contains pointer to file label to open
; RET: A contains error state if nonzero
;      MFS_ERRCD_OPEN = A file or directory is already open
;      MFS_ERRCD_NOT_FOUND = File was not found by label
; MOD: HL, AF
; ==============================================================================
R_MFS_OPENFILE:
                push DE
                push BC

                ; Check for valid state
                call R_MFS_ISIDLE   ; Only proceed if FS driver is idle    
                jp nz,__openfscan
                ld A,MFS_ERRCD_OPEN
                jp __openfdone      ; Exit

__openfscan:    ; Open the directory and see if we can find this file
                call R_MFS_OPENDIR  ; Open directory
__openfscanlp:  jp z,__openfnf      ; End of dir
                push HL             ; Back up user label pointer
                call R_MFS_GETDIRLBL ; Read dir label, now (HL)
                pop DE              ; User label at (DE)
                push DE             ; Back up user label again
                call R_STRCMP       ; Compare (DE), (HL)
                pop HL              ; Restore user label at (HL)
                jp z,__openffound   ; We found a file!
                call R_MFS_DIRNEXT  ; Seek next dir
                jp __openfscanlp    ; Loop and look at this dir entry
                
__openffound:   ; File is found, take note of it in variables
                ld HL,_MFS_BLOCK
                ld DE,_MFS_FDIRBLK
                ld BC,0x0008        ; Copy 8 bytes from current blk to fdir blk
                ldir                ; Load, increment, repeat
                ld A,(_MFS_DIRINDEX)
                ld (_MFS_FDIRINDEX),A ; Copy dir index to file dir index
                
                ; Get directory file head
                call _R_MFS_SETDIROFFSET
                call R_MFS_CLOSEDIR ; Close directory walk
                ld A,(_MFS_OFFSET)  ; Seek address to offset for file head    
                add A,_MFS_OFFSET_DIRFILEBLK
                ld (_MFS_OFFSET),A
                ld BC,(_MFS_IOCMD)
                ld A,_CMD_SETADDR
                out (C),A           ; Set address on SD card    
                M_SENDN 8,_MFS_ADDRESS
                ld BC,(_MFS_IODAT)
                M_RECVN 8,_MFS_BLOCK ; Get file block head
                
                ; Mark the truncation as 0 so the READ method knows to load truncation
                ld A,0x00
                ld (_MFS_BLKTRUNC),A
                
                ; Mark open file indicators
                ld A,(_MFS_FLAGS)
                set _MFSFLG_OPEN,A  ; File is open
                res _MFSFLG_IDLE,A  ; Not idle
                ld (_MFS_FLAGS),A
                ld A,0x00           ; Indicate no error
                jp __openfdone      ; Exit
                
__openfnf:      ld A,MFS_ERRCD_NOT_FOUND

__openfdone:    ; Restore registers and exit
                pop BC
                pop DE
                ret


; ==============================================================================
; R_MFS_WRITE: Write to open file
; 
; RET: DE contains the pointer to the new memory space
; MOD: DE, BC
; ==============================================================================
R_MFS_WRITE:
                ret


; ==============================================================================
; _R_MFS_ISBLKNULL: Checks if block address is zero
; 
; RET: F.Z if block is null
; MOD: AF
; ==============================================================================
_R_MFS_ISBLKNULL:
                push BC
                push DE
                push HL
                ld DE,_MFS_BLOCK
                ld HL,_MFS_ZEROLONG
                call R_CMPINT64
                pop HL
                pop DE
                pop BC
                ret


; ==============================================================================
; R_MFS_CLOSEFILE: Close an open file
; 
; ARG: 
; ==============================================================================
R_MFS_CLOSEFILE:
                call R_MFS_ISFILEOPEN
                ret z               ; Abort if file not open
                ld A,(_MFS_FLAGS)
                res _MFSFLG_OPEN,A  ; File is not open
                set _MFSFLG_IDLE,A  ; We are idle
                ld (_MFS_FLAGS),A
                ret


; ==============================================================================
; R_MFS_READ: Read from open file
; 
; ARG: DE contains the maximal number of bytes to read, 0 means 64K
; ARG: HL contains the pointer to copy data to
; RET: HL points to the next unwritten address
; RET: F.Z indicates end of file
; MOD: DE, BC
; ==============================================================================
R_MFS_READ:
                call R_MFS_ISFILEOPEN
                ret z               ; Abort if file not open
                
                ; Is the block null? If so we're at EOF
                call _R_MFS_ISBLKNULL
                ret z               ; Abort if block is null

                ; If first block, need to load truncation but blk already loaded
                ld (_MFS_BLKTRUNC),A
                cp 0x00
                jp z,__fsrdloadtrcp ; Probably our first time reading
                
                ; Is the offset currently equal to the limit?
__fsrdnxtbyte:  ld A,(_MFS_BLKTRUNC)
                ld B,A
                ld A,(_MFS_BLKINDEX)
                cp A,B
                jp nc,__fsrdnxtblk  ; No borrow means index >= truncation
                
                ; Next byte
                ld BC,(_MFS_IODAT)
                in A,(C)            ; Read a byte
                ld (HL),A           ; Store byte
                inc HL              ; HL to next address
__fsrdnz:       ld A,(_MFS_BLKINDEX)
                inc A               ; Increment index
                ld (_MFS_BLKINDEX),A
                dec DE              ; Decrement bytes permitted
                ld A,0x00
                cp A,D              
                jp nz,__fsrdnxtbyte ; Nonzero means more bytes permitted to copy
                cp A,E
                jp nz,__fsrdnxtbyte ; Nonzero means more bytes permitted to copy
                jp __fsrddoneclr    ; No more bytes permitted
                
__fsrdnxtblk:   ; Next block
                push HL             ; Back up HL for bulk I/O
                ld A,_MFS_OFFSET_NXTBLK
                ld (_MFS_OFFSET),A  ; Set offset to next block pointer
                ld BC,(_MFS_IOCMD)
                ld A,_CMD_SETADDR
                out (C),A           ; Set address cmd
                M_SENDN 8,_MFS_ADDRESS
                
                ld BC,(_MFS_IODAT)
                M_RECVN 8,_MFS_BLOCK ; Point to next file block
                call _R_MFS_ISBLKNULL
                jp z,__fsrdnullhlr  ; Abort if block is null
__fsrdloadtrc:  ld A,_MFS_OFFSET_FTRUNC ; Get file truncation
                ld (_MFS_OFFSET),A  ; Store as address offset
                
                ld BC,(_MFS_IOCMD)
                ld A,_CMD_SETADDR
                out (C),A           ; Seek to next block
                M_SENDN 8,_MFS_ADDRESS
                
                ; Read new block truncation
                ld BC,(_MFS_IODAT)
                in A,(C)            ; Read truncation byte
                cp A,0x00           ; If zero, read full block
                jp z,__fsrdfull     ; Default truncation value then store
                jp __fsrdsttrunc    ; Store truncation
__fsrdfull:     ld A,_MFS_TRUNCMAX  ; Default to max truncation
__fsrdsttrunc:  ld (_MFS_BLKTRUNC),A ; Store file truncation
                ld A,0x00
                ld (_MFS_BLKINDEX),A ; Reset block index
                in A,(C)
                in A,(C)
                in A,(C)
                in A,(C)
                in A,(C)
                in A,(C)
                in A,(C)
                in A,(C)
                in A,(C)            ; Blowing through 9 unnecessary bytes
                pop HL              ; Restore HL address
                jp __fsrdnxtbyte    ; Read next byte
                
__fsrddoneclr:  ; Done reading bytes
                ld C,0xFF
                ld A,0x00
                cp A,C              ; Clear zero bit
                ret

__fsrdloadtrcp: push HL             ; Back up HL pointer
                jp __fsrdloadtrc    ; Parse first block
                
__fsrdnullhlr:  pop HL              ; Abort z condition after restoring HL
                ret

; ==============================================================================
; R_MFS_SEEK: Seek in open file
; 
; RET: DE contains the pointer to the new memory space
; MOD: DE, BC
; ==============================================================================
R_MFS_SEEK:
                ret


; ==============================================================================
; R_MFS_RSEEK: Relative seek in open file
; 
; RET: DE contains the pointer to the new memory space
; MOD: DE, BC
; ==============================================================================
R_MFS_RSEEK:
                ret


; ==============================================================================
; R_MFS_CLOSEDIR: Stop directory walk
; 
; MOD: AF
; ==============================================================================
R_MFS_CLOSEDIR:  ; Ensure we're in a good state
                call R_MFS_ISDIROPEN
                ret z
                
                ; Set the flags to indicate dir is open
                ld A,(_MFS_FLAGS)
                res _MFSFLG_DIR,A   ; Indicate we are NOT reading dir
                set _MFSFLG_IDLE,A  ; Indicate we are idling
                ld (_MFS_FLAGS),A
                ret
                

; ==============================================================================
; R_MFS_OPENDIR: Initiate directory walk
; 
; See R_MFS_DIRNEXT for input/output
; ==============================================================================
R_MFS_OPENDIR:  push HL
                push DE
                push BC
                
                ; Ensure we're in a good state
                call R_MFS_ISIDLE
                jp z,__fsodr_fail   ; Abort if not idle
                
                ; Set the flags to indicate dir is open
                ld A,(_MFS_FLAGS)   
                set _MFSFLG_DIR,A   ; Indicate we are reading dir
                res _MFSFLG_IDLE,A  ; Indicate we are NOT idling
                ld (_MFS_FLAGS),A
                
                ; Load the head block and point to dir head pointer
                ld BC,_MFS_BLOCK
                call R_ZINT64       ; Go to head block
                ld A,_MFS_OFFSET_FSDIRBLK
                ld (_MFS_OFFSET),A  ; Point address at dir head ptr
                ld BC,(_MFS_IOCMD)
                ld A,_CMD_SETADDR
                out (C),A           ; Set address
                M_SENDN 8,_MFS_ADDRESS
                
                ; MFS DIRNEXT will handle retrieving and validating the ptr
                jp __fsdldptr       ; Hand control to R_MFS_DIRNEXT

__fsodr_fail:   pop BC
                pop DE
                pop HL
                ret


; ==============================================================================
; R_MFS_DIRNEXT: Next directory entry
; 
; RET: DE contains the pointer to the new memory space
; RET: F.Z indicates end of directory
; MOD: AF
; ==============================================================================
R_MFS_DIRNEXT:  push HL
                push DE
                push BC
                
                ; Ensure dir is open
                call R_MFS_ISDIROPEN
                jp z,__fsndr_done   ; Abort if not dir open
                
                ; Shortcut 0xFF index means no more blocks
                ld A,(_MFS_DIRINDEX)
                cp A,0xFF
                jp z,__fsndr_done
                
                ; get dir index and add 1
                jp __fsdninc
                
__fsdnilp:      ; Looping through available indexes checking for a valid one

                ; Once index reaches 3 we need to fetch next block
                ld A,(_MFS_DIRINDEX)
                cp A,0x03           ; Only 3 dir indexes per block
                jp z,__fsdfnb       ; Exhausted this block, load next
                
                ; Load up the appropriate directory offset
                cp A,0x02
                jp z,__fsdnoff2
                cp A,0x01
                jp z,__fsdnoff1
__fsdnoff0:     ld A,_MFS_OFFSET_DIR0
                jp __fsdncnt
__fsdnoff1:     ld A,_MFS_OFFSET_DIR1
                jp __fsdncnt
__fsdnoff2:     ld A,_MFS_OFFSET_DIR2
                
                ; Block offset starts with the dir label, to which we seek
__fsdncnt:      ld (_MFS_OFFSET),A      ; Set the offset address
                ld BC,(_MFS_IOCMD)      ; Send commands to SD
                ld A,_CMD_SETADDR
                out (C),A               ; Set address cmd
                M_SENDN 8,_MFS_ADDRESS  ; Set address
                
                ; A zero first label byte indicates an empty entry
                ld BC,(_MFS_IODAT)
                in A,(C)                ; Get first label byte
                jp z,__fsdninc          ; Was blank, increment and find next!
                
                ; Was not blank, return with this entry and block!
                jp __fsndr_done

__fsdninc:      ; Else, add 1 to index, repeat index loop
                ld A,(_MFS_DIRINDEX)
                add A,0x01
                ld (_MFS_DIRINDEX),A
                jp __fsdnilp

__fsdfnb:       ; Fetch next dir block
                ld A,_MFS_OFFSET_NXTBLK
                ld (_MFS_OFFSET),A  ; Point address at next dir ptr
                ld BC,(_MFS_IOCMD)
                ld A,_CMD_SETADDR
                out (C),A           ; Set address
                M_SENDN 8,_MFS_ADDRESS
                
__fsdldptr:     ; Read in the pointer to this dir block
                ld BC,(_MFS_IODAT)
                M_RECVN 8,_MFS_BLOCK ; Receive new block ptr
                ld A,0x00
                ld (_MFS_DIRINDEX),A ; Zero the index

                ; If next dir block is null, we're done, return
                ld DE,_MFS_BLOCK
                ld HL,_MFS_ZEROLONG
                call R_CMPINT64         ; Compare block to zero
                jp nz,__fsdnilp         ; If non-zero check out the first index
                ld A,0xFF
                ld (_MFS_DIRINDEX),A    ; 0xFF dir index quickly marks end-of-dir
                
__fsndr_done:   pop BC
                pop DE
                pop HL
                ret


; ==============================================================================
; R_MFS_GETDIRLBL: Get current directory label
;
; Only works if the directory is open and pointing at a valid entry. This state
; is achieved after calling R_MFS_OPENDIR or R_MFS_DIRNEXT and receiving a 
; non-zero flag. 
; 
; RET: HL contains a temporary pointer to a null term string
; MOD: HL
; ==============================================================================
R_MFS_GETDIRLBL:
                push BC
                push AF
                ld HL,_MFS_BFFRLBL
                ld (HL),0x00        ; Blank the buffer
                
                ; Ensure we're in a good state
                call R_MFS_ISDIROPEN
                jp z,__fsdirlbl_done   ; Abort if not open
                
                ; Go to correct offset
                call _R_MFS_SETDIROFFSET
                ld BC,(_MFS_IOCMD)
                ld A,_CMD_SETADDR
                out (C),A
                M_SENDN 8,_MFS_ADDRESS
                
                ; Get label
                ld BC,(_MFS_IODAT)
                M_RECVN _MFS_LABELMAX,_MFS_BFFRLBL
                ld (HL),0x00        ; Null term it
                
__fsdirlbl_done:
                ld HL,_MFS_BFFRLBL
                pop AF
                pop BC
                ret


; ==============================================================================
; _R_MFS_SETDIROFFSET: Sets the address offset based on the directory index
;
; Only works if the directory is open and pointing at a valid entry.
; 
; MOD: AF
; ==============================================================================
_R_MFS_SETDIROFFSET:
                ld A,(_MFS_DIRINDEX)
                cp A,0x02
                jp z,__fsdgloff2
                cp A,0x01
                jp z,__fsdgloff1
__fsdgloff0:    ld A,_MFS_OFFSET_DIR0
                jp __fsdglcnt
__fsdgloff1:    ld A,_MFS_OFFSET_DIR1
                jp __fsdglcnt
__fsdgloff2:    ld A,_MFS_OFFSET_DIR2
__fsdglcnt:     ld (_MFS_OFFSET),A
                ret


_mfs_st_header: db  "MAJELFS",0     ; Majel FS header comparison string




















