
local arr = reaper.new_array({}, 1)
local title = "Actions"
local windowIsOpen = reaper.JS_Window_ArrayFind(title, true, arr)

if windowIsOpen == 1 then
  hwnd = reaper.JS_Window_HandleFromAddress(arr[1])
end

if windowIsOpen == 0  or reaper.JS_Window_IsVisible(hwnd) == false then 
  reaper.ShowActionList()
else
  reaper.JS_Window_Destroy(hwnd)
end



