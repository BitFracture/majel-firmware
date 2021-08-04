;
; MAJEL-1 FIRMWARE 32KB V1
; 
; This firmware exposes a serial-interactive bootloader that can do several 
; functions including:
;  1. Start running at a given address in memory
;  2. Read the contents of an SD card program into memory and start it
;  3. Clone the firmware ROM to RAM
; 
; When this firmware program is in use, it reserves the upper 1K of RAM 
; (0xFC00 to 0xFFFF), which includes the stack. Modifying this region may result 
; in unpredictable behavior from this firmware program. Relocating the stack is
; acceptable if the new location does not reside in this memory range.
;
; Note for loading programs: the firmware will automatically stop loading any
; program when its address meets the stack pointer. Programs that require use
; of this reserved portion of memory will have to load it after being invoked.
;
; Author: Erik W. Greif
; Date: 2021-05-11
;

                include "majel_io_v1.h"
SER_MAX_ADDR:   equ 0x10000         ; Serial cache at top of memory
                
                include "majel_serial_v1.h"
                
MFS_MAX_ADDR:   equ SER_CACHE_LOC   ; Majel FS sits below serial

                include "majel_fs_v1.h"
                
IOTBL_MAX_ADDR: equ MFS_CACHE_LOC   ; Place the IO table below MFS but above the stack
                
                include "majel_ioseek_v1.h"

STACK_START:    equ IOTBL_LOC       ; Start stack right under the IO table
                
OPT_GOTO:       equ 0x31            ; "1"
OPT_FILE:       equ 0x32            ; "2"
OPT_MEMT:       equ 0x33            ; "3"
OPT_COPY:       equ 0x34            ; "4"
OPT_ECHO:       equ 0x35            ; "5"
OPT_INTR:       equ 0x36            ; "6"


                org 0x0000          ; Starting location
start:          di                  ; Disable interrupts
                ld sp,STACK_START   ; Init stack for 64KB RAM
                call R_SER_INIT     ; Locate the serial port
                jp nz,__serialfound ; Serial was found
                halt                ; Serial was NOT found!
                
__serialfound:  ld de,st_wel        ; Load the string pointer
                call R_SER_PRINT    ; Print welcome message
                
                ld de,st_optmain    ; Load the string pointer
                call R_SER_PRINT    ; Print options message
                
__choices:      call R_SER_WAIT     ; Wait for a char
                call R_SER_RECVBYTE ; Receive char
                call R_SER_SENDBYTE ; Echo char
                
                cp OPT_GOTO
                jp z,__invalid      ; Todo: Jump to upper RAM bank
                
                cp OPT_INTR
                jp z,R_ECHO_INT     ; Echo back in interrupt fashion
                
                cp OPT_FILE
                jp z,R_LOAD_SD      ; Load a file
                
                cp OPT_COPY
                jp z,R_CPY_TO_RAM   ; Copy firmware to RAM
                
                cp OPT_MEMT
                jp z,R_MEMTEST      ; Todo: Will be a memory test
                
                cp OPT_ECHO
                jp z,R_ECHO         ; Echo back in blocking fashion
                
__invalid:      ld de,st_eraseone   ; Erase one char
                call R_SER_PRINT
                jp __choices        ; Wait at prompt


; ==============================================================================
; Main routine: Load a file from SD card
; ==============================================================================
R_LOAD_SD:      
                ld DE,st_mfs_setup
                call R_SER_PRINT    ; Alert the user we're initializing MFS
                call R_MFS_SETUP    ; Initialize the MFS memory space
                
                ld DE,st_mfs_scan
                call R_SER_PRINT    ; Alert the user we're scanning for cards
                call R_MFS_CONNECT  ; Connect to an FS and report back state
                
                ; Handle A response codes
                cp A,0x00
                jp z,__rsd_success
                cp A,MFS_ERRCD_IO_NOT_FOUND
                jp z,__rsd_fail_io
                cp A,MFS_ERRCD_NO_CARD
                jp z,__rsd_fail_cd
                cp A,MFS_ERRCD_NO_FORMAT
                jp z,__rsd_fail_fs
                cp A,MFS_ERRCD_BAD_VERSION
                jp z,__rsd_fail_fv
                cp A,MFS_ERRCD_CONNECTED
                jp z,__rsd_fail_cn
                jp __rsd_fail_oth
                
                ; Successful open, print out volume header
__rsd_success:  ld DE,st_mfs_vollbl
                call R_SER_PRINT
                call R_MFS_GETLBL   ; Get vol label
                ld DE,HL
                call R_SER_PRINT    ; Print vol label (DE)
                ld DE,st_mfs_dirhead
                call R_SER_PRINT
                
                ; Print out directory entries
                call R_MFS_OPENDIR  ; Opens the directory
                jp z,__rsd_prompt    ; If empty dir, skip over
__rsd_pdirnxt:  ld DE,st_mfs_fnamest
                call R_SER_PRINT    ; Prefix formatting
                call R_MFS_GETDIRLBL
                ld DE,HL
                call R_SER_PRINT    ; Dir label    
                ld DE,st_mfs_fnamend
                call R_SER_PRINT    ; Suffix formatting
                call R_MFS_DIRNEXT  ; Seek to next dir entry
                jp nz,__rsd_pdirnxt ; If not eod, print next
                
                ; Get user to enter file name
__rsd_prompt:   call R_MFS_CLOSEDIR ; Close directory walk
                call R_SER_CLEAR    ; Clear serial buffer
                ld DE,st_promptstr
                call R_SER_PRINT    ; Prompt for input
                ld A,0x20           ; Allocate 32 byte stack buffer
                call R_MALLOC_STACK ; Leaves HL pointing to new 32-byte memory
                ld E,0x1F           ; Allow 31 characters to be typed
                call R_SER_RECVLINE_ECHO ; Receive string input visible to terminal
                
                ; Ask MFS to open the file entered
                call R_MFS_OPENFILE ; Open a file with name (HL)
                ld B,A
                
                ld A,0x20           ; Deallocate stack buffer
                call R_FREE_STACK
                
                ld A,B              ; Restore file open response
                cp 0x00
                jp z,__rsd_found    ; File found!
                cp A,MFS_ERRCD_NOT_FOUND
                jp z, __rsd_fail_nf ; File not found!
                jp __rsd_fail_oth   ; Other error
                
__rsd_found:    ; The file is found and open, time to load it!
                ld DE,st_file_load
                call R_SER_PRINT
                
                ; Sort out how many bytes we can load
                ld HL,0xFFEF        ; -16
                add HL,SP           ; HL = SP - 16, sparing us some stack space
                ld BC,HL            ; BC holds the max bytes we can safely load
                ld HL,0x0000        ; Org to 0
                
                ; Calculate block size for next load
__rsd_nxtblk:   ld D,B
                ld E,C              ; DE holds max bytes
                ex DE,HL            ; DE holds bytes loaded, HL holds max bytes
                cp A,A              ; Clear cary
                sbc HL,DE           ; HL is bytes permitted remaining
                ex DE,HL            ; HL holds bytes loaded, DE holds bytes permitted remaining
                push BC             ; Back up max bytes to load
                ld A,D
                cp A,0x04           ; Compare D to 4
                jp nc,__rsd_fullblk ; No borrow means D >= 4, meaning DE is >= 1024 bytes remaining
                
                ; Preparing to read a partial block, ensure it isn't zero
                ld A,0x00
                cp A,D
                jp nz,__rsd_rdblk   ; Read next block!
                cp A,E
                jp nz,__rsd_rdblk   ; Read next block!
                jp __rsd_trunc      ; No more RAM left :(
                
__rsd_fullblk:  ; Prepare to read a full 1024B block
                ld D,0x04
                ld E,0x00           ; DE is 1024, HL point to next addr to write

__rsd_rdblk:    ; Read the full or partial block
                call R_MFS_READ     ; Read file (dirties BC)
                ld A,0x2D           ; Hypthen character
                call R_SER_SENDBYTE ; Send a hypthen (dirties BC)
                pop BC              ; Restore max bytes to load
                jp z,__rsd_eof
                jp __rsd_nxtblk
                

__rsd_trunc:    ld DE,st_filetrunc
                call R_SER_PRINT    ; Print saying file was cut short
                jp __rsd_closef

__rsd_eof:      ld DE,st_filedone
                call R_SER_PRINT    ; Print saying file is loaded in full

__rsd_closef:   call R_MFS_CLOSEFILE
                jp R_PROGRAM_LAUNCHER ; Wait in RAM so ROM can be disabled
                
                ; Error handle jump table
__rsd_fail_io:  ld DE,st_mfs_ernohw
                call R_SER_PRINT
                jp __rsd_exit
__rsd_fail_cd:  ld DE,st_mfs_ernocd
                call R_SER_PRINT
                jp __rsd_exit
__rsd_fail_fs:  ld DE,st_mfs_ernofs
                call R_SER_PRINT
                jp __rsd_exit
__rsd_fail_fv:  ld DE,st_mfs_erbver
                call R_SER_PRINT
                jp __rsd_exit
__rsd_fail_cn:  ld DE,st_mfs_erconn
                call R_SER_PRINT
                jp __rsd_exit
__rsd_fail_nf:  ld DE,st_mfs_ernf
                call R_SER_PRINT
                jp __rsd_exit
__rsd_fail_oth: ld DE,st_mfs_eroth
                call R_SER_PRINT

__rsd_exit:     jp start            ; Abort and restart firmware


; ==============================================================================
; Main routine: create a blocking, synchronous serial echo
; ==============================================================================
R_ECHO:
                ld DE,st_kbwel      ; Load the string pointer
                call R_SER_PRINT    ; Print (DE)
                
__ech_waitblk:  call R_SER_WAIT     ; Block wait for input
                ld D,A              ; Number bytes available
                
__ech_outloop:  call R_SER_RECVBYTE ; Get a byte
                call R_SER_SENDBYTE ; Echo the byte
                dec D
                jp nz,__ech_outloop ; More bytes left!
                jp __ech_waitblk    ; Block on more bytes


; ==============================================================================
; Main routine: create a non-blocking interrupt serial echo
; ==============================================================================
R_ECHO_INT:
                ld A,hi(INT_VECTORS)
                ld I,A              ; Set up interrupt vector table
                ld DE,st_kbwel      ; Load the string pointer
                call R_SER_PRINT    ; Print (DE)
                ld A,lo(INTV_SERECHO) ; Serial echo jump vector
                ld D,A
                call R_SER_SETINTV  ; Set serial interrupt vector
                im 2                ; Interrupt vectoring mode
                ei                  ; Interrupts enabled!
__echasynchalt: halt                ; Interrupts will resume operation
                jp __echasynchalt

                ; Normally we would back up registers, but CPU is halted
IR_SERIAL_ECHO: 
                call R_SER_COUNT    ; Count number of bytes available
                ld D,A              ; Number bytes available
                ld A,0x00
                cp D                ; D==0?
                jp z,__echas_done   ; Return if no bytes
__echas_outlp:  call R_SER_RECVBYTE ; Get a byte
                call R_SER_SENDBYTE ; Echo the byte
                dec D
                jp nz,__echas_outlp ; More bytes left?
__echas_done:   ei                  ; Re-enable interrupts
                reti                ; Get us outta hereeree


; ==============================================================================
; Main routine: clone to RAM
; ==============================================================================
__ramdetect:    equ 0xAA
__romdetect:    equ 0x55
__detect:       db __romdetect      ; We're in ROM
R_CPY_TO_RAM:
                ld DE,st_cpwel      ; Load the string pointer
                call R_SER_PRINT    ; Print
                
                ld HL,0x0000
                ld DE,0x0000
                ld BC,end_of_file   ; End of file marker address is the length of data to copy
                call R_MEMCPY       ; Copy using the RAM write masking hardware
                
                ld A,__ramdetect
                ld (__detect),A     ; Overwrite the detect variable
                
                ld DE,st_cpdone     ; Load the string pointer
                call R_SER_PRINT    ; Print
                
__cp_waitlp     call R_SER_WAIT     ; Wait for serial char
                call R_SER_RECVBYTE ; Read one character
                ld A,(__detect)
                cp __ramdetect
                jp z,__cp_success
                
                ld DE,st_cpwait     ; Load the string pointer
                call R_SER_PRINT    ; Print
                jp __cp_waitlp
                
__cp_success:   jp start            ; Reinitialize from RAM clone


; ==============================================================================
; Main routine: Memory tester
; ==============================================================================
R_MEMTEST:
                ld de,st_mtwel      ; Load the string pointer
                call R_SER_PRINT    ; Print prompt
                
__mt_read:      call R_SER_WAIT     ; Wait for a char
                call R_SER_RECVBYTE ; Read character
                
                cp 0x79             ; Capital and lower Y
                jp z,__mt_begin
                cp 0x59
                jp z,__mt_begin
                cp 0x4E             ; Capital and lower N
                jp z,__mt_abort
                cp 0x6E
                jp z,__mt_abort
                jp __mt_read
                
__mt_abort:     call R_SER_SENDBYTE ; Echo A back out
                ld de,st_mtaborted  ; Load the string pointer
                call R_SER_PRINT    ; Print
                jp start
                
__mt_begin:     out (C),A           ; Echo character
                ld DE,st_mtsuccess  ; Load the string pointer
                call R_SER_PRINT        ; Print
                jp start            ; Reinitialize


; ==============================================================================
; R_MEMCPY: Memory copy
;
; Copy a block of memory to another
;
; Will copy (HL) to (DE) incrementing both pointers and decrementing BC until 
; BC is zero.
;
; ARG: HL the source address
; ARG: DE the dest address
; ARG: BC the number of bytes to copy
; ==============================================================================
R_MEMCPY:
                ldir                ; Complex instruction set serves us well
                ret


; ==============================================================================
; String table
; ==============================================================================
                
st_wel:         db 10,"MAJEL-1 BOOTLOADER v0.1.0",10,"Built July 27th, 2021",10,"Created May 11th, 2021",10,0

st_optmain:     db 10,"Choose a boot option",10
                db 10,"1) Execute upper RAM bank at 0x8000",10
                db "2) Choose a program from a storage device",10
                db "3) Run a memory test",10
                db "4) Copy this firmware to RAM",10
                db "5) Synchronous keyboard echo demo",10
                db "6) Asynchronous keyboard echo demo",10,10
                db "#> ",0

st_kbwel:       db 10,10,"Keyboard Echo Demo",10,"Everything you type will echo back to you.",10,10,0

st_cpwel:       db 10,10,"This firmware is being copied to RAM...",0

st_cpdone:      db " DONE",10,"Switch the memory mode to RAM and press any key",10,0

st_cpwait:      db "The memory mode switch still appears to select ROM",10,0

st_willhalt:    db 10,"The system will now halt",10,0

st_mtwel:       db 10,10,"The contents of RAM will be permanently overwritten by this test. "
                db "Proceed?",10,"Y/N> ",0
                
st_mtaborted:   db 10,10,"Memory test aborted",10,0
                
st_mtsuccess:   db 10,10,"Memory test complete",10,0

st_mfs_setup:   db "Initializing Majel-FS driver...",10,0

st_mfs_scan:    db "Attempting to open file system...",10,0

st_mfs_ernohw:  db "SD card reader HWID 0x0002 is not found! Aborting.",10,0

st_mfs_ernocd:  db "SD card is not inserted! Aborting.",10,0

st_mfs_ernofs:  db "SD card is not formatted with Majel-FS! Aborting.",10,0

st_mfs_erbver:  db "The version of Majel-FS on this card is unsupported! Aborting.",10,0

st_mfs_erconn:  db "The SD card driver is already in use! Aborting.",10,0

st_mfs_ernf:    db "That file was not found! Aborting.",10,0

st_mfs_eroth:   db "An unrecognized error occurred! Aborting.",10,0

st_file_load:   db "Your program is being loaded, please wait...",10,0

st_filetrunc:   db 10,"Your program was too long but was partially loaded",10,0

st_filedone:    db 10,"Your program is loaded",10,0

st_filedonepk:  db "Change the RAM/ROM switch to RAM, then press any key to start",10,0

st_mfs_dirhead: db 34,10,"File list: ",10,0

st_mfs_vollbl:  db 10,"Volume label: ",34,0

st_promptstr:   db 10," > ",0

st_mfs_fnamest: db "  ",34,0

st_mfs_fnamend: db 34,10,0

st_mfs_choose:  db 10,"Choose a program file by name: ",10,0

st_eraseone:    db 0x08,0x20,0x08,0

; ==============================================================================
; Library implementations
; ==============================================================================

                include "majel_math_v1.asm"
                include "majel_strings_v1.asm"
                include "majel_stack_v1.asm"
                include "majel_ioseek_v1.asm"
                include "majel_serial_v1.asm"
                include "majel_fs_v1.asm"


; ==============================================================================
; Interrupt vector table
; ==============================================================================
__temp_ivt_marker: db 0x00              ; Used to bump intv table
                org (hi(__temp_ivt_marker) + 1) << 8 ; Calc next full block!
INT_VECTORS:    
                ; Serial echo interrupt vector
INTV_SERECHO:   dw IR_SERIAL_ECHO


; ==============================================================================
; Bootstrap the custom program launcher
; ==============================================================================
R_PROGRAM_LAUNCHER:
                ld HL,org_pgm_launch    ; Program launcher in ROM
                ld BC,launcher_len      ; Size of launcher routine
                ld DE,launcher_start    ; Program launcher in RAM
                ldir                    ; Copy program launcher to RAM
                call R_SER_LOADCMD      ; Preload the serial card address
                push BC
                ld DE,st_filedonepk
                call R_SER_PRINT        ; Let user know to toggle and press key
                pop BC
                ld A,_SER_CMD_AVAIL
                out (C),A               ; Query for available byte count
                jp launcher_start       ; Go to launcher in RAM
                


; ==============================================================================
; Custom program launcher that runs in the stack
; This program orgs to overwrite MajelFS program memory. At the point where 
; this routine is used, MFS is not used anymore and can be corrupted safely. 
; Since this routine is moved to RAM, the ROM switch can safely be changed
; while in this routine.
; ==============================================================================
end_of_firm:    db 0x00
org_pgm_launch: equ end_of_firm+1
                
                ; Org to MFS memory space above stack, rorg below existing code
                org MFS_CACHE_LOC,org_pgm_launch
                
launcher_start: ; Actual routine is here
                in A,(C)                ; Get available bytes
                jp z,launcher_start     ; No key presses, re-check
                jp 0x0000               ; Go to loaded program now
                
launcher_end:   
launcher_len:   equ launcher_end-launcher_start  ; Size of launcher

; ==============================================================================
; End of firmware marker used for firmware copy
; ==============================================================================

end_of_file:    equ end_of_firm+launcher_len

