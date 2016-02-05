# -*- coding: utf-8 -*-
import serial, platform
from serial.tools import list_ports

OperatingSystem = platform.system()

def cmdString(a,b,c,d):
    # ret = chr(a) + chr(b) + chr(c) + chr(d)
    ret = bytearray([a,b,c,d])
    return ret

def open_arduino_port():
    available = []
    if OperatingSystem == 'Windows': # Windows
        for i in range(256):
            try:
                s = serial.Serial(i)
                available.append('COM'+str(i + 1))
                s.close()
            except serial.SerialException:
                pass
        if len(available) < 1:
            print 'Error: unable to find Arduino: no COM ports detected. Check drivers.'
            return []
        print 'Possible list of available serial ports:'
        print available
    else: # Mac / Linux
        available = [port[0] for port in list_ports.comports()]
        print 'Possible list of available serial ports:'
        print available
        available = [s for s in available if ".us" in s or "USB" in s or "ACM" in s]
        if len(available) < 1:
            print 'Error: unable to find Arduino port named ".us": check drivers'
    print 'assuming Arduino attached to port %s' %(available[0])
    serPort = serial.Serial(available[0], 115200, timeout=1)
    serPort.flushInput()
    serPort.write(cmdString(177, 163, 169, 169)) #set to keyboard mode 177,163,169,169
    serPort.flush()
    serPort.write(cmdString(169,163,169,169)) #get current mode 169,163,169,169 we expect the reply 169,163,169,169
    serPort.flush() #send command
    obs = serPort.read(4)
    if obs != cmdString(169,163,169,169) :
        print 'Warning: the selected port does not have a StimSync attached'
    return serPort

def digitalWrite(myPort, myVal):
    myPort.write(myVal)
    myPort.flush()

from psychopy import visual, core #import some libraries from PsychoPy
#open the StimSync
nReps = 10 #number of repititions
ser = open_arduino_port()
ser.write(cmdString(177,163,181,181)) #set usec mode 177,163,181,181
ser.flush()
ser.flushInput()
inData = ''
digitalWrite(ser, chr(0)) #turn off all digital outputs
#create window and stimuli
#mywin = visual.Window([1024,768], allowGUI=True, fullscr=False, waitBlanking=True, monitor='testMonitor', color='black', units='deg')
mywin = visual.Window([800,600],fullscr=False,monitor="testMonitor", units="norm",color=-1)
mywin.setMouseVisible(False)
dark = visual.PatchStim(win=mywin, size=1, pos=[0,0], sf=0, rgb=-1)
bright = visual.PatchStim(win=mywin, size=1, pos=[-0.5,0.5], sf=0, rgb=1)
for x in range(0, nReps): #show the trials
    core.wait(0.5)
    bright.draw()
    mywin.callOnFlip(digitalWrite, ser, chr(127)) #all on
    mywin.flip()
    core.wait(0.5)
    digitalWrite(ser, chr(1))
    digitalWrite(ser, chr(2))
    dark.draw()
    mywin.callOnFlip(digitalWrite, ser, chr(0)) #all off
    mywin.flip()
    core.wait(0.5)
    inBytes = ser.inWaiting()
    if inBytes > 0:
        inData = inData + ser.read(inBytes)

print len(inData)
useclist = []
if len(inData) > 8:
    obsBin = [ord(c) for c in inData]
    nEvents = len(inData) // 8
    for i in range(0, nEvents):
        o = i * 8
        usec = (obsBin[o+3] << 24)+ (obsBin[o+4] << 16)+ (obsBin[o+5] << 8)+obsBin[o+6]
        keys = (obsBin[o+1] << 8)+obsBin[o+2]
        print '%2d: keycode\t%d\tat\t%d\tusec' % (i, keys, usec)
        useclist.append([keys, usec])

oldusec = 0
i = 1
for u in useclist:
    d = u[1]-oldusec
    k = u[0]
    print "%2d Key: %6d, Diff: %d" % (i,k,d)
    oldusec = u[1]
    i += 1

ser.write(cmdString(177,163,169,169)) #turn off oscilloscope: set keyboard mode 177,163,169,169
ser.close #close the serial port when the study is over