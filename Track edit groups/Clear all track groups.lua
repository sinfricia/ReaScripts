reaper.Undo_BeginBlock()

local trCount = reaper.CountTracks(0)
local tr = 0
local groupMask = 4294967295
local groupingParam = "RECARM_LEAD"

reaper.Main_OnCommand(40182, 0) -- select all items
reaper.Main_OnCommand(40033, 0) --remove item from group
reaper.Main_OnCommand(40289, 0) -- unselect all items
reaper.Main_OnCommand(40297, 0) -- unselect all tracks

for i = 0, trCount - 1 do
  tr = reaper.GetTrack(0, i)
  reaper.GetSetTrackGroupMembership(tr, groupingParam, groupMask, 0)
end



reaper.Undo_EndBlock("Clear all track groups", -1)
