//
//  ViewController.m
//  ArduinoSerial
//
//  Created by Pat O'Keefe on 4/30/09.
//  Copyright 2009 POP - Pat OKeefe Productions. All rights reserved.
//
//	Portions of this code were derived from Andreas Mayer's work on AMSerialPort.
//	AMSerialPort was absolutely necessary for the success of this project, and for
//	this, I thank Andreas. This is just a glorified adaptation to present an interface
//	for the ambitious programmer and work well with Arduino serial messages.
//
//	AMSerialPort is Copyright 2006 Andreas Mayer.
//



#import "ViewController.h"
#import "AMSerialPortList.h"
#import "AMSerialPortAdditions.h"
#import "AMView.h"


@implementation ViewController

static int gOscHz = 500;
static int gOscChannels = 3; //number of channels to report
static int gOscSuperSampling = 0; //DEFAULT 0 device will average 2^N subsamples, for example a 100 Hz recording with supersampling =3 will be based on 800 (2^3 * 100) samples per second

static int samples = 0;
static int graphTimepoints = 100;
static int graphSamplesPerTimepoint = 10;

- (void)serialTimerTick:(NSTimer *)timer {
    if ((graphView == nil)  || (gOscChannels < 1)  || (gOscChannels > kMaxChannels)  ||  (samples < 1)) return;
    GraphStruct lGraph;
    lGraph.blackBackground = FALSE;
    lGraph.enabled = TRUE;
    lGraph.timepoints = graphTimepoints;
    lGraph.verticalScale = 1.0;
    lGraph.selectedTimepoint = 1;
    lGraph.lines = gOscChannels;
    lGraph.data = (float *) malloc(lGraph.timepoints*lGraph.lines*sizeof(float));   
    int p = 0;
    for (int c = 0; c < lGraph.lines; c++) {
        int sample = samples- (graphTimepoints* graphSamplesPerTimepoint);
        while (sample < 0) sample = kMaxSamples - sample;
        for (int i = 0; i < lGraph.timepoints; i++) {
            lGraph.data[p] = channelData[c][sample];
            p++;
            sample = sample + graphSamplesPerTimepoint;
            if (sample >= kMaxSamples) sample = sample - kMaxSamples;
        }
    }
    [graphView updateData: lGraph];
    free(lGraph.data);
}

-(void) startTimer {
    float theInterval = 1.0/60.0;
    serialTimer = [NSTimer scheduledTimerWithTimeInterval:theInterval target:self selector:@selector(serialTimerTick:) userInfo:nil repeats:YES];
}

-(void) stopTimer {
    [serialTimer invalidate];
}

- (void)windowWillClose:(NSNotification *)aNotification {
    [serialTimer invalidate];
    [self disconnectPort];
    //[NSApp terminate:self];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication*)inSender
{
    return YES;
}

- (void)awakeFromNib
{
    [theWindow setDelegate:self]; //this is required, despite XCode complaints
    [NSApp setDelegate:self];
    serialBuffer = [[NSMutableData alloc] init];
    //NSLog(@"Awake");
	/// set up notifications
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didAddPorts:) name:AMSerialPortListDidAddPortsNotification object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didRemovePorts:) name:AMSerialPortListDidRemovePortsNotification object:nil];
	/// initialize port list to arm notifications
	[AMSerialPortList sharedPortList];
	[self listDevices];
    [super awakeFromNib];
}

- (IBAction)attemptConnect:(id)sender {
	[self initPort];
    [self startTimer];
}

const  u_char kCmdBytes = 4;
const  u_char kCmd1Set = 177;
const  u_char kCmd1Get = 169;
const  u_char kCmd2Mode = 163;
//const  u_char kCmd2KeyDown = 129;
//const  u_char kCmd2KeyUp = 130;
//const  u_char kCmd2KeyTrigger = 131;
const  u_char kCmd2OscHz = 132;
const  u_char kCmd2OscChannels = 133;
//const  u_char kCmd2EEPROMSAVE = 134;
//const u_char kCmd2NumAnalogKeys = 135;
const u_char kCmd2OscSuperSampling = 136;
const  u_char kCmd34ModeKey = 169; //set Arduino to keyboard mode
//const  u_char kCmd34ModeuSec = 181;
const  u_char kCmd34ModeOsc = 162; //set Arduino to oscilloscope mode

- (void)disconnectPort
{
    if([port isOpen]) {
        u_char chrArrayMode[5] = {kCmd1Set,kCmd2Mode,kCmd34ModeKey,kCmd34ModeKey};
        [port writeData:[NSData dataWithBytes:& chrArrayMode length:4] error:NULL];
        [port close];
        NSLog(@"device placed in keyboard mode [disconnected]");
    }
}

	- (void)initPort
	{
        [self stopTimer];
        if ([port isOpen]) {
			[self disconnectPort];
            //[port close];
            [connectButton setTitle:@"Connect"];
            return;
        }
		NSString *deviceName = [serialSelectMenu titleOfSelectedItem];
        gOscChannels = [[channelSelectMenu titleOfSelectedItem] intValue];
        if (gOscChannels < 1) gOscChannels = 1;
        if (gOscChannels > kMaxChannels) gOscChannels = kMaxChannels;
        gOscHz = [[samplingRateSelectMenu titleOfSelectedItem] intValue];
        if (gOscHz < 10) gOscHz = 10;
        [self disconnectPort];
        [self setPort:[[[AMSerialPort alloc] init:deviceName withName:deviceName type:(NSString*)CFSTR(kIOSerialBSDModemType)] autorelease]];
        [port setDelegate:self];
		if ([port open]) {
				
			//[serialBuffer replaceBytesInRange:NSMakeRange(0, [serialBuffer length]) withBytes:NULL length:0];
            [serialBuffer setData:[NSData dataWithBytes:NULL length:0]];
             NSLog(@"Connected with %d channels at %d Hz\n",gOscChannels, gOscHz);
            
            if ([port bytesAvailable] > 0) {
                //NSLog(@"flushing %d bytes", [port bytesAvailable ]);
                //NSData *result =
                [port readAndStopAfterBytes:YES bytes:[port bytesAvailable ] stopAtChar:NO stopChar:0 error:false];
            }
            
            [connectButton setTitle:@"Disconnect"];
				//[port setSpeed:B57600];
                [port setSpeed:921600];
                u_char chrArrayChan[5] = {kCmd1Set,kCmd2OscChannels,0,gOscChannels}; //set channels
                [port writeData:[NSData dataWithBytes:& chrArrayChan length:4] error:NULL];
                u_char chrArrayHz[5] = {kCmd1Set,kCmd2OscHz,(gOscHz >> 8) & 0xff,gOscHz & 0xff};//set sample rate
                [port writeData:[NSData dataWithBytes:& chrArrayHz length:4] error:NULL];
                u_char chrArraySuper[5] = {kCmd1Set,kCmd2OscSuperSampling,(gOscSuperSampling >> 8) & 0xff,gOscSuperSampling & 0xff};
                [port writeData:[NSData dataWithBytes:& chrArraySuper length:4] error:NULL];
                //check hardware
                u_char chrArrayChanGet[5] = {kCmd1Get,kCmd2OscChannels,0,gOscChannels}; //get channels - test hardware
                [port writeData:[NSData dataWithBytes:& chrArrayChanGet length:4] error:NULL];
                //sleep(0.01);
                // listen for data in a separate thread
        
                [port readDataInBackground];
            //start hardware
                u_char chrArrayMode[5] = {kCmd1Set,kCmd2Mode,kCmd34ModeOsc,kCmd34ModeOsc}; //set oscilloscope data streaming on
                [port writeData:[NSData dataWithBytes:& chrArrayMode length:4] error:NULL];
                
				
        } else { // an error occured while creating port
				NSLog(@"error connecting");
				[self setPort:nil];
        }
	}
	
	- (void)serialPortReadData:(NSDictionary *)dataDictionary
	{
        int packetBytes = 4 + (gOscChannels *2); //bytes in a packet of data
        AMSerialPort *sendPort = [dataDictionary objectForKey:@"serialPort"];
		NSData *data = [dataDictionary objectForKey:@"data"];
		if ([data length] < 1) {
            //NSLog(@"no serial port data: is it closed?");
            return;   
        }
        [sendPort readDataInBackground];// continue listening
        [serialBuffer appendData:data];//add new values to orphans from previous call
        int len = [serialBuffer length];
        int pos = 0;
        int posOK = 0;
        int errors = 0;
        Byte* byteData = (const Byte*)[serialBuffer bytes];
        while (pos < len) {
            if (((len-pos) >= kCmdBytes) && (byteData[pos] == kCmd1Get) &&  (byteData[pos+1] == kCmd2OscChannels) ) { //check-new command?
                int lOscChannels = (byteData[pos+2] << 8) + byteData[pos+3];
                NSLog(@"Requested %d channels, Arduino reports %d channel\n",gOscChannels, lOscChannels);
                if (lOscChannels != gOscChannels) {
                    gOscChannels = lOscChannels;
                    //[self initPort];
                }
                pos = pos + kCmdBytes;
                posOK = pos;
            } else if ((len-pos) >= packetBytes) { //check to see if we have a new packet
                int checkSum = 0;
                for (int i = 0; i <= (packetBytes-2); i++)
                    checkSum = checkSum + byteData[pos+i];
                while (checkSum > 0xff) checkSum=(checkSum >> 8)+(checkSum & 0xff);
                int checkSumStored = byteData[pos+packetBytes-1];
                if (checkSum == checkSumStored) {
                    //int digitalByte = (byteData[pos+1] << 8)+byteData[pos+2]; //we ignore digital inuts - this reports button presses
                    for (int i = 0; i < gOscChannels; i++)
                        channelData[i][samples] = (byteData[pos+3+(i*2)]  << 8) +byteData[pos+4+(i*2)] ;
                    for (int i = 0; i < gOscChannels; i++)
                                channelData[i][samples] = channelData[i][samples] /65535;
                        samples = samples + 1;
                        if (samples >= kMaxSamples)
                            samples = 0;
                    pos = pos + packetBytes;
                    posOK = pos;
                } else {//the checksum does not match - disregard oldest byte and try again
                    //NSLog(@"CheckSum %d\n",pos);
                    pos = pos + 1;
                    errors++;
                }
            } else { //pos means not long enought to be a command or packet
                pos = pos + 1;
            } //if pos is command, else packet, else resudual byte
        }//while potential blocks to read
        [serialBuffer replaceBytesInRange:NSMakeRange(0, posOK) withBytes:NULL length:0];
        if (errors > 0)
            NSLog(@" Errors = %d Len = %d PosOK = %d resiudal =%d",errors,len,posOK, [serialBuffer length]);
	}
	
	- (void)listDevices
	{
		// get an port enumerator
		NSEnumerator *enumerator = [AMSerialPortList portEnumerator];
		AMSerialPort *aPort;
        [channelSelectMenu removeAllItems];
        for (int i = 1; i <= kMaxChannels; i++)
            [channelSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",i]];
        [channelSelectMenu selectItemAtIndex: 0];
        [samplingRateSelectMenu removeAllItems];
        [samplingRateSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",125]];
        [samplingRateSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",250]];
        [samplingRateSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",500]];
        [samplingRateSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",1000]];
            [samplingRateSelectMenu addItemWithTitle:[NSString stringWithFormat:@"%d",2000]];
		[samplingRateSelectMenu selectItemAtIndex: 3];
        [serialSelectMenu removeAllItems];
        NSRange textRange;
        int index =0;
        int found = 0;
        while (aPort = [enumerator nextObject]) {
			[serialSelectMenu addItemWithTitle:[aPort bsdPath]];
            textRange =[[aPort bsdPath] rangeOfString:@"123"];
            if(textRange.location != NSNotFound)
                found = index;
            index++;
		}
        [serialSelectMenu selectItemAtIndex: found];
	}
		
	- (AMSerialPort *)port
	{
		return port;
	}
	
	- (void)setPort:(AMSerialPort *)newPort
	{
		id old = nil;
		if (newPort != port) {
            old = port;
			port = [newPort retain];
			[old release];
		}
	}	
	
	- (void)didAddPorts:(NSNotification *)theNotification
	{
		NSLog(@"A port was added");
		[self listDevices];
	}
	
	- (void)didRemovePorts:(NSNotification *)theNotification
	{
		NSLog(@"A port was removed");
		[self listDevices];
	}








@end
