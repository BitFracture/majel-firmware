;
; MAJEL-1 STACK LIB V1
; 
; This library consists of stack allocation and deallocation utilities. 
; Note: Using the stack is incredibly inefficient on a Z80 and it should only
; be used where portability is significantly more important than speed.
;
; Author: Erik W. Greif
; Date: 2021-07-28
;


; ==============================================================================
; R_MALLOC_STACK: Allocated N bytes on the stack
;
; Allocates N bytes on the stack, adjusting the stack pointer and returning the
; memory location in HL.
;
; ARG: A provides number of bytes to allocate where 0 means 256
; RET: HL stores lowest address of allocated memory
; MOD: AF, HL, SP
; ==============================================================================
R_MALLOC_STACK:
                pop HL              ; Back up return address
__mlcnext:      dec SP              ; Decrement SP N times
                dec A
                jp nz,__mlcnext
                
                ; Make SP accessible
                push HL             ; Restore return address
                ld HL,0x0002        ; 2 bytes for return address offset
                add HL,SP           ; Move SP to HL
                ret


; ==============================================================================
; R_FREE_STACK: Deallocates N bytes on the stack
;
; Frees N bytes from the stack.
;
; ARG: A provides number of bytes to deallocate where 0 means 256
; MOD: AF, HL, SP
; ==============================================================================
R_FREE_STACK:
                pop HL              ; Back up return address
__mfrnext:      inc SP              ; Increment SP N times
                dec A
                jp nz,__mfrnext
                push HL             ; Restore return address
                ret

