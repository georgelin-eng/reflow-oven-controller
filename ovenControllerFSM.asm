
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

; Push button macro - It does not work :( - check if it works now, moved location
check_Push_Button MAC
    jb %0, %1
    Wait_Milli_Seconds(#50)
    jb %0, %1
    jnb %0, $
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
TIMER2_RELOAD         EQU (65536-(CLK/1000))    ; 1ms Delay ISR
TIMER0_RELOAD         EQU (0x10000-(CLK/4096))    ; Sound ISR For 2kHz square wave

; Pin definitions + Hardware Wiring 
START_PIN             EQU P1.5 ; change to correct pin later
CHANGE_MENU_PIN       EQU P1.6 ; change to correct pin later 
INC_TEMP_PIN          EQU P3.0 ; change to correct pin later
INC_TIME_PIN          EQU P0.4 ; change to correct pin later
STOP_PIN              EQU P1.0 ; change to correct pin later
PWM_OUT               EQU P1.1 ; change to correct pin later

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
FINISHED_SECONDS      EQU 10
MAX_TIME              EQU 90
MIN_TIME              EQU 15
MAX_TEMP              EQU 250
MIN_TEMP              EQU 100

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
Count1ms_PWM    : ds 1
seconds_elapsed	: ds 1
exit_seconds    : ds 1 ; if we dont reach 50 c before 60 S terminate

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

$NOLIST
$include(LCD_4bit.inc) ; A library of LCD related functions and utility macros
$LIST

; Flags that are used to control events 
BSEG 
mf              : dbit 1
IN_MENU_FLAG    : dbit 1
IN_OVEN_FLAG    : dbit 1
REFLOW_FLAG     : dbit 1

$NOLIST
$include(math32.inc)
$LIST

; Messages to display on LCD when in Menu FSM
LCD_defaultTop  : db 'Reflow Oven: ', 0
LCD_defaultBot  : db 'Start/Configure?', 0
LCD_soakTime    : db 'Soak Time: ', 0
LCD_soakTemp    : db 'Soak Temp: ', 0
LCD_reflowTime  : db 'Refl Time: ', 0
LCD_reflowTemp  : db 'Refl Temp: ', 0
LCD_TEST        : db 'TEST MESSAGE ', 0
LCD_clearLine   : db '                ', 0 ; put at end to clear line

preheatMessage  : db 'Preheat', 0
soakMessage     : db 'Soak', 0
ramp2peakMessage: db 'Peak to Soak', 0
reflowMessage   : db 'Reflow', 0
coolingMessage  : db 'Cooling', 0
FinishedMessage : db 'Finished!', 0
stopMessage     : db 'EMERGENCY STOP', 0

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

Timer0_ISR:
        reti

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
        clr     TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
        cpl     P0.4 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.

        ; The two registers used in the ISR must be saved in the stack
        push    acc
        push    psw

        inc     Count1ms_PWM

        ; Increment the 16-bit one mili second counter
        inc     Count1ms+0    ; Increment the low 8-bits first
        mov     a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
        jnz     Inc_done
        inc     Count1ms+1
 
        
        Inc_done:
        mov    a, Count1ms_PWM
        cjne   a, #10, check1secondsPassed 

                ;RK working on PWM
                inc     pwm_counter
                clr     c
                mov     a, pwm
                subb    a, pwm_counter ; If pwm_counter <= pwm then c=1
                cpl     c
                mov     PWM_OUT, c 
                mov     a, pwm_counter
                cjne    a, #100, Timer2_ISR_done
                mov     pwm_counter, #0

                clr     a
                mov     Count1ms_PWM, a
        
        
        check1secondsPassed:
        ; Check if one second has passed
	mov	a, Count1ms+0
	cjne    a, #low(1000), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov     a, Count1ms+1
	cjne    a, #high(1000), Timer2_ISR_done	

        ; ---  1s has passed ----
  
        ; debugging
        mov a,  pwm_counter
        lcall   SendToSerialPort
        mov a,  #'\r' ; Return character
        lcall   putchar
        mov a,  #'\n' ; New-line character
        lcall   putchar

        ; mov a, OVEN_STATE
        ; add A, #1
        ; mov OVEN_STATE, a
        jnb     REFLOW_FLAG,  not_in_reflow ;Checks if we are in reflow state
        mov     a, exit_seconds
        add     a, #1
        mov     exit_seconds, a
        
 not_in_reflow:
        mov     a, seconds_elapsed
        add     A, #1
        mov     seconds_elapsed, a

        ; reset seconds ms counter
        clr     a
        mov     Count1ms+0, a
        mov     Count1ms+1, a

        Timer2_ISR_done:
        pop     psw
	pop     acc
        reti

Initilize_All:
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
	clr	TR0         ; Stop timer 0
	orl	CKCON,#0x08 ; CLK is the input for timer 0
	anl	TMOD,#0xF0  ; Clear the configuration bits for timer 0
	orl	TMOD,#0x01  ; Timer 0 in Mode 1: 16-bit timer
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
        mov     temp_soak, #150
        mov     time_soak, #MIN_TIME
        mov     temp_refl, #220
        mov     time_refl, #MIN_TIME
        
        ; Oven configuration
        mov     OVEN_STATE, #OVEN_STATE_PREHEAT
        mov     seconds_elapsed, #0
        mov     Count1ms_PWM, #0
        mov     exit_seconds, #0
        clr     REFLOW_FLAG
        
        ret
        
;Button nested logic -> we should be constantly checking in the main loop for a stop (i.e the stop should be instantaneous)
        ;->Buttons should allow for adjustment of soak temp, soak time, reflow temp, reflow time (Ui should be designed to make all these visible and clear)
        ;->Start button should either be used only for start or used for start/pause (different from a stop
        ;Try to use button logic given in lab 2 to stay consistent
        ; Menu Logic (will keep UI clean)
        ; Button to switch states - Changes a state variable (4 states -> 2 bits) (or two flags)
        ; Two buttons to go up or down a value
        ; One button to stop <---- safety feature make this button only STOP
        
        ; ;pseudo code lol
        ; jb [button], [branch]
        ; Wait_Milli_Seconds(#50)
        ; jb [button], [branch]
        ; jnb [button], $
        ; ljmp [display??]

; ; 3 values : current time elapsed in seconds, 
; FSM_transition_check MAC
;         jb %0, %2
;         Wait_Milli_Seconds(#50) ; de-bounce
;         jb %0, %2
;         jnb %0, $
;         ; successful press registered
;         inc %1 ; increment param #1
; ENDMAC


STOP_PROCESS:
        ; Turn everything off
        clr     REFLOW_FLAG
        clr     IN_OVEN_FLAG
        MOV     OVEN_STATE, #OVEN_STATE_PREHEAT
        MOV     seconds_elapsed, #0
        MOV     pwm, #0
        ljmp    PROGRAM_ENTRY

; SSR_FSM: 


; Precondition: Has temperature stored in x
OVEN_FSM:
        check_Push_Button (STOP_PIN, enterOvenStateCheck)
        lcall   STOP_PROCESS

        ; check oven state if stop button is not pressed
        enterOvenStateCheck:
                mov     a, OVEN_STATE
           
        ovenFSM_preheat:
                ; long jump for relative offset
                cjne    a, #OVEN_STATE_PREHEAT, ovenFSM_soak_jmp
                sjmp    oven_state_preheat_tasks
                ovenFSM_soak_jmp:
                        ljmp    ovenFSM_soak
                oven_state_preheat_tasks:
                        mov     pwm, #30
                        Set_Cursor(1, 1)
                        Send_Constant_String(#preheatMessage)
                        Send_Constant_String(#LCD_clearLine)
                        Set_Cursor(2, 1)
                        mov     a, seconds_elapsed
                        lcall   SendToLCD

                        load_x  (60) ; Imagine this is the measured temp 

                ;Emergency exit process; tested, works
                setb    REFLOW_FLAG
                mov     a, exit_seconds
                cjne    a, #10, Skip_Emergency_exit
                load_y  (50)
                lcall   x_gteq_y
                jb      mf, Skip_Emergency_exit
                
                ; mov a, temp
                ; lcall ;send temperature value to serial
                ljmp    STOP_PROCESS ; more then 60 seconds has elapse and we are below 50C ESCAPE
                
        Skip_Emergency_exit:       
                ; check temperature has reached configured value 
                load_y  (temp_soak) ; this line is sus ; temp_soak is a BCD value
                lcall   x_gteq_y
                jnb     mf, noChange_preheatState
                mov     OVEN_STATE, #OVEN_STATE_SOAK
                noChange_preheatState:
                        ljmp    oven_FSM_done

        ovenFSM_soak:
                cjne    a, #OVEN_STATE_SOAK, ovenFSM_Ramp2Peak
                mov     pwm, #20
                Set_Cursor (1, 1)
                Send_Constant_String(#soakMessage)
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2, 1)
                mov     a, seconds_elapsed
                lcall   SendToLCD

                ; check if seconds elapsed > soak time
                mov     a, seconds_elapsed
                cjne    a, time_soak, noChange_soakState
                mov     OVEN_STATE, #OVEN_STATE_RAMP2PEAK
                ; mov seconds_elapsed, #0 ; reset
                noChange_soakState:
                        ljmp    oven_FSM_done

        ovenFSM_Ramp2Peak:
                cjne    a, #OVEN_STATE_RAMP2PEAK, ovenFSM_reflow
                mov     pwm, #100
                Set_Cursor(1, 1)
                Send_Constant_String(#ramp2peakMessage)
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2, 1)
                mov     a, seconds_elapsed
                lcall   SendToLCD
                mov     seconds_elapsed, #0 ; reset

                ; check that temperature for reflow is reached, then exit                
                load_y  (temp_refl) ; this line is sus ; temp_soak is a BCD value
                lcall   x_lteq_y
                jnb     mf, noChange_ramp2peak
                mov     OVEN_STATE, #OVEN_STATE_REFLOW
                noChange_ramp2peak:
                        ljmp    oven_FSM_done
                
        ovenFSM_reflow:
                cjne    a, #OVEN_STATE_REFLOW, ovenFSM_cooling
                mov     pwm, #100
                Set_Cursor(1, 1)
                Send_Constant_String(#reflowMessage)
                Send_Constant_String(#LCD_clearLine)
                mov     a, seconds_elapsed
                lcall   SendToLCD

                ; check if seconds elapsed > reflow time
                mov     a, seconds_elapsed
                cjne    a, time_refl, noChange_reflowState
                mov     OVEN_STATE, #OVEN_STATE_COOLING
                mov     seconds_elapsed, #0 ; reset
                noChange_reflowState:
                        ljmp    oven_FSM_done

        ovenFSM_cooling:
                cjne    a, #OVEN_STATE_COOLING, ovenFSM_finished
                mov     pwm, #0
                Set_Cursor(1, 1)
                Send_Constant_String(#coolingMessage)
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2, 1)
                mov     a, seconds_elapsed
                lcall   SendToLCD
                mov     seconds_elapsed, #0 ; reset

                ; once temperature is low (compare with temp constant)
                load_y  (COOLED_TEMP_LOAD_MATH) ; this line is sus ; temp_soak is a BCD value
                lcall   x_lteq_y
                jnb     mf, noChange_cooling
                mov     OVEN_STATE, #OVEN_STATE_FINISHED
                noChange_cooling:
                        ljmp    oven_FSM_done
        
        ovenFSM_finished:
                cjne    a, #OVEN_STATE_FINISHED, ovenFSM_exit
                Set_Cursor(1, 1)
                Send_Constant_String(#FinishedMessage)
                Send_Constant_String(#LCD_clearLine)
                mov     a, seconds_elapsed
                lcall   SendToLCD

                ; go back to Start Screen after a certain number of seconds
                mov     a, seconds_elapsed
                cjne    a, #FINISHED_SECONDS, noChange_finishedState
                ljmp    PROGRAM_ENTRY
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
        mov     a, MENU_STATE 
        check_Push_Button (CHANGE_MENU_PIN, checkTimeInc) ; increments menu state
        inc     a
        mov     MENU_STATE, a 

        ; increment is checked with a seperate cascade that's outside the FSM
        ; I wanted to keep FSM state outputs seperate from push button checks - George
        checkTimeInc:
                check_Push_Button(INC_TIME_PIN, checkTempInc)
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


         checkTempInc:
                check_Push_Button(INC_TEMP_PIN, enterMenuStateCheck)
                cjne a, #MENU_STATE_SOAK, incTempReflow
                        mov     a, temp_soak 
                        add     A, #5        
                        mov     temp_soak, a 

                        cjne a, #(MAX_TEMP+5), enterMenuStateCheck
                        mov a, #MIN_TEMP
                        mov temp_soak, a

                        sjmp enterMenuStateCheck       
                incTempReflow:
                        mov     a, temp_refl
                        add     A, #5
                        mov     temp_refl, a

                        cjne a, #(MAX_TEMP+5), enterMenuStateCheck
                        mov a, #MIN_TEMP
                        mov temp_refl, a

        ; ---------------- FSM State Check ---------------- ;  
        enterMenuStateCheck:
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
        lcall   Initilize_All
        lcall   LCD_4BIT

        ; Default display - 
        ; Reflow oven controller 
        ; (Start or Configure?)
        PROGRAM_ENTRY:
                Set_Cursor(1, 1)
                Send_Constant_String(#LCD_defaultTop)
                Set_Cursor(2, 1)
                Send_Constant_String(#LCD_defaultBot)

        checkStartButton: ; assumed negative logic - used a label for an easy ljmp in the future
                check_Push_Button(START_PIN, noStartButtonPress)
                ljmp    enter_oven_fsm ; successful button press, enter oven FSM   

        noStartButtonPress:
                ; if the 'IN_MENU' flag is set, always enter into the menu FSM, this is so that the menu FSM can always be entered
                ; creates an infinite loop that will always display menu once entered - broken if START button pressed
                jnb     IN_MENU_FLAG, checkMenuButtonPress
                lcall   MENU_FSM 
                ljmp    checkStartButton

        checkMenuButtonPress:
                ; check for enter menu button press (reusing increment menu pin)
                check_Push_Button(CHANGE_MENU_PIN, noMenuButtonPress)
                ; setb IN_MENU_FLAG; successful button press, enter menu FSM loop ; - THIS LINE CAUSES THE BUG
                ljmp    setMenuFlag
                
        noMenuButtonPress:
                ljmp    checkStartButton ; this line does not execute if ljmp setMenuFlag is there?!?!?

        enter_oven_fsm:
                clr     IN_MENU_FLAG ; No longer in menu
                setb    IN_OVEN_FLAG
                Set_Cursor(1,1)
                Send_Constant_String(#LCD_clearLine)
                Set_Cursor(2,1)
                Send_Constant_String(#LCD_clearLine)

                lcall   Timer2_Init  ; breaks things
                lcall   OVEN_FSM     ; will call STOP_PROCESS which loops back to the entry point
                lcall   STOP_PROCESS ; added for safety
                
        setMenuFlag: 
                setb    IN_MENU_FLAG
                ljmp    checkStartButton

        program_end:
                ljmp    main_program
END