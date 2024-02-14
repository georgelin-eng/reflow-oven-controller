# combined code in instructions for setting up serial port and from printing sinewave
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.animation as animation
import sys, time, math
import time #already added
import serial
#import re 
#import pygame 
#from tkinter import *
#from PIL import ImageTk, Image
#import tkinter.messagebox as messagebox
# 
## Initialize the pygame mixer 
#pygame.mixer.init() 
#airhorn_file = "C:\\Users\\maya2\\Desktop\\291pythonproj\\airhorn.mp3"
#airhorn = pygame.mixer.Sound(airhorn_file)  
#airhorn.play()
#
#def play_question():
#
#    win = Tk() #initializing window 
#    win.geometry("700x500")
#
#    # Load and display the image
#    img = Image.open("linares.png")
#    img = img.resize((200, 350))
#    img = ImageTk.PhotoImage(img)
#    image_label = Label(win, image=img)
#    image_label.pack()
#
#    # Create a Label Widget to display the text
#    l = Label(win, text="Hello my student... \n Please prepare to reflow your first board")
#    l.config(font=("Courier", 14))
#    l.pack()
#
#    # Play the sound
#    #airhorn_file = "C:\\Users\\maya2\\Desktop\\291pythonproj\\airhorn.mp3"
#    #airhorn = pygame.mixer.Sound(airhorn_file)  
#    #airhorn.play()
#
#    labrules_file = "C:\\Users\\maya2\\Desktop\\291pythonproj\\labrules.mp3" 
#    labrules = pygame.mixer.Sound(labrules_file)  
#
#    win.after(int(airhorn.get_length() * 2000), lambda: win.destroy()) # Destroy window after sound finishes
#    win.mainloop()
#
#    # After window closes, prompt user with a yes/no question
#    response = messagebox.askyesno("Question", "Will you follow all lab safety procedures?")
#
#    if not response: # If yes, replay the question
#        labrules.play()
#        pygame.time.wait(int(labrules.get_length() * 1000)) 
#        play_question()  
#    else: # If no, exit the function
#        return
#
#play_question()
#pygame.init()
#one ms for every increment of x, reflects 1 ms counter in t2 in ovencontroller FSM
xsize=250 #remain cognizant of delays from division

soaktime = 15
soaktemp = 80
refltime = 15
refltemp = 110

#soakpos = -1
soakflag = 0 #so we only set the flag once
p2sflag = 0
reflflag = 0
coolflag = 0
safeflag = 0

soakstart = 100000 #marks the time sin
reflstart = 100000 #marks the time since we started rreflow
#p2spos = -1
#reflpos = -1
#coolpos = -1

ser = serial.Serial(
    port='COM6', #change to whichever serial port we end up using (e.g. COM5)
    baudrate=115200,
    parity=serial.PARITY_NONE,
    stopbits=serial.STOPBITS_TWO,
    bytesize=serial.EIGHTBITS
)
ser.isOpen()    
   
def data_gen():
    #global line
    global soaktime, soaktemp, refltime, refltemp
    t = data_gen.t
    while 1:
        strin = ser.readline()# Get data from serial port
        strin = strin.rstrip() # Remove trailing characters from the string
        print(strin)
        strin = strin.decode() # Change string encoding to utf-8 (compatible with ASCII)
        
        
        try:
            #temperature = float(strin) # store only temp vals since we will sync time with the serial monitor o
            temperature = float(strin[0:9])
            soaktime    = float(strin[9:12])
            soaktemp    = float(strin[12:15])
            refltime    = float(strin[15:18])
            refltemp    = float(strin[18:21])

            
        except:
            print("***ERROR: Unable to receive string***") # Something wrong with the received string
        
        t+=1
        yield t, temperature


def run(data):
    # update the data
    global soakstart, reflstart, soakflag, p2sflag, reflflag, coolflag, safeflag
    t, temperature = data
    if t>-1:
        xdata.append(t)
        temp_data.append(temperature) 
        
        if t>xsize: # Scroll to the left.
            ax.set_xlim(t-xsize, t)

        line_temp.set_data(xdata, temp_data)
        
        l1.get_texts()[0].set_text(f"Temp = {round(temperature,2)} °C \n        = {round((temperature * 9/5 + 35),2)} °F")

        
        if temperature>=soaktemp and soakflag != 1:
            soakstart = t
            vlsoak.set_xdata(soakstart)
            soakflag = 1

        if soakflag == 1 and t-soakstart >= soaktime and p2sflag != 1:
            vlp2s.set_xdata(t)
            p2sflag = 1

        if p2sflag == 1 and temperature >= refltemp and reflflag != 1:
            reflstart = t
            vlrefl.set_xdata(reflstart)
            reflflag = 1

        if reflflag == 1 and t-reflstart >= refltime and coolflag !=1:
            vlcool.set_xdata(t)
            coolflag = 1

        if coolflag == 1 and temperature <= 50 and safeflag != 1:
            vlsafe.set_xdata(t)
            safeflag = 1

    return line_temp

def on_close_figure(event):
    sys.exit(0)

data_gen.t = -1
fig = plt.figure()
fig.canvas.mpl_connect('close_event', on_close_figure)
ax = fig.add_subplot(111)
# creates an empty plot
line_temp, = ax.plot([],[],lw=2,color = 'pink', label = 'Temperature, degrees C')

l1 = ax.legend()

ax.set_ylim(0, 250) #define range of graph
ax.set_xlim(0, xsize)

xdata, temp_data = [], [] # Set font for the graph
font1 = {'fontname':'Times New Roman','color':'black','size':20}
plt.title("Temperature over time", fontdict = font1)
plt.xlabel("Time", fontdict=font1)
plt.ylabel("Temperature", fontdict=font1)
vlsoak = plt.axvline(x = -1, color='g')
vlp2s = plt.axvline(x = -1, color='y')
vlrefl = plt.axvline(x = -1, color='r')
vlcool = plt.axvline(x = -1, color='b')
vlsafe = plt.axvline(x=-1, color='m')


# Important: Although blit=True makes graphing faster, we need blit=False to prevent
# spurious lines to appear when resizing the stripchart.
# animation for data_gen
ani = animation.FuncAnimation(fig, run, data_gen, blit=False, interval=100, repeat=False, cache_frame_data=False)
# animation for farenheit
# animation for kelvins
plt.show()
