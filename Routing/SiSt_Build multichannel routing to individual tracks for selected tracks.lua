--[[
 * ReaScript Name: Build multichannel routing to individual tracks for selected tracks
 * Author: sinfricia
 * Licence: GPL v3
 * Version: 1.0
--]]
--[[
 * Changelog:
 * v1.0 (2024-03-23)
  + Initial Release
--]]

local r = reaper
r.ClearConsole()

function Msg(input)
  local str = tostring(input)
  r.ShowConsoleMsg(str .. "\n")
end

local sel_tr_count = r.CountSelectedTracks(0)

for i = 0, sel_tr_count - 1 do
  local tr = r.GetSelectedTrack(0, i)
  local ch_count = r.GetMediaTrackInfo_Value(tr, "I_NCHAN")
  local tr_number = r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER")
  r.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)

  for j = 0, ch_count - 1 do
    local idx = tr_number + j
    r.InsertTrackAtIndex(idx, true)
    local rec_tr = r.GetTrack(0, idx)

    r.CreateTrackSend(tr, rec_tr)
    r.SetTrackSendInfo_Value(tr, 0, j, "I_SRCCHAN", j + 1024)
    r.SetTrackSendInfo_Value(tr, 0, j, "D_VOL", 1)

    local ch_digit_count = math.floor(math.log(ch_count, 10) + 1)

    local tr_name = "ch " .. string.format("%0" .. ch_digit_count .. "i", j + 1)
    r.GetSetMediaTrackInfo_String(rec_tr, "P_NAME", tr_name, true)
  end
end
