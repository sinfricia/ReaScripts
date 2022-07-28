reaper.Undo_BeginBlock()

  local userInput = ""
  local inputRecieved, userInput = reaper.GetUserInputs("Enter marker number", 1, "", "")
  local markerIndex = tonumber(userInput)

  if markerIndex ~= nil then
    reaper.GoToMarker(0, markerIndex, false )
  else
    return
  end
  
reaper.Undo_EndBlock("Jump to marker...", -1)
