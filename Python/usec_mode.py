import serial
ser = serial.Serial('/dev/tty.usbmodem7071', 115200, timeout=10)
ser.write("\xb1\xa3\xb5\xb5") #set usec mode 177,163,181,181
ser.flush()
ser.flushInput()
obs = ser.read(8)
if len(obs) != 8:
    print('Error: no buttons presses detected')

print 'Observed data (as hex): '+ obs.encode('hex')
obsBin = [ord(c) for c in obs]
usec = (obsBin[3] << 24)+ (obsBin[4] << 16)+ (obsBin[5] << 8)+obsBin[6]
keys = (obsBin[1] << 8)+obsBin[2]
print 'keys pressed %d at %d usec' % (keys, usec)
ser.write("\xb1\xa3\xa9\xa9") #turn off oscilloscope: set keyboard mode 177,163,169,169
ser.close()