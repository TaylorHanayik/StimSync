function err=SerDOut(ser,port,data)
%Sets digital ouputs of serial port device
%  Useful for Teensy/Arduino Output box
%  Currently only supports 1 port (8 outputs)
%   ser  : name of open serial port
%   port : IGNORED - provides compatibility with DaqDOut
%   data : a value 0..127 independently controlling 7 digital outputs
%Example
%  See SerDeviceIndex for usage examples  
%Similar to
%  DaqDOut


while (data > 127) data=data-128; end;

fwrite(ser,data);