import time
import serial
import numpy as np
import sys, time, math
# configure the serial port
ser = serial.Serial(
    port='COM10',
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_TWO,
    bytesize=serial.EIGHTBITS
)
ser.isOpen()

vdata = []
avgdata = []
tempdata = []
i = 0
win_size = 100
ambtemp = 22

while 1 :
    strin = ser.readline()
    val = float(strin[0:8])
    val1 = val*326/98500.0*0.99+0.00004
    vdata.append(val1)
    if(len(vdata) > win_size):
        average = np.sum(vdata[i:i+win_size])/win_size
        avgdata.append(average)
        temp = average/(41 * 0.000001)+ambtemp 
        tempdata.append(temp)
        if (i%10==0):
            print(tempdata[i])
        i += 1


    #print(strin)
    #print(f'{strin} -> {val1}')