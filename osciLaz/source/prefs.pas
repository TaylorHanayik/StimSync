unit prefs;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, Menus,
  StdCtrls, Spin, ExtCtrls,synaser, userdir, mainprefs;

type

  { TPrefForm }

  TPrefForm = class(TForm)
    AutoSaveLabel1: TLabel;
    AutoSaveLabel2: TLabel;
    Button1: TButton;
    Button2: TButton;
    AutoSaveLabel: TLabel;
    CustomMinMaxCheck: TCheckBox;
    DefaultsBtn: TButton;
    DigitalChannelCheck: TCheckBox;
    AnalogTriggerCheck: TCheckBox;
    DisplayMaxEdit: TFloatSpinEdit;
    DisplayMinEdit: TFloatSpinEdit;
    Label10: TLabel;
    Label11: TLabel;
    Label12: TLabel;
    Label13: TLabel;
    Label3: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    MaxEdit: TFloatSpinEdit;
    MinEdit: TFloatSpinEdit;
    CalibrationPanel: TPanel;
    SuperSamplingEdit: TSpinEdit;
    SelectDirectoryDialog1: TSelectDirectoryDialog;
    SetFolderBtn: TButton;
    ComPortDrop: TComboBox;
    AutoSaveCheck: TCheckBox;
    Label4: TLabel;
    Label5: TLabel;
    GroupBox1: TGroupBox;
    Label1: TLabel;
    Label2: TLabel;
    HighThresholdEdit: TFloatSpinEdit;
    LowThresholdEdit: TFloatSpinEdit;
    TimelineMSEdit: TSpinEdit;
    AnalogChannelsEdit: TSpinEdit;
    SampleRateEdit: TSpinEdit;
    TriggerPositionEdit: TSpinEdit;
    HighPassEdit: TSpinEdit;
    procedure AutoSaveCheckChange(Sender: TObject);
    procedure Button3Click(Sender: TObject);
    procedure CustomMinMaxCheckChange(Sender: TObject);
    procedure DefaultsBtnClick(Sender: TObject);
    procedure DetectPorts;
    procedure AnalogTriggerCheckChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure GroupBox2Click(Sender: TObject);
    procedure Label2Click(Sender: TObject);
    procedure GetPrefs (var lPrefs: TMainPrefs);
    procedure SetPrefs (var lPrefs: TMainPrefs);
    procedure SetFolderBtnClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  PrefForm: TPrefForm;

implementation

{$R *.lfm}

{ TPrefForm }
procedure TPrefForm.SetPrefs (var lPrefs: TMainPrefs);
begin
 with lPrefs do begin
   //integers
   AnalogChannelsEdit.Value := AnalogChannels;
   SampleRateEdit.value := sampleRateHz;
   SuperSamplingEdit.value := superSampling;
   TimelineMSEdit.value := timelineMS;
   TriggerPositionEdit.value := triggerPosition;
   //bools
   DigitalChannelCheck.checked := digitalChannel;
   AutoSaveCheck.checked := autoSave;
   AnalogTriggerCheck.checked := detectAnalogTriggers;
   CustomMinMaxCheck.checked := customMinMax;
   //floats
   HighPassEdit.value := highPassFreqHz;
   HighThresholdEdit.Value := HighAnalogThreshold;
   LowThresholdEdit.Value := LowAnalogThreshold;
   minEdit.Value := calibratedMin;
   maxEdit.Value := calibratedMax;
   displayMinEdit.Value := displayMin;
   displayMaxEdit.Value := displayMax;
   //str
   AutoSaveLabel.caption := autoSaveDir;
 end; //with lPrefs
 AnalogTriggerCheckChange(nil);
 CustomMinMaxCheckChange(nil);
end;//proc SetPrefs

procedure TPrefForm.GetPrefs (var lPrefs: TMainPrefs);
begin
 with lPrefs do begin
   //integers
   AnalogChannels := AnalogChannelsEdit.Value;
   sampleRateHz := SampleRateEdit.value;
   superSampling := SuperSamplingEdit.Value;
   timelineMS := TimelineMSEdit.value;
   triggerPosition := TriggerPositionEdit.value;
   //bools
   digitalChannel := DigitalChannelCheck.checked;
   autoSave := AutoSaveCheck.checked;
   detectAnalogTriggers := AnalogTriggerCheck.checked;
   customMinMax := CustomMinMaxCheck.checked;
   //floats
   highPassFreqHz := HighPassEdit.value;
   HighAnalogThreshold := HighThresholdEdit.value;
   lowAnalogThreshold := lowThresholdEdit.value;
   displayMin := displayMinEdit.value;
   displayMax := displayMaxEdit.value;
   calibratedMin := MinEdit.value;
   calibratedMax := MaxEdit.value;
   //str
   autoSaveDir := AutoSaveLabel.caption;
 end; //with lPrefs
end;//proc GetPrefs

procedure TPrefForm.DetectPorts;
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
       showmessage('No com port devices detected. Make sure the Arduino is plugged and the correct drivers are installed.');
    if (ComPortDrop.Items.Count = 1) then
       ComPortDrop.ItemIndex := 0;
end;

procedure TPrefForm.AutoSaveCheckChange(Sender: TObject);
begin

end;

procedure TPrefForm.Button3Click(Sender: TObject);
begin

end;

procedure TPrefForm.CustomMinMaxCheckChange(Sender: TObject);
begin
  CalibrationPanel.Enabled := CustomMinMaxCheck.checked;
 (*MinEdit.Enabled := CustomMinMaxCheck.checked;
    MaxEdit.Enabled := CustomMinMaxCheck.checked;
    DisplayMinEdit.Enabled := CustomMinMaxCheck.checked;
    DisplayMaxEdit.Enabled := CustomMinMaxCheck.checked;    *)
end;

procedure TPrefForm.DefaultsBtnClick(Sender: TObject);
var lPrefs: TMainPrefs;
begin
 SetDefaultPrefs(lPrefs);
 SetPrefs (lPrefs);
end;

procedure TPrefForm.Label2Click(Sender: TObject);
begin
  SetFolderBtn.enabled := not AutoSaveCheck.checked;
end;

procedure TPrefForm.SetFolderBtnClick(Sender: TObject);
begin
  if SelectDirectoryDialog1.Execute then
     AutoSaveLabel.Caption := SelectDirectoryDialog1.Filename;
end;

procedure TPrefForm.AnalogTriggerCheckChange(Sender: TObject);
begin
    // HighThresholdEdit.enabled := not AnalogTriggerCheck.checked;
end;

procedure TPrefForm.FormCreate(Sender: TObject);
begin
  AutoSaveLabel.caption := UserDataFolder;
  SelectDirectoryDialog1.InitialDir := AutoSaveLabel.caption;
  DetectPorts;

end;

procedure TPrefForm.FormShow(Sender: TObject);
begin
//
end;

procedure TPrefForm.GroupBox2Click(Sender: TObject);
begin

end;

end.

