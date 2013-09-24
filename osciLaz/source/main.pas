unit main;
//Chris Rorden, 2013 BSD license (see license.txt or http://opensource.org/licenses/BSD-2-Clause)
{$mode delphi}{$H+}
{$DEFINE VMRK}

interface

uses
{$IFDEF VMRK}format_vmrk, {$ENDIF}
Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  ComCtrls, PairSplitter, Buttons, Menus, eeg_type, eeg_graph, format_all,
  prefs, synaser, userdir, mainprefs;
type

  { TMainForm }
  TGraph = record
     firstSample, lastSample: integer;
     bigText: string;
  end;

  TMainForm = class(TForm)
  {$IFDEF DARWIN}
        AppMenu     : TMenuItem;
        AppAboutCmd : TMenuItem;
        AppQuitCmd  : TMenuItem;
        //AppPrefCmd  : TMenuItem;
    {$ENDIF}
    CurrentImage: TImage;
    MainMenu1: TMainMenu;
    FileItem: TMenuItem;
    HelpMenu: TMenuItem;
    AboutItem: TMenuItem;
    QuitMenu: TMenuItem;
    SaveMenu: TMenuItem;
    RecordItem: TMenuItem;
    sampleTimer: TTimer;
    initTimer: TTimer;
    SaveDialog1: TSaveDialog;
    TriggerImage: TImage;
    PairSplitter1: TPairSplitter;
    PairSplitterSide1: TPairSplitterSide;
    PairSplitterSide2: TPairSplitterSide;
    StatusBar1: TStatusBar;
    procedure WriteCmd (setNotGet: boolean; Cmd2, Cmd3, Cmd4: byte);
    procedure QuitMenuClick(Sender: TObject);
    procedure SaveCore (AutoSave: boolean);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormResize(Sender: TObject);
    procedure initTimerTimer(Sender: TObject);
    procedure SaveMenuClick(Sender: TObject);
    procedure PairSplitter1ChangeBounds(Sender: TObject);
    procedure PairSplitter1Resize(Sender: TObject);
    procedure PairSplitterSide1Resize(Sender: TObject);
    procedure RecordItemClicks(Sender: TObject);
    procedure RefreshGraphs;
    procedure sampleTimerTimer(Sender: TObject);
    procedure StartBtnClick(Sender: TObject);
    procedure StopRecording;
    procedure PrefItemClick(Sender: TObject);
    procedure AboutItemClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  MainForm: TMainForm;

implementation

{$R *.lfm}
var
   gGraphPrefs: TGraphPrefs;
   gMainPrefs: TMainPrefs;
   gCurrentGraph, gTriggerGraph: TGraph;
   gHzResp, gChannelsResp : integer;
{$IFDEF VMRK}gVMRK: TVMRK;
const
  kMaxVMRK = 65535;
   {$ENDIF}
const
  kMaxChannels = 15;
  kMaxSec = 60 * 45; //45 minutes

  const
  kKeyNum = 10; //number of digital keys
  kKeyNumAnalog = 2; //number of analog inputs
  kKeyNumDigital = kKeyNum - kKeyNumAnalog;
  //kCmd are Command Codes for communication
  kCmd1Set = 177;
  kCmd1Get = 169;
  kCmd2Mode = 163;
  kCmd2KeyDown = 129;
  kCmd2KeyUp = 130;
  kCmd2KeyTrigger = 131;
  kCmd2OscHz = 132;
  kCmd2OscChannels = 133;
  kCmd2EEPROMSAVE = 134;
    kCmd2NumAnalogKeys = 135;
  kCmd2OscSuperSampling = 136;
  kCmd34ModeKey = 169;
  kCmd34ModeuSec = 181;
  kCmd34ModeOsc = 162;
  kCmdBytes = 4; //length of commands (in bytes)
{ TMainForm }

procedure TMainForm.PrefItemClick(Sender: TObject);
begin
  showmessage('Not yet implemented');
end;

procedure TMainForm.AboutItemClick(Sender: TObject);
begin
  showmessage('Beta version: April 2013 - for testing only ');
end;

procedure TMainForm.SaveCore (AutoSave: boolean);
var
   s, dir: string;
begin
  if MaxNumSamples(gMainPrefs.EEG) < 1 then begin
    Showmessage('You need to load data before you can save.');
    exit;
  end;
  gMainPrefs.UnsavedData := false;
  if AutoSave then begin
     dir := gMainPrefs.autoSaveDir;
     if (length(dir) > 0) and (dir[length(dir)] <> pathdelim) then
        dir := dir + pathdelim;
     if not DirectoryExists(dir) then begin
        showmessage('Unable to automatically save data: directory not found: '+dir);
        exit;
     end;
     SaveDialog1.FileName :=  dir+ (FormatDateTime('yyyymmdd_hhnnss', (gMainPrefs.EEG.time{now})))+'.vhdr'
  end else begin
    if not SaveDialog1.Execute then
      exit;
  end;
  WriteEEG(SaveDialog1.FileName,gMainPrefs.EEG);
  s := 'saved data as '+SaveDialog1.FileName;
  {$IFDEF VMRK}

  if (gVMRK.CurrentEvent < 1) then
     s := s + ' no triggers'
  else begin
      setlength(gVMRK.Events,gVMRK.CurrentEvent);
     if WriteVMRK(changefileext(SaveDialog1.FileName,'.vmrk'),gVMRK) then
        s := s + ' + vmrk'
     else
         s := s + ' error writing vmrk';
  end;
  {$ENDIF}
  StatusBar1.Panels[2].Text  := s;
end;

{$IFDEF VMRK}
procedure AddVMRK(Cond, Sample: integer; var lVMRK: TVMRK);
var
  t: integer;
begin
  if (lVMRK.CurrentEvent >= kMaxVMRK) or ((lVMRK.CurrentEvent+1) > Length(lVMRK.events)) then
    exit;
  inc(lVMRK.CurrentEvent);
  t := lVMRK.CurrentEvent-1; //indexed from 0
  lVMRK.Events[t].Typ:= 'Stimulus';
  lVMRK.Events[t].Desc := 'Cond'+inttostr(Cond);
  lVMRK.Events[t].OnsetSamp := Sample;
  lVMRK.Events[t].DurationSamp := 100;
  lVMRK.Events[t].Channel := 0;
end;
{$ENDIF}

procedure TMainForm.RefreshGraphs;
begin
     DrawGraph(CurrentImage, gMainPrefs.EEG, gGraphPrefs, gCurrentGraph.firstSample, gCurrentGraph.lastSample, gCurrentGraph.bigText, gMainPrefs.DigitalChannel);
     DrawGraph(TriggerImage, gMainPrefs.EEG, gGraphPrefs, gTriggerGraph.firstSample, gTriggerGraph.lastSample, gTriggerGraph.bigText, gMainPrefs.DigitalChannel);
end;

procedure DecodeBuffer;
var
  tempBuffer,serialBytes: array of byte;
  packetBytes,sampleNumber, samples, digitalChannel, len,pos, c, checkSumStored, checkSum: integer;
begin
 packetBytes := 4 + (2 * gMainPrefs.AnalogChannels);
 setLength(serialBytes,packetBytes);
 samples := 0;
 len := length(gMainPrefs.SerialBuffer);
  if (len < packetBytes) then exit; //no new packets
    pos := 0;
    while ((len-pos) >= packetBytes) do begin
         for c :=0 to (packetBytes-1) do
             serialBytes[c] := gMainPrefs.SerialBuffer[pos+c]; //initialize output so unused channels report 0
         checkSumStored := serialBytes[packetBytes-1] ;
         checkSum  := 0;
         for c :=0 to (packetBytes-2) do
             checkSum := checkSum +serialBytes[c];
         while (checkSum > $ff) do
               checkSum :=(checkSum shr 8)+(checkSum and $ff);
         //analogChannels  := serialBytes[0] and $1f;  //1..31 channels
         if (checkSum = checkSumStored) then begin
            digitalChannel := (serialBytes[2] shl 8)+ serialBytes[2];
            if (not gMainPrefs.Recording) then begin
                  //gMainPrefs.AnalogChannels := analogChannels;
                  MainForm.initTimer.tag := MainForm.initTimer.tag + 1;
             end else if (gMainPrefs.EEG.maxsamples > 0) then begin
                  for c := 0 to (gMainPrefs.AnalogChannels-1) do
                      gMainPrefs.EEG.samples[c][gMainPrefs.EEG.samplesacquired] :=  (serialBytes[3+(c*2)]  shl 8) +serialBytes[4+(c*2)] ;


                  if gMainPrefs.detectAnalogTriggers then begin
                     if (gMainPrefs.EEG.samples[0][gMainPrefs.EEG.samplesacquired] > gMainPrefs.highAnalogTriggerThresholdRaw) then
                        digitalChannel := digitalChannel + 16384;
                     if (gMainPrefs.EEG.samples[0][gMainPrefs.EEG.samplesacquired] < gMainPrefs.lowAnalogTriggerThresholdRaw) then
                        digitalChannel := digitalChannel + 32768;
                  end;
                  if (gMainPrefs.DigitalChannel) then
                     gMainPrefs.EEG.samples[gMainPrefs.AnalogChannels][gMainPrefs.EEG.samplesacquired] := digitalChannel;
                  gMainPrefs.EEG.samplesacquired := gMainPrefs.EEG.samplesacquired+1;
                  if gMainPrefs.EEG.samplesacquired > gMainPrefs.EEG.maxsamples then begin
                     gMainPrefs.EEG.samplesacquired := gMainPrefs.EEG.maxsamples;
                     MainForm.sampleTimer.Enabled := false;
                     MainForm.StopRecording;
                     MainForm.RecordItem.Caption:= 'Start Recording';
                     Showmessage('Warning: maximum session duration exceeded. Please start a new session. Please check for a new software version that continuously saves data.');
                     //gMainPrefs.EEG.samplesacquired := 0;
                  end;


                  if (gMainPrefs.DigitalCurrent <> DigitalChannel) then begin
                        if (DigitalChannel > gMainPrefs.DigitalCurrent) then begin //value increased - event onset detected
                           gMainPrefs.LastDigitalOnsetSample:= gMainPrefs.EEG.samplesacquired;
                           gMainPrefs.LastDigitalOnset:= DigitalChannel;
                           gTriggerGraph.lastSample :=  gMainPrefs.EEG.samplesacquired+gMainPrefs.samplesPerGraph;
                           if (gTriggerGraph.lastSample > gMainPrefs.EEG.maxsamples) then
                              gTriggerGraph.firstSample := gMainPrefs.EEG.maxsamples;
                           gTriggerGraph.firstSample := gTriggerGraph.lastSample-gMainPrefs.samplesPerGraph;
                           if (gTriggerGraph.firstSample < 1) then
                              gTriggerGraph.firstSample := 1;
                           gMainPrefs.UpdateTriggerGraphSample := gTriggerGraph.lastSample;
                           gTriggerGraph.BigText := inttostr(gMainPrefs.LastDigitalOnset)+'@'+inttostr(gMainPrefs.LastDigitalOnsetSample);
                           AddVMRK(DigitalChannel - gMainPrefs.DigitalCurrent, gMainPrefs.EEG.samplesacquired, gVMRK);

                        end; //if digitalByte increase
                        gMainPrefs.DigitalCurrent := DigitalChannel;
                  end; // if gMainPrefs.DigitalCurrent <> digitalByte
             end;  //new samples
             pos := pos + packetBytes;
             samples := samples + 1;
             //if (samples >= kMaxSamples)
             //    samples = 0;
         end else begin//checksum matches
             //the checksum does not match - disregard oldest byte and try again
             pos := pos + 1;
             //MainForm.StatusBar1.Panels[1].Text:='xxxxxx'+inttostr(len)+'  '+inttostr(random(888));
         end;
     end;//while potential blocks to read
    if (pos >= len) then
        setlength(gMainPrefs.SerialBuffer,0)
     else begin
         len := len-pos;
         setlength(tempBuffer,len);
         for c :=0 to (len-1) do
             tempBuffer[c] :=  gMainPrefs.SerialBuffer[pos+c];
        setlength(gMainPrefs.SerialBuffer,len);
         for c :=0 to (len-1) do
             gMainPrefs.SerialBuffer[c] := tempBuffer[c];
         tempBuffer := nil;
     end;
end;

function isCmd (position: integer): boolean ;
var
    c: integer;
begin
  result := false;
  if (position+kCmdBytes) > length(gMainPrefs.SerialBuffer) then exit; //to short to be a command
  if ((gMainPrefs.SerialBuffer[position] <> kCmd1Set) and (gMainPrefs.SerialBuffer[position] <> kCmd1Get))  then exit; //first byte not a command signature
  if ((gMainPrefs.SerialBuffer[position] = kCmd1Set) and   (gMainPrefs.SerialBuffer[position+1] in [kCmd2Mode,kCmd2KeyDown,kCmd2KeyUp,kCmd2KeyTrigger,kCmd2OscHz,kCmd2OscChannels,kCmd2OscSuperSampling])) then begin
     result := true; //valid set command, which we will ignore
     //caption := 'ignored set command';
     exit;
  end;
  if (gMainPrefs.SerialBuffer[position] = kCmd1Set) then exit; //unknown Set command
  case gMainPrefs.SerialBuffer[position+1] of
       kCmd2Mode : begin //Arduino is reporting its MODE
             result := true;
       end; //Cmd2Mode
       kCmd2KeyDown : begin //Arduino is reporting key press mapping
             result := true;
       end; //Camd2KeyDown
       kCmd2KeyUp : begin //Arduino is reporting key release mapping
             result := true;
       end; //Cmd2KeyUp
       kCmd2KeyTrigger : begin //Arduino is reporting key binding mapping
             result := true;
       end; //Cmd2KeyTrigger
       kCmd2NumAnalogKeys : begin //Arduino is reporting key binding mapping
            //not required
             result := true;
       end;
       kCmd2OscHz : begin
             //not required
            gHzResp := (gMainPrefs.SerialBuffer[position+2]  shl 8) + gMainPrefs.SerialBuffer[position+3];
             result := true;
       end; //Cmd2OscHz
       kCmd2OscChannels : begin
            gChannelsResp := (gMainPrefs.SerialBuffer[position+2]  shl 8) + gMainPrefs.SerialBuffer[position+3];
            //not required
             result := true;
       end; //Cmd2OscChannels
       kCmd2OscSuperSampling : begin
            result := true; //not required
       end;
  end;
end;

procedure checkResp; //see if Arduino has reported Hz or Channels
var
   pos, len: integer;
begin
  len := length(gMainPrefs.SerialBuffer)-kCmdBytes;
  //if len < 0 then exit;
  pos := 0;
  while pos <= len do begin
        if isCmd(pos) then
           pos := pos + kCmdBytes
        else
            pos := pos + 1;
  end;
  //MainForm.Caption := inttostr(gHzResp)+'  '+inttostr(gChannelsResp);

end;

procedure ReadBuffer;
type
	byteRA0 = array [0..0] of byte;
        Bytep0 = ^ByteRA0;
const
  kBufSz = 4096;
var
  buffer: Bytep0;
  recvSize, totalSize, i,t : integer;
begin
  totalSize := length(gMainPrefs.SerialBuffer);
  getmem(buffer,kBufSz);
  t := 0;
  repeat
   recvSize := gMainPrefs.ser.RecvBufferEx(buffer, kBufSz, 0);
   if (recvSize > 0) then begin
      inc(t);
      SetLength(gMainPrefs.SerialBuffer, totalSize+ recvSize);
      for i := 0 to (recvSize -1) do
          gMainPrefs.SerialBuffer[totalSize+i] := buffer[i];
      totalSize := totalSize + recvSize;
   end;
  until (recvSize < kBufSz);
  freemem(buffer);
  if mainform.initTimer.Enabled then
     checkResp;
  DecodeBuffer;
end;

procedure TMainForm.WriteCmd (setNotGet: boolean; Cmd2, Cmd3, Cmd4: byte);
var
     serialBytes: array of byte;
begin
     setLength(serialBytes,kCmdBytes);
     if setNotGet then
        serialBytes[0] := kCmd1Set
     else
         serialBytes[0] := kCmd1Get;
     serialBytes[1] := Cmd2;
     serialBytes[2] := Cmd3;
     serialBytes[3] := Cmd4;
     gMainPrefs.ser.SendBuffer(serialBytes, 4);
     serialBytes := nil; //release memory - not required due to reference counting
end;

procedure TMainForm.StopRecording;
begin
     RecordItem.Caption:= 'Start Recording';
     sampleTimer.Enabled := false;
     WriteCmd(true,kCmd2Mode,kCmd34ModeKey,kCmd34ModeKey); //set to Osc Mode
     if (gMainPrefs.UnsavedData) and (gMainPrefs.AutoSave) then
        SaveCore (true);
     SaveMenu.Enabled := gMainPrefs.UnsavedData;
end;

procedure TMainForm.initTimerTimer(Sender: TObject);
var
  str: string;
begin
     readBuffer;
     if (initTimer.Tag < 0) or (gChannelsResp = 0) or (gHzResp = 0) then begin
     	initTimer.Tag := 0; //lets wait one more interval - perhaps a Windows Lazarus bug, but first timer can occur in less time than interval
        exit;
     end;
     initTimer.Enabled := false;
     if  (gChannelsResp > 0) and  (gMainPrefs.AnalogChannels <> gChannelsResp) then begin
        StopRecording;
        showmessage('Wrong number of channels (expected '+inttostr(gMainPrefs.AnalogChannels)+' received '+inttostr(gChannelsResp)+'). Perhaps the Arduino can not support this many channels.' );
        exit;
     end;
     if (gHzResp > 0) and  (gMainPrefs.sampleRateHz <> gHzResp) then begin
        StopRecording;
        showmessage('Wrong sampling rate (expected '+inttostr(gMainPrefs.sampleRateHz)+' received '+inttostr(gHzResp)+'). Perhaps this Arduino can not support this many channels.' );
        exit;
     end;

     if (initTimer.Tag = 0) or (gChannelsResp = 0) or (gHzResp = 0) then begin
        StopRecording;
        showmessage('No data received. Please check power, drivers, Arduino sketches and preferences. '+PrefForm.ComPortDrop.Text);
        exit;
     end;

     gMainPrefs.UpdateTriggerGraphSample := maxint;

     str := '';
     if (gMainPrefs.sampleRateHzObs = 0) then begin
        gMainPrefs.sampleRateHzObs := round((initTimer.Tag+1)/(initTimer.interval/1000) );    //plus 1 as we start from -1 not zero
        if gMainPrefs.sampleRateHzObs < 1 then
          gMainPrefs.sampleRateHzObs := 1;
        //str := '(est '+inttostr(gMainPrefs.sampleRateHzObs)+')';
     end;

     gMainPrefs.samplesPerGraph :=  round(gMainPrefs.TimelineMS /(1000/gMainPrefs.sampleRateHz));
     if (gMainPrefs.samplesPerGraph < 3) then
       gMainPrefs.samplesPerGraph := 3;
     str := str+ ' GraphDuration(ms): '+inttostr(round(gMainPrefs.samplesPerGraph*1000/gMainPrefs.sampleRateHz));
     StatusBar1.Panels[2].Text:='channels: '+inttostr(gMainPrefs.AnalogChannels)+' sampleHz: '+inttostr(gMainPrefs.sampleRateHz)+str;
     if gMainPrefs.DigitalChannel then
       CreateEEG(gMainPrefs.EEG, gMainPrefs.AnalogChannels+1,kMaxSec*gMainPrefs.sampleRateHz, gMainPrefs.sampleRateHz, gMainPrefs.highPassFreqHz)
     else
       CreateEEG(gMainPrefs.EEG, gMainPrefs.AnalogChannels,kMaxSec*gMainPrefs.sampleRateHz, gMainPrefs.sampleRateHz, gMainPrefs.highPassFreqHz);
     SetCalibration(gMainPrefs);
     {$IFDEF VMRK}
    CreateEmptyVMRK(gVMRK, kMaxVMRK);
    {$ENDIF}
     gCurrentGraph.bigText := '';
     gMainPrefs.Recording := true;
     gMainPrefs.UnsavedData:= true;
     sampleTimer.enabled := true;
     gMainPrefs.RecStartTime:= Now;
     gMainPrefs.RecSec := 0;
end;

procedure TMainForm.SaveMenuClick(Sender: TObject);
begin
  SaveCore(false);
end;

procedure TMainForm.StartBtnClick(Sender: TObject);
begin

     if (sampleTimer.Enabled) then begin
        StopRecording;
        exit;
     end;
     //stop any processing
     sampleTimer.Enabled := false;
     initTimer.Enabled := false;
     gMainPrefs.Recording := false;
     PrefForm.SetPrefs (gMainPrefs);
     if (PrefForm.showmodal <> mrOK) then  exit;//   <----  START RECORDING HERE

     PrefForm.GetPrefs (gMainPrefs);
     gMainPrefs.sampleRateHzObs := 0;
     RecordItem.Caption:='Stop Recording';

     setlength(gMainPrefs.SerialBuffer,0);
     //TimelineMSEdit.value;
     FreeEEG(gMainPrefs.EEG);
     gMainPrefs.ser.Connect(PrefForm.ComPortDrop.Text);
     //gMainPrefs.ser.Config(57600,8,'N',0,false,false);
     gMainPrefs.ser.Config(115200,8,'N',0,false,false);
     setlength(gMainPrefs.SerialBuffer,0);
     if (gMainPrefs.sampleRateHz < 10) then gMainPrefs.sampleRateHz :=  10;

     WriteCmd(true,kCmd2OscChannels,(gMainPrefs.AnalogChannels shr 8),(gMainPrefs.AnalogChannels and $FF)); //set number of channels
     WriteCmd(true,kCmd2OscHz,(gMainPrefs.sampleRateHz shr 8),(gMainPrefs.sampleRateHz and $FF)); //set sampling rate
     WriteCmd(false,kCmd2OscChannels,(gMainPrefs.AnalogChannels shr 8),(gMainPrefs.AnalogChannels and $FF)); //set number of channels
     WriteCmd(false,kCmd2OscHz,(gMainPrefs.sampleRateHz shr 8),(gMainPrefs.sampleRateHz and $FF)); //set sampling rate
     WriteCmd(false,kCmd2OscSuperSampling,(gMainPrefs.superSampling shr 8),(gMainPrefs.superSampling and $FF)); //set super sampling rate
     //check hardware
          gHzResp := 0;
     gChannelsResp := 0;
     WriteCmd(true,kCmd2Mode,kCmd34ModeOsc,kCmd34ModeOsc); //GET Osc Mode
     MainForm.StatusBar1.Panels[2].Text:='Hz: '+inttostr(gMainPrefs.sampleRateHz);

     initTimer.Tag := -1; //detect samples...
     initTimer.Enabled := true;
end;

procedure FilterSamples(var EEG: TEEG);
var
  i,c, numChannels: Integer;
begin
  if (EEG.samplesacquired >= EEG.maxsamples) or (EEG.samplesacquired <= EEG.samplesprocessed) then
    exit; //no new samples to process
  numChannels := EEG.numChannels;
  if gMainPrefs.DigitalChannel then
       numChannels := numChannels-1; //do not temporal filter digital data!
  if numChannels < 1 then
       exit;
  //transform raw data to calibrated voltages....
  for i := EEG.samplesprocessed to EEG.samplesacquired-1 do
      for c := 0 to numChannels-1 do
          EEG.samples[c][i] := (EEG.samples[c][i] * gMainPrefs.raw2CalSlope) + gMainPrefs.raw2CalIntercept;
  //transform calibrated voltages to screen values [range -1..+1]
  for i := EEG.samplesprocessed to EEG.samplesacquired-1 do
      for c := 0 to numChannels-1 do
          EEG.filtered[c][i] := (EEG.samples[c][i] * gMainPrefs.cal2DisplaySlope) + gMainPrefs.cal2DisplayIntercept;
  //add processing here....
  //scale output for -1.0..1.0 with midrange at 0.0
  (*if gMainPrefs.Precision16bit then
    for i := EEG.samplesprocessed to EEG.samplesacquired-1 do
      for c := 0 to numChannels-1 do
          EEG.filtered[c][i] := (EEG.samples[c][i]-32767.5) / 32767.5
  else
    for i := EEG.samplesprocessed to EEG.samplesacquired-1 do
      for c := 0 to numChannels-1 do
          EEG.filtered[c][i] :=    (EEG.samples[c][i]-511.5) / 511.5;
  *)
  //apply filter
  if EEG.Channels[c].HighPass.Freq <> 0 then begin
     for c := 0 to numChannels-1 do
         for i := EEG.samplesprocessed to EEG.samplesacquired-1 do //-1: indexed from 0
             EEG.filtered[c][i] := EEG.Channels[c].HighPass.Process(EEG.filtered[c][i]);
  end;
  //next: clip channels to range -1..+1
  for c := 0 to numChannels-1 do
      for i := EEG.samplesprocessed to EEG.samplesacquired-1 do //-1: indexed from 0
          if EEG.filtered[c][i] > 1 then
             EEG.filtered[c][i] := 1
          else if EEG.filtered[c][i] < -1 then
             EEG.filtered[c][i] := -1 ;
  EEG.samplesprocessed := EEG.samplesacquired;
end;

procedure ReportElapsedSec;
var
  time: integer;
begin
  time := round(86400 * (Now-gMainPrefs.RecStartTime));  //86400 seconds per day
  if (time = gMainPrefs.RecSec) then
     exit;
  gMainPrefs.RecSec := time;
  MainForm.StatusBar1.Panels[0].Text := formatdatetime('hh:nn:ss',Now-gMainPrefs.RecStartTime);
end;

procedure ReportDigital;
begin

  MainForm.StatusBar1.Panels[1].Text := inttostr(gMainPrefs.LastDigitalOnset)+'@'+inttostr(gMainPrefs.LastDigitalOnsetSample);
end;

procedure TMainForm.sampleTimerTimer(Sender: TObject);
var
  samples, digitalSample: integer;
begin
  digitalSample := gMainPrefs.LastDigitalOnsetSample;
  samples := gMainPrefs.EEG.samplesacquired;
  ReadBuffer;
  ReportElapsedSec;
  if (digitalSample <> gMainPrefs.LastDigitalOnsetSample ) then //a new digital trigger was detected - report it
     ReportDigital;
  if (samples = gMainPrefs.EEG.samplesacquired) then exit; //no new samples - no need to update graph
  FilterSamples(gMainPrefs.EEG);
  gCurrentGraph.lastSample :=  gMainPrefs.EEG.samplesprocessed;
  gCurrentGraph.firstSample := gCurrentGraph.lastSample-gMainPrefs.samplesPerGraph;
  if (gCurrentGraph.firstSample < 1) then
    gCurrentGraph.firstSample := 1;
  DrawGraph(CurrentImage, gMainPrefs.EEG, gGraphPrefs, gCurrentGraph.firstSample, gCurrentGraph.lastSample, gCurrentGraph.bigText, gMainPrefs.DigitalChannel);
  if (gMainPrefs.EEG.samplesacquired > gMainPrefs.UpdateTriggerGraphSample ) then begin
     gMainPrefs.UpdateTriggerGraphSample := maxint;
     DrawGraph(TriggerImage, gMainPrefs.EEG, gGraphPrefs, gTriggerGraph.firstSample, gTriggerGraph.lastSample, gTriggerGraph.bigText, gMainPrefs.DigitalChannel);
  end;

end;

procedure TMainForm.FormCreate(Sender: TObject);
const
  kDummySamples = 200;
  ksampleHz = 100;
  khighPassFreqHz = 15;
begin
  //Double buffering reduces screen flicker during updates...
  MainForm.DoubleBuffered := true;
  PairSplitterSide1.DoubleBuffered := true;
  PairSplitterSide2.DoubleBuffered := true;
  StatusBar1.DoubleBuffered := true;
  {$IFDEF DARWIN} //Mac OSX has a different menu style
        HelpMenu.visible := false;//Hide Help menu - place in Apple menu
        QuitMenu.Visible := false;
  		// Add 'Apple' Menu
        AppMenu := TMenuItem.Create(Self);  // Application menu
        AppMenu.Caption := #$EF#$A3#$BF;    // Unicode Apple logo char
        MainMenu1.Items.Insert(0, AppMenu);
        // Add 'About' as item in application menu
        AppAboutCmd := TMenuItem.Create(Self);
        AppAboutCmd.Caption := 'About... ';// + BundleName;  // Bundlename is the name of one of your global variables.
        AppAboutCmd.OnClick := AboutItemClick;         // mnuAboutClick is the procedure to show the AboutBox.
        AppMenu.Add(AppAboutCmd);
        // Add 'About' as item in application menu
        AppQuitCmd := TMenuItem.Create(Self);
        AppQuitCmd.Caption := 'Quit';// + BundleName;  // Bundlename is the name of one of your global variables.
        AppQuitCmd.OnClick := QuitMenuClick;         // mnuAboutClick is the procedure to show the AboutBox.
        AppMenu.Add(AppQuitCmd);
  {$ENDIF}
  StatusBar1.Panels[0].Text := '00:00:00';
  StatusBar1.Panels[1].Text := 'No triggers';
  StatusBar1.Panels[2].Text := 'Choose File/Record to acquire new data';
  //initialize defaults
  SetDefaultPrefs(gMainPrefs);
  IniFile(true, IniName, gMainPrefs);
  setlength(gMainPrefs.SerialBuffer,0);
  gMainPrefs.ser:=TBlockserial.Create;
  gGraphPrefs := DefaultPrefs;
  Application.ShowButtonGlyphs:= sbgNever;
  //create fake data
  CreateEEG(gMainPrefs.EEG, kMaxChannels,kMaxSec*ksampleHz, ksampleHz,khighPassFreqHz);
  SetCalibration(gMainPrefs);
  DummyData(gMainPrefs.EEG, kDummySamples);
  FilterSamples(gMainPrefs.EEG); //filter data
  //display fake data
  gCurrentGraph.firstSample := 1;
  gCurrentGraph.lastSample := MaxNumSamples(gMainPrefs.EEG);
  gCurrentGraph.bigText := 'OFFLINE';
  gTriggerGraph.firstSample := 1;
  gTriggerGraph.lastSample := MaxNumSamples(gMainPrefs.EEG);
  gTriggerGraph.bigText := 'NO TRIGGERS';
  RefreshGraphs;
end;

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
     if (sampleTimer.Enabled) then begin
        StopRecording;
        exit;
     end;
  initTimer.Enabled := false;
  sampleTimer.Enabled := false;
  FreeEEG(gMainPrefs.EEG);
  gMainPrefs.ser.Free;
  gMainPrefs.SerialBuffer := nil;
  IniFile(false, IniName, gMainPrefs);
end;

procedure TMainForm.FormResize(Sender: TObject);
begin
     SetDimension(TriggerImage, TriggerImage.Height, TriggerImage.Width);
     SetDimension(CurrentImage, CurrentImage.Height, CurrentImage.Width);
     RefreshGraphs;
     //PairSplitter1.Position := PairSplitter1.Height - PairSplitter1.Position;
end;


procedure TMainForm.PairSplitter1ChangeBounds(Sender: TObject);
begin
     //FormResize(Sender);
end;

procedure TMainForm.PairSplitter1Resize(Sender: TObject);
begin
     //
end;

procedure TMainForm.PairSplitterSide1Resize(Sender: TObject);
begin
     FormResize(Sender);
end;

procedure TMainForm.RecordItemClicks(Sender: TObject);
begin

end;

procedure TMainForm.QuitMenuClick(Sender: TObject);
begin
 Close;
end;

end.

