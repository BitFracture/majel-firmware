;
; MAJEL-1 MATH LIB V1
; 
; This library consists of mathematics functions for manipulating various data types in memory.
;
; Author: Erik W. Greif
; Date: 2021-06-16
;


; ==============================================================================
; M_ADDINT: Add N-byte integer number
; 
; Adds two numbers, works for signed and unsigned values. Uses an unrolled add
; carry chain instead of a loop, cutting execution time by 30%.
; 46 clock cycles for one iteration, +64 for each additional iteration
; 
; ARG: DE pointer to first number
; ARG: HL pointer to second number
; ARG: BC pointer to result
; RET: F flags following high-order byte add
; MOD: AF, HL, DE, BC
; ==============================================================================
MACRO M_ADDINT BYTES
  repeat {BYTES},CNT
        ld A,(DE)
        push BC             ; Back up dest address
        ld B,(HL)
    IF CNT==1
        add A,B             ; Add bytes
    ELSE
        adc A,B             ; Add bytes and carry
    ENDIF
        pop BC              ; Restore dest address
        ld (BC),A           ; Store result
    IF CNT!={BYTES}         ; We don't increment at the last iteration
        inc HL
        inc DE
        inc BC
    ENDIF
  rend
MEND


; ==============================================================================
; M_SUBINT: Subtract N-byte integer number
; 
; Subtract two numbers, works for signed and unsigned values. Uses an unrolled
; sub borrow chain instead of a loop. By using STORE_RESULT=0, no output is 
; stored to BC, and this method's cost is cut nearly in half. Used for making 
; comparisons.
; 
; ARG: DE pointer to first number (subtracted from)
; ARG: HL pointer to second number (subtracted)
; ARG: BC pointer to result during subtractions, unused for comparisons
; RET: F flags following high-order byte sub, with a zero flag fix on comparison
; MOD: AF, HL, DE, BC
; ==============================================================================
MACRO M_SUBINT BYTES,STORE_RESULT
    IF {STORE_RESULT}==0
        ld C,0x00
    ENDIF
  repeat {BYTES},CNT
        ld A,(DE)
    IF {STORE_RESULT}==1
        push BC             ; Back up dest address
    ENDIF
        ld B,(HL)
    IF CNT==1
        sub A,B             ; Add bytes
    ELSE
        sbc A,B             ; Add bytes and carry
    ENDIF
    IF {STORE_RESULT}==0
        jp z,@__msubintcnt
        ld C,0x01           ; Mark nonzero!
    ENDIF
@__msubintcnt:
    IF {STORE_RESULT}==1
        pop BC              ; Restore dest address
        ld (BC),A           ; Store result
    ENDIF
    IF CNT!={BYTES}         ; We don't increment at the last iteration
        inc HL
        inc DE
      IF {STORE_RESULT}==1
        inc BC
      ENDIF
    ENDIF
  rend
    IF {STORE_RESULT}==0
        ld A,0x00
        cp A,C
        jp z,@__msubz
        push AF
        pop BC
        res 6,C             ; Funky way to reset the zero flag
        jp @__msubdone
@__msubz:
        push AF
        pop BC
        set 6,C             ; Funky way to set the zero flag
@__msubdone:
        push BC
        pop AF
    ENDIF
MEND


; ==============================================================================
; M_ZINT: Fill N-byte integer with 0
; 
; Writes zeros to all bytes in a number.
; 
; ARG: BC pointer to result
; MOD: AF, BC
; ==============================================================================
MACRO M_ZINT BYTES
        ld A,0x00
  repeat {BYTES},CNT
        ld (BC),A
    IF CNT!={BYTES}         ; We don't increment at the last iteration
        inc BC
    ENDIF
  rend
MEND


; ==============================================================================
; R_ADDINT8: Add 1-byte integer
; 
; See M_ADDINT for details.
; ==============================================================================
R_ADDINT8:      M_ADDINT 1          ; Add 1 bytes
                ret

                
; ==============================================================================
; R_ADDINT16: Add 2-byte integer
; 
; See M_ADDINT for details.
; ==============================================================================
R_ADDINT16:     
                M_ADDINT 2          ; Add 2 bytes
                ret

             
; ==============================================================================
; R_ADDINT32: Add 4-byte integer
; 
; See M_ADDINT for details.
; ==============================================================================
R_ADDINT32:     M_ADDINT 4          ; Add 4 bytes
                ret


; ==============================================================================
; R_ADDINT64: Add 8-byte integer
; 
; See M_ADDINT for details.
; ==============================================================================
R_ADDINT64:     M_ADDINT 8          ; Add 8 bytes
                ret


; ==============================================================================
; R_SUBINT8: Sub 1-byte integer
; 
; See M_SUBINT for details.
; ==============================================================================
R_SUBINT8:      M_SUBINT 1,1        ; Subs 1 bytes
                ret


; ==============================================================================
; R_SUBINT16: Sub 2-byte integer
; 
; See M_SUBINT for details.
; ==============================================================================
R_SUBINT16:     M_SUBINT 2,1        ; Subs 2 bytes
                ret


; ==============================================================================
; R_SUBINT32: Sub 4-byte integer
; 
; See M_SUBINT for details.
; ==============================================================================
R_SUBINT32:     M_SUBINT 4,1        ; Subs 4 bytes
                ret


; ==============================================================================
; R_SUBINT64: Sub 8-byte integer
; 
; See M_SUBINT for details.
; ==============================================================================
R_SUBINT64:     M_SUBINT 8,1        ; Subs 8 bytes
                ret


; ==============================================================================
; R_CMPINT8: Sub 1-byte integer
; 
; See M_SUBINT for details.
; ==============================================================================
R_CMPINT8:      M_SUBINT 1,0        ; Compares 1 bytes
                ret


; ==============================================================================
; R_CMPINT16: Sub 2-byte integer
; 
; See M_SUBINT for details.
; ==============================================================================
R_CMPINT16:     M_SUBINT 2,0        ; Compares 2 bytes
                ret


; ==============================================================================
; R_CMPINT32: Sub 4-byte integer
; 
; See M_SUBINT for details.
; ==============================================================================
R_CMPINT32:     M_SUBINT 4,0        ; Compares 4 bytes
                ret

 
; ==============================================================================
; R_CMPINT64: Sub 8-byte integer
; 
; See M_SUBINT for details.
; ==============================================================================
R_CMPINT64:     M_SUBINT 8,0        ; Compares 8 bytes
                ret

 
; ==============================================================================
; R_ZINT8: Fill 1-byte integer with 0
; 
; See M_ZINT for details.
; ==============================================================================
R_ZINT8:     
                M_ZINT 1            ; Zero 1 byte
                ret

                
; ==============================================================================
; R_ZINT16: Fill 2-byte integer with 0
; 
; See M_ZINT for details.
; ==============================================================================
R_ZINT16:     
                M_ZINT 2            ; Zero 2 bytes
                ret

                
; ==============================================================================
; R_ZINT32: Fill 4-byte integer with 0
; 
; See M_ZINT for details.
; ==============================================================================
R_ZINT32:     
                M_ZINT 4            ; Zero 4 bytes
                ret

                
; ==============================================================================
; R_ZINT64: Fill 8-byte integer with 0
; 
; See M_ZINT for details.
; ==============================================================================
R_ZINT64:     
                M_ZINT 8            ; Zero 8 bytes
                ret















