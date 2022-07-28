local r = reaper
package.path = reaper.GetResourcePath() .. '/Scripts/rtk/1/?.lua'
local rtk = require('rtk')
local log = rtk.log
log.level = log.DEBUG

local function msg(msg)
  r.ShowConsoleMsg(tostring(msg).."\n")
end

rtk.set_theme_overrides({
   entry_placeholder = {255,255,255,0.2}
})

function main()
    local w = rtk.Window{title='RTK TESTING', w=400, h=300, resizable=true}

    local box = w:add(rtk.VBox({margin={30, 10}, spacing=10}))
    local text = box:add(rtk.Text{'TEXT'}, {halign='center'})
    local data = box:add(rtk.FlowBox({hspacing=1, vspacing=1}))
    

    

    local e1 = data:add(rtk.Entry{placeholder='test', textwidth=15}) 
    w:reflow()
    msg(e1.calc.w)
    
  local b = box:add(rtk.Button{"TEST", margin=30}, {halign='center'})
  b.onclick = function(self)
    reaper.ShowConsoleMsg(e.entry)
  end
    
    w:open()
end
 
rtk.call(main)
