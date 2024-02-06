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

; Include Macros
$include(math32.inc)
$include(LCD_4bit.inc)

; Timer constants
CLK                             EQU 16600000 ; Microcontroller system frequency in Hz
BAUD                            EQU 115200   ; Baud rate of UART in bps 
TIMER1_RELOAD                   EQU (0x100-(CLK/(16*BAUD))) ; ISR that's used for serial???
TIMER2_RELOAD                   EQU (0x10000-(CLK/1000))    ; For ISR that runs every 1ms
TIMER0_RELOAD_1MS EQU (0x10000-(CLK/1000)) ; for delay functions

; Pin definitions + Hardware Wiring
CHANGE_MENU_DISPLAYED_PIN       EQU P1.7
SSR_OUTPUT_PIN                  EQU P3.0


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
ORG 0x0023 ; Serial port receive/transmit interrupt vector (
	reti
ORG 0x002B ; Timer/Counter 2 overflow interrupt vector
	ljmp Timer2_ISR




; register definitions previously needed by 'math32.inc' - currently commented out for future changes
DSEG at 30H
;x:   ds 4
;y:   ds 4
;bcd: ds 5
;bcdf: ds 5
;VLED_ADC: ds 2


; Flags that are used to control events 
BSEG 
; mf   				: dbit 1
IN_MENU         : dbit 1


CSEG ;starts the absolute segment from that address
        
Initilize_All:
        ; Configure pins to be bi-directional
        mov	P3M1,#0x00
	mov	P3M2,#0x00
	mov	P1M1,#0x00
	mov	P1M2,#0x00
	mov	P0M1,#0x00
	mov	P0M2,#0x00

        ; Since the reset button bounces, we need to wait a bit before
        ; sending messages, otherwise we risk displaying gibberish!
        Wait_Milli_Seconds(#50)

        ; Now we can proceed with the configuration of the serial port
        orl	CKCON, #0x10 ; CLK is the input for timer 1
        orl	PCON, #0x80 ; Bit SMOD=1, double baud rate
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
        
        ;pseudo code lol
        jb [button], [branch]
        Wait_Milli_Seconds(#50)
        jb [button], [branch]
        jnb [button], $
        ljmp [display??]



main_program:
        


        ljmp main_program

END