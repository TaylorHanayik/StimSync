unit format_all;
//this unit determines file format
interface

uses SysUtils, eeg_type,  format_tms32, format_vhdr, dialogs ;

function WriteEEG(lFilename: string; var lEEG: TEEG): boolean;


implementation


function WriteEEG(lFilename: string; var lEEG: TEEG): boolean;
var
  Ext: string;
begin
      result := false;
      Ext:=UpperCase(ExtractFileExt(lFileName));
      if  Ext='.VHDR'  then
        result := WriteVHDR(lFilename,lEEG)
      else if  Ext='.S00'  then
        result := WriteTMS32(lFilename,lEEG)
      //else if Ext='.EDF' then
      //  result := WriteEDF(lFilename,lEEG)
      else
        showmessage('Unknown format '+lFilename);
end;

end.

