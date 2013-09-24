from psychopy import visual, core, event, data #import some libraries from PsychoPy
stimList = [{'cond': 1}]
nReps = 10 #number of repititions per condition
trials = data.TrialHandler(stimList,nReps,dataTypes='RT')
mywin = visual.Window([800,600],allowGUI="false",fullscr="false", units="norm", color=-1)
mywin.setMouseVisible(False)
#create some stimuli
dark = visual.PatchStim(win=mywin, size=0.1, pos=[0,0], sf=0, color=0, colorSpace='rgb')
bright = visual.PatchStim(win=mywin, size=1, pos=[-0.5,0.5], sf=0, color=1, colorSpace='rgb')
#draw the stimuli and update the window
event.clearEvents()
startTime = core.Clock() # make a clock for capturing RT (reaction time)
for thisTrial in trials: #handler can act like a for loop
    bright.draw()
    mywin.callOnFlip(startTime.reset) # reaction time starts immediately after flip
    mywin.flip()
    dark.draw()
    responses = event.waitKeys(timeStamped=startTime)
    #trials.addData('RT', startTime.getTime())
    trials.addData('RT', responses[0][1])
    mywin.flip()
    core.wait(0.4)
#display and save data
trials.printAsText(stimOut=['cond'],dataOut=['RT_mean','RT_std'])
trials.saveAsText(fileName='testData',stimOut=['cond'],dataOut=['RT_raw'])