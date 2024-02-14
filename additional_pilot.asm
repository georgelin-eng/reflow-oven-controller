

; Main file. FSM implementing the following sequence:
;       State 0: Power = 0% (default state)
;               if start = NO, self loop; if start = YES, next state
;       State 1: Power = 100%; Sec = 0
;               if temp <= 150, self loop; temp > 150, next
;       State 2: Power = 20%
;               if sec <= 60s, self loop; sec>60s, next
;       State 3: Power = 100%; Sec = 0
;               if temp <= 220, self loop; temp>220, next
;       State 4: Power = 20%
;               if sec <= 45s, self loop; sec >45, next
;       State 5: Power = 0%
;               if temp >=60, self loop; temp <60, next
;       return to state 0


; MACROS ;
CLJNE mac  
    cjne %0, %1, $+3+2 ; Jump if no equal 2 bytes ahead since sjmp is a 2 byte instruction  
    sjmp $+2+3 ; Jump 3 bytes after this instruction as ljmp takes 3 bytes to encode
    ljmp %2 ; ljmp can access any part of the code space
endmac

; check_Push_Button(variable_flag, dest_label)
; Params
; variable_flag - variable we are checking in place of the pin e.g. PB_START_PIN
; dest_label - where to jump if a push button is not pressed
check_Push_Button MAC ; new one with multiplexed buttons
        setb PB_START_PIN
        setb PB_CHANGE_MENU_PIN
        setb PB_INC_TEMP_PIN
        setb PB_INC_TIME_PIN
        setb PB_STOP_PIN
        
        setb SHARED_PIN
        ; check if any push buttons are pressed
        clr START_PIN             
        clr CHANGE_MENU_PIN       
        clr INC_TEMP_PIN          
        clr INC_TIME_PIN          
        clr STOP_PIN

        ; debounce
        jb SHARED_PIN, %1 ; use helper label to jump to the end
        Wait_Milli_Seconds(#50)
        jb SHARED_PIN, %1

        ; Set the LCD data pins to logic 1
        setb START_PIN
        setb CHANGE_MENU_PIN
        setb INC_TEMP_PIN
        setb INC_TIME_PIN
        setb STOP_PIN

        ; check push buttons 1 by one
        clr START_PIN
        mov c, SHARED_PIN
        mov PB_START_PIN, c
        setb START_PIN

        clr CHANGE_MENU_PIN
        mov c, SHARED_PIN
        mov PB_CHANGE_MENU_PIN, c
        setb CHANGE_MENU_PIN

        clr INC_TEMP_PIN
        mov c, SHARED_PIN
        mov PB_INC_TEMP_PIN, c
        setb INC_TEMP_PIN

        clr INC_TIME_PIN
        mov c, SHARED_PIN
        mov PB_INC_TIME_PIN, c
        setb INC_TIME_PIN

        clr STOP_PIN
        mov c, SHARED_PIN
        mov PB_STOP_PIN, c
        setb STOP_PIN

        jb %0, %1 ; check that the variable flag is not 1, otherwise jmp

ENDMAC

; temp_gt_threshold(threshold_temp, new_oven_state)
; assumes that x has current temp value
; new_oven_state is a constant
temp_gt_threshold MAC
        load_y(%0 * 10000)

        lcall x_gt_y
        jnb mf, $+3+3+3 ; jump past the jnb and mov instructions which are both 3 bytes
        mov OVEN_STATE, %1 
        mov seconds_elapsed, #0
        ljmp oven_FSM_done

ENDMAC

temp_lt_threshold MAC
        load_y(%0 * 10000)

        lcall x_lt_y
        jnb mf, $+3+3 ; jump past the jnb and mov instructions which are both 3 bytes
        mov OVEN_STATE, %1 
        ljmp oven_FSM_done

ENDMAC

$NOLIST
$MODN76E003
$LIST

;  N76E003 pinout:
;                               -------
;       PWM2/IC6/T0/AIN4/P0.5 -|1    20|- P0.4/AIN5/STADC/PWM3/IC3
;               TXD/AIN3/P0.6 -|2    19|- P0.3/PWM5/IC5/AIN6
;               RXD/AIN2/P0.7 -|3    18|- P0.2/ICPCK/OCDCK/RXD_1/[SCL]
;                    RST/P2.0 -|4    17|- P0.1/PWM4/IC4/MISO
;        INT0/OSCIN/AIN1/P3.0 -|5    16|- P0.0/PWM3/IC3/MOSI/T1
;              INT1/AIN0/P1.7 -|6    15|- P1.0/PWM2/IC2/SPCLK
;                         GND -|7    14|- P1.1/PWM1/IC1/AIN7/CLO
;[SDA]/TXD_1/ICPDA/OCDDA/P1.6 -|8    13|- P1.2/PWM0/IC0
;                         VDD -|9    12|- P1.3/SCL/[STADC]
;            PWM5/IC7/SS/P1.5 -|10   11|- P1.4/SDA/FB/PWM1
;                               -------



;-------------------------------------------------------------------------------------------------------------------------------------

;                                                              STYLE GUIDE

; End flag names with _FLAG
; Use all upper case for constants (anything defined in equ or pin definitions), as it makes it easier to read quickly
; Before any jump or logic block comment purpose and try to comment throughout - code should be self explanatory, comment "why" it was implemented this way
; Before any block of code also comment who wrote it 
; Aim for variable names with 8-20 characters

; --------------------------------------------------------------------------------------------------------------------------


; Timer constants
CLK                   EQU 16600000 ; Microcontroller system frequency in Hz
BAUD                  EQU 115200   ; Baud rate of UART in bps 
TIMER1_RELOAD         EQU (0x100-(CLK/(16*BAUD))) ; Serial ISR
TIMER2_RELOAD         EQU (65536-(CLK/1000))      ; 1ms Delay ISR
TIMER0_RELOAD         EQU (0x10000-(CLK/4096))    ; Sound ISR For 2kHz square wave

; Pin definitions + Hardware Wiring 
; Layout
; {Start} {Stop} {Change Menu} {Inc Temp} {Inc Time}
START_PIN             EQU P1.3 
CHANGE_MENU_PIN       EQU P0.1 
INC_TEMP_PIN          EQU P0.2  
INC_TIME_PIN          EQU P0.3  
STOP_PIN              EQU P0.0  
SHARED_PIN            EQU P1.5 

PWM_OUT               EQU P1.2 ; Pin 13

; FSM uses integer state encodings
; Menu states
MENU_STATE_SOAK       EQU 0
MENU_STATE_REFLOW     EQU 1
MENU_STATE_TEST       EQU 2

; oven states
OVEN_STATE_PREHEAT    EQU 0
OVEN_STATE_SOAK       EQU 1
OVEN_STATE_RAMP2PEAK  EQU 2
OVEN_STATE_REFLOW     EQU 3
OVEN_STATE_COOLING    EQU 4
OVEN_STATE_FINISHED   EQU 5

; things to keep track of
COOLED_TEMP           EQU 50 ; once cooled to this temperature, the reflow is now "finished"
COOLED_TEMP_LOAD_MATH EQU COOLED_TEMP*10000 ; use to load up the math
FINISHED_SECONDS      EQU 5
MAX_TIME              EQU 90
MIN_TIME              EQU 45
MAX_TEMP              EQU 250
MIN_TEMP              EQU 80

; define vectors
ORG 0x0000 ; Reset vector
        ljmp main_program
ORG 0x0003 ; External interrupt 0 vector
        reti
ORG 0x000B ; Timer/Counter 0 overflow interrupt vector
	ljmp Timer0_ISR
ORG 0x0013 ; External interrupt 1 vector
	reti
ORG 0x001B ; Timer/Counter 1 overflow interrupt vector 
	reti
ORG 0x0023 ; Serial port receive/transmit interrupt vector 
	reti
ORG 0x002B ; Timer/Counter 2 overflow interrupt vector
	ljmp Timer2_ISR


; register definitions previously needed by 'math32.inc' - currently commented out for future changes
DSEG at 0x30
x               : ds 4
y               : ds 4
z               : ds 4
bcd             : ds 5
bcdf            : ds 5
VLED_ADC        : ds 2

OVEN_STATE      : ds 1 ; stores oven FSM state
MENU_STATE      : ds 1 ; stores menu FSM state
temp_soak       : ds 1 
time_soak       : ds 1
temp_refl       : ds 1
time_refl       : ds 1
; pwm             : ds 1 ; controls output power to SSR
; pwm_counter     : ds 1 

Count1ms        : ds 2 ; determines the number of 1ms increments that have passed 
Count1ms0        : ds 2
Count1ms_PWM    : ds 1
seconds_elapsed	: ds 1
exit_seconds    : ds 1 ; if we dont reach 50 c before 60 S terminate
total_seconds   : ds 1 ; total runtime

pwm_counter: ds 1 ; Free running counter 0, 1, 2, ..., 100, 0
pwm: ds 1 ; pwm percentage


CSEG ;starts the absolute segment from that address
; These 'EQU' must match the hardware wiring
LCD_RS          EQU P1.3
;LCD_RW         EQU PX.X ; Not used in this code, connect the pin to GND
LCD_E           EQU P1.4
LCD_D4          EQU P0.0
LCD_D5          EQU P0.1
LCD_D6          EQU P0.2
LCD_D7          EQU P0.3

SOUND_OUT       EQU P0.4
$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

; Flags that are used to control events 
BSEG 
mf                  : dbit 1
IN_MENU_FLAG        : dbit 1
IN_OVEN_FLAG        : dbit 1
REFLOW_FLAG         : dbit 1
ENABLE_SEC_INC_FLAG : dbit 1 ; used to control whether seconds incrementing is enabled 
TIME_TO_BEEP_FLAG   : dbit 1 ; state transition flag; set to high whenever entering a new state 
SYSTEM_DONE_FLAG    : dbit 1 ; used for controlling the final beeping routine
BEEP_SECOND_FLAG    : dbit 1

; Variables used for push button mux
PB_START_PIN        : dbit 1
PB_CHANGE_MENU_PIN  : dbit 1
PB_INC_TEMP_PIN     : dbit 1
PB_INC_TIME_PIN     : dbit 1
PB_STOP_PIN         : dbit 1

$NOLIST
$include(math32.inc)
$LIST

; Messages to display on LCD when in Menu FSM
LCD_defaultTop  : db 'Reflow Oven:    ', 0
LCD_defaultBot  : db 'Start/Configure?', 0
LCD_soakTime    : db 'Soak Time: ', 0
LCD_soakTemp    : db 'Soak Temp: ', 0
LCD_reflowTime  : db 'Refl Time: ', 0
LCD_reflowTemp  : db 'Refl Temp: ', 0
LCD_TEST        : db 'TEST MESSAGE ', 0
LCD_clearLine   : db '                ', 0 ; put at end to clear line

preheatMessage  : db 'Preheat', 0
soakMessage     : db 'Soak', 0
ramp2peakMessage: db 'Ramp to Peak', 0
reflowMessage   : db 'Reflow', 0
coolingMessage  : db 'Cooling', 0
FinishedMessage : db 'Finished!', 0
stopMessage     : db 'EMERGENCY STOP', 0

; -- Debug messages
; seonds_passed   : db 'Seconds: ', 0
; temp            : db 'Temp: ', 0
; ovenState       : db 'State: ', 0
; errorMessage    : db '** ERROR **', 0

emergency:
    DB  'Emergency Stop!', '\r', '\n', 0

soak:
    DB  'y val from soak temp: ', 0

reflow:
    DB  'y val from reflow temp: ',0

soakTempLog:
    DB 'Soak Temp: ', 0

reflowTempLog:
    DB 'Reflow Temp: ', 0

; Messages to display on LCD when in Oven Controller FSM

; Send a character using the serial port
putchar:
        jnb     TI, putchar
        clr     TI
        mov     SBUF, a
        ret

; Send a constant-zero-terminated string using the serial port
SendString:
        clr     A
        movc    A, @A+DPTR
        jz      SendStringDone
        lcall   putchar
        inc     DPTR
        sjmp    SendString
SendStringDone:
        ret

; Eight bit number to display passed in ’a’.
SendToLCD:
        mov     b, #100
        div     ab
        orl     a, #0x30 ; Convert hundreds to ASCII
        lcall   ?WriteData ; Send to LCD
        mov     a, b ; Remainder is in register b
        mov     b, #10
        div     ab
        orl     a, #0x30 ; Convert tens to ASCII
        lcall   ?WriteData; Send to LCD
        mov     a, b
        orl     a, #0x30 ; Convert units to ASCII
        lcall   ?WriteData; Send to LCD
        ret

; Eight bit number to display passed in ’a’.
SendToSerialPort:
        mov     b, #100
        div     ab
        orl     a, #0x30 ; Convert hundreds to ASCII
        lcall   putchar ; Send to PuTTY/Python/Matlab
        mov     a, b ; Remainder is in register b
        mov     b, #10
        div     ab
        orl     a, #0x30 ; Convert tens to ASCII
        lcall   putchar ; Send to PuTTY/Python/Matlab
        mov     a, b
        orl     a, #0x30 ; Convert units to ASCII
        lcall   putchar ; Send to PuTTY/Python/Matlab
        ret

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	orl     CKCON, #0b00001000 ; Input for timer 0 is sysclk/1 ; performs bit masking on CKON - Clock Control ; T0M = 1, timer 0 uses the system clock directly
	mov     a, TMOD
	anl     a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl     a, #0x01 ; 00000001 Configure timer 0 as 16-timer (M1M0 = 01 -> Mode 1: 16-bit Timer/Counter)
	mov     TMOD, a
	mov     TH0, #high(TIMER0_RELOAD) ; 8051 works with 8 bits so the oepration T0 = TIMER0_RELOAD  (16 bits) is done by setting high byte then low byte (8x2)
	mov     TL0, #low (TIMER0_RELOAD)
	; Enable the timer and interrupts
        setb    ET0  ; Enable timer 0 interrupt
        setb    TR0  ; Start timer 0
	ret

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov     T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov     TH2, #high(TIMER2_RELOAD)
	mov     TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	orl     T2MOD, #0x80 ; Enable timer 2 autoreload
	mov     RCMP2H, #high(TIMER2_RELOAD)
	mov     RCMP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr     a
	mov     Count1ms+0, a
	mov     Count1ms+1, a
	; Enable the timer and interrupts
	orl     EIE, #0x80 ; Enable timer 2 interrupt ET2=1
        setb    TR2  ; Enable timer 2
	ret

Timer0_ISR: ; PASTED- AL
        ;clr TF0  ; According to the data sheet this is done for us already.
	; Timer 0 doesn't have 16-bit auto-reload, so
	clr TR0
        
	mov TH0, #high(TIMER0_RELOAD)
	mov TL0, #low(TIMER0_RELOAD)
	setb TR0


        jnb TIME_TO_BEEP_FLAG, Early_Exit
	cpl SOUND_OUT ; Connect speaker the pin assigned to 'SOUND_OUT'!

    Early_Exit:
 
        reti

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
        clr     TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
        ; cpl     P0.4 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.

        ; The two registers used in the ISR must be saved in the stack
        push    acc
        push    psw

        inc     Count1ms_PWM   ; variable used to count every 10ms used for the PWM

        ; Increment the 16-bit one mili second counter
        inc     Count1ms+0    ; Increment the low 8-bits first
        mov     a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
        jnz     Inc_done
        inc     Count1ms+1    


        
        Inc_done:
        ; If not in oven, skip PWM
        jnb    IN_OVEN_FLAG, skipPWM
        mov    a, Count1ms_PWM ; 


        ; This check is done so that this subroutine executes every 10ms 
        cjne    a, #10, check10msPassed 
                mov Count1ms_PWM, #0
                ;GL PWM code that Jesus gave
                ;RK working on PWM
                inc     pwm_counter
                clr     c
                mov     a, pwm
                subb    a, pwm_counter ; If pwm_counter <= pwm then c=1
                cpl     c
                mov     PWM_OUT, c 
                mov     a, pwm_counter
                ; cjne    a, #100, Timer2_ISR_done ; why does this go to Timer2_ISR_done? - GL
                cjne    a, #100, check10msPassed ; changed label from `Timer2_ISR_done` to `check10msPassed`
                mov     pwm_counter, #0

                clr     a
                mov     Count1ms_PWM, a ; reset the 1ms for PWM counter
        
                
        check10msPassed:
        skipPWM:
        ; Check if one second has passed
	mov	a, Count1ms+0
	cjne    a, #low(1000), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov     a, Count1ms+1
	cjne    a, #high(1000), Timer2_ISR_done	

        ; ---  1s has passed ----
        clr   TIME_TO_BEEP_FLAG
        lcall DO_TEMP_READ
        lcall hex2bcd ; puts value of x into BCD varaibles
        lcall send_temp_to_serial
        
        clr     a
        mov     Count1ms+0, a
        mov     Count1ms+1, a
        
        ; -------- Log File -------
        mov a,  PWM
        lcall   SendToSerialPort
        mov a,  #'\r' ; Return character
        lcall   putchar
        mov a,  #'\n' ; New-line character
        lcall   putchar

        ; mov a,  seconds_elapsed
        ; lcall   SendToSerialPort
        ; mov a,  #'\r' ; Return character
        ; lcall   putchar
        ; mov a,  #'\n' ; New-line character
        ; lcall   putchar

        ; mov a, OVEN_STATE
        ; add A, #1
        ; mov OVEN_STATE, a

        ; mov DPTR, #soakTempLog
        ; lcall SendString
        ; mov a, temp_soak
        ; lcall SendToSerialPort
        ; mov a,  #'\r' ; Return character
        ; lcall   putchar
        ; mov a,  #'\n' ; New-line character
        ; lcall   putchar

        ; mov DPTR, #reflowTempLog
        ; lcall SendString
        ; mov a, temp_refl
        ; lcall SendToSerialPort
        ; mov a,  #'\r' ; Return character
        ; lcall   putchar
        ; mov a,  #'\n' ; New-line character
        ; lcall   putchar

        jnb     REFLOW_FLAG,  not_in_reflow ;Checks if we are in reflow state
        mov     a, exit_seconds             ;Increments the early exit seconds counter
        add     a, #1
        mov     exit_seconds, a
        
 not_in_reflow:
        ; Check a flag for inc. seconds, otherwise go to end of timer, Timer2_ISR_done label used to save a line
        jnb     ENABLE_SEC_INC_FLAG, Timer2_ISR_done
        mov     a, seconds_elapsed
        add     A, #1
        mov     seconds_elapsed, a
        mov     a, total_seconds
        add     a, #1
        mov     total_seconds, a
        
        Timer2_ISR_done:
        ; reset seconds ms counter
        
        pop     psw
	pop     acc
        reti


Display_formated_BCD:
        Set_Cursor(2, 1)
        Display_BCD(bcd+3)
        Display_BCD(bcd+2)
        Display_char(#'.')
        Display_BCD(bcd+1)
        Display_BCD(bcd+0)
ret


InitSerialPort:
    ; Since the reset button bounces, we need to wait a bit before
    ; sending messages, otherwise we risk displaying gibberish!
    mov R1, #200
    mov R0, #104
    djnz R0, $   ; 4 cycles->4*60.285ns*104=25us
    djnz R1, $-4 ; 25us*200=5.0ms

    ; Now we can proceed with the configuration of the serial port
	orl	CKCON, #0x10 ; CLK is the input for timer 1
	orl	PCON, #0x80 ; Bit SMOD=1, double baud rate
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0F ; Clear the configuration bits for timer 1
	orl	TMOD, #0x20 ; Timer 1 Mode 2
	mov	TH1, #TIMER1_RELOAD
	setb TR1
        ret
        
;jesus' beautiful averaging code, can be used in place of Read_ADC in place where we read
Average_ADC:
        Load_x(0)
        mov R5, #100
        mov R6, #100

        Sum_loop0:
        lcall Read_ADC
        mov y+3, #0
        mov y+2, #0
        mov y+1, R1
        mov y+0, R0

        push x
        load_x(34300)
        lcall x_lteq_y
        jb mf, skipval
        pop x

        lcall add32
        djnz R5, Sum_loop0

        skipval:
               djnz R6, Sum_loop0

        ;load_y(100)
        mov y+3, #0
        mov y+2, #0
        mov y+1, #0
        mov y+0, R6
        lcall div32
        ret


Read_ADC:
        clr ADCF
        setb ADCS ;  ADC start trigger signal
        jnb ADCF, $ ; Wait for conversion complete
        
        ; Read the ADC result and store in [R1, R0]
        mov a, ADCRL
        anl a, #0x0f
        mov R0, a
        mov a, ADCRH  
        swap a
        push acc
        anl a, #0x0f
        mov R1, a
        pop acc
        anl a, #0xf0
        orl a, R0
        mov R0, A
ret

DO_TEMP_READ:
        ;push x
        ; Read the 2.08V LED voltage connected to AIN0 on pin 6
        anl ADCCON0, #0xF0
        orl ADCCON0, #0x00 ; Select channel 0

        lcall Read_ADC
        ; Save result for later use
        mov VLED_ADC+0, R0
        mov VLED_ADC+1, R1

        ; Read the signal connected to AIN7
        anl ADCCON0, #0xF0
        orl ADCCON0, #0x07 ; Select channel 7
        ;lcall Read_ADC
        lcall Average_ADC ;using in place of Read_ADC function, takes 100 measurements and averages
                          ;fairly instantaneous reading 

        ; Convert to voltage
        mov x+0, R0
        mov x+1, R1
        ; Pad other bits with zero
        mov x+2, #0
        mov x+3, #0
        Load_y(20500) ; The MEASURED LED voltage: 2.074V, with 4 decimal places
        lcall mul32
        ; Retrive the ADC LED value
        mov y+0, VLED_ADC+0
        mov y+1, VLED_ADC+1
        ; Pad other bits with zero
        mov y+2, #0
        mov y+3, #0
        lcall div32 ; x stores thermocouple voltage

        Load_y(81)
        lcall mul32

        ; code to use temp sensor for amb temp
        ;push x
;
        ;anl ADCCON0, #0xF0
        ;orl ADCCON0, #0x01 ; Select channel 1
        ;lcall Read_ADC
;
        ;mov x+0, R0
        ;mov x+1, R1
        ;; Pad other bits with zero
        ;mov x+2, #0
        ;mov x+3, #0
        ;Load_y(20500) ; The MEASURED LED voltage: 2.074V, with 4 decimal places
        ;lcall mul32
        ;; Retrive the ADC LED value
        ;mov y+0, VLED_ADC+0
        ;mov y+1, VLED_ADC+1
        ;; Pad other bits with zero
        ;mov y+2, #0
        ;mov y+3, #0
        ;lcall div32
;
        ;load_y(100)
        ;lcall mul32
        ;
        ;
        ;load_y(273000)
        ;lcall sub32
;
        ;mov y+0, x+0
        ;mov y+1, x+1
        ;mov y+2, x+2
        ;mov y+3, x+3
;
        ;lcall hex2bcd
        ;lcall send_temp_to_serial
;
        ;pop x
        
        Load_y(220000) ;adding 22, will change to ambient later
        lcall add32

        ret

;---------------------------------;
; Send a BCD number to PuTTY      ;
;---------------------------------;
Send_BCD mac
	push    ar0
	mov     r0, %0
	lcall   ?Send_BCD
	pop     ar0
	endmac
	?Send_BCD:
                push    acc
                ; Write most significant digit
                mov     a, r0
                swap    a
                anl     a, #0fh
                orl     a, #30h
                lcall   putchar
                ; write least significant digit
                mov     a, r0
                anl     a, #0fh
                orl     a, #30h
                lcall   putchar
                pop     acc
ret

; oven_FSM_LCD_DISPLAY (message)
; Params
;       message - constant string dataByte
oven_FSM_LCD_DISPLAY MAC
        ; Display mode and temperature on line 1
        Set_Cursor(1,1)
        Send_Constant_String(%0)
        Send_Constant_String(#LCD_clearLine)

        ; display seconds on line 2
        Set_Cursor(2, 1)
        mov     a, seconds_elapsed
ENDMAC

; Sends the BCD value
send_temp_to_serial:
        ; Sends temperature
        Send_BCD (bcd+3)
        Send_BCD (bcd+2)
        mov a, #'.'
        lcall putchar
        Send_BCD (bcd+1)
        Send_BCD (bcd+0)

        ; Sends soak time, soak temp, reflow time, reflow temp
        mov a, time_soak
        lcall SendToSerialPort 
        mov a, temp_soak
        lcall SendToSerialPort 
        mov a, time_refl
        lcall SendToSerialPort 
        mov a, temp_refl
        lcall SendToSerialPort 

        mov a,  #'\r' ; Return character
        lcall   putchar
        mov a,  #'\n' ; New-line character
        lcall   putchar

        ret 

INIT_ALL:
        ; Configure pins to be bi-directional
        mov	P3M1,#0x00
	mov	P3M2,#0x00
	mov	P1M1,#0x00
	mov	P1M2,#0x00
	mov	P0M1,#0x00
	mov	P0M2,#0x00

        setb    CHANGE_MENU_PIN
        setb    START_PIN

        setb    EA   ; Enable Global interrupts
        lcall   Timer0_Init
        lcall   Timer2_Init

        ; Since the reset button bounces, we need to wait a bit before
        ; sending messages, otherwise we risk displaying gibberish!
        Wait_Milli_Seconds(#50)

        ; Now we can proceed with the configuration of the serial port
        orl	CKCON, #0x10 ; CLK is the input for timer 1
        orl	PCON, #0x80  ; Bit SMOD=1, double baud rate
        mov	SCON, #0x52
        anl	T3CON, #0b11011111
        anl	TMOD, #0x0F ; Clear the configuration bits for timer 1
        orl	TMOD, #0x20 ; Timer 1 Mode 2
        mov	TH1, #TIMER1_RELOAD
        setb    TR1

        ; ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓ SUS  ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓ ↓   
        ; works on its own from lab3, might interfere with other stuff though       ; NOTE TIMER ZERO HAS NOT YET BEEN TESTED       
        ; Using timer 0 for delay functions.  Initialize here:
	;clr	TR0         ; Stop timer 0
	;orl	CKCON,#0x08 ; CLK is the input for timer 0
	;anl	TMOD,#0xF0  ; Clear the configuration bits for timer 0
	;orl	TMOD,#0x01  ; Timer 0 in Mode 1: 16-bit timer
        ; ^ ^ ^ ^ ^ ^ ^ ^^ ^ ^ ^ ^ ^^ ^ ^ ^ ^^ ^ ^ ^            
	
	; Initialize the pins used by the ADC (P1.1, P1.7) as input.
	orl	P1M1, #0b10000010
	anl	P1M2, #0b01111101
	
	; Initialize and start the ADC:
	anl     ADCCON0, #0xF0
	orl     ADCCON0, #0x07 ; Select channel 7
	
        ; AINDIDS select if some pins are analog inputs or digital I/O:
	mov     AINDIDS, #0x00 ; Disable all analog inputs
	orl     AINDIDS, #0b10000001 ; Activate AIN0 and AIN7 analog inputs
	orl     ADCCON1, #0x01 ; Enable ADC

        ; Menu Configuration
        clr     IN_MENU_FLAG
        clr     IN_OVEN_FLAG
        mov     a, #0
        mov     MENU_STATE, a ; set menu state to 0 

        ; mov     temp_soak, #0x250
        mov     temp_soak, #MIN_TEMP ; 80
        mov     time_soak, #MIN_TIME
        mov     temp_refl, #120
        mov     time_refl, #MIN_TIME
        
        ; Oven configuration
        mov     OVEN_STATE, #OVEN_STATE_PREHEAT
        mov     seconds_elapsed, #0
        mov     PWM, #0
        mov     Count1ms_PWM, #0
        mov     exit_seconds, #0
        mov     total_seconds, #0
        clr     REFLOW_FLAG
        clr     ENABLE_SEC_INC_FLAG ; flag is set to zero so that seconds won't increment
        clr     TIME_TO_BEEP_FLAG   ; flag is one when we switch states (i.e will beep)

        setb    TR2

        ; clear x
        mov x+0, #0
        mov x+1, #0
        mov x+2, #0
        mov x+3, #0

        
        ret

STOP_PROCESS:
        ; Turn everything off
       
        clr     PWM_OUT
        clr     REFLOW_FLAG
        clr     IN_OVEN_FLAG
        clr     IN_MENU_FLAG
        MOV     OVEN_STATE, #OVEN_STATE_PREHEAT
        MOV     seconds_elapsed, #0
        mov     Count1ms_PWM, #0
        mov     exit_seconds, #0
        mov     total_seconds, #0
        MOV     pwm, #0
        MOV     pwm_counter, #0
        mov x+0, #0
        mov x+1, #0
        mov x+2, #0
        mov x+3, #0

        ; mov DPTR, #emergency
        ; lcall SendString

        ; Do not disable TR2, otherwise temperature will no longer be sent to serial
        ; clr     TR2 ; disable timer 2 so that it doesn't count up in background ; 
        clr     ENABLE_SEC_INC_FLAG ; 
        ljmp    PROGRAM_ENTRY

; Precondition: Has temperature stored in BCD
; States
;       Preheat --> Soak --> Ramp to Peak --> Reflow --> Cooling --> Finished ----> EXIT
;
; Exit conditions
;       1. Early exit  - Stop button pressed
;       2. Early exit  - Temp threshold not reached after 60s
;       3. Normal exit - End of FSM reached 
;
; State Layout
;    state_label
;       if OVEN_STATE != state,  jmp
;       display on time and temp LCD
OVEN_FSM:
        Wait_Milli_Seconds(#50)                                 
        

        check_Push_Button (PB_STOP_PIN, enterOvenStateCheck)    
        setb    TIME_TO_BEEP_FLAG
        lcall   STOP_PROCESS

        ; check oven state if stop button is not pressed
        enterOvenStateCheck:
                mov  a, OVEN_STATE
        
        ovenFSM_preheat:

                ;
                
                ; long jump for relative offset
                cjne    a, #OVEN_STATE_PREHEAT, ovenFSM_soak_jmp
                sjmp    oven_state_preheat_tasks
                ovenFSM_soak_jmp:
                        ljmp    ovenFSM_soak
                oven_state_preheat_tasks:
                        mov     pwm, #80
                        Set_Cursor(1, 1)
                        Send_Constant_String(#preheatMessage)
                        Send_Constant_String(#LCD_clearLine)
                        Set_Cursor(2, 14)
                        mov     a, seconds_elapsed
                        lcall   SendToLCD ; send seconds to LCD
                        mov     a, total_seconds
                        set_cursor(1, 14)
                        lcall   SendToLCD
                        lcall   hex2bcd
                        ; lcall   send_temp_to_serial
                        lcall   Display_formated_BCD

                ;Emergency exit process; tested, works
                setb    REFLOW_FLAG
                mov     a, exit_seconds
                cjne    a, #60, Skip_Emergency_exit
                load_y  (50*10000)
                lcall   x_gteq_y
                jb      mf, Skip_Emergency_exit ; if x > y, don't exit
                
                ; mov a, temp
                ; lcall ;send temperature value to serial
                ljmp    STOP_PROCESS ; more then 60 seconds has elapsed and we are below 50C ESCAPE
                
        Skip_Emergency_exit:       
                ; State transition check ; if x > temp_soak, next state ; else, self loop
                mov y+0, temp_soak
                mov y+1, #0
                mov y+2, #0
                mov y+3, #0        
                load_z(10000)
                lcall mul32z
                mov y+0, z+0
                mov y+1, z+1
                mov y+2, z+2
                mov y+3, z+3     ; y = y * 10000
                load_z(250000)
                lcall sub32z    ; y = y - 25
                
                ; print value of y to serial for debugging
                ; mov a, y+3
                ; lcall SendToSerialPort
                ; mov a, y+2
                ; lcall SendToSerialPort
                ; mov a, y+1
                ; lcall SendToSerialPort
                ; mov a, y+0
                ; lcall SendToSerialPort

                ; mov a,  #'\r' ; Return character
                ; lcall   putchar
                ; mov a,  #'\n' ; New-line character
                ; lcall   putchar

                lcall x_gt_y   ; if x > y-30, set PWM
                jnb mf, $+3+3
                mov PWM, #0 ; turn PWM off

                mov y+0, temp_soak
                mov y+1, #0
                mov y+2, #0
                mov y+3, #0        
                load_z(10000)
                lcall mul32z
                mov y+0, z+0
                mov y+1, z+1
                mov y+2, z+2
                mov y+3, z+3                        

                lcall x_gt_y
                jnb mf, noChange_preHeat ; jump past the jnb and mov instructions which are both 3 bytes
                mov OVEN_STATE, #OVEN_STATE_SOAK
                mov seconds_elapsed, #0
                setb TIME_TO_BEEP_FLAG
                
        noChange_preHeat:
                ljmp oven_FSM_done
        
        ovenFSM_soak:
                cjne    a, #OVEN_STATE_SOAK, ovenFSM_Ramp2Peak
                mov     pwm, #1
                Set_Cursor (1, 1)
                Send_Constant_String(#soakMessage)
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2, 14)
                mov     a, seconds_elapsed
                lcall   SendToLCD
                mov     a, total_seconds
                set_cursor(1, 14)
                lcall SendToLCD
                
                lcall   hex2bcd
                lcall   Display_formated_BCD

                ; check if seconds elapsed > soak time
                mov     a, seconds_elapsed
                cjne    a, time_soak, noChange_soakState
                mov     OVEN_STATE, #OVEN_STATE_RAMP2PEAK
                mov     seconds_elapsed, #0 ; reset
                setb    TIME_TO_BEEP_FLAG

                noChange_soakState:
                        ljmp    oven_FSM_done
        
        ovenFSM_Ramp2Peak:
                cjne    a, #OVEN_STATE_RAMP2PEAK, ovenFSM_reflow_jmp
                sjmp ovenFSM_Ramp2Peak_task
                ovenFSM_reflow_jmp:
                ljmp ovenFSM_reflow
                ovenFSM_Ramp2Peak_task:
                mov     pwm, #80
                Set_Cursor(1, 1)
                Send_Constant_String(#ramp2peakMessage)
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2, 14)
                mov     a, seconds_elapsed
                lcall   SendToLCD
                mov     a, total_seconds
                set_cursor(1, 14)
                lcall SendToLCD

                lcall   hex2bcd
                lcall   Display_formated_BCD

                ; check that temperature for reflow is reached, then exit 
                mov y+0, temp_refl
                mov y+1, #0
                mov y+2, #0
                mov y+3, #0        
                load_z(10000)
                lcall mul32z
                mov y+0, z+0
                mov y+1, z+1
                mov y+2, z+2
                mov y+3, z+3     ; y = y * 10000
                load_z(100000)
                lcall sub32z    ; y = y - 10


                lcall x_gt_y   ; if x > y-30, set PWM
                jnb mf, $+3+3
                mov PWM, #0 ; turn PWM off

                mov y+0, temp_refl
                mov y+1, #0
                mov y+2, #0
                mov y+3, #0        
                load_z(10000)
                lcall mul32z
                mov y+0, z+0
                mov y+1, z+1
                mov y+2, z+2
                mov y+3, z+3                        

                lcall x_gt_y
                ; 
                jnb mf, noChange_Ramp2Peak ; jump past the jnb and mov instructions which are both 3 bytes
                mov OVEN_STATE, #OVEN_STATE_REFLOW
                mov  seconds_elapsed, #0
                setb TIME_TO_BEEP_FLAG

                noChange_Ramp2Peak:
                ljmp oven_FSM_done
                
        ovenFSM_reflow:
                cjne    a, #OVEN_STATE_REFLOW, ovenFSM_cooling
                mov     pwm, #5
                Set_Cursor(1, 1)
                Send_Constant_String(#reflowMessage)
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2, 14)
                mov     a, seconds_elapsed
                lcall   SendToLCD
                mov     a, total_seconds
                set_cursor(1, 14)
                lcall SendToLCD

                lcall   hex2bcd
                lcall   Display_formated_BCD

                ; check if seconds elapsed > reflow time
                mov     a, seconds_elapsed
                cjne    a, time_refl, noChange_reflowState
                mov     OVEN_STATE, #OVEN_STATE_COOLING
                mov     seconds_elapsed, #0 ; reset
                setb    TIME_TO_BEEP_FLAG
               
                noChange_reflowState:
                        ljmp    oven_FSM_done

        ovenFSM_cooling:
                cjne    a, #OVEN_STATE_COOLING, ovenFSM_finished
                mov     pwm, #0
                Set_Cursor(1, 1)
                Send_Constant_String(#coolingMessage)
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2, 14)
                mov     a, seconds_elapsed
                lcall   SendToLCD
                mov     a, total_seconds
                set_cursor(1, 14)
                lcall SendToLCD

                lcall   hex2bcd
                ; lcall   send_temp_to_serial
                lcall   Display_formated_BCD

                ; once temperature is low (compare with temp constant)
                load_y(50 * 10000)
                lcall x_lt_y
                jnb mf, $+3+3+3 ; jump past the jnb and mov instructions which are both 3 bytes
                mov OVEN_STATE, #OVEN_STATE_FINISHED
                mov     seconds_elapsed, #0 ; reset
                setb    TIME_TO_BEEP_FLAG
              
                ljmp oven_FSM_done

        ovenFSM_finished:
                cjne    a, #OVEN_STATE_FINISHED, ovenFSM_exit
                Set_Cursor(1, 1)
                Send_Constant_String(#FinishedMessage)
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2, 14)
                mov     a, seconds_elapsed
                lcall   SendToLCD
                mov     a, total_seconds
                set_cursor(1, 14)
                lcall SendToLCD
                
                Send_Constant_String(#LCD_clearLine)


                ; go back to Start Screen after a certain number of seconds
                mov     a, seconds_elapsed
                cjne    a, #FINISHED_SECONDS, noChange_finishedState
                mov OVEN_STATE, #OVEN_STATE_PREHEAT
                lcall STOP_PROCESS
                noChange_finishedState:
                        ljmp    oven_FSM_done

        ovenFSM_exit:
                mov     OVEN_STATE, #OVEN_STATE_PREHEAT
                ; ljmp oven_FSM_done
                lcall   STOP_PROCESS ; Exit oven FSM, turn power off, return to program entry
                
        oven_FSM_done:
                ljmp    OVEN_FSM ; return to start of oven FSM ; this is a blocking FSM
        
ret ; technically unncessary

MENU_FSM: 
        ; lcall configure_LCD_multiplexing
        mov     pwm, #0
        mov     a, MENU_STATE 
        check_Push_Button (PB_CHANGE_MENU_PIN, checkTimeInc) ; increments menu state
        inc     a
        mov     MENU_STATE, a 
        ;clr     TIME_TO_BEEP_FLAG
        setb    CHANGE_MENU_PIN
        
        ; increment is checked with a seperate cascade that's outside the FSM
        ; I wanted to keep FSM state outputs seperate from push button checks - George
        checkTimeInc:
                check_Push_Button(PB_INC_TIME_PIN, checkTempInc)
                cjne a, #MENU_STATE_SOAK, incTimeReflow
                        mov     a, time_soak 
                        add     A, #5        
                        mov     time_soak, a 

                        ; check if time_soak will need to reset - assumes multiples of 5
                        ; +5 to constants so they display on LCD b/f reseting
                        cjne a, #(MAX_TIME+5), checkTempInc 
                        mov a, #MIN_TIME
                        mov time_soak, a

                        sjmp checkTempInc       
                incTimeReflow:
                        mov     a, time_refl
                        add     A, #5
                        mov     time_refl, a

                        cjne a, #(MAX_TIME+5), checkTempInc
                        mov a, #MIN_TIME
                        mov time_refl, a

        ; check whether we're in the soak or 
        checkTempInc:
                check_Push_Button(PB_INC_TEMP_PIN, enterMenuStateCheck)
                cjne a, #MENU_STATE_SOAK, incTempReflow
                        mov     a, temp_soak 
                        add     a, #5        
                        mov     temp_soak, a 

                        cjne a, #(MAX_TEMP+5), enterMenuStateCheck
                        mov a, #MIN_TEMP
                        mov temp_soak, a

                        sjmp enterMenuStateCheck       
                incTempReflow:
                        mov     a, temp_refl
                        add     a, #5
                        mov     temp_refl, a

                        cjne a, #(MAX_TEMP+5), enterMenuStateCheck
                        mov a, #MIN_TEMP
                        mov temp_refl, a

        ; ---------------- FSM State Check ---------------- ;  
        enterMenuStateCheck:
                setb INC_TEMP_PIN
                mov     a, MENU_STATE

        menuFSM_configSoak:
                cjne    a, #MENU_STATE_SOAK, menuFSM_configReflow
                ; display Soak Menu Options
                Set_Cursor(1, 1)
                Send_Constant_String(#LCD_soakTemp)
                mov     a, temp_soak
                lcall   SendToLCD
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2, 1)
                Send_Constant_String(#LCD_soakTime)
                mov     a, time_soak
                lcall   SendToLCD
                Send_Constant_String(#LCD_clearLine)
                ljmp    menu_FSM_done

        menuFSM_configReflow:
                cjne    a, #MENU_STATE_REFLOW, reset_menu_state
                ; display Reflow Menu Options
                Set_Cursor(1, 1)
                Send_Constant_String(#LCD_reflowTemp)
                mov     a, temp_refl
                lcall   SendToLCD
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2, 1)
                Send_Constant_String(#LCD_reflowTime)
                mov     a, time_refl
                lcall   SendToLCD
                Send_Constant_String(#LCD_clearLine)
                ljmp    menu_FSM_done

        reset_menu_state: ; sets menu state variable to 0
                mov     MENU_STATE, #MENU_STATE_SOAK
                ljmp    menu_FSM_done

        menu_FSM_done:
                ret

main_program:
        ; George
        mov     sp, #0x7f
        lcall   INIT_ALL
        lcall   LCD_4BIT
        clr     PWM_OUT

        ; Default display - 
        ; Reflow oven controller 
        ; (Start or Configure?)
        PROGRAM_ENTRY:
                Set_Cursor(1, 1)
                Send_Constant_String(#LCD_defaultTop)
                Set_Cursor(2, 1)
                Send_Constant_String(#LCD_defaultBot)
                
                mov  PWM, #0 ; sets PWM to zero
                clr  PWM_OUT

                setb TR2 ; keep TR2 enabled

        checkStartButton: ; assumed negative logic - used a label for an easy ljmp in the future
                check_Push_Button(PB_START_PIN, noStartButtonPress)
                setb    ENABLE_SEC_INC_FLAG 
                setb    TIME_TO_BEEP_FLAG
                setb    TR0

                ; Send 0 to the serial
                mov BCD+0, #0x0
                mov BCD+1, #0x0
                mov BCD+2, #0x0
                mov BCD+3, #0x0
                mov BCD+4, #0x0
                lcall send_temp_to_serial
                mov a,  #'\r' ; Return character
                lcall   putchar
                mov a,  #'\n' ; New-line character
                lcall   putchar

                ljmp    enter_oven_fsm ; successful button press, enter oven FSM   

        noStartButtonPress:
                setb    START_PIN
                ; if the 'IN_MENU' flag is set, always enter into the menu FSM, this is so that the menu FSM can always be entered
                ; creates an infinite loop that will always display menu once entered - broken if START button pressed
                jnb     IN_MENU_FLAG, checkMenuButtonPress
                lcall   MENU_FSM 
                ljmp    checkStartButton

        checkMenuButtonPress:
                ; check for enter menu button press (reusing increment menu pin)
                check_Push_Button(PB_CHANGE_MENU_PIN, noMenuButtonPress)
                ; setb IN_MENU_FLAG; successful button press, enter menu FSM loop ; - THIS LINE CAUSES THE BUG
                ljmp    setMenuFlag
                
        noMenuButtonPress:
                setb CHANGE_MENU_PIN
                ljmp    checkStartButton ; this line does not execute if ljmp setMenuFlag is there?!?!?

        enter_oven_fsm:
                clr     IN_MENU_FLAG ; No longer in menu
                setb    IN_OVEN_FLAG
                Set_Cursor(1,1)
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2,1)
                Send_Constant_String(#LCD_clearLine)
                ; lcall   Timer2_Init  
                lcall   OVEN_FSM     ; `OVEN_FSM` exit by calling STOP_PROCESS which then loops back to the entry point
                lcall   STOP_PROCESS ; added for safety
                
        setMenuFlag: 
                setb    IN_MENU_FLAG
                ljmp    checkStartButton

        program_end:
                ljmp    main_program
END
