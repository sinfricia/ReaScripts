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

  if pl.selTrCount == 0 then return end

  local selTr = pl.GetSelectedTracks()
  local isFirst = true
  local doHide = false
  local parents = {}

  -- Iterates through all selected tracks. The visibility of the first playlist track determines --
  -- whether all other selected playlist folders are hidden or shown. --
  for i = 0, pl.selTrCount - 1 do

    parents[i] = pl.GetPlaylistParent(selTr[i])

    -- Make sure current track is a playlist, but if it's not store it for restoring --
    -- user track selection at end of action --
    if parents[i] == nil then
      parents[i] = selTr[i]
      goto skipTrack
    end

    local _, trName = r.GetTrackName(parents[i])

    if string.find(trName, "_t$") or string.find(trName, ".p%d+$") then
      if isFirst then
        local trIndex = r.GetMediaTrackInfo_Value(parents[i], "IP_TRACKNUMBER")
        local child = r.GetTrack(0, trIndex + 1)

        if r.GetMediaTrackInfo_Value(child, "B_SHOWINTCP") == 1 then
          doHide = true
        end

        isFirst = false
      end

      r.SetOnlyTrackSelected(parents[i])
      r.Main_OnCommand(pl.selectOnlyChildren, 0)

      if doHide then
        r.Main_OnCommand(41593, 0) -- hide tracks
        pl.toggleListenToPlaylist(parents[i], parents[i], 1)
      else
        r.Main_OnCommand(pl.showSelectedTracks, 0) -- show tracks
      end
    end
    ::skipTrack::
  end

  pl.exclusiveSelectTracks(parents)
end

r.PreventUIRefresh(1) -- Prevents flickering when showing/hiding tracks.
r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Create new playlist for selected tracks", -1)
r.PreventUIRefresh(-1)
r.UpdateArrange()
