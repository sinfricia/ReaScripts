local r = reaper

r.Undo_BeginBlock()

local selTrCount = r.CountSelectedTracks(0)

if selTrCount == 0 then
    return
end

local firstSelTr = r.GetSelectedTrack(0, 0)
local lastSelTr = r.GetSelectedTrack(0, selTrCount-1)
local index = r.GetMediaTrackInfo_Value(firstSelTr, "IP_TRACKNUMBER") - 1
local folderColor = reaper.GetTrackColor(firstSelTr)

r.InsertTrackAtIndex(index, 0)
local parent = r.GetTrack(0, index)

local retval, parentName = r.GetUserInputs("Name track:", 1, "Folder Name:,extrawidth=100", "")

if retval == false then
    reaper.DeleteTrack(parent)
    return
end

r.SetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH", 1)
r.GetSetMediaTrackInfo_String(parent, "P_NAME", parentName, 1)
r.SetMediaTrackInfo_Value(parent, "I_CUSTOMCOLOR", folderColor)
r.SetMediaTrackInfo_Value(lastSelTr, "I_FOLDERDEPTH", -1)

r.Undo_EndBlock("Create new folder", -1)

r.UpdateArrange()