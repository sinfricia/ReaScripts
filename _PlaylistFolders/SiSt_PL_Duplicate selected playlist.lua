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
  local selRestore = {} -- Used to restore user track selection at the end of the action.

  local tracksToProcess, tracksToProcessCount = pl.GetPlaylistsWithSameOffsetInGroup(selTracks)
  if tracksToProcessCount == 0 or tracksToProcess == nil then return end

  for i = 0, tracksToProcessCount - 1 do
    pl.DuplicatePlaylist(tracksToProcess[i])
    selRestore[i] = pl.GetPlaylistParent(tracksToProcess[i])
  end

  pl.exclusiveSelectTracks(selRestore)

end


r.PreventUIRefresh(1) -- Prevents flickering when swapping tracks.
r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Create new playlist for selected tracks", -1)
r.PreventUIRefresh(-1)
r.UpdateArrange()

