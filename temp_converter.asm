; This file converts temperature from voltage to celsius



; hannah y
; conversion based on led calibration

;process analog inputs

;assume that value was already read and stored into x
mov x+0, R0
mov x+1, R1

; pad other bits:
mov x+2, #0
mov x+3, #0 
mov x+4, #0 ; use more bits because we need to read up to 240 deg. cels

load_y([ledvoltage]) ;measured led voltaeg
lcall mul32

;read led value
;mov y+0, [led_adc+0]
;mov y+1, [led_adc+1]

; pad bits:
mov y+2, #0
mov y+3, #0
mov y+4, #0
lcall 32

; voltage to celsius conversion:
load_y(27300)
lcall sub32
load_y(100)
lcall mul32





