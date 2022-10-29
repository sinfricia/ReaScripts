-- @description Metadata Manager
-- @author sinfricia
-- @version 0.9.0
-- @changelog
--  - Reworked pregap creation system. Pregap can now be specified per track.
--  - Added additional warnings if tracks or markers don't conform with the CD Red Book standard.
--  - On startup the script can now automatically set all necessary grid settings to ensure CD Red Book conformity.
--  - Markers are now always placed on the grid.
--  - Many, many bugfixes and improvments.
-- @provides
--  img/logo.png
--  img/logo_what.png
--  img/logo_thumbnail.png
-- @about
--  # METADATA MANAGER
--  This Script provides an easy to use interface to create and manage DDP Metadata markers in Reaper.
--  ### Key features:
--   - Clear and easy to use interface to enter Metadata
--   - Multiple possible workflows to create DDP markers
--   - Elaborate error checking in regards to the CD Red Book standard
--   - Responsive UI
-------------------


---- CONFIG STUFF ----
local Script_Name = 'Metadata Manager'
local r = reaper
r.ClearConsole()
local entrypath = ({ r.get_action_context() })[2]:match('^.+[\\//]')
package.path = string.format('%s/Scripts/rtk/1/?.lua;%s?.lua;',
   r.GetResourcePath(), entrypath)
local log
local rtk

local function msg(msg) r.ShowConsoleMsg(tostring(msg) .. "\n") end

-----------------------

------ UTILITY FUNCTIONS -------
local function stringtoboolean(string)
   local bool = false
   if string == 'true' then bool = true end
   return bool
end

function table.contains(table, element)
   for _, value in pairs(table) do if value == element then return true end end
   return false
end

---- USER CONFIGURABLE VARIABLES ----
local proj_data_fields = {
   'ALBUM', 'EAN', 'PERFORMER', 'SONGWRITER', 'COMPOSER', 'ARRANGER', 'GENRE',
   'LANGUAGE'
}
local obj_data_fields = {
   'TITLE', 'ISRC', 'PERFORMER', 'SONGWRITER', 'COMPOSER', 'ARRANGER', 'PREGAP',
}

local proj_marker_color = r.ColorToNative(0, 0, 0) | 0x1000000
local obj_marker_color = r.ColorToNative(255, 255, 255) | 0x1000000
local pregap_marker_color = r.ColorToNative(0, 0, 0) | 0x1000000

-------------------------------------

---- SHARED VARIABLES ----

local retval, proj_marker_dest = r.GetProjExtState(0, Script_Name, 'dest')
local ext_marker_dest = r.GetExtState(Script_Name, 'dest')
local marker_dest
if retval ~= 0 then
   marker_dest = proj_marker_dest
elseif r.HasExtState(Script_Name, 'dest') then
   marker_dest = ext_marker_dest
else
   marker_dest = 'regions'
end

local dest_changed = true

if r.GetProjExtState(0, Script_Name, 'dest') then dest_changed = false end

local proj_data_fields_count = #proj_data_fields
local obj_data_fields_count = #obj_data_fields

local proj_entries = {}
local obj_entries = {}
local objs
local obj_count = 0

local resize = {}

local proj_text = {}
local proj_text_w = {}
local obj_text = {}
local obj_text_w = {}

local copy_buttons_proj = {}
local b_copy_objs = {}

local markers
local regions

local proj_marker_data
local obj_marker_data
local pregap_markers_idx
local obj_marker_idx
local obj_regions_idx
local marker_end_pos

local markers_created = false
if r.GetProjExtState(0, Script_Name, 'markers_created') then
   _, markers_created =
   r.GetProjExtState(0, Script_Name, 'markers_created')
   markers_created = stringtoboolean(markers_created)
end

----------------------------------
------ GUI VALUES ----------------
local w

-- SIZES
local LR_Margin = 25
local TB_Margin = 20
local Entry_Min_W = 70
local Entry_H = 28
local entry_ratios = {}
local Resize_W = 6
local Toolbar_H = 25
local Logo_Size = 175

local total_ratio = 0
for i = 1, proj_data_fields_count do

   entry_ratios[i] = r.GetExtState(Script_Name, 'entry_ratios' .. tostring(i))
   if type(entry_ratios[i]) == 'number' then
      total_ratio = total_ratio + entry_ratios[i]
   end
end

if math.abs(total_ratio - 1) > 1 * 10 ^ (-10) then
   for i = 1, proj_data_fields_count do
      entry_ratios[i] = 1 / proj_data_fields_count
   end
end

-- COLORS
local Lightest_Grey = { 1, 1, 1, 0.1 }
local Light_Grey = { 1, 1, 1, 0.2 }
local Grey = { 1, 1, 1, 0.5 }
------------------------

----------------------------------
------ TOOLTIPS ------------------

local tips = {

   tips = [[
      When activated, hover over UI elements to get tooltips.
   ]],
   TITLE = [[
      Enter your title here. For track titles use the 'copy' button or press alt + shift + downarrow to quickly copy the top entry to all entries.

      If you use a character that's not allowed in the CD-Text standard the entry will light up red. Allowed CD-Text characters are:

      !"$%&\'()*+,-./0123456789:<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
   ]],
   EAN = [[
      Enter your 13 digit EAN/UPC number here. In this field only numbers are allowed.

      If your number is not a valid EAN/UPC the entry wil light up red.
   ]],
   ISRC = [[
      Enter your ISRC here. Use the 'copy' button or press alt + shift + downarrow to quickly copy the top entry
      to all entries with auto incrementing for each track.

      If your number is not a valid ISRC the entry wil light up red.
   ]],
   PEOPLE = [[
      Enter the people involved in creating your album here. If you specify a person for a track you also need to set the corresponding field in
      the album section. Album entries will light up red to indicate this. For albums with different people in the same role you can for example use
      'various' in the album field.

      Use the 'copy' button or press alt + shift + downarrow to quickly copy the top entry to all entries.

      If you use a character that's not allowed in the CD-Text standard the entry will also light up red. Allowed CD-Text characters are:

      !"$%&\'()*+,-./0123456789:<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
   ]],
   GENRE = [[
      Enter the genre of your album here.

      If you use a character that's not allowed in the CD-Text standard the entry will also light up red. Allowed CD-Text characters are:

      !"$%&\'()*+,-./0123456789:<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz
   ]],
   LANGUAGE = [[
      Must be one of the following languages:

      LANGUAGES:
      Albanian, Amharic, Arabic, Armenian, Assamese, Azerbaijani, Bambora, Basque, Bengali, Bielorussian, Breton, Bulgarian, Burmese, Catalan, Chinese, 
      Churash, Croatian, Czech, Danish, Dari, Dutch, English, Esperanto, Estonian, Faroese, Finnish, Flemish, French, Frisian, Fulani, Gaelic, Galician, 
      Georgian, German, Greek, Gujurati, Gurani, Hausa, Hebrew, Hindi, Hungarian, Icelandic, Indonesian, Irish, Italian, Japanese, Kannada, Kazakh, Khmer, 
      Korean, Laotian, Lappish, Latin, Latvian, Lithuanian, Luxembourgian, Macedonian, Malagasay, Malaysian, Maltese, Marathi, Moldavian, Ndebele, Nepali, 
      Norwegian, Occitan, Oriya, Papamiento, Persian, Polish, Portugese, Punjabi, Pushtu, Quechua, Romanian, Romansh, Russian, Ruthenian, Serbian, Serbo-croat, 
      Shona, Sinhalese, Slovak, Slovenian, Somali, Spanish, SrananTongo, Swahili, Swedish, Tadzhik, Tamil, Tatar, Telugu, Thai, Turkish, Ukrainian, Urdu, Uzbek,
      Vietnamese, Wallon, Welsh, Zulu
   ]],
   dest_menu = [[
      Metadata Manager (MM) provides several different workflows to get already existing data from and markers into your project. On first startup MM 
      automatically imports all available data from your last set marker destination. After that if you change your marker destination
      you will have to check the checkbox below if you want to overwrite existing data with data from the new destination.
      
      Once markers are created the marker destination is locked to the existing markers. 
      If you want to change your marker destination again you need to first delete all metadata markers in your project. Use the clear function
      or delete them manually and restart the script.

      Items: Track postions and names are imported from selected items. Data and pregap markers are created at the start of selected items. 
             Items only need to be selected when changing destination after that the script remebers your initial selection.

      Tracks: Track postions and names are imported from selected tracks. Data and pregap markers are created at the start of the first item in each track. 
              Tracks only need to be selected when changing destination after that the script remebers your selection.

      Regions: Track postions and names are imported from regions with names starting with '#'. Data markers are created at the start of these regions.

      Markers: Markers with names starting with '#' are replaced by data markers. If the marker names contain data in the format "...KEY1=value1|KEY2=value2|..." 
               with keys corresponding to CD-Text data fields then all this data is imported into MM.
   ]],
   cb_dest_import = [[
      On first startup Metadata Manager (MM) automatically imports all track titles from your last set marker destination. After that if you change
      your marker destination you will have to check the checkbox below if you want to overwrite existing titles wuth those from the new destination.
   ]],
   b_create = [[
      Create: Creates DDP compatible Metadata markers in REAPER at the positions specified by the marker destination and with the data entered above.


      Update: Once markers are created, you can't create any new markers but only update existing ones. If you want to remove a track from MM after you
      already created markers, delete the marker manually in your project and restart the script. Be careful tough, as MM doesn't statically link
      specific data to a certain marker, but rather to a track number. So if you have 5 tracks in your album and you delete the marker for track 3, 
      your new track 3 will now contain all data from your old track 3.
      If you want to create new markers you you need to first delete all metadata markers in your project. Use the clear function or delete them 
      manually and restart the script.

      Shift + click makes the script think you never created markers (mainly useful for faster debugging).
   ]],
   b_clear = [[
      Deletes various data.

      Album: Clears album metadata entry fields. This is not undoable!

      Tracks: Clears track metadata entry fields. This is not undoable!

      Markers: Deletes all metadata markers (including pregap markers) from the active REAPER project. This is undoable.

      Shift + click to reset script to initial state.
   ]],
   user_scale = [[
      Sets UI scaling.
   ]],
   logo = [[
      This is Metadata. And this is Manager. 
      Life without Metadata just isn't the same for Manager.
   ]],
}


-----------------------------------

function getObjs()
   objs = {}
   getMarkerData()
   local _, ext_obj_count = r.GetProjExtState(0, Script_Name, 'obj_count')
   ext_obj_count = tonumber(ext_obj_count)
   if type(ext_obj_count) == 'number' then obj_count = ext_obj_count end
   local ext_objs = getExtObjs()

   if marker_dest == 'items' then

      if dest_changed then obj_count = r.CountSelectedMediaItems(0) end

      ::restart_loop::
      for i = 1, obj_count do
         objs[i] = {}

         local item
         if dest_changed then
            item = r.GetSelectedMediaItem(0, i - 1)
         else
            item = reaper.BR_GetMediaItemByGUID(0, ext_objs[i])
         end

         if item then
            objs[i].name = r.GetTakeName(r.GetTake(item, 0))
            objs[i].start = r.GetMediaItemInfo_Value(item, "D_POSITION")
            objs[i].stop = objs[i].start + r.GetMediaItemInfo_Value(item, "D_LENGTH")
            objs[i].guid = r.BR_GetMediaItemGUID(item)
         else
            obj_count = obj_count - 1
            table.remove(ext_objs, i)
            goto restart_loop
         end
      end

   elseif marker_dest == 'tracks' then

      if dest_changed then obj_count = r.CountSelectedTracks(0) end

      ::restart_loop::
      for i = 1, obj_count do
         objs[i] = {}

         local tr
         if dest_changed then
            tr = r.GetSelectedTrack(0, i - 1)
         else
            tr = reaper.BR_GetMediaTrackByGUID(0, ext_objs[i])
         end

         if tr then
            local firstItem = r.GetTrackMediaItem(tr, 0)
            local lastItem = r.GetTrackMediaItem(tr, r.CountTrackMediaItems(
               tr) - 1)
            _, objs[i].name = r.GetTrackName(tr)
            _, objs[i].guid = r.GetSetMediaTrackInfo_String(tr, 'GUID', "",
               0)
            if r.CountTrackMediaItems(tr) ~= 0 then
               objs[i].start = r.GetMediaItemInfo_Value(firstItem,
                  "D_POSITION")
               objs[i].stop = r.GetMediaItemInfo_Value(lastItem, "D_POSITION")
                   + r.GetMediaItemInfo_Value(lastItem, "D_LENGTH")
            else
               objs[i].start = i
               objs[i].stop = i
            end
         else
            obj_count = obj_count - 1
            table.remove(ext_objs, i)
            goto restart_loop
         end
      end
   elseif marker_dest == 'markers' or marker_dest == 'regions' then
      local source = {}
      local dest = {}
      if marker_dest == 'markers' then
         source = markers
         dest = obj_marker_idx
      else
         source = regions
         dest = obj_regions_idx
      end

      obj_count = #dest

      for i = 1, obj_count do
         local markrgnidx = dest[i]
         local name = source[markrgnidx].name
         local pos = source[markrgnidx].pos

         if name:find("TITLE=([^|]*)") then
            name = name:match("TITLE=([^|]*)")
         else
            name = name:gsub("^%#", "")
         end

         local stop = 0
         if marker_dest == 'markers' then
            if i == obj_count then
               local item_count = r.CountMediaItems(0)
               if item_count == 0 then
                  stop = r.GetProjectLength(0)
                  goto skip
               end

               local max_item_end = -1
               for j = 1, item_count do
                  local item = r.GetMediaItem(0, j - 1)
                  if item ~= nil then
                     local item_pos = reaper.GetMediaItemInfo_Value(item, "D_POSITION")
                     local item_len = reaper.GetMediaItemInfo_Value(item, "D_LENGTH")
                     local item_end = item_pos + item_len
                     if item_end > max_item_end then
                        max_item_end = item_end
                     end
                  end
               end
               stop = max_item_end
            end
            ::skip::
            if i ~= 1 then
               objs[i - 1].stop = pos
            end
         elseif marker_dest == 'regions' then
            stop = source[markrgnidx].stop
         end

         table.insert(objs, {
            ['name'] = name,
            ['start'] = pos,
            ['stop'] = stop,
            ['idx'] = markrgnidx
         })


      end

   else
      error("data_dest undefined while getting objects")
   end

   if marker_end_pos then
      objs[obj_count].stop = marker_end_pos
   end


   if dest_changed and obj_count < 1 then
      reaper.ShowMessageBox(
         "No tracks were found. This means you either haven't selected any items/tracks or haven't created any markers/regions with a '#' prefix (depending on your chosen marker destination)."
         ,
         Script_Name, 0)
      return false
   end
   if marker_dest ~= 'markers' then
      checkObjOnGrid()
   end

   checkObjMinLength()
end

function initObjEntries()
   for i = 1, obj_count do
      obj_entries[i] = {}
      for j = 1, obj_data_fields_count do obj_entries[i][j] = "" end
   end
end

function storeExtStateData()
   for i = 1, proj_data_fields_count do
      if proj_entries[i].value then
         r.SetProjExtState(0, Script_Name, proj_data_fields[i],
            proj_entries[i].value)
      end
      r.SetExtState(Script_Name, 'entry_ratios' .. tostring(i),
         entry_ratios[i], true)
   end

   for i = 1, obj_count do
      local obj_marker = "#"
      for j = 1, obj_data_fields_count do
         local value = obj_entries[i][j].value

         obj_marker = obj_marker .. obj_data_fields[j] .. '=' ..
             value .. '|'
      end
      r.SetProjExtState(0, Script_Name, 'obj_data' .. i, obj_marker)

      if marker_dest == 'items' or marker_dest == 'tracks' then
         if objs[i].guid then
            r.SetProjExtState(0, Script_Name, 'obj_guid' .. i, objs[i].guid)
         end
      end
   end

   if not markers_created then
      r.SetExtState(Script_Name, 'dest', marker_dest, true)
   end
   r.SetProjExtState(0, Script_Name, 'obj_count', obj_count)
end

function getExtObjs()
   local _ext_objs = {}
   for i = 1, obj_count do
      if marker_dest == 'items' or marker_dest == 'tracks' then
         _, _ext_objs[i] = r.GetProjExtState(0, Script_Name, 'obj_guid' .. i)
      end
   end

   return _ext_objs
end

function getExtData()

   local _proj_ext_data = {}

   for i = 1, proj_data_fields_count do
      _, _proj_ext_data[proj_data_fields[i]] =
      r.GetProjExtState(0, Script_Name, proj_data_fields[i])
   end

   local _obj_ext_data = {}

   for i = 1, obj_count do
      _obj_ext_data[i] = {}

      retval, _obj_ext_data[i]['extString'] = r.GetProjExtState(0, Script_Name, 'obj_data' .. i)
      r.GetProjExtState(0, Script_Name, 'obj_data' .. i)

      if retval ~= 0 then
         local j = 1

         for match in _obj_ext_data[i]['extString']:gmatch("=([^|]*)") do
            _obj_ext_data[i][obj_data_fields[j]] = match
            j = j + 1
         end
      end
   end

   return _proj_ext_data, _obj_ext_data
end

function getMarkerData()
   markers = {}
   regions = {}

   proj_marker_data = {}
   obj_marker_data = {}
   pregap_markers_idx = {}
   obj_marker_idx = {}
   obj_regions_idx = {}

   local marker_count = r.CountProjectMarkers(0)

   for i = 0, marker_count do
      local _, is_rgn, pos, rgn_end, name, idx = r.EnumProjectMarkers(i)

      if is_rgn then
         regions[idx] = { pos = pos, stop = rgn_end, name = name }
      else
         markers[idx] = { pos = pos, name = name }
      end

      if name:find("^%@") and not is_rgn then
         proj_marker_data.idx = idx
         for j = 1, proj_data_fields_count do
            for field, value in name:gmatch("(%a+)=([^|]*)") do
               if field:upper() == proj_data_fields[j] then
                  proj_marker_data[proj_data_fields[j]] = value
               end
            end
         end
      elseif name:find("^%#") then
         if not is_rgn then

            table.insert(obj_marker_data, {})
            table.insert(obj_marker_idx, idx)

            for j = 1, obj_data_fields_count do

               for field, data in name:gmatch("(%a+)=([^|]*)") do
                  if field:upper() == obj_data_fields[j] then

                     obj_marker_data[#obj_marker_data][obj_data_fields[j]] = data
                     break
                  end
               end
            end
         else
            table.insert(obj_regions_idx, idx)
         end
      elseif name:find("^%!") then
         table.insert(pregap_markers_idx, idx)

      elseif name:find("^=END") then
         marker_end_pos = pos
      end
   end

   -- Calculate Pregaps
   local prev_obj_pos = -10000
   for i = 1, #obj_marker_idx do
      local obj_pos = markers[obj_marker_idx[i]].pos
      for j = 1, #pregap_markers_idx do
         local pregap_pos = markers[pregap_markers_idx[j]].pos
         if pregap_pos > prev_obj_pos and pregap_pos < obj_pos then
            obj_marker_data[i]['PREGAP'] = tostring(obj_pos - pregap_pos)
         end
      end

      prev_obj_pos = obj_pos
   end


   if #obj_marker_idx < 1 and not proj_marker_data.idx then
      markers_created = false
      r.SetProjExtState(0, Script_Name, 'markers_created', 'false')
   end
end

function checkObjMinLength()
   for i = 1, obj_count do

      if objs[i].stop - objs[i].start < 4 then
         local err_msg = string.format('Track %i is shorter than 4 seconds. For conformity with the Red Book CD standard tracks need to be longer than 4 seconds!'
            , i)
         return r.MB(err_msg, Script_Name, 0)
      end
   end
end

--------------------------------------------




------ ENTRY ERROR CHECKING FUNCTIONS -------
function markEntry(entry, correct)
   if correct then
      entry:attr('textcolor', 'white')
      entry:attr('border_focused', rtk.themes.dark.entry_border_focused)
      entry:attr('border_hover', rtk.themes.dark.entry_border_hover)
   else
      entry:attr('textcolor', 'red')
      entry:attr('border_focused', 'red#B3')
      entry:attr('border_hover', 'red#4D')
   end
end

function checkEan(entry, mark_immediately)

   local _ean = entry.value
   _ean = _ean:gsub("[^%d]", "")
   _ean = _ean:sub(1, 13)
   entry:attr('value', _ean)

   local is_ean_correct = false

   if #tostring(_ean) == 13 then
      local ean_sum = 0
      for i = 2, 13 do
         if i % 2 == 0 then
            ean_sum = ean_sum + math.floor((_ean % 10 ^ i) / 10 ^ (i - 1)) *
                3
         else
            ean_sum = ean_sum + math.floor((_ean % 10 ^ i) / 10 ^ (i - 1)) *
                1
         end
      end

      local checkdigit = math.floor(_ean % 10)
      local next_ten = math.ceil(ean_sum / 10) * 10

      if next_ten - ean_sum == checkdigit then is_ean_correct = true end
   end

   if is_ean_correct or _ean == "" then
      markEntry(entry, true)
   elseif #tostring(_ean) == 13 then
      markEntry(entry, false)
   elseif not is_ean_correct and mark_immediately then
      markEntry(entry, false)
   end
end

function checkIsrc(entry, mark_immediately)

   local test = entry.value

   test = test:gsub("[^%w]", "")
   test = test:sub(1, 12)
   entry:attr('value', test)

   if test:find("^%a%a%w%w%w%d%d%d%d%d%d%d$") or test == "" then
      markEntry(entry, true)
      return true
   elseif #test == 12 then
      markEntry(entry, false)
   elseif test ~= "" and mark_immediately then
      markEntry(entry, false)
   end
   return false
end

function calculateIsrc(entry)

   if not checkIsrc(entry, true) or entry.value == "" then return false end

   local isrc_start = entry.value
   local _isrc = { entry.value }

   local isrc_fixed = isrc_start:sub(1, 7)

   for i = 2, obj_count do
      local isrc_tr_id = tostring(tonumber(isrc_start:sub(8, 12)) + i - 1)
      local leading_zeroes = string.match(isrc_start:sub(8, 12), "^0*")

      if #isrc_tr_id + #leading_zeroes ~= 5 then
         leading_zeroes = leading_zeroes:sub(1, -2)
      end

      _isrc[i] = isrc_fixed .. leading_zeroes .. isrc_tr_id
   end
   return _isrc
end

function checkCdText(entry)

   local found_illegal = entry.value:find('[^%w%s!"#$%%&\'%(%)%*%+,%-%./:;<=>%?]')
   -- allowedChar = '!"$%&\'()*+,-./0123456789:<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'

   if found_illegal ~= nil then
      markEntry(entry, false)
   else
      markEntry(entry, true)
   end


end

function checkProjPeople(entry, field)
   if entry.value ~= '' and proj_entries[field].value == '' then
      markEntry(proj_entries[field], false)
      proj_entries[field]:attr('border', 'red#B3')
   else
      markEntry(proj_entries[field], true)
      proj_entries[field]:attr('border', rtk.themes.dark.entry_border)
   end
end

function checkPregap(entry)
   local _pregap = entry.value
   if _pregap:match('^%d+%.?%d*') then
      _pregap = _pregap:match('^%d+%.?%d*')
   elseif _pregap:match('^%.%d*') then
      _pregap = _pregap:match('^%.%d*')
   else
      _pregap = '0'
   end

   _pregap = tonumber(_pregap)
   if entry == obj_entries[1][7] then
      if _pregap < 2 then
         markEntry(entry, false)
      else
         markEntry(entry, true)
      end
   elseif _pregap == 0 then
      entry:attr('textcolor', Light_Grey)
   else
      entry:attr('textcolor', 'white')
   end

   _pregap = tostring(_pregap)
   _pregap = _pregap:sub(1, 7)



   _pregap = _pregap .. ' seconds'
   entry:attr('value', _pregap)
end

function hasErrors()
   for i = 1, proj_data_fields_count do
      if proj_entries[i].textcolor == 'red' then
         return 'true'
      end
   end

   for i = 1, obj_count do
      for j = 1, obj_data_fields_count do
         if obj_entries[i][j].textcolor == 'red' then
            return 'true'
         end
      end
   end

   return false
end

--------------------------------------------





------ GRID CHECKING FUNCTIONS -------

function checkGridSettings()
   if r.SNM_GetIntConfigVar('projfrbase', 0) ~= 75 or r.SNM_GetIntConfigVar('projgridframe', 0) & 1 ~= 1 then
      local ok = r.MB("Your grid is not set to 75 frames/second. DDP markers must be placed on a frame boundary at 75 frames per second. \nDo you want to set your grid/snap settings accordingly? (Highly recommended!)"
         , Script_Name, 4)

      if ok == 6 then
         r.SNM_SetIntConfigVar('projfrdrop', 0)
         r.SNM_SetIntConfigVar('projfrbase', 75)
         r.SNM_SetIntConfigVar('projgridframe', 199)
         r.SNM_SetIntConfigVar('projshowgrid', r.SNM_GetIntConfigVar('projshowgrid', 0) | 3)
         r.Main_OnCommand(40754, 0) --enable snap to grid
         r.UpdateArrange()
      end
   end
end

function checkObjOnGrid()
   for i = 1, obj_count do
      local obj_start = string.format('%.10f', objs[i].start)
      local closest_grid = string.format('%.10f', r.BR_GetClosestGridDivision(objs[i].start))

      if obj_start ~= closest_grid then
         local errmsg = "Some of your items don't start on a frame boundary at 75 frames/second. This might cause unwanted overlap between tracks when creating markers. Please consider aligning your item positions to frames"
         return r.MB(errmsg, Script_Name, 0)
      end
   end
end

function getCurrOrPrevGridPos(_pos)
   -- Checks if _pos is on the grid, else returns the previous grid position. Since r.GetMediaItemInfo_Value(item, "D_POSITION") (which is a value _pos might potentially hold)
   -- only seems to be accurate to about 10 decimal places I don't check if closest_grid is == _pos.
   local prev_grid = r.BR_GetPrevGridDivision(_pos)
   local closest_grid = r.BR_GetClosestGridDivision(_pos)
   if closest_grid > _pos then
      return prev_grid
   else
      return closest_grid
   end
end

function getCurrOrNextGridPos(_pos)
   local next_grid = r.BR_GetNextGridDivision(_pos)
   local closest_grid = r.BR_GetClosestGridDivision(_pos)
   if closest_grid < _pos then
      return next_grid
   else
      return closest_grid
   end
end

--------------------------------------------




function fillEntries(get_dest_name)

   local proj_ext_data, obj_ext_data = getExtData()

   for i = 1, proj_data_fields_count do

      if proj_marker_data[proj_data_fields[i]] then
         proj_entries[i]:attr('value', proj_marker_data[proj_data_fields[i]])
      elseif proj_ext_data[proj_data_fields[i]] then
         proj_entries[i]:attr('value', proj_ext_data[proj_data_fields[i]])
      else
         proj_entries[j]:attr('value', "")
      end

      if proj_data_fields[i] == 'EAN' then
         checkEan(proj_entries[i], true)
      end
   end

   for i = 1, obj_count do
      for j = 1, obj_data_fields_count do
         if obj_marker_data[i] and obj_marker_data[i][obj_data_fields[j]] then
            obj_entries[i][j]:attr('value', obj_marker_data[i][obj_data_fields[j]])
         elseif obj_ext_data[i] and obj_ext_data[i][obj_data_fields[j]] then
            obj_entries[i][j]:attr('value', obj_ext_data[i][obj_data_fields[j]])
         else
            obj_entries[i][j]:attr('value', "")
         end

         if obj_data_fields[j] == 'TITLE' and objs[i] and
             ((dest_changed and obj_entries[i][j].value == "") or get_dest_name) then
            obj_entries[i][j]:attr('value', objs[i].name)
         end

         if obj_data_fields[j] == 'ISRC' then
            checkIsrc(obj_entries[i][j], true)
         end

         if obj_data_fields[j] == 'PREGAP' and obj_entries[i][j].value == "" then
            if i == 1 then
               obj_entries[i][j]:attr('value', '2')
            else
               obj_entries[i][j]:attr('value', '0')
            end
         end
      end
   end

   dest_changed = false
   r.SetProjExtState(0, Script_Name, 'dest', marker_dest)
end

function copyDataToAllEntrys(type, section)
   local data
   if section == 'project' then
      data = proj_entries[type].value

      for i = 1, obj_count do obj_entries[i][type]:attr('value', data) end
   elseif obj_data_fields[type] == 'ISRC' then
      data = calculateIsrc(obj_entries[1][type])
      if data then
         for i = 1, obj_count do
            obj_entries[i][type]:attr('value', data[i], false)
         end
      end
   else
      data = obj_entries[1][type].value
      for i = 2, obj_count do obj_entries[i][type]:attr('value', data) end
   end
end

function clearProjEntries()
   for i = 1, proj_data_fields_count do
      proj_entries[i]:attr('value', "")
      markEntry(proj_entries[i], true)
      r.SetProjExtState(0, Script_Name, proj_data_fields[i], "")
   end
end

function clearObjEntries()
   for i = 1, obj_count do
      for j = 1, obj_data_fields_count do
         obj_entries[i][j]:attr('value', "")
         markEntry(obj_entries[i][j], true)

         if i == 1 and obj_data_fields[j] == 'PREGAP' then
            obj_entries[i][j]:attr('value', '2')
         end
      end
   end

   local i = 0
   while reaper.EnumProjExtState(0, Script_Name, i) do
      local retval, key = reaper.EnumProjExtState(0, Script_Name, i)
      if key:find('obj') then
         r.SetProjExtState(0, Script_Name, key, "")
      end
      i = i + 1
   end

   dest_changed = true
end

function clearAllData()
   clearObjEntries()
   local i = 0
   while true do
      local retval, key, _ = reaper.EnumProjExtState(0, Script_Name, i)

      if not retval then
         break
      else
         r.SetProjExtState(0, Script_Name, key, "")
      end
   end
   objs = {}
   obj_count = 0
   w:close()

   buildGui()
   fillEntries()
   clearProjEntries()
end

function deleteDataMarkers()
   getMarkerData()
   r.Undo_BeginBlock()

   r.DeleteProjectMarker(0, 0, false)
   if proj_marker_data.idx then
      r.DeleteProjectMarker(0, proj_marker_data.idx, false)
   end

   for i = 1, #obj_marker_idx do
      r.DeleteProjectMarker(0, obj_marker_idx[i], false)
   end

   for i = 1, #pregap_markers_idx do
      r.DeleteProjectMarker(0, pregap_markers_idx[i], false)
   end

   r.SNM_SetDoubleConfigVar('projtimeoffs', 0)
   r.UpdateArrange()
   r.Undo_EndBlock("Delete all metadata markers", -1)
end

function createDataMarkers()
   checkGridSettings()
   reaper.PreventUIRefresh(1)
   r.Undo_BeginBlock()

   storeExtStateData()
   getObjs()

   deleteDataMarkers()

   local marker_pos = {}

   local proj_marker = '@'
   for i = 1, proj_data_fields_count do
      proj_marker = proj_marker .. proj_data_fields[i] .. '=' ..
          proj_entries[i].value .. '|'
   end

   local proj_marker_pos

   if obj_count > 0 then
      proj_marker_pos = getCurrOrPrevGridPos(objs[obj_count].stop)
   elseif marker_end_pos then
      proj_marker_pos = getCurrOrPrevGridPos(marker_end_pos)
   else
      proj_marker_pos = getCurrOrPrevGridPos(r.GetProjectLength(0))
   end

   marker_pos[proj_marker_pos] = true

   r.AddProjectMarker2(0, 0, proj_marker_pos, 0, proj_marker, 999, proj_marker_color)

   local obj_marker_pos
   for i = 1, obj_count do
      local obj_marker = "#"
      local pregap

      for j = 1, obj_data_fields_count do
         if obj_data_fields[j] == 'PREGAP' then
            if obj_entries[i][j].value:match('^%d+%.?%d*') then
               pregap = obj_entries[i][j].value:match('^%d+%.?%d*')
            elseif obj_entries[i][j].value:match('^%.%d*') then
               pregap = obj_entries[i][j].value:match('^%.%d*')
            else
               pregap = '0'
            end
            pregap = tonumber(pregap)
         else
            obj_marker = obj_marker .. obj_data_fields[j] .. '=' ..
                obj_entries[i][j].value .. '|'
         end
      end

      obj_marker_pos = getCurrOrPrevGridPos(objs[i].start)
      if marker_pos[obj_marker_pos] then
         obj_marker_pos = obj_marker_pos - 1 / 75
      else
         marker_pos[obj_marker_pos] = true
      end

      r.AddProjectMarker2(0, 0, obj_marker_pos, 0, obj_marker, i + 100, obj_marker_color)

      if pregap > 0 then
         local pregap_pos = getCurrOrPrevGridPos(objs[i].start - pregap)
         if marker_pos[pregap_pos] then
            pregap_pos = pregap_pos - 1 / 75
         else
            marker_pos[pregap_pos] = true
         end

         if i == 1 then
            if objs[i].start - pregap < 0 then
               local start, stop = r.GetSet_LoopTimeRange(false, false, 0, 0, false)
               r.GetSet_LoopTimeRange(true, false, 0, pregap - objs[1].start, false)
               r.Main_OnCommand(40200, 0) -- Time selection: Insert empty space at time selection (moving later items)
               r.AddProjectMarker2(0, 0, 0, 0, "!", 501, pregap_marker_color)
               r.GetSet_LoopTimeRange(true, false, start, stop, false)
            else
               r.AddProjectMarker2(0, 0, pregap_pos, 0, "!", 501, pregap_marker_color)
            end

            r.SNM_SetDoubleConfigVar('projtimeoffs', (pregap_pos + pregap) * (-1))
         else
            r.AddProjectMarker2(0, 0, pregap_pos, 0, "!", i + 500, pregap_marker_color)
         end
      end
   end

   --[[ 	r.SetEditCurPos(0, 1, 0)
      r.Main_OnCommand(40635, 1) --remove time selection
      r.Main_OnCommand(40296, 1) -- select all tracks
      r.Main_OnCommand(r.NamedCommandLookup("_SWS_VZOOMFIT"), 1) --zoom to selected tracks vertically
      r.Main_OnCommand(40769, 1) --unselect tracks and items
      r.Main_OnCommand(40295, 1) --zoom out to project horizontally ]]

   r.Undo_EndBlock("Create/update metadata markers", -1)
   reaper.PreventUIRefresh(-1)
end

function storeWinPos()
   r.SetExtState(Script_Name, 'wx', w.x, true)
   r.SetExtState(Script_Name, 'wy', w.y, true)
end

function storeWinSize()
   r.SetExtState(Script_Name, 'ww', w.w, true)
   r.SetExtState(Script_Name, 'wh', w.h, true)
end

function recallWinPos()

   if not (r.HasExtState(Script_Name, 'wx') and
       r.HasExtState(Script_Name, 'wy')) then return false end

   local wx = r.GetExtState(Script_Name, 'wx')
   local wy = r.GetExtState(Script_Name, 'wy')

   if wx == '' or wy == '' then return false end

   w:attr('x', wx)
   w:attr('y', wy)

   return true
end

function recallWinSize()
   if not (r.HasExtState(Script_Name, 'ww') and
       r.HasExtState(Script_Name, 'wh')) then return false end

   local ww = r.GetExtState(Script_Name, 'ww')
   local wh = r.GetExtState(Script_Name, 'wh')

   if ww == '' or wh == '' then return false end

   w:attr('w', ww)
   w:attr('h', wh)

   return true
end

function getEntryTextWidths()
   for i = 1, proj_data_fields_count do
      proj_text_w[i] = proj_text[i].calc.w / rtk.scale.value
   end

   if obj_count < 1 then return end

   for i = 1, obj_data_fields_count do
      obj_text_w[i] = obj_text[i].calc.w / rtk.scale.value
   end
end

function buildGui()

   ----------------------------------
   ---- WINDOW  ---------------------
   ----------------------------------
   w = rtk.Window {
      title = Script_Name,
      resizable = true,
      borderless = true,
      border = { { 0, 0, 0, 0.1 }, 1 }
   }

   w.onclose = function()
      storeExtStateData()
      storeWinPos()
      storeWinSize()
   end

   recallWinPos()

   ----------------------------------
   ---- TOOLBAR ---------------------
   ----------------------------------
   local app = w:add(rtk.Application())
   app.toolbar:attr('h', 25)
   app.toolbar:attr('bborder', { Lightest_Grey, 1 })

   local user_scale = app.toolbar:add(rtk.OptionMenu {
      menu = {
         { '50%', id = '0.5' }, { '75%', id = '0.75' }, { '90%', id = '0.9' },
         { '100%', id = '1.0' }, { '110%', id = '1.1' }, { '125%', id = '1.25' },
         { '150%', id = '1.5' }
      },

      tooltip = tips.user_scale,
      x = 1,
      h = app.toolbar.h - 2,
      w = 65,
      fontsize = 12,
      margin = { 0, 5 },
      selected = tostring(rtk.scale.user),
      valign = 'center',
      color = { 0.2, 0.2, 0.2, 1 },
      gradient = 0.5,
   })

   local function resetUI()
      for i = 1, proj_data_fields_count do
         entry_ratios[i] = 1 / proj_data_fields_count
      end

      w:close()

      r.SetExtState(Script_Name, 'ww', '', true)
      r.SetExtState(Script_Name, 'wh', '', true)

      buildGui()
      fillEntries()
   end

   user_scale.onchange = function()
      rtk.scale.user = user_scale.selected_id
      r.SetExtState(Script_Name, 'user_scale', rtk.scale.user, true)

      resetUI()
   end

   user_scale:select(rtk.scale.user, false)

   local b_reset_ui = app.toolbar:add(rtk.Button {
      label = 'reset ui',
      h = app.toolbar.h - 1,
      flat = true,
      padding = { 0, 5 },
      fontsize = 14,
      halign = 'center',
      valign = 'center',
      color = { 0.2, 0.2, 0.2, 1 },
   })
   b_reset_ui.onclick = function() resetUI() end

   local show_tooltips = stringtoboolean(r.GetExtState(Script_Name, 'show_tooltips'))

   if show_tooltips == nil or show_tooltips == "" then
      show_tooltips = true
   end


   local b_tooltips = app.toolbar:add(rtk.Button {
      label = '?',
      w = app.toolbar.h - 1,
      h = app.toolbar.h - 1,
      flat = true,
      padding = { 0, 5 },
      fontsize = 14,
      halign = 'center',
      valign = 'center',
      color = { 0.2, 0.2, 0.2, 1 },
      tooltip = tips.tips
   })

   local function tooltipsToggle()
      if show_tooltips then
         rtk.tooltip_delay = 0.1
         b_tooltips:attr('flat', false)
         r.SetExtState(Script_Name, 'show_tooltips', 'true', true)
      else
         rtk.tooltip_delay = 150
         b_tooltips:attr('flat', true)
         r.SetExtState(Script_Name, 'show_tooltips', 'false', false)
      end
   end

   tooltipsToggle()

   b_tooltips.onclick = function()
      if not show_tooltips then
         show_tooltips = true
      else
         show_tooltips = false
      end
      tooltipsToggle()
   end

   local b_close = app.toolbar:add(rtk.Button {
      'x',
      w = app.toolbar.h - 1,
      h = app.toolbar.h - 1,
      flat = true,
      padding = 0,
      fontsize = 14,
      halign = 'center',
      valign = 'center',
      color = { 0.2, 0.2, 0.2, 1 },
   })
   b_close.onclick = function() rtk.quit() end

   app.statusbar:attr('h', 20)
   app.statusbar:attr('tborder', { Lightest_Grey, 1 })
   app.statusbar:attr('tpadding', 2)

   ----------------------------------
   ---- THUMBNAIL/WINDOW TITLE-------
   ----------------------------------

   w:add(rtk.Heading {
      text = 'METADATA MANAGER',
      x = LR_Margin,
      y = 3,
      color = { 1, 1, 1, 0.3 },
      fontscale = 0.9,
      fontflags = rtk.font.BOLD
   })

   local logo_thumb = rtk.Image():load('logo_thumbnail.png')
   w:add(rtk.ImageBox {
      image = logo_thumb,
      x = 5,
      y = 4,
      scale = 0.2,
      alpha = 0.7
   })

   ----------------------------------
   ---- Initializing Stuff ----------
   ----------------------------------
   w:open()

   local w_min_w = (proj_data_fields_count * Entry_Min_W + LR_Margin * 2 + Resize_W * (proj_data_fields_count)) *
       rtk.scale.value
   w:attr('minw', math.floor(w_min_w + 1))

   local has_w_size_stored = recallWinSize()
   if not has_w_size_stored then w:resize(math.floor(w_min_w + 1) * 2, 600) end

   local box_outer = w:add(rtk.VBox {})
   local box = rtk.VBox { w = w.w / rtk.scale.value }
   local vp = box_outer:add(rtk.Viewport {
      box,
      vscrollbar = 'always',
      scrollbar_size = 5,
      tmargin = app.toolbar.h,
      cell = { expand = 1 }
   })

   -- Make space for track numbers
   local entries_indent = LR_Margin + 20
   if obj_count > 9 then
      entries_indent = entries_indent + 10 *
          (math.ceil(math.log(obj_count + 1, 10)) - 1)
   end

   ----------------------------------
   ---- PROJECT SECTION -------------
   ----------------------------------
   local proj_heading = box:add(rtk.Heading {
      text = 'ALBUM METADATA',
      margin = { TB_Margin, LR_Margin },
      bborder = { Grey, 1 },
      cell = { fillw = true }
   })

   local proj_text_box = box:add(rtk.Container { margin = { 0, 0, 4, 0 } })
   local proj_entry_box = box:add(rtk.Container { margin = { 0, 0, 4, 0 } })

   local entry_w = (box.w - entries_indent * 2 - Resize_W *
       proj_data_fields_count) / proj_data_fields_count

   resize[0] = proj_entry_box:add(rtk.Spacer {
      x = entries_indent - Resize_W,
      w = Resize_W,
      h = Entry_H,
      bg = Lightest_Grey
   })

   proj_entries[1] = proj_entry_box:add(rtk.Entry {
      placeholder = proj_data_fields[1],
      x = entries_indent,
      w = entry_w * entry_ratios[1] * proj_data_fields_count,
      h = Entry_H,
      tooltip = tips.TITLE
   })

   proj_entries[1].onchange = function()
      checkCdText(proj_entries[1])
   end

   proj_text[1] = proj_text_box:add(rtk.Text {
      proj_data_fields[1],
      x = proj_entries[1].x + 2,
      h = 20,
      fontsize = 16,
      color = Grey,
      valign = 'center'
   })

   resize[1] = proj_entry_box:add(rtk.Spacer {
      x = proj_entries[1].x + proj_entries[1].w,
      w = Resize_W,
      h = Entry_H,
      bg = Light_Grey,
      cursor = rtk.mouse.cursors.SIZE_EW
   })

   for i = 2, proj_data_fields_count do

      local entry_x = resize[i - 1].x + resize[i - 1].w
      proj_entries[i] = proj_entry_box:add(rtk.Entry {
         placeholder = proj_data_fields[i],
         x = entry_x,
         w = entry_w * entry_ratios[i] * proj_data_fields_count,
         h = Entry_H,
         tooltip = tips.entry
      })

      local resize_x = proj_entries[i].x + proj_entries[i].w
      resize[i] = proj_entry_box:add(rtk.Spacer {
         x = resize_x,
         w = Resize_W,
         h = Entry_H,
         bg = { 255, 255, 255, 0.3 },
         cursor = rtk.mouse.cursors.SIZE_EW
      })

      if i == proj_data_fields_count then
         resize[i]:attr('bg', Light_Grey)
         resize[i]:attr('cursor', nil)
      end

      proj_text[i] = proj_text_box:add(rtk.Text {
         proj_data_fields[i],
         x = proj_entries[i].x + 2,
         h = 20,
         fontsize = 16,
         color = Grey,
         valign = 'center'
      })

      if proj_data_fields[i] == 'EAN' then
         proj_entries[i]:attr('tooltip', tips.EAN)
         proj_entries[i].onchange = function()
            checkEan(proj_entries[i], false)
         end
         proj_entries[i].onblur = function()
            checkEan(proj_entries[i], true)
         end
      elseif proj_data_fields[i] == 'PERFORMER' or proj_data_fields[i] ==
          'SONGWRITER' or proj_data_fields[i] == 'COMPOSER' or
          proj_data_fields[i] == 'ARRANGER' then
         proj_entries[i]:attr('tooltip', tips.PEOPLE)
         copy_buttons_proj[i] = proj_text_box:add(rtk.Button {
            label = "copy",
            x = proj_entries[i].x + proj_entries[i].w - 29,
            w = 29,
            h = proj_text_box.h,
            padding = 4,
            flat = true,
            fontsize = 12,
         })

         copy_buttons_proj[i].onclick = function()
            copyDataToAllEntrys(i, 'project')
         end

         proj_entries[i].onchange = function()
            checkProjPeople(proj_entries[i], i)
            checkCdText(proj_entries[i])
         end
      elseif proj_data_fields[i] == 'GENRE' then
         proj_entries[i]:attr('tooltip', tips.GENRE)
      elseif proj_data_fields[i] == 'LANGUAGE' then
         proj_entries[i]:attr('tooltip', tips.LANGUAGE)
      else
         proj_entries[i].onchange = function()
            checkCdText(proj_entries[i])
         end
      end
   end

   ----------------------------------
   ---- OBJECTS SECTION -------------
   ----------------------------------
   initObjEntries()

   local obj_heading = box:add(rtk.Heading {
      text = 'TRACK METADATA',
      margin = { TB_Margin, LR_Margin },
      bborder = { Grey, 1 },
      cell = { fillw = true }
   })

   local obj_entry_box = {}
   local obj_number = {}
   local obj_text_box = box:add(rtk.Container { margin = proj_text_box.margin })

   for i = 1, obj_count do

      obj_entry_box[i] = box:add(rtk.Container {
         margin = proj_entry_box.margin
      })
      obj_number[i] = obj_entry_box[i]:add(rtk.Text {
         text = tostring(i),
         x = LR_Margin,
         h = Entry_H,
         w = entries_indent - LR_Margin,
         rpadding = 10,
         halign = 'right',
         valign = 'center'
      })

      for j = 1, obj_data_fields_count do

         if j == 1 then
            obj_entries[i][1] = obj_entry_box[i]:add(rtk.Entry {
               placeholder = obj_data_fields[j],
               x = entries_indent,
               w = entry_w * entry_ratios[j] * proj_data_fields_count,
               h = Entry_H,
               tooltip = tips.TITLE
            })
         else
            local entry_x = resize[j - 1].x + resize[j - 1].w

            obj_entries[i][j] = obj_entry_box[i]:add(rtk.Entry {
               placeholder = obj_data_fields[j],
               x = entry_x,
               w = entry_w * entry_ratios[j] * proj_data_fields_count,
               h = Entry_H,
               tooltip = tips.entry
            })
         end

         if i == 1 then -- draw object field name and copy buttons
            obj_text[j] = obj_text_box:add(rtk.Text {
               text = obj_data_fields[j],
               x = obj_entries[i][j].x + 2,
               fontsize = 16,
               color = Grey,
            })

            b_copy_objs[j] = obj_text_box:add(rtk.Button {
               label = "copy",
               x = obj_entries[i][j].x + obj_entries[i][j].w - 29,
               w = 29,
               h = obj_text_box.h,
               padding = 4,
               flat = true,
               fontsize = 12,
            })


            b_copy_objs[j].onclick = function()
               copyDataToAllEntrys(j, 'objects')
            end
         end


         if obj_data_fields[j] == 'ISRC' then
            obj_entries[i][j]:attr('tooltip', tips.ISRC)
            obj_entries[i][j].onchange = function()
               checkIsrc(obj_entries[i][j], false)
            end

            obj_entries[i][j].onblur = function()
               checkIsrc(obj_entries[i][j], true)
            end
         elseif obj_data_fields[j] == 'PREGAP' then

            obj_entries[i][j]:attr('bg', { 0.2, 0.2, 0.2, 1 })


            obj_entries[i][j].onclick = function()
               obj_entries[i][j]:select_all()
            end

            obj_entries[i][j].onchange = function()
               checkPregap(obj_entries[i][j])
            end

            obj_entries[i][j].onblur = function()
               checkPregap(obj_entries[i][j])
            end
         elseif obj_data_fields[j] == 'PERFORMER' or obj_data_fields[j] == 'SONGWRITER' or
             obj_data_fields[j] == 'COMPOSER' or
             obj_data_fields[j] == 'ARRANGER' then

            obj_entries[i][j]:attr('tooltip', tips.PEOPLE)

            obj_entries[i][j].onchange = function()
               checkCdText(obj_entries[i][j])
               checkProjPeople(obj_entries[i][j], j)
               checkCdText(proj_entries[j])
            end
         else
            obj_entries[i][j].onchange = function()
               checkCdText(obj_entries[i][j])
            end
         end



         obj_entries[i][j].onfocus = function()
            if obj_entry_box[i].calc.y - vp.scroll_top < Toolbar_H * rtk.scale.value then
               vp:scrollby(0, (Entry_H * rtk.scale.value + obj_entry_box[i].calc.bmargin + 1) * (-1)) -- Don't really know where the +1 comes from
            end

            if obj_entry_box[i].calc.y + Entry_H * rtk.scale.value - vp.scroll_top > vp.calc.h then
               vp:scrollby(0, Entry_H * rtk.scale.value + obj_entry_box[i].calc.bmargin + 1) -- Don't really know where the +1 comes from
            end
         end

         obj_entries[i][j].onkeypress = function(self, event)
            if event.keycode == rtk.keycodes.TAB then
               if event.shift then
                  if i == 1 and j == 1 then
                     proj_entries[proj_data_fields_count]:focus()
                  elseif i ~= 1 and j == 1 then
                     obj_entries[i - 1][obj_data_fields_count]:focus()
                  else
                     obj_entries[i][j - 1]:focus()
                     obj_entries[i][j - 1]:select_all()
                  end
               else
                  if i == obj_count and j == obj_data_fields_count then
                     event:set_handled()
                     return
                  elseif i ~= obj_count and j == obj_data_fields_count then
                     obj_entries[i + 1][1]:focus()
                     obj_entries[i + 1][1]:select_all()
                  else
                     obj_entries[i][j + 1]:focus()
                     obj_entries[i][j + 1]:select_all()
                  end
               end

               event:set_handled()
            end

            if event.keycode == rtk.keycodes.ENTER then
               if event.shift then
                  if i == 1 then
                     proj_entries[j]:focus()
                     proj_entries[j]:select_all()
                  else
                     obj_entries[i - 1][j]:focus()
                     obj_entries[i - 1][j]:select_all()
                  end
               else
                  if i == obj_count then
                     proj_entries[j]:focus()
                     proj_entries[j]:select_all()
                  else
                     obj_entries[i + 1][j]:focus()
                     obj_entries[i + 1][j]:select_all()
                  end
               end

               event:set_handled()
            end

            if event.keycode == rtk.keycodes.DOWN and event.alt and
                event.shift then
               copyDataToAllEntrys(j, 'objects')
               event:set_handled(self)
            end
         end
      end
   end

   -- proj_data keypress/focus handlers
   for i = 1, proj_data_fields_count do
      proj_entries[i].onfocus = function(self, event)
         if proj_entries[i].calc.y - vp.scroll_top < Toolbar_H *
             rtk.scale.value then vp:scrollto(0, 0) end
      end

      proj_entries[i].onkeypress = function(self, event)
         if event.keycode == rtk.keycodes.TAB then
            if event.shift then
               if i == 1 then
                  event:set_handled()
                  return
               else
                  proj_entries[i - 1]:focus()
                  proj_entries[i - 1]:select_all()
               end
            else
               if i == proj_data_fields_count and obj_count > 0 then
                  obj_entries[1][1]:focus()
                  obj_entries[1][1]:select_all()
               else
                  proj_entries[i + 1]:focus()
                  proj_entries[i + 1]:select_all()
               end
            end

            event:set_handled()
         end

         if event.keycode == rtk.keycodes.ENTER then
            if event.shift and i <= obj_data_fields_count then
               obj_entries[obj_count][i]:focus()
               vp:scrollto(0,
                  obj_entry_box[obj_count].calc.y + Entry_H *
                  rtk.scale.value +
                  obj_entry_box[obj_count].calc.bmargin -
                  vp.calc.h)
            else
               if i <= obj_data_fields_count then
                  obj_entries[1][i]:focus()
                  obj_entries[1][i]:select_all()
               else
                  obj_entries[1][1]:focus()
                  obj_entries[1][1]:select_all()
               end
            end

            event:set_handled()
         end

         if event.keycode == rtk.keycodes.DOWN and event.alt and event.shift then
            copyDataToAllEntrys(i, 'project')
            event:set_handled(self)
         end
      end
   end



   local function checkTextOverlap()
      for i = 1, proj_data_fields_count do
         if proj_text_w[i] > proj_entries[i].w then
            proj_text[i]:attr('text', proj_text[i].text:sub(1, 3) .. '...')
            -- proj_text[i]:attr('placeholder', proj_text[i].text:sub(1, 3)..'...')
         elseif proj_text_w[i] < proj_entries[i].w then
            proj_text[i]:attr('text', proj_data_fields[i])
            -- proj_text[i]:attr('placeholder', proj_data_fields[i])
         end

         if not copy_buttons_proj[i] then goto skip end

         if copy_buttons_proj[i].x < proj_text[i].x + proj_text[i].calc.w /
             rtk.scale.value then
            copy_buttons_proj[i]:hide()
         else
            copy_buttons_proj[i]:show()
         end

         ::skip::
      end

      if obj_count < 1 then return end

      for i = 1, obj_data_fields_count do
         if (obj_text_w[i] > obj_entries[1][i].w) then
            obj_text[i]:attr('text', obj_text[i].text:sub(1, 3) .. '...')
            -- obj_text[i]:attr('placeholder', obj_text[i].text:sub(1, 3)..'...')
         elseif obj_text_w[i] < proj_entries[i].w then
            obj_text[i]:attr('text', obj_data_fields[i])
            -- obj_text[i]:attr('placeholder', obj_data_fields[i])
         end

         if b_copy_objs[i].x < obj_text[i].x + obj_text[i].calc.w /
             rtk.scale.value then
            b_copy_objs[i]:hide()
         else
            b_copy_objs[i]:show()
         end
      end
   end

   ----------------------------------
   ---- MENU SECTION ----------------
   ----------------------------------
   local menu_box = box_outer:add(rtk.HBox {
      h = 130,
      margin = { 0, Logo_Size + entries_indent, app.statusbar.h, LR_Margin },
      padding = { 20, 0 },
      spacing = 20,
      tborder = { { 1, 1, 1, 0.6 }, 2 },
      cell = { valign = 'bottom', fillw = true }
   })

   local m_spacer_front = menu_box:add(rtk.Spacer {}, { expand = true })

   local m_dest_box = menu_box:add(rtk.VBox {
      spacing = 5,
      padding = { 0, menu_box.spacing },
      lborder = { Light_Grey, 1 },
      rborder = { Light_Grey, 1 },
      cell = { fillh = true }
   })
   local m_create_box = menu_box:add(rtk.VBox {
      spacing = 5,
      rpadding = menu_box.spacing,
      rborder = { Light_Grey, 1 },
      cell = { fillh = true }
   })
   local m_clear_box = menu_box:add(rtk.VBox {
      spacing = 0,
      rpadding = menu_box.spacing,
      rborder = { Light_Grey, 1 },
      cell = { fillh = true }
   })

   local m_spacer_back = menu_box:add(rtk.Spacer { w = 0.5 })

   -- dest
   local dest_text = m_dest_box:add(rtk.Text {
      text = 'Marker Destination',
      fontscale = 0.9,
      padding = { 0, 0, 5 },
      cell = { halign = 'center' }
   })

   local dest_menu = m_dest_box:add(rtk.OptionMenu {
      menu = {
         { 'Items', id = 'items' },
         { 'Tracks', id = 'tracks' },
         { 'Markers', id = 'markers' },
         { 'Regions', id = 'regions' },
      },
      fontsize = 13,
      h = 25,
      bmargin = 5,
      color = { 0.2, 0.2, 0.2, 1 },
      gradient = 0.5,
      tooltip = tips.dest_menu,
      cell = { halign = 'center' }
   })

   dest_menu:select(marker_dest, false)

   local cb_dest_import = m_dest_box:add(rtk.CheckBox {
      label = 'Import track names from destination',
      w = 170,
      wrap = true,
      fontscale = 0.75,
      spacing = 4,
      padding = { 5 },
      tborder = { Grey, 1 },
      tooltip = tips.cb_dest_import,
   })

   dest_menu.onselect = function()
      w:close()

      dest_changed = true
      marker_dest = dest_menu.selected_id
      getObjs()
      buildGui()
      fillEntries(cb_dest_import.value)
   end

   -- GENERATE
   m_create_box:add(rtk.Spacer {
      h = 5
   })

   local b_create = m_create_box:add(rtk.Button {
      label = "Create markers",
      h = 35,
      bmargin = 5,
      color = { 0.2, 0.2, 0.2, 1 },
      tooltip = tips.b_create,
      cell = { halign = 'center' }
   })


   b_create.onclick = function(self, event)
      if event.shift then
         markers_created = false
         r.SetProjExtState(0, Script_Name, 'markers_created', 'false')
         setMarkersCreatedState(false)
         return
      end

      if hasErrors() then
         local popupBox = rtk.Container {}
         local popup = rtk.Popup {
            child = popupBox,
            padding = 25,
            autoclose = false,
            shadow = { 0, 0, 0, 0.1 }
         }
         local popupText = popupBox:add(rtk.Text {
            "There are errors present in your entries. Are you sure want to create markers with errors present?"
         })
         local b_yes = popupBox:add(rtk.Button {
            'Yes',
            tmargin = 50,
            fontsize = 14,
            cell = { halign = 'right' }
         })
         local b_cancel = popupBox:add(rtk.Button {
            'Cancel',
            x = -60,
            tmargin = 50,
            fontsize = 14,
            cell = { halign = 'right' }
         })

         b_cancel.onclick = function()
            popup:close()
            return false
         end
         b_yes.onclick = function()
            popup:close()
            createDataMarkers()

            markers_created = true
            r.SetProjExtState(0, Script_Name, 'markers_created', 'true')
            r.SetProjExtState(0, Script_Name, 'dest', dest_menu.selected_id)

            setMarkersCreatedState(true)
         end
         popup.onkeypress = function(self, event)
            if event.keycode == rtk.keycodes.ENTER then
               b_yes.onclick()
               event:set_handled(self)
            elseif event.keycode == rtk.keycodes.ESCAPE then
               event:set_handled(self)
               popup:close()
            end
         end

         popup:open()
      else
         createDataMarkers()

         markers_created = true
         r.SetProjExtState(0, Script_Name, 'markers_created', 'true')
         r.SetProjExtState(0, Script_Name, 'dest', dest_menu.selected_id)

         setMarkersCreatedState(true)
      end
   end

   function setMarkersCreatedState(state)
      if state == false then
         if r.HasExtState(Script_Name, 'dest') and r.GetExtState(Script_Name, 'dest') ~= "" then
            marker_dest = r.GetExtState(Script_Name, 'dest')
         else
            dest_menu:select('markers', false)
            marker_dest = 'markers'
         end
         dest_menu:select(marker_dest, false)
         dest_text:attr('color', 'White')
         dest_menu:attr('disabled', false)
         cb_dest_import:attr('disabled', false)

         b_create:attr('label', 'Create Markers')

      elseif state == true then
         dest_menu:select('markers', false)
         marker_dest = 'markers'
         dest_text:attr('color', Grey)
         dest_menu:attr('disabled', true)
         cb_dest_import:attr('disabled', true)

         b_create:attr('label', 'Update Markers')
      end
   end

   if markers_created then setMarkersCreatedState(true) end

   -- CLEAR
   local b_clear = m_clear_box:add(rtk.Button {
      "clear",
      fontsize = 13,
      bmargin = 8,
      color = { 0.2, 0.2, 0.2, 1 },
      tooltip = tips.b_clear,
      cell = { halign = 'center', valign = 'bottom' }
   })
   local cb_clear_proj = m_clear_box:add(rtk.CheckBox {
      label = 'Album',
      fontscale = 0.75,
      spacing = 4
   })
   local cb_clear_objs = m_clear_box:add(rtk.CheckBox {
      label = 'Tracks',
      fontscale = 0.75,
      spacing = 4
   })
   local cb_clear_markers = m_clear_box:add(rtk.CheckBox {
      label = 'Markers',
      fontscale = 0.75,
      spacing = 4
   })
   if not cb_clear_proj.value and not cb_clear_objs.value and
       not cb_clear_markers.value then b_clear:attr('disabled', true) end

   cb_clear_proj.onchange = function()
      if not cb_clear_proj.value and not cb_clear_objs.value and
          not cb_clear_markers.value then
         b_clear:attr('disabled', true)
      else
         b_clear:attr('disabled', false)
      end
   end
   cb_clear_objs.onchange = function()
      if not cb_clear_proj.value and not cb_clear_objs.value and
          not cb_clear_markers.value then
         b_clear:attr('disabled', true)
      else
         b_clear:attr('disabled', false)
      end
   end
   cb_clear_markers.onchange = function()
      if not cb_clear_proj.value and not cb_clear_objs.value and
          not cb_clear_markers.value then
         b_clear:attr('disabled', true)
      else
         b_clear:attr('disabled', false)
      end
   end

   b_clear.onclick = function(_, event)
      if event.alt then
         clearProjEntries()
         clearObjEntries()
         local i = 0
         while true do
            local retval, key, _ = reaper.EnumProjExtState(0, Script_Name, i)

            if not retval then
               break
            else
               r.SetProjExtState(0, Script_Name, key, "")
            end
         end
         objs = {}
         obj_count = 0

         r.DeleteExtState(Script_Name, "dest", true)
         r.DeleteExtState(Script_Name, "user_scale", true)
         r.DeleteExtState(Script_Name, "show_tooltips", true)

         resetUI()
         rtk.quit()
      end

      local shift = event.shift
      local clear_msg = "Are you sure you want to delete selected Data? \nClearing entry fields is not undoable!"
      if shift then
         clear_msg = "Are you sure you want to reset Metadata Manager to its inital state? \nThis is not undoable!"
      end
      local popupBox = rtk.Container {}
      local popup = rtk.Popup {
         child = popupBox,
         padding = 25,
         autoclose = false,
         shadow = { 0, 0, 0, 0.1 }
      }
      local popupText = popupBox:add(rtk.Text {
         clear_msg
      })
      local b_yes = popupBox:add(rtk.Button {
         'Yes',
         tmargin = 50,
         fontsize = 14,
         cell = { halign = 'right' }
      })
      local b_cancel = popupBox:add(rtk.Button {
         'Cancel',
         x = -60,
         tmargin = 50,
         fontsize = 14,
         cell = { halign = 'right' }
      })

      b_cancel.onclick = function()
         popup:close()
         return false
      end
      b_yes.onclick = function()
         popup:close()
         if cb_clear_proj.value then clearProjEntries() end
         if cb_clear_objs.value then clearObjEntries() end
         if cb_clear_markers.value then

            deleteDataMarkers()

            markers_created = false
            r.SetProjExtState(0, Script_Name, 'markers_created', 'false')
            setMarkersCreatedState(false)
         end
         if shift then clearAllData() end
      end
      popup.onkeypress = function(self, event)
         if event.keycode == rtk.keycodes.ENTER then
            b_yes.onclick()
            event:set_handled(self)
         elseif event.keycode == rtk.keycodes.ESCAPE then
            event:set_handled(self)
            popup:close()
         end
      end

      popup:open()
   end

   w:reflow()
   local menu_w = m_clear_box.calc.x + m_clear_box.calc.w - m_dest_box.calc.x +
       entries_indent * rtk.scale.value + 30 * rtk.scale.value

   ----------------------------------
   ---- LOGO ------------------------
   ----------------------------------
   local logo_container = w:add(rtk.Container {
      z = -1,
      w = Logo_Size,
      h = Logo_Size,
      margin = { 0, 15, app.statusbar.h + 10, 0 },
      tooltip = tips.logo,
      cell = { halign = 'right', valign = 'bottom' }
   })
   local logo = logo_container:add(rtk.ImageBox { 'logo' })
   local logo_what = logo_container:add(rtk.ImageBox {
      'logo_what',
      visible = false
   })

   function checkLogoOverlap()
      local obj_end_x = 0
      local obj_end_y = 0
      if obj_count > 1 then
         obj_end_x = obj_entry_box[1].calc.x + obj_entry_box[1].calc.w + 4 *
             rtk.scale.value
         obj_end_y = obj_entry_box[obj_count].calc.y + Entry_H *
             rtk.scale.value * 2 + 4 * rtk.scale.value
      end

      logo:attr('visible', true)
      logo_what:attr('visible', false)
      menu_box:attr('rmargin', Logo_Size + entries_indent)
      m_spacer_front:attr('visible', true)

      if obj_end_x > logo_container.calc.x and obj_end_y > logo_container.calc.y then
         logo:attr('visible', false)
         logo_what:attr('visible', true)
         menu_box:attr('rmargin', Logo_Size * 0.65)

      end
      if menu_w > logo_container.calc.x then
         logo:attr('visible', false)
         logo_what:attr('visible', true)
         menu_box:attr('rmargin', Logo_Size * 0.65)
         m_spacer_front:attr('visible', false)
      end
   end

   ----------------------------------
   ---- Initializing More Stuff -----
   ----------------------------------
   w:reflow()
   getEntryTextWidths()
   checkTextOverlap()
   checkLogoOverlap()

   local w_min_h
   local w_max_h
   if obj_count ~= 0 then
      w_min_h = obj_heading.calc.y + logo_container.calc.h + menu_box.calc.h
      w_max_h = obj_entry_box[obj_count].calc.y + menu_box.calc.h
   else
      w_min_h = obj_heading.calc.y + logo_container.calc.h + menu_box.calc.h * 0.7
      w_max_h = w_min_h
   end

   w:attr('minh', math.floor(w_min_h + 1))
   w:attr('maxh', w_max_h)
   if not has_w_size_stored then w:attr('h', w_max_h * rtk.scale.value) end

   ----------------------------------
   ---- RESIZING FUNCTIONS ----------
   ----------------------------------
   local min_x = 0
   local max_x = 0

   for i = 1, proj_data_fields_count - 1 do

      resize[i].ondragstart = function(self, event)

         min_x = (resize[i].x - (proj_entries[i].w - Entry_Min_W)) * rtk.scale.value
         max_x = (resize[i].x + (proj_entries[i + 1].w - Entry_Min_W)) * rtk.scale.value

         return event.x
      end

      resize[i].ondragmousemove = function(self, event, dragarg)

         if event.simulated then return end

         local change = event.x - dragarg
         local is_positive = change >= 0

         if proj_entries[i].w <= Entry_Min_W and proj_entries[i + 1].w <= Entry_Min_W then
            return
         elseif change == 0 then
            return
         elseif event.x <= min_x and not is_positive then
            event.x = min_x
         elseif event.x >= max_x and is_positive then
            event.x = max_x
         end

         resize[i]:attr('x', event.x / rtk.scale.value)
         proj_entries[i]:attr('w', resize[i].x - proj_entries[i].x)

         proj_entries[i + 1]:attr('x', resize[i].x + Resize_W)
         proj_entries[i + 1]:attr('w',
            resize[i + 1].x - proj_entries[i + 1].x)

         proj_text[i + 1]:attr('x', resize[i].x + Resize_W)

         if copy_buttons_proj[i] then
            copy_buttons_proj[i]:attr('x', proj_entries[i].x + proj_entries[i].w - 32)
         end

         if obj_count < 1 then goto skip end

         if obj_data_fields_count >= i then
            for j = 1, obj_count do
               obj_entries[j][i]:attr('w', resize[i].x - proj_entries[i].x)

               if obj_data_fields_count > i then
                  obj_entries[j][i + 1]:attr('x', resize[i].x + Resize_W)
                  obj_entries[j][i + 1]:attr('w', resize[i + 1].x - proj_entries[i + 1].x)
               end
            end

            b_copy_objs[i]:attr('x', obj_entries[1][i].x + obj_entries[1][i].w - 29)
            if obj_data_fields_count > i then
               obj_text[i + 1]:attr('x', resize[i].x + Resize_W)
            end
         end

         ::skip::
         entry_ratios[i] = (proj_entries[i].w) /
             (box.w - entries_indent * 2 - Resize_W * proj_data_fields_count)
         entry_ratios[i + 1] = (proj_entries[i + 1].w) /
             (box.w - entries_indent * 2 - Resize_W * proj_data_fields_count)

         checkTextOverlap()
         checkLogoOverlap()
      end
   end

   w.onresize = function(self, last_w)

      if proj_entries[proj_data_fields_count].drawn then
         local box_last_w = last_w / rtk.scale.value - entries_indent * 2
         local w_change = (w.w - last_w) / rtk.scale.value
         box:attr('w', last_w / rtk.scale.value + w_change)

         for i = 1, proj_data_fields_count do

            if i ~= 1 then
               local new_x =
               proj_entries[i - 1].x + proj_entries[i - 1].w + Resize_W
               local move_by = new_x - proj_entries[i].x

               proj_entries[i]:attr('x', new_x)
               proj_text[i]:attr('x', proj_text[i].x + move_by)

               if obj_count < 1 then goto skip_1 end

               if obj_entries[1][i] then
                  for j = 1, obj_count do
                     obj_entries[j][i]:attr('x', new_x)
                     obj_text[i]:attr('x', obj_entries[j][i].x + 2)
                  end
               end
            end

            ::skip_1::
            local new_w = (proj_entries[i].w + w_change * entry_ratios[i])
            proj_entries[i]:attr('w', new_w)

            if copy_buttons_proj[i] then
               copy_buttons_proj[i]:attr('x', proj_entries[i].x + proj_entries[i].w - 29)
            end

            if obj_count < 1 then goto skip_2 end

            if obj_entries[1][i] then
               for j = 1, obj_count do
                  obj_entries[j][i]:attr('w', new_w)
               end
               b_copy_objs[i]:attr('x', obj_entries[1][i].x + obj_entries[1][i].w - 29)
            end

            ::skip_2::
            resize[i]:attr('x', proj_entries[i].x + proj_entries[i].w)

            checkTextOverlap()
         end

         checkLogoOverlap()
      end
   end
end

function main()
   checkGridSettings()
   getObjs()
   buildGui()
   fillEntries()
end

function init()

   local has_sws =
   'Missing. Visit https://www.sws-extension.org/ for installtion instructions.'
   local has_js = 'Missing. Click OK to open ReaPack.'
   local has_rtk = 'Missing. Click OK to open ReaPack.'

   local has_js_noauto =
   'Get it from ReaPack or visit https://forum.cockos.com/showthread.php?t=212174 \nfor installation instructions.'
   local has_rtk_noauto =
   'Visit https://reapertoolkit.dev for installation instructions.'
   local ok
   ok, rtk = pcall(function() return require('rtk') end)

   if ok then has_rtk = 'Installed.' end
   if r.APIExists('CF_GetSWSVersion') then has_sws = 'Installed.' end
   if r.APIExists('JS_Dialog_BrowseForOpenFiles') then has_js = 'Installed.' end

   if has_sws ~= 'Installed.' or has_js ~= 'Installed.' or has_rtk ~=
       'Installed.' then

      local error_msg1 = string.format(
         "Metadata Manager requires SWS Extension, JS ReaScript API and REAPER Toolkit to run. \n\nSWS Extension:	%s \n\nJS API: 		%s \n\nREAPER Toolkit: 	%s"
         ,
         has_sws, has_js, has_rtk)
      local response = r.MB(error_msg1, 'Missing Libraries', 1)

      if response ~= 1 and (has_js ~= 'Installed.' or has_rtk ~= 'Installed.') then
         local error_msg2 = 'Please install missing libraries manually.'
         if has_js ~= 'Installed.' then
            error_msg2 = error_msg2 .. '\n\nJS API: \n' .. has_js_noauto
         end
         if has_rtk ~= 'Installed.' then
            error_msg2 = error_msg2 .. '\n\nREAPER Toolkit: \n' ..
                has_rtk_noauto
         end
         return r.MB(error_msg2, 'Thank you and goodbye', 0)
      elseif response == 1 and has_js == 'Installed.' and has_rtk ==
          'Installed.' then
         return
      end

      if has_js ~= 'Installed.' and r.APIExists('ReaPack_BrowsePackages') then
         r.ReaPack_BrowsePackages(
            'js_ReaScriptAPI: API functions for ReaScripts')
         if has_rtk == 'Installed.' then return end
      elseif not r.APIExists('ReaPack_BrowsePackages') then
         local error_msg3 =
         "Couldn't find ReaPack. Visit https://reapack.com/ for installation instructions or install missing libraries manually."
         if has_js ~= 'Installed.' then
            error_msg3 = error_msg3 .. '\n\nJS API: \n' .. has_js_noauto
         end
         if has_rtk ~= 'Installed.' then
            error_msg3 = error_msg3 .. '\n\nREAPER Toolkit: \n' ..
                has_rtk_noauto
         end
         return r.MB(error_msg3, 'Thank you and goodbye', 0)
      end

      if not r.ReaPack_GetRepositoryInfo('rtk') then
         local ok, err = r.ReaPack_AddSetRepository('rtk',
            'https://reapertoolkit.dev/index.xml',
            true, 0)

         if not ok then
            return r.MB(
               'You need to manually add https://reapertoolkit.dev/index.xml to your ReaPack repositories.',
               'Missing Libraries', 0)
         else
            r.ReaPack_ProcessQueue(true)
         end
      else
         if has_js == 'Installed.' then
            r.ReaPack_BrowsePackages('REAPER Toolkit')
         end
         return
      end
   else

      rtk.add_image_search_path('img', rtk.theme.iconstyle)
      log = rtk.log
      log.level = log.ERROR

      rtk.tooltip_delay = 150
      rtk.scale.user = 1.0
      if r.HasExtState(Script_Name, 'user_scale') then
         rtk.scale.user = r.GetExtState(Script_Name, 'user_scale')
      end


      rtk.set_theme_overrides({
         entry_placeholder = Lightest_Grey,
         entry_font = { 'Calibri', 16 },
         entry_bg = { 0.28, 0.28, 0.28, 1 },
         entry_border_focused = { 1, 1, 1, 0.7 },
         entry_border_hover = { 1, 1, 1, 0.3 },
         heading_font = { 'Calibri', 20 },
         accent = 'white',

         tooltip_bg = { 0.3, 0.3, 0.3 },
         tooltip_text = Grey,
         tooltip_font = { 'Calibri', 14 }
      })

      rtk.call(main)
   end
end

init()
