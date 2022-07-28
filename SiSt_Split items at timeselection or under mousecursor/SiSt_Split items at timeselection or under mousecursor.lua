local r = reaper

r.Undo_BeginBlock()

local tsStart, tsEnd = r.GetSet_LoopTimeRange(0, 0,0,0,0)

if tsStart == tsEnd then
    r.Main_OnCommand(40746, 0) -- Split item under mouse cursor
else
    r.Main_OnCommand(40061, 0) -- Split items at time selection
end

r.Undo_EndBlock("Split Items", 4)