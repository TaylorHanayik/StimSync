import serial
ser = serial.Serial('/dev/tty.usbmodem7071', 115200, timeout=1)
ser.write("\xb1\x84\x00\x7d") #set oscilloscope for 125Hz sampling rate 177,132,0,125
ser.write("\xb1\x85\x00\x01")  #set oscilloscope for 2 channels 177,133,0,2
ser.write("\xb1\xa3\xa2\xa2") #set oscilloscope mode 177,163,162,162
obs = ser.read(8)
if len(obs) != 8:
    print('Error: did not receive data')

print 'Observed data (as hex): '+ obs.encode('hex')
obsBin = [ord(c) for c in obs]
ch1 = (obsBin[3] << 8)+obsBin[4]
ch2 = (obsBin[5] << 8)+obsBin[6]
print 'Channel 1: %d Channel 2: %d' % (ch1, ch2)
ser.write("\xb1\xa3\xa9\xa9") #turn off oscilloscope: set keyboard mode 177,163,169,169
ser.close()

