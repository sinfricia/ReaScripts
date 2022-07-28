reaper.Undo_BeginBlock()

 selectedTrCount = reaper.CountSelectedTracks(0)
 selectedTrSoloCount = 0

--Case 1-- no tracks are soloed
if reaper.AnyTrackSolo()== false then
  
  reaper.Main_OnCommand(40728, 0) -- solo selected tracks
  return
else

  for i = 0, selectedTrCount - 1 do
      tr = reaper.GetSelectedTrack(0, i)
      
      if reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") > 0 then
        selectedTrSoloCount = selectedTrSoloCount + 1
      end
  end
  
  --Case 2-- not all selected tracks are soloed
  if selectedTrSoloCount ~= selectedTrCount then 
    reaper.Main_OnCommand(40340, 0) -- unsolo all
    reaper.Main_OnCommand(40728, 0) -- solo selected tracks
    return
  end 
end



 trCount = reaper.CountTracks(0)
 trSoloCount = 0

for i = 0, trCount - 1 do
    tr = reaper.GetTrack(0, i)
    
    if reaper.GetMediaTrackInfo_Value(tr, "I_SOLO") > 0 then
      trSoloCount = trSoloCount + 1
    end
end

--Case 3-- All soloed tracks in project are selected
--(and all selected tracks are soloed, as else we wouldn't be here)
if trSoloCount == selectedTrSoloCount then
  reaper.Main_OnCommand(40340, 0) -- unsolo all
  test = 1
  return

--Case 4-- Not all soloed tracks in project are selected
--(and all selected tracks are soloed, as else we wouldn't be here)
else
  reaper.Main_OnCommand(40340, 0) -- unsolo all
  reaper.Main_OnCommand(40728, 0) -- solo selected tracks
  return
end
  
reaper.Undo_EndBlock("Change track solo state", -1)



