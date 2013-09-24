unit eeg_graph;

{$mode delphi} {$H+}

interface

uses
  Classes, SysUtils, LResources, Forms, Controls, Graphics, Dialogs, synaser,
  StdCtrls, ComCtrls, ExtCtrls, Buttons, eeg_type;

Type
TGraphPrefs = record
   Text, Background, Trace, Frame: TColor;
   TimeScale: single;
end;

function DefaultPrefs: TGraphPrefs;
//procedure DrawGraph(Img: TImage; EEG: TEEG; gP: TPrefs);
procedure DrawGraph(Img: TImage; EEG: TEEG; gP: TGraphPrefs; FirstSample, LastSample: integer; bigText: string; HideFinalChannel: boolean);
procedure SetDimension(lImage: TImage; lPGHt,lPGWid :integer);

implementation

procedure SetDimension(lImage: TImage; lPGHt,lPGWid :integer);
var
   Bmp     : TBitmap;
begin

     if (lImage.Picture.Height = lPGHt) and (lImage.Picture.Width = lPGWid) then
      exit;
     Bmp        := TBitmap.Create;
     {$IFDEF FPC}
     Bmp.Height := lPGHt-2;
     Bmp.Width  := lPGwid-2;
     {$ELSE}
     Bmp.Height := lPGHt;
     Bmp.Width  := lPGwid;
     {$ENDIF}
     lImage.Picture.Assign(Bmp);
     lImage.width := round(Bmp.Width);
     lImage.height := round(Bmp.Height);
     Bmp.Free;
end;

function DefaultPrefs: TGraphPrefs;
begin
     result.Text := $660022;
     result.Background := $CCCCCC;// $C8FFB4;
     result.Frame := $AAAAAA;//$AA0055;
     result.Trace := $000000;//$AA0055;
     result.TimeScale:= 1.0;
end;

function NumVisibleChannels(lEEG: TEEG): integer;
begin
    result := NumChannels(lEEG);
end;

function DisplayDistX: integer;
begin
      result := 64
end;

procedure BoundRange (EEG: TEEG; var firstSample, lastSample: integer);
var
   s: integer;
begin
    //compute sample range
  s := MaxNumSamples(EEG);
  if (firstSample > s) then firstSample := s;
  if (firstSample < 1) then firstSample := 1;
  if (lastSample > s) then lastSample := s;
  if (lastSample < 1) then lastSample := 1;
  if (lastSample < firstSample) then begin
     s := lastSample;
     lastSample := firstSample;
     firstSample := s;
  end;
end;


procedure DrawGraph(Img: TImage; EEG: TEEG; gP: TGraphPrefs; firstSample, lastSample: integer; bigText: string; HideFinalChannel: boolean);
const
  kLBorder = 30;
  kTBborder = 10;
var
  sample, pixelX, samplesPerNode, pixelPerNode: single;
  channelHtDiv2,imgHt, imgWid,channelHt,startSample,nC,c,nS, s, n, nNodes, xOffset, yOffset: integer;
  nodes: array of TPoint;
begin
  nC := NumChannels(EEG);
  if HideFinalChannel then
     nC := nC -1;
  BoundRange(EEG, firstSample, lastSample);
  nS := lastSample-firstSample;
  imgHt := Img.Height - (2*kTBborder); //height without top bottom margin
  imgWid := Img.Width- kLBorder; //XOffset = left margin
  //create a blank graph
  Img.Canvas.Font.color := gp.Text;
  Img.Canvas.Brush.Style:=bsSolid;
  Img.Canvas.Brush.Color := gp.Background;
  Img.Canvas.FillRect(Img.Canvas.ClipRect);
  Img.Canvas.Brush.Style:=bsClear;
  Img.Canvas.Font.Size := 12;
  Img.Canvas.Font.Color := gp.Trace;
  //exit if invalid input
  if (nC < 1) or (nS < 2) or (imgHt < 1) or (imgWid < 1) then exit; //exit if nonsense values
  channelHt := round(imgHt / nC);
  channelHtDiv2 := channelHt div 2;
  if channelHt < 2 then exit;
  if (nS > imgWid) then begin //sample once per pixel
     nNodes := imgWid;
     pixelPerNode := 1.0; //plot for every pixel
     samplesPerNode := nS/imgWid;
  end else begin  //else fewer samples than pixels
    nNodes := nS;
    pixelPerNode := imgWid/(nS-1); //plot for every pixel
    samplesPerNode := 1.0;
  end;

  with   Img.Canvas do begin
      //draw frame
      yOffset := kTBborder+channelHt;
      Pen.Color:=gp.Frame;
      for c := 0 to (nC -1) do begin
          moveTo(kLBorder,YOffset-(ChannelHt div 2) );
          lineTo(kLBorder+imgWid, YOffset-(ChannelHt div 2) );
          moveTo(kLBorder, YOffset-(ChannelHt div 4) );
          lineTo(kLBorder, YOffset-round(ChannelHt/4*3) );

          YOffset := YOffset + ChannelHt;
      end;
      //draw traces
      yOffset := kTBborder+ChannelHtDiv2;
      Pen.Color:=gp.Trace;//clBlue;
      SetLength( nodes, nNodes );
      for c := 0 to (nC -1) do begin
          sample := firstSample; //start sample
          pixelX := kLBorder;
          TextOut(1,YOffset ,EEG.Channels[c].Info);
          for n := 0 to nNodes-1 do begin
            with nodes[n] do begin
              X := round(pixelX);
              Y := YOffset-Round(EEG.filtered[c,round(sample)]*ChannelHtDiv2)
            end;
            pixelX := pixelX + pixelPerNode;
            sample := sample + samplesPerNode;
          end;//for each node
          Polyline( nodes );
          YOffset := YOffset + ChannelHt;
      end; //for each channel
      nodes := nil;
  end;
  if (length(bigText) > 0) then begin
    Img.Canvas.Font.Size := 36;
    Img.Canvas.Font.Color := gp.Trace;
    Img.Canvas.TextOut(Img.width-Img.Canvas.TextWidth(bigText)-2,0,bigText);
  end;
end;

(*procedure UpdateTimeDisplay(DestCanvas: TCanvas; EEG: TEEG; gP: TPrefs);
var
  vchan,dec,nvchan,nchan,maxsamp,DisplayDist,L, I, Start, DispCount, YOffset, XOffset, TimeOffset : Integer;
  SampleFreq, DI, DIInc, TimeStart : Double;
  lClip: boolean;
  TimeStr, Str : string;
  TPA: array of TPoint;
begin
  nchan := NumChannels(EEG);
  nvchan := NumVisibleChannels(EEG);

  maxsamp := MaxNumSamples (EEG);
  if (maxsamp < 1) then
    exit;
  lClip := true; //Windows Powerpoint has a problem with EMFs that have negative coordinates....
  DisplayDist := DisplayDistx;
  XOffset :=0;//only to prevent compiler warning


  TimeOffset:=10;
  with   DestCanvas do begin
      Font.color := gp.Text;
      Brush.Color := gp.Background;
      Brush.Style:=bsSolid;
      FillRect(ClipRect);
      Brush.Style:=bsClear;
      DispCount:=Min(Round((Width-DisplayLabelWidth)/gP.TimeScale),maxsamp-Start);
      //next - draw events
      if (length(VMRK.Events) > 0) and (Start  < (VMRK.Events[VMRK.CurrentEvent].OnsetSamp+VMRK.Events[VMRK.CurrentEvent].DurationSamp)) and ((Start+DispCount) > VMRK.Events[VMRK.CurrentEvent].OnsetSamp) then begin          //(VMRK.CurrentEvent < 0) or
          if gP.ShowVerticalAxis then
            XOffset:=2*DisplayLabelWidth
          else
            XOffset:=DisplayLabelWidth;

          Pen.Color := gp.Zero;
          L := max(round((VMRK.Events[VMRK.CurrentEvent].OnsetSamp-Start)*gP.TimeScale), 0);
          I := min(round((VMRK.Events[VMRK.CurrentEvent].OnsetSamp+VMRK.Events[VMRK.CurrentEvent].DurationSamp-Start)*gP.TimeScale), DispCount);
          if VMRK.Events[VMRK.CurrentEvent].Channel > 0 then begin
            YOffset:=(VMRK.Events[VMRK.CurrentEvent].Channel-1)*DisplayDist;
            Rectangle(XOffset+L,YOffset,XOffset+I,YOffset + DisplayDist);
          end else
            Rectangle(XOffset+L,2,XOffset+I,DisplayDist*nvchan-2);
          //caption := inttostr(XOffset+L)+'  '+inttostr(Xoffset+I)+'  '+inttostr(DispCount);
          Brush.Style:=bsClear;
      end;
      vchan := 0;
      for L:=0 to nchan-1 do begin
       if  EEG.Channels[L].visible then begin  //not a digital channel
        YOffset:=DisplayDist div 2+vchan*DisplayDist;
        inc(vchan);
        if not EEG.Channels[L].SignalLead then
          TextOut(1{DisplayLabelWidth-8-TextWidth(EEG.Channels[L].INfo)},YOffset-TextHeight(EEG.Channels[L].Info) div 2,'*'+EEG.Channels[L].Info)
        else
          TextOut(1,YOffset-TextHeight(EEG.Channels[L].Info) div 2,EEG.Channels[L].Info);
        if gP.ShowVerticalAxis then begin
          Pen.Color:=gp.Text; //clBlack;
          XOffset:=2*DisplayLabelWidth;
          I:=Round(DisplayDist*VerticalAxisFrac);
          MoveTo(XOffset,YOffset-I); LineTo(XOffset,YOffset+I);
          MoveTo(XOffset-2,YOffset-I); LineTo(XOffset+3,YOffset-I);
          MoveTo(XOffset-2,YOffset+I); LineTo(XOffset+3,YOffset+I);
          if (not EEG.Channels[L].SignalLead) or (EEG.Channels[L].DisplayScale = 0) then
             Str:=''
          else
              Str:=FormatFloat('0.00',-
              VerticalAxisFrac*DisplayDist/EEG.Channels[L].DisplayScale)+'uV';
          TextOut(XOffset-7-TextWidth(Str),YOffset+I-3*TextHeight(Str) div 4,Str);
          if (not EEG.Channels[L].SignalLead) or (EEG.Channels[L].DisplayScale = 0) then
            Str:=''
          else
            Str:=FormatFloat('0.00',VerticalAxisFrac*DisplayDist/EEG.Channels[L].DisplayScale)+'uV';
          TextOut(XOffset-7-TextWidth(Str),YOffset-I-TextHeight(Str) div 4,Str);
          Inc(XOffset);
        end else
          XOffset:=DisplayLabelWidth;
        Pen.Color:= gp.Zero;//;
        MoveTo(XOffset,YOffset);
        LineTo(Width,YOffset);
        Pen.Color:=gp.Trace;//clBlue;
        SetLength( TPA, DispCount );
        for i := 0 to DispCount-1 do begin
            with TPA[i] do begin
              X := XOffset+Round(I*gP.TimeScale);
              //Y := YOffset-random(55);
              Y := YOffset-Round(EEG.Samples[L,Start+I]*EEG.Channels[L].DisplayScale);
              if (lClip) and (Y < 0) then
                Y := 0;
            end;
        end;
        Polyline( TPA );
       end;
      end;
      SampleFreq:=EEG.Channels[0].SampleRate;

    end;



    if TimeOffset=0 then begin
      DestCanvas:=TimePanel.Canvas;
      DestCanvas.Font.Color := gP.Text;
      DestCanvas.Brush.Color:=gP.Background; //clBtnFace;
      DestCanvas.FillRect(DestCanvas.ClipRect);
    end;
    //next - time codes
    if SampleFreq>0 then with DestCanvas do begin
      Pen.Color:=clBlack;
      if gP.TimeScale>4.1 then DIInc:=SampleFreq/100
      else if gP.TimeScale>2.1 then DIInc:=SampleFreq/50
      else if gP.TimeScale>1.1 then DIInc:=SampleFreq/20
      else if gP.TimeScale>0.6 then DIInc:=SampleFreq/10
      else if gP.TimeScale>0.26 then DIInc:=SampleFreq/4
      else DIInc:=SampleFreq/2;
      Dec := ReqDecimals(DIInc/SampleFreq);
      //caption := floattostr(DIInc/SampleFreq);
      TimeStart:=Ceil(Start/DIInc)*DIInc;
      DI:=TimeStart-Start;
      while DI<=DispCount do begin
        I:=XOffset+Round(DI*gP.TimeScale);
        if TimeOffset=0 then
        begin
          MoveTo(I,16); LineTo(I,25);
        end
        else
        begin
          MoveTo(I,TimeOffset); LineTo(I,TimeOffset-10);     //OSX
        end;
        TimeStr := FloatToStrF((Start+DI)/SampleFreq, ffFixed,7,Dec);
        //x TimeStr:=FormatFloat('0.000',(Start+DI)/SampleFreq)+' s';
        TextOut(I-TextWidth(TimeStr) div 2,TimeOffset+1,TimeStr); //z
        DI:=DI+DIInc;
      end;
  end
  else if Assigned(TimePanel.Canvas) then with TimePanel.Canvas do
  begin
    Brush.Color:=clBtnFace;
    FillRect(ClipRect);
  end;
  Copy2ForeGround(TimeDisplayPanelBackBuffer);
  TimeDisplayPanel.Invalidate;
  TimePanel.Invalidate;
end;*)

end.

