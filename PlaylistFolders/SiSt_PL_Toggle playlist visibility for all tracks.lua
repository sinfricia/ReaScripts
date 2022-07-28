local r = reaper

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
      
    if string.find(trName, "_t$") or string.find(trName, ".p%d+$") then
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