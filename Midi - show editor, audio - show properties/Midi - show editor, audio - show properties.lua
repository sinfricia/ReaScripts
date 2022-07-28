
local selectedItem = reaper.GetSelectedMediaItem( 0, 0 )
local activeTake = reaper.GetActiveTake( selectedItem )
if activeTake then
   isMidi = reaper.TakeIsMIDI(activeTake)
end

if isMidi == true then
  
  if reaper.MIDIEditor_GetActive() then
    reaper.Main_OnCommand(reaper.NamedCommandLookup("_SN_FOCUS_MIDI_EDITOR"), 0)
    local hwnd = reaper.MIDIEditor_GetActive() 
    reaper.MIDIEditor_OnCommand(hwnd, 40466) -- zoom to content
    reaper.MIDIEditor_OnCommand(hwnd, 40112) -- zoom out vertically
    reaper.MIDIEditor_OnCommand(hwnd, 1011) -- zoom out horizontally
  
  else
    reaper.Main_OnCommand(40153, 0) -- open midi editor
    local hwnd = reaper.MIDIEditor_GetActive()
    reaper.MIDIEditor_OnCommand(hwnd, 40466) -- zoom to content
    reaper.MIDIEditor_OnCommand(hwnd, 40112) -- zoom out vertically
  end
  
else 
  reaper.Main_OnCommand(40009, 0) -- show media item properties
end
