#see http://forum.cogsci.nl/index.php?p=/discussion/454/solved-sending-triggers-to-nexus-trigger-interface-via-serial-port/p1
import serial
exp.serial_port = serial.Serial('/dev/tty.usbmodem7071', 115200, timeout=1) # For Windows, something like 'COM1'
#And then send a trigger like this (at some moment during a trial):
exp.serial_port.write("\x7f") # Send decimal 127 (hex 7f) to turn on all outputs
exp.serial_port.flush()
#At the end of the experiment, you need to close the connection </font>
exp.serial_port.close()