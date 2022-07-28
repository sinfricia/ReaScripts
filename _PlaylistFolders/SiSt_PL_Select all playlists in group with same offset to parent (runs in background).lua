local r = reaper

------------- IMPORT PLAYLIST FUNCTIONS MODULE -------------
--[[ Reaper sadly doesn't look for modules in the folder of the executed script, --
--   so we have to tell it where to look by getting the script path. ]]--
local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local pl = require("SiSt_PL_Playlist functions")
------------------------------------------------------------

pl.selTrCount = 0
pl.trCount = 0
local lastSelTrCount = 0
local selTr1 = nil
local lastSelTr1 = nil


local function mainloop()

  pl.selTrCount = r.CountSelectedTracks(0) 
  pl.trCount = r.CountTracks(0)
  selTr1 = r.GetSelectedTrack(0, 0)
  
  -- If track selection has changed: --
  if pl.selTrCount ~= lastSelTrCount or selTr1 ~= lastSelTr1 then
    r.PreventUIRefresh(1) -- Prevents flickering

    local selTracks = pl.GetSelectedTracks()
    
    local playlists, playlistCount = pl.GetPlaylistsWithSameOffsetInGroup(selTracks)
    if playlists == nil then goto skip end -- Do nothing if no playlists were selected.
    
    for i = 0, playlistCount - 1 do
      r.SetTrackSelected(playlists[i], 1)
    end
        
    lastSelTrCount = pl.selTrCount
    lastSelTr1 = selTr1
    
    ::skip::
    r.PreventUIRefresh(-1)
  end
  r.defer(mainloop)
end


mainloop ()

