--[[
 *  Description: Mastering setup (space items ans create regions)
 *  Author: sinfricia
 *  Version: 1.0
 *  Screenshots: https://imgur.com/mwL56Hr
 *  Links: http://forum.cockos.com/showthread.php?t=169127
 *  Provides: 'SiSt_Mastering setup.lua'
 *  About:
 *    Generates DDP markers from user inputs. Track Names and marker positions are taken from regions prefixed with '#'.
 *  Changelog:
 *    v1.1 (2022-07-29):
 *    - Fixed typo in 'performer' field
 *    - metadata markers now start at index 101, pregap markers at 501
--]]

reaper.Undo_BeginBlock()

  local inputRecieved, retval_csv = reaper.GetUserInputs("Mastering Setup", 3, "Move items, Pause length, # prefix (0/1)", "1,2,1") 
  if inputRecieved == false then return -1 end 
  local moveItems, defaultPause, prefix = retval_csv:match("([^,]*),([^,]*),([^,]*)")

  if prefix ~= "0" and prefix ~= "1" then prefix = 1 end
  if defaultPause == nil or defaultPause:find("%D") or defaultPause == "" then defaultPause = "2" end
  
  defaultPause = tonumber(defaultPause)

  trCount = reaper.CountSelectedMediaItems(0)
  local trLength = {}
  local trPosition = {}
  local trName = {}
  local item = 0
  local albumLength = 2
  
  if trCount < 1 then
    return 0
  else
    reaper.BR_SetArrangeView( 0, 0,1.5)
    for i = 0, trCount - 1 do
      item = reaper.GetSelectedMediaItem(0,i)
      trLength[i] = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
      trPosition[i] = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
      retval, trName[i] =  reaper.GetSetMediaTrackInfo_String(reaper.GetMediaItemInfo_Value(item, "P_TRACK"), "P_NAME", "", 0 )
      
      if prefix == "1" then trName[i] = "#" .. trName[i] end
      
      if moveItems == "1" then 
        reaper.SetMediaItemInfo_Value(item, "D_POSITION", albumLength)
        trPosition[i] = albumLength
        albumLength = reaper.SnapToGrid(0, albumLength + trLength[i] + defaultPause)
      end
      reaper.AddProjectMarker(0, 1, trPosition[i], trPosition[i] + trLength[i], trName[i], i+1)
    end
  end
  
  reaper.SetEditCurPos(0, 1, 0)
  reaper.Main_OnCommand(40635, 1) --remove time selection
  reaper.Main_OnCommand(40296, 1) --select all tracks
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_VZOOMFIT"), 1) --zoom to selected tracks verticaally
  reaper.Main_OnCommand(40769, 1) --unselect tracks and items
  reaper.Main_OnCommand(40295, 1) --zoom out to project horizontally

reaper.Undo_EndBlock("Mastering Setup", -1)
    
