--[[
-- @description ReaDDP
-- @author sinfricia
-- @version 1.0
-- @about Utility to create DDP markers with a very basic UI.    
]]--

local albumMetadataFields = "Album Name,Album Performer,Album Composer,EAN,ISRC of first track,Language,Track Review (0/1), Pregap marker (0/1),extrawidth=200,separator=^"
local albumDataCount = 8
local trackMetadataFields = "Track,Performer,Composer,ISRC,extrawidth=200,separator=^"
local trackDataCount = 4
local doTrackReview = "0"
local makePregapMarker = "0"
local defaultInputs_csv = "^^^^^^" .. doTrackReview.."^"..makePregapMarker
local temp
local Album = {}
local Track = {}


local function msg(msg)
  reaper.ShowConsoleMsg(tostring(msg).."\n")
end

function Album:create()
   local alb = {}    
   setmetatable(alb, self)
   self.__index = self
    
   alb.name = ""
   alb.performer = "" 
   alb.composer = "" 
   alb.ean = "" 
   alb.isrcStart = ""
   alb.Language = ""
   alb.metadataMarker = ""
   alb.trackCount = 0
   return alb
end

function Track:create(name, performer, composer, isrcStart, trackNumber, trackStart, trackFinish)
   local tr = {}    
   setmetatable(tr, self)
   self.__index = self
    
   tr.name = name 
   tr.performer = performer 
   tr.composer = composer 
   tr.ean = ean 
   tr.isrc = calculateIsrc(isrcStart, trackNumber)
   tr.start = trackStart
   tr.finish = trackFinish
   tr.metadataMarker = ""
   return tr
end



function calculateIsrc(isrcStart, increment)
  
  if isrcStart == nil or isrcStart == "" then return "" end
  
  local isrcFixed = isrcStart:sub(1, 7)
  local isrcTrackId = tostring(tonumber(isrcStart:sub(8, 12)) + increment)
  local isrcLeadingZeroes = string.match(isrcStart:sub(8, 12),"^0*")
  
  if #isrcTrackId + #isrcLeadingZeroes ~= 5 then
    isrcLeadingZeroes = isrcLeadingZeroes:sub(1, -2)
  end
     
  return isrcFixed..isrcLeadingZeroes..isrcTrackId
end



function createAlbumFromUserInput(defaultInputs_csv)

  local inputRecieved, albumMetadata_csv = reaper.GetUserInputs("Album Metadata", albumDataCount, albumMetadataFields, defaultInputs_csv)
  if inputRecieved == false then return -1 end 
  
  albumMetadata_csv, temp = albumMetadata_csv:gsub("_", "'") --GetUserInputs doesn't like "'" as default inputs, so we use "_" as a substitute
  defaultInputs_csv, temp = albumMetadata_csv:gsub("'", "_")
  
  
  
  local a = Album:create()
  a.name, a.performer, a.composer, a.ean, a.isrcStart, a.language, doTrackReview, makePregapMarker = albumMetadata_csv:match("([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)")
  
  ------------------ sanity checking ------------------
  if a.name == nil  then
    msg("You're album needs a name!")
    return createAlbumFromUserInput(defaultInputs_csv)
  end

  if a.ean ~= ""  and (a.ean:find("%D") or #a.ean ~= 13) then
    msg("Something seems to be wrong with your EAN number")
    return createAlbumFromUserInput(defaultInputs_csv)
  end
 
  if a.isrcStart ~= "" and #a.isrcStart ~=12 then
    msg("ISRC needs to be 12 characters long.")
    return createAlbumFromUserInput(defaultInputs_csv)
  end
  ------------------------------------------------------
  
  return a
end



function createTrackObjects(album)
  local tracks = {}
  
  local temp, markerCount, regionCount = reaper.CountProjectMarkers(0)
  if regionCount == 0 then return 0 end
  
  for i = 0, regionCount + markerCount - 1 do
    local retval, isrgn, markerPos, rgnEnd, markerName, index = reaper.EnumProjectMarkers2(0, i)
    
    if isrgn == true and markerName:sub(1, 1) == "#" then
      tracks[album.trackCount] = Track:create(markerName:sub(2, -1), album.performer, album.composer, album.isrcStart, album.trackCount, markerPos, rgnEnd)
      reaper.SetProjectMarker(index, isrgn, markerPos, rgnEnd, markerName:sub(2))
      album.trackCount = album.trackCount + 1
    end
  end
  
  return tracks
  
end
  
  
function trackReview(album, tracks, index)

  if index == nil then index = 0 end
  
  for i = index, album.trackCount - 1 do
  
    defaultInputs_csv =  tracks[i].name.."^".. tracks[i].performer.."^".. tracks[i].composer.."^".. tracks[i].isrc
    defaultInputs_csv, temp = defaultInputs_csv:gsub("'", "_")
  
    local inputRecieved, trackMetadata_csv = reaper.GetUserInputs( "Track Metadata: "..tostring(i + 1).."/".. album.trackCount.." "..tracks[i].name, trackDataCount, trackMetadataFields, defaultInputs_csv)
    if inputRecieved == false then return -1 end
    trackMetadata_csv, temp = trackMetadata_csv:gsub("_", "'")
    
    tracks[i].name, tracks[i].performer, tracks[i].composer, tracks[i].isrc = trackMetadata_csv:match("([^%^]*)%^([^%^]*)%^([^%^]*)%^([^%^]*)")

    if tracks[i].isrc ~= "" and #tracks[i].isrc ~=12 then
      msg("ISRC needs to be 12 characters long.")
      return trackReview(album, tracks, i)
    end
  end

  return 0
end



function createDDPMarkers(album, tracks)

  album.metadataMarker = "@ALBUM="..album.name.."|PERFORMER="..album.performer.."|COMPOSER="..album.composer.."|EAN="..album.ean.."|LANGUAGE="..album.language
  reaper.AddProjectMarker(0, 0, tracks[album.trackCount-1].finish, 0, album.metadataMarker, 999)
  reaper.AddProjectMarker(0, 0, 0, 0, "!", 0)
  
  for i = 0, album.trackCount-1 do
    tracks[i].metadataMarker = "#TITLE="..tracks[i].name.."|PERFORMER=".. tracks[i].performer.."|COMPOSER=".. tracks[i].composer.."|ISRC="..tracks[i].isrc
    reaper.AddProjectMarker(0, 0, tracks[i].start, 0, tracks[i].metadataMarker, i+1)
    if makePregapMarker == "1" then 
      reaper.AddProjectMarker(0, 0, tracks[i].finish, 0, "!", i+101)
    end
  end
end



function main()

  local album = createAlbumFromUserInput(defaultInputs_csv)
  if album == -1 then return end
  
  local tracks = {}
  local trackCount
  tracks = createTrackObjects(album)
  
  if doTrackReview == "1" then trackReview(album, tracks) end
  
  createDDPMarkers(album, tracks)

  reaper.SetEditCurPos(0, 1, 0)
  reaper.Main_OnCommand(40635, 1) --remove time selection
  reaper.Main_OnCommand(40296, 1) -- select all tracks
  reaper.Main_OnCommand(reaper.NamedCommandLookup("_SWS_VZOOMFIT"), 1) --zoom to selected tracks verticaally
  reaper.Main_OnCommand(40769, 1) --unselect tracks and items
  reaper.Main_OnCommand(40295, 1)     --zoom out to project horizontally
end 

reaper.Undo_BeginBlock()

main()

reaper.Undo_EndBlock("Create DDP markers from regions", -1) 
