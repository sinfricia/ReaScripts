-- @description Playlist Folders
-- @author sinfricia
-- @version 0.9.01
-- @about
--  # Playlist Folders
--
--  Features:
--   Create Pro Tools style playlists in Reaper.
--   Record on automatically numbered playlists, then assemble your takes on a target playlist.
--   Cycle through your playlists or move specific playlists to the top.
--   Toggle solo (listen) to specific playlists.
--   All actions (should) work with playlists hidden.
--   All actions (should) work on grouped tracks using Reapers native track grouping system. Use the "Record Arm Lead" parameter.
--   Running an action on one track will run it for all grouped tracks. Even without their playlists showing!
--   If you ever accidentally move a playlist of a grouped track or want to restore order in your playlist folders you can automatically sort them again by number.
-- @provides
--  [main] SiSt_PL_Copy item selection to target playlist.lua
--  [main] SiSt_PL_Create new playlists for selected tracks.lua
--  [main] SiSt_PL_Cycle down through playlists.lua
--  [main] SiSt_PL_Cycle up through playlists.lua
--  [main] SiSt_PL_Duplicate selected playlist.lua
--  [main] SiSt_PL_Move selected playlist to top.lua
--  [main] SiSt_PL_Move target playlist to top.lua
--  [main] SiSt_PL_Select all playlists in group with same offset to parent (runs in background).lua
--  [main] SiSt_PL_Sort playlists of selected track.lua
--  [main] SiSt_PL_Toggle listen to playlist.lua
--  [main] SiSt_PL_Toggle playlist visibility for all tracks.lua
--  [main] SiSt_PL_Toggle playlist visibility for selected tracks.lua
-- @changelog
--  - Cycling playlists on tracks without playlists now works as expected, aka does nothing.
--  - Toggling visibility now properly respects hidden tracks, aka does nothing to them.
--  - Reworked the listening to playlist function. Should be much more usable now.

local pl = {}
local r = reaper -- in lua accessing local variables/functions is a lot faster.




--+++++++++ USER CONIGURABLE VARIABLES +++++++++--

pl.playlistColor = 27830440 -- This is the default playlist color. If you want the playlist to inherit the parent color see the NewPlaylist and DuplicatePlaylist functions below.
pl.userPlaylistColoring = false -- Set this to true if you want to be able to color your playlists freely after creating them.
pl.playlistLayout = "C" -- This is the name of the track layout that is automatically applied to your playlists.
pl.groupingParameter = "RECARM_LEAD" -- This is the track grouping parameter the actions respect, when performing them on grouped tracks.

--++++++++++++++++++++++++++++++++++++++++++++++--


----------------------------------------------------------------------------------------------------
--------- DEBUGGING FUNCTIONS -----------

function pl.ValidateTrack(tr)
  if r.ValidatePtr(tr, "MediaTrack*") == false then
    error("Function was not given a valid track.")
  else return true end
end

function pl.msg(input)
  r.ShowConsoleMsg(tostring(input) .. "\n")
end

----------------------------------------------------------------------------------------------------
--------- GLOBAL VARIABLES ------------

pl.selTrCount = r.CountSelectedTracks()
pl.trCount = r.CountTracks()
pl.clearAllSelection = r.NamedCommandLookup("_SWS_UNSELALL")
pl.selectAllFolders = r.NamedCommandLookup("_SWS_SELALLPARENTS")
pl.selectOnlyChildren = r.NamedCommandLookup("_SWS_SELCHILDREN")
pl.showSelectedTracks = reaper.NamedCommandLookup("_SWSTL_BOTH")


----------------------------------------------------------------------------------------------------
--------- UTILITY FUNCTIONS -----------

function pl.tableContains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end

function pl.exclusiveSelectTracks(tracks)
  r.Main_OnCommand(pl.clearAllSelection, 0)

  for k, v in pairs(tracks) do
    r.SetMediaTrackInfo_Value(v, "I_SELECTED", 1)
  end
end

function pl.GetSelectedTracks()
  local tr = {}
  for i = 0, pl.selTrCount - 1 do
    tr[i] = r.GetSelectedTrack(0, i)
  end

  return tr
end

function pl.GetGroupedTracks(tr)

  local groupedTracks = {}
  local groupedTracksCount = 0
  local trGroups = {}
  local trGroupCount = 0

  -- This returns a 64 bit value with each bit representing the state of the grouping parameter for the correspondig group --
  local groupState = r.GetSetTrackGroupMembership(tr, pl.groupingParameter, 0, 0)
      + (r.GetSetTrackGroupMembershipHigh(tr, pl.groupingParameter, 0, 0) << 32)

  -- Checking the groupState for group memberships and storing them.
  for i = 0, 63 do
    if groupState & 1 == 1 then
      trGroups[trGroupCount] = i
      trGroupCount = trGroupCount + 1
    end
    groupState = groupState >> 1
  end

  -- Find all tracks grouped with tr in the project...
  for i = 0, pl.trCount - 1 do
    local currentTr = r.GetTrack(0, i)

    -- ...for every group membership tr has. --
    for j = 0, trGroupCount - 1 do
      groupState = r.GetSetTrackGroupMembership(currentTr, pl.groupingParameter, 0, 0)
          + (r.GetSetTrackGroupMembershipHigh(currentTr, pl.groupingParameter, 0, 0) << 32)

      if (groupState >> trGroups[j]) & 1 == 1 and pl.tableContains(groupedTracks, currentTr) == false and currentTr ~= tr then
        groupedTracks[groupedTracksCount] = currentTr
        groupedTracksCount = groupedTracksCount + 1
      end
    end
  end

  return groupedTracks, groupedTracksCount, trGroups
end

----------------------------------------------------------------------------------------------------
--------- PLAYLIST FUNCTIONS ----------

function pl.GetPlaylistState(tr, trName)

  --[[--- PLAYLIST STATES: ---

      0 = Track is playlist in a playlist folder
      1 = Track is a playlist folder parent
     -1 = Track is a normal track

     Else the track is a folder with non playlist tracks in it or otherwise invalid.

  ]] --

  if trName == nil then
    _, trName = r.GetTrackName(tr)
  end

  local folderState = r.GetMediaTrackInfo_Value(tr, "I_FOLDERDEPTH")
  local trIndex = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
  local trDepth = r.GetTrackDepth(tr)
  local hasChild = false
  local isTarget = false
  local isPlaylist = false

  -- If tr isn't last track in project check if it has children.
  if trIndex ~= pl.trCount then
    if trDepth - r.GetTrackDepth(r.GetTrack(0, trIndex)) == -1 then
      hasChild = true
    end
  end

  if string.find(trName, "_t$") ~= nil then
    isTarget = true
  end
  if string.find(trName, ".p%d+$") ~= nil then
    isPlaylist = true
  end


  -- Case 1: Track is playlist in a playlist folder --
  if folderState < 1 and (isTarget or isPlaylist) then return 0
    -- Case 2 Track is a playlist folder parent --
  elseif folderState == 1 and (isTarget or isPlaylist) and hasChild then return 1
    -- Case 3: Track is a normal track --
  elseif folderState < 1 and isTarget == false and isPlaylist == false then return -1

  else return nil end
end

function pl.SwapPlaylists(trA, trB, isNewPlaylist)

  ---- When creating or moving playlists we don't actually move the tracks around, just their attributes. ----

  -- SWAP NAMES --
  local _, nameA = r.GetTrackName(trA)
  local _, nameB = r.GetTrackName(trB)

  r.GetSetMediaTrackInfo_String(trA, "P_NAME", nameB, true)
  r.GetSetMediaTrackInfo_String(trB, "P_NAME", nameA, true)

  -- SWAP COLORS -- (only if not called as part of new playlist creation)
  if pl.userPlaylistColoring == true and isNewPlaylist ~= true then
    local colorA = reaper.GetTrackColor(trA)
    local colorB = reaper.GetTrackColor(trB)
    reaper.SetTrackColor(trA, colorB)
    reaper.SetTrackColor(trB, colorA)
  end

  -- SWAP ITEMS -- (by extracting the item portion of the track state chunk of both playlists and swapping them)
  local _, chunkA = r.GetTrackStateChunk(trA, "", 0)
  local itemChunkA = string.match(chunkA, "<ITEM.+")
  if itemChunkA == nil then
    itemChunkA = ">"
  end

  local _, chunkB = r.GetTrackStateChunk(trB, "", 0)
  local itemChunkB = string.match(chunkB, "<ITEM.+")
  if itemChunkB == nil then
    itemChunkB = ">"
  end

  chunkA = string.gsub(chunkA, "<ITEM.+", ">")
  chunkB = string.gsub(chunkB, "<ITEM.+", ">")
  chunkA = string.gsub(chunkA, ">%s*$", itemChunkB)
  chunkB = string.gsub(chunkB, ">%s*$", itemChunkA)

  r.SetTrackStateChunk(trA, chunkA, 1)
  r.SetTrackStateChunk(trB, chunkB, 1)

end

function pl.CountPlaylists(parent, findTarget, playlistState, parentName)

  ----[[ This function counts all playlists in a playlist folder including the target and/or parent.   ----
  ----   In addition it let's you find the target playlist of a playlist folder. In order to minimize  ----
  ----   iterating through all tracks in a playlist folder these two functions are combined here.       ]]--

  -- Let the function be called without specifying all parameters: --
  if findTarget == nil then findTarget = false end
  if parentName == nil then
    _, parentName = r.GetTrackName(parent)
  end
  if playlistState == nil then
    playlistState = pl.GetPlaylistState(parent, parentName)
  end
  -------------------------------------------------------------------

  -- Check if track is actually a parent --
  if playlistState == -1 then
    return 0
  end


  local target = 0
  local count = 1
  local parentIndex = r.GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER")
  local playlistIndex = parentIndex
  local playlist = r.GetTrack(0, playlistIndex)
  local _, playlistName = r.GetTrackName(playlist)


  if string.find(parentName, "_t$") ~= nil then
    target = parent
  end

  -- Iterate through all playlists in the folder to count them and optionally find the target playlist by name. --
  while r.GetParentTrack(playlist) == parent do

    count = count + 1
    if target == 0 and findTarget == true then
      _, playlistName = r.GetTrackName(playlist)
      if string.find(playlistName, "_t$") ~= nil then
        target = playlist
      end
    end

    playlist = r.GetTrack(0, playlistIndex + count - 1)

    -- If we arrive at the last track of a session, playlist will be nil. --
    if playlist == nil then break end
  end

  if findTarget == true then return count, target
  else return count end

end

function pl.GetPlaylistParent(tr)

  local playlistState = pl.GetPlaylistState(tr)
  local parent


  if playlistState == 1 or playlistState == -1 then
    parent = tr
  elseif playlistState == 0 then
    parent = r.GetParentTrack(tr)

    -- Checking for normal track with playlist/target name extension --
    if parent == nil then
      playlistState = -1
      parent = tr
    end

    local _, parentName = r.GetTrackName(parent)

    if string.find(parentName, "_t$") == nil and string.find(parentName, ".p%d+$") == nil then
      playlistState = -1
      parent = tr
    end

  else
    return nil
  end

  return parent, playlistState
end

function pl.GetNewPlaylistName(parent, parentName, playlistState, isDuplicate)

  -- Let the function be called without specifying all parameters: --
  if parentName == nil then
    _, parentName = r.GetTrackName(parent)
  end
  if playlistState == nil then
    playlistState = pl.GetPlaylistState(parent, parentName)
  end
  -------------------------------------------------------------------

  local targetName
  local newPlaylistName

  local playlistNumber, target = pl.CountPlaylists(parent, true, playlistState)
  local playlistSuffix = ".p" .. string.format("%02d", tostring(playlistNumber))


  if parent == target and isDuplicate == false then
    newPlaylistName = string.gsub(parentName, "_t$", playlistSuffix)
  else
    newPlaylistName = string.gsub(parentName, ".p%d+$", playlistSuffix)

    -- make sure we don't create a second target when duplicating playlists
    if isDuplicate == true then
      if string.find(newPlaylistName, "_t$") then
        newPlaylistName = string.gsub(parentName, "_t$", playlistSuffix)
      end
    end
  end

  if playlistState == -1 then
    targetName = parentName .. "_t"
    newPlaylistName = parentName .. ".p01"
  end

  return newPlaylistName, targetName

end

function pl.NewPlaylist(parent, playlistState)

  local _, parentName = r.GetTrackName(parent)
  local parentIndex = r.GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER")

  local newPlaylistName, targetName = pl.GetNewPlaylistName(parent, parentName, playlistState, false)

  r.InsertTrackAtIndex(parentIndex, 0)
  local newPlaylist = r.GetTrack(0, parentIndex)


  if playlistState == -1 then
    r.GetSetMediaTrackInfo_String(parent, "P_NAME", targetName, true)

    -- If parent is last track in a folder we need to make sure the folder structure is preserved after adding --
    -- the first new playlist. --
    local depthParent = r.GetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH")
    local depthPlaylist = r.GetMediaTrackInfo_Value(newPlaylist, "I_FOLDERDEPTH")

    r.SetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH", 1)

    if depthParent - depthPlaylist ~= 0 then
      r.SetMediaTrackInfo_Value(newPlaylist, "I_FOLDERDEPTH", -2)
    else
      r.SetMediaTrackInfo_Value(newPlaylist, "I_FOLDERDEPTH", -1)
    end

  else
    r.SetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH", 1)
  end

  -- If playlists of playlist folder are hidden also hide new playlist. --
  if playlistState > -1 then
    if r.GetMediaTrackInfo_Value(r.GetTrack(0, parentIndex + 1), "B_SHOWINTCP") == 0 then
      r.SetMediaTrackInfo_Value(newPlaylist, "B_SHOWINTCP", 0)
    end
  end

  r.SetMediaTrackInfo_Value(newPlaylist, "B_MAINSEND", 0)
  r.SetTrackColor(newPlaylist, pl.playlistColor) -- User configurable. For parent color set this to: r.GetTrackColor(parent)
  r.GetSetMediaTrackInfo_String(newPlaylist, "P_TCP_LAYOUT", pl.playlistLayout, true)
  r.SetMediaTrackInfo_Value(newPlaylist, "B_SHOWINMIXER", 0)
  r.GetSetMediaTrackInfo_String(newPlaylist, "P_NAME", newPlaylistName, true)

  pl.SwapPlaylists(parent, newPlaylist, true)
end

function pl.DuplicatePlaylist(playlist)

  local parent, playlistState = pl.GetPlaylistParent(playlist)
  local _, playlistName = r.GetTrackName(playlist)
  local parentIndex = r.GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER")

  local newPlaylistName = pl.GetNewPlaylistName(parent, playlistName, playlistState, true)

  -- Check if track is part of a playlist folder. --
  if playlistState == -1 or nil then
    return 0
  end


  r.InsertTrackAtIndex(parentIndex, 0)
  pl.trCount = pl.trCount + 1

  local newPlaylist = r.GetTrack(0, parentIndex)
  r.SetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH", 1)

  -- If playlists of playlist folder are hidden also hide new playlist. --
  if r.GetMediaTrackInfo_Value(r.GetTrack(0, parentIndex + 1), "B_SHOWINTCP") == 0 then
    r.SetMediaTrackInfo_Value(newPlaylist, "B_SHOWINTCP", 0)
  end
  r.SetMediaTrackInfo_Value(newPlaylist, "B_MAINSEND", 0)
  r.SetTrackColor(newPlaylist, pl.playlistColor) -- User configurable. For parent color set this to: r.GetTrackColor(parent)
  r.GetSetMediaTrackInfo_String(newPlaylist, "P_TCP_LAYOUT", pl.playlistLayout, true)
  r.SetMediaTrackInfo_Value(newPlaylist, "B_SHOWINMIXER", 0)
  r.GetSetMediaTrackInfo_String(newPlaylist, "P_NAME", newPlaylistName, true)

  -- Copy Items from orignial to duplicate playlist. --
  local _, chunkA = r.GetTrackStateChunk(playlist, "", 0)
  local itemChunkA = string.match(chunkA, "<ITEM.+")
  if itemChunkA == nil then
    itemChunkA = ">"
  end

  local _, chunkB = r.GetTrackStateChunk(newPlaylist, "", 0)
  local itemChunkB = string.match(chunkB, "<ITEM.+")
  if itemChunkB == nil then
    itemChunkB = ">"
  end

  chunkA = string.gsub(chunkA, "<ITEM.+", ">")
  chunkB = string.gsub(chunkB, "<ITEM.+", ">")
  chunkB = string.gsub(chunkB, ">%s*$", itemChunkA)

  r.SetTrackStateChunk(newPlaylist, chunkB, 1)

  pl.SwapPlaylists(parent, newPlaylist, true)
end

function pl.GetParentsOfGroupedPlaylists(selTracks)

  ----[[ GROUPING IN PLAYLIST FOLDERS:
  ----   Only the parents of playlist folders must be grouped. All group related activity is derived   ----
  ----   from the parent track of a playlist folder.       ]]--

  local parents = {}
  local playlistStates = {}
  local selRestore = {} -- Used to restore user track selection at the end of the action.
  local parentCount = 0

  -- Build a table that includes the parents of the currently selected tracks and all grouped playlist folder parents. --
  for i = 0, pl.selTrCount - 1 do

    local parent, playlistState = pl.GetPlaylistParent(selTracks[i])
    selRestore[i] = parent

    if parent == nil then return nil end -- Making sure track is part of a playlist folder.


    -- Every parent and its grouped parents must be added to the table only once even when there are multiple tracks of the same group selected. --
    if pl.tableContains(parents, parent) == false then
      parents[parentCount] = parent
      playlistStates[parentCount] = playlistState
      parentCount = parentCount + 1


      local groupedTracks, groupedTracksCount, _ = pl.GetGroupedTracks(parents[parentCount - 1])

      for j = 0, groupedTracksCount - 1 do
        parents[parentCount] = groupedTracks[j]
        playlistStates[parentCount] = pl.GetPlaylistState(groupedTracks[j])

        if playlistStates[parentCount] == nil then return nil end -- Making sure track is part of a playlist folder.

        parentCount = parentCount + 1

      end
    end
  end

  return parents, parentCount, playlistStates, selRestore
end

function pl.GetPlaylistIndexOffset(tr, parent)

  -- Let the function be called without specifying all parameters: --
  if parent == nil then
    parent = pl.GetPlaylistParent(tr)
  end
  -------------------------------------------------------------------

  local parentIndex = r.GetMediaTrackInfo_Value(parent, "IP_TRACKNUMBER")
  local playlistIndex = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")

  return playlistIndex - parentIndex
end

function pl.GetPlaylistsWithSameOffsetInGroup(selTracks)

  ---- Returns tracks with same offset from parent in grouped playlist folders as well as already selected tracks! ----

  local playlists = selTracks

  local playlistCount = pl.selTrCount

  --[[ Every tracks' grouped tracks are looked at sperately so each group can be treated indidually. For example:   ----
  ---- When duplicating playlist 3 from group 1 and playlist 2 from group 2 we need to make sure playlist 3 from   ----
  ---- group 2 is not also duplicated. Every group can have its own offsets. ]] --
  for i = 0, pl.selTrCount - 1 do
    local parent = pl.GetPlaylistParent(selTracks[i])

    if parent == nil then return nil end -- Making sure track is part of a playlist folder.

    local currentOffset = pl.GetPlaylistIndexOffset(selTracks[i], parent) - 1
    local groupedTracks, groupedTracksCount = pl.GetGroupedTracks(parent)

    for j = 0, groupedTracksCount - 1 do
      local groupedTrackIndex = r.GetMediaTrackInfo_Value(groupedTracks[j], "IP_TRACKNUMBER")
      local currPl = r.GetTrack(0, groupedTrackIndex + currentOffset)

      -- Making sure every track is added to the table only once. --
      if pl.tableContains(playlists, currPl) == false then
        playlists[playlistCount] = currPl
        playlistCount = playlistCount + 1
      end
    end
  end

  return playlists, playlistCount
end

function pl.toggleListenToPlaylist(playlist, parent, playlistState)

  local listenString = "(pl.solo) "
  local listenStringEscaped = "%(pl%.solo%) "

  -- Let the function be called without specifying all parameters: --
  if parent == nil then
    parent = pl.GetPlaylistParent(playlist)
  end
  if playlistState == nil then
    playlistState = pl.GetPlaylistState(parent)
  end
  -------------------------------------------------------------------

  if playlistState == -1 then return end -- Making sure track is part of a playlist folder.

  local isParentSending = r.GetMediaTrackInfo_Value(playlist, "B_MAINSEND")
  local _, parentName = r.GetTrackName(parent)
  local _, itemGUIDS = r.GetProjExtState(0, "PlaylistFolders", r.GetTrackGUID(parent))

  if not itemGUIDS then
    itemGUIDS = ""
  end

  r.SetOnlyTrackSelected(parent)
  r.Main_OnCommand(pl.selectOnlyChildren, 0)

  -- Case 1: Playlist was selected and it is currently not in listening mode. --
  if isParentSending == 0 and playlistState == 0 then
    for i = 0, r.CountSelectedTracks(0) - 1 do

      local currentTr = r.GetSelectedTrack(0, i)

      -- Mute all other playlists
      if currentTr == playlist then
        r.SetMediaTrackInfo_Value(currentTr, "B_MUTE", 0)
        r.SetMediaTrackInfo_Value(currentTr, "I_SOLO", 0)
        r.SetMediaTrackInfo_Value(currentTr, "B_MAINSEND", 1)
      else
        r.SetMediaTrackInfo_Value(currentTr, "B_MUTE", 1)
        r.SetMediaTrackInfo_Value(currentTr, "I_SOLO", 0)
        r.SetMediaTrackInfo_Value(currentTr, "B_MAINSEND", 0)
      end
    end

    -- Store all unmuted items
    local parentItemCount = r.CountTrackMediaItems(parent)


    if itemGUIDS == "" then
      for i = 0, parentItemCount - 1 do
        local item = r.GetTrackMediaItem(parent, i)

        if r.GetMediaItemInfo_Value(item, "B_MUTE") == 0 then
          r.SetMediaItemInfo_Value(item, "B_MUTE", 1)
          itemGUIDS = itemGUIDS .. r.BR_GetMediaItemGUID(item) .. ","
        end
      end

      r.SetProjExtState(0, "PlaylistFolders", r.GetTrackGUID(parent), itemGUIDS)
    end

    if not parentName:find(listenStringEscaped) then
      r.GetSetMediaTrackInfo_String(parent, 'P_NAME', listenString .. parentName, 1)
    end

    -- Case 2: Playlist was selected and it is currently in listening mode. --
  else
    for i = 0, r.CountSelectedTracks(0) - 1 do
      local currentTr = r.GetSelectedTrack(0, i)
      r.SetMediaTrackInfo_Value(currentTr, "B_MUTE", 0)
      r.SetMediaTrackInfo_Value(currentTr, "I_SOLO", 0)
      r.SetMediaTrackInfo_Value(currentTr, "B_MAINSEND", 0)
    end

    -- Restore all muted items to unmuted state
    for w in itemGUIDS:gmatch("([^,]*),") do
      local item = r.BR_GetMediaItemByGUID(0, w)

      if item then
        r.SetMediaItemInfo_Value(item, "B_MUTE", 0)
      end
    end

    r.GetSetMediaTrackInfo_String(parent, 'P_NAME', string.gsub(parentName, listenStringEscaped, ""), 1)
    r.SetProjExtState(0, "PlaylistFolders", r.GetTrackGUID(parent), "")
  end
end

----------------------------------------------------------------------------------------------------

return pl
