reaper.Undo_BeginBlock()

local selTrCount = reaper.CountSelectedTracks(0)
local trCount = reaper.CountTracks(0)
local tr = 0
local item = 0
local groupNumber = 0
local groupMask = 0
local prevGroupMask = 0
local itemGroupStart = 0
local groupingParam = "RECARM_LEAD"


-- find first unused group
for i = 0, trCount - 1 do
  tr = reaper.GetTrack(0, i)
  groupMask = reaper.GetSetTrackGroupMembership(tr, groupingParam, 0, 0)
  groupMask = prevGroupMask | groupMask
  prevGroupMask = groupMask
end

for i = 0, 32 do
  if groupMask >> i & 1 == 0 then
    groupNumber = i + 1
    break
  end
end
  
-- set group mask so bit at index of first unused group is 1
groupMask = 1 << groupNumber - 1
itemGroupStart = 1000 * groupNumber

-- add selected Tracks to group by enabling grouping parameter and group all items one by one
for i = 0, selTrCount - 1 do
  tr = reaper.GetSelectedTrack(0, i)
  reaper.GetSetTrackGroupMembership(tr, groupingParam, groupMask, groupMask)
  local itemCount = reaper.CountTrackMediaItems(tr)
  
  for j = 0, itemCount - 1 do
    item = reaper.GetTrackMediaItem(tr, j)
    reaper.SetMediaItemInfo_Value(item, "I_GROUPID", itemGroupStart + j)
  end
end

reaper.UpdateArrange()

reaper.Undo_EndBlock("Create track edit group " .. tostring(groupNumber), -1)
