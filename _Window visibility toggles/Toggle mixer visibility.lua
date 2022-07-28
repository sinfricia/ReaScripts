Mixer = reaper.JS_Window_Find( "Mixer",1 )
 
if Mixer then
  reaper.JS_Window_Destroy(Mixer)
else
  reaper.Main_OnCommand(40078, 0) -- Toggle mixer visible
  Mixer = reaper.JS_Window_Find( "Mixer",1 )
  reaper.JS_Window_SetFocus(Mixer)
end
  
if reaper.MIDIEditor_GetActive() then
  reaper.Main_OnCommand(40716, 0) -- Toggle MIDI editor visible
end
