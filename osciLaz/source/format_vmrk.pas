unit format_vmrk;
//support for BrainProducts VHDR format ..

interface
uses eeg_type, sysutils,dialogs, DateUtils,IniFiles, StrUtils,classes;

 type
  TEvent = record
      Typ,Desc: string;
      OnsetSamp,DurationSamp,Channel : integer;
   end;
  TVMRK = record
      Datafile: string;
      CurrentEvent: integer;
      Events: array of TEvent;
   end;

function LoadVMRK(lFilename: string; var lV: TVMRK): boolean;
function WriteVMRK(lFilename: string; var lV: TVMRK): boolean;
//function LoadVMRKdummy(var lV: TVMRK): boolean;
function CreateEmptyVMRK(var lV: TVMRK; N: integer): boolean;


implementation

function WriteVMRK(lFilename: string; var lV: TVMRK): boolean;
var
  t,lN: integer;
  lVMRK: TStringList;
begin
  result := false;
  lN := length(lV.Events);
  if lN < 1 then
    exit;
  lVMRK := TStringList.Create;
  lVMRK.Add('Brain Vision Data Exchange Marker File, Version 1.0');
  lVMRK.Add('[Common Infos]');
  //showmessage(lV.DataFile);
  if lV.Datafile <> '' then
    lVMRK.Add('DataFile='+lV.Datafile);
  lVMRK.Add('[Marker Infos]');
  lVMRK.Add('; Each entry: Mk{Marker number}={Type},{Description},{Position in data points},');
  lVMRK.Add('; {Size in data points}, {Trace number (0 = marker is related to all Traces)}');
  lVMRK.Add('; Fields are delimited by commas, some fields might be omitted (empty).');
  for t := 0 to lN-1 do
    lVMRK.Add('Mk'+inttostr(t+1)+'=Stimulus, '+lV.Events[t].Desc+', '+inttostr(lV.Events[t].OnsetSamp)+', '+inttostr(lV.Events[t].DurationSamp)+', '+inttostr(lV.Events[t].Channel));
  //lFilename :=  extractfiledir(paramstr(0))+'\tms_'+ (FormatDateTime('yyyymmdd_hhnnss', (now)))+'.tab';
  lVMRK.SaveToFile(lFilename);
   //Clipboard.AsText:= lVMRK.Text;
  lVMRK.free;
  result := true;
end;


{    TEvent = record
      Typ,Desc: string;
      OnsetSamp,DurationSamp,Channel : integer;
   end;

  for t := 0 to n-1 do begin
    lV.Events[t].Typ:= 'Stimulus';
    lV.Events[t].Desc := inttostr(t)+'desc';
    lV.Events[t].OnsetSamp := (t) * 2048* 10;
    lV.Events[t].DurationSamp := 204;
    lV.Events[t].Channel := 0;
  end; }

function NextCSV(lStr: string; var lP: integer): string;
//reports text prior to comma...
var
 len: integer;
begin
  result := '';
  len := length(lStr);
  if len < lP then exit;
  repeat
    if lStr[lP] = ',' then begin
      lP := lP + 1;
      exit;
    end;
    if lStr[lP] <> ' ' then
      result := result + lStr[lP];
    lP := lP + 1;
  until (lP > len);
end;

procedure ReadEvent(lIniFile: TIniFile; lSection, lIdent: string; var lV: TEvent);
//read or write a string value to the initialization file
var
  lS: string;
  lP: integer;
begin
	lS := lIniFile.ReadString(lSection,lIdent, '');
  if lS = '' then
    exit;
  //Stimulus, Cond2, 0, 307, 0
  lP := 1;
  lV.Typ :=  NextCSV(lS, lP);
  lV.Desc :=  NextCSV(lS, lP);
  lV.OnsetSamp := StrToInt(NextCSV(lS, lP));
  lV.DurationSamp := StrToInt(NextCSV(lS, lP));
  lV.Channel := StrToInt(NextCSV(lS, lP));
end; //IniStr

function LoadVMRK(lFilename: string; var lV: TVMRK): boolean;
const
  lRead = true;
var
  lIniFile: TIniFile;
  t,N: integer;
  lS: string;
begin
  result := false;
  if (not Fileexists(lFilename)) then
        exit;
  lIniFile := TIniFile.Create(lFilename);
  lV.Datafile := lIniFile.ReadString('Common Infos','DataFile','');
  N := 0;
  repeat
    inc(N);
    lS := lIniFile.ReadString('Marker Infos','Mk'+inttostr(N),'');
  until (lS = '');
  dec(N);
  lIniFile.Free;
  if N < 1 then
    exit;
  //2nd passs: read events
  setlength(lV.Events,n);
  lIniFile := TIniFile.Create(lFilename);
  lV.Datafile := lIniFile.ReadString('Common Infos','DataFile','');
  for t := 1 to N do
    ReadEvent(lIniFile,'Marker Infos','Mk'+inttostr(t),lV.Events[t-1]);
  lIniFile.Free;
end;

function CreateEmptyVMRK(var lV: TVMRK; N: integer): boolean;
var
  t: integer;
begin
  //result := false;
  //if not Fileexists(lFilename) then
  //  exit;
  lV.Datafile := 'Test';
  lV.CurrentEvent := 0;
  //n := 30;
  setlength(lV.Events,n);
  for t := 0 to n-1 do begin
    lV.Events[t].Typ:= 'Stimulus';
    lV.Events[t].Desc := 'Cond'+inttostr(t);
    lV.Events[t].OnsetSamp := (t) * 2048* 10;
    lV.Events[t].DurationSamp := 100;
    lV.Events[t].Channel := 0;
  end;
  result := true;
end;



end.
