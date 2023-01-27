-- @description Smart folder state toggle (skip minimized)
-- @author sinfricia
-- @version 1.0.0
-- @about
--   This script allows you to to open/close a folder while having the parent or any child of it selected.
-- @changelog
--  Initial release




local trackCount = reaper.CountSelectedTracks(0)

if trackCount ~= 0 then

  local selectedTrack = 0
  local hash = {}
  local allParents = {}
  local relevantParents = {}
  local ParentCounter = 1
  local firstLvlParents = {}
  local isFirstLvl = false


  for i = 1, trackCount do
    selectedTrack = reaper.GetSelectedTrack(0, i - 1)

    if reaper.GetMediaTrackInfo_Value(selectedTrack, "I_FOLDERDEPTH") ~= 1 then
      allParents[ParentCounter] = reaper.GetMediaTrackInfo_Value(selectedTrack, "P_PARTRACK")
      firstLvlParents[i] = allParents[ParentCounter]
    else
      allParents[ParentCounter] = selectedTrack
      firstLvlParents[i] = allParents[ParentCounter]
    end

    while allParents[ParentCounter] ~= 0 do
      allParents[ParentCounter + 1] = reaper.GetMediaTrackInfo_Value(allParents[ParentCounter], "P_PARTRACK")
      ParentCounter = ParentCounter + 1
    end
  end

  table.remove(allParents, ParentCounter)


  for i, v in ipairs(allParents) do
    if not hash[v] then
      relevantParents[#relevantParents + 1] = v
      hash[v] = true
    end
  end


  for i = 1, #relevantParents do
    isFirstLvl = false
    for j, v in ipairs(firstLvlParents) do
      if v == relevantParents[i] then
        isFirstLvl = true
        break
      end
    end

    if reaper.GetMediaTrackInfo_Value(relevantParents[i], "I_FOLDERCOMPACT") == 2 then
      reaper.SetMediaTrackInfo_Value(relevantParents[i], "I_FOLDERCOMPACT", 0)

    elseif isFirstLvl == true then
      reaper.SetMediaTrackInfo_Value(relevantParents[i], "I_FOLDERCOMPACT", 2)

    else end
  end

  reaper.Main_OnCommand(40913, 0) -- Vertical scroll selected tracks into view

else
  return 0
end
