local groupNumber = 7


local trCount = reaper.CountTracks(0)
local groupMask = 1 << groupNumber - 1
local trGroup = 0
local relevantTr = {}
local item = {}
local groupSize = 0
local itemGroupStart = groupNumber * 1000
local groupingParam = "RECARM_LEAD"

--get all tracks in group and put them in relevantTr[]
for i = 0, trCount - 1 do
  tr = reaper.GetTrack(0, i)
  trGroup = reaper.GetSetTrackGroupMembership(tr, groupingParam, 0, 0)
  
  if  trGroup >> groupNumber - 1 & 1 == 1 then
    relevantTr[groupSize] = tr
    groupSize = groupSize + 1
  end
end


--link items of track group
for i = 0, groupSize - 1 do
  itemCount = reaper.CountTrackMediaItems(relevantTr[i])
  
  for j = 0, itemCount - 1 do
    item[j] = reaper.GetTrackMediaItem(relevantTr[i], j)
    reaper.SetMediaItemInfo_Value(item[j], "I_GROUPID", itemGroupStart + j)
  end
end

reaper.UpdateArrange()
