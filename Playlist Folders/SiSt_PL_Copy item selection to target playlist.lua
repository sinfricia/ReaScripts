-- @noindex
local r = reaper

------------- IMPORT PLAYLIST FUNCTIONS MODULE -------------
--[[ Reaper sadly doesn't look for modules in the folder of the executed script, --
--   so we have to tell it where to look by getting the script path. ]] --
local modulePath = ({ r.get_action_context() })[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local pl = require("SiSt_PL_Playlist functions")
------------------------------------------------------------

local selectTracksWithItemSelected = r.NamedCommandLookup("_SWS_SELTRKWITEM")

local function main()

  r.Main_OnCommand(selectTracksWithItemSelected, 0) -- In case item and track selection is not linked.

  pl.selTrCount = r.CountSelectedTracks()

  if pl.selTrCount == 0 or r.CountSelectedMediaItems(0) == 0 then return 0 end -- Make sure something is selected to perform the action on.


  local selTracks = pl.GetSelectedTracks()
  local hiddenTracks = {} -- To restore track visibility state at the end of the action.
  local hiddenTracksCounter = 0

  -- Getting and configuring time selection state. --
  local start, stop = reaper.GetSet_LoopTimeRange(0, 0, 0, 0, 0)
  if start == stop then r.Main_OnCommand(40290, 0) end -- Set time selection to items to make sure there is a time selection for the copy action.
  local startItem, stopItem = reaper.GetSet_LoopTimeRange(0, 0, 0, 0, 0)

  -- Deactivating "Selecting one item selects group" so we can copy items for grouped tracks individually --
  -- (to make sure they land on the target playlist) --
  local groupToggle = r.GetToggleCommandState(41156)
  if groupToggle == 1 then r.SNM_SetIntConfigVar("projgroupsel", 0) end
  ----

  local groupedTracks, groupedTracksCount = pl.GetPlaylistsWithSameOffsetInGroup(selTracks)
  if groupedTracks == nil then return end -- Making sure a playlist was selected.

  -- Making sure all grouped tracks that are needed to perform the action are visible in the TCP (otherwise copy/paste won't work properly) --
  for i = 0, groupedTracksCount - 1 do
    if r.GetMediaTrackInfo_Value(groupedTracks[i], "B_SHOWINTCP") == 0 then
      r.SetMediaTrackInfo_Value(groupedTracks[i], "B_SHOWINTCP", 1)
      hiddenTracks[hiddenTracksCounter] = groupedTracks[i]
      hiddenTracksCounter = hiddenTracksCounter + 1
    end
  end

  -- Copy and paste the item in the time selection for each selected/grouped track individually. --
  for i = 0, groupedTracksCount - 1 do
    local parent, playlistState = pl.GetPlaylistParent(groupedTracks[i])

    if parent == nil then goto skipTrack end -- Making sure current track is a playlist.

    local _, parentName = r.GetSetMediaTrackInfo_String(parent, "P_NAME", "", false)
    local _, target = pl.CountPlaylists(parent, true, parentName)

    if playlistState == -1 or groupedTracks[i] == target then
      goto skipTrack -- Do Nothing if target was selected or track is not a playlist folder.
    else
      -- Making sure target is visible in the TCP --
      if r.GetMediaTrackInfo_Value(target, "B_SHOWINTCP") == 0 then
        r.SetMediaTrackInfo_Value(target, "B_SHOWINTCP", 1)
        hiddenTracks[hiddenTracksCounter] = target
        hiddenTracksCounter = hiddenTracksCounter + 1
      end

      r.Main_OnCommand(40289, 0) -- unselect all items
      r.SetOnlyTrackSelected(groupedTracks[i])
      r.Main_OnCommand(40718, 0) -- Select all items on selected tracks in current time selection
      r.Main_OnCommand(40060, 0) -- copy selected area of item
      r.SetOnlyTrackSelected(target)
      r.Main_OnCommand(42398, 0) -- paste item
      reaper.SetEditCurPos(startItem, 0, 0) -- Making sure cursor is at the right position to paste on the next track.
    end
    ::skipTrack::
  end


  -- Restoring state from start of action --
  r.SNM_SetIntConfigVar("projgroupsel", groupToggle)
  reaper.GetSet_LoopTimeRange(1, 0, start, stop, 0)
  pl.exclusiveSelectTracks(selTracks)

  for i = 0, hiddenTracksCounter - 1 do
    r.SetMediaTrackInfo_Value(hiddenTracks[i], "B_SHOWINTCP", 0)
  end
end

r.PreventUIRefresh(1) -- Prevents flickering when hiding/unhiding tracks.
r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Copy item selection to target playlist", -1)
r.PreventUIRefresh(-1)
r.UpdateArrange()
