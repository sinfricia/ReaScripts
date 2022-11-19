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

  local parents, parentCount, _, selRestore = pl.GetParentsOfGroupedPlaylists(selTracks)
  if parents == nil then return end -- Making sure a playlist was selected.

  local playlists, _ = pl.GetPlaylistsWithSameOffsetInGroup(selTracks)
  if playlists == nil then return end -- Making sure a playlist was selected.

  for i = 0, parentCount - 1 do
    pl.toggleListenToPlaylist(parents[i], parents[i], 1)
    pl.SwapPlaylists(parents[i], playlists[i])
  end


  pl.exclusiveSelectTracks(selRestore)

end

r.PreventUIRefresh(1) -- Prevents flickering when swapping tracks.
r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Move selected playlist to top", -1)
r.PreventUIRefresh(-1)
r.UpdateArrange()
