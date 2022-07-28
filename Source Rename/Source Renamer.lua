function SplitFilename(strFilename)
  -- Returns the Path, Filename, and Extension as 3 values
  return string.match(strFilename, "(.-)([^\\]-([^\\%.]+))$")
end

item = reaper.GetSelectedMediaItem(0, 0)
take = reaper.GetActiveTake(item)
source = reaper.GetMediaItemTake_Source(take)
sourceName = ""
sourceName = reaper.GetMediaSourceFileName(source, sourceName)
sourceExtension = string.match(sourceName, "[^\\%.]+$")

_, newSourceName = reaper.GetUserInputs("New source name", 1, "", "")
newSourceName = newSourceName.."."..sourceExtension
reaper.Main_OnCommand(42356, 0) -- force selected media offline
_, _ = reaper.GetSetMediaItemTakeInfo_String(take, "P_NAME", newSourceName, true )
newSourceName = string.gsub(sourceName, "[^\\/]-$","")..newSourceName
os.rename(sourceName, newSourceName)
reaper.BR_SetTakeSourceFromFile2(take, newSourceName, true, true )
