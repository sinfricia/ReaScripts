reaper.Undo_BeginBlock()

  local userInput = ""
  local inputRecieved, userInput = reaper.GetUserInputs("Enter region number", 1, "", "")
  local regionIndex = tonumber(userInput)

  if regionIndex ~= nil then
    reaper.GoToRegion(0, regionIndex, false )
  else
    return
  end
  
reaper.Undo_EndBlock("Jump to region...", -1)
