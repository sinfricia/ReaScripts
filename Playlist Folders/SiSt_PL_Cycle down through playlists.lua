-- @noindex
local r = reaper

------------- IMPORT PLAYLIST FUNCTIONS MODULE -------------
--[[ Reaper sadly doesn't look for modules in the folder of the executed script, --
--   so we have to tell it where to look by getting the script path. ]] --
local modulePath = ({ r.get_action_context() })[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local pl = require("SiSt_PL_Playlist functions")
------------------------------------------------------------

local function main()

  if pl.selTrCount == 0 then return 0 end

  local selTracks = pl.GetSelectedTracks()

  local parents, parentCount, playlistStates, _ = pl.GetParentsOfGroupedPlaylists(selTracks)
  if parents == nil then return end -- Make sure a playlist was selected.


  for i = 0, parentCount - 1 do

    if playlistStates[i] == -1 then goto skipTrack end

    pl.toggleListenToPlaylist(parents[i], parents[i], 1)

    -- Swap parent playlist with playlist right below parent. --
    local parentIndex = r.GetMediaTrackInfo_Value(parents[i], "IP_TRACKNUMBER")
    local nextTrack = r.GetTrack(0, parentIndex)
    pl.SwapPlaylists(parents[i], nextTrack, 0)


    local count, _ = pl.CountPlaylists(parents[i], playlistStates)
    r.SetOnlyTrackSelected(nextTrack)

    -- Move previous parent to the bottom of the playlist folder to preserve playlist order.  --
    -- But not if there's only a parent and 1 child as this would break the folder structure. --
    if count > 2 then
      r.ReorderSelectedTracks(parentIndex + count - 1, 2)
    end

    ::skipTrack::
  end

  pl.exclusiveSelectTracks(selTracks)

end

r.PreventUIRefresh(1) -- Prevents flickering when swapping tracks.
r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Cycle down through playlists", -1)
r.PreventUIRefresh(-1)
r.UpdateArrange()
