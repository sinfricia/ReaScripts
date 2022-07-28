reaper.Undo_BeginBlock()

  local trackCount = reaper.CountSelectedTracks(0)
  if trackCount < 1 then return end
  
  for i = 0, trackCount -1 do
    local track = reaper.GetSelectedTrack(0, i)
    local monitorMode = reaper.GetMediaTrackInfo_Value(track, "I_RECMON" )
  
    if monitorMode == 0 then
      reaper.SetMediaTrackInfo_Value(track, "I_RECMON", 1)
    else
      reaper.SetMediaTrackInfo_Value(track, "I_RECMON", 0)
    end
  end
 
 
reaper.Undo_EndBlock( "Toggle track record monitoring", 0 )
 
