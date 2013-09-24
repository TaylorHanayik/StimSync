You can control digital inputs (buttons) and outputs using an Arduino running the stimsyncArd sketch. The buttons should be easy to use - the Arduino will appear as a normal USB keyboard. You can set up the keyboard mapping (e.g. which button mimics which keyboard press) using the keymapLaz project. You only have to setup the key mapping once with keymapLaz and then choose "Write men" - the key mappings will be remembered.

You can control digital outputs from EPrime. You need a Teensy/Arduino with the stimsyncArd Sketch installed. The digital outputs are on the following pins:
  Arduino Leonardo: pins 10,11,12 corresponding to values 1,2,4 
  Teensy 2.0: pins 10,12,13,14,15 corresponding to values 1,2,4,8,16
  Teensy 3.0: pins 10,11,12,20,21,22,23 corresponding to values 1,2,4,8,16,32,64
For example, connect a light emitting diode so the anode is connected to pin 10 (value 1) and the cathode is connected to a 220 Ohm resistor that connects to ground. Writing any odd number to the device switches this light on, writing any even number switches the light off. You can use a relay (e.g. solid state AQZ207) to switch larger currents.

To add this feature to your experiment:
 1.) Launch EPrime and open up an experiment.
 2.) Choose Edit/Experiment and then select the 'Devices' tab. 
 	-Press the 'Add' button to add a serial device. 
        -Name the new device 'Serial'
        -Set the "COM Port" to match the com port of your Arduino as seen by your computers' device manager. If the device manager can not find a device, check your drivers.
	-You can leave all the other settings as the default values. Press OK.
 3.) In your main experiment, drag an "Inline" event from your Toolbox to your procedure (timeline). 
 4.) Edit the text in the Inline event
   Dim vOut(0) as Integer
   vOut(0) = 85
   Serial.WriteBytes vOut
 5.) Run the experiment, in this example the devices attached to pins with values 1,4,16,64 should switch on (e.g. pins 10,12,21,23 on a Teensy 3).

