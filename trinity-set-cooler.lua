script_name('Trinity Set Cooler')
script_author('Akionka')
script_version('1.2.2')

local sampev = require 'samp.events'
local encoding = require 'encoding'
encoding.default = 'UTF-8'
local cp = encoding.cp1251

---@enum state
local STATE = {
  NONE = 0,
  TAKE_BOTTLE = 1,
  SETUP_BOTTLE = 2,
  CLOSE_INVENTORY = 3,
  BUY_BOTTLES = 4,
  CLOSE_TALK_DIALOG = 5,
}
---@enum dialog
local DIALOG = {
  ERROR = 999,
  INVENTORY = 1000,
  INVENTORY_ITEM_ACTION = 1001,
  TALK_BEGIN = 5400,
  TALK_ACTION = 5401,
  TALK_ERROR = 5402,
  TALK_PRICE = 5403,
  TALK_SUCCESS = 5404,
}
---@class position
---@field x number
---@field y number
---@field z number

local prefix = 'TSC'
local state = STATE.NONE
local bottles_to_buy = 0
local bought_bottles = 0
local empty_coolers = {} ---@type table<number, position>
local auto_install_cooler = true
local spent_money = 0 -- Money spent on bottles
local bottle_price = 0 -- Price of one bottle

---Prints message to chat with prefix
---@param text string | number | boolean
---@param in_cp1251 boolean?
local function alert(text, in_cp1251)
  if not in_cp1251 and type(text) == 'string' then text = cp(text) end
  sampAddChatMessage(string.format('[%s]: %s', prefix, tostring(text)), -1)
end
---@param n number
---@param t table<number, string>
---@return string
local function plural(n, t)
  local i = n % 10 == 1 and n % 100 ~= 11 and 1 or n % 10 >= 2 and n % 10 <= 4 and (n % 100 < 10 or n % 100 >= 20) and 2 or 3
  return t[i]
end

function sampev.onSetObjectMaterialText(id, text)
  if not (text.fontColor == -14535885 and text.backGroundColor == -8942705 and text.text:find('empty')) then return end
  local res, cX, cY, cZ = getObjectCoordinates(sampGetObjectHandleBySampId(id))
  if not res then return end
  empty_coolers[id] = {x = cX, y = cY, z = cZ}
end

function sampev.onDestroyObject(id)
  empty_coolers[id] = nil
end

function sampev.onShowDialog(id, _, _, _, _, text)
  if id == DIALOG.ERROR then
    if text == cp'{afafaf}В этом кулере еще не закончилась вода.' then
      state = STATE.CLOSE_INVENTORY
      alert('В этом кулере еще не закончилась вода')
      sampSendDialogResponse(id, 1, 0, '')
      sampSendChat('/hands')
      return false
    elseif text == cp'{afafaf}Менять воду в кулерах могут только механики.' then
      state = STATE.CLOSE_INVENTORY
      alert('Менять воду в кулерах могут только механики. Устройтесь на работу механиком: {9932CC}/gps 310')
      sampSendDialogResponse(id, 1, 0, '')
      sampSendChat('/hands')
      return false
    end
  elseif id == DIALOG.INVENTORY then
    if state == STATE.TAKE_BOTTLE then
      local i = 0
      for item in text:gmatch('[^\r\n]+') do
        if item == cp'Бутыль воды для кулера' then
          sampSendDialogResponse(id, 1, i, '')
          return false
        end
        i = i + 1
      end
      alert('Нет бутылей. Купите бутыли в магазине воды: {9932CC}/gps 27')
      sampSendDialogResponse(id, 0, 0, '')
      state = STATE.NONE
      return false
    elseif state == STATE.SETUP_BOTTLE then
      local i = 0
      for item in text:gmatch('[^\r\n]+') do
        i = i + 1
        if item == 'Бутыль воды для кулера {abcdef}[Используется]' then
          sampSendDialogResponse(id, 1, i-1, '')
          return false
        end
      end
    elseif state == STATE.CLOSE_INVENTORY then
      state = STATE.NONE
      sampSendDialogResponse(id, 0, 0, '')
      return false
    end
  elseif id == 1001 then
    if state == STATE.TAKE_BOTTLE then
      state = STATE.SETUP_BOTTLE
      sampSendDialogResponse(id, 1, 5, '')
      return false
    elseif state == STATE.SETUP_BOTTLE then
      state = STATE.NONE
      sampSendDialogResponse(id, 1, 6, '')
      return false
    elseif state == STATE.CLOSE_INVENTORY then
      sampSendDialogResponse(id, 0, 0, '')
      return false
    end
  elseif id == DIALOG.TALK_BEGIN then
    if state == STATE.BUY_BOTTLES then
      sampSendDialogResponse(id, 1, 0, '')
      return false
    end
  elseif id == DIALOG.TALK_ACTION then
    if state == STATE.BUY_BOTTLES then
      sampSendDialogResponse(id, 1, 4, '')
      return false
    elseif state == STATE.CLOSE_TALK_DIALOG then
      state = STATE.NONE
      sampSendDialogResponse(id, 0, 0, '')
      return false
    end
  elseif id == DIALOG.TALK_ERROR then
    if state == STATE.BUY_BOTTLES then
      if text:find(cp'Куда же вы его положите%?') then
        alert(string.format('Нет места для большего количества бутылей. Всего куплено {9932CC}%d{FFFFFF} бутылей за {33AA33}%d ${FFFFFF}.', bought_bottles, spent_money))
      elseif text:find(cp'Этого недостаточно%. Бутыль стоит {33AA33}%d+ %${FFFFFF}%.') then
        alert(string.format('Не хватает денег на покупку бутылей. Всего куплено {9932CC}%d{FFFFFF} бутылей за {33AA33}%d ${FFFFFF}.', bought_bottles, spent_money))
      elseif text:find(cp'С его установкой сможет справиться только лицензированный механик. Мы продаем их только им.') then
        alert('Менять воду в кулерах могут только механики. Устройтесь на работу механиком: {9932CC}/gps 310{FFFFFF}.')
      end
      state = STATE.CLOSE_TALK_DIALOG
      bottles_to_buy = 0
      bought_bottles = 0
      sampSendDialogResponse(id, 1, 0, '')
      return false
    end
  elseif id == DIALOG.TALK_PRICE then
    bottle_price = text:match('{33AA33}(%d+) %${FFFFFF}')
    if state == STATE.BUY_BOTTLES then
      bottles_to_buy = bottles_to_buy - 1
      sampSendDialogResponse(id, 1, 0, '')
      return false
    end
  elseif id == DIALOG.TALK_SUCCESS then
    if state == STATE.BUY_BOTTLES then
      spent_money = spent_money + bottle_price
      bought_bottles = bought_bottles + 1
      if bottles_to_buy == 0 then
        alert(string.format('Куплено {9932CC}%d{FFFFFF} %s за {33AA33}%d ${FFFFFF}.', bought_bottles, plural(bought_bottles, {'бутыль', 'бутыли', 'бутылей'}), spent_money))
        state = STATE.NONE
        sampSendDialogResponse(id, 0, 0, '')
        return false
      end
      sampSendDialogResponse(id, 1, 0, '')
      return false
    end
  end
end

local function install_bottle()
  state = STATE.TAKE_BOTTLE
  sampSendChat('/hands')
  sampSendChat('/invex')
end
---Draws line on screen from 3d coords to 3d coords with color and width
---@param pos_x1 number
---@param pos_y1 number
---@param pos_z1 number
---@param pos_x2 number
---@param pos_y2 number
---@param pos_z2 number
---@param width number
---@param color integer
local function renderDrawLineBy3dCoords(pos_x1, pos_y1, pos_z1, pos_x2, pos_y2, pos_z2, width, color)
  local s_pos_x1, s_pos_y1 = convert3DCoordsToScreen(pos_x1, pos_y1, pos_z1)
  local s_pos_x2, s_pos_y2 = convert3DCoordsToScreen(pos_x2, pos_y2, pos_z2)
  if isPointOnScreen(pos_x1, pos_y1, pos_z1, 1) and isPointOnScreen(pos_x2, pos_y2, pos_z2, 1) then
      renderDrawLine(s_pos_x1, s_pos_y1, s_pos_x2, s_pos_y2, width, color)
  end
end

function main()
  if not isSampfuncsLoaded() or not isSampLoaded() then return end
  while not isSampAvailable() do wait(0) end

  local ip = sampGetCurrentServerAddress()
  if ip ~= '185.169.134.83' and ip ~= '185.169.134.84' and ip ~= '185.169.134.85' then
    print(cp'Скрипт поддерживает только сервера Trinity GTA')
    thisScript():unload()
    return
  end

  sampRegisterChatCommand('sc', install_bottle)

  sampRegisterChatCommand('bb', function(params)
    if getActiveInterior() ~= 14 and not isCharInArea3d(PLAYER_PED, -2222, 488, 2160, -2210, 477, 2170, false) then
      alert('Вы не в магазине воды. Езжайте туда: {9932CC}/gps 27{FFFFFF}.')
      return
    end
    local x, y, z = getCharCoordinates(PLAYER_PED)
    if getDistanceBetweenCoords3d(x, y, z, -2220, 480, 2165) > 10 then
      alert('Подойдите ближе к продавцу воды')
      return
    end
    bottles_to_buy = params:match("(%d+)") or -1
    bought_bottles = 0
    state = STATE.BUY_BOTTLES
    spent_money = 0
    sampSendChat('/talk')
  end)

  sampRegisterChatCommand('coolering', function()
    auto_install_cooler = not auto_install_cooler
    printStringNow(auto_install_cooler and '~g~on' or '~r~off', 1000)
  end)

  while true do
    if auto_install_cooler then
      local p_x, p_y, p_z = getCharCoordinates(PLAYER_PED)
      for id, pos in pairs(empty_coolers) do
        renderDrawLineBy3dCoords(p_x, p_y, p_z, pos.x, pos.y, pos.z, 2, -1)
        if getDistanceBetweenCoords3d(p_x, p_y, p_z, pos.x, pos.y, pos.z) < 1 then
          empty_coolers[id] = nil
          install_bottle()
          return
        end
      end
    end
    wait(0)
  end
end
