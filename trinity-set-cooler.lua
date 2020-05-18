script_name('Trinity Set Cooler')
script_author('Akionka')
script_version('1.2.0')

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
  4 = Buy bottles
  5 = Close talk dialog
]]
local amountOfBuyableBottles = 0
local amountOfBuyedBottles = 0
local emptyCoolers = {}
local autoSetupCooler = false
local spentMoney = 0
local bottleCost = 0

function sampev.onSetObjectMaterialText(id, text)
  if not autoSetupCooler then return end
  if text.fontColor == -14535885 and text.backGroundColor == -8942705 then
    if text.text:find('empty') and emptyCoolers[id] == nil then
      local res, cX, cY, cZ = getObjectCoordinates(sampGetObjectHandleBySampId(id))
      emptyCoolers[id] = lua_thread.create(function()
        while true do
          wait(0)
          local pX, pY, pZ = getCharCoordinates(PLAYER_PED)
          if getDistanceBetweenCoords3d(pX, pY, pZ, cX, cY, cZ) < 1 then
            setUpCooler()
            return
          end
        end
      end)
    end
  end
end

function sampev.onDestroyObject(id)
  if not autoSetupCooler then return end
  if emptyCoolers[id] ~= nil then emptyCoolers[id]:terminate() emptyCoolers[id] = nil end
end

function sampev.onShowDialog(id, style, title, btn1, btn2, text)
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
  elseif id == 5400 then
    if state == 4 then
      sampSendDialogResponse(id, 1, 0, '')
      return false
    end
  elseif id == 5401 then
    if state == 4 then
      sampSendDialogResponse(id, 1, 4, '')
      return false
    elseif state == 5 then
      state = 0
      sampSendDialogResponse(id, 0, 0, '')
      return false
    end
  elseif id == 5402 then
    if state == 4 then
      if text:find(u8:decode('Куда же вы её положите%?')) then
        msg('Нет места для большего количества бутылей. Всего куплено {9932cc}'..amountOfBuyedBottles..'{FFFFFF} бутылей за {33aa33}'..spentMoney..' ${ffffff}.')
        state = 5
        amountOfBuyableBottles = 0
        amountOfBuyedBottles = 0
        sampSendDialogResponse(id, 1, 0, '')
        return false
      elseif text:find(u8:decode('Этого недостаточно%. Бутыль стоит {33aa33}%d+ %${ffffff}%.')) then
        msg('Не хватает денег на покупку бутылей. Всего куплено {9932cc}'..amountOfBuyedBottles..'{FFFFFF} бутылей за {33aa33}'..spentMoney..' ${ffffff}.')
        state = 5
        amountOfBuyableBottles = 0
        amountOfBuyedBottles = 0
        sampSendDialogResponse(id, 1, 0, '')
        return false
      end
    end
  elseif id == 5403 then
    bottleCost = text:match(u8:decode('{33aa33}(%d+) %${ffffff}'))
    if state == 4 then
      amountOfBuyableBottles = amountOfBuyableBottles - 1
      sampSendDialogResponse(id, 1, 0, '')
      return false
    end
  elseif id == 5404 then
    if state == 4 then
      spentMoney = spentMoney + bottleCost
      amountOfBuyedBottles = amountOfBuyedBottles + 1
      if amountOfBuyableBottles == 0 then
        msg('Куплено {9932cc}'..amountOfBuyedBottles..'{FFFFFF} бутылей за {33aa33}'..spentMoney..' ${ffffff}.')
        state = 0
        sampSendDialogResponse(id, 0, 0, '')
        return false
      end
      sampSendDialogResponse(id, 1, 0, '')
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

  sampRegisterChatCommand('sc', setUpCooler)

  sampRegisterChatCommand('bb', function(params)
    if getActiveInterior() ~= 1 and not isCharInArea3d(PLAYER_PED, 1793, 751, 1498, 1801, 739, 1510, false) then
      msg('Вы не в магазине воды. Езжайте туда: /gps 27')
    end
    if not isCharInArea3d(PLAYER_PED, 1793, 741, 1500, 1798, 747, 15010) then
      msg('Подойдите ближе к продавцу воды')
    end
    params = trim(params)
    if #params == 0 then amountOfBuyableBottles = -1
    else amountOfBuyableBottles = tonumber(params) end
    amountOfBuyedBottles = 0
    state = 4
    spentMoney = 0
    sampSendChat('/talk')
  end)

  sampRegisterChatCommand('coolering', function()
    autoSetupCooler = not autoSetupCooler
    printStringNow(autoSetupCooler and '~g~on' or '~r~off',1000)
  end)

  while true do
    wait(0)
   end
end

function setUpCooler()
  state = 1
  sampSendChat('/hands')
  sampSendChat('/invex')
end

function msg(text)
  sampAddChatMessage(u8:decode('{FFFFFF}['..prefix..']: '..text), -1)
end

function trim(s)
  return (string.gsub(s, "^%s*(.-)%s*$", "%1"))
end
