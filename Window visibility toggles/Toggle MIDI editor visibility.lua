local MIDIEditor = reaper.MIDIEditor_GetActive()
local editorExists = reaper.JS_Window_IsWindow(MIDIEditor)
local Mixer = reaper.JS_Window_Find( "Mixer",1 ) 
local itemCount =  reaper.CountSelectedMediaItems()

if  reaper.JS_Window_IsVisible(MIDIEditor) then
    reaper.JS_Window_Destroy(MIDIEditor)
    
elseif editorExists and reaper.JS_Window_IsVisible(MIDIEditor) == false then
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SN_FOCUS_MIDI_EDITOR"), 0)
  
elseif  editorExists == false and  itemCount > 0 then
  reaper.Main_OnCommand(40153, 0) -- Open in built in MIDI editor
  local MIDIEditor = reaper.MIDIEditor_GetActive()
  reaper.MIDIEditor_OnCommand(MIDIEditor, 40466) -- zoom to content
  reaper.MIDIEditor_OnCommand(MIDIEditor, 40112) -- zoom out vertically
  reaper.MIDIEditor_OnCommand(MIDIEditor, 1011) -- zoom out horizontally
  
else
  reaper.Main_OnCommand(40716, 0) -- Toggle show MIDI editor windows
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SN_FOCUS_MIDI_EDITOR"), 0)
  
end

if Mixer then
  reaper.JS_Window_Destroy(Mixer)
end
