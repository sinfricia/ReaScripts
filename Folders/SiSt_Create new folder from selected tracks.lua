-- @description Create new folder from selected tracks (respecting existing folders)
-- @author sinfricia
-- @version 1.0.0
-- @about
--  This Script let's you quickly create folders from selected tracks while keeping already existing folders untouched in their structure.
-- @changelog
--  - Initial release


local r = reaper

local function msg(input)
  r.ShowConsoleMsg(tostring(input) .. "\n")
end

local function findLastChildTrack(parent_tr)
  local tr_count = r.CountTracks(0)
  local curr_tr = parent_tr
  local curr_tr_idx = r.GetMediaTrackInfo_Value(parent_tr, "IP_TRACKNUMBER")
  local curr_tr_depth = r.GetMediaTrackInfo_Value(curr_tr, 'I_FOLDERDEPTH')

  if curr_tr_depth ~= 1 then return end

  local folder_level = 1

  while true do
    curr_tr = r.GetTrack(0, curr_tr_idx)

    curr_tr_depth = r.GetMediaTrackInfo_Value(curr_tr, 'I_FOLDERDEPTH')
    folder_level = folder_level + curr_tr_depth

    if folder_level <= 0 then
      return curr_tr, curr_tr_depth
    end

    curr_tr_idx = curr_tr_idx + 1

    if curr_tr_idx == tr_count then
      return false
    end
  end
end

local function main()

  local sel_tr_count = r.CountSelectedTracks(0)

  if sel_tr_count == 0 then return end

  local first_tr = r.GetSelectedTrack(0, 0)
  local first_tr_depth = r.GetMediaTrackInfo_Value(first_tr, 'I_FOLDERDEPTH')
  local first_tr_idx = r.GetMediaTrackInfo_Value(first_tr, "IP_TRACKNUMBER") - 1
  local last_tr = r.GetSelectedTrack(0, sel_tr_count - 1)
  local last_tr_depth = r.GetMediaTrackInfo_Value(last_tr, 'I_FOLDERDEPTH')
  local last_tr_idx = r.GetMediaTrackInfo_Value(last_tr, "IP_TRACKNUMBER") - 1


  -- DETERMINE LAST TRACK IN NEW FOLDER: Check if last selected track is part of a folder and if so find the last track in that folder so wen can add the whole folder to our new folder
  local i = last_tr_idx
  while true do
    if i == first_tr_idx then break end

    local curr_tr = r.GetTrack(0, i)
    local curr_tr_depth = r.GetMediaTrackInfo_Value(curr_tr, 'I_FOLDERDEPTH')

    if curr_tr_depth < 0 then -- if last track of a folder is found before a folder parent, then last selected track is not part of a folder
      break
    elseif curr_tr_depth == 1 then
      last_tr, last_tr_depth = findLastChildTrack(curr_tr)
      break
    end

    i = i - 1
  end

  last_tr_idx = r.GetMediaTrackInfo_Value(last_tr, "IP_TRACKNUMBER") - 1 -- update last_tr variable in case last track changed
  last_tr_depth = r.GetMediaTrackInfo_Value(last_tr, 'I_FOLDERDEPTH')


  -- DETERMINE FIRST TRACK IN NEW FOLDER: If the first track is a child of a partially selected folder, we want to add the whole folders to our new folder
  local found_folder_end = false
  local found_folder_parent = false

  if first_tr_depth ~= 1 then

    for i = first_tr_idx, last_tr_idx do
      local curr_tr = reaper.GetTrack(0, i)
      local curr_tr_depth = r.GetMediaTrackInfo_Value(curr_tr, 'I_FOLDERDEPTH')

      if curr_tr_depth == 1 and found_folder_end == false then
        break
      elseif curr_tr_depth < 0 then
        found_folder_end = true
      elseif curr_tr_depth >= 0 then
        found_folder_parent = true
        break
      end
    end

    if found_folder_end and found_folder_parent then
      local first_tr_parent = r.GetParentTrack(first_tr)

      if first_tr_parent then
        first_tr = first_tr_parent
      end
    end
  end

  first_tr_idx = r.GetMediaTrackInfo_Value(first_tr, "IP_TRACKNUMBER") - 1 -- update first_tr variables in case first track changed

  -- TODO: SET Folderdepth of track with max folder depth instead to bring track on higher level on lower level!!
  -- CHECK IF THERE ARE MULTIPLE
  --[[   local max_folder_level = 1
  for i = first_tr_idx, last_tr_idx do
    local curr_tr = r.GetTrack(0, i)
    local curr_tr_depth = r.GetMediaTrackInfo_Value(curr_tr, 'I_FOLDERDEPTH')

    if curr_tr_depth < max_folder_level then
      max_folder_level = curr_tr_depth
    end
  end

  if last_tr_depth ~= 0 and last_tr_depth > max_folder_level then
    r.SetMediaTrackInfo_Value(last_tr, "I_FOLDERDEPTH", max_folder_level)
  end ]]


  -- ADD NEW FOLDER
  r.InsertTrackAtIndex(first_tr_idx, 0)
  local parent = r.GetTrack(0, first_tr_idx)

  local ok, parent_name = r.GetUserInputs("Name new track folder", 1, "Folder Name:,extrawidth=100", "")

  if not ok then
    reaper.DeleteTrack(parent)
    return
  end

  local folder_color = reaper.GetTrackColor(first_tr)

  r.SetMediaTrackInfo_Value(parent, "I_FOLDERDEPTH", 1)
  r.GetSetMediaTrackInfo_String(parent, "P_NAME", parent_name, 1)
  r.SetMediaTrackInfo_Value(parent, "I_CUSTOMCOLOR", folder_color)
  r.SetMediaTrackInfo_Value(last_tr, "I_FOLDERDEPTH", last_tr_depth - 1)
end

r.PreventUIRefresh(1)
r.Undo_BeginBlock()
main()
r.Undo_EndBlock("Create new folder from selected tracks", -1)
r.PreventUIRefresh(-1)
r.UpdateArrange()
