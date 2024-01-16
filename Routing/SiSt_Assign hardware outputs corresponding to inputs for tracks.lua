--[[
 * ReaScript Name: Assign hardware outputs corresponding to inputs for tracks
 * Description:
 * Author: sinfricia
 * Licence: GPL v3
 * Version: 1.1
--]]
--[[
 * Changelog:
 * V1.1 (2024-01-16)
  + Fixed some bugs related to checking the dependencies
 * v1.0 (2024-01-16)
  + Initial Release
--]]

local r = reaper
local rtk
local Script_Name = "Assign hardware outputs corresponding to inputs for tracks"
local Version = "v1.0"



function Msg(input)
   local str = tostring(input)
   r.ShowConsoleMsg(str .. "\n")
end

------ CHANGE THESE VALUES TO CHANGE DEFAULT VALUES FOR CREATED HW OUTS ------
local DEFAULT_OUT_PROPERTIES = {
   B_MUTE = 0,
   B_PHASE = 0,
   B_MONO = 0,
   D_VOL = 1,
   D_PAN = 0,
   D_PANLAW = 1,
   --I_SENDMODE,
   --I_AUTOMODE,
   --I_SRCCHAN,
   --I_DSTCHAN,
   --I_MIDIFLAGS,
   --P_DESTTRACK,
   --P_ENV,
}
--------------------------------------------------------------------------

local ui_elemets_color = { 0.2, 0.2, 0.2, 1 }
local gui = {}

function Main()
   if not CheckDependencies() then return end

   local sel_tr_count = r.CountSelectedTracks(0)
   if sel_tr_count == 0 then
      r.ShowMessageBox("Can't run this action without any tracks selected.", Script_Name, 0)
      return
   end

   local retval = GetUserInput()
   return retval
end

function CreateHWOutCorrespondingToIn(tr, sendmode, set_defaults, delete_other_outs)
   local _, tr_name = r.GetTrackName(tr)
   local rec_in = r.GetMediaTrackInfo_Value(tr, "I_RECINPUT")



   if rec_in >= 4096 then --Input is MIDI
      Msg(tr_name .. ": WARNING! Input is MIDI!")
      return
   end

   local hw_out
   local out_start_idx
   local out_end_idx
   local out_width = 0
   local ch_range = ""

   if rec_in >= 2048 then --Input is Multichannel
      hw_out = rec_in - 2048
      out_start_idx = hw_out + 1
      out_end_idx = out_start_idx + r.GetMediaTrackInfo_Value(tr, "I_NCHAN") - 1
      out_width = out_end_idx - out_start_idx + 1
      ch_range = string.format("%i-%i", out_start_idx, out_end_idx)
      --Msg(tr_name .. ": WARNING! Input is Multichannel. Can't handle that yet.")
   else -- input is mono or stereo
      -- "I_RECINPUT" has 1024 set if input is mono but "I_DSTCHAN" has 1024 set if output is stereo so we need to flip that bit
      local isstereo = rec_in & 1024

      if isstereo == 1024 then
         hw_out = rec_in - 1024
         out_start_idx = hw_out + 1
         out_end_idx = hw_out + 2
         ch_range = string.format("%i/%i", out_start_idx, out_end_idx)
      else
         hw_out = rec_in + 1024
         out_start_idx = hw_out - 1024 + 1
         out_end_idx = out_start_idx
         ch_range = string.format("%i", out_start_idx)
      end
   end

   if delete_other_outs then RemoveAllHWOuts(tr) end

   -- used to set audio src channels for outputs on tracks with multichannel inputs
   local src_ch_mask = out_width / 2 << 10
   local num_sends = r.GetTrackNumSends(tr, 1)

   local out_idx = OutExists(tr, hw_out)
   if not out_idx then
      r.CreateTrackSend(tr, nil)
      out_idx = num_sends
   end

   r.SetTrackSendInfo_Value(tr, 1, out_idx, "I_DSTCHAN", hw_out)
   r.SetTrackSendInfo_Value(tr, 1, out_idx, "I_SRCCHAN", src_ch_mask)
   r.SetTrackSendInfo_Value(tr, 1, out_idx, "I_SENDMODE", sendmode)

   -- Msg(tr_name .. ": Output set to " .. ch_range)

   if set_defaults then SetOutToDefaultProperties(tr, out_idx) end
end

function OutExists(tr, out)
   local num_sends = r.GetTrackNumSends(tr, 1)

   for i = 0, num_sends - 1 do
      local curr_out = r.GetTrackSendInfo_Value(tr, 1, i, "I_DSTCHAN")
      if curr_out == out then return i end
   end

   return false
end

function SetOutToDefaultProperties(tr, out_idx)
   r.SetMediaTrackInfo_Value(tr, "B_MAINSEND", 0)
   for k, v in pairs(DEFAULT_OUT_PROPERTIES) do
      r.SetTrackSendInfo_Value(tr, 1, out_idx, k, v)
   end
end

function RemoveAllHWOuts(tr)
   local num_sends = r.GetTrackNumSends(tr, 1)
   for i = 0, num_sends - 1 do
      reaper.RemoveTrackSend(tr, 1, i)
   end
end

function GetUserInput()
   local mouse_x, mouse_y = r.GetMousePosition()

   gui.w = rtk.Window {
      title = Script_Name,
      x = mouse_x, y = mouse_y,
      borderless = true,
      resizable = false,
      border = { { 0, 0, 0, 0.1 }, 1 },
   }

   gui.vbox = gui.w:add(rtk.VBox {
      margin = 12,
      spacing = 10,
   })


   gui.heading = gui.vbox:add(rtk.Heading {
      text = "Create HW outputs corresponding to inputs?",
      fontscale = 0.8,
      bmargin = 4
   })
   gui.m_tap = gui.vbox:add(rtk.OptionMenu {
      menu = {
         { 'Post-Fader (Post-Pan)', id = '0' },
         { 'Pre-Fader (Post-FX)',   id = '3' },
         { 'Pre-Fader (Pre-FX)',    id = '1' },
      },
      selected = 1,
      color = ui_elemets_color,
      lmargin = 20,
      fontscale = 0.9,
   })
   gui.cb_defaults = gui.vbox:add(rtk.CheckBox {
      label = "Set created HW out to defaults?",
      value = true,
      lmargin = 20
   })
   gui.cb_delete_other = gui.vbox:add(rtk.CheckBox {
      label = "Remove all other HW outs?",
      value = true,
      lmargin = 20
   })


   gui.hbox_buttons = gui.vbox:add(rtk.HBox {
      tmargin = 8,
      spacing = 20,
   })
   gui.version_number = gui.hbox_buttons:add(rtk.Text {
      text = Version,
      color = { 1, 1, 1, 0.3 },
      fontscale = 0.7,
      rmargin = 100,
      cell = { valign = 'bottom' }
   })
   gui.hbox_buttons:add(rtk.Spacer {
      cell = { expand = 1 }
   })
   gui.b_cancel = gui.hbox_buttons:add(rtk.Button {
      label = "Cancel",
      color = ui_elemets_color,
   })
   gui.b_cancel.onclick = function()
      gui.w:close()
      return false
   end
   gui.b_ok = gui.hbox_buttons:add(rtk.Button {
      label = "Create",
      color = ui_elemets_color,
   })
   gui.b_ok.onclick = function()
      local sendmode = gui.m_tap.selected
      local set_defaults = gui.cb_defaults.value
      local delete_other_outs = gui.cb_delete_other.value

      gui.w:close()

      local sel_tr_count = r.CountSelectedTracks(0)

      for i = 0, sel_tr_count - 1 do
         local tr = r.GetSelectedTrack(0, i)
         CreateHWOutCorrespondingToIn(tr, sendmode, set_defaults, delete_other_outs)
      end
      return true
   end

   gui.w.onkeypresspre = function(self, event)
      if event.keycode == rtk.keycodes.ENTER then
         gui.b_ok.onclick()
      elseif event.keycode == rtk.keycodes.ESCAPE then
         gui.b_cancel.onclick()
      end
   end

   gui.w:open()
   gui.w:resize(nil, nil)
   gui.cb_defaults:focus()
end

function CheckDependencies()
   local entrypath = ({ r.get_action_context() })[2]:match('^.+[\\//]')
   package.path = string.format('%s/Scripts/rtk/1/?.lua;%s?.lua;',
      r.GetResourcePath(), entrypath)

   local has_sws = 'Missing. Visit https://www.sws-extension.org/ for installtion instructions.'
   local has_js = 'Missing. Click OK to open ReaPack.'
   local has_rtk = 'Missing. Click OK to open ReaPack.'

   local has_js_noauto =
   'Get it from ReaPack or visit https://forum.cockos.com/showthread.php?t=212174 \nfor installation instructions.'
   local has_rtk_noauto = 'Visit https://reapertoolkit.dev for installation instructions.'
   local ok
   ok, rtk = pcall(function() return require('rtk') end)

   if ok then has_rtk = 'Installed.' end
   if r.APIExists('CF_GetSWSVersion') then has_sws = 'Installed.' end
   if r.APIExists('JS_Dialog_BrowseForOpenFiles') then has_js = 'Installed.' end

   if has_sws ~= 'Installed.' or has_js ~= 'Installed.' or has_rtk ~= 'Installed.' then
      local error_msg1 = string.format(
         "This script requires SWS Extension, JS ReaScript API and REAPER Toolkit to run. \n\nSWS Extension:	%s \n\nJS API: 		%s \n\nREAPER Toolkit: 	%s"
         ,
         has_sws, has_js, has_rtk)
      local response = r.MB(error_msg1, 'Missing dependencies', 1)

      if response ~= 1 and (has_js ~= 'Installed.' or has_rtk ~= 'Installed.') then
         local error_msg2 = 'Please install missing dependencies manually.'
         if has_js ~= 'Installed.' then
            error_msg2 = error_msg2 .. '\n\nJS API: \n' .. has_js_noauto
         end
         if has_rtk ~= 'Installed.' then
            error_msg2 = error_msg2 .. '\n\nREAPER Toolkit: \n' .. has_rtk_noauto
         end
         return r.MB(error_msg2, 'Thank you and goodbye', 0)
      elseif response == 1 and has_js == 'Installed.' and has_rtk == 'Installed.' then
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
            error_msg3 = error_msg3 .. '\n\nREAPER Toolkit: \n' .. has_rtk_noauto
         end
         return r.MB(error_msg3, 'Thank you and goodbye', 0)
      end

      if not r.ReaPack_GetRepositoryInfo('rtk') then
         local ok, err = r.ReaPack_AddSetRepository('rtk',
            'https://reapertoolkit.dev/index.xml',
            true, 0)

         if not ok then
            return r.MB('You need to manually add https://reapertoolkit.dev/index.xml to your ReaPack repositories.',
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

      return false
   else
      return true
   end
end

r.Undo_BeginBlock()

Main()

r.UpdateArrange()

r.Undo_EndBlock("Assign hardware outputs corresponding to inputs for tracks", 1)
