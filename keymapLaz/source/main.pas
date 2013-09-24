unit main;

//{$mode objfpc}{$H+}
{$mode delphi}{$H+}
interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, Spin, Menus, synaser;

type

  { TForm1 }

  TForm1 = class(TForm)
    ComPortDrop: TComboBox;
    Down1: TEdit;
    Down10: TEdit;
    Down11: TEdit;
    Down12: TEdit;
    Down2: TEdit;
    Down3: TEdit;
    Down4: TEdit;
    Down5: TEdit;
    Down6: TEdit;
    Down7: TEdit;
    Down8: TEdit;
    Down9: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
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
    SpinEdit1: TSpinEdit;
    StatusGroup: TCheckGroup;
    Timer1: TTimer;
    Up1: TEdit;
    Up10: TEdit;
    Up11: TEdit;
    Up12: TEdit;
    Up2: TEdit;
    Up3: TEdit;
    Up4: TEdit;
    Up5: TEdit;
    Up6: TEdit;
    Up7: TEdit;
    Up8: TEdit;
    Up9: TEdit;
    ser:TBlockSerial;

    procedure ComPortDropChange(Sender: TObject);
    procedure ComPortDropClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure SaveMenuClick(Sender: TObject);
    procedure SetupVisibleMenuClick(Sender: TObject);
    procedure StatusGroupClick(Sender: TObject);
    procedure DetectPorts;
    procedure SerialConnect;
    procedure Timer1Timer(Sender: TObject);
    procedure ReadBuffer;
    procedure DecodeBuffer;
    procedure ShowStatus(keyBits: integer);
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
const
  kNumKeys = 12;
{ TForm1 }

procedure TForm1.ShowStatus(keyBits: integer);
var
    i: integer;
begin
    for i := 1 to (kNumKeys-1) do
        StatusGroup.Checked[i-1] := odd( (keyBits shr (i-1)) and 1);
end;

procedure TForm1.SerialConnect;
begin
     ser.Connect(ComPortDrop.Text);
     MappingBox.enabled := true;
     Timer1.enabled := true;
end;

procedure TForm1.DecodeBuffer;
const
  packetBytes = 8;
var
  tempBuffer: array of byte;
  serialBytes: array[0..packetBytes] of byte;
  keyBits, samples, len,pos, c, checkSumStored, checkSum: integer;
  uSec : Longword;
begin
  samples := 0;
  len := length(SerialBuffer);
  if (len < packetBytes) then exit; //no new packets
    pos := 0;
    while ((len-pos) >= packetBytes) do begin
         for c :=0 to (packetBytes-1) do
             serialBytes[c] := SerialBuffer[pos+c]; //initialize output so unused channels report 0
         checkSumStored := serialBytes[7];
         checkSum  :=
             serialBytes[0]+ serialBytes[1]+serialBytes[2]+serialBytes[3]+
               serialBytes[4]+ serialBytes[5]+serialBytes[6];
         while (checkSum > $ff) do
               checkSum :=(checkSum shr 8)+(checkSum and $ff);
         if (checkSum = checkSumStored) then begin
             keyBits :=  (serialBytes[1] shl 8) +  serialBytes[2];
             uSec :=  serialBytes[6] + (serialBytes[5] shl 8) + (serialBytes[4] shl 16) +  (serialBytes[3] shl 24);
             TextOutput.lines.add ( inttostr(keyBits)+ chr(9) + inttostr(uSec));
             pos := pos + 8;
             samples := samples + 1;
         end else begin//if checksum matches else try to find a valid checksum
             //the checksum does not match - disregard oldest byte and try again
             pos := pos + 1;

         end;
     end;//while potential blocks to read
    //display current key status
    if samples > 0 then
       ShowStatus(keyBits);
     //caption := inttostr( keyBits)+' '+inttostr(pos);   //show information in window title

     //empty all read bytes from the buffer
     if (pos >= len) then
        setlength(SerialBuffer,0)
     else begin
         len := len-pos;
         setlength(tempBuffer,len);
         for c :=0 to (len-1) do
             tempBuffer[c] :=  SerialBuffer[pos+c];
        setlength(SerialBuffer,len);
         for c :=0 to (len-1) do
             SerialBuffer[c] := tempBuffer[c];
         tempBuffer := nil;
     end;
      // caption := inttostr(totalSize);
end; //DecodeBuffer

procedure TForm1.ReadBuffer;
type
	byteRA0 = array [0..0] of byte;
        Bytep0 = ^ByteRA0;
const
  kBufSz = 4096;
var
  buffer: Bytep0;
  recvSize, totalSize, i,t : integer;
begin
  totalSize := length(SerialBuffer);
  getmem(buffer,kBufSz);
  t := 0;
  repeat
   recvSize := ser.RecvBufferEx(buffer, kBufSz, 0);
   if (recvSize > 0) then begin
      inc(t);
      SetLength(SerialBuffer, totalSize+ recvSize);
      for i := 0 to (recvSize -1) do
          SerialBuffer[totalSize+i] := buffer[i];
      totalSize := totalSize + recvSize;
   end;
  until (recvSize < kBufSz);
  freemem(buffer);
  DecodeBuffer;
  //caption := inttostr(totalSize);


end;

procedure TForm1.Timer1Timer(Sender: TObject);
begin
     ReadBuffer;

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
       showmessage('No com port devices detected. Make sure your StimSync is plugged in and blinking (jumper on J1).');
    if (ComPortDrop.Items.Count = 1) then begin
       ComPortDrop.ItemIndex := 0;
       //caption := (ComPortDrop.Text);
       SerialConnect;
    end;
end;

procedure TForm1.StatusGroupClick(Sender: TObject);
begin

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

procedure TForm1.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  ser.Free;
  SerialBuffer := nil;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
     setlength(SerialBuffer,0);
     ser:=TBlockserial.Create;
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

