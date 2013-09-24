unit mainprefs;
{$H+}
interface
uses
  {$IFDEF FPC}
  {$IFDEF UNIX} BaseUnix,{$ENDIF}
  {$IFDEF GUI}LResources, {$ENDIF}
  
  {$ELSE}
   SelectFolder,
{$ENDIF}
  inifiles,SysUtils, userdir, eeg_type, synaser, Dialogs;
type

TMainPrefs = record
   EEG: TEEG;
   RecStartTime: TDateTime;
   AnalogChannels,RecSec,DigitalCurrent,  LastDigitalOnset ,LastDigitalOnsetSample,UpdateTriggerGraphSample : integer;
   customMinMax, AutoSave, //Precision16bit,
   Recording,UnsavedData, DigitalChannel, detectAnalogTriggers : boolean;
   ser:TBlockSerial;
   highAnalogTriggerThresholdRaw, lowAnalogTriggerThresholdRaw, calibratedMin, calibratedMax, displayMin, displayMax, highPassFreqHz, highAnalogThreshold, lowAnalogThreshold, raw2CalSlope,
   raw2CalIntercept, cal2DisplaySlope, cal2DisplayIntercept: single;
   TimelineMS,sampleRateHz,sampleRateHzObs,superSampling,triggerPosition, samplesPerGraph : integer;
   autoSaveDir: string;
   SerialBuffer: array of byte;
end;
 procedure SetCalibration (var lPrefs: TMainPrefs);
procedure SetDefaultPrefs (var lPrefs: TMainPrefs);
function IniFile(lRead: boolean; lFilename: string; var lPrefs: TMainPrefs): boolean;

implementation

procedure SetCalibration (var lPrefs: TMainPrefs);
//sets transform for raw data to calibrated voltages: raw2CalSlope, raw2CalIntercept
//sets transform for calibrated data to calibrated voltages:  cal2DisplaySlope, cal2DisplayIntercept
var
  min, max, range, outrange: single;
begin
 //raw is 0..1023 for 10 bit, 0..65535 for 16bit
 min := 0;
    max := 65535;
 range := max-min;
 if (not lPrefs.customMinMax) or (lPrefs.calibratedMax <= lPrefs.calibratedMin) then begin
    lPrefs.raw2CalSlope := 1.0;
    lPrefs.raw2CalIntercept := 0;
 end else begin
   outrange := lPrefs.calibratedMax - lPrefs.calibratedMin;
   lPrefs.raw2CalSlope := outrange/range;
   lPrefs.raw2CalIntercept := lPrefs.calibratedMin - (min*lPrefs.raw2CalSlope);

   if (lPrefs.displayMin < lPrefs.displayMax) then begin
      min := lPrefs.displayMin;
      max := lPrefs.displayMax;
   end else begin
       min :=  lPrefs.calibratedMin;
       max :=  lPrefs.calibratedMax;
   end;
 end;
 if lPrefs.raw2CalSlope = 0 then lPrefs.raw2CalSlope:= 1.0; //if clauses above ensure this line will never be called - just reminder that raw2CalSlope must not be zero
 lPrefs.highAnalogTriggerThresholdRaw := 66666; //initialize as impossible threshold: raw signal is 0..1023 or 0..65535 for 10/16 bit samples
 lPrefs.lowAnalogTriggerThresholdRaw := 0; //initialize as impossible threshold: raw signal is 0..1023 or 0..65535 for 10/16 bit samples
 if (lPrefs.detectAnalogTriggers) and ( lPrefs.customMinMax) then begin
    //compute trigger threshold in raw units...
    //raw to calibrated
    //  cal := (raw * raw2CalSlope) + raw2CalIntercept;
    //calibrated to raw
    //  raw := (cal-raw2CalIntercept)/ raw2CalSlope
    lPrefs.highAnalogTriggerThresholdRaw := (lPrefs.highAnalogThreshold-lPrefs.raw2CalIntercept)/lPrefs.raw2CalSlope;
     lPrefs.lowAnalogTriggerThresholdRaw := (lPrefs.lowAnalogThreshold-lPrefs.raw2CalIntercept)/lPrefs.raw2CalSlope;
 end;
 lPrefs.DigitalCurrent := 0; //assume no trigger sensed
 //display range must be -1..+1
 outrange := 1- -1;
 lPrefs.cal2DisplaySlope := outrange/(max-min);
 lPrefs.cal2DisplayIntercept := -1 - (min*lPrefs.cal2DisplaySlope );
 //raw2CalSlope, raw2CalIntercept, cal2DisplaySlope, cal2DisplayIntercept
end;

procedure SetDefaultPrefs (var lPrefs: TMainPrefs);
begin
 with lPrefs do begin
   //integers
   AnalogChannels := 3;
   sampleRateHz := 500;
   superSampling := 0;
   timelineMS := 1000;
   triggerPosition := 0;
   //bools
   digitalChannel := true;
   autoSave := false;
   detectAnalogTriggers := false;
   //floats
   highPassFreqHz := 0.0;
   lowAnalogThreshold := -40.0;
   highAnalogThreshold := 40.0;
   //str
   autoSaveDir := UserDataFolder;
   //just for dummy data....
   sampleRateHzObs:= 0;
   UnsavedData := false;
   customMinMax := false;
   displayMin := -45;
   displayMax := 45;
   calibratedMin := -50;
   calibratedMax := 50;
 end; //with lPrefs
end;//proc SetDefaultPrefs

procedure IniFloat(lRead: boolean; lIniFile: TIniFile; lIdent: string;  var lValue: single);
//read or write an integer value to the initialization file
var
	lStr: string;
begin
        if not lRead then begin
           lIniFile.WriteString('FLT',lIdent,FloattoStr(lValue));
           exit;
        end;
	lStr := lIniFile.ReadString('FLT',lIdent, '');
	if length(lStr) > 0 then
		lValue := StrToFloat(lStr);
end; //IniFloat

procedure IniInt(lRead: boolean; lIniFile: TCustomIniFile; lIdent: string;  var lValue: integer);
//read or write an integer value to the initialization file
var
	lStr: string;
begin
        if not lRead then begin
           lIniFile.WriteString('INT',lIdent,IntToStr(lValue));
           exit;
        end;
	lStr := lIniFile.ReadString('INT',lIdent, '');
	if length(lStr) > 0 then
		lValue := StrToInt(lStr);
end; //IniInt

function Bool2Char (lBool: boolean): char;
begin
	if lBool then
		result := '1'
	else
		result := '0';
end;

function Char2Bool (lChar: char): boolean;
begin
	if lChar = '1' then
		result := true
	else
		result := false;
end;

procedure IniBool(lRead: boolean; lIniFile: TCustomIniFile; lIdent: string;  var lValue: boolean);
//read or write a boolean value to the initialization file
var
	lStr: string;
begin
        if not lRead then begin
           lIniFile.WriteString('BOOL',lIdent,Bool2Char(lValue));
           exit;
        end;
	lStr := lIniFile.ReadString('BOOL',lIdent, '');
	if length(lStr) > 0 then
		lValue := Char2Bool(lStr[1]);
end; //IniBool

procedure IniStr(lRead: boolean; lIniFile: TCustomIniFile; lIdent: string; var lValue: string);
//read or write a string value to the initialization file
begin
  if not lRead then begin
    lIniFile.WriteString('STR',lIdent,lValue);
    exit;
  end;
	lValue := lIniFile.ReadString('STR',lIdent, '');
end; //IniStr

procedure msg (s: string);
begin
 showmessage(s);
end;

function IniFile(lRead: boolean; lFilename: string; var lPrefs: TMainPrefs): boolean;
//Read or write initialization variables to disk
var
  lIniFile: TMemIniFile;
  s: string;
begin
  result := false;
  if (lRead) and (not Fileexists(lFilename)) then
        exit;
  {$IFDEF UNIX}  //Uses BaseUnix;
  if (lRead) and (fpAccess (lFilename,R_OK)<>0) then begin//ensure user has read-access to prefs file...
    msg('Unable to load preferences: no write access for '+lFilename);
    exit;
  end;
  {$ENDIF}
  if (lRead) then begin
     Filemode := 0; //Readonly
     //msg('reading preferences file '+lFilename);
  end else
      Filemode := 2; //Read-Write
  lIniFile := TMemIniFile.Create(lFilename);
  //integers
   IniInt(lRead,lIniFile,'AnalogChannels',lPrefs.AnalogChannels);
   IniInt(lRead,lIniFile,'sampleRateHz',lPrefs.sampleRateHz);
   IniInt(lRead,lIniFile,'superSampling',lPrefs.superSampling);
  IniInt(lRead,lIniFile,'timelineMS',lPrefs.timelineMS);
  IniInt(lRead,lIniFile,'triggerPosition',lPrefs.triggerPosition);
  //bools
  IniBool(lRead,lIniFile,'digitalChannel',lPrefs.digitalChannel);
  IniBool(lRead,lIniFile,'autoSave',lPrefs.autoSave);
  IniBool(lRead,lIniFile,'detectAnalogTriggers',lPrefs.detectAnalogTriggers);
  IniBool(lRead,lIniFile,'customMinMax',lPrefs.customMinMax);
  //floats
  IniFloat(lRead,lIniFile,'highPassFreqHz',lPrefs.highPassFreqHz);
  IniFloat(lRead,lIniFile,'highAnalogThreshold',lPrefs.highAnalogThreshold);
  IniFloat(lRead,lIniFile,'lowAnalogThreshold',lPrefs.lowAnalogThreshold);
  IniFloat(lRead,lIniFile,'calibratedMin',lPrefs.calibratedMin);
  IniFloat(lRead,lIniFile,'calibratedMax',lPrefs.calibratedMax);
  IniFloat(lRead,lIniFile,'displayMin',lPrefs.displayMin);
  IniFloat(lRead,lIniFile,'displayMax',lPrefs.displayMax);
  //str
  s := lPrefs.autoSaveDir;
  IniStr(lRead,lIniFile,'autoSaveDir',s);
  if not fileexists(s) then
          lPrefs.autoSaveDir := UserDataFolder;
  if not lRead then
    lIniFile.UpdateFile;
  lIniFile.Free;
  if (lRead) then
     Filemode := 2; //Read-write
end;

end.


