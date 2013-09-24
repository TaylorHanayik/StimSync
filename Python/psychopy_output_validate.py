import os, serial
from serial.tools import list_ports
def open_arduino_port():
 available = []
 if os.name == 'nt': # Windows
  for i in range(256):
   try:
    s = serial.Serial(i)
    available.append('COM'+str(i + 1))
    s.close()
   except serial.SerialException:
    pass
  if len(possible) < 1:
   print 'Error: unable to find Arduino: no COM ports detected. Check drivers.'
   return []
  print 'Possible list of available serial ports:'
  print available
 else: # Mac / Linux
  available = [port[0] for port in list_ports.comports()]
  print 'Possible list of available serial ports:'
  print available
  available = [s for s in available if ".us" in s]
  if len(available) < 1:
   print 'Error: unable to find Arduino port named ".us": check drivers'
 print 'assuming Arduino attached to port %s' %(available[0])
 serPort = serial.Serial(available[0], 115200, timeout=1)
 serPort.write("\xb1\xa3\xa9\xa9") #set to keyboard mode 177,163,169,169
 serPort.flushInput()
 serPort.write("\xa9\xa3\xa9\xa9") #get current mode 169,163,169,169 we expect the reply 169,163,169,169
 serPort.flush() #send command
 obs = serPort.read(4)
 if obs != "\xa9\xa3\xa9\xa9" :
  print 'Warning: the selected port does not have a StimSync attached'
 return serPort

def digitalWrite(myPort, myVal):
 myPort.write(myVal)
 myPort.flush()

from psychopy import visual, core #import some libraries from PsychoPy
#open the StimSync
nReps = 10 #number of repititions
ser = open_arduino_port()
ser.write("\xb1\xa3\xb5\xb5") #set usec mode 177,163,181,181
ser.flush()
ser.flushInput()
inData = ''
digitalWrite(ser, "\x00") #turn off all digital outputs
#create window and stimuli
mywin = visual.Window([800,600],fullscr="false",monitor="testMonitor", units="norm",color=-1)
mywin.setMouseVisible(False)
dark = visual.PatchStim(win=mywin, size=1, pos=[0,0], sf=0, rgb=-1)
bright = visual.PatchStim(win=mywin, size=1, pos=[-0.5,0.5], sf=0, rgb=1)
for x in range(0, nReps): #show the trials
 core.wait(0.5)
 bright.draw()
 mywin.callOnFlip(digitalWrite, ser, "\x7f") #all on
 mywin.flip()
 dark.draw()
 mywin.callOnFlip(digitalWrite, ser, "\x00") #all off
 mywin.flip()
 core.wait(0.5)
 inBytes = ser.inWaiting()
 if inBytes > 0:
  inData = inData + ser.read(inBytes)

print len(inData)
if len(inData) > 8:
 obsBin = [ord(c) for c in inData]
 nEvents = len(inData) // 8
 for i in range(0, nEvents):
  o = i * 8
  usec = (obsBin[o+3] << 24)+ (obsBin[o+4] << 16)+ (obsBin[o+5] << 8)+obsBin[o+6]
  keys = (obsBin[o+1] << 8)+obsBin[o+2]
  print 'keycode\t%d\tat\t%d\tusec' % (keys, usec)

ser.write("\xb1\xa3\xa9\xa9") #turn off oscilloscope: set keyboard mode 177,163,169,169
ser.close #close the serial port when the study is over