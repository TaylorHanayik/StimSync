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

from psychopy import visual, core #import some libraries from PsychoPy
ser = open_arduino_port() #open the StimSync
#stimuli
mywin = visual.Window([800,600],fullscr="false",monitor="testMonitor", units="deg")
mywin.setMouseVisible(False)
#create some stimuli
dark = visual.PatchStim(win=mywin, size=1, pos=[0,0], sf=0, color=-1)
bright = visual.PatchStim(win=mywin, size=1, pos=[0,0], sf=0, color=1)
#show the trials
for x in range(0, 5):
 bright.draw()
 mywin.flip()
 ser.write("\x7f")
 ser.flush()
 dark.draw()
 mywin.flip()
 ser.write("\x00")
 core.wait(1.0)

#close the serial port when the study is over
ser.close