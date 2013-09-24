unit eeg_type;
{$mode delphi}{$H+}
interface
uses filter_rbj, sysutils;

const
 kMaxChannels = 64;
type
	SingleRA0 = array [0..0] of Single;
	Singlep0 = ^SingleRA0;
  TChannel = record
      previ: integer;
      SignalLead: boolean;
      Info,UnitType: string;
      DisplayMin,DisplayMax,DisplayScale,SampleRate : double;
      HighPass:  TRbjEqFilter;
   end;
  TEEG = record
      maxsamples,numChannels,samplesprocessed, samplesacquired: integer;
      audiomin,audiomax: single;
      Time: TDateTime;
      Channels: array [0..kMaxChannels] of TChannel;
      samples,filtered: array [0..kMaxChannels] of Singlep0;
   end;
   procedure FreeEEG (var lEEG: TEEG);
   procedure CreateEEG(var lEEG: TEEG; channels,nSamples: integer; SampleHz, HighPassFreqHz: double);
   function NumChannels(lEEG: TEEG): integer;
   function NumSamples(lEEG: TEEG; lChannel: integer): integer;
   function MaxNumSamples(lEEG: TEEG): integer;
   function NumSamplesZeroIfVariable(lEEG: TEEG): integer;
   function SampleRateZeroIfVariable(lEEG: TEEG): double;
   //procedure DummyData(var lEEG: TEEG);
   procedure DummyData(var lEEG: TEEG; samples: integer);

implementation

procedure DummyData(var lEEG: TEEG; samples: integer);
var
  nC, c, s: integer;
begin
  nC := NumChannels(lEEG);
  //nS := 1000;
  for c := 0 to (nC-1) do
    for s := 0 to (samples-1) do
      lEEG.samples[c][s] := 32767.5* (1.0+(sin(s/(c+1))) ); //scale -1..+1 to 0..65535
  lEEG.samplesprocessed := 0;
  lEEG.samplesacquired := samples;
end;

function NumChannels(lEEG: TEEG): integer;
begin
  result := lEEG.numChannels;
end;

function NumSamples(lEEG: TEEG; lChannel: integer): integer;
begin
  result := lEEG.samplesprocessed;
end;

function MaxNumSamples(lEEG: TEEG): integer;
begin
  result := lEEG.samplesprocessed;
end;

function NumSamplesZeroIfVariable(lEEG: TEEG): integer;
begin
  result := lEEG.samplesprocessed;
end;

function SampleRateZeroIfVariable(lEEG: TEEG): double;
var
  r: double;
  c: integer;
begin
  result := 0;
  if (NumChannels(lEEG) < 1) or (MaxNumSamples(lEEG)<1) then
    exit;
  r := lEEG.Channels[0].SampleRate;
  for c := 0 to  NumChannels(lEEG)-1 do
    if r <> lEEG.Channels[0].SampleRate then
      exit;
  result := round(r);
end;

procedure FreeEEG(var lEEG: TEEG);
var
  i: integer;
begin
  lEEG.maxsamples := 0;
  lEEG.samplesacquired := 0;
  lEEG.samplesprocessed := 0;
  if lEEG.numChannels > 0 then begin

    for i := 0 to lEEG.numChannels-1 do begin
      freemem(lEEG.Samples[i]);
      freemem(lEEG.Filtered[i]);
     end;//for each channel
  end; //more than one channel
  lEEG.numChannels := 0;
end; //freeEEG

procedure CreateEEG(var lEEG: TEEG; channels,nSamples: integer; SampleHz, HighPassFreqHz: double);
var
  i: integer;
begin
  lEEG.samplesacquired := 0;
  lEEG.samplesprocessed := 0;
  lEEG.Time := Now;
  if channels > kMaxChannels then
    lEEG.numChannels := kMaxChannels
  else
    lEEG.numChannels := channels;
  //channelheight := pixelheightperchannelX;
  if channels > 0 then begin
    lEEG.maxsamples := nSamples;
    for i := 0 to lEEG.numChannels-1 do begin
      getmem(lEEG.Samples[i], lEEG.maxsamples*sizeof(single));
      getmem(lEEG.Filtered[i], lEEG.maxsamples*sizeof(single));
      lEEG.Channels[i].SignalLead := true;
      lEEG.Channels[i].Info := 'ch'+inttostr(i+1);
      lEEG.Channels[i].UnitType := 'uV';
      lEEG.Channels[i].SampleRate := SampleHz ;
      lEEG.Channels[i].previ := 0;
      lEEG.Channels[i].DisplayScale := 1.0;
      lEEG.Channels[i].HighPass := TRbjEqFilter.Create(SampleHz,0);
      lEEG.Channels[i].HighPass.Freq := HighPassFreqHz;
      if HighPassFreqHz <> 0 then
          lEEG.Channels[i].HighPass.CalcFilterCoeffs(kHighPass,HighPassFreqHz,0.3{Q},0{Gain}, true {QIsBandWidthCheck})



    end;
   end;

end;


end.