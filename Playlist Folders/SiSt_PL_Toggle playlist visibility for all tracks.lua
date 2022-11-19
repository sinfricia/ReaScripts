-- @noindex
local r = reaper

------------- IMPORT PLAYLIST FUNCTIONS MODULE -------------
--[[ Reaper sadly doesn't look for modules in the folder of the executed script, --
--   so we have to tell it where to look by getting the script path. ]] --
local modulePath = ({ r.get_action_context() })[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local pl = require("SiSt_PL_Playlist functions")
------------------------------------------------------------

local showSelectedTracks = r.NamedCommandLookup("_SWSTL_BOTH")
local selectOnlyChildren = r.NamedCommandLookup("_SWS_SELCHILDREN")

local function main()

  local trCount = r.CountTracks(0)

  local isFirst = true
  local doHide = false

  -- Iterates through all tracks. The visibility of the first playlist track determines --
  -- whether all playlist tracks are hidden or shown. --
  for i = 0, trCount - 1 do

    local tr = r.GetTrack(0, i)
    local _, trName = r.GetTrackName(tr)
    local playlistState = pl.GetPlaylistState(tr)
    local isVisible = r.GetMediaTrackInfo_Value(tr, "B_SHOWINTCP")

    if playlistState == 1 and isVisible == 1 then
      if isFirst then
        local trIndex = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
        local child = r.GetTrack(0, trIndex + 1)

        if r.GetMediaTrackInfo_Value(child, "B_SHOWINTCP") == 1 then
          doHide = true
        else
          doHide = false
        end

        isFirst = false
      end

      r.SetOnlyTrackSelected(tr)
      r.Main_OnCommand(selectOnlyChildren, 0)

      if doHide then
        r.Main_OnCommand(41593, 0) -- hide tracks
        pl.toggleListenToPlaylist(tr, tr, 1)
      else
        r.Main_OnCommand(showSelectedTracks, 0) -- show tracks
      end
    end
  end

  r.Main_OnCommand(40769, 0) -- Unselect everything
end

r.PreventUIRefresh(1) -- Prevents flickering when showing/hiding tracks.
main()
r.PreventUIRefresh(-1)
r.UpdateArrange()
