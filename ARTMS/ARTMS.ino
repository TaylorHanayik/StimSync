/*
Voicekey Enable  -   PWM2
                Detect    -   PWM13
Keyboard   PWM3 bis PWM9
AUX in  PWM10 - PWM12
Trigger out  Digital 22-37
Und 8 Analogeingänge A0 - A7
*/

#define IS_MEGA

//no need to edit lines below here....111123

#define BAUD_RATE  115200
const int kSoftwareVersion = 1;
const int kBitsResolution = 16; //currently we always send 16-bits per sample
const int kCmdLength = 4; //length of commands

byte gCmdPrevBytes[kCmdLength] = {0, 0,0,0};
const byte  kCmd1Set = 177;
const byte kCmd1Get = 169;
const byte kCmd2Mode = 163;
const byte kCmd2SetTimeStamp = 137;
const byte kCmd2SoftwareVersion = 138;
const byte kCmd2EEGTrigger = 139;
const byte kCmd34ModeuSec = 181;

/*COMMANDS FROM COMPUTER TO ARDUINO AND RESPONSES FROM ARDIUNO TO THE COMPUTER
All commands are 4 bytes long, the first byte is either SET (177) or GET (169)
SET commands change Arduino settings
 SET commands will typically be forgotten when the ARDUINO restarts
 However, the SET:EEPROMSAVE command will have the ARDUINO remember keyboard settings (keyup, keydown, keytrigger and debounce values)
GET commands request the Arduino to report its current settings
 SET: 177 -Have Arduino Change Settings
  SET:MODE: 163 -change whether Arduino acts as a USB Keyboard, Microsecond Timer or Oscilloscope
   SET:MODE:KEYBOARD 169,169 - digital inputs mimic a USB keyboard [177,163,169,169]
   SET:MODE:USEC 181,181 - used for precise timing and to change keyboard mapping [177,163,181,181]
   SET:MODE:OSC 162,162- used to plot analog inputs [177,163,162,162]
   -Example: [177,163,181,181] switches the Arduino to uSec mode
   -**Tip: From Arduino SerialMonitor sending '±£©©' sets keyboard, '±£µµ' sets uSec, '±£¢¢' sets oscilloscope
  SET:KEYDOWNPRESS:[LINE]:[MAPPING] 129 - change USB key stroke sent when key depressed
   -Example [177,129,2,72] pressing 2nd button will elicit 'H' (ASCII=32)
   -Special: MAPPING 0 means no response is generated
     -Example [177,129,3,0] pressing 3rd button will not create a response
   -Special: LINE 0 changes debounce time
     -Example [177,129,0,44] sets debounce time to 44ms
  SET:KEYUPPRESS:[LINE]:[MAPPING] 130 - change USB key stroke sent when key released
   -Example [177,130,2,72] releasing 2nd button will elicit 'H' (ASCII=32)
   -Special: MAPPING 0 means no response is generated
     -Example [177,130,3,0] releasing 3rd button will not create a response
  SET:KEYTRIGGER:[LINE]:[MAPPING] 131 - bing digital out to digital input
   -Example [177,131,2,3] down/up of second button determines on/off of 3rd output line
   -Special: MAPPING 0 removes binding
     -Example [177,131,3,0] status of 3rd button does not influence any outputs
  SET:OSCHZ:[HZhi]:[HZlo] 132 - set sample rate of Oscilloscope (Hz)
   -Example [177,132,1,244] sets 500Hz sampling rate
   -Example [177,132,0,125] sets 125Hz sampling rate
  SET:OSCCHANNELS:[CHANNELShi]:[CHANNELSlo] 133 - set number of analog inputs reported by Oscilloscope
   -Example [177,133,0,6] sets recording to 6 inputs
  SET:EEPROMSAVE:EEPROMSAVE:EEPROMSAVE 134 - save current settings to EEPROM so it will be recalled
  -Example [177,134,134,134] stores current settings in persistent memory
  SET:NUMANALOGKEYS:[NUMhi]:[NUMlo] 135 - bind digital out to digital input
   -Example [177,135,0,1] enable 1 analog key (currently 0,1,2)
  SET:SUPERSAMPLE:[NUMhi]:[NUMlo] 136 - average 2^VALUE subsamples per reported sample [DEFAULT = 0]
   -Example [177,136,0,3] average 2^3=8 subsamples, so a reported 100 Hz data set is based on 800 Hz recording
   -Example [177,136,0,0] average 2^0=1 subsamples, so a reported 100 Hz data set is based on 100 Hz recording
 GET: 169 -Same functions as SET, but have Arduino Report Settings rather than change settings
  -Same commands as 'SET'
  -Example: [169,163,0,0] requests mode, if Arduino is in uSec mode it will respond [169,163,181,181]
  -Example: [169,129,5,0] requests down-press mapping for fifth key, if this is 'i' (ASCII=105) the Arduino responds [169,129,5,105]

SIGNALS IN MIRCROSECOND (USEC) MODE
  0: kuSecSignature (254)
  1: HIGH(1) byte keybits
  2: LOW(0) byte of keybits
  3: HIGH(3) byte of uSec
  4: 2 byte of uSec
  5: 1 byte of uSec
  6:  0 byte of uSec
  7: Checksum - sum of all previous bytes folded to fit in 0..255
For example, if only the first (binary 1) and tenth (binary 512) buttons are pressed, the keybits is 513, with 2 stored in the HIGH byte and 1 stored in the LOW BYTE
Likewsie, the time in microsenconds is sent as a 32-bit value.

*/
//DIGITAL OUTPUTS - we can switch on or off outputs

const int kKeyNumAnalog = 0; //number of analog inputs
const int kKeyNumDigital = 7;
const int kOutEEGTriggerNum = 16;
const int kOutNum = 7;


#define BAUD_RATE 115200 //The UNO is not as capabe as other devices
const int kADCbits = 10; //The Uno supports 10bit (0..1023) analog input

const int kOutLEDpin = 13; //location of in-built light emitting diode - 11 for Teensy, 13 for Arduino
int kDigitalInPin[kKeyNumDigital + 1] = {0,3,4,5,6,7,8,9};
int kOutPin[kOutNum+1] = {0, 10,11,12,14,15,16,17};
int kOutEEGTriggerPin[kOutEEGTriggerNum+1] = {0, 22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37};


const int kADCbitShift = 16-kADCbits; //we report data with 16 bits precision, so we need to up-scale 10 and 12 bit ADC

//MODE VALUES - device can operate as a keyboard, a microsecond timer, or an oscilloscope
const int kModeuSec = 1;
int gMode = kModeuSec;
const int kDefaultDebounceMillis = 100;
boolean gCoupleDownUpDebounce = true;
int gDebounceMillis = 100;
//VALUES FOR KEYBOARD MODE
const int kKeyNum = kKeyNumDigital + kKeyNumAnalog; //digital inputs, e.g. if you have 8 buttons and 2 analog inputs, set to 10
const int kMaxKeyNum = kKeyNumDigital + 2; //digital inputs, e.g. if you have 8 buttons and 2 analog inputs, set to 10
char gKeyDown[kMaxKeyNum+1] = {kDefaultDebounceMillis, '1','2','3','4','5','6','7','a','b'}; //key mapping when button depressed
char gKeyUp[kMaxKeyNum+1] = {2,0,0,0,0, 0,0,0,0,0}; //key mapping when button released
int gKeyOldDownStatus[kMaxKeyNum+1] = {0, 0, 0, 0, 0,  0, 0, 0, 0, 0}; //keys previously depressed
int gKeyNewDownStatus[kMaxKeyNum+1] = {0, 0, 0, 0, 0,  0, 0, 0, 0, 0}; //keys currently depressed

byte gCurrentDigitalOutput = 0; //0..127 reflecting current status of digital output pins
char gKeyChangeChar;
unsigned long gKeyChangeTime = 0;

unsigned long gKeyTimeLastTrigger[kMaxKeyNum+1] = {};
unsigned long gKeyTimeLastUp[kMaxKeyNum+1] = {};
unsigned long gKeyTimeLastDown[kMaxKeyNum+1] = {};


boolean readKeys() { //reads which keys are down, returns true if keys have changed
  boolean statusChange = false;
  //read digital buttons
  for (int i = 1; i <= kKeyNumDigital; i++) {
      gKeyNewDownStatus[i] = !digitalRead(kDigitalInPin[i]);
      if (gKeyNewDownStatus[i] != gKeyOldDownStatus[i]) statusChange = true;
  }
  if (kKeyNumAnalog < 1) return statusChange;
  int c = 0;
  for (int a = 0; a < kKeyNumAnalog; a++) {
        #ifdef PROTO_BOARD
        int ref = analogRead(a*2); //read analog channel
        int value = analogRead((a*2)+1); //read threshold potentiometer
      #else
        int value = analogRead(a); //read analog channel
        int ref = analogRead(a+(kKeyNumAnalog) ); //read threshold potentiometer
      #endif
    int index = kKeyNumDigital+a+1;
    if (value > ref) {
      gKeyNewDownStatus[index] = HIGH;
    } else {
      gKeyNewDownStatus[index] = LOW;
    }
    //if (gKeyNewDownStatus[index] != gKeyOldDownStatus[index]) {
      statusChange = true;
      digitalWrite(A0+kKeyNumAnalog+kKeyNumAnalog+a, gKeyNewDownStatus[index]);  //turn analog status light on
    //}
  } //for each analog channel
  return statusChange;
} //readKeys()

void updateDebounceSettings() {
  //set time based on otherwise unused gKeyDown[0]
  if (gKeyDown[0]  < 1) gKeyDown[0] = kDefaultDebounceMillis;
  if (gKeyDown[0]  > 254) gKeyDown[0] = kDefaultDebounceMillis;
  gDebounceMillis = gKeyDown[0];
  //set flags based on otherwise unused gKeyUp[0]
  if (gKeyUp[0]  & 2)
    gCoupleDownUpDebounce = true;
  else
    gCoupleDownUpDebounce = false;
}

void sendUSec() {
  const int numSerialBytes = 8;
  const byte kuSecSignature = 254;
  byte serialBytes[numSerialBytes];
  int keyBits = 0;
  unsigned long uSec = micros();
  /* that proofed to mess it up
  for (int i = 1; i <= kKeyNum; i++)
    if (gKeyNewDownStatus[i] > 0) {
        keyBits = keyBits + (1 << (i-1)); // 2 ^ (i-1)
        if (i <= 2) digitalWrite(kOutEEGTriggerPin[i],HIGH); // instant setting of EEG Triggers for response key
    }
  */
  keyBits = keyBits + (gCurrentDigitalOutput << kKeyNum);
  serialBytes[0] = kuSecSignature;//indentify this reponse
  serialBytes[1] = ( keyBits >> 8) & 0xff; //keys 9..16 as bits 8..15
  serialBytes[2] = ( keyBits & 0xff);       //keys 1..8 as bits 0..7
  serialBytes[3] = ( uSec >> 24) & 0xff; //event time bits 24..31
  serialBytes[4] = ( uSec >> 16) & 0xff; //event time bits 16..23
  serialBytes[5] = ( uSec >> 8) & 0xff; //event time bits 8..15
  serialBytes[6] = ( uSec & 0xff);    //event time bits 0..7
  int checkSum = 0;
  for (int i = 0; i <= (numSerialBytes-2); i++)
     checkSum = checkSum + serialBytes[i];
  while (checkSum > 0xff) checkSum=(checkSum >> 8)+(checkSum & 0xff);
  serialBytes[numSerialBytes-1] = checkSum;
  Serial.write(serialBytes, numSerialBytes);
} //sendUSec()


void sendGetResponse(byte b2, byte b3, byte b4) { //report key press mapping for pin bitIndex
  byte serialBytes[kCmdLength];
        serialBytes[0] = kCmd1Get;
        serialBytes[1] = b2;
        serialBytes[2] = b3;
        serialBytes[3] = b4;
        Serial.write(serialBytes, kCmdLength);
} //sendGetResponse()

boolean isNewCommand(byte Val) {
//responds to any commands from PC - either reporting settings or changing settings, updates queue of recent bytes
// 1 2 3 -> 0 1 2 Val # left shift buffer and append val
 for (int i = 1; i < kCmdLength; i++) //e.g. 1 to 3
   gCmdPrevBytes[i-1] = gCmdPrevBytes[i];
 gCmdPrevBytes[kCmdLength-1] = Val;
 boolean possibleCmd = false; // default
 for (int i = 0; i < kCmdLength; i++) {//e.g. 0 to 3
   if ((gCmdPrevBytes[i] == kCmd1Set) )
     possibleCmd = true; // buffer contains a command
 }
 for (int i = 0; i < kCmdLength; i++) {//e.g. 0 to 3
   if ((gCmdPrevBytes[i] == kCmd1Get) )
     possibleCmd = true; // buffer contains a command
 }
 if (!possibleCmd)
   return false; //input is not a new command
 if ((gCmdPrevBytes[0] != kCmd1Set) && (gCmdPrevBytes[0] != kCmd1Get) )
   return possibleCmd; //only part of a Command has been received...wait for the complete message
 boolean cmdOK = true; // command is at beginning of buffer
 switch (gCmdPrevBytes[1]) { //decode the command
   case kCmd2Mode: //command: mode
        if (gCmdPrevBytes[0] == kCmd1Get) {
         //sendMode;
         byte mode34 = kCmd34ModeuSec;
         sendGetResponse(kCmd2Mode,mode34,mode34);
         break;
        }
        gMode = kModeuSec; //switch to keyboard mode
        break;
   case kCmd2SetTimeStamp:
        if (gCmdPrevBytes[0] == kCmd1Set) {
            sendUSec();
        }
        break;
   case kCmd2SoftwareVersion: //report version of software
        if (gCmdPrevBytes[0] == kCmd1Get) {
          sendGetResponse(kCmd2SoftwareVersion,(kSoftwareVersion >> 8) & 0xff,kSoftwareVersion & 0xff);
          break;
        }
    case kCmd2EEGTrigger: // send EEG Trigger
        // gCmdPrevBytes[2] gCmdPrevBytes[3]
        // use void sendTrigger(byte Index, int Val)
        {
        int i = 0;
        if ((gCmdPrevBytes[3] > 0) && (gCmdPrevBytes[3] < (kOutEEGTriggerNum + 1))) {
            i = gCmdPrevBytes[3];
        if (gCmdPrevBytes[2] == 0)  // Trigger LOW
                digitalWrite(kOutEEGTriggerPin[i],LOW);
            else
                digitalWrite(kOutEEGTriggerPin[i],HIGH);
        }
        else
            if (gCmdPrevBytes[3] == 0) { // for all
                for (i=1; i < kOutEEGTriggerNum + 1; i++) {
                    if (gCmdPrevBytes[2] == 0)  // Trigger LOW
                        digitalWrite(kOutEEGTriggerPin[i],LOW);
                    else
                        digitalWrite(kOutEEGTriggerPin[i],HIGH);
                }

            }
        }
        break;
    default : cmdOK = false;
 } //switch
 if (cmdOK) { //clear command buffer
   gCmdPrevBytes[0] = 0;
   gCmdPrevBytes[1] = 0;
   gCmdPrevBytes[2] = 0;
   gCmdPrevBytes[3] = 0;
 }
 return possibleCmd;
} //isNewCommand()

void writePins(byte Val) {
  gCurrentDigitalOutput = Val;
  for (int i = 1; i <= kOutNum; i++) {
    if ((( Val >> (i-1)) & 0x01) == 1)
      digitalWrite(kOutPin[i],HIGH);
    else
       digitalWrite(kOutPin[i],LOW);
   }
   if (gMode == kModeuSec) sendUSec();
} //writePins

void setup()
{
  //set KEY values - inputs
  unsigned long timeNow = millis();
  for (int i = 0; i <= kMaxKeyNum; i++) {
    gKeyTimeLastUp[i] = timeNow;
    gKeyTimeLastDown[i] = timeNow;
    gKeyTimeLastTrigger[i] = timeNow;
  }
    for (int i = 1; i <= (kKeyNumDigital); i++) {
    pinMode(kDigitalInPin[i], INPUT);           // set pin to input
    digitalWrite(kDigitalInPin[i], HIGH);       // turn on pullup resistors
  }
  readKeys(); //scan inputs
  for (int i = 1; i <= kMaxKeyNum; i++) {
    gKeyOldDownStatus[i] = gKeyNewDownStatus[i];
  }
  //Set OUT values - digital outputs
  for (int i = 1; i <= (kOutNum); i++)  //set analog status lights as outputs1
    pinMode(kOutPin[i], OUTPUT); //lights that signal if an LED is on
  if (kKeyNumAnalog > 0) {
    for (int a = 0; a < kKeyNumAnalog; a++) {
      pinMode(A0+kKeyNumAnalog+kKeyNumAnalog+a,OUTPUT);  //turn analog status light on
    }
  }
  pinMode(kOutLEDpin, OUTPUT); //set light as an output
  for (int i = 1; i <= kOutEEGTriggerNum; i++)
    pinMode(kOutEEGTriggerPin[i], OUTPUT);
  Serial.begin(BAUD_RATE);
} //setup()

void loop() {
 unsigned long timeNow = millis();
 if (gMode == kModeuSec) {
   //READ digital inputs
   boolean newStatusMapped = false;
   boolean newStatus = false;
   readKeys();
   for (int i = 1; i <= kKeyNum; i++) {
     if (gKeyNewDownStatus[i] != gKeyOldDownStatus[i]) {
       if (gKeyNewDownStatus[i] > 0)  { //downPress
         if ( (timeNow >  (gKeyTimeLastDown[i]+ gDebounceMillis))  || (timeNow < gKeyTimeLastDown[i]) )  {
           newStatus = true;
           if  (gKeyDown[i] > 0) newStatusMapped = true;  //status change of mapped key
           gKeyTimeLastDown[i] = timeNow ;
           if (gCoupleDownUpDebounce) gKeyTimeLastUp[i] = timeNow; //
           gKeyOldDownStatus[i] = gKeyNewDownStatus[i];
         }//debounce
       }//down press
       if (gKeyNewDownStatus[i] == 0)  { //upPress
        if ( (timeNow >( gKeyTimeLastUp[i]+gDebounceMillis))  || (timeNow < gKeyTimeLastUp[i]) )  { //
          //newStatus = true;
          if  (gKeyUp[i] > 0) newStatusMapped = true; //status change of mapped key
          gKeyTimeLastUp[i] = timeNow; //
          if (gCoupleDownUpDebounce) gKeyTimeLastDown[i] = timeNow; //
          gKeyOldDownStatus[i] = gKeyNewDownStatus[i];
         } //debounce
       } //up press
     } //if key change
   } //for each key

   if ((gMode == kModeuSec) && (newStatus)) {
        sendUSec();
   }

#ifdef BLINK
   //BLINK power light in uSec mode
  if (gMode == kModeuSec) {
    int modulo = timeNow % 1000;
    if ((modulo == 1) || (modulo == 201) ) digitalWrite(kOutLEDpin, HIGH);
    if ((modulo == 100) || (modulo == 300)) digitalWrite(kOutLEDpin, LOW);
  } //ModeUSec
#endif // BLINK
  }
  //Write digtal outputs - check for new commands

   if (Serial.available()) { //read data from primary serial port
                             // reads only one byte
        while (Serial.available()) {
            byte val = Serial.read();
            if (!isNewCommand(val)) writePins(val);
        }
    }

} //loop()
