-- Seagull Strike, console edition (LOVE 11, for PortMaster handhelds like the K36).
-- You are a seagull over the prom at Ballyspray. Eat chips. Drop on people. Taken extremely seriously.
-- The screen is drawn in a space 480 units tall (scr = pixels per unit); the game runs in steps of 1/60 s.
local U = require 'ui'
local W = require 'world'
local St = require 'stage'
local Snd = require 'sound'
local lg = love.graphics
local floor, min, max, sin = math.floor, math.min, math.max, math.sin

local TEST = nil
local GPTK = os.getenv('SEAGULL_GPTK') == '1'
local WEB = love.system.getOS() == 'Web'   -- the website version (love.js), also inside the Android app
local TOUCH = false                          -- turns on the first time someone touches the screen
for _, a in ipairs(arg or {}) do
  if a == '--test' then love.errorhandler = function(msg) print('ERROR: ' .. tostring(msg)); print(debug.traceback()) end end
end

---------------------------------------------------------------- settings
local cfg = { sound = true, music = true, invert = false, best = 0, medal = 0 }
local function saveCfg()
  if TEST then return end
  local t = {}
  for k, v in pairs(cfg) do t[#t + 1] = k .. '=' .. tostring(v) end
  pcall(love.filesystem.write, 'settings.txt', table.concat(t, '\n'))
end
local function loadCfg()
  if not love.filesystem.getInfo('settings.txt') then return end   -- (the web version can't recover from reading a missing file)
  local ok, s = pcall(love.filesystem.read, 'settings.txt')
  if not ok or type(s) ~= 'string' then return end
  for line in s:gmatch('[^\r\n]+') do
    local k, v = line:match('^(%w+)=(.*)$')
    if k and cfg[k] ~= nil then
      if type(cfg[k]) == 'number' then cfg[k] = tonumber(v) or cfg[k] else cfg[k] = v == 'true' end
    end
  end
end

---------------------------------------------------------------- the screen
local SW, SH, scr, VW = 640, 480, 1, 640
local function setupScreen()
  SW, SH = lg.getDimensions()
  scr = SH / 480; VW = SW / scr
  W.cam.cx = VW / 2
end

---------------------------------------------------------------- state
local state = 'title'
local clock, timer = 0, 0
local menuSel, setSel, pauseSel, helpPage = 1, 1, 1, 1
local paused = false
local game, demo
local pressed = {}
local result

local MENU = WEB and { 'START MISSION', 'HOW TO PLAY', 'SETTINGS' } or { 'START MISSION', 'HOW TO PLAY', 'SETTINGS', 'QUIT' }
local PAUSE = { 'RESUME', 'RESTART STAGE', 'QUIT TO MENU' }
local HELP = {
  { title = 'THE BUTTONS', lines = {
    'A  -  drop (hold it for a quick burst)', 'B  -  swoop down and grab food', 'Y  -  SQUAWK: people drop their food, umbrellas come down',
    'X  -  flap hard for a burst of speed', 'L1 / R1  -  barrel roll out of the way', 'LEFT / RIGHT  -  steer',
    'UP / DOWN  -  fly higher or lower', 'START  -  pause' } },
  { title = 'AIMING', lines = {
    'The ring on the ground is where your drop will land.', 'It turns red when someone is standing in it. Let go.',
    'People keep walking, so lead them a little.', 'Fly higher and the ring moves further ahead.', 'Fly lower and it comes closer, but it is a dangerous place to be.' } },
  { title = 'THE HUNGER', lines = {
    'Your hunger goes down all the time. If it runs out, you faint.', 'Every bit of food gives you 3 drops (your PAYLOAD, 10 at most).',
    'Food sparkles. Chips on the ground, sandwiches on the bins.', 'Swoop (B) low over it to grab it.',
    'Squawk (Y) at people with ice creams or chips: they drop them.', 'Or swoop right at them and snatch it from their hand.' } },
  { title = 'POINTS', lines = {
    'A hit on the head is full points. On the body, half.', 'Hits in a row multiply your points, up to x5. A miss resets it.',
    'Three heads in a row: HAT TRICK, 300 extra.', 'A freshly washed car: FRESH WAX.', 'Joggers 120. Ice creams 150. Phones 200. Newspaper men 300.',
    'The man in the white suit: 400. A wedding: 500 each.' } },
  { title = 'DANGERS', lines = {
    'Umbrellas block your drops. Squawk and they look up.', 'Newspaper men swat you if you fly low near them.',
    'Children with water pistols aim at you. Steer away or roll.', 'You have 4 feathers. Lose them all and it is over.',
    '', 'Sergeant Gannet will be on the radio. Listen to him.' } },
}
local BRIEF = {
  'Ballyspray. Oh-seven-hundred hours.',
  'The prom is full of people who think they own it.',
  'Your orders: drop on as many of them as you can.',
  'Eat to reload. Chips, cones, anything. A hungry gull is a dead gull.',
  'Watch for umbrellas, newspapers and children with water pistols.',
  'Good luck, gull. Ballyspray is counting on you.',
}

local function sfx(name, pitch, vol) Snd.play(name, pitch, vol) end
local function newDemo() demo = St.new({ demo = true, auto = true, seed = 77 }); W.cam.cx = VW / 2 end

-- Website only: the page reads the result from the window title and shows a "Share my score" button (WhatsApp card)
local shareN = 0
local function shareOffer(r)
  if not WEB then return end
  shareN = shareN + 1
  if r then
    love.window.setTitle(table.concat({ 'Seagull Strike', 'share', shareN, r.score, r.medal, r.hits, r.heads, r.combo, r.eaten, r.done and 1 or 0, r.newBest and 1 or 0 }, '|'))
  else
    love.window.setTitle('Seagull Strike|hide|' .. shareN)
  end
end

local function toMenu()
  if state == 'results' then shareOffer(nil) end
  state = 'menu'; game = nil; paused = false; newDemo()
  Snd.musicPlay('musicMenu')
end
local function startGame()
  if state == 'results' then shareOffer(nil) end
  game = St.new({ sfx = sfx, invert = cfg.invert, auto = TEST and TEST.auto, seed = 2026 })
  state = 'play'; paused = false; pauseSel = 1; timer = 0
  Snd.musicPlay('musicStage')
end
local function finish()
  local g = game
  result = { score = g.score, hits = g.hits, heads = g.heads, combo = g.bestCombo, eaten = g.eaten, done = g.phase == 'done', why = g.downWhy }
  result.medal = result.done and St.medal(g.score) or 0
  result.newBest = g.score > cfg.best
  if result.newBest then cfg.best = g.score end
  if result.medal > cfg.medal then cfg.medal = result.medal end
  saveCfg()
  state = 'results'; timer = 0
  shareOffer(result)
  Snd.allLoopsStop()
  Snd.musicPlay('musicMenu')
end

---------------------------------------------------------------- buttons
local KEYMAP = { up = 'up', down = 'down', left = 'left', right = 'right', w = 'up', s = 'down', a = 'left', d = 'right',
  x = 'A', z = 'B', c = 'X', v = 'Y', q = 'L1', e = 'R1', r = 'L2', t = 'R2', ['return'] = 'start', kpenter = 'start', escape = 'select', space = 'A', backspace = 'select' }
local PADMAP = { dpup = 'up', dpdown = 'down', dpleft = 'left', dpright = 'right', a = 'B', b = 'A', x = 'Y', y = 'X',
  leftshoulder = 'L1', rightshoulder = 'R1', start = 'start', back = 'select' }

local function heldInput()
  local kd = love.keyboard.isDown
  local h = { left = kd('left') or kd('a'), right = kd('right') or kd('d'), up = kd('up') or kd('w'), down = kd('down') or kd('s'),
    dropHeld = kd('x') or kd('space') }
  if not GPTK then
    for _, j in ipairs(love.joystick.getJoysticks()) do
      if j:isGamepad() then
        h.left = h.left or j:isGamepadDown('dpleft') or j:getGamepadAxis('leftx') < -.4
        h.right = h.right or j:isGamepadDown('dpright') or j:getGamepadAxis('leftx') > .4
        h.up = h.up or j:isGamepadDown('dpup') or j:getGamepadAxis('lefty') < -.4
        h.down = h.down or j:isGamepadDown('dpdown') or j:getGamepadAxis('lefty') > .4
        h.dropHeld = h.dropHeld or j:isGamepadDown('b')
      end
    end
  end
  if h.left and h.right then h.left, h.right = false, false end
  if h.up and h.down then h.up, h.down = false, false end
  h.swoop, h.squawk, h.flap, h.rollL, h.rollR = pressed.B, pressed.Y, pressed.X, pressed.L1 or pressed.L2, pressed.R1 or pressed.R2
  if pressed.A then h.dropHeld = true end
  return h
end

local function action(a)
  if state == 'title' then
    if a == 'A' or a == 'start' then state = 'menu'; menuSel = 1; sfx('confirm') end
  elseif state == 'menu' then
    if a == 'up' then menuSel = (menuSel - 2) % #MENU + 1; sfx('select')
    elseif a == 'down' then menuSel = menuSel % #MENU + 1; sfx('select')
    elseif a == 'A' or a == 'start' then
      sfx('confirm')
      if menuSel == 1 then state = 'brief'; timer = 0
      elseif menuSel == 2 then state = 'help'; helpPage = 1
      elseif menuSel == 3 then state = 'settings'; setSel = 1
      else love.event.quit() end
    elseif a == 'B' or a == 'select' then state = 'title'; sfx('back') end
  elseif state == 'brief' then
    if (a == 'A' or a == 'start') and timer > .4 then sfx('confirm'); startGame()
    elseif a == 'B' or a == 'select' then state = 'menu'; sfx('back') end
  elseif state == 'play' then
    if paused then
      if a == 'up' then pauseSel = (pauseSel - 2) % #PAUSE + 1; sfx('select')
      elseif a == 'down' then pauseSel = pauseSel % #PAUSE + 1; sfx('select')
      elseif a == 'start' or a == 'B' or a == 'select' then paused = false; sfx('back')
      elseif a == 'A' then
        sfx('confirm')
        if pauseSel == 1 then paused = false
        elseif pauseSel == 2 then startGame()
        else toMenu() end
      end
    else
      if a == 'start' or a == 'select' then paused = true; pauseSel = 1; Snd.allLoopsStop(); sfx('back')
      else pressed[a] = true end
    end
  elseif state == 'results' then
    if timer > .8 then
      if a == 'A' or a == 'start' then sfx('confirm'); startGame()
      elseif a == 'B' or a == 'select' then sfx('back'); toMenu() end
    end
  elseif state == 'help' then
    if a == 'left' then helpPage = (helpPage - 2) % #HELP + 1; sfx('select')
    elseif a == 'right' or a == 'A' then
      if a == 'A' and helpPage == #HELP then state = 'menu'; sfx('back') else helpPage = helpPage % #HELP + 1; sfx('select') end
    elseif a == 'B' or a == 'select' or a == 'start' then state = 'menu'; sfx('back') end
  elseif state == 'settings' then
    if a == 'up' then setSel = (setSel - 2) % 4 + 1; sfx('select')
    elseif a == 'down' then setSel = setSel % 4 + 1; sfx('select')
    elseif a == 'left' or a == 'right' or a == 'A' then
      if setSel == 1 then cfg.sound = not cfg.sound; Snd.on = cfg.sound; Snd.refresh()
      elseif setSel == 2 then cfg.music = not cfg.music; Snd.music = cfg.music; Snd.refresh()
      elseif setSel == 3 then cfg.invert = not cfg.invert
      elseif setSel == 4 and a == 'A' then state = 'menu' end
      saveCfg(); sfx('select')
    elseif a == 'B' or a == 'select' then state = 'menu'; sfx('back') end
  end
end

function love.keypressed(key, sc, isrepeat)
  local a = KEYMAP[key]
  if not a then return end
  if isrepeat and not (state ~= 'play' and (a == 'up' or a == 'down' or a == 'left' or a == 'right')) then return end
  action(a)
end
function love.gamepadpressed(j, b)
  if GPTK then return end
  local a = PADMAP[b]
  if a then action(a) end
end
function love.gamepadaxis(j, axis, v)
  if GPTK then return end
  if axis == 'triggerleft' and v > .6 then action('L2') elseif axis == 'triggerright' and v > .6 then action('R2') end
end
function love.focus(f) if not f and state == 'play' and not TEST then paused = true; pauseSel = 1; Snd.allLoopsStop() end end

---------------------------------------------------------------- touch screens (phones, website, Android app)
local touches = {}
local function touchButtons()
  return {
    { id = 'A', x = VW - 76, y = 376, r = 48, label = 'DROP' },
    { id = 'B', x = VW - 178, y = 424, r = 36, label = 'SWOOP' },
    { id = 'Y', x = VW - 176, y = 326, r = 32, label = 'SQUAWK' },
    { id = 'X', x = VW - 76, y = 264, r = 30, label = 'FLAP' },
    { id = 'ROLL', x = VW - 264, y = 436, r = 28, label = 'ROLL' },
    { id = 'start', x = VW - 36, y = 146, r = 18, label = 'II' },
  }
end
local function stickOf()
  for _, t in pairs(touches) do if t.role == 'stick' then return t end end
end
local function touchHeld(h)
  local s = stickOf()
  if s then
    local dx, dy = s.x - s.x0, s.y - s.y0
    if dx < -14 then h.left = true elseif dx > 14 then h.right = true end
    if dy < -14 then h.up = true elseif dy > 14 then h.down = true end
  end
  for _, t in pairs(touches) do if t.role == 'A' then h.dropHeld = true end end
end

-- a tap on the menus (x, y in screen units)
local function tapUI(x, y)
  if state == 'title' then action('A')
  elseif state == 'menu' then
    for i = 1, #MENU do
      local yy = 184 + 14 + (i - 1) * 44
      if y >= yy - 4 and y <= yy + 40 and math.abs(x - VW / 2) < 150 then menuSel = i; action('A'); return end
    end
  elseif state == 'brief' then action('A')
  elseif state == 'help' then
    if x < VW / 3 then action('left') elseif x > VW * 2 / 3 then action('right') else action('B') end
  elseif state == 'settings' then
    for i = 1, 4 do
      local yy = 110 + 70 + (i - 1) * 40 - 6
      if y >= yy and y <= yy + 34 and math.abs(x - VW / 2) < 210 then setSel = i; action('A'); return end
    end
    action('B')
  elseif state == 'play' and paused then
    for i = 1, #PAUSE do
      local yy = 180 + 14 + (i - 1) * 44
      if y >= yy - 4 and y <= yy + 40 and math.abs(x - VW / 2) < 150 then pauseSel = i; action('A'); return end
    end
  elseif state == 'results' then
    if x < VW / 2 then action('A') else action('B') end
  end
end

function love.touchpressed(id, x, y)
  TOUCH = true
  local vx, vy = x / scr, y / scr
  if state ~= 'play' or paused then tapUI(vx, vy); return end
  for _, b in ipairs(touchButtons()) do
    local dx, dy = vx - b.x, vy - b.y
    if dx * dx + dy * dy < (b.r + 12) ^ 2 then
      touches[id] = { role = b.id }
      if b.id == 'ROLL' then
        local s = stickOf()
        action((s and s.x < s.x0 - 8) and 'L1' or 'R1')
      elseif b.id ~= 'A' then action(b.id) end
      return
    end
  end
  if vx < VW * 0.55 then touches[id] = { role = 'stick', x0 = vx, y0 = vy, x = vx, y = vy } end
end
function love.touchmoved(id, x, y)
  local t = touches[id]
  if t and t.role == 'stick' then t.x, t.y = x / scr, y / scr end
end
function love.touchreleased(id) touches[id] = nil end
function love.mousepressed(x, y, button, istouch)
  if istouch or button ~= 1 then return end
  if state ~= 'play' or paused then tapUI(x / scr, y / scr) end
end

local function drawTouch()
  local s = stickOf()
  local cx, cy = s and s.x0 or 112, s and s.y0 or 370
  lg.setColor(1, 1, 1, s and 0.22 or 0.12); lg.circle('fill', cx, cy, 52)
  lg.setColor(1, 1, 1, 0.45); lg.setLineWidth(2); lg.circle('line', cx, cy, 52)
  local kx, ky = cx, cy
  if s then
    local dx, dy = s.x - s.x0, s.y - s.y0
    local d = math.sqrt(dx * dx + dy * dy)
    if d > 40 then dx, dy = dx / d * 40, dy / d * 40 end
    kx, ky = cx + dx, cy + dy
  end
  lg.setColor(1, 1, 1, 0.55); lg.circle('fill', kx, ky, 22)
  if not s then U.text('STEER', 11, cx, cy + 58, { 1, 1, 1 }, 'center', 0.7) end
  local down = {}
  for _, t in pairs(touches) do down[t.role] = true end
  for _, b in ipairs(touchButtons()) do
    local on = down[b.id]
    if b.id == 'A' then lg.setColor(1, 0.35, 0.3, on and 0.75 or 0.45)
    elseif b.id == 'start' then lg.setColor(0.03, 0.09, 0.16, 0.6)
    else lg.setColor(0.03, 0.09, 0.16, on and 0.75 or 0.5) end
    lg.circle('fill', b.x, b.y, b.r)
    lg.setColor(1, 1, 1, on and 0.9 or 0.55); lg.setLineWidth(2); lg.circle('line', b.x, b.y, b.r)
    U.text(b.label, b.r > 40 and 15 or (b.r > 20 and 11 or 13), b.x, b.y - (b.r > 40 and 9 or 7), { 1, 1, 1 }, 'center')
  end
end

---------------------------------------------------------------- screens
local function dim(a) lg.setColor(0.02, 0.06, 0.12, a); lg.rectangle('fill', 0, 0, VW, 480) end

local function logo(y, a)
  U.otext('SEAGULL', 60, VW / 2, y, { 1, 1, 1 }, 'center', a, 4)
  U.otext('STRIKE', 60, VW / 2, y + 58, { 1, 0.82, 0.25 }, 'center', a, 4)
end

local function drawDemo()
  St.draw(demo, VW, clock)
end

local function drawTitle()
  drawDemo()
  lg.setColor(0.02, 0.06, 0.12, 0.25); lg.rectangle('fill', 0, 0, VW, 480)
  logo(96, 1)
  U.otext('Ballyspray. 07:00. Taken very seriously.', 15, VW / 2, 232, { 0.9, 0.95, 1 }, 'center')
  if clock % 1.2 < 0.8 then U.otext('PRESS START', 22, VW / 2, 300, { 1, 1, 1 }, 'center') end
  if cfg.best > 0 then U.otext('BEST  ' .. St.fmt(cfg.best), 13, VW / 2, 336, { 1, 0.84, 0.25 }, 'center') end
end

local function drawMenu()
  drawDemo()
  dim(0.35)
  logo(40, 1)
  local w, h = 280, 44 * #MENU + 26
  local x, y = VW / 2 - w / 2, 184
  U.panel(x, y, w, h, 0.8)
  for i, m in ipairs(MENU) do
    local yy = y + 14 + (i - 1) * 44
    if i == menuSel then
      lg.setColor(1, 0.82, 0.25, 0.95); lg.rectangle('fill', x + 14, yy, w - 28, 36, 10, 10, 12)
      U.text(m, 17, VW / 2, yy + 8, { 0.1, 0.1, 0.15 }, 'center')
    else U.text(m, 17, VW / 2, yy + 8, { 1, 1, 1 }, 'center') end
  end
end

local function drawBrief()
  drawDemo()
  dim(0.55)
  local w, h = min(VW - 40, 600), 360
  local x, y = VW / 2 - w / 2, 60
  U.panel(x, y, w, h, 0.88)
  U.gannet(x + 70, y + 76, 46)
  U.text('MISSION BRIEFING', 13, x + 136, y + 30, { 1, 0.72, 0.2 })
  U.text('Operation Battered Sausage', 22, x + 136, y + 48, { 1, 1, 1 })
  U.text('Sergeant Gannet, Ballyspray Lighthouse', 11, x + 136, y + 80, { 0.75, 0.82, 0.9 })
  local shown = floor(timer / 0.5) + 1
  for i, l in ipairs(BRIEF) do
    if i <= shown then U.text(l, 15, x + 34, y + 140 + (i - 1) * 28, i == #BRIEF and { 1, 0.84, 0.25 } or { 1, 1, 1 }) end
  end
  if clock % 1.2 < 0.8 then U.text('A  -  take off', 13, VW / 2, y + h - 30, { 1, 1, 1 }, 'center') end
end

local function drawPause()
  dim(0.55)
  U.otext('PAUSED', 40, VW / 2, 110, { 1, 1, 1 }, 'center', 1, 3)
  local w = 280
  local x, y = VW / 2 - w / 2, 180
  U.panel(x, y, w, 44 * #PAUSE + 26, 0.85)
  for i, m in ipairs(PAUSE) do
    local yy = y + 14 + (i - 1) * 44
    if i == pauseSel then
      lg.setColor(1, 0.82, 0.25, 0.95); lg.rectangle('fill', x + 14, yy, w - 28, 36, 10, 10, 12)
      U.text(m, 17, VW / 2, yy + 8, { 0.1, 0.1, 0.15 }, 'center')
    else U.text(m, 17, VW / 2, yy + 8, { 1, 1, 1 }, 'center') end
  end
end

local MEDALC = { { 'cd7f32', 'BRONZE' }, { 'c0c7cf', 'SILVER' }, { 'ffd166', 'GOLD' } }
local function drawResults()
  drawDemo()
  dim(0.6)
  local r = result
  local w, h = min(VW - 40, 560), 400
  local x, y = VW / 2 - w / 2, 40
  U.panel(x, y, w, h, 0.9)
  U.otext(r.done and 'PROM SECURED' or 'GULL DOWN', 40, VW / 2, y + 18, r.done and { 1, 0.84, 0.25 } or { 1, 0.4, 0.35 }, 'center', 1, 3)
  if not r.done then U.text(r.why == 'hunger' and 'You fainted from hunger. Eat more chips.' or 'Out of feathers. Mind the newspapers.', 13, VW / 2, y + 70, { 1, 1, 1 }, 'center') end
  local rows = { { 'SCORE', St.fmt(r.score) }, { 'HITS', r.hits .. '   (' .. r.heads .. ' on the head)' }, { 'BEST COMBO', 'x' .. max(1, min(5, r.combo)) .. '  (' .. r.combo .. ' in a row)' }, { 'FOOD EATEN', tostring(r.eaten) } }
  for i, row in ipairs(rows) do
    local yy = y + 100 + (i - 1) * 32
    U.text(row[1], 13, x + 40, yy + 3, { 0.62, 0.83, 0.97 })
    U.text(row[2], i == 1 and 22 or 15, x + 190, yy, { 1, 1, 1 })
  end
  -- the medal
  local mx, my = x + w - 90, y + 160
  if r.medal > 0 then
    local mc = U.hex(MEDALC[r.medal][1])
    lg.setColor(U.hex('e63946')); lg.polygon('fill', mx - 18, my - 70, mx - 4, my - 70, mx + 4, my - 30, mx - 10, my - 30)
    lg.setColor(U.hex('1d3557')); lg.polygon('fill', mx + 18, my - 70, mx + 4, my - 70, mx - 4, my - 30, mx + 10, my - 30)
    lg.setColor(mc); lg.circle('fill', mx, my, 38)
    lg.setColor(1, 1, 1, 0.35); lg.circle('line', mx, my, 30)
    lg.setColor(W.dk(mc, 0.7)); lg.circle('fill', mx, my, 26)
    -- a gull on the medal
    lg.setColor(1, 1, 1); lg.setLineWidth(3)
    lg.line(mx - 16, my + 2, mx - 7, my - 6, mx, my + 1, mx + 7, my - 6, mx + 16, my + 2)
    U.text(MEDALC[r.medal][2], 13, mx, my + 46, mc, 'center')
  elseif r.done then
    U.text('No medal', 13, mx, my - 6, { 0.8, 0.8, 0.8 }, 'center')
    U.text('Bronze at ' .. St.fmt(St.MEDALS[1]), 11, mx, my + 12, { 0.7, 0.75, 0.8 }, 'center')
  end
  if r.newBest and r.score > 0 then U.otext('NEW BEST!', 17, mx, y + 250, { 1, 0.84, 0.25 }, 'center') end
  U.text('Next: Stage 2, The Harbour  -  coming soon', 13, VW / 2, y + (WEB and 270 or 300), { 0.85, 0.9, 1 }, 'center')
  if timer > .8 and clock % 1.2 < 0.8 then
    U.text(TOUCH and 'Tap left: fly again        Tap right: menu' or 'A  -  fly again        B  -  menu', 13, VW / 2, y + h - 34, { 1, 1, 1 }, 'center')
  end
end

local function drawHelp()
  drawDemo()
  dim(0.6)
  local p = HELP[helpPage]
  local w, h = min(VW - 40, 600), 380
  local x, y = VW / 2 - w / 2, 50
  U.panel(x, y, w, h, 0.9)
  U.text('HOW TO PLAY  ' .. helpPage .. ' / ' .. #HELP, 11, VW / 2, y + 18, { 0.62, 0.83, 0.97 }, 'center')
  U.text(p.title, 28, VW / 2, y + 36, { 1, 0.84, 0.25 }, 'center')
  for i, l in ipairs(p.lines) do U.text(l, 15, x + 30, y + 92 + (i - 1) * 30, { 1, 1, 1 }) end
  U.text('<  LEFT / RIGHT  >        B  -  back', 11, VW / 2, y + h - 26, { 0.8, 0.85, 0.9 }, 'center')
end

local function drawSettings()
  drawDemo()
  dim(0.6)
  local w, h = 420, 250
  local x, y = VW / 2 - w / 2, 110
  U.panel(x, y, w, h, 0.9)
  U.text('SETTINGS', 28, VW / 2, y + 18, { 1, 0.84, 0.25 }, 'center')
  local rows = { { 'SOUND', cfg.sound and 'ON' or 'OFF' }, { 'MUSIC', cfg.music and 'ON' or 'OFF' },
    { 'UP BUTTON', cfg.invert and 'DIVES (like a plane)' or 'CLIMBS' }, { 'BACK', '' } }
  for i, r in ipairs(rows) do
    local yy = y + 70 + (i - 1) * 40
    local sel = i == setSel
    if sel then lg.setColor(1, 0.82, 0.25, 0.95); lg.rectangle('fill', x + 14, yy - 6, w - 28, 32, 10, 10, 12) end
    local c = sel and { 0.1, 0.1, 0.15 } or { 1, 1, 1 }
    if r[2] == '' then U.text(r[1], 15, VW / 2, yy, c, 'center')
    else U.text(r[1], 15, x + 30, yy, c); U.text('<  ' .. r[2] .. '  >', 15, x + w - 30, yy, c, 'right') end
  end
end

---------------------------------------------------------------- the main loop
function love.load(args)
  local size
  for i, a in ipairs(args or {}) do
    if a == '--test' then TEST = { f = 0, fast = 1 } end
    if a == '--size' and args[i + 1] then local w, h = args[i + 1]:match('(%d+)x(%d+)'); size = { tonumber(w), tonumber(h) } end
  end
  love.keyboard.setKeyRepeat(true)
  if WEB then -- the window comes from conf.lua
  elseif size then love.window.setMode(size[1], size[2], { resizable = false, msaa = 4, stencil = true })
  elseif love.system.getOS() == 'Linux' or love.system.getOS() == 'Android' then
    local ok = pcall(love.window.setMode, 0, 0, { fullscreen = true, fullscreentype = 'desktop', msaa = 4, stencil = true })
    if not ok then pcall(love.window.setMode, 0, 0, { fullscreen = true, fullscreentype = 'desktop', stencil = true }) end
    love.mouse.setVisible(false)
  else
    pcall(love.window.setMode, 854, 480, { resizable = true, msaa = 4, stencil = true })
  end
  lg.setLineStyle('smooth')
  lg.setLineJoin('bevel')
  math.randomseed(os.time())
  loadCfg()
  if TEST then cfg.sound = false end
  Snd.on = cfg.sound; Snd.music = cfg.music
  Snd.load()
  U.load()
  setupScreen()
  W.load()
  newDemo()
  Snd.musicPlay('musicMenu')
end
function love.resize() setupScreen() end

local testStep
local function step(dt)
  clock = clock + dt
  timer = timer + dt
  if state == 'play' and game then
    if not paused then
      local h = (TEST and TEST.inp) or heldInput()
      if TOUCH then touchHeld(h) end
      St.touch = TOUCH
      St.update(game, dt, h)
      Snd.loop('sea', 0.25 * min(1, 8 / max(1, W.cam.x + 21)), 1)
      Snd.loop('wind', 0.12 + (game.flapT and 0.15 or 0) + (game.swoopAmt or 0) * 0.2, 1 + (game.speed - 13) * 0.02)
      if game.finished then finish() end
    end
  else
    St.update(demo, dt, {})
    Snd.allLoopsStop()
  end
  for k in pairs(pressed) do pressed[k] = nil end
end

local acc = 0
function love.update(dt)
  dt = min(dt, .1)
  if TEST then
    for _ = 1, TEST.fast do
      step(1 / 60); testStep()
      if TEST.shot or TEST.quit then break end
    end
    return
  end
  acc = acc + dt
  local n = 0
  while acc >= 1 / 60 and n < 4 do acc = acc - 1 / 60; n = n + 1; step(1 / 60) end
  if n == 4 then acc = 0 end
end

function love.draw()
  lg.origin()
  lg.clear(0, 0, 0, 1)
  lg.push()
  lg.scale(scr)
  if state == 'title' then drawTitle()
  elseif state == 'menu' then drawMenu()
  elseif state == 'brief' then drawBrief()
  elseif state == 'play' then
    St.draw(game, VW, clock); St.drawHUD(game, VW, clock)
    if TOUCH and not paused and game.phase == 'play' then drawTouch() end
    if paused then drawPause() end
  elseif state == 'results' then drawResults()
  elseif state == 'help' then drawHelp()
  elseif state == 'settings' then drawSettings() end
  lg.pop()
  if TEST and TEST.shot then
    local name = TEST.shot; TEST.shot = nil
    lg.captureScreenshot(name .. '.png')
    TEST.names[#TEST.names + 1] = name
    print('shot', name, state, game and ('score ' .. game.score .. ' z ' .. floor(W.cam.z) .. ' hunger ' .. floor(game.hunger) .. ' pay ' .. game.payload .. ' feathers ' .. game.feathers .. ' hits ' .. game.hits .. ' eaten ' .. game.eaten) or '')
  end
end

---------------------------------------------------------------- the test run (--test)
-- Visits every screen, then lets the computer fly the whole stage (dropping, eating, squawking, rolling),
-- then a second go where the gull starves. Pictures go to the save folder, plus contact sheets (sheet-1.png ...).
local co
testStep = function()
  if not co then
    TEST.names = {}
    co = coroutine.create(function()
      local function wait(n) for _ = 1, n do coroutine.yield() end end
      local function waitFor(fn, limit) local n = 0; while not fn() and n < (limit or 60000) do n = n + 1; coroutine.yield() end; return n < (limit or 60000) end
      local function shot(name) TEST.shot = name; coroutine.yield() end
      wait(40); shot('01-title')
      action('start'); wait(10); shot('02-menu')
      action('down'); action('A'); wait(4)
      for k = 1, #HELP do shot('03-help-' .. k); action('right'); wait(2) end
      action('B'); action('down'); action('A'); wait(4); shot('04-settings'); action('B')
      menuSel = 1; action('A'); wait(200); shot('05-brief')
      TEST.auto = true; action('A'); wait(60); shot('06-start')
      local g = game
      waitFor(function() return #g.drops > 0 end, 1200); wait(10); shot('07-drop-falling')
      waitFor(function() return g.hits >= 1 end, 2400); wait(3); shot('08-first-hit')
      wait(40); shot('09-hit-reaction')
      waitFor(function() return g.swoopT and g.swoopT > 0.45 end, 4000); shot('10-swoop')
      waitFor(function() return g.eaten >= 1 end, 3000); wait(2); shot('11-eaten')
      TEST.fast = 3
      waitFor(function() return g.squawkT ~= nil end, 6000); TEST.fast = 1; wait(6); shot('12-squawk')
      TEST.fast = 3
      waitFor(function() for _, p in ipairs(g.people) do if p.typ == 'umb' and p.z - W.cam.z < 22 and p.z - W.cam.z > 8 then return true end end end, 6000)
      TEST.fast = 1; shot('13-umbrella')
      TEST.fast = 3
      waitFor(function() return #g.jets > 0 end, 9000); TEST.fast = 1; wait(14); shot('14-water-pistol')
      waitFor(function() return g.rollT and g.rollT > 0.2 end, 120); shot('15-roll')
      -- fly low past a newspaper man
      TEST.fast = 3
      local pm
      waitFor(function() for _, p in ipairs(g.people) do if p.typ == 'paper' and p.z - W.cam.z < 30 and p.z - W.cam.z > 12 then pm = p; return true end end end, 9000)
      TEST.fast = 1
      if pm then
        g.auto = false
        local n = 0
        while pm.z - W.cam.z > 1.6 and n < 400 do
          n = n + 1
          TEST.inp = { left = W.cam.x > pm.x + 0.2, right = W.cam.x < pm.x - 0.2, down = true }
          coroutine.yield()
          if pm.state == 'swing' and n % 10 == 0 and not TEST.paperShot then TEST.paperShot = true; shot('16-newspaper') end
        end
        wait(6); shot('17-thwack')
        TEST.inp = nil; g.auto = true; g.cruiseY = 7
      end
      TEST.fast = 4
      waitFor(function() return W.cam.z > 880 end, 20000)
      TEST.fast = 1
      waitFor(function() for _, p in ipairs(g.people) do if p.typ == 'suit' and p.z - W.cam.z < 24 then return true end end end, 2000)
      shot('18-white-suit')
      TEST.fast = 4
      waitFor(function() return W.cam.z > St.END - 150 end, 20000)
      TEST.fast = 1; shot('19-wedding')
      action('start'); wait(2); shot('20-pause'); action('start')
      TEST.fast = 4
      waitFor(function() return g.phase ~= 'play' end, 20000)
      TEST.fast = 1; wait(60); shot('21-end')
      waitFor(function() return state == 'results' end, 600); wait(80); shot('22-results')
      -- second go: starve
      action('A'); wait(60)
      game.hunger = 3; game.auto = false
      waitFor(function() return state == 'results' end, 900); wait(80); shot('23-gull-down')
      action('B'); wait(20); shot('24-back-to-menu')
      TEST.quit = true
    end)
  end
  if coroutine.status(co) ~= 'dead' and not TEST.quit then
    local ok, err = coroutine.resume(co)
    if not ok then print('TEST ERROR: ' .. tostring(err)); TEST.quit = true end
  end
  if TEST.quit and not TEST.sheet then TEST.sheet = true; TEST.sheetT = 10 end
end

local oldUpdate = love.update
function love.update(dt)
  if TEST and TEST.sheet then
    TEST.sheetT = TEST.sheetT - 1
    if TEST.sheetT == 0 then
      local names = TEST.names
      local per = 9
      for sheet = 1, math.ceil(#names / per) do
        local c = lg.newCanvas(1920, 1440)
        lg.push('all'); lg.setCanvas(c); lg.clear(.1, .1, .1, 1); lg.origin()
        for k = 1, per do
          local nm = names[(sheet - 1) * per + k]
          if nm and love.filesystem.getInfo(nm .. '.png') then
            local img = lg.newImage(nm .. '.png')
            local cl, row = (k - 1) % 3, floor((k - 1) / 3)
            local s = min(640 / img:getWidth(), 480 / img:getHeight())
            lg.setColor(1, 1, 1, 1); lg.draw(img, cl * 640, row * 480, 0, s, s)
            lg.setColor(0, 0, 0, .7); lg.rectangle('fill', cl * 640, row * 480, 170, 16)
            lg.setColor(1, 1, 0, 1); lg.print(nm, cl * 640 + 3, row * 480 + 1)
          end
        end
        lg.pop()
        c:newImageData():encode('png', 'sheet-' .. sheet .. '.png')
      end
      print('TEST DONE', #names, 'pictures')
      love.event.quit()
    end
    return
  end
  oldUpdate(dt)
end

