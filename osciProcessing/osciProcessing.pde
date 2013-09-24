int gOscHz = 1000;
int gOscChannels = 1; //number of channels to report
int gOscSuperSampling = 0; //DEFAULT 0: device will average 2^N subsamples, for example a 100 Hz recording with supersampling =3 will be based on 800 (2^3 * 100) samples per second 
float gGraphTotalTimeSec = 1; //e.g. if 1 then the last 1 second of data is displayed
float tickSpacing = gGraphTotalTimeSec/5; //e.g. if 0.2 then vertical lines once every 200 ms 
int serialPortNumber = 0; //set to 0 for automatic detection
int screenWid = 1000; //width of scrren, in pixels
int screenHt = 600; //height of screen, in pixels
boolean offsetTraces = true; //vertically shift different channels to avoid overlap
int BAUD_RATE = 460800;//230400;//921600;//460800;//921600; //921600 for Teensy2/Teensy3/Leonardo 460800
boolean saveAsText = false; //save a text file you can view with excel
boolean autoScale = true;
//************   no need to edit lines below here *******
//this script was derived from  Sofian Audry’s  Poorman's oscilloscope http://accrochages.drone.ws/en/node/90
// modified by Chris Rorden, 2013 BSD license (see license.txt or http://opensource.org/licenses/BSD-2-Clause)
import processing.serial.*;
import javax.swing.JOptionPane;//For user input dialogs
import java.util.Date; //for date/time used by saveAsText
PrintWriter output; // for file storage used by saveAsText
Serial port;      // Create object from Serial class
int[]  val;              // Data received from the serial port
int[] channelMin, channelMax, channelIntercept;
float[] channelSlope;
int cnt; //sample count
int wm1; //screenWidth -1
int[][] values; //data for up to 3 analog channels
int maxResidualBytes = 1024; //maximum bytes left over from previous transmission
int residualBytes = 0; //number of bytes left over from previous transmission
int[]  residualRawData; //array with bytes left over from previous transmission
//float screenScale16bit = float(screenHt-1)/65535;
int halfScreenHt = screenHt / 2;
int positionHt = 200; //height of vertical bar shown at leading edge of oscilloscope
long valuesReceived = 0; //how many samples have been recorded
long calibrationFrames = 120;
float lastSamplePlotted = 0;
float pixelsPerSample = 1;
int Margin = 4; //margin in pixels for top and bottom
//float plotEveryNthSample = 1000;//how many samples are skipped for each one plotted - will be set based on gOscHz,gGraphTotalTimeSec,screenWid
//long plotEveryNthSample = 1000;//how many samples are skipped for each one plotted - will be set based on gOscHz,gGraphTotalTimeSec,screenWid
long startTime;
int kOscMaxChannels = 15;
int[][] lineColorsRGB = { {255,0,0}, {0,255,0}, {0,0,255}, {255,255,0}, {0,255,255}, {255,0,255},
                         {128,0,0}, {0,128,0}, {0,0,128}, {128,128,0}, {0,128,128}, {128,0,128},
                         {64,0,0}, {0,64,0}, {0,0,64} };

int kCmdLength = 4; //length of commands
byte  kCmd1Set = (byte) 177;
byte kCmd1Get = (byte) 169;
byte kCmd2Mode = (byte) 163;
byte kCmd2KeyDown = (byte) 129;
byte kCmd2KeyUp = (byte) 130;
byte kCmd2KeyTrigger = (byte) 131;
byte kCmd2OscHz = (byte) 132;
byte kCmd2OscChannels = (byte) 133;
byte kCmd2EEPROMSAVE =(byte) 134;
byte kCmd2NumAnalogKeys =(byte) 135;
byte kCmd2OscSuperSampling =(byte) 136; 
byte kCmd34ModeKey = (byte) 169;
byte kCmd34ModeuSec = (byte) 181;
byte kCmd34ModeOsc = (byte) 162;

void writeCmd(boolean setNotGet, byte b2, byte b3, byte b4) { //get or set Arduino settings
  byte[] serialBytes = new byte[kCmdLength];
  if (setNotGet) 
        serialBytes[0] = kCmd1Set;
  else
    serialBytes[0] = kCmd1Get;
        serialBytes[1] = b2; 
        serialBytes[2] = b3;
        serialBytes[3] = b4;
        port.write(serialBytes);  
} //writeCmd()

void exit()  { //put the Arduino back into default keyboard mode
    writeCmd(true,kCmd2Mode,kCmd34ModeKey,kCmd34ModeKey); //set to uSec Mode
    if (saveAsText) {
      output.flush(); // Write the remaining data
      output.close(); //close the text file
    }
    super.exit();
} //exit()

void calibrateFrameRate() {
  if (valuesReceived < 1) {
    println("Error: No samples detected: either device is not connected or serialPortNumber is wrong.");
    exit();
  }
  //plotEveryNthSample = round(gGraphTotalTimeSec/float(screenWid)* float(gOscHz));
  //if (plotEveryNthSample < 1) plotEveryNthSample = 1; 
  float plotEveryNthSample;
  plotEveryNthSample = (gGraphTotalTimeSec/float(screenWid)* float(gOscHz));
  if (plotEveryNthSample > 1) plotEveryNthSample = round(plotEveryNthSample);
  if (plotEveryNthSample == 1) plotEveryNthSample = 1; 
  pixelsPerSample = 1 / plotEveryNthSample;
  if ((tickSpacing == 0) || (screenWid == 0) || (plotEveryNthSample ==0) || (gOscHz == 0) ) //avoid divide by zero
    tickSpacing = screenWid / 4;
  else {
    tickSpacing = screenWid /  (((screenWid *plotEveryNthSample)/ gOscHz)/tickSpacing);
  }
  println(tickSpacing);
  float estHz = (1000*valuesReceived)/(millis()-startTime);
  print("Requested ");  print(gOscHz); print("Hz, so far we have observed "); print(estHz); println("Hz");
  print ("Displaying  ");  print(pixelsPerSample); print(" pixels per sample, so the screen shows "); print((screenWid *plotEveryNthSample)/ gOscHz); println(" Sec");
} //calibrateFrameRate()

void setPortNum() {
   String[] portStr = Serial.list();
   int nPort = portStr.length;
   if (nPort < 1) {
      javax.swing.JOptionPane.showMessageDialog(frame,"No devices detected: please check Arduino power and drivers.");  
      exit();    
   }
   int index = 0;
   for (int i=0; i<nPort; i++) {
     if (match(portStr[i], "cu.us") != null) index = i; //Arduino/Teensy names like /dev/cu.usbmodem*" and our BlueTooth is  /dev/cu.us922k0000bt 
     portStr[i] =  i+ " "+portStr[i] ;
   }  
   String respStr = (String) JOptionPane.showInputDialog(null,
      "Choose your device (if not listed: check drivers and power)", "Select Arduino",
      JOptionPane.PLAIN_MESSAGE, null,
      portStr, portStr[index]);
   serialPortNumber = Integer.parseInt(respStr.substring(0, 1));  
} //setPortNum()

void autoScaleChannel (int ch) {
  int Ht = screenHt-Margin-Margin;
  if (offsetTraces) Ht = Ht - (gOscChannels * 2);
  if ((Ht < 1) || (ch < 0) || (ch >= kOscMaxChannels) || (channelMin[ch] > channelMax[ch])) return;
  if (channelMin[ch] == channelMax[ch]) {
    channelSlope[ch] = 0;
    return; 
  }
  channelSlope[ch] = float(Ht)/ float(channelMax[ch] - channelMin[ch]);
  //print(channelMin[ch]); print(".."); print(channelMax[ch]); print(" "); print(channelSlope[ch]);
} //autoScaleChannel()

void setup() 
{
  residualRawData = new int[maxResidualBytes];
  channelMin= new int[kOscMaxChannels];
  channelMax= new int[kOscMaxChannels];
  channelSlope= new float[kOscMaxChannels];
  channelIntercept= new int[kOscMaxChannels];
  for (int c=0;c<kOscMaxChannels;c++) {
    if (offsetTraces) 
      channelIntercept[c] = Margin+ (c * 2);
    else
      channelIntercept[c] = Margin;
    channelMin[c] = 0;
    channelMax[c] = 65535;
    autoScaleChannel(c);
    if (autoScale) {
      channelMin[c] = 65535;
      channelMax[c] = 0;        
    }
  }
  if (gOscChannels > lineColorsRGB.length) {
    println("Error: you need to specify more colors to the array lineColorsRGB.");
    exit();   
  } 
  if (gOscChannels > kOscMaxChannels) {
    print("Error: you requested "); print(gOscChannels); print(" channels but this software currently only supports ");println(kOscMaxChannels);
    exit();   
  } 
  if (serialPortNumber == 0) {
    setPortNum();
  } else {
    print("Will attempt to open port "); println(serialPortNumber); 
    println(", this should correspond to the device number in this list:");
    println(Serial.list());
    println("Hint: if you set serialPortNumber=0 the program will allow the user to select from a drop down list of available ports");
  }
  port = new Serial(this, Serial.list()[serialPortNumber], BAUD_RATE);    
  // port = new Serial(this, Serial.list()[serialPortNumber]);
  writeCmd(true,kCmd2OscChannels,(byte) 0, (byte)gOscChannels); //set number of channels
  writeCmd(true,kCmd2OscHz, (byte) ((gOscHz >> 8) & 0xff), (byte) (gOscHz & 0xff)); //set sampling rate to 125 Hz
  writeCmd(true,kCmd2OscSuperSampling, (byte) ((gOscSuperSampling >> 8) & 0xff), (byte) (gOscSuperSampling & 0xff)); //set sampling rate to 125 Hz
  //hardware check
  while (port.available() > 0)  port.read();
  writeCmd(false,kCmd2OscChannels,(byte) 0, (byte)gOscChannels); //get number of channels
  //start transmission
  //writeCmd(true,kCmd2Mode,kCmd34ModeOsc,kCmd34ModeOsc); //set to uSec Mode
  startTime = 0;
  size(screenWid, screenHt);                                  //currently set to 5 sec
  //serialBytes = new int[packetBytes];
  val = new int[gOscChannels]; //most recent sample for each channel
  values = new int[gOscChannels][width]; //previous samples for each channel
  wm1= width-1; 
  cnt = 1;     
  frameRate(60); //refresh screen 60 times per second
  for (int c=0;c<gOscChannels;c++) {
    for (int s=0;s<width;s++) {                 //set initial values to midrange
      values[c][s] = 0;
    }//for each sample
  }//for each channel 
  if (saveAsText) {
    Date d = new Date();
    long timestamp = d.getTime() ;
    String date = new java.text.SimpleDateFormat("yyyyMMddHHmmss").format(timestamp);
    String storagePath = System.getProperty("user.home")+ File.separator+ date+ ".txt"; 
    print("Saving data to file "); println( storagePath);
    output = createWriter(storagePath);    
  }
    //start transmission
  writeCmd(true,kCmd2Mode,kCmd34ModeOsc,kCmd34ModeOsc); //set to uSec Mode
} //setup() 

void serDecode() {
  int newlen = port.available();
  if (newlen < 1) return;
  int packetBytes = 4 + (2 * gOscChannels); //16-bits data per channel plus 4 bytes header
  int len = newlen + residualBytes;
  int[] rawData = new int [len];
  if (residualBytes > 0)
    for (int c=0; c <residualBytes; c++)
      rawData[c] = residualRawData[c];    
  for (int c=0; c <newlen; c++)
    rawData[residualBytes+c] = port.read();
  int pos = 0;
  int OKpos = -1;
  //print(residualBytes);print("+");print(len);print(":");
  while (pos < len) {  //read the latest value
    if (((len-pos) >= 4)  && (rawData[pos] == 169) && (rawData[pos+1] > 127)) {//169 is kCmd1Get
            switch(rawData[pos+1]) {
              case 133:// (byte) 133:// kCmd2OscChannels kCmd2OscChannels
                    int lOscChannels =  (rawData[pos+2]  << 8) +rawData[pos+3] ;
                    if (lOscChannels != gOscChannels) {
                        print("Error: requested ");print(gOscChannels);
                        print(" but Arduino reports "); print(lOscChannels);
                        println(" channels - perhaps this device can not support so many channels");
                        pos = len; //ignore rest of the available bytes 
                        exit();   
                    } 
                    break;
              default: 
                print("Arduino sent unknown GET command :");println(rawData[pos+1]);
                break;
            } //switch
            pos = pos + 4; //commands are 4 bytes
            //print("Arduino sent GET command :");
            OKpos = pos -1;//last useful byte
    } else if ((len-pos) >= packetBytes) { // if 1st byte is 169 (kCmd1Get) command else check for data (first byte of data packet always <128)       
         int checkSum  = 0;
         for (int c=0; c <(packetBytes-1); c++)
           checkSum = checkSum + rawData[pos+c];
         while (checkSum > 0xff) checkSum=(checkSum >> 8)+(checkSum & 0xff); //fold checksum
         int checkSumStored = rawData[pos+packetBytes-1];
         if  (checkSum == checkSumStored)  {
           //int digitalByte = (rawData[pos+1] << 8)+rawData[pos+2]; //we ignore digital inuts - this reports button presses
           for (int i = 0; i < gOscChannels; i++)
             val[i] =  ( rawData[pos+3+(i*2)]  << 8) +rawData[pos+4+(i*2)] ;
           if (saveAsText) {
             if (gOscChannels > 1) {
               for (int i = 0; i < (gOscChannels-1); i++)
                 output.print(val[i] + "\t");
             } //if multiple channels
             output.println(val[gOscChannels-1]);
           }//if saveAsText
          if (autoScale) {
            for (int i = 0; i < gOscChannels; i++) {
              if (val[i] > channelMax[i]) {
                channelMax[i] =  val[i];
                autoScaleChannel(i);
              }//new max
              if (val[i] < channelMin[i]) {
                channelMin[i] =  val[i];
                autoScaleChannel(i);
              } //new min                    
            }//for each channel
          } //if autoScale
           
           if (calibrationFrames == 0) { //drawing display
              lastSamplePlotted = (lastSamplePlotted + pixelsPerSample);
              if (lastSamplePlotted >= 1) { //draw new sample[s]
                for (int i = 0; i < gOscChannels; i++) 
                  val[i] = round(float(val[i]-  channelMin[i])*channelSlope[i])+channelIntercept[i];  
                //if (offsetTraces)
                //  for (int i = 0; i < gOscChannels; i++) val[i] = val[i] + (i*2) - (gOscChannels-1); 
                for (int px = 0; px < floor(lastSamplePlotted); px++) {
                  for (int ch = 0; ch < gOscChannels; ch++) values[ch][cnt] = val[ch];  //put it in the array
                  cnt++;  //increment the count
                  if (cnt > wm1) cnt = 1;
                }
              } 
              lastSamplePlotted = lastSamplePlotted - floor(lastSamplePlotted);
           } else //if calibrationframes = 0 else still calibrating...
             valuesReceived++;
             
            pos = pos+packetBytes;
            OKpos = pos-1;
            //print("."); //report valid sample
         } else {//checksum matches else assume error and skip one byte   
            pos = pos + 1;
            print("CheckSumError"); //report error
         }   
     } else { //if not commmand
        pos = pos + 1; 
     } //single byte
  } //while samples to read
  //deal with partial packets
  residualBytes = (len-1) - OKpos; //bytes we were unable to use, e.g. 1024 bytes sent, 1022 read 
  if (residualBytes > maxResidualBytes) residualBytes = maxResidualBytes;
  if (residualBytes > 0)
       for (int i = 0; i < residualBytes; i++)
         residualRawData[i] = rawData[len-residualBytes+i]; 
} //void serDecode

void draw() {
      serDecode();
      if (calibrationFrames > 0) {
        if ((startTime == 0) && (valuesReceived > 0)){
          valuesReceived = 0; 
          startTime = millis();
        }
        calibrationFrames--;
        if (calibrationFrames == 0) {
          calibrateFrameRate(); 
        }
        return;
      } //if still in initial calibration frames period
      //NEXT : DRAW GRAPH
      background(96); // background 0 = black, 255= white
      //next: vertical lines for seconds...
      stroke(60);
      float xpos = tickSpacing;
      while (xpos < width) {  
        line(xpos,0,xpos,screenHt);  
        xpos = xpos + tickSpacing;
      }
      //draw the leading edge line
      stroke(255,255,0);
      line(cnt,halfScreenHt-positionHt,cnt,halfScreenHt+positionHt);  
      //plot incoming data      
      for (int i = 0; i < gOscChannels; i++) {
        stroke(lineColorsRGB[i][0],lineColorsRGB[i][1],lineColorsRGB[i][2]);  
        for (int x=2; x<wm1; x++) line (x-1,  values[i][x-1], x, values[i][x]);
      }        
 } //draw()
