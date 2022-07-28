local r = reaper

r.Undo_BeginBlock()

local tsStart, tsEnd = r.GetSet_LoopTimeRange(0, 0,0,0,0)

if tsStart == tsEnd then
    r.Main_OnCommand(41295, 0) -- Duplicate items
else
    r.Main_OnCommand(41296, 0) -- Duplicate selected area of items
end

r.Undo_EndBlock("Duplicate items", 4)

r.UpdateArrange()