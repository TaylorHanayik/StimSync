unit mainNew;
//Chris Rorden, 2013 BSD license (see license.txt or http://opensource.org/licenses/BSD-2-Clause)
//{$mode objfpc}{$H+}
{$mode delphi}{$H+}
interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Spin, Menus, synaser;
type
  { TForm1 }
  TForm1 = class(TForm)
    BindBox: TCheckGroup;
    InvertTriggersCheck: TCheckBox;
    CoupleDownUpDebounceCheck: TCheckBox;
    EditMenu: TMenuItem;
    ClearMenu: TMenuItem;
    w2r_btn: TButton;
    ComPortDrop: TComboBox;
    Down1: TEdit;
    Down10: TEdit;
    Down2: TEdit;
    Down3: TEdit;
    Down4: TEdit;
    Down5: TEdit;
    Down6: TEdit;
    Down7: TEdit;
    Down8: TEdit;
    Down9: TEdit;
    DownBox: TGroupBox;
    UpBox: TGroupBox;
    Label2: TLabel;
    MainMenu1: TMainMenu;
    MappingBox: TGroupBox;
    Label1: TLabel;
    FileMenu: TMenuItem;
    SaveDialog1: TSaveDialog;
    SaveMenu: TMenuItem;
    SetupVisibleMenu: TMenuItem;
    TextOutput: TMemo;
    Panel1: TPanel;
    RepeatMSEdit: TSpinEdit;
    StatusGroup: TCheckGroup;
    Timer1: TTimer;
    Up1: TEdit;
    Up10: TEdit;
    Up2: TEdit;
    Up3: TEdit;
    Up4: TEdit;
    Up5: TEdit;
    Up6: TEdit;
    Up7: TEdit;
    Up8: TEdit;
    Up9: TEdit;
    ser:TBlockSerial;
    DefaultsBtn: TButton;
    procedure ClearMenuClick(Sender: TObject);
    procedure ComPortDropChange(Sender: TObject);
    procedure ComPortDropClick(Sender: TObject);
    procedure DefaultsBtnClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure SaveMenuClick(Sender: TObject);
    procedure SetupVisibleMenuClick(Sender: TObject);
    procedure DetectPorts;
    procedure SerialConnect;
    procedure Timer1Timer(Sender: TObject);
    procedure ReadBuffer;
    procedure DecodeBuffer;
    procedure ShowStatus(keyBits: integer);
    procedure w2r_btnClick(Sender: TObject);
    function isCmd (position: integer): boolean ;
    function isUSec (position: integer): boolean ;
    procedure WriteKeyMapping (resetROM: boolean) ;
    procedure WriteCmd (setNotGet: boolean; Cmd2, Cmd3, Cmd4: byte);
    //procedure AddCmd (setNotGet: boolean; Cmd2, Cmd3, Cmd4: byte);
    function GetDebounceFlags: integer;
    procedure SetDebounceFlags(val: integer);
    procedure WriteReturnToKeyMode;
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.lfm}
var
  SerialBuffer: array of byte;
  //gOutSerialBuffer: array of byte;
  gLastuSec: Int64;
  kMaxUnsignedLong: Int64 = 4294967295; // (2^32 - 1) http://arduino.cc/en/Reference/UnsignedLong
const
  kTimerStartTag0 = 0;
  kTimerStartTag1 = 1;
  kTimerFailTag2 = 2;
  kTimerOKTag3 = 3;
  kTimerRunningTag4 = 4;


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
  kCmd34ModeKey = 169;
  kCmd34ModeuSec = 181;
  //kCmd34ModeOsc = 162;  //For Oscilloscopes only
  kCmdBytes = 4; //length of commands (in bytes)
  kUSecBytes = 8; //length of uSec signals (in bytes)
  kBindMapping: array [1..kKeyNum] of byte = (1,2,3,4,5,0,0,0,6,7);
  kDelimiter = chr(9); //text delimiter: chr(9) for tab stop, ' ' for space


{ TForm1 }
function Byte2Str (b: byte): string;
begin
     if (b = 0) then
        result := ''
     else
         result := chr(b);
end;

function Str2Byte (s: string): byte;
begin
     if length(s) = 0 then
        result := 0
     else
         result := ord(s[1]);
end;

procedure TForm1.w2r_btnClick(Sender: TObject);
begin
     WriteKeyMapping(true);
end;

procedure TForm1.ShowStatus(keyBits: integer);
var
    i: integer;
begin
    for i := 1 to (kKeyNum) do
        StatusGroup.Checked[i-1] := odd( (keyBits shr (i-1)) and 1);
end;

procedure TForm1.SerialConnect;
begin
    if Timer1.Tag <= kTimerStartTag1 then exit; //currently trying to connect
  if Timer1.Tag >= kTimerOKTag3 then WriteReturnToKeyMode; //close previous device if currently connected
  ser.Connect(ComPortDrop.Text);
  MappingBox.enabled := true;
  Timer1.enabled := false;
  Timer1.enabled := true;
  Timer1.Tag := kTimerStartTag0;
  WriteKeyMapping(false);
end;

function TForm1.GetDebounceFlags: integer;
begin
  result := 0;
  if InvertTriggersCheck.Checked then result := result + 1;
  if CoupleDownUpDebounceCheck.Checked then result := result + 2;
end;

procedure TForm1.SetDebounceFlags(val: integer);
begin
  InvertTriggersCheck.Checked := ((val and 1) > 0);
  CoupleDownUpDebounceCheck.Checked := ((val and 2) > 0);
end;

function TForm1.isCmd (position: integer): boolean ;
var
    c: integer;
begin
  result := false;
  if (position+kCmdBytes) > length(SerialBuffer) then exit; //to short to be a command
  if ((SerialBuffer[position] <> kCmd1Set) and (SerialBuffer[position] <> kCmd1Get))  then exit; //first byte not a command signature
  if ((SerialBuffer[position] = kCmd1Set) and   (SerialBuffer[position+1] in [kCmd2Mode,kCmd2KeyDown,kCmd2KeyUp,kCmd2KeyTrigger,kCmd2OscHz,kCmd2OscChannels])) then begin
     result := true; //valid SET command, which we will ignore - the client only process GET commands
     //caption := 'ignored set command';
     exit;
  end;

  if (SerialBuffer[position] = kCmd1Set) then exit; //unknown Set command
  case SerialBuffer[position+1] of
       kCmd2Mode : begin //Arduino is reporting its MODE
             result := true;
       end; //Cmd2Mode
       kCmd2KeyDown : begin //Arduino is reporting key press mapping
             if (SerialBuffer[position+2] = 0) then begin
                Timer1.Tag := kTimerOKTag3; //this allows us to detect if a supported device is connected
                RepeatMSEdit.Value := SerialBuffer[position+3];
             end;
             if (SerialBuffer[position+2] > 0) and (SerialBuffer[position+2] <= DownBox.ControlCount) then
                (DownBox.Controls[SerialBuffer[position+2]-1] as TEdit).Text := Byte2Str(SerialBuffer[position+3]);
             result := true;
       end; //Camd2KeyDown
       kCmd2KeyUp : begin //Arduino is reporting key release mapping
             //caption := 'up '+inttostr(SerialBuffer[position+2])+'  '+inttostr(SerialBuffer[position+3]);
             if (SerialBuffer[position+2] = 0) then begin
                SetDebounceFlags( SerialBuffer[position+3]);
             end;
             if (SerialBuffer[position+2] > 0) and (SerialBuffer[position+2] <= DownBox.ControlCount) then
                (UpBox.Controls[SerialBuffer[position+2]-1] as TEdit).Text := Byte2Str(SerialBuffer[position+3]);
             result := true;
       end; //Cmd2KeyUp
       kCmd2KeyTrigger : begin //Arduino is reporting key binding mapping
             if (SerialBuffer[position+2] > 0) and (SerialBuffer[position+2] <= BindBox.ControlCount) then
                (BindBox.Controls[SerialBuffer[position+2]-1] as TCheckBox).Checked := (SerialBuffer[position+3] > 0);
             result := true;
       end; //Cmd2KeyTrigger
       kCmd2NumAnalogKeys : begin //Arduino is reporting key binding mapping
            if SerialBuffer[position+3] > 0 then
               Caption := 'Attached StimSync supports buttons A and B'
            else
                Caption := 'Attached StimSync does not support buttons A and B';
            for c := 9 to DownBox.ControlCount do
                DownBox.Controls[c-1].enabled := SerialBuffer[position+3] > 0;
            for c := 9 to UpBox.ControlCount do
                UpBox.Controls[c-1].enabled := SerialBuffer[position+3] > 0;
            for c := 9 to BindBox.ControlCount do
                BindBox.Controls[c-1].enabled := SerialBuffer[position+3] > 0;
            //   (DownBox.Controls[c-1] as TEdit).Text) );
            //for c := 1 to UpBox.ControlCount do
            //WriteCmd(resetROM,kCmd2KeyUp,c,str2byte((UpBox.Controls[c-1] as TEdit).Text) );
            //for c := 1 to BindBox.ControlCount do begin
            //if  (BindBox.Controls[c-1] as TCheckBox).Checked then
		result := true; 

       end;
       kCmd2OscHz : begin
             //not required
             result := true;
       end; //Cmd2OscHz
       kCmd2OscChannels : begin
             //not required
             result := true;
       end; //Cmd2OscChannels
  end;
end;

function keyStr (bits : integer): string;
var
  c: integer;
begin
  result := kDelimiter;
  for c :=1 to kKeyNum do begin
        if odd(bits shr (c-1)) then
           if (c > kKeyNumDigital) then
              result := result + IntToHex((c-kKeyNumDigital)+9, 1) //analog outputs 'A','B'...
           else
               result := result + IntToStr(c) //digital outputs '1','2'...'10','11'
        else
            result := result + '0';
        if c < kKeyNum then result := result + kDelimiter;
  end;
end;

function TForm1.isUSec (position: integer): boolean ;
const
  kUSecSignature = 254;
var
  uSec, uSecDelta: Int64;//    uSec : Longword;
 c, checkSum,keyBits: integer;
begin
  result := false;
  if (position+kUSecBytes) > length(SerialBuffer) then exit; //to short to be a command
  if (SerialBuffer[position] <> kUSecSignature) then exit; //wrong first byte
  checkSum := 0;
  for c :=0 to (kUSecBytes-2) do
     checkSum := checkSum + SerialBuffer[position+c];
  while (checkSum > $ff) do
       checkSum :=(checkSum shr 8)+(checkSum and $ff);
  if (SerialBuffer[position+kUSecBytes-1] <> checkSum) then exit; //checkSum does not match
  result := true;
  keyBits :=  (SerialBuffer[position+1] shl 8) +  SerialBuffer[position+2];
  uSec :=  (SerialBuffer[position+3] shl 24)+ (SerialBuffer[position+4] shl 16)+ (SerialBuffer[position+5] shl 8)+ SerialBuffer[position+6];
  if (gLastuSec > kMaxUnsignedLong) then //first time code, so time since last makes no sense   //kMaxUnsignedLong
     uSecDelta := 0
  else begin
       if (uSec >= gLastuSec) then
          uSecDelta := uSec - gLastuSec //how many uSec elapsed since previous event
       else
           uSecDelta := uSec + (kMaxUnsignedLong - gLastuSec); //deal with micros() overflow
  end;
  // we use %10d as micros should have up to 10 digits, e.g. 4294967295 , in theory uSecDelta could have more, but this means an unreasonably long delay
  TextOutput.lines.add ( Format('%10d',[uSec])+kDelimiter+Format('%10d',[uSecDelta])+kDelimiter+ Format('%3d',[keyBits])+kDelimiter+keyStr(keyBits));
  gLastuSec := uSec;
  ShowStatus(keyBits);
end;

procedure TForm1.ClearMenuClick(Sender: TObject);
begin
  gLastuSec := kMaxUnsignedLong + 1;
  TextOutput.lines.clear;
     TextOutput.lines.add('#uSec       uSecDelta  Keys');
end;

procedure TForm1.DecodeBuffer;
var
   position, positionOK, len, residual: integer;
   residualBuffer: array of byte;
begin
  len := length(SerialBuffer);
  if (len < kCmdBytes) then exit; //not enough bytes for a message
  position := 0;
  positionOK := 0;
  while position < len do  begin
        //TextOutput.Lines.Add (inttostr(len)+'  '+inttostr(position));
        if isUSec(position) then begin
           inc(position,kUSecBytes);
           positionOK := position;
        end else if isCmd(position) then begin
           inc(position,kCmdBytes);
           positionOK := position;
        end else
            inc(position); //try next byte
  end; //while
  if positionOK = 0 then exit; //
  if (positionOK < len) then begin //partial commands remaining in buffer?8
     //TextOutput.Lines.Add('residual bytes '+inttostr(len-positionOK)+' total '+inttostr(len));
     residual := len-positionOK; //e.g. if we started with 64 bytes and read 62, then 2 are left over
     if (residual >= kUSecBytes) then
        residual := kUSecBytes-1; //avoid huge buffers: in case unsupported device is sending garbage only retain enough bytes for a signal
     SetLength(residualBuffer,residual);
     for position := 0 to (residual-1) do
        residualBuffer[position] := SerialBuffer[len-residual+position];
     SerialBuffer := residualBuffer;
     residualBuffer := nil;//release memory - not required as this is done automatically
     //for position := 0 to (length(SerialBuffer)-1) do
     //   TextOutput.Lines.Add('+ '+ inttostr(SerialBuffer[position]) );
  end;
  SetLength(SerialBuffer,0);
end;

var
   gX : integer = 0;

procedure TForm1.ReadBuffer;
const
  kBufSz = 4096;
var
  buffer: array of byte;
  recvSize, totalSize, i : integer;
begin
  totalSize := length(SerialBuffer);
  SetLength(buffer,kBufSz);
  repeat
   recvSize := ser.RecvBufferEx(buffer, kBufSz, 0);
   if (recvSize > 0) then begin
      SetLength(SerialBuffer, totalSize+ recvSize);
      for i := 0 to (recvSize -1) do
          SerialBuffer[totalSize+i] := buffer[i];
      totalSize := totalSize + recvSize;
   end;
  until (recvSize < kBufSz);
  if totalSize > 0 then begin
     gX := gX + 1;
     //TextOutput.lines.add(inttostr(gx) + ' '+inttostr(totalSize));
  end;
  buffer := nil; //free for good form - not required as this will be done automatically
  DecodeBuffer;
end;

procedure TForm1.WriteCmd (setNotGet: boolean; Cmd2, Cmd3, Cmd4: byte);
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
   ser.SendBuffer(serialBytes, kCmdBytes);
   serialBytes := nil; //release memory - not required due to reference counting
end;

procedure TForm1.WriteKeyMapping (resetROM: boolean);
var
   c,b: integer;
begin
  //On OSX we seem to be limited to 128 bytes of data  - so either pause or keep <128 bytes
    WriteCmd(resetROM,kCmd2KeyDown,0,repeatMSEdit.value); //debounce time
    for c := 1 to DownBox.ControlCount do
        WriteCmd(resetROM,kCmd2KeyDown,c,str2byte((DownBox.Controls[c-1] as TEdit).Text) );
    for c := 1 to UpBox.ControlCount do
        WriteCmd(resetROM,kCmd2KeyUp,c,str2byte((UpBox.Controls[c-1] as TEdit).Text) );
    for c := 1 to BindBox.ControlCount do begin
        if  (BindBox.Controls[c-1] as TCheckBox).Checked then
            b := kBindMapping[c]
        else
            b := 0;
        WriteCmd(resetROM,kCmd2KeyTrigger,c,b );
    end;

    if resetROM then begin
       WriteCmd(resetROM,kCmd2KeyUp,0,GetDebounceFlags); //debounce flags
       WriteCmd(resetROM,kCmd2EEPROMSAVE,kCmd2EEPROMSAVE,kCmd2EEPROMSAVE);
    end;
end;

procedure TForm1.WriteReturnToKeyMode;
begin
  WriteCmd(true,kCmd2Mode,kCmd34ModeKey,kCmd34ModeKey);
end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
     ReadBuffer;
     if Timer1.Tag = kTimerStartTag0 then //allow one more timer interval to elapse before giving up
        Timer1.Tag := kTimerStartTag1
     else if Timer1.Tag = kTimerStartTag1 then begin
        Timer1.Tag := kTimerFailTag2;
        WriteReturnToKeyMode;
        Timer1.enabled := false;
        ShowMessage('No response from device: please make sure you have selected the correct port.');
     end else if Timer1.Tag = kTimerOKTag3 then begin
        Timer1.Tag := kTimerRunningTag4;
        WriteCmd(false,kCmd2KeyUp,0,GetDebounceFlags); //debounce flags
        WriteCmd(false,kCmd2NumAnalogKeys,0,0); //find out if this board supports analog keys
         WriteCmd(true,kCmd2Mode,kCmd34ModeuSec,kCmd34ModeuSec); //set to uSec Mode
     end;
end;

procedure TForm1.DetectPorts;
var
  ports, port: string;
  l,p: integer;
begin
    ports := GetSerialPortNames;
    ComPortDrop.Items.clear;
    l := length(ports);
    port := '';
    p := 1;
    while p <= l do begin
    	  if (ports[p] <> ',') and (ports[p] <> ' ') then
          	 port := port+ports[p];
          if ((p = l) or (ports[p] = ',') or (ports[p] = ' ')) and (length(port) > 0) then begin
          	 ComPortDrop.Items.Add(port);
             port := '';
          end;
    	  p := p + 1;
    end;
    if (ComPortDrop.Items.Count < 1) then
       showmessage('No com port devices detected. Make sure your StimSync is plugged in and any drivers installed.');
    if (ComPortDrop.Items.Count = 1) then begin
       ComPortDrop.ItemIndex := 0;
       SerialConnect;
    end;
end;

procedure TForm1.ComPortDropChange(Sender: TObject);
begin
  SerialConnect;
end;


procedure TForm1.ComPortDropClick(Sender: TObject);
begin
  if (ComPortDrop.Items.Count < 1) then
     DetectPorts;
end;

procedure TForm1.DefaultsBtnClick(Sender: TObject);
var
  c: integer;
begin
  for c := 1 to DownBox.ControlCount do begin
      if c <= 8 then
         (DownBox.Controls[c-1] as TEdit).Text := inttohex(c,1) ///digital values 1,2,3
      else
         (DownBox.Controls[c-1] as TEdit).Text := inttohex(c+1,1); //Analog values A,B...
  end;
  for c := 1 to UpBox.ControlCount do
      (UpBox.Controls[c-1] as TEdit).Text := '';
  for c := 1 to BindBox.ControlCount do
      (BindBox.Controls[c-1] as TCheckbox).checked := false;
  CoupleDownUpDebounceCheck.checked := false;
  InvertTriggersCheck.checked := false;

end;

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin

   if Timer1.Tag >= kTimerOKTag3 then WriteReturnToKeyMode; //close previous device if currently connected


  //ser.Free;  //This command generates a access violation in Windows
  SerialBuffer := nil;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  ClearMenuClick(sender);
  setlength(SerialBuffer,0);
  ser:=TBlockserial.Create;
  ser.config(460800,8,'N',0,false,true);
  //we have 10 inputs and only 7 outputs, so we can not bind outputs 5,6,7
  (BindBox.Controls[5] as TCheckBox).enabled := false;
  (BindBox.Controls[6] as TCheckBox).enabled := false;
  (BindBox.Controls[7] as TCheckBox).enabled := false;
end;

procedure TForm1.FormShow(Sender: TObject);
begin
      DetectPorts;
end;

procedure TForm1.SaveMenuClick(Sender: TObject);
begin
  If not SaveDialog1.Execute then exit;
  TextOutput.Lines.SaveToFile(SaveDialog1.filename);
end;

procedure TForm1.SetupVisibleMenuClick(Sender: TObject);
begin
    Panel1.visible := not Panel1.visible;
end;

end.

