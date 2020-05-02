script_name('Trinity Set Cooler')
script_author('Akionka')
script_version('1.0.0')

local sampev = require 'lib.samp.events'
local encoding = require 'encoding'
encoding.default = 'cp1251'
local u8 = encoding.UTF8

local prefix = 'TSC'
local state = 0 --[[
  0 = None
  1 = Take a bottle
  2 = Setup a bottle
  3 = Close inventory
]]

function sampev.onShowDialog(id, style, title, btn1, btn2, text)
  print(id, style, title, btn1, btn2, text)
  if id == 999 then
    if text == u8:decode('{afafaf}В этом кулере еще не закончилась вода.') then
      state = 3
      msg('В этом кулере еще не закончилась вода')
      sampSendDialogResponse(id, 1, 0, '')
      sampSendChat('/hands')
      return false
    elseif text == u8:decode('{afafaf}Менять воду в кулерах могут только механики.') then
      state = 3
      msg('Менять воду в кулерах могут только механики')
      sampSendDialogResponse(id, 1, 0, '')
      sampSendChat('/hands')
      return false
    end
  elseif id == 1000 then
    if state == 1 then
      local i = 0
      for item in text:gmatch('[^\r\n]+') do
        i = i + 1
        if item == u8:decode('Бутыль воды для кулера') then
          sampSendDialogResponse(id, 1, i-1, '')
          return false
        end
      end
      msg('Нет бутылей')
      sampSendDialogResponse(id, 0, 0, '')
      state = 0
      return false
    elseif state == 2 then
      local i = 0
      for item in text:gmatch('[^\r\n]+') do
        i = i + 1
        if item == u8:decode('Бутыль воды для кулера {abcdef}[Используется]') then
          sampSendDialogResponse(id, 1, i-1, '')
          return false
        end
      end
    elseif state == 3 then
      state = 0
      sampSendDialogResponse(id, 0, 0, '')
      return false
    end
  elseif id == 1001 then
    if state == 1 then
      state = 2
      sampSendDialogResponse(id, 1, 5, '')
      return false
    elseif state == 2 then
      state = 0
      sampSendDialogResponse(id, 1, 6, '')
      return false
    elseif state == 3 then
      sampSendDialogResponse(id, 0, 0, '')
      return false
    end
  end
end

function main()
  if not isSampfuncsLoaded() or not isSampLoaded() then return end
  while not isSampAvailable() do wait(0) end

  local ip = sampGetCurrentServerAddress()
  if ip ~= '185.169.134.83' and ip ~= '185.169.134.84' and ip ~= '185.169.134.85' then
    print(u8:decode('Скрипт поддерживает только сервера Trinity GTA'))
    thisScript():unload()
  end

  sampRegisterChatCommand('sc', function()
    state = 1
    sampSendChat('/hands')
    sampSendChat('/invex')
  end)

  while true do
    wait(0)
   end
end

function msg(text)
  sampAddChatMessage(u8:decode('['..prefix..']: '..text), -1)
end