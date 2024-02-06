;;;;; FSM ;;;;;

;;Include this before the FSM
; Variables need to be initialized!
;About Variables
;• Initialize variables before using them!
;• It is easy to work with binary (8-bit) variables. Use “inc”,
;“dec”, to increment/decrement and ‘subb’ to compare.
;• Small variables are easy to save and retrieve from non-
;volatile memory such as FLASH or EEPROM.
;• If temperature measurements are too “noisy”, make several
;measurements and take the average!
;• To convert 8-bit binary variable to decimal use either
;HEX2BCD (in the math32 library) or one of these
;smaller/faster 8051 subroutines:
DSEG ; Before the state machine!
state: ds 1
temp_soak: ds 1
Time_soak: ds 1
Temp_refl: ds 1
Time_refl: ds 1
;;;;;;;;;
FSM1:
    mov a, FSM1_state
    FSM1_state0:
    cjne a, #0, FSM1_state1
    mov pwm, #0
    jb PB6, FSM1_state0_done
    jnb PB6, $ ; Wait for key release
    mov FSM1_state, #1
    FSM1_state0_done:
    ljmp FSM1_FSM2
FSM1_state1:
    cjne a, #1, FSM1_state2
    mov pwm, #100
    mov sec, #0
    mov a, #150
    clr c
    subb a, temp
    jnc FSM1_state1_done
    mov FSM1_state, #2
FSM1_state1_done:
    ljmp FSM2
    FSM1_state2:
    cjne a, #2, FSM1_state3
    mov pwm, #20
    mov a, #60
    clr c
    subb a, sec
    jnc FSM1_state2_done
    mov FSM1_state, #3
    FSM1_state2_done:
    ljmp FSM2



;;;;; 8 Bit Number Binary to Decimal Conversion ;;;;;
; Send eight bit number via serial port, passed in ’a’.
SendToSerialPort:
    mov b, #100
    div ab
    orl a, #0x30 ; Convert hundreds to ASCII
    lcall putchar ; Send to PuTTY/Python/Matlab
    mov a, b ; Remainder is in register b
    mov b, #10
    div ab
    orl a, #0x30 ; Convert tens to ASCII
    lcall putchar ; Send to PuTTY/Python/Matlab
    mov a, b
    orl a, #0x30 ; Convert units to ASCII
    lcall putchar ; Send to PuTTY/Python/Matlab
    ret

; Eight bit number to display passed in ’a’.
; Sends result to LCD
SendToLCD:
    mov b, #100
    div ab
    orl a, #0x30 ; Convert hundreds to ASCII
    lcall ?WriteData ; Send to LCD
    mov a, b ; Remainder is in register b
    mov b, #10
    div ab
    orl a, #0x30 ; Convert tens to ASCII
    lcall ?WriteData; Send to LCD
    mov a, b
    orl a, #0x30 ; Convert units to ASCII
    lcall ?WriteData; Send to LCD
    ret

;;;; MACRO EXAMPLE ;;;;
Change_8bit_Variable MAC
    jb %0, %2
    Wait_Milli_Seconds(#50) ; de-bounce
    jb %0, %2
    jnb %0, $
    jb SHIFT_BUTTON, skip%Mb
    dec %1
    sjmp skip%Ma
skip%Mb:
    inc %1
skip%Ma:
ENDMAC
;; More Macro Code (example cont'd)
    Change_8bit_Variable(MY_VARIABLE_BUTTON, my_variable, loop_c)
    Set_Cursor(2, 14)
    mov a, my_variable
    lcall SendToLCD
    lcall Save_Configuration
    loop_c:

; • ‘Noisy’ measurements? Average!
Average_ADC:
    Load_x(0)
    mov R5, #100
Sum_loop0:
    lcall Read_ADC
    mov y+3, #0
    mov y+2, #0
    mov y+1, R1
    mov y+0, R0
    lcall add32
    djnz R5, Sum_loop0
    load_y(100)
    lcall div32
    ret
