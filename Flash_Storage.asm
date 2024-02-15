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
;

CLK           EQU 16600000 ; Microcontroller system oscillator frequency in Hz
BAUD          EQU 115200 ; Baud rate of UART in bps
TIMER1_RELOAD EQU (0x100-(CLK/(16*BAUD)))

org 0000H
   ljmp MyProgram

DSEG at 0x30
variable_1: ds 1
variable_2: ds 1
variable_3: ds 1
variable_4: ds 1

CSEG

Init_All:
	; Configure all the pins for biderectional I/O
	mov	P3M1, #0x00
	mov	P3M2, #0x00
	mov	P1M1, #0x00
	mov	P1M2, #0x00
	mov	P0M1, #0x00
	mov	P0M2, #0x00
	
	orl	CKCON, #0x10 ; CLK is the input for timer 1
	orl	PCON, #0x80 ; Bit SMOD=1, double baud rate
	mov	SCON, #0x52
	anl	T3CON, #0b11011111
	anl	TMOD, #0x0F ; Clear the configuration bits for timer 1
	orl	TMOD, #0x20 ; Timer 1 Mode 2
	mov	TH1, #TIMER1_RELOAD ; TH1=TIMER1_RELOAD;
	setb TR1
	
	ret

putchar:
    JNB TI, putchar
    CLR TI
    MOV SBUF, a
    RET

SendString:
    CLR A
    MOVC A, @A+DPTR
    JZ SSDone
    LCALL putchar
    INC DPTR
    SJMP SendString
SSDone:
    ret

; Sends the byte in the accumulator to the serial port in decimal 
Send_byte:
	mov b, #100
	div ab
	orl a, #'0'
	lcall putchar
	mov a, b
	mov b, #10
	div ab
	orl a, #'0'
	lcall putchar
	mov a, b
	orl a, #'0'
	lcall putchar
	mov a, #'\r'
	lcall putchar
	mov a, #'\n'
	lcall putchar
	ret

;******************************************************************************
; This code illustrates how to use IAP to make APROM 3f80h as a byte of
; Data Flash when user code is executed in APROM.
; (The base of this code is listed in the N76E003 user manual)
;******************************************************************************
PAGE_ERASE_AP   EQU 00100010b
BYTE_PROGRAM_AP EQU 00100001b

Save_Variables:
	CLR EA  ; MUST disable interrupts for this to work!
	
	MOV TA, #0aah ; CHPCON is TA protected
	MOV TA, #55h
	ORL CHPCON, #00000001b ; IAPEN = 1, enable IAP mode
	
	MOV TA, #0aah ; IAPUEN is TA protected
	MOV TA, #55h
	ORL IAPUEN, #00000001b ; APUEN = 1, enable APROM update
	
	MOV IAPCN, #PAGE_ERASE_AP ; Erase page 3f80h~3f7Fh
	MOV IAPAH, #3fh
	MOV IAPAL, #80h
	MOV IAPFD, #0FFh
	MOV TA, #0aah ; IAPTRG is TA protected
	MOV TA, #55h
	ORL IAPTRG, #00000001b ; write ‘1’ to IAPGO to trigger IAP process
	
	MOV IAPCN, #BYTE_PROGRAM_AP
	MOV IAPAH, #3fh
	
	;Load 3f80h with variable_1
	MOV IAPAL, #80h
	MOV IAPFD, variable_1
	MOV TA, #0aah
	MOV TA, #55h
	ORL IAPTRG,#00000001b
	
	;Load 3f81h with variable_2
	MOV IAPAL, #81h
	MOV IAPFD, variable_2
	MOV TA, #0aah
	MOV TA, #55h
	ORL IAPTRG,#00000001b
	
	;Load 3f82h with variable_3
	MOV IAPAL, #82h
	MOV IAPFD, variable_3
	MOV TA, #0aah
	MOV TA, #55h
	ORL IAPTRG,#00000001b
	
	;Load 3f83h with variable_4
	MOV IAPAL, #83h
	MOV IAPFD, variable_4
	MOV TA, #0aah
	MOV TA, #55h
	ORL IAPTRG,#00000001b

	;Load 3f84h with 55h
	MOV IAPAL,#84h
	MOV IAPFD, #55h
	MOV TA, #0aah
	MOV TA, #55h
	ORL IAPTRG, #00000001b

	;Load 3f85h with aah
	MOV IAPAL, #85h
	MOV IAPFD, #0aah
	MOV TA, #0aah
	MOV TA, #55h
	ORL IAPTRG, #00000001b

	MOV TA, #0aah
	MOV TA, #55h
	ANL IAPUEN, #11111110b ; APUEN = 0, disable APROM update
	MOV TA, #0aah
	MOV TA, #55h
	ANL CHPCON, #11111110b ; IAPEN = 0, disable IAP mode
	
	setb EA  ; Re-enable interrupts

	ret

Load_Variables:
	mov dptr, #0x3f84  ; First key value location.  Must be 0x55
	clr a
	movc a, @a+dptr
	cjne a, #0x55, Load_Defaults
	inc dptr      ; Second key value location.  Must be 0xaa
	clr a
	movc a, @a+dptr
	cjne a, #0xaa, Load_Defaults
	
	mov dptr, #0x3f80
	clr a
	movc a, @a+dptr
	mov variable_1, a
	
	inc dptr
	clr a
	movc a, @a+dptr
	mov variable_2, a
	
	inc dptr
	clr a
	movc a, @a+dptr
	mov variable_3, a
	
	inc dptr
	clr a
	movc a, @a+dptr
	mov variable_4, a
	ret

Load_Defaults:
	mov variable_1, #1
	mov variable_2, #2
	mov variable_3, #3
	mov variable_4, #4
	ret

msg0: db '\r\nThis program illustrates how to use flash memory for\r\n'
      db 'non-volatile storage of variables.\r\n'
      db 'After each power-on or reset, the variables are loaded from\r\n'
      db 'flash memory, incremented, and the new values are stored back\r\n'
      db 'into flash memory.\r\n\r\n',0
msg1:
	  DB 'variable_', 0

Display_Variables:
	mov dptr, #msg1
	lcall SendString
	mov a, #'1'
	lcall putchar
	mov a, #'='
	lcall putchar
	mov a, variable_1
	lcall Send_byte

	mov dptr, #msg1
	lcall SendString
	mov a, #'2'
	lcall putchar
	mov a, #'='
	lcall putchar
	mov a, variable_2
	lcall Send_byte

	mov dptr, #msg1
	lcall SendString
	mov a, #'3'
	lcall putchar
	mov a, #'='
	lcall putchar
	mov a, variable_3
	lcall Send_byte

	mov dptr, #msg1
	lcall SendString
	mov a, #'4'
	lcall putchar
	mov a, #'='
	lcall putchar
	mov a, variable_4
	lcall Send_byte

	ret
	
MyProgram:
	mov sp, #07FH
	lcall INIT_ALL
	
	mov dptr, #msg0
	lcall SendString
	
	lcall Load_Variables ; Get the old variable values stored in flash memory
	inc variable_1
	inc variable_2
	inc variable_3
	inc variable_4
	lcall Display_Variables
	lcall Save_Variables ; Save the new values into flash memory

Forever:
	ljmp Forever
	
END
