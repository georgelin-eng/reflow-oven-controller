; blinky_EFM8.asm 

$MODEFM8LB1

CSEG at 0H
ljmp main
Wait_half_second:
;For a 6MHz clock one machine cycle takes 1/6.0000MHz=166.666ns
mov R2, #25
L3: mov R1, #250
L2: mov R0, #120
L1: djnz R0, L1 ; 4 machine cycles-> 4*166.666ns*120=80us
djnz R1, L2 ; 80us*250=0.02s
djnz R2, L3 ; 0.02s*25=0.5s
ret
main:
; DISABLE WDT: provide Watchdog disable keys
mov WDTCN, #0xDE ; First key
mov WDTCN, #0xAD ; Second key
mov SP, #7FH
; Enable crossbar and weak pull-ups
mov XBR0, #0x00
mov XBR1, #0x00
mov XBR2, #0x40
mov P2MDOUT, #0x02 ; make LED pin (P2.1) output push-pull
M0: cpl P2.1 ; Led off/on
lcall Wait_half_second
sjmp M0
end