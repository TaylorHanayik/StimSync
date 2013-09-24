You can control digital inputs (buttons) and outputs using an Arduino running the stimsyncArd sketch. The buttons should be easy to use - the Arduino will appear as a normal USB keyboard. You can set up the keyboard mapping (e.g. which button mimics which keyboard press) using the keymapLaz project. You only have to setup the key mapping once with keymapLaz and then choose "Write men" - the key mappings will be remembered.

SerDeviceIndex and SerDOut allow the user to control digital outputs from Matlab. You need a Teensy/Arduino with the stimsyncArd Sketch installed. The digital outputs are on the following pins:
  Arduino Leonardo: pins 10,11,12 corresponding to values 1,2,4 
  Teensy 2.0: pins 10,12,13,14,15 corresponding to values 1,2,4,8,16
  Teensy 3.0: pins 10,11,12,20,21,22,23 corresponding to values 1,2,4,8,16,32,64
For example, connect a light emitting diode so the anode is connected to pin 10 (value 1) and the cathode is connected to a 220 Ohm resistor that connects to ground. Writing any odd number to the device switches this light on, writing any even number switches the light off. You can use a relay (e.g. solid state AQZ207) to switch larger currents.

Here is a sample script
  s1 = SerDeviceIndex;
  SerDOut(s1,1,127);
  h=helpdlg('all serial port outputs should be on');
  uiwait(h);
  SerDOut(s1,1,0);
  disp('all serial port outputs should be off');
  fclose(s1);

This only works if the Arduino is in its default keyboard state (internal light on steady). If you are using the device as an oscilloscope or microsecond timer (in both cases the light flashes), these commands will not work.

Chris Rorden, 2013 BSD license (see license.txt or http://opensource.org/licenses/BSD-2-Clause)