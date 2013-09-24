function ser=SerDeviceIndex(DeviceName,IShouldWarn)
% Send binary values to Serial Port
%  Useful with Arduino/Teensy output device
%   DeviceName  : [optional] name of port, e.g. 'COM1'
%   IShouldWarn : visual dialog box if unable to connect
%
%
%Example:
%  s1 = SerDeviceIndex;
%  SerDOut(s1,1,127);
%  h=helpdlg('all serial port outputs should be on');
%  uiwait(h);
%  SerDOut(s1,1,0);
%  disp('all serial port outputs should be off');
%  fclose(s1);
%Similar to
%  DaqDeviceIndex


%CHECK ARGUMENTS
if nargin < 2 || isempty(IShouldWarn)
  IShouldWarn=1;
end
if ~nargin || isempty(DeviceName)
  % MK note: DeviceName as set here could be anything -- doesn't matter for further processing.  
  if (ispc) 
    DeviceName = 'COM2';
  else
    %DeviceName = '/dev/tty.usbmodem12341';
    [ok, ser] = system('ls /dev/cu.*');
    ser = regexp(ser,'\s','split');
    ser = ser(~cellfun(@isempty, ser)); %deblank
    if isempty(ser)
        fprintf('Warning: no serial port devices found attached to this computer.');
        DeviceName = '/dev/tty.usbmodem12341';
    else
        
        Index = find(not(cellfun('isempty', strfind(ser, 'us'))));
        if isempty(Index)
            DeviceName = ser(1);
        else
            DeviceName = ser(Index(1));  %choose first port that matches our search string
        end;
       
        DeviceName = DeviceName{1} %convert cell to string
    end; %if ser exists
  end;
  fprintf('SerDeviceIndex assuming device is named %s\n', DeviceName);
end;

if (license('test', 'Instr_Control_Toolbox'))
    fprintf('You have the Instrument Control Toolbox Installed.\n');
    fprintf(' SerDeviceIndex was written without access to the ICT.\n');
    fprintf(' it could be improved with ICT functions like instrhwinfo(''serial'')');
end;


if IShouldWarn
    fprintf('SerDeviceIndex will attempt to open %s\n', DeviceName);
    fprintf(' If this fails, please make sure it is plugged in.\n');
    fprintf('   On some computers you may need to install driver software.\n');
    if (ispc)
        fprintf(' You can check the active serial ports in the device manager.\n');    
    else
        fprintf('Possible device names are:\n');
        system('ls /dev/cu.*');
    end;
end;
%CHECK IF REQUESTED PORT IS AVAILABLE
ser = serial(DeviceName);%,'BaudRate',115200);
fopen(ser);

%Current versions of Matlab halt the script if fopen fails
% therefore the code below is never displayed. 
if (~IShouldWarn && strcmp(get(ser,'Status'),'closed'))
    fprintf('Unable to find device %s\n', DeviceName);
    fprintf(' Please make sure your device is plugged and drivers are installed.\n');
    if (ispc)
        fprintf(' You can check the port in the device manager.\n');    
    else
        fprintf('Possible device names are:\n');
        system('ls /dev/cu.*');
    end;
end;

