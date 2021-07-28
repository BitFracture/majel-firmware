;
; MAJEL-1 STRINGS LIB V1
; 
; This library consists of string manipulation capabilities, including but not limited to concatenation and number 
; conversion. 
;
; Author: Erik W. Greif
; Date: 2021-06-15
;


; ==============================================================================
; R_STRCPY: String copy
; 
; Copy a string from one location to another, limit between 0 and 65,535
; characters. Dest max length does not include terminator.
; 
; ARG: HL stores source string address
; ARG: DE stores dest string addr
; ARG: BC stores dest str max length
; MOD: AF
; ==============================================================================
R_STRCPY:       ; Check if this copy has exceeded max length
                ld A,$00            ; 
                cp B                ; b==0
                jp nz,__cp_load     ; if (b != 0) goto __cp_load
                cp C                ; c==0
                jp z,__cp_done      ; if (c == 0) goto __cp_done
                
                ; Check if this copy has hit the null terminator
__cp_load:      ld A,(HL)           ; a = *hl
                cp $00              ; a==0
                jp z,__cp_done      ; if (a == 0) goto __cp_done
                
                ; Rapid instruction saves 14 clock cycles, moves byte
__cp_store:     ldi                 ; *(de++) = *(hl++); BC--
                jp R_STRCPY         ; Repeat the loop
                
                ; Null terminate
__cp_done:      ld A,$00            ; 
                ld (DE),A           ; Terminate dest
                ret                 ; Return control


; ==============================================================================
; R_STRAPP: String append
; 
; Append one string at the end of another string, limit between 0 and 65,535 
; characters. Dest max length does not include terminator. First str will be 
; truncated if longer than the dest max length.
;
; ARG: DE stores first/dest string addr
; ARG: HL stores second string addr
; ARG: BC stores dest str max length
; MOD: AF
; ==============================================================================
R_STRAPP:       ; Finding the end of the first string
                ld A,$00            ; 
                cp B                ; b==0
                jp nz,__ap_load     ; if (b != 0) goto __ap_load
                cp C                ; c==0
                jp z,__ap_copy      ; if (c == 0) goto __ap_copy
                
                ; Check if this seek has hit the null terminator
__ap_load:      ld A,(DE)           ; a = *de
                cp $00              ; a==0
                jp z,__ap_copy      ; if (a == 0) goto __ap_copy
                inc DE              ; DE++
                dec BC              ; BC--
                jp R_STRAPP         ; Repeat the loop
                
                ; Invoke the copy function to finish the job
__ap_copy:      call R_STRCPY
                ret                 ; Return control


; ==============================================================================
; R_STRLEN: String length
; 
; Count the number of characters in a null terminated string. If all of memory
; contains no null bytes, this function may never return. An enhancement may be
; added in the future to prevent this unlikely behavior.
;
; ARG: HL stores string address
; RET: DE returns string length
; MOD: AF, HL, DE
; ==============================================================================
R_STRLEN:       ld DE,$00           ; Count from 0

                ; Check if this seek has hit the null terminator
__ln_load:      ld A,(HL)           ; a = *HL
                cp $00              ; a==0
                jp z,__ln_done      ; if (a == 0) goto __ln_done
                inc DE              ; DE++
                inc HL              ; BC++
                jp __ln_load        ; Repeat the loop
                
                ; Invoke the copy function to finish the job
__ln_done:      ret                 ; Return control


; ==============================================================================
; R_STRCMP: String compare
; 
; Compare two strings to determine whether equal, or greater/lesser. 
;
; ARG: DE stores first string address
; ARG: HL stores second string address
; RET: A the difference between the first inequal character, or zero
; RET: F flags reflect compare of first inequal character, or last character
; MOD: AF, HL, DE, B
; ==============================================================================
R_STRCMP:
__stcm_next:    ld A,$00
                ld B,(HL)
                cp B
                jp z,__stcm_finl    ; *HL is null
                ld A,(DE)
                cp $00
                jp z,__stcm_fin     ; *DE is null
                cp B
                jp nz,__stcm_fin    ; *HL != *DE
                inc HL
                inc DE
                jp __stcm_next

__stcm_finl:    ld A,(DE)
__stcm_fin:     ; Something may be inequal, determine how much
                sub B
                ret


; ==============================================================================
; R_HEX2NIBBLE: Hex character to nibble
; 
; Convert a hexadecimal character '0' through 'a' or 'A' to a nibble, returned
; as a byte with values 0 through 15.
;
; ARG: A stores the char value
; RET: A returns the numeric value
; RET: B.0 bit returns high if the value is unparseable
; MOD: AF, B
; ==============================================================================
CHAR_0:         equ $30
R_HEX2NIBBLE:   sub A,CHAR_0        ; Subtract '0' to get numeric equivalent
                cp A,0x10
                jp c,__h2n_done     ; if (a < 10)
                sub A,0x07          ; Subtract upper case lettering offset
                cp A,0x16
                jp c,__h2n_done     ; if (a < 16)
                sub A,0x20          ; Subtract lower case lettering offset
                cp A,0x16
                jp c,__h2n_done     ; if (a < 16)
                jp __h2n_fail       ; This is not a hex character
                
__h2n_done:     ; Clear B0 and return
                res 0,B             ; B & 0x01 == 0
                ret                 ; Return control, success
                
 __h2n_fail:    ; Set B0 and return
                set 0,B             ; B & 0x01 == 1
                ret                 ; Return control, failure


; ==============================================================================
; M_STR2UNUM: Hex string to unsigned number (variable size)
; 
; Convert a hexadecimal string to N/2 bytes, reads at most the last N characters
; ignoring extra, and stopping if terminated.
;
; CONST: CWIDTH is the max char width of the source number hex string
;        must equal 2x the resulting number's byte width.
;
; ARG: HL stores upper nibble hex string address
; ARG: IX stores the destination number pointer
; RET: B.0 bit returns high if the value is unparseable
; MOD: AF, HL, BC, DE, IX
; ==============================================================================
MACRO M_STR2UNUM CWIDTH
                push HL
                call R_STRLEN       ; DE = len(HL)
                pop HL              ; HL = upper nibble ptr
                
                ; Perform a seek in the hi ptr, focus on lower 256 bytes (L)
                ld A,H
                add D
                ld H,A              ; Add D to H to hi seek
                ld D,$00
                
                ; Fast forward the lo ptr
                ld A,L
                add E
                ld L,A              ; L += E; lo seek
                ld A,H
                adc $00             
                ld H,A              ; Carry L to H
                
                ; See if we have more than N*2 bytes
                ld A,{CWIDTH}
                cp E
                jp nc,@__h2w_start  ; if (E <= N*2)
                ld E,{CWIDTH}       ; We'll ignore extra chars
                
@__h2w_start:   ; Are there 2 or more chars left?
                ld A,$01
                cp E
                jp z,@__h2w_skiphi  ; if (E == 1) only a half byte left
                jp nc,@__h2w_success ; if (E <= 1) we're done
                
                ; Read lo nibble
                dec HL              ; Walk ptr backwards
                dec E               ; Count down nibbles remaining
                ld A,(HL)           ; Fetch char
                call R_HEX2NIBBLE   ; Convert nibble
                bit 0,B             ; Failure?
                jp nz,@__h2w_done   ; This is not a hex character
                ld B,A
                
@__h2w_sec:     ; Read second of two or only nibble
                dec HL
                dec E
                ld A,(HL)           ; Fetch nibble
                call R_HEX2NIBBLE   ; Convert nibble
                bit 0,B             ; Failure?
                jp nz,@__h2w_done   ; This is not a hex character

@__h2w_skiphi:  ; Skip the upper nibble
                ld B,$00
                jp @__h2w_sec
                
                ; Assemble the nibbles
                sla A
                sla A
                sla A
                sla A
                or B                ; A = (A << 4) | B
                
                ; Write byte to memory
                ld (IX+$00),A       ; IX is terribly inefficient, but using RAM would be worse...
                inc IX              ; *(IX++) = A
                
                jp @__h2w_start     ; Next byte!
                
@__h2w_success: res 0,B             ; Mark successful result
                
@__h2w_done:    ret                 ; Return and preserve B0 error state

MEND


; ==============================================================================
; R_HEX2UINT8: Hex string to unsigned byte
; 
; See M_STR2UNUM for details.
; ==============================================================================
R_HEX2UINT8:    
                M_STR2UNUM 2        ; Number conversion with byte width


; ==============================================================================
; R_HEX2UINT16: Hex string to unsigned word (2 bytes)
; 
; See M_STR2UNUM for details.
; ==============================================================================
R_HEX2UINT16:    
                M_STR2UNUM 4        ; Number conversion with word width


; ==============================================================================
; R_HEX2UINT32: Hex string to unsigned int (4 bytes)
; 
; See M_STR2UNUM for details.
; ==============================================================================
R_HEX2UINT32:    
                M_STR2UNUM 8        ; Number conversion with int width


; ==============================================================================
; R_HEX2UINT64: Hex string to unsigned long (8 bytes)
; 
; See M_STR2UNUM for details.
; ==============================================================================
R_HEX2UINT64:    
                M_STR2UNUM 16        ; Number conversion with long width

   









