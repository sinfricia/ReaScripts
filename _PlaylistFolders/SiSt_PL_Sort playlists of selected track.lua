local r = reaper

------------- IMPORT PLAYLIST FUNCTIONS MODULE -------------
--[[ Reaper sadly doesn't look for modules in the folder of the executed script, --
--   so we have to tell it where to look by getting the script path. ]]--
local modulePath = ({r.get_action_context()})[2]:match("^.+[\\/]")
package.path = modulePath .. "?.lua"
local pl = require("SiSt_PL_Playlist functions")
------------------------------------------------------------

local function main()
  
  --[[ This Funciton sorts the selected an all grouped playlist folders. --
  --   The target playlist is put on top, followed by all other playlists in descending order. ]]--


  if pl.selTrCount == 0 then return 0 end
  local selTracks = pl.GetSelectedTracks()
  
  local parents, parentCount, playlistStates, selRestore = pl.GetParentsOfGroupedPlaylists(selTracks)
  if parents == nil then return end -- Make sure a playlist was selected.
  
  for i = 0, parentCount - 1 do
    local count, target = pl.CountPlaylists(parents[i], true, playlistStates[i])
    
    -- Make target playlist parent of playlist folder. --
    pl.SwapPlaylists(target, parents[i], 0)
    

    local parentIndex = r.GetMediaTrackInfo_Value(parents[i], "IP_TRACKNUMBER")
    local playlists = {}
    local playlistName = {}
    local playlistNumber = {}
    local playlistsSorted = {}
    local prevPlaylistsSorted = {}
    local tableIsSorted = false
     
    for j = 0, count - 2 do
      -- Get all the information needed for sorting. --
      playlists[j] = r.GetTrack(0, parentIndex + j)
      _, playlistName[j] = r.GetSetMediaTrackInfo_String(playlists[j], "P_NAME", "", false)
      playlistNumber[j] = tonumber(string.sub(playlistName[j], -2))
      playlistsSorted[j] = playlists[j]
    end
    
    while tableIsSorted == false do
      -- Check if table is sorted, by checking if there was a change compared to the previous order. --
      -- Multiple sorting runs are needed as reordering the tracks might put already sorted playlists in the wrong place agein. --
      for k,v in pairs(playlistsSorted) do 
        if prevPlaylistsSorted[k] == v then
          tableIsSorted = true
        else
          tableIsSorted = false
          for l = 0, count - 2 do
            -- Sort the table by putting each playlist at the parentIndex + playlistNumber. --
            prevPlaylistsSorted[l] = playlistsSorted[l]
            r.SetOnlyTrackSelected(playlists[l])
            r.ReorderSelectedTracks(parentIndex + count - 1 - playlistNumber[l], 0)
            playlistsSorted[l] = r.GetTrack(0, parentIndex + l)
          end
        end
      end
    end
  end
  
  pl.exclusiveSelectTracks(selRestore)
end


r.PreventUIRefresh(1) -- Prevents flickering when reordering tracks.
r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Create new playlist for selected tracks", -1)
r.PreventUIRefresh(-1)
r.UpdateArrange()

