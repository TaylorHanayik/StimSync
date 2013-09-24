import serial
ser = serial.Serial('/dev/tty.usbmodem7071', 115200, timeout=1)
ser.write("\x0b") #send 11 decimal: turn on outputs 1,2,4; hex 0B = decimal 11
ser.flush() #send data immediately
ser.close()