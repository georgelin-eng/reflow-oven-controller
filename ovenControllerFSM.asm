


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
TIMER1_RELOAD         EQU (0x100-(CLK/(16*BAUD))) ; ISR that's used for serial???
TIMER2_RELOAD         EQU (0x10000-(CLK/1000))    ; For ISR that runs every 1ms
TIMER0_RELOAD         EQU (0x10000-(CLK/4096))    ; For 2kHz square wave

; Pin definitions + Hardware Wiring
START_PIN             EQU P1.0 ; change to correct pin later
; STOP_PIN              EQU P1.5 ; change to correct pin later
; INC_TIME_PIN          EQU P1.7 ; change to correct pin later
; INC_TEMP_PIN          EQU P1.7 ; change to correct pin later
CHANGE_MENU_PIN       EQU P1.6 ; change to correct pin later
; SSR_OUTPUT_PIN        EQU P3.0 ; change to correct pin later


MENU_STATE_SOAK        EQU 0
MENU_STATE_REFLOW      EQU 1
OVEN_STATE_PREHEAT     EQU 0
OVEN_STATE_SOAK        EQU 1
OVEN_STATE_REFLOW      EQU 2

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
DSEG at 30H
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
pwm             : ds 1 ; controls output power to SSR

dseg at 0x30
Count1ms        : ds 2 ; determines the number of 1ms increments that have passed 

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
LCD_clearLine   : db '                ', 0 ; put at end to clear line

preheatMessage  : db 'Preheat', 0
soakMessage     : db 'Reflow', 0
reflowMessage   : db 'Reflow', 0

; Messages to display on LCD when in Oven Controller FSM

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 0                     ;
;---------------------------------;
Timer0_Init:
	orl CKCON, #0b00001000 ; Input for timer 0 is sysclk/1 ; performs bit masking on CKON - Clock Control ; T0M = 1, timer 0 uses the system clock directly
	mov a, TMOD
	anl a, #0xf0 ; 11110000 Clear the bits for timer 0
	orl a, #0x01 ; 00000001 Configure timer 0 as 16-timer (M1M0 = 01 -> Mode 1: 16-bit Timer/Counter)
	mov TMOD, a
	mov TH0, #high(TIMER0_RELOAD) ; 8051 works with 8 bits so the oepration T0 = TIMER0_RELOAD  (16 bits) is done by setting high byte then low byte (8x2)
	mov TL0, #low (TIMER0_RELOAD)
	; Enable the timer and interrupts
    setb ET0  ; Enable timer 0 interrupt
    setb TR0  ; Start timer 0
	ret

;---------------------------------;
; Routine to initialize the ISR   ;
; for timer 2                     ;
;---------------------------------;
Timer2_Init:
	mov T2CON, #0 ; Stop timer/counter.  Autoreload mode.
	mov TH2, #high(TIMER2_RELOAD)
	mov TL2, #low(TIMER2_RELOAD)
	; Set the reload value
	orl T2MOD, #0x80 ; Enable timer 2 autoreload
	mov RCMP2H, #high(TIMER2_RELOAD)
	mov RCMP2L, #low(TIMER2_RELOAD)
	; Init One millisecond interrupt counter.  It is a 16-bit variable made with two 8-bit parts
	clr a
	mov Count1ms+0, a
	mov Count1ms+1, a
	mov Count1ms+0 , a
	mov Count1ms+1 , a
	; Enable the timer and interrupts
	orl EIE, #0x80 ; Enable timer 2 interrupt ET2=1
    setb TR2  ; Enable timer 2
	ret

Timer0_ISR:
reti

;---------------------------------;
; ISR for timer 2                 ;
;---------------------------------;
Timer2_ISR:
        clr TF2  ; Timer 2 doesn't clear TF2 automatically. Do it in the ISR.  It is bit addressable.
        cpl P0.4 ; To check the interrupt rate with oscilloscope. It must be precisely a 1 ms pulse.

        ; The two registers used in the ISR must be saved in the stack
        push acc
        push psw

        ; Increment the 16-bit one mili second counter
        inc Count1ms+0    ; Increment the low 8-bits first
        mov a, Count1ms+0 ; If the low 8-bits overflow, then increment high 8-bits
        jnz Inc_done
        inc Count1ms+1
        
        Inc_done:
        ; Check if one second has passed
	mov	a, Count1ms+0
	cjne    a, #low(1000), Timer2_ISR_done ; Warning: this instruction changes the carry flag!
	mov     a, Count1ms+1
	cjne    a, #high(1000), Timer2_ISR_done	

        ; ---  1s has passed ----
        ; mov a, OVEN_STATE
        ; inc a
        ; mov OVEN_STATE, a
        
        Timer2_ISR_done:
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
                        
        ; Using timer 0 for delay functions.  Initialize here:
	clr	TR0         ; Stop timer 0
	orl	CKCON,#0x08 ; CLK is the input for timer 0
	anl	TMOD,#0xF0  ; Clear the configuration bits for timer 0
	orl	TMOD,#0x01  ; Timer 0 in Mode 1: 16-bit timer
	
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
        mov     a, #5
        mov     MENU_STATE, a ; set menu state to 0 

        mov     temp_soak, #0x80
        mov     time_soak, #0x60
        mov     temp_refl, #0x90
        mov     time_refl, #0x1

        ; Oven configuration
        mov OVEN_STATE, #OVEN_STATE_PREHEAT
        
        ; note that above is pasted from lab 3 - AL, need to add setup code from lab 2
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

; Push button macro - It does not work :(
Inc_Menu_Variable MAC
        jb %0, %2
        Wait_Milli_Seconds(#50) ; de-bounce
        jb %0, %2
        jnb %0, $
        ; successful press registered
        inc %1 ; increment param #1
ENDMAC

STOP_PROCESS:
; Turn everything off
        ljmp PROGRAM_ENTRY

OVEN_FSM:
        enterOvenStateCheck:
        mov a, OVEN_STATE

        ; ovenFSM_preheat:
        cjne a, #OVEN_STATE_PREHEAT, ovenFSM_soak
        Set_Cursor(1, 1)
        Send_Constant_String(#preheatMessage)
        Send_Constant_String(#LCD_clearLine)
        Set_Cursor(2, 1)
        Send_Constant_String(#LCD_clearLine)

        ovenFSM_soak:
        cjne a, #OVEN_STATE_SOAK, ovenFSM_reflow
        ; Set_Cursor(1, 1)
        ; Send_Constant_String(#preheatMessage)
        ; Send_Constant_String(#LCD_clearLine)
        ; Set_Cursor(2, 1)
        ; Send_Constant_String(#LCD_clearLine)

        ovenFSM_reflow:
        cjne a, #OVEN_STATE_REFLOW, ovenFSM_exit
        ; Set_Cursor(1, 1)
        ; Send_Constant_String(#preheatMessage)
        ; Send_Constant_String(#LCD_clearLine)
        ; Set_Cursor(2, 1)
        ; Send_Constant_String(#LCD_clearLine)

        ovenFSM_exit:
        ; mov OVEN_STATE, #OVEN_STATE_REFLOW
        ljmp OVEN_FSM

        ret

MENU_FSM:        
	jb CHANGE_MENU_PIN, enterMenuStateCheck
	Wait_Milli_Seconds(#50)	      ; debounce delay
	jb CHANGE_MENU_PIN, enterMenuStateCheck  ; 
	jnb CHANGE_MENU_PIN, $             ; wait for release

        mov a, MENU_STATE
        inc a
        mov MENU_STATE, a ; line is doubled for clarity - George
        
        enterMenuStateCheck:
        mov a, MENU_STATE

        menuFSM_configSoak:
        cjne a, #MENU_STATE_SOAK, menuFSM_configReflow
        ; State - Config Soak
        ; Inc_Menu_Variable (INC_TEMP_PIN, temp_soak, noSoakTempInc)
        ; noSoakTempInc:
        ; Inc_Menu_Variable (INC_TIME_PIN, time_soak, noSoaktimeInc)
        ; noSoaktimeInc:
        ; display Soak Menu Options
        Set_Cursor(1, 1)
        Send_Constant_String(#LCD_soakTemp)
        Display_BCD (temp_soak)
        Set_Cursor(2, 1)
        Send_Constant_String(#LCD_soakTime)
        Display_BCD (time_soak)
        Send_Constant_String(#LCD_clearLine)
        ljmp menu_FSM_done

        menuFSM_configReflow:
        cjne a, #MENU_STATE_REFLOW, reset_menu_state
        ; State - Config Reflow
        ; Inc_Menu_Variable (INC_TEMP_PIN, temp_refl, noReflowTempInc)
        ; noReflowTempInc:
        ; Inc_Menu_Variable (INC_TIME_PIN, time_refl, noReflowTimeInc)
        ; noReflowTimeInc:
        ; display Reflow Menu Options
        Set_Cursor(1, 1)
        Send_Constant_String(#LCD_reflowTemp)
        Display_BCD (temp_refl)
        Set_Cursor(2, 1)
        Send_Constant_String(#LCD_reflowTime)
        Display_BCD (time_refl)
        Send_Constant_String(#LCD_clearLine)
        ljmp menu_FSM_done


        reset_menu_state: ; sets menu state variable to 0
        mov MENU_STATE, #MENU_STATE_SOAK
        ljmp menu_FSM_done


        menu_FSM_done:
        ret

main_program:
        ; George
        mov sp, #0x7f
        lcall Initilize_All
        lcall LCD_4BIT

        ; Default display - 
        ; Reflow oven controller 
        ; (Start or Configure?)
        PROGRAM_ENTRY:
	Set_Cursor(1, 1)
        Send_Constant_String(#LCD_defaultTop)
	Set_Cursor(2, 1)
        Send_Constant_String(#LCD_defaultBot)

        checkStartButton: ; assumed negative logic - used a label for an easy ljmp in the future
        jb START_PIN, noStartButtonPress
        Wait_Milli_Seconds(#50)
        jb START_PIN, noStartButtonPress
        jnb START_PIN, $
        ljmp enter_oven_fsm ; successful button press, enter oven FSM   

        noStartButtonPress:
        ; if the 'IN_MENU' flag is set, always enter into the menu FSM, this is so that the menu FSM can always be entered
        ; creates an infinite loop that will always display menu once entered - broken if START button pressed
        jnb IN_MENU_FLAG, checkMenuButtonPress
        lcall MENU_FSM 
        ljmp checkStartButton

        checkMenuButtonPress:
        ; check for enter menu button press (reusing increment menu pin)
        jb CHANGE_MENU_PIN, noMenuButtonPress
        Wait_Milli_Seconds(#50)
        jb CHANGE_MENU_PIN, noMenuButtonPress
        jnb CHANGE_MENU_PIN, $
        setb IN_MENU_FLAG; successful button press, enter menu FSM loop ; - THIS LINE CAUSES THE BUG
        ljmp setMenuFlag ; this isn't executing...
        
        noMenuButtonPress:
        ljmp checkStartButton ; this line does not execute if ljmp setMenuFlag is there?!?!?

        enter_oven_fsm:
        clr IN_MENU_FLAG ; No longer in menu
        setb IN_OVEN_FLAG
        ; lcall Timer2_Init
        lcall OVEN_FSM ; will call STOP_PROCESS which loops back to the entry point
        lcall STOP_PROCESS ; added for safety
        
        setMenuFlag:
        setb IN_MENU_FLAG
        ljmp checkStartButton

        program_end:
        ljmp main_program
END