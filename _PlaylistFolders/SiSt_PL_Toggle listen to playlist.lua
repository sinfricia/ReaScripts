local r = reaper

------------- IMPORT PLAYLIST FUNCTIONS MODULE -------------
--[[ Reaper sadly doesn't look for modules in the folder of the executed script, --
--   so we have to tell it where to look by getting the script path. ]]--
local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local pl = require("SiSt_PL_Playlist functions")
------------------------------------------------------------

local function main()
  
  if pl.selTrCount == 0 then return 0 end 
  local selTracks = pl.GetSelectedTracks()
  
  
  
  local parents, parentCount = pl.GetParentsOfGroupedPlaylists(selTracks)
  local playlists, playlistCount = pl.GetPlaylistsWithSameOffsetInGroup(selTracks)
  if playlists == nil then return end -- Make sure a playlist was selected.

  local clearAllListening = false
  if playlistCount > parentCount then 
    clearAllListening = true
    pl.exclusiveSelectTracks(parents)
  end

  local playlistState

  for i = 0, playlistCount - 1 do
    if clearAllListening == true then
      playlistState = 1
    else
      playlistState = pl.GetPlaylistState(playlists[i])
      if playlistState == nil then return end -- Make sure a playlist was selected.
    end

    pl.listenToPlaylist(playlists[i], parents[i], playlistState)
  end

  if clearAllListening then
    reaper.Main_OnCommand(pl.clearAllSelection, 0)
  else
    pl.exclusiveSelectTracks(selTracks)
  end
end


r.PreventUIRefresh(1) -- Prevents flickering.
r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Toggle listen to playlist", -1)
r.PreventUIRefresh(-1)
r.UpdateArrange()

