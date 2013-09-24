function [indexes] = GetStimSyncDeviceIndex;
%returns the device index[es] for any StimSyncs attached to the keyboard
% returns empty if no StimSyncs attached
% note that this can return the addresses of multiple devices
% indexes(1) will be the first address

% inspired by  http://tech.groups.yahoo.com/group/psychtoolbox/message/4402
indexes = []; % Initialization.
devices = PsychHID('Devices');
for i = 1:length(devices)
  if (strcmp(devices(i).usageName,'Keyboard'))
    if (strcmp(devices(i).transport,'USB'))
      if (strcmp(devices(i).manufacturer,'Teensyduino'))
        indexes = [indexes i];
        fprintf('Detected a StimSync  device number %d\n',i);
      end
    end
  end
end
if isempty(indexes)
  disp('WARNING: No StimSyncs detected');
end