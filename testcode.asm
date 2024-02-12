; Send a character using the serial port
putchar:
        jnb     TI, putchar
        clr     TI
        mov     SBUF, a
        ret


send_temp_to_serial:
        SendToSerialPort(x+3) ;four times bc there are 4x2 bits
        SendToSerialPort(x+2)
        SendToSerialPort(x+1)
        SendToSerialPort(x+0)
        ret 

;---------------------------------;
; Send a BCD number to PuTTY      ;
;---------------------------------;
SendToSerialPort mac
	push    ar0
	mov     r0, %0
	lcall   ?Send_BCD
	pop     ar0
	endmac
	?SendToSerialPort:
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


