--[[
 * ReaScript Name: ReaDDP
 * Author: sinfricia
 * Version: 1.0
 * About:
 *   DDP data manager and marker generator.
--]]


---- CONFIG STUFF ----
local r = reaper
package.path = r.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
local rtk = require('rtk')
local log = rtk.log
log.level = log.DEBUG

local function msg(msg)
  r.ShowConsoleMsg(tostring(msg).."\n")
end
-----------------------



---- USER CONFIGURABLE VARIABLES ----
local albumDataFields = {'ALBUM', 'EAN', 'PERFORMER', 'SONGWRITER', 'COMPOSER', 'ARRANGER', 'GENRE', 'LANGUAGE'}
local trackDataFields = {'TITLE', 'ISRC', 'PERFORMER', 'SONGWRITER', 'COMPOSER', 'ARRANGER'}
local source = 'regions'
local sanitizeIsrc = true
-------------------------------------

---- SHARED VARIABLES ----
local regions = {}
local markers = {}
local pregapIndex = {}
local markerCount, regionCount = 0
local DDPTrackCount = 0
local albumData = {}
local trackData = {}
--------------------------

------ GUI VALUES ------
local entrySpacing = 1
local windowMargin = 10

rtk.set_theme_overrides({
  entry_placeholder = {255,255,255,0.2},
  entry_font ={'Calibri', 16},
  entry_border_focused  ={255,255,255,0.7},
  entry_border_hover ={255,255,255,0.3},
})

------------------------

function getMetadataMarkers()
  local projMarkerCount = r.CountProjectMarkers(0)
  regionCount = 0
  markerCount = 0

  for i = 0, projMarkerCount - 1 do 
    index, isrgn, pos, rgnEnd, name, projIndex = r.EnumProjectMarkers(i)
    if name:find("^%#") then
      if isrgn == true then 
        name = name:gsub("^%#", "")
        regions[regionCount] = {['index']=index, ['pos']=pos, ['rgnEnd']=rgnEnd, ['name']=name, ['projIndex']=projIndex,}
        regionCount = regionCount + 1   
      else
        markers[markerCount] ={['index']=index,['name']=name, ['projIndex']=projIndex,}

        local j = 0                  
        for match in name:gmatch("=([^|]*)") do
            j = j + 1
            markers[markerCount][trackDataFields[j]] = match
        end  
        markerCount = markerCount + 1
      end
    elseif name:find("^%@") then
      markers['ALBUM'] ={['index']=index, ['name']=name, ['projIndex']=projIndex,}

      local j = 0   
      for match in name:gmatch("=([^|]*)") do
        j = j + 1
        markers['ALBUM'][albumDataFields[j]] = match
      end  
    elseif name:find("^%!") then
      pregapIndex[#pregapIndex+1] = projIndex
    end
  end
end
 

function countDDPTracks(source)
  if source == 'items' then
    DDPTrackCount = r.CountSelectedMediaItems(0)
  elseif source == 'regions' then 
    DDPTrackCount = regionCount
  elseif source == 'tracks' then 
    DDPTrackCount = r.CountSelectedTracks(0)
  end
end


function setTrackTitles(source)
  local trackTitles = {}
  local type = 1
  for j = 1, #trackDataFields do
    if trackDataFields[j] == 'TITLE' then
      type = j
    end
  end


  if source == 'items' and DDPTrackCount ~= 0 then 
    for i=0, DDPTrackCount-1 do 
      local item = r.GetSelectedMediaItem(0, i)
      trackData[i][type]:attr('value', r.GetTakeName(r.GetTake(item, 0)))
    end
  elseif source == 'regions' then 
    for i=0, DDPTrackCount-1 do 
      trackData[i][type]:attr('value', regions[i].name)
    end
  elseif source == 'tracks' then
    for i=0, DDPTrackCount-1 do 
      local track = r.GetSelectedTrack(0, i) 
      _, name = r.GetTrackName(track) 
      trackData[i][type]:attr('value', name)
    end
  else
    for i=0, DDPTrackCount-1 do 
      trackData[i][type]:attr('value', "")
    end
  end

    return trackTitles
end

function isrcCheck(entry, doSanitizeIsrc)
  
  local _isrc = entry.value
  if sanitizeIsrc then
     _isrc = _isrc:gsub("[^%w]", "")
     entry:attr('value', _isrc)
  end

  if _isrc:find("^%a%a%w%w%w%d%d%d%d%d%d%d$") or _isrc == "" then
    entry:attr('textcolor', 'white')
    entry:attr('border_focused', rtk.themes.dark.entry_border_focused)
    entry:attr('border_hover',  rtk.themes.dark.entry_border_hover)
    return true
  else
    entry:attr('textcolor', 'red')
    entry:attr('border_focused', 'red#B3')
    entry:attr('border_hover', 'red#4D')
    return false
  end

end

function calculateIsrc(entry)
  
  if isrcCheck(entry) == false then 
    return false
  end

  local isrcStart = entry.value
  local _isrc = {}

  local isrcFixed = isrcStart:sub(1, 7)

  for i=0, DDPTrackCount-1 do
    local isrcTrackId = tostring(tonumber(isrcStart:sub(8, 12)) + i)
    local isrcLeadingZeroes = string.match(isrcStart:sub(8, 12),"^0*")
    
    if #isrcTrackId + #isrcLeadingZeroes ~= 5 then
      isrcLeadingZeroes = isrcLeadingZeroes:sub(1, -2)
    end
     
  _isrc[i] = isrcFixed..isrcLeadingZeroes..isrcTrackId
  end
  return _isrc
end

function eanCheck(entry)

  local _ean = entry.value
  _ean = _ean:gsub("[^%d]", "")
  entry:attr('value', _ean)

  local eanCorrect = false

  if #tostring(_ean) == 13 then
    local eanSum = 0
    for i = 2, 13 do
      if i % 2 == 0 then
        eanSum = eanSum + math.floor((_ean % 10^i)/10^(i-1))*3
      else
        eanSum = eanSum + math.floor((_ean % 10^i)/10^(i-1))*1
      end
    end

    local checkDigit = math.floor(_ean % 10)
    local nextTen  = math.ceil(eanSum/10)*10
    if nextTen - eanSum == checkDigit then
      eanCorrect = true
    end
  end

  if eanCorrect or _ean == "" then
    entry:attr('textcolor', 'white')
    entry:attr('border_focused', rtk.themes.dark.entry_border_focused)
    entry:attr('border_hover',  rtk.themes.dark.entry_border_hover)
    return true
  else
    entry:attr('textcolor', 'red')
    entry:attr('border_focused', 'red#B3')
    entry:attr('border_hover', 'red#4D')
    return false
  end
end

function cdTextCheck(entry)
  local value = entry.value
  local foundIllegal = value:find('[^%w%s!"#$%%&\'%(%)%*%+,%-%./:;<=>%?]')
  if foundIllegal ~= nil then
    entry:attr('textcolor', 'red')
    entry:attr('border_focused', 'red#B3')
    entry:attr('border_hover', 'red#4D')
    return false
  else
    entry:attr('textcolor', 'white')
    entry:attr('border_focused', rtk.themes.dark.entry_border_focused)
    entry:attr('border_hover',  rtk.themes.dark.entry_border_hover)
    return true
  end
  -- allowedChar = '!"$%&\'()*+,-./0123456789:<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
  
end


function copyDataToAllEntrys(type, section)
  local data

  if section == 'album' then
    data = albumData[type].value
    for i = 0, DDPTrackCount-1 do
      trackData[i][type]:attr('value', data)
    end
  elseif trackDataFields[type] == 'ISRC' then
    data = calculateIsrc(trackData[0][type])
    if data ~= false then
      for i = 1, DDPTrackCount-1 do
        trackData[i][type]:attr('value', data[i])
      end
    end
  else
    data = trackData[0][type].value
    for i = 1, DDPTrackCount-1 do
      trackData[i][type]:attr('value', data)
    end
  end
end


function createDDPMarkers()
  r.Undo_BeginBlock()

  albumMarker = '@'
  for i = 1, #albumDataFields do
    albumMarker = albumMarker..albumDataFields[i]..'='..albumData[i].value..'|'
  end

  r.AddProjectMarker(0, 0, regions[regionCount-1].rgnEnd, 0, albumMarker, 999)
  r.AddProjectMarker(0, 0, 0, 0, "!", 0)
  
  for i = 0, DDPTrackCount-1 do
    trackMarker = "#"

    for j = 1, #trackDataFields do
      trackMarker = trackMarker..trackDataFields[j]..'='..trackData[i][j].value..'|'
    end
    r.AddProjectMarker(0, 0, regions[i].pos, 0, trackMarker, i+1)
    if makePregapMarker == "1" then 
      r.AddProjectMarker(0, 0, tracks[i].finish, 0, "!", i+101)
    end
  end

  r.Undo_EndBlock("Create DDP markers", -1) 
end


function fillEntries(_albumData, _trackData)
  if markerCount ~= 0 then 
    for j = 1, #albumDataFields do
      albumData[j]:attr('value', markers['ALBUM'][albumDataFields[j]])
    end

    for i = 0, markerCount - 1 do 
      for j = 1, #trackDataFields do
        trackData[i][j]:attr('value', markers[i][trackDataFields[j]])
      end
    end 
  else
    for j = 1, #albumDataFields do
      if type(_albumData[j]) == 'string' then
        albumData[j]:attr('value', _albumData[j])
      else
        albumData[j]:attr('value', "")
      end
    end

    for i = 0, DDPTrackCount - 1 do 
      for j = 1, #trackDataFields do
        if type(_trackData[i][trackDataFields[j]]) == 'string' then
          trackData[i][j]:attr('value', _trackData[i][trackDataFields[j]])
        else
          trackData[i][j]:attr('value', "")
        end
      end
    end 
  end
end

function setAlbumData(data)
  for i = 1, #albumDataFields do
    albumData[i]:attr('value', data[i])
  end
end

function recallExtStateData()
  local albumExt = {}
  local tracksExt = {}

  for i = 1, #albumDataFields do
      retval, albumExt[i] = r.GetProjExtState(0, 'ReaDDP', albumDataFields[i])
    if retval ==0 then
      albumExt[i] = ""
    end
  end

  for i = 0, DDPTrackCount - 1 do
    tracksExt[i] = {}
      retval, tracksExt[i]['extString'] = r.GetProjExtState(0,'ReaDDP', i)
      
      if retval~=0 then
        local j = 0  
      
        for match in tracksExt[i]['extString']:gmatch("=([^|]*)") do
          j = j + 1
          tracksExt[i][trackDataFields[j]] = match
        end
    else
      for j=1, #trackDataFields do
        tracksExt[i][trackDataFields[j]] = ""
      end
    end
  end  

  return albumExt, tracksExt
end

function storeExtStateData()
  for i = 1, #albumDataFields do
    if albumData[i].value ~= nil then
      r.SetProjExtState(0,'ReaDDP', albumDataFields[i], albumData[i].value)
    end
  end
  
  for i = 0, DDPTrackCount-1 do
    trackMarker = "#"
    for j = 1, #trackDataFields do
      trackMarker = trackMarker..trackDataFields[j]..'='..trackData[i][j].value..'|'
    end
    r.SetProjExtState(0, 'ReaDDP', i, trackMarker)
  end
end

function deleteDDPMarkers()
  getMetadataMarkers()

  r.Undo_BeginBlock()
  if markers['ALBUM'] ~= nil then
    r.DeleteProjectMarker(0, markers['ALBUM']['projIndex'], false)
  end
  for i=0, markerCount-1 do      
    r.DeleteProjectMarker(0, markers[i]['projIndex'], false)
  end
  for i=1, #pregapIndex do
    r.DeleteProjectMarker(0, pregapIndex[i], false)
  end
  r.Undo_EndBlock("Delete all DDP markers", -1) 
end

function clearAllData()
  for j = 1, #albumDataFields do
    albumData[j]:attr('value', "")
    r.SetProjExtState(0, 'ReaDDP', albumDataFields[j], "")
  end

  for i = 0, markerCount - 1 do
    r.SetProjExtState(0, 'ReaDDP', i, "")
    for j = 1, #trackDataFields do
      trackData[i][j]:attr('value', "")
    end
  end 
end

function storeWpos(w)
  r.SetExtState('ReaDDP', 'wx', w.x, true)
  r.SetExtState('ReaDDP', 'wy', w.y, true)
end

function recallWpos(w)
  if r.HasExtState('ReaDDP', 'wx') then
    w:attr('x', r.GetExtState('ReaDDP', 'wx'))
  end

  if r.HasExtState('ReaDDP', 'wy') then
    w:attr('y', r.GetExtState('ReaDDP', 'wy')) 
  end
end

function buildGui(source)

  ---- WINDOW SECTION ----
  local w = rtk.Window{title='ReaDDP', w=100, h=100, resizable=true}

  w.onkeypress = function(self, event)
    if event.keycode == rtk.keycodes.ESCAPE then
      rtk.quit() 
    end
  end
  
  w.onclose = function()
    storeExtStateData()
    storeWpos(w)
  end

  local box = rtk.VBox{margin={30, 10}, spacing=5}
  local vp = w:add(rtk.Viewport{box, vscrollbar='always', scrollbar_size=5})


  ---- ALBUM SECTION ----
  local albumHeading = box:add(rtk.Heading{'ALBUM METADATA', bmargin=15}, {halign='center'})
  local albumBox = box:add(rtk.HBox({lmargin=30, spacing=entrySpacing}))

  ---- ALBUM COPY BOXES ----
  local copyBoxAlbum = box:add(rtk.HBox({lmargin=30, bmargin=20,spacing=140}))
  local copyButtonsAlbum = {}
  for j = 1, #albumDataFields do
    if albumDataFields[j]=='PERFORMER' or albumDataFields[j]=='SONGWRITER' or 
       albumDataFields[j]=='COMPOSER'  or albumDataFields[j]=='ARRANGER' then
      copyButtonsAlbum[j] = copyBoxAlbum:add(rtk.Button{"copy", flat=true, fontsize=12})
      copyButtonsAlbum[j].onclick = function()
        copyDataToAllEntrys(j, 'album')
      end 
    else
      copyBoxAlbum:add(rtk.Spacer{w=30})
    end
  end
  
  --draw and fill album entry widgets
  for i = 1, #albumDataFields do
    albumData[i] = albumBox:add(rtk.Entry{placeholder=albumDataFields[i], textwidth=13}) 

    if albumDataFields[i] == 'EAN' then
      albumData[i].onchange = function()
        eanCheck(albumData[i])
      end
    else
      albumData[i].onchange = function()
        cdTextCheck(albumData[i])
      end
    end
  end

  ---- TRACK SECTION ----
  local trackHeading = box:add(rtk.Heading{'TRACK METADATA', bmargin=15}, {halign='center'})

  --draw and track entry widgets
  for i = 0, DDPTrackCount-1 do

    local trackBox = box:add(rtk.HBox({lmargin=10, spacing=entrySpacing}))
    local trNumber = trackBox:add(rtk.Text{tostring(i+1), tpadding=2, margin={0, 10, 0, 0}})
    
    for j = 1, #trackDataFields do 
      trackData[i][j] = trackBox:add(rtk.Entry{placeholder=trackDataFields[j], textwidth=13})
      
      if trackDataFields[j] == 'ISRC' then
        trackData[i][j].onchange = function(event)
          isrcCheck(trackData[i][j])
        end
      else
        trackData[i][j].onchange = function()
          cdTextCheck(trackData[i][j])
        end
      end
    end   
  end

  ---- TRACK COPY BOXES ----
  local copyBoxTracks = box:add(rtk.HBox({lmargin=30, spacing=140}))
  local copyButtonsTracks = {}
  for j = 1, #trackDataFields do
    copyButtonsTracks[j] = copyBoxTracks:add(rtk.Button{"copy", flat=true, fontsize=12})
    copyButtonsTracks[j].onclick = function()
      copyDataToAllEntrys(j, 'tracks')
    end 
  end

  ---- MENU SECTION ----
  local menuBox = box:add(rtk.HBox({margin=30, spacing=40}))

  local sourceMenu = menuBox:add(rtk.OptionMenu{
    menu={
      {'Items', id='items'},
      {'Regions', id='regions'},
      {'Tracks', id='tracks'},
    },
  })
  
  sourceMenu:select(source)
  sourceMenu.onselect = function()
    source = sourceMenu.selected_id
    local albumDataSave = {}
    for j = 1, #albumDataFields do
      albumDataSave[j] = albumData[j].value
    end
    w:close()
    countDDPTracks(source)
    buildGui(source)
    fillEntries(recallExtStateData())
    setTrackTitles(source)
    setAlbumData(albumDataSave)
  end

  local b = menuBox:add(rtk.Button{"Generate Markers"})
  b.onclick = function(self)
    createDDPMarkers()
  end

  local clearButton = menuBox:add(rtk.Button{"clear", fontsize=12},{valign='center'})
  clearButton.onclick = function()
    buildClearPopup()
  end
  
  w:open()
  w:attr('w', box.calc.w + 40)
  w:attr('h', box.calc.h + 60)
  recallWpos(w) 
end

function buildClearPopup()
  local popupBox = rtk.Container{spacing=30}
  local popup = rtk.Popup{child=popupBox, padding=25, autoclose=false, shadow={0, 0, 0, 0.1}}
  local popupText = popupBox:add(rtk.Text{"Do you want to delete all Data?", rpadding=60})
  local bNo = popupBox:add(rtk.Button{'No', margin='40 50 0 0', fontsize=14}, {halign='right'})
  local bYes = popupBox:add(rtk.Button{'Yes', margin='40 0 0 0', fontsize=14}, {halign='right'})
  local checkbox = popupBox:add(rtk.CheckBox{'Include DDP Markers', margin='46 0 0 0', fontsize=14}, {halign='left'})
  
  
  bNo.onclick = function()
    popup:close()
    return false
  end
  bYes.onclick = function()
    popup:close()
    if checkbox.value then
      deleteDDPMarkers()
    end
    clearAllData()
  end
  popup.onkeypress = function(self, event)
    if event.keycode == rtk.keycodes.ENTER then
      bYes.onclick()
    end
    --if event.keycode == rtk.keycodes.ESCAPE then
    --  popup:close() 
    --end
  end

  popup:open()
end



function main()
  getMetadataMarkers()
  countDDPTracks(source)

  for i = 0, DDPTrackCount - 1 do 
    trackData[i] = {}
    for j = 1, #albumDataFields do
      trackData[i][j] = ""
    end 
  end

  buildGui(source)

  setTrackTitles(source)
  fillEntries(recallExtStateData())


  r.SetEditCurPos(0, 1, 0)
  r.Main_OnCommand(40635, 1) --remove time selection
  r.Main_OnCommand(40296, 1) -- select all tracks
  r.Main_OnCommand(r.NamedCommandLookup("_SWS_VZOOMFIT"), 1) --zoom to selected tracks verticaally
  r.Main_OnCommand(40769, 1) --unselect tracks and items
  r.Main_OnCommand(40295, 1)     --zoom out to project horizontally
end 

r.Undo_BeginBlock()

rtk.call(main)

r.Undo_EndBlock("Create DDP markers from regions", -1) 
