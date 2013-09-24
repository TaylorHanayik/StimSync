unit format_tms32;
{$mode delphi}

interface
uses eeg_type, sysutils,dialogs, DateUtils;

//function LoadTMS32(lFilename: string; var lEEG: TEEG): boolean;
function WriteTMS32(lFilename: string; var lEEG: TEEG): boolean;

implementation

const
kSig = chr($0d)+chr($0a)+chr($1a);

type
 TDOSTIME = packed record //Next: Poly5 header
   Year,Month,Day,DayofWeek,Hour,Minute,Second: smallint;
 end;
  TEEGHdr = packed record //Next: Poly5 header
   //ID: array [1..32] of char; //unused
   //VER: Word; //unused                  `
   MeasureName: array [1..81] of char; //unused
   SR: smallint; //samplerate                  `
   StoreFreq: smallint; //must eqaul sample freq                  `
   StoreType: byte; //Must be 0 (Hz)                  `
   NS: smallint; //number of channels                  `
   NP: integer; // number of periods                `
   NPpad: integer; //pads  nPeriods to 8 bytes
   DOSTIME: TDOSTIME; //unused
   NB: integer; //num blocks                  `
   PB: smallint; //periods per block (multiple of 16)                 `
   SD: smallint; //size of sample data
   Compression: Word; //unused -must be zero
   ReservedTxt: array [1..64] of char; //unused                      `
 end; //TNIFTIhdr Header Structure
 TLeadHdr = packed record //Next: Poly5 header
   LeadName: array [1..41] of char;
   Reserved: DWord;
   UN: array [1..11] of char;
   UL: single; //            `
   UH: single; //
   AL: single; //            `
   AH: single; //
   SI: smallint;
   Unused: smallint;
   UnusedStr: array [1..60] of char;
 end;
  TBlockHdr = packed record //Next: Poly5 header
   PI: integer;
   Reserved: integer; //pad for PI
   DOSTIME: TDOSTIME; //unused
   Reserved2: array [1..64] of char;
 end;

procedure Str2Array(lIn: string; var lOut: array of char);
var
  Len,i: integer;
begin
  Len := length(lIn);
  if length(lOut) < Len then
    Len := length(lOut);
  if Len < 1 then
    exit;
  for i := 1 to Len do
    lOut[i] := lIn[i];
  if Len < length(lOut) then
    for i := Len+1 to length(lOut) do
      lOut[i] := chr(0);
  lOut[0] := chr(Len);
end;

function TDate2Dos (lTime: TDateTime): TDOSTIME;
begin
  result.Day := DayOf(lTime);
  result.Month := MonthOf(lTime);
  result.Year := YearOf(lTime);
  result.Hour := HourOf(lTime);
  result.Minute := MinuteOf(lTime);
  result.Second := SecondOf(lTime);
end;

(*function LoadTMS32(lFilename: string; var lEEG: TEEG): boolean;
//The Poly5 data format can store 16-bit int data
//The TMS32 version can store 32-bit float, 16-bit int or mixture of data
//This function currently only supports pure 32-bit float...
//... will report incompatible variants to the user.
//I would rather add support when I have same files to test.
function DOSTIMEToStr (lDOS: TDOSTIME; var lTIME: TDateTime): string;
begin
  if not IsValidDateTime(lDOS.Year, lDOS.Month, lDOS.Day, lDOS.Hour, lDOS.Minute, lDOS.Second, 0) then begin
      lTime := Now;
      result := (FormatDateTime('yyyymmdd_hhnnss', (Now))) ;
      exit;
    end;
  lTime := EncodeDateTime(lDOS.Year, lDOS.Month, lDOS.Day, lDOS.Hour, lDOS.Minute, lDOS.Second,0);
  result := (FormatDateTime('yyyymmdd_hhnnss', (lTime)))
end;
function ParseLeadName(LeadHdr: TLeadHdr): string;
var
  j: integer;
  c: char;
begin
    result := '';
    for j := 1 to 41 do begin
      c := LeadHdr.LeadName[j];
      if c in ['0'..'9','a'..'z','A'..'Z'] then
      //if LeadHdr.LeadName[j] <> chr(0) then
        result := result+LeadHdr.LeadName[j];
    end;
    result := result;
end;
FUNCTION specialsingle (var s:single): boolean;
//returns true if s is Infinity, NAN or Indeterminate
//4byte IEEE: msb[31] = signbit, bits[23-30] exponent, bits[0..22] mantissa
//exponent of all 1s =   Infinity, NAN or Indeterminate
CONST kSpecialExponent = 255 shl 23;
VAR Overlay: LongInt ABSOLUTE s;
BEGIN
  IF ((Overlay AND kSpecialExponent) = kSpecialExponent) THEN
     RESULT := true
  ELSE
      RESULT := false;
END;
function ClipStr (lStr: string; NumChar: integer): string;
var
  i,len: integer;
begin
    result := lStr;
    len := length(lStr);
    if len<= NumChar then
      exit;
    result := '';
    for i := NumChar+1 to len do
      result := result + lStr[i];
end;
var
  fp: file;
  EEGHdr: TEEGHdr;
  LeadHdr: TLeadHdr;
  BlockHdr:TBlockHdr;
  lVers: word;
  lChan, I, Block,lSample,lLead,q: integer;
  lStr: string;
  DataRA : array of single;
  lSig: array[1..3] of char;
begin
  result := false;
  FileMode := 0; //set to readonly
  AssignFile(fp, lFileName);
  Reset(fp, 1);
  if FileSize(fp) <  sizeof(TEEGHdr) then begin
    Showmessage('To small to be an TMS32 file :'+lFilename);
    exit;
  end;
  seek(fp, 28);
  BlockRead(fp, lSig, 3);
  if lSig <> kSig then  begin
    seek(fp, 29);
    BlockRead(fp, lSig, 3);
    if lSig <> kSig then begin
      Showmessage('Incorrect signature for TMS32');
      exit;
    end;
  end;
  BlockRead(fp, lVers,sizeof(lVers));
  //fx(lvers);
  BlockRead(fp, EEGHdr, SizeOf(TEEGHdr));
   if EEGHdr.StoreType<>0 then raise Exception.Create('TMS32 Storage type not supported '+inttostr(EEGHdr.StoreType));
   if EEGHdr.Compression<>0 then raise Exception.Create('TMS32 compression not supported');
   if EEGHdr.SR<>EEGHdr.StoreFreq then raise Exception.Create('TMS32 Sample Freqeuncy is not the Store Frequency');
   //lEEG.SequenceInfo :=
    //fx(EEGHdr.SR,EEGHdr.NB,EEGHdr.PB);
   // fx(EEGHdr.SD);
   DOSTIMEToStr(EEGHdr.DOSTIME, lEEG.Time);
   setlength(lEEG.Channels,EEGHdr.NS div 2);
   ClearEEGHdr (lEEG);
   lChan := 0;
    for I:=1 to EEGHdr.NS do begin
      BlockRead(fp, LeadHdr,SizeOf(TLeadHdr));
      //fx(LeadHdr.AL,LeadHdr.AH);
      lStr := ParseLeadName(LeadHdr);
      if odd(I) and (lStr[1] = 'L') and (lStr[2] = 'o') then
      else if not (odd(I)) and (lStr[1] = 'H') and (lStr[2] = 'i') then
      else
          raise Exception.Create('Current version only supports 32-bit data.');
      if odd(I) then begin
         lEEG.Channels[lChan].info :=  ClipStr(lStr,2);
         lEEG.Channels[lChan].unittype :=  Trim(LeadHdr.UN);
         lEEG.Channels[lChan].SampleRate :=EEGHdr.SR;
         lEEG.Channels[lChan].SignalLead := (Trim(LeadHdr.UN)[1] = 'µ');
         inc(lChan);
      end;
    end;

    //now read data....
    setlength(lEEG.Samples,lChan,EEGHdr.NP);
    setlength(DataRA,EEGHdr.PB*lChan);
    //next read data
    i := 0;
    for Block := 1 to (EEGHdr.NB) do begin
      BlockRead(fp,BlockHdr,SizeOf(TBlockHdr));

      if i <> BlockHdr.PI then
        showmessage('Data not contiguous: expected sample '+inttostr(i)+', but found sample '+  inttostr(BlockHdr.PI));
      BlockRead(fp,DataRA[0],EEGHdr.PB*lChan * sizeof(single));
      for lSample := 0 to (EEGHdr.PB*lChan)-1 do
          if specialsingle (DataRA[lSample]) then
            DataRA[lSample] := 0;
      q := 0;
      for lSample := 1 to EEGHdr.PB do begin
        if i < EEGHdr.NP then begin //the final block may not be filled with samples, e.g. if 128 samples per block, and only 200 samples collected
          for lLead:=0 to lChan-1 do begin
            lEEG.Samples[lLead][i] := DataRA[q];
            inc(q);
          end;
        end; //if i
        inc(i);
      end;
    end;//for each block
    CloseFile(fp);
    FileMode := 2; //set to read-write
   result := true;
end; //LoadTMS32
  *)
function WriteTMS32(lFilename: string; var lEEG: TEEG): boolean;
const
  kSig3= 'POLY SAMPLE FILEversion 2.03'+kSig+chr(203)+chr(0);
  kSig4= 'POLY SAMPLE FILE version 2.04'+kSig+chr(204)+chr(0);
  kBlockSize = 336;
var
  fp: file;
  EEGHdr: TEEGHdr;
  LeadHdr: TLeadHdr;
  BlockHdr:TBlockHdr;
  lChan, I, Block,lSample,lLead,q: integer;
  DataRA : array of single;
begin

  result := false;
  if MaxNumSamples(lEEG) < 1 then
    exit;
  FillChar(EEGHdr, SizeOf(TEEGHdr), 0);
  FillChar(LeadHdr, SizeOf(TLeadHdr), 0);
  FillChar(BlockHdr, SizeOf(TBlockHdr), 0);
  FileMode := 2; //set to read/write
  AssignFile(fp, lFileName);
  Rewrite(fp, 1);
  //if Format203 then
    BlockWrite(fp, kSig3, length(kSig3));
  //else //format 204
  //  BlockWrite(fp, kSig4, length(kSig4));
  Str2Array('Poly5 File',EEGHdr.MeasureName);
  EEGHdr.DOSTIME := TDate2Dos(lEEG.Time);
  EEGHdr.NS := NumChannels(lEEG)*2;
  EEGHdr.NP := MaxNumSamples(lEEG);
  EEGHdr.NB :=  (EEGHdr.NP+kBlockSize-1) div kBlockSize;    //Number of blocks
  EEGHdr.PB :=  kBlockSize;    //per block
  EEGHdr.StoreType:= 0;
  EEGHdr.Compression := 0;
  EEGHdr.SR := round(lEEG.Channels[0].SampleRate);
  EEGHdr.StoreFreq := EEGHdr.SR;
  EEGHdr.SD := EEGHdr.PB * EEGHdr.NS * 2;
  BlockWrite(fp, EEGHdr, SizeOf(TEEGHdr));
  lChan := 0;
      LeadHdr.UL := 0.0;
      LeadHdr.UH := 1.0;
      LeadHdr.AL := 0.0;
      LeadHdr.AH := 1.0;
  for I:=1 to EEGHdr.NS do begin
      if odd(I)  then
       Str2Array('(Lo) '+lEEG.Channels[lChan].info,LeadHdr.LeadName)
      else begin
       Str2Array('(Hi) '+lEEG.Channels[lChan].info,LeadHdr.LeadName);
      end;
      // EEGHdr.SR := round(lEEG.Channels[lChan].SampleRate);
      //lEEG.Channels[lChan].UnitType := '1234';

      Str2Array(lEEG.Channels[lChan].unittype,LeadHdr.UN);
      //TLeadHdr;


      BlockHdr.PI := i;
      BlockWrite(fp, LeadHdr,SizeOf(TLeadHdr));
      if not odd(i) then
        inc(lChan);
  end;
  setlength(DataRA,EEGHdr.PB*lChan);
  //next write data
  i := 0;
  lChan := NumChannels(lEEG);
  for Block := 1 to (EEGHdr.NB) do begin
      BlockHdr.PI := i;
      BlockWrite(fp,BlockHdr,SizeOf(TBlockHdr));
      q := 0;
      for lSample := 1 to EEGHdr.PB do begin
        if i < EEGHdr.NP then begin //the final block may not be filled with samples, e.g. if 128 samples per block, and only 200 samples collected
          for lLead:=0 to lChan-1 do begin
            DataRA[q] := (lEEG.Samples[lLead][i]);
            inc(q);
          end;
        end; //if i
        inc(i);
      end;
      BlockWrite(fp,DataRA[0],EEGHdr.PB*lChan * sizeof(single));
    end;//for each block
    CloseFile(fp);
   result := true;
end; //WriteTMS32

end.
