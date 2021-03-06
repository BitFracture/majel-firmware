;
; MAJEL-1 SERIAL LIB V1
; 
; This library provides tools for serial input and output.
;
; Author: Erik W. Greif
; Date: 2021-07-27
;


; ==============================================================================
; R_SER_INIT: Initializes the serial variables
; This routine will HALT the system if serial cannot be initialized.
;
; RET: F.Z indicates failure to find the serial card
; MOD: AF, BC, DE, AF
; ==============================================================================
R_SER_INIT:     
                call R_IO_SCANALL   ; Scan for all hardware device IDs
                ld DE,0x0001        ; Serial card device ID
                call R_IO_FIND      ; Find the serial card!
                jp nz,__insr_fin    ; Serial was found!
                ret                 ; z is set, failed to find
__insr_fin:     ld C,B              ; Put data channel in C
                inc B               ; Put command channel in B
                ld (_SER_IODAT),BC  ; Store in RAM for other methods to use
                call R_SER_CLRINTV  ; Clear any interrupt vectors
                ld A,0x00
                inc A               ; Clear zero
                ret                 ; z is unset, successful find


; ==============================================================================
; R_SER_PRINT: Print string
;
; Print a null-terminated string to serial port
;
; ARG: DE stores string start address
; ==============================================================================
R_SER_PRINT:        
                push HL             ; Back up HL
                push AF             ; Back up index and accum
                ld BC,(_SER_IODAT)
                ld hl,$00
                
__rp_ldchar:    ld A,(DE)           ; Load character
                inc DE              ; Next pointer
                cp $00              ; Is character in 'a' null?
                jp z,__rp_done      ; If so, routine done
                out (C),A           ; Send character
                jp __rp_ldchar      ; Loop to send next char
                
__rp_done:      pop AF
                pop HL
                ret
                
; ==============================================================================
; R_SER_RECVLINE_ECHO: Receive a textual string LF terminated
;
; Receives written character bytes space/0x20 through tilde/0x7E from serial 
; until a LF/0x0A character is encountered. Bytes are placed in the specified 
; buffer until it is full, then bytes are simply discarded. Receipt of a 
; backspace/0x08 or a delete/0x7F result in the buffer removing the latest 
; character and the backspace/0x08 character being echoed to the terminal.
;
; Upon receipt of the line terminator LF, the buffer is terminated and does not
; include the LF character, but it is echoed back to the terminal.
;
; ARG: HL pointer to buffer
; ARG: E max string length 0-255, one less than total buffer size (null term)
; RET: (HL) points to input string as shown on terminal
; MOD: HL, DE
; ==============================================================================
R_SER_RECVLINE_ECHO:
                push BC
                push AF
                push DE
                push HL
                ld D,0              ; Length tracker starts at 0

                ; Waiting and getting a character
__rcvwait:      call R_SER_WAIT     ; Wait for characters
                ld BC,(_SER_IODAT)  ; Set up IO for serial data
                ld B,A              ; Store char count in B
__rcvnext:      in A,(C)            ; Read a character A
                
                ; If A is newline, submit and return
                cp A,_SER_CH_LF
                jp nz,__rcvlnc1     ; If not an LF, do next check
                out (C),A           ; Echo the newline
                ld (HL),0x00        ; Terminate buffer
                pop HL
                pop DE
                pop AF
                pop BC
                ret
                
__rcvlnc1:      ; If A is backspace or del, remove a char if we can
                cp A,_SER_CH_BCK
                jp z,__rcvbck       ; Is backspace
                cp A,_SER_CH_DEL
                jp nz,__rcvlnc2     ; Is not a delete
__rcvbck:       dec D
                inc D
                jp z,__rcvhasmore   ; No chars exist to backspace
                ld A,_SER_CH_BCK
                out (C),A           ; Echo backspace character
                dec HL              ; Back up our buffer pointer
                inc E               ; Add back a char we can type
                dec D               ; Remove a char we can backspace
                jp __rcvhasmore

__rcvlnc2:      ; If E is zero, our buffer is full and we ignore this char
                dec E
                inc E
                jp nz,__rcvlnc3     ; Buffer not full
                jp __rcvhasmore     ; Buffer full, ignore and goto next
                
__rcvlnc3:      ; Is the character a visible character?
                cp A,_SER_CH_LOWEST
                jp c,__rcvhasmore   ; Character is lower than lowest, ignore it
                cp A,_SER_CH_HIGHEST
                jp z,__rcvinrange   ; Character is highest, proceed
                jp c,__rcvinrange   ; Character is less than highest, proceed
                jp __rcvhasmore     ; Character is higher than highest, ignore it
                
__rcvinrange:   ; This is a visible character and we have room for it
                ld (HL),A           ; Write the character to buffer
                inc HL              ; Next buffer pointer
                dec E               ; Remove from chars we can type
                inc D               ; Add to chars we can backspace
                out (C),A           ; Echo character to terminal
                
__rcvhasmore:   ; Are there any more characters waiting?
                dec B               ; One char consumed
                jp z,__rcvwait      ; No more chars, block wait again    
                jp __rcvnext        ; More chars exist, process the next one!

; ==============================================================================
; R_SER_RECVBYTE: Receive one byte
;
; Consumes one byte from serial, returns garbage if nothing available
;
; RET: A input byte
; MOD: BC, AF
; ==============================================================================
R_SER_RECVBYTE:
                ld BC,(_SER_IODAT)  ; Read/write serial port
                in A,(C)
                ret


; ==============================================================================
; R_SER_SENDBYTE: Receive one byte
;
; Consumes one byte from serial, returns garbage if nothing available
;
; ARG: A output byte
; MOD: BC
; ==============================================================================
R_SER_SENDBYTE:
                ld BC,(_SER_IODAT)  ; Read/write serial port
                out (C),A           ; Echo character
                ret


; ==============================================================================
; R_SER_LOADCMD: Load command port C
;
; Leaves C pointing to the serial command port and returns.
;
; MOD: BC
; ==============================================================================
R_SER_LOADCMD:
                ld BC,(_SER_IOCMD)  ; Read/write serial commands
                ret


; ==============================================================================
; R_SER_WAIT: Wait for serial
;
; Will block waiting until serial data is available to read
;
; RET: A number of bytes available
; MOD: AF, BC
; ==============================================================================
R_SER_WAIT:
                ld A,_SER_CMD_AVAIL
                ld BC,(_SER_IOCMD)
                out (C),A           ; Ask for num serial bytes
__blk_waitlp:   in A,(C)            ; Number of bytes available
                cp $00              ; Any bytes yet?
                jp z,__blk_waitlp   ; Nope, check again
                ret                 ; Bytes are available!


; ==============================================================================
; R_SER_COUNT: Count number of inbound bytes waiting
;
; Will return immediately with number of bytes available, non-blocking
;
; RET: A number of bytes available
; MOD: AF, BC
; ==============================================================================
R_SER_COUNT:
                ld A,_SER_CMD_AVAIL
                ld BC,(_SER_IOCMD)
                out (C),A           ; Ask for num serial bytes
                in A,(C)            ; Number of bytes available
                ret


; ==============================================================================
; R_SER_SETINTV: Set serial interrupt vector
;
; Enables serial interrupt triggering and sets an interrupt vector
;
; ARG: D the vector to use
; MOD: AF, BC
; ==============================================================================
R_SER_SETINTV:
                ld A,_SER_CMD_SETINT
                ld BC,(_SER_IOCMD)
                out (C),A           ; Cmd set interrupt vector
                out (C),D           ; The interrupt vector
                ret


; ==============================================================================
; R_SER_CLRINTV: Clear serial interrupt vector
;
; Disables serial interrupt triggering
;
; MOD: AF, BC
; ==============================================================================
R_SER_CLRINTV:
                ld A,_SER_CMD_CLRINT
                ld BC,(_SER_IOCMD)
                out (C),A           ; Cmd clr interrupt vector
                ret



; ==============================================================================
; R_SER_CLEAR: Clear serial input buffer
;
; Will read and discard serial data until none is left
; ==============================================================================
R_SER_CLEAR:
                push AF
                push BC
                
__clrnxt:       ld A,_SER_CMD_AVAIL
                ld BC,(_SER_IOCMD)
                out (C),A           ; Ask for num serial bytes
                in A,(C)            ; Number of bytes available
                jp z,__blk_clrend   ; Done!
                ld BC,(_SER_IODAT)
                LD B,A              ; Put count in B
                
__clrconsume:   in A,(C)            ; Read byte
                dec B               ; Dec bytes avail
                jp nz,__clrconsume  ; Eat next byte
                jp __clrnxt         ; Check buffer size again
                
__blk_clrend:   pop BC
                pop AF
                ret











