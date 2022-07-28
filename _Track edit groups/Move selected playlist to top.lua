function msg(input)
  reaper.ShowConsoleMsg(tostring(input) .. "\n")
end

local selTrCount = reaper.CountSelectedTracks()
local trCount = reaper.CountTracks()
local clearAllSelection = reaper.NamedCommandLookup("_SWS_UNSELALL")
local selectAllFolders = reaper.NamedCommandLookup("_SWS_SELALLPARENTS")




function table.contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end





local function exclusiveSelectTracks(tracks)
  reaper.Main_OnCommand(clearAllSelection, 0)
  
  for i = 0, #tracks do
    reaper.SetMediaTrackInfo_Value(tracks[i], "I_SELECTED", 1)
  end
end




local function GetSelectedTracks()
  local tr = {}
  for i = 0, selTrCount - 1 do
    tr[i] = reaper.GetSelectedTrack(0, i)
  end
  
  return tr
end




local function ValidateTrack(tr)
  if reaper.ValidatePtr(tr, "MediaTrack*") == false then
    error("Function was not given a valid track.")
  else return true end
end
  
  
  
  
local function GetGroupedTracks(tr)

  local groupedTracks = {}
  local groupedTracks = {}
  local groupedTracksCount = 0
  local trGroups = {}
  local trGroupCount = 0
  local groupState = reaper.GetSetTrackGroupMembership(tr, "RECARM_LEAD", 0, 0) 
                     + (reaper.GetSetTrackGroupMembershipHigh(tr, "RECARM_LEAD", 0, 0) << 32)
                    
  for i = 0, 63 do
    if groupState & 1 == 1 then 
      trGroups[trGroupCount] = i 
      trGroupCount = trGroupCount + 1
    end
    groupState = groupState >> 1
  end

  for i = 0, trCount - 1 do
    local currentTr = reaper.GetTrack(0, i)
    
    for j = 0, trGroupCount - 1 do
      groupState = reaper.GetSetTrackGroupMembership(currentTr, "RECARM_LEAD", 0, 0) 
                   +  (reaper.GetSetTrackGroupMembershipHigh(currentTr, "RECARM_LEAD", 0, 0) << 32)
      
      if (groupState >> trGroups[j]) & 1 == 1 and table.contains(groupedTracks, currentTr) == false and currentTr ~= tr then
        groupedTracks[groupedTracksCount] = currentTr
        groupedTracksCount = groupedTracksCount + 1
      end
    end
  end
  

  return groupedTracks, groupedTracksCount, trGroups
end






function GetPlaylistState(tr, trName)

  if trName == nil then
    _, trName = reaper.GetTrackName(tr)
  end
  
  local folderState = reaper.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
  local trIndex = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
  local trDepth = reaper.GetTrackDepth(tr)
  local hasChild = false
  local isTarget = false
  local isPlaylist = false
  
  if trIndex ~= trCount then
    if trDepth - reaper.GetTrackDepth(reaper.GetTrack(0, trIndex)) == -1 then
      hasChild = true
    end
  end
  
  if string.find(trName, "_t$") ~= nil then
    isTarget = true
  end
  if string.find(trName, ".p%d+$")~= nil then
    isPlaylist = true
  end
    
  
  -- Case 1: Track is playlist in a playlist folder--
  if folderState < 1 and (isTarget or isPlaylist) then
    return 0
  -- Case 2 Track is a playlist folder parent --
  elseif folderState == 1 and (isTarget or isPlaylist) and hasChild then
    return 1
  -- case 3: Track is a normal track --
  elseif folderState < 1 and isTarget == false and isPlaylist == false then
    return -1
  else
    error("Track is a Buss.")
  end
end




local function SwapPlaylists(trA, trB, isNewPlaylist)

  ValidateTrack(trA)
  ValidateTrack(trB)
  
  -- SWAP NAMES--
  local _, nameA = reaper.GetTrackName(trA)
  local _, nameB = reaper.GetTrackName(trB)
  reaper.GetSetMediaTrackInfo_String(trA, "P_NAME", nameB, true)
  reaper.GetSetMediaTrackInfo_String(trB, "P_NAME", nameA, true)
  
  --[[-- SWAP COLORS -- (only if not called as part of new playlist creation)--
  if isNewPlaylist ~= true then
    local colorA = reaper.GetTrackColor(trA)
    local colorB = reaper.GetTrackColor(trB)
    reaper.SetTrackColor( trA, colorB )
    reaper.SetTrackColor( trB, colorA )
  end]]--
    
  -- SWAP VOLUMES --
  local volumeA = reaper.GetMediaTrackInfo_Value( trA, "D_VOL" )
  local volumeB = reaper.GetMediaTrackInfo_Value( trB, "D_VOL" )
  reaper.SetMediaTrackInfo_Value(trA, "D_VOL", volumeB)
  reaper.SetMediaTrackInfo_Value(trB, "D_VOL", volumeA)

  -- SWAP ITEMS --
  local chunkA = ""
  local _, chunkA = reaper.GetTrackStateChunk(trA, chunkA, 0)
  local itemChunkA = string.match(chunkA, "<ITEM.+")
  if itemChunkA == nil then
    itemChunkA = ">"
  end
  
  local chunkB = ""
  local _, chunkB = reaper.GetTrackStateChunk(trB, chunkB, 0)
  local itemChunkB = string.match(chunkB, "<ITEM.+")
  if itemChunkB == nil then
    itemChunkB = ">"
  end
  
  chunkA = string.gsub(chunkA, "<ITEM.+", ">")
  chunkB = string.gsub(chunkB, "<ITEM.+", ">")
  chunkA = string.gsub(chunkA, ">%s*$", itemChunkB)
  chunkB = string.gsub(chunkB, ">%s*$", itemChunkA)
  
  reaper.SetTrackStateChunk(trA, chunkA, 1)
  reaper.SetTrackStateChunk(trB, chunkB, 1)
  
  return
end




local function CountPlaylists(parent, findTarget, playlistState, parentName)

  ValidateTrack(parent)
  
  if parentName == nil then
    _, parentName = reaper.GetTrackName(parent)
  end
  
  local target = 0
  
  -- Check if track is actually a parent --
  if playlistState == -1 then 
    return 0
  end
   
  local count = 1
  local parentIndex = reaper.GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER")
  local playlistIndex = parentIndex
  local playlist = reaper.GetTrack(0, playlistIndex)
  local _, playlistName = reaper.GetTrackName(playlist)
  
  if string.find(parentName, "_t$") ~= nil then
    target = parent
  end
  
  -- iterate through all playlists to count them and optionally find the target playlist by name --
  while reaper.GetParentTrack(playlist) == parent do
  
    count = count + 1
  
    if target == 0 and findTarget == true then
      _, playlistName = reaper.GetTrackName(playlist)
      if string.find(playlistName, "_t$") ~= nil then
        target = playlist
      end
    end
    
    playlist = reaper.GetTrack(0, playlistIndex + count -1)
    
    --If we arrive at the last track of a session, playlist will be nill --
    if playlist == nil then break end
  end 
  
  if findTarget == true then return count, target
  else return count end
  
end





local function GetPlaylistParent(tr)

  ValidateTrack(tr)
  
  local playlistState = GetPlaylistState(tr)
  local parent

  if playlistState == 1 or playlistState == - 1 then
    parent = tr
  elseif playlistState == 0 then
    parent = reaper.GetParentTrack(tr)
  else 
    error("Something went wrong with getting the parent track.")
  end 
  
  return parent, playlistState
end




local function BuildGrpTableForSelPlaylists(selTracks)

  local parents = {}
  local groupedTracks = {}
  local playlistStates = {}
  local selRestore = {}
  local parentCount = 0
   
   
  for i = 0, selTrCount - 1 do
  
    local parent, playlistState = GetPlaylistParent(selTracks[i])
      
    if table.contains(parents, parent) == false then
      parents[parentCount] = parent
      playlistStates[parentCount] = playlistState
      selRestore[parentCount] = parents[parentCount]
      local groupedTracks, groupedTracksCount, parentGroups = GetGroupedTracks(parents[parentCount])
      
      parentCount = parentCount + 1
      
      

      for j = 0, groupedTracksCount - 1 do
        parents[parentCount] = groupedTracks[j]
        playlistStates[parentCount] = GetPlaylistState(groupedTracks[j])
        parentCount = parentCount + 1
      end
    end
  end
  
  return parents, parentCount, playlistStates, selRestore
end





local function GetPlaylistIndexOffset(tr)
  local parent = GetPlaylistParent(tr)
  local parentIndex = reaper.GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER")
  local playlistIndex = reaper.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")

  return playlistIndex - parentIndex
end




local function GetPlaylistsWithSameOffsetInGroup(selTracks)

  local parents, parentCount, playlistStates = BuildGrpTableForSelPlaylists(selTracks)
  local parentIndex = {}
  
   indexToSel = {}
   playlists = {}
   playlistCount = 0

  for i = 0, selTrCount - 1 do
    local currentOffset = GetPlaylistIndexOffset(reaper.GetSelectedTrack(0, i)) - 1

    if table.contains(indexToSel, currentOffset) == false then
      indexToSel[i] = currentOffset

    end
  
    for i= 0, parentCount - 1 do
       count = CountPlaylists(parents[i], 0, playlistStates[i])
       count = count - 1
      local parentIndex = reaper.GetMediaTrackInfo_Value(parents[i], "IP_TRACKNUMBER")
      
      for j = 0, #indexToSel do
 
        if indexToSel[j] < count then
          pl = reaper.GetTrack(0, parentIndex + indexToSel[j])
            playlists[playlistCount] = pl
            playlistCount = playlistCount + 1
          
        end
      end
    end
  end
  
  return playlists, playlistCount
end








local function main()
  
  if selTrCount == 0 then return 0 end 
  
  local selTracks = {}
  local selTracks = GetSelectedTracks()
  
   parents, parentCount, _, selRestore = BuildGrpTableForSelPlaylists(selTracks)
   playlists = GetPlaylistsWithSameOffsetInGroup(selTracks)

  for i = 0, parentCount - 1 do
    SwapPlaylists(playlists[i], parents[i], 0)
    
  end
  
  exclusiveSelectTracks(selRestore)
  
end


reaper.PreventUIRefresh(1)
reaper.Undo_BeginBlock()
main()
reaper.Undo_EndBlock("Move target playlist to top", -1)
reaper.PreventUIRefresh(-1)
reaper.UpdateArrange()







