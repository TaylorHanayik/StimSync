import serial
ser = serial.Serial('/dev/tty.usbmodem7071', 115200, timeout=1)
ser.write("\xb1\x81\x01A") #set key-press 1st button = 'A' 177,129,1,'A'
ser.write("\xb1\x81\x02a") #set key-press 2nd button = 'a' 177,129,1,'a'
ser.write("\xb1\x82\x011") #set key-release 1st button ='1' 177,130,1,'a'
ser.write("\xb1\x82\x02\x00") #set key-release 2nd button = none 177,130,1,0
ser.write("\xb1\x81\x00\x7b") #set de-bounce time to 123ms 177,129,0,123
ser.write("\xb1\x86\x86\x86") #set EEPROM to store mapping 177,134,134,134
ser.close()

