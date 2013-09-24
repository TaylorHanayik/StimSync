%http://cbs.fas.harvard.edu/science/core-facilities/neuroimaging/information-investigators/matlabfaq
stimSyncID = GetStimSyncDeviceIndex;
if isempty(stimSyncID)
    return
end;
keylist=ones(1,256);%%create a list of 256 zeros
KbQueueCreate(stimSyncID(1),keylist);

s1 = SerDeviceIndex;
SerDOut(s1,1,127);
fprintf('(The StimSync outputs should be on)\n');
fprintf('Waiting for a StimSync button press\n');
KbQueueStart();%%start listening
KbQueueFlush();%%removes all keyboard presses
pressed=0;
start_resp_time=GetSecs;
while ~pressed
 [pressed, firstpress] = KbQueueCheck(); %check response
end
RT = GetSecs-start_resp_time;
KbQueueRelease;
fprintf('That took %f seconds\n',RT);
fprintf(' button %d pressed\n',find(firstpress));

fprintf('(The StimSync outputs should be off)\n');
SerDOut(s1,1,0);
fclose(s1);

