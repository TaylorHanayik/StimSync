unit format_vhdr;
{$mode delphi}
//support for BrainProducts VHDR format ..
interface
uses eeg_type, sysutils,dialogs, DateUtils;

function WriteVHDR(lFilename: string; var lEEG: TEEG): boolean;

implementation

function SaveASCII (lFilename: string; var lEEG: TEEG; VECTORIZED: boolean): boolean;
const
  kDelim = Chr(9);//tab
var
  f : TextFile;
  str: string;
  c,s,nc,nS: integer;
begin
  result := false;
  NC := NumChannels(lEEG);
  NS := NumSamplesZeroIfVariable(lEEG);
  if (NC < 1) or (NS < 1) then
    exit;
  decimalseparator := '.';
  filemode := (2);
  AssignFile(f,lFilename);
  ReWrite(f);
  //data...
  if VECTORIZED then begin
    for c := 0 to nc-1 do begin
      for s := 0 to ns -1 do begin
        write(f,floattostr(lEEG.Samples[c][s]));
        if c < (nc-1) then
          write(f,kDelim);
    end;//each signal
    WriteLn(f,'');
   end;
  end else begin
   for s := 0 to ns -1 do begin
    str := '';
    for c := 0 to nc-1 do begin
        str := str+floattostr(lEEG.Samples[c][s]);
      if c < (nc-1) then
        str := str+kDelim;
    end;//each signal
    WriteLn(f, str);
   end;
  end;//not a vector
  CloseFile(f);
  result := true;
end;

function SaveFloat (lFilename: string; var lEEG: TEEG; VECTORIZED: boolean): boolean;
var
  fp: file;
  S,C,NC,NS: integer;
begin
  result := false;
  NC := NumChannels(lEEG);
  NS := NumSamplesZeroIfVariable(lEEG);
  if (NC < 1) or (NS < 1) then
    exit;
  //first maximum number of recordings for any channel
  FileMode := 2; //set to read/write
  AssignFile(fp, lFileName);
  Rewrite(fp, 1);
  if  VECTORIZED then begin
    for C := 0 to NC - 1 do
      blockwrite(fp,lEEG.Samples[c][0],NS*sizeof(single))
  end else begin //not a vector
    for S := 0 to NS - 1 do
      for C := 0 to NC - 1 do
        blockwrite(fp,lEEG.Samples[c][s],sizeof(single));
  end;
  CloseFile(fp);
  result := true;
end;

function WriteV(lFilename: string; var  lEEG: TEEG; BINARY,VECTORIZED: boolean): boolean;
//Read or write initialization variables to disk
var
  f : TextFile;
  lC, lNS: integer;
  lDatName: string;
begin
  result := false;
  lNS := NumSamplesZeroIfVariable(lEEG);
  if (NumChannels(lEEG) < 1) or (lNS < 1) or (SampleRateZeroIfVariable(lEEG) < 1) then begin
    showmessage('VHDR error: no data to write or variable number of samples.');
    exit;
  end;
  filemode:= fmOpenReadWrite;
  AssignFile(f,lFilename);
  Rewrite(f);
  WriteLn(f, 'Brain Vision Data Exchange Header File Version 1.0');
  WriteLn(f, '[Common Infos]');
  lDatName := changefileext(extractfilename(lFilename),'.eeg');
  WriteLn(f, 'DataFile='+lDatName);
    lDatName := changefileext(lFilename,'.eeg'); //save in same folder
  if BINARY then
    WriteLn(f, 'DataFormat=BINARY')
  else
    WriteLn(f, 'DataFormat=ASCII');
  if VECTORIZED then
    WriteLn(f, 'DataOrientation=VECTORIZED')
  else
    WriteLn(f, 'DataOrientation=MULTIPLEXED');
  WriteLn(f, 'DataType=TIMEDOMAIN');
  WriteLn(f, 'NumberOfChannels='+inttostr(NumChannels(lEEG)));
  WriteLn(f, 'SamplingInterval='+floattostr((1000/lEEG.Channels[0].SampleRate) * 1000));
  WriteLn(f, 'DataPoints='+inttostr(lNS));
  if BINARY then begin
    WriteLn(f, '[Binary Infos]');
    WriteLn(f, 'BinaryFormat=IEEE_FLOAT_32');
  end else begin
    WriteLn(f, '[ASCII Infos]');
    WriteLn(f, 'DecimalSymbol=.');
    //WriteLn(f, 'SkipLines=0');
    //WriteLn(f, 'SkipColumns=0');
  end;
  WriteLn(f, '[Channel Infos]');
  for lC := 1 to NumChannels(lEEG) do begin
    if not lEEG.Channels[lC-1].SignalLead then
      WriteLn(f,'Ch'+Inttostr(lC)+'='+ lEEG.channels[lC-1].Info+',,1,Digital')
    else
      WriteLn(f,'Ch'+Inttostr(lC)+'='+ lEEG.channels[lC-1].Info+',,1,µV')
  end;
  CloseFile(f);
  //put signature in first line of vhdr...
  if BINARY then
    result := SaveFloat(lDatName, lEEG, VECTORIZED)
  else
    result := SaveASCII(lDatName, lEEG, VECTORIZED)
end;

function WriteVHDR(lFilename: string; var lEEG: TEEG): boolean;
begin
  result := WriteV(lFilename,lEEG, TRUE,TRUE); //BINARY, VECOTR
  //VECTORIZED TEXT WORKS POORLY...WriteV(lFilename,lEEG, FALSE,TRUE); //BINARY, VECTOR
  //   ... many tools limit number of columns
  //IF you want text output, use multiplexed text ...WriteV(lFilename,lEEG, FALSE,FALSE); //BINARY, VECOTR
end;



end.
