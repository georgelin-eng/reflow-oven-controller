# combined code in instructions for setting up serial port and from printing sinewave
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, math
import time #already added
import serial
import re 

#one ms for every increment of x, reflects 1 ms counter in t2 in ovencontroller FSM
xsize=250 #remain cognizant of delays from division


# configure the serial port
ser = serial.Serial(
    port='/dev/cu.usbserial-D30HKNUK', #change to whichever serial port we end up using (e.g. COM5)
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_TWO,
    bytesize=serial.EIGHTBITS
)
ser.isOpen()
   
def data_gen():
    global line
    t = data_gen.t
    while 1:
        strin = ser.readline()# Get data from serial port
        strin = strin.rstrip() # Remove trailing characters from the string
        strin = strin.decode() # Change string encoding to utf-8 (compatible with ASCII)
        
   
        try:
            temperature = float(strin) # store only temp vals since we will sync time with the serial monitor o
            
        except:
            print("***ERROR: Unable to receive string***") # Something wrong with the received string
        
        t+=1
        yield t, temperature


def run(data):
    # update the data
    t, temperature = data
    if t>-1:
        xdata.append(t)
        temp_data.append(temperature) 
        
        if t>xsize: # Scroll to the left.
            ax.set_xlim(t-xsize, t)
        line_temp.set_data(xdata, temp_data)

    return line_temp

def on_close_figure(event):
    sys.exit(0)

data_gen.t = -1
fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
# creates an empty plot
line_temp, = ax.plot([],[],lw=2,color = 'pink', linestyle='dashed', label = 'Temperature, degrees C')

ax.legend ()

ax.set_ylim(0, 350) #define range of graph
ax.set_xlim(0, xsize)

xdata, temp_data = [], [] # Set font for the graph
font1 = {'fontname':'Times New Roman','color':'blue','size':20}
plt.title("Temperature over time", fontdict = font1)
plt.xlabel("Time", fontdict=font1)
plt.ylabel("Temperature", fontdict=font1)

# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
# animation for data_gen
ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False, cache_frame_data=False)
# animation for farenheit
# animation for kelvins
plt.show()
