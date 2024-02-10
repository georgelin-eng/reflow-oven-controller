#!/usr/bin/python
import tkinter
from tkinter import *
import time
import serial
import serial.tools.list_ports
import sys
import numpy as np
import pandas as pd
import kconvert


serc = serial.Serial(
    port='COM10',
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_TWO,
    bytesize=serial.EIGHTBITS
)
serc.isOpen()

serm = serial.Serial('COM8', 9600, timeout=0.5)

ambtemp = 0
winsize = 10
multdata, micdata, avgmicdata = [], [], []
for i in range(5):
    micdata.append(22.9756)
j = 0
button = 0
ambset = 0

#ATTENTION: Make sure the multimeter is configured at 9600 baud, 8-bits, parity none, 1 stop bit, echo Off

def update_amb_temp():
    strinc = serc.readline()
    valc2 = float(strinc[10:19])

    global ambtemp
    ambtemp = valc2*100-273.15
    print(ambtemp)

def update_cont_temp(i,j):
    # read from microcontroller and append to micdata
    strinc = serc.readline()
    
    valc = float(strinc[0:10])
    valc2 = float(strinc[10:19])

    global ambtemp
    ambtemp = valc2*100-273.15
    #ambtemp = 22

    #print(ambtemp)
    #print(f'{strinc} = {valc} + {valc2}')
    val1 = valc*327.5/98500.0+valc**2*0.00001+valc**3*0.00000+0.00003 #this is how we scale using opamp factor
                                        #and some extra scaling to make temp reading more accurate
    #print(valc)
    mictemp = val1/(41*0.000001) + ambtemp
    micdata.append(mictemp)
    if (i == winsize-1):
        avgtemp = np.sum(micdata[winsize*j:winsize*(j+1)])/winsize
        avgmicdata.append(avgtemp)
        print(f'microcontroller: {avgtemp}')


def update_mult_temp():
    # read from multimeter and append to multdata
    strinm = serm.readline() # Read the requested value, for example "+0.234E-3 VDC"
    strinm = strinm.rstrip()
    strinm = strinm.decode()
    #print(strinm)
    serm.readline() # Read and discard the prompt "=>"
    if len(strinm)>1:
        if strinm[1]=='>': # Out of sync?
            strinm = serm.readline() # Read the value again
    serm.write(b"MEAS1?\r\n") # Request next value from multimeter

    strinm_clean = strinm.replace("VDC","") # get rid of the units as the 'float()' function doesn't like it

    valm=float(strinm_clean)*1000.0 # Convert from volts to millivolts

    cj=ambtemp # Read the cold junction temperature in degrees centigrade

    ktemp=round(kconvert.mV_to_C(valm, cj),1)
    print(f'multimeter: {ktemp}')
    if ktemp > -200 and ktemp < 1372:
        multdata.append(ktemp)

def exit_handler():
    print(len(avgmicdata))
    print(len(multdata))
    df = pd.DataFrame(
        {
            "Multimeter Data" : multdata,
            "Microcontroller" : avgmicdata,
        }
    )
    df.to_excel("Proj1.xlsx")
    print('done!')
    sys.exit()

def set_button():
    global button
    button = 1


def set_ambtemp():
    global ambset
    ambset = 1


top = tkinter.Tk()

setB = tkinter.Button(top, text = f"Set ambient temp to {ambtemp}", command = set_ambtemp)
setB.pack()

while ambset == 0:
    top.update()
    update_amb_temp()
    setB.config(text=f"Set ambient temp to {ambtemp}")



serm.write(b"\x03") # Request prompt from possible multimeter
pstring = serm.readline() # Read the prompt "=>"
pstring=pstring.rstrip()
pstring=pstring.decode()
# print(pstring)
if len(pstring) > 1:
   if pstring[1]=='>':
        serm.timeout=3  # Three seconds timeout to receive data should be enough
        serm.write(b"VDC; RATE S; *IDN?\r\n") # Measure DC voltage, set scan rate to 'Slow' for max resolution, get multimeter ID
        serm.readline()
        serm.readline() # Read and discard the prompt "=>"
        serm.write(b"MEAS1?\r\n") # Request first value from multimeter

setB.destroy()
B = tkinter.Button(top, text="End Program", command = set_button)
B.pack()


while 1:
    top.update()
    for i in range(winsize):
        update_cont_temp(i,j)
    update_mult_temp()
    j+=1
    if (button == 1):
        exit_handler()


