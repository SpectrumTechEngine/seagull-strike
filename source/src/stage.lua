-- The five stages: the layout, the flying, the drops, the food, the dangers, the radio and the HUD.
local W = require 'world'
local U = require 'ui'
local St = {}
local lg = love.graphics
local hex = U.hex
local cam = W.cam
local pi, min, max, floor, sin, cos, abs, sqrt = math.pi, math.min, math.max, math.floor, math.sin, math.cos, math.abs, math.sqrt
local function clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end

local GRAV = 16          -- how fast drops fall
local THROW = 11         -- drops leave the gull faster than it flies, so they land well ahead
local HZ0 = 170          -- the horizon on screen

-- Each stage gets harder: faster flying, hungrier gull, more throwers who throw sooner, faster and straighter.
-- len: metres to fly. throwers: how many. throwT: seconds a thrown thing takes to reach you (lower = harder).
-- err: how far off their aim is (metres). shots: throws each. cd: seconds between their throws.
St.LEVELS = {
  { name = 'THE PROM', theme = 'prom', len = 1450, speed = 13, hunger = 1.45, throwers = 1, throwT = 1.3, err = 1.5, shots = 2, cd = 2.6,
    kidsFrom = 430, paperFrom = 330, umbFrom = 200, thing = 'shoe', food = { 'chips', 'chips', 'cone', 'sandwich' },
    shops = { 'chips', 'ices', 'cafe', 'chips' }, pal = { 'f2b5c4', 'f6d97a', 'a9d6e5', 'f4f1e8', 'b8e0c2', 'f3a76f', 'c9b8e8', 'fbfaf6', '9fc5e8', 'ffd6a5' },
    pool = { 'walker', 'walker', 'cone', 'jogger', 'dog', 'pram', 'selfie', 'chips', 'walker' }, beach = true,
    done = 'PROM SECURED', medals = { 3500, 7000, 12000 },
    lines = { start = 'Ballyspray, oh-seven-hundred. The prom is busy. Make them remember us.', ['end'] = 'Prom secured. Back to the lighthouse, gull.' } },
  { name = 'THE HARBOUR', theme = 'harbour', len = 1500, speed = 13.5, hunger = 1.55, throwers = 3, throwT = 1.15, err = 1.15, shots = 2, cd = 2.3,
    kidsFrom = 380, paperFrom = 220, umbFrom = 160, thing = 'fish', food = { 'fish', 'fish', 'chips', 'sandwich' },
    shops = { 'fish', 'chips', 'cafe', 'fish' }, pal = { '5c7fa3', 'd7dee5', 'e9c46a', 'f4f1e8', 'b56576', '8ecae6', 'a3b18a', 'f2b5c4' },
    pool = { 'fisher', 'fisher', 'walker', 'map', 'chips', 'phone', 'dog', 'walker' }, boats = true,
    vip = { pts = 400, top = '1d3557', bottom = '1d3557', cap = 'ffffff', tie = 'ffd166', say = { 'MY HARBOUR!', 'This is a working port!' } },
    done = 'HARBOUR TAKEN', medals = { 4500, 9000, 15000 },
    lines = { start = 'The harbour. Fishermen have long memories, son. Mind the mackerel.', vip = 'Harbour master on the quay. He has had this coming.',
      ['end'] = 'Harbour taken. The trawlermen will talk about this for years.' } },
  { name = 'THE AMUSEMENTS', theme = 'fair', len = 1550, speed = 14, hunger = 1.65, throwers = 5, throwT = 1.05, err = 0.95, shots = 3, cd = 2.0,
    kidsFrom = 120, paperFrom = 260, umbFrom = 160, thing = 'ball', food = { 'candyfloss', 'chips', 'cone', 'burger' },
    shops = { 'arcade', 'bingo', 'ices', 'arcade', 'chips' }, pal = { 'ffafcc', 'bde0fe', 'fdffb6', 'caffbf', 'ffc6ff', 'ffd6a5' },
    pool = { 'walker', 'cone', 'candy', 'candy', 'selfie', 'pram', 'jogger', 'walker', 'chips' }, beach = true,
    vip = { pts = 400, top = 'f72585', bottom = 'ffbe0b', cap = '3a86ff', stripe = '4cc9f0', say = { 'HONK HONK?!', 'Not the face paint!' } },
    done = 'FUNFAIR FLATTENED', medals = { 4500, 8500, 14000 },
    lines = { start = 'The amusements. Children, candyfloss and chaos. Stay sharp.', vip = 'A clown. Nobody will miss him.',
      ['end'] = 'The funfair is ours. Go easy on the candyfloss.' } },
  { name = 'MATCH DAY', theme = 'match', len = 1600, speed = 14.5, hunger = 1.75, throwers = 7, throwT = 0.95, err = 0.75, shots = 3, cd = 1.8,
    kidsFrom = 250, paperFrom = 160, umbFrom = 99999, thing = 'hat', food = { 'burger', 'chips', 'burger', 'pizza' },
    shops = { 'pub', 'chips', 'pub', 'kebab' }, pal = { '2d6a4f', 'f4f1e8', 'c1121f', 'e9c46a', 'a9d6e5', 'f2b5c4' },
    pool = { 'fan', 'fan', 'fan', 'chips', 'walker', 'fan', 'phone' }, crowd = true,
    vip = { pts = 1000, top = '111111', bottom = '111111', stripe = 'ffd166', say = { 'YELLOW CARD!', 'I SAW THAT!' } },
    done = 'FULL TIME', medals = { 4000, 7500, 12000 },
    lines = { start = 'Match day. Ten thousand fans and not one of them likes gulls.', vip = 'The referee. Do it for the people.',
      ['end'] = 'Full time. Ballyspray will never forget it.' } },
  { name = 'BIN NIGHT', theme = 'night', len = 1650, speed = 15, hunger = 1.85, throwers = 10, throwT = 0.85, err = 0.55, shots = 3, cd = 1.6,
    kidsFrom = 99999, paperFrom = 120, umbFrom = 99999, thing = 'lid', food = { 'pizza', 'chips', 'burger', 'pizza' },
    shops = { 'kebab', 'chips', 'pub', 'kebab' }, pal = { 'f2b5c4', 'f6d97a', 'a9d6e5', 'f4f1e8', 'b8e0c2', 'c9b8e8' },
    pool = { 'walker', 'binman', 'chips', 'walker', 'binman', 'phone' }, binsMany = true,
    vip = { pts = 1000, top = '1d3557', bottom = '1d3557', tie = 'ffd166', stripe = 'ffd166', say = { 'I AM THE MAYOR!', 'Do you know who I am?!' } },
    done = 'BALLYSPRAY IS OURS', medals = { 6000, 13000, 22000 },
    lines = { start = 'Bin night. The town sleeps. The bins do not. This is the big one.', vip = 'The Mayor. He signed the order against us. Make it count.',
      ['end'] = 'Ballyspray is ours. I am proud of you, gull.' } },
}
St.MEDALS = St.LEVELS[1].medals

---------------------------------------------------------------- who's on the prom
local TYPES = {
  walker = { pts = 100, say = { 'OI!', 'Ah no.', 'NOT AGAIN!', 'Disgusting!' } },
  jogger = { pts = 120, say = { 'MY RUN!', 'Seriously?!' }, pose = 'jog', speed = 3.0 },
  cone = { pts = 150, say = { 'MY 99!', 'In me ice cream!' }, pose = 'cone', food = 'cone' },
  chips = { pts = 150, say = { 'GET AWAY!', 'Not the chips!' }, pose = 'chips', food = 'chips' },
  selfie = { pts = 200, say = { 'DELETE THAT!', 'Ah, the photo!' }, pose = 'selfie', still = true },
  pram = { pts = 100, say = { 'Ah here!', 'The CHEEK of it!' }, pose = 'pram' },
  dog = { pts = 100, say = { 'Don\'t look, Rex.', 'OI!' }, pose = 'dog' },
  phone = { pts = 200, say = { 'I\'ll call you back.', 'Ring you back.' }, pose = 'phone' },
  map = { pts = 150, say = { 'Where AM I?!', 'Is this normal?' }, pose = 'map', still = true },
  umb = { pts = 175, say = { 'What?!', 'It\'s not even raining!' }, pose = 'umb' },
  paper = { pts = 300, say = { 'YOU\'RE DEAD, BIRD!', 'COME HERE!' }, pose = 'paper' },
  kid = { pts = 150, say = { 'MAMMY!', 'NOT FAIR!' }, pose = 'pistol', h = 1.15, still = true },
  suit = { pts = 400, say = { 'NOT THE SUIT!', 'It was RENTED!' } },
  lifeguard = { pts = 250, say = { 'FWEEEEP!' }, pose = 'look', still = true },
  bride = { pts = 500, say = { 'MY DRESS!', 'TODAY?!' }, still = true },
  groom = { pts = 500, say = { 'It\'s lucky, they say.', 'Ah lads.' }, still = true },
  snapper = { pts = 300, say = { 'Got it!', 'Beautiful.' }, pose = 'camera', still = true },
  pal = { pts = 150, say = { 'OI!', 'Ah no.' }, still = true },
  fisher = { pts = 150, say = { 'Not on the oilskin!', 'Gerrup outta that!' } },
  candy = { pts = 150, say = { 'MY CANDYFLOSS!', 'It is all sticky now!' }, pose = 'chips', food = 'candyfloss' },
  fan = { pts = 150, say = { 'REF! REF!', 'Up the Bally!', 'That is a foul!' } },
  binman = { pts = 200, say = { 'I am on shift here!', 'Charming.' } },
  thrower = { pts = 250, say = { 'MISSED ME!', 'Come back here!', 'Right. That is it.' }, pose = 'thrower', still = true },
  vip = { pts = 400, say = { 'OI!' }, still = true },
}
local SKINS = { 'f1c9a5', 'e0ac69', 'c68642', '8d5524', 'f2b8a0', 'ffdbac' }
local HAIRS = { '2b1d14', '4a2c1d', '6b4f3a', 'e9c46a', '1b1b1b', 'a0a0a0', 'b5562b' }
local STYLES = { 'short', 'short', 'long', 'bun', 'ponytail', 'bald' }
local TOPS = { 'ef476f', '118ab2', '06d6a0', 'ffd166', '8338ec', 'fb8500', '2a9d8f', '3a86ff', 'c77dff', 'e76f51', '588157', '264653' }
local BOTTOMS = { '22223b', '3d405b', '4a4e69', '264653', '8d99ae', 'e8d9b5' }
local CARS = { 'e63946', 'f1f1ec', '2a9d8f', 'ffb703', '457b9d', '6d597a', '1d3557', 'adb5bd' }
local PAL = { 'f2b5c4', 'f6d97a', 'a9d6e5', 'f4f1e8', 'b8e0c2', 'f3a76f', 'c9b8e8', 'fbfaf6', '9fc5e8', 'ffd6a5' }

local function pick(r, t) return t[floor(r:random() * #t) + 1] end

local function newPerson(g, typ, x, z)
  local T = TYPES[typ]
  local r = g.rng
  local p = { kind = 'person', typ = typ, x = x, z = z, h = T.h or (1.62 + r:random() * 0.22), pts = T.pts,
    skin = hex(pick(r, SKINS)), hair = hex(pick(r, HAIRS)), hairStyle = pick(r, STYLES), top = hex(pick(r, TOPS)),
    bottom = hex(pick(r, BOTTOMS)), shoes = hex(r:random() < 0.4 and 'f5f5f5' or '2b2b2b'), pose = T.pose or 'walk', food = T.food,
    state = 'walk', st = 0, phase = r:random() * 6, vz = 0, moving = not T.still }
  if p.moving then p.vz = (r:random() < 0.65 and -1 or 1) * (T.speed or (1.0 + r:random() * 0.5)) end
  if typ == 'jogger' then p.band = hex('ffffff'); p.shoes = hex('f5f5f5'); p.hairStyle = 'ponytail' end
  if typ == 'cone' and r:random() < 0.5 then p.shorts = true; p.hairStyle = 'bald'; p.skin = hex('f2a98d'); p.blush = true; p.stripe = hex('f8f3e3') end
  if typ == 'suit' then p.top = hex('f8f9fa'); p.bottom = hex('f1f3f5'); p.tie = hex('e63946'); p.shoes = hex('5b3a29'); p.hairStyle = 'short' end
  if typ == 'paper' then p.top = hex('6c584c'); p.bottom = hex('3d405b'); p.cap = hex('7f8c8d'); p.hairStyle = 'short'; p.hair = hex('a0a0a0') end
  if typ == 'kid' then p.shorts = true; p.cap = hex(pick(r, { 'ff006e', '3a86ff', 'ffbe0b' })); p.hairStyle = 'short' end
  if typ == 'lifeguard' then p.top = hex('e63946'); p.bottom = hex('ffd60a'); p.shorts = true; p.cap = hex('ffd60a') end
  if typ == 'bride' then p.dress = true; p.top = hex('ffffff'); p.bottom = hex('fdfdfd'); p.veil = true; p.hairStyle = 'bun' end
  if typ == 'groom' then p.top = hex('1d3557'); p.bottom = hex('1d3557'); p.tie = hex('ffd166'); p.hairStyle = 'short' end
  if typ == 'snapper' then p.top = hex('222222'); p.bottom = hex('22223b') end
  if typ == 'umb' then p.umbOpen = true; p.umbC = hex(pick(r, { 'e63946', '3a86ff', 'ffbe0b', '8338ec', '06d6a0' })) end
  if typ == 'pram' then p.pramC = hex(pick(r, { 'ef476f', '3d5a80', '2a9d8f' })); p.vz = -abs(p.vz) end
  if typ == 'selfie' then p.hairStyle = 'long' end
  local th = g.L.theme
  if typ == 'fisher' or (typ == 'thrower' and th == 'harbour') then p.top = hex('ffbe0b'); p.bottom = hex('ffbe0b'); p.cap = hex('ffbe0b'); p.shoes = hex('2b2b2b') end
  if typ == 'fan' or (th == 'match' and (typ == 'thrower' or typ == 'walker' or typ == 'chips')) then
    local j = r:random() < 0.7 and '2d6a4f' or 'c1121f'
    p.top = hex(j); p.stripe = hex('ffffff')
    if typ ~= 'thrower' and r:random() < 0.4 then p.cap = hex(j) end
  end
  if typ == 'binman' or (typ == 'thrower' and th == 'night') then p.top = hex('ff7b00'); p.stripe = hex('e9ff70'); p.bottom = hex('22223b'); p.cap = hex('22223b') end
  if typ == 'thrower' and th == 'prom' then p.shorts = true; p.top = hex('ff5d8f') end
  if typ == 'thrower' and th == 'fair' then p.h = 1.5; p.cap = hex('3a86ff'); p.shorts = true end
  if typ == 'thrower' then p.throwKind = g.L.thing end
  if typ == 'vip' then
    local v = g.L.vip
    p.top = hex(v.top); p.bottom = hex(v.bottom); p.pts = v.pts
    p.tie = v.tie and hex(v.tie); p.cap = v.cap and hex(v.cap); p.stripe = v.stripe and hex(v.stripe)
  end
  g.people[#g.people + 1] = p
  return p
end

local function addItem(g, food, x, z, y)
  local it = { kind = 'item', food = food, x = x, z = z, y = y or 0 }
  g.items[#g.items + 1] = it
  return it
end

local function build(g)
  local r = g.rng
  local L = g.L
  local END = L.len
  local z, i, shopK = -10, 0, 0
  while z < END + 600 do
    i = i + 1
    local w = 6.4 + r:random() * 2.2
    local h = { z0 = z, z1 = z + w, h = 8.8 + r:random() * 2.4, c = hex(L.pal[(i - 1) % #L.pal + 1]), door = (i % 6) + 1 }
    if i % (L.theme == 'fair' and 2 or 5) == (L.theme == 'fair' and 1 or 3) then
      shopK = shopK + 1; h.shop = L.shops[(shopK - 1) % #L.shops + 1]; h.c = hex('f4f1e8')
    end
    g.houses[#g.houses + 1] = h
    z = z + w
  end
  for lz = 11, END + 400, 15 do g.lamps[#g.lamps + 1] = { kind = 'lamp', x = -7.95, z = lz } end
  for lz = 19, END + 400, 17 do g.lamps[#g.lamps + 1] = { kind = 'lamp', x = 11.4, z = lz } end
  for bz = 13.5, END + 300, 27 do g.benches[#g.benches + 1] = { kind = 'bench', z = bz } end
  local binGap = L.binsMany and 18 or (L.theme == 'harbour' and 24 or 38)
  for bz = 24.6, END + 300, binGap do
    g.bins[#g.bins + 1] = { kind = 'bin', x = -7.3, z = bz }
    if bz > 40 and r:random() < (L.binsMany and 0.6 or 0.5) then addItem(g, L.food[floor(r:random() * #L.food) + 1], -7.3, bz - 0.05, 1.0) end
  end
  if L.binsMany then
    for bz = 30, END + 300, 21 do g.bins[#g.bins + 1] = { kind = 'bin', x = 12.2, z = bz } end
  end
  if L.beach then
    for wz = 20, END + 300, 55 + floor(r:random() * 30) do g.winds[#g.winds + 1] = { kind = 'wind', z = wz } end
    for _, cz in ipairs({ 140, 610, 1080 }) do
      g.chairs[#g.chairs + 1] = { kind = 'chair', x = -11.2, z = cz }
      newPerson(g, 'lifeguard', -10.3, cz + 0.6)
    end
  end
  if L.boats then
    for tz = 30, END + 300, 26 + floor(r:random() * 16) do g.trawlers[#g.trawlers + 1] = { kind = 'trawler', z = tz, c = pick(r, { '1d3557', 'c1121f', '2a9d8f', '264653' }) } end
  end
  for k, b in ipairs({ { -60, 105 }, { -180, 300 }, { -90, 520 }, { -140, 800 }, { -70, 1050 }, { -120, 1300 }, { -200, 1700 } }) do
    g.boats[#g.boats + 1] = { kind = 'boat', x = b[1], z = b[2], c = ({ '264653', 'e63946', '1d3557' })[k % 3 + 1] }
  end
  g.piers[1] = { kind = 'pier', z = END + 60 }
  z = 17
  while z < END + 300 do
    g.cars[#g.cars + 1] = { kind = 'car', z = z, c = hex(pick(r, CARS)) }
    z = z + 4.3 + 1.5 + r:random() * 10
  end
  -- people
  z = 30
  while z < END - 60 do
    local pool = {}
    for _, t in ipairs(L.pool) do pool[#pool + 1] = t end
    if z > L.umbFrom then pool[#pool + 1] = 'umb'; pool[#pool + 1] = 'phone' end
    if z > L.paperFrom then pool[#pool + 1] = 'paper' end
    if z > L.kidsFrom then pool[#pool + 1] = 'kid'; if z > L.kidsFrom + 400 then pool[#pool + 1] = 'kid' end end
    local typ = pick(r, pool)
    local x = -7.0 + r:random() * 6.6
    if typ ~= 'kid' and typ ~= 'paper' and r:random() < 0.12 then x = 11.6 + r:random() * 1.8 end
    newPerson(g, typ, x, z)
    if typ == 'selfie' then local q = newPerson(g, 'pal', x + 0.7, z + 0.3); q.pose = 'walk' end
    local extra = L.crowd and 0.75 or 0.35
    if r:random() < extra then newPerson(g, pick(r, L.pool), clamp(x + (r:random() * 3 - 1.5), -7.2, 0), z + 2 + r:random() * 3) end
    z = z + (L.crowd and 5 or 8) + r:random() * (L.crowd and 6 or 9)
  end
  -- the throwers, spread along the stage
  for k = 1, L.throwers do
    local tz = END * (0.16 + 0.74 * (k - 0.5) / L.throwers)
    newPerson(g, 'thrower', -6.5 + r:random() * 5.5, tz)
  end
  -- someone special
  if L.theme == 'prom' then
    newPerson(g, 'suit', -3.4, 930).vz = -1.1
    newPerson(g, 'bride', -4.5, END - 120)
    newPerson(g, 'groom', -3.7, END - 119.8)
    newPerson(g, 'snapper', -1.6, END - 126)
  else
    newPerson(g, 'vip', -3.2, L.theme == 'night' and END - 110 or END * 0.6)
  end
  -- food lying about
  addItem(g, L.food[1], -2.6, 62)
  z = 95
  while z < END do
    local x = -7 + r:random() * 6.5
    if L.beach and r:random() < 0.2 then x = -11 + r:random() * 2 end
    addItem(g, pick(r, L.food), x, z)
    z = z + 32 + r:random() * 22
  end
end

---------------------------------------------------------------- the radio
local LINES = {
  start = 'Ballyspray, oh-seven-hundred. The prom is busy. Make them remember us.',
  aim = 'The ring is your drop zone. A to release. Lead your target.',
  first = 'Direct hit. Textbook.',
  food = 'Payload low. Swoop with B on that food. A gull fights on its stomach.',
  hungry = 'You\'re running on fumes, son. Eat something.',
  umb = 'Umbrella. Clever. Squawk with Y and he\'ll look up.',
  kids = 'Water pistols ahead. Steer clear or roll with L1 or R1.',
  paper = 'Newspaper man. Stay high, or he\'ll have you.',
  suit = 'White suit, twelve o\'clock. This is what we trained for.',
  wedding = 'A wedding. God forgive us.',
  combo = 'Three in a row. The lads on the pier are watching.',
  hit = 'You\'re hit! Shake it off.',
  hat = 'Hat trick. I haven\'t seen flying like that since the summer of \'09.',
  empty = 'You\'re empty. Find food.',
  throw = 'Incoming! Watch the one with his arm back. Dodge it.',
  downF = 'Gull down. Gull down.',
  downH = 'He fainted. Too proud to eat a chip.',
}
local function radio(g, key, force)
  if g.demo then return end
  g.said = g.said or {}
  if g.said[key] and not force then return end
  g.said[key] = true
  local text = (g.L.lines and g.L.lines[key]) or LINES[key]
  if text then table.insert(g.radio, { text = text, t = 4.2 }) end
end

---------------------------------------------------------------- making a stage
function St.new(opts)
  opts = opts or {}
  local level = opts.level or 1
  local L = St.LEVELS[level]
  W.setTheme(L.theme)
  local g = { rng = love.math.newRandomGenerator((opts.seed or 2026) + level * 101), houses = {}, lamps = {}, benches = {}, bins = {}, winds = {}, chairs = {},
    boats = {}, piers = {}, people = {}, items = {}, drops = {}, jets = {}, cars = {}, decals = {}, pops = {}, radio = {}, throws = {}, trawlers = {},
    L = L, level = level,
    demo = opts.demo, auto = opts.auto, invert = opts.invert, sfx = opts.sfx or function() end,
    t = 0, speed = L.speed, cruiseY = 7, vx = 0, payload = 6, hunger = 85, feathers = 3, score = 0, combo = 0, bestCombo = 0,
    heads = 0, hits = 0, eaten = 0, headStreak = 0, phase = 'play', flap = 0, dropCD = 0, squawkCD = 0, flapCD = 0, hurtT = 0, shake = 0 }
  cam.x, cam.y, cam.z, cam.roll, cam.hz = -2.5, 7, 0, 0, HZ0
  build(g)
  return g
end

local function pop(g, x, y, z, text, sub, c, size)
  g.pops[#g.pops + 1] = { x = x, y = y, z = z, text = text, sub = sub, c = c, size = size, t = 1.2 }
end

local function hurt(g, why)
  if g.rollT or g.hurtT > 0 or g.phase ~= 'play' then return false end
  g.feathers = g.feathers - 1
  g.hurtT = 1.5; g.shake = 0.45; g.hurtWhy = why
  g.combo = 0; g.headStreak = 0
  g.sfx(why == 'water' and 'squirt' or 'thwack'); g.sfx('hurtcry')
  if g.feathers <= 0 then
    g.phase = 'down'; g.endT = 0; g.downWhy = 'feathers'; g.sfx('sad'); radio(g, 'downF')
  else radio(g, 'hit', true) end
  return true
end

local function eat(g, food, x, z)
  g.payload = min(10, g.payload + 3)
  g.hunger = min(100, g.hunger + 22)
  g.eaten = g.eaten + 1
  local name = food == 'cone' and 'A 99!' or food == 'sandwich' and 'SAMBO!' or 'CHIPS!'
  pop(g, x, 1.6, z, name, '+3 DROPS', { 0.6, 1, 0.6 }, 17)
  g.sfx('chomp')
end

local function hitPerson(g, p, where)
  local base = p.pts
  if where == 'body' then base = floor(base / 2) end
  local again = p.splat and where == 'head'
  if again then base = 25 end
  g.combo = g.combo + 1
  local mult = min(5, g.combo)
  local pts = base * mult
  g.score = g.score + pts
  g.hits = g.hits + 1
  g.bestCombo = max(g.bestCombo, g.combo)
  if where == 'head' then p.splat = true; g.heads = g.heads + 1; g.headStreak = g.headStreak + 1 else p.bodySplat = true; g.headStreak = 0 end
  p.state = 'hit'; p.st = 0
  local says = (p.typ == 'vip' and g.L.vip.say) or TYPES[p.typ].say
  p.say = says[floor(g.rng:random() * #says) + 1]; p.sayT = 2.2
  if p.food then addItem(g, p.food, p.x + 0.4, p.z); p.food = nil end
  if p.typ == 'umb' then p.umbOpen = false; p.umbT = 99 end
  pop(g, p.x, p.h + 0.4, p.z, again and 'AGAIN?' or (where == 'head' and 'SPLAT!' or 'HIT!'), '+' .. pts .. (mult > 1 and ('   x' .. mult) or ''))
  g.sfx('splat')
  if p.typ == 'lifeguard' then g.sfx('whistle') end
  if g.hits == 1 then radio(g, 'first') end
  if g.combo == 3 then radio(g, 'combo') end
  if g.headStreak == 3 then
    g.headStreak = 0
    g.score = g.score + 300
    pop(g, p.x, p.h + 1.4, p.z, 'HAT TRICK!', '+300', { 1, 0.55, 0.2 }, 22)
    g.sfx('ding'); radio(g, 'hat')
  end
end

local function checkHit(g, d)
  for _, p in ipairs(g.people) do
    local dz = p.z - d.z
    if dz > -0.8 and dz < 0.8 then
      local dx = p.x - d.x
      local dist2 = dx * dx + dz * dz
      local hh = p.h
      if d.y < hh + 0.25 and d.y > hh - 0.5 and dist2 < 0.45 * 0.45 then
        if p.typ == 'umb' and p.umbOpen then
          pop(g, p.x, p.h + 0.6, p.z, 'BLOCKED!', 'squawk first (Y)', { 0.75, 0.85, 1 }, 15)
          g.combo = 0; g.headStreak = 0; g.sfx('blocked'); radio(g, 'umb')
          return true
        end
        hitPerson(g, p, 'head'); return true
      elseif d.y <= hh - 0.5 and d.y > 0.3 and dist2 < 0.5 * 0.5 then
        hitPerson(g, p, 'body'); return true
      end
    end
  end
  if d.y < 1.5 and d.x > 9 and d.x < 10.8 then
    for _, c in ipairs(g.cars) do
      if d.z >= c.z and d.z <= c.z + 4.3 then
        c.splats = c.splats or {}
        c.splats[#c.splats + 1] = { d.x, d.z }
        g.combo = g.combo + 1
        local mult = min(5, g.combo)
        g.score = g.score + 120 * mult; g.hits = g.hits + 1; g.bestCombo = max(g.bestCombo, g.combo)
        pop(g, d.x, 2, d.z, 'FRESH WAX!', '+' .. (120 * mult) .. (mult > 1 and ('   x' .. mult) or ''), { 0.6, 0.9, 1 })
        g.sfx('splat'); g.sfx('alarm')
        return true
      end
    end
  end
  return false
end

local function miss(g, d)
  g.combo = 0; g.headStreak = 0
  if d.x > -13 then
    table.insert(g.decals, { x = d.x, z = d.z })
    if #g.decals > 40 then table.remove(g.decals, 1) end
    g.sfx('miss')
    for _, p in ipairs(g.people) do
      if p.state == 'walk' and abs(p.z - d.z) < 2.5 and abs(p.x - d.x) < 2.5 then p.state = 'look'; p.st = 0; p.say = '?'; p.sayT = 0.9 end
    end
  else g.sfx('plop', 0.6) end
  g.misses = (g.misses or 0) + 1
end

local function squawk(g)
  g.sfx('squawk')
  g.squawkCD = 2.5
  g.squawkT = 0
  for _, p in ipairs(g.people) do
    local d = p.z - cam.z
    if d > 1 and d < 32 and abs(p.x - cam.x) < 10 then
      if p.food then addItem(g, p.food, p.x + 0.4, p.z); p.food = nil; p.say = 'HEY!'; p.sayT = 1.2 end
      if p.typ == 'umb' and p.umbOpen then p.umbOpen = false; p.umbT = 5; p.say = 'Hm?'; p.sayT = 1.2 end
      if p.state == 'walk' then p.state = 'look'; p.st = 0 end
    end
  end
end

---------------------------------------------------------------- the computer pilot (tests + title screen)
local function autopilot(g)
  local inp = {}
  if g.demo then
    local tx = -2.5 + sin(g.t * 0.25) * 3
    inp.left = cam.x > tx + 0.4; inp.right = cam.x < tx - 0.4
    return inp
  end
  g.ap = g.ap or {}
  if g.phase ~= 'play' then return inp end
  for _, j in ipairs(g.throws) do
    if j.z - cam.z < 8 and abs(j.x - cam.x) < 2 and not g.rollT then
      if j.x > cam.x then inp.rollL = true else inp.rollR = true end
      return inp
    end
  end
  for _, j in ipairs(g.jets) do
    if j.z - cam.z < 9 and not g.rollT then
      if j.x > cam.x then inp.rollL = true else inp.rollR = true end
      return inp
    end
  end
  local tx
  if g.payload <= 2 or g.hunger < 40 then
    local best, bd
    for _, it in ipairs(g.items) do
      local d = it.z - cam.z
      if not it.gone and d > 3 and d < 45 and (not bd or d < bd) then best, bd = it, d end
    end
    if best then
      tx = best.x
      if bd < g.speed * 0.42 + 1 and abs(best.x - cam.x) < 1.2 and not g.swoopT then inp.swoop = true end
    end
  end
  if not tx and g.payload > 0 then
    local best, bs
    for _, p in ipairs(g.people) do
      local d = p.z - cam.z
      if not p.splat and d > 10 and d < 40 and p.x > -12 and p.x < 3.2 then
        local sc = p.pts - d * 4
        if not bs or sc > bs then best, bs = p, sc end
      end
    end
    if best then
      tx = best.x
      if best.typ == 'umb' and best.umbOpen and g.squawkCD <= 0 and best.z - cam.z < 25 then inp.squawk = true end
    end
    if g.lock and not g.lock.splat then inp.dropHeld = true end
  end
  if g.flapCD <= 0 and g.t % 11 < 0.05 then inp.flap = true end
  tx = tx or -3
  inp.left = cam.x > tx + 0.12; inp.right = cam.x < tx - 0.12
  return inp
end

---------------------------------------------------------------- one step (1/60 s)
function St.update(g, dt, inp)
  g.t = g.t + dt
  if g.auto then inp = autopilot(g) end
  inp = inp or {}
  local play = g.phase == 'play'
  if not play then g.endT = (g.endT or 0) + dt end

  if g.flapT then g.flapT = g.flapT + dt; if g.flapT > 1.3 then g.flapT = nil end end
  local target = g.L.speed + (g.flapT and 9 or 0)
  if g.phase == 'down' then target = g.L.speed * 0.5 end
  g.speed = g.speed + (target - g.speed) * min(1, dt * 3)
  cam.z = cam.z + g.speed * dt

  local sx = (inp.right and 1 or 0) - (inp.left and 1 or 0)
  if not play then sx = 0 end
  g.vx = g.vx + (sx * 9 - g.vx) * min(1, dt * 5)
  cam.x = clamp(cam.x + g.vx * dt, -13, 10.5)
  local sy = (inp.up and 1 or 0) - (inp.down and 1 or 0)
  if g.invert then sy = -sy end
  if play then g.cruiseY = clamp(g.cruiseY + sy * 4 * dt, 3.5, 10) end

  local amt = 0
  if g.swoopT then
    g.swoopT = g.swoopT + dt
    amt = sin(pi * min(1, g.swoopT / 1.0))
    if g.swoopT >= 1 then g.swoopT = nil end
  end
  g.swoopAmt = amt
  cam.y = g.cruiseY - (g.cruiseY - 1.5) * amt
  if g.phase == 'down' then g.cruiseY = max(1.4, g.cruiseY - dt * 2) end
  cam.hz = HZ0 - 60 * amt
  local roll = -g.vx * 0.012
  if g.rollT then
    g.rollT = g.rollT + dt
    local k = min(1, g.rollT / 0.6)
    roll = roll + g.rollDir * 2 * pi * (k * k * (3 - 2 * k))
    cam.x = clamp(cam.x + g.rollDir * 6 * dt, -13, 10.5)
    if g.rollT >= 0.6 then g.rollT = nil end
  end
  if g.phase == 'down' then roll = roll + sin(g.endT * 5) * 0.25 end
  cam.roll = roll
  g.flap = (g.flap + dt * (g.flapT and 3.5 or 1.1)) % 1
  g.hurtT = max(0, g.hurtT - dt); g.shake = max(0, g.shake - dt)
  g.dropCD = max(0, g.dropCD - dt); g.squawkCD = max(0, g.squawkCD - dt); g.flapCD = max(0, g.flapCD - dt)
  if g.squawkT then g.squawkT = g.squawkT + dt; if g.squawkT > 0.6 then g.squawkT = nil end end
  if g.emptyT then g.emptyT = g.emptyT - dt; if g.emptyT <= 0 then g.emptyT = nil end end

  if play and not g.demo then
    if inp.dropHeld and g.dropCD <= 0 then
      if g.payload > 0 then
        g.payload = g.payload - 1
        g.drops[#g.drops + 1] = { kind = 'drop', x = cam.x, y = cam.y - 0.5, z = cam.z + 1.6, vy = -1, vz = g.speed + THROW }
        g.dropCD = 0.22
        g.sfx('plop')
      else
        g.dropCD = 0.6; g.emptyT = 1.2; g.sfx('warn'); radio(g, 'empty')
      end
    end
    if inp.swoop and not g.swoopT and not g.rollT then g.swoopT = 0; g.sfx('whoosh') end
    if inp.squawk and g.squawkCD <= 0 then squawk(g) end
    if inp.flap and not g.flapT and g.flapCD <= 0 then g.flapT = 0; g.flapCD = 1.6; g.hunger = g.hunger - 3; g.sfx('flap') end
    if (inp.rollL or inp.rollR) and not g.rollT and not g.swoopT then g.rollT = 0; g.rollDir = inp.rollL and -1 or 1; g.sfx('whoosh', 1.5) end
    g.hunger = g.hunger - g.L.hunger * dt
    if g.hunger < 25 then radio(g, 'hungry') end
    if g.payload <= 1 then radio(g, 'food') end
    if g.hunger <= 0 then g.hunger = 0; g.phase = 'down'; g.endT = 0; g.downWhy = 'hunger'; g.sfx('sad'); radio(g, 'downH') end
    if g.t > 0.6 then radio(g, 'start') end
    if g.t > 6 and g.hits == 0 then radio(g, 'aim') end
    if cam.z >= g.L.len then g.phase = 'done'; g.endT = 0; g.sfx('fanfare'); radio(g, 'end') end
  end

  -- drops in flight
  for i = #g.drops, 1, -1 do
    local d = g.drops[i]
    d.vy = d.vy - GRAV * dt; d.y = d.y + d.vy * dt; d.z = d.z + d.vz * dt
    if checkHit(g, d) then table.remove(g.drops, i)
    elseif d.y <= 0 then miss(g, d); table.remove(g.drops, i) end
  end

  -- people
  for _, p in ipairs(g.people) do
    local d = p.z - cam.z
    if d > -12 and d < 220 then
      p.st = (p.st or 0) + dt
      if p.sayT then p.sayT = p.sayT - dt end
      if p.state == 'walk' then
        if p.moving then p.z = p.z + p.vz * dt; p.phase = p.phase + dt * abs(p.vz) * 4.5 end
      elseif p.state == 'hit' and p.st > 3.0 then p.state = 'walk'
      elseif p.state == 'look' and p.st > 1.0 then p.state = 'walk'
      elseif p.state == 'swing' and p.st > 0.9 then p.state = 'walk'; p.swung = nil end
      if p.typ == 'umb' and not p.umbOpen and p.umbT then p.umbT = p.umbT - dt; if p.umbT <= 0 then p.umbOpen = true end end
      if play and not g.demo then
        if d > 0 and d < 30 then
          if p.typ == 'umb' and p.umbOpen then radio(g, 'umb') end
          if p.typ == 'kid' then radio(g, 'kids') end
          if p.typ == 'paper' then radio(g, 'paper') end
        end
        if p.typ == 'suit' and d > 0 and d < 45 then radio(g, 'suit') end
        if p.typ == 'vip' and d > 0 and d < 50 then radio(g, 'vip') end
        if p.typ == 'thrower' then
          if p.state == 'walk' or p.state == 'look' then
            p.cd = (p.cd or 0) - dt
            if d > 12 and d < 36 and abs(p.x - cam.x) < 10 and p.cd <= 0 and (p.shots or 0) < g.L.shots then
              p.state = 'windup'; p.st = 0; p.say = '!'; p.sayT = 0.6
              radio(g, 'throw')
            end
          elseif p.state == 'windup' and p.st > 0.55 then
            local L = g.L
            local T = L.throwT
            local y0 = p.h + 0.3
            local tx = cam.x + g.vx * T * 0.5 + (g.rng:random() * 2 - 1) * L.err
            local ty = clamp(cam.y + (g.rng:random() * 2 - 1) * L.err * 0.6, 1.2, 12)
            local tz = cam.z + g.speed * T
            g.throws[#g.throws + 1] = { kind = 'throw', what = p.throwKind, x = p.x, y = y0, z = p.z, t = 0, rot = 0,
              vx = (tx - p.x) / T, vz = (tz - p.z) / T, vy = (ty - y0) / T + 0.5 * 9 * T, spin = (g.rng:random() < 0.5 and -1 or 1) * 9 }
            p.state = 'thrown'; p.st = 0; p.shots = (p.shots or 0) + 1; p.cd = L.cd
            g.sfx('whoosh', 1.7, 0.6)
          elseif p.state == 'thrown' and p.st > 0.5 then p.state = 'walk' end
        end
        if p.typ == 'bride' and d > 0 and d < 55 then radio(g, 'wedding') end
        if p.typ == 'paper' and p.state == 'walk' and d > 0 and d < 6 and abs(p.x - cam.x) < 2.6 and cam.y < 4.5 then
          p.state = 'swing'; p.st = 0; p.say = 'COME HERE!'; p.sayT = 1
        end
        if p.typ == 'paper' and p.state == 'swing' and not p.swung and d < 2.2 and d > -0.5 and abs(p.x - cam.x) < 2.2 and cam.y < 3.8 then
          p.swung = true
          if hurt(g, 'paper') then pop(g, p.x, 2.5, p.z + 2, 'THWACK!', nil, { 1, 0.4, 0.35 }, 22) end
        end
        if p.typ == 'kid' and p.state == 'walk' and d > 7 and d < 26 and abs(p.x - cam.x) < 7 then
          p.fireCD = (p.fireCD or 0.5) - dt
          if p.fireCD <= 0 and (p.shots or 0) < 3 then
            local T = 0.85
            local tx, ty, tz = cam.x, cam.y, cam.z + g.speed * T
            g.jets[#g.jets + 1] = { kind = 'jet', x = p.x, y = 1.0, z = p.z, vx = (tx - p.x) / T, vy = (ty - 1.0) / T, vz = (tz - p.z) / T, t = 0 }
            p.fireCD = 1.5; p.shots = (p.shots or 0) + 1
            g.sfx('squirt', 1.3, 0.6)
          end
        end
      end
    end
  end

  -- water
  for i = #g.jets, 1, -1 do
    local j = g.jets[i]
    j.t = j.t + dt
    j.x = j.x + j.vx * dt; j.y = j.y + j.vy * dt; j.z = j.z + j.vz * dt
    if j.z <= cam.z + 0.4 then
      if abs(j.x - cam.x) < 0.9 and abs(j.y - cam.y) < 1.0 then
        if hurt(g, 'water') then pop(g, cam.x, cam.y - 1, cam.z + 3, 'SOAKED!', nil, { 0.5, 0.85, 1 }, 22)
        elseif g.rollT then pop(g, cam.x, cam.y - 1, cam.z + 4, 'DODGED!', nil, { 1, 1, 1 }, 15) end
      end
      table.remove(g.jets, i)
    elseif j.t > 1.6 then table.remove(g.jets, i) end
  end

  -- things thrown at the gull
  for i = #g.throws, 1, -1 do
    local o = g.throws[i]
    o.t = o.t + dt
    o.vy = o.vy - 9 * dt
    o.x = o.x + o.vx * dt; o.y = o.y + o.vy * dt; o.z = o.z + o.vz * dt; o.rot = o.rot + o.spin * dt
    if o.z <= cam.z + 0.4 then
      if abs(o.x - cam.x) < 0.85 and abs(o.y - cam.y) < 0.95 then
        if hurt(g, 'throw') then pop(g, cam.x, cam.y - 1, cam.z + 3, 'BONK!', nil, { 1, 0.45, 0.3 }, 22)
        elseif g.rollT then pop(g, cam.x, cam.y - 1, cam.z + 4, 'DODGED!', nil, { 1, 1, 1 }, 15) end
      end
      table.remove(g.throws, i)
    elseif o.t > 2.5 or o.y < -1 then table.remove(g.throws, i) end
  end

  -- grabbing food on a swoop
  if play and cam.y < 2.8 then
    for _, it in ipairs(g.items) do
      local d = it.z - cam.z
      if not it.gone and abs(it.x - cam.x) < 1.5 and d > -0.6 and d < 2.2 and (it.y or 0) < cam.y then
        it.gone = true; eat(g, it.food, it.x, it.z + 3)
      end
    end
    for _, p in ipairs(g.people) do
      local d = p.z - cam.z
      if p.food and abs(p.x - cam.x) < 1.3 and d > -0.5 and d < 2.4 then
        eat(g, p.food, p.x, p.z + 3); p.food = nil
        g.score = g.score + 50
        p.state = 'look'; p.st = 0; p.say = p.typ == 'cone' and 'MY 99!' or 'MY CHIPS!'; p.sayT = 1.6
        pop(g, p.x, 2.6, p.z + 3, 'SNATCHED!', '+50', { 1, 0.84, 0.25 }, 15)
      end
    end
  end

  -- the drop zone ring and what's in it
  local y0 = cam.y - 0.5
  local tf = y0 > 1.7 and sqrt(2 * (y0 - 1.7) / GRAV) or 0.1
  g.ret = g.ret or {}
  g.ret.x, g.ret.z = cam.x, cam.z + 1.6 + (g.speed + THROW) * tf
  g.ret.lock = false; g.lock = nil
  if play and not g.demo then
    local bestD
    for _, p in ipairs(g.people) do
      local pz = p.z + ((p.state == 'walk' and p.moving) and p.vz * tf or 0)
      local dz, dx = pz - g.ret.z, p.x - g.ret.x
      local dd = dx * dx + dz * dz
      if dd < 0.55 * 0.55 and (not bestD or dd < bestD) then bestD = dd; g.lock = p end
    end
    g.ret.lock = g.lock ~= nil
  end

  for i = #g.pops, 1, -1 do local p = g.pops[i]; p.t = p.t - dt; if p.t <= 0 then table.remove(g.pops, i) end end
  if g.radio[1] then g.radio[1].t = g.radio[1].t - dt; if g.radio[1].t <= 0 then table.remove(g.radio, 1) end end
  if not play and g.endT > 3.5 then g.finished = true end
end

---------------------------------------------------------------- drawing
function St.draw(g, VW, t)
  cam.cx = VW / 2
  lg.push()
  local sk = g.shake > 0 and g.shake * 14 or 0
  lg.translate(VW / 2 + (love.math.random() - 0.5) * sk, 240 + (love.math.random() - 0.5) * sk)
  lg.rotate(cam.roll)
  lg.translate(-VW / 2, -240)
  W.draw(g, t)
  lg.pop()
  if g.flapT then W.speedLines(t, 1 - g.flapT / 1.3) end
  if g.swoopT then W.speedLines(t * 1.5, g.swoopAmt * 0.8) end
  if g.squawkT then
    local a = 1 - g.squawkT / 0.6
    lg.setColor(1, 1, 1, 0.5 * a); lg.setLineWidth(3)
    for k = 0, 2 do lg.arc('line', 'open', VW / 2, 470, 60 + k * 30 + g.squawkT * 160, -pi * 0.85, -pi * 0.15) end
  end
  W.drawGull(g.flap, VW)
  if g.hurtT > 0 then
    if g.hurtWhy == 'water' then lg.setColor(0.4, 0.7, 1, g.hurtT * 0.25) else lg.setColor(1, 0.15, 0.1, g.hurtT * 0.22) end
    lg.rectangle('fill', 0, 0, VW, 480)
  end
end

local function bar(x, y, w, h, frac, c)
  lg.setColor(1, 1, 1, 0.14); lg.rectangle('fill', x, y, w, h, h / 2)
  if frac > 0.02 then
    lg.setColor(c); lg.rectangle('fill', x, y, max(h, w * frac), h, h / 2)
    lg.setColor(1, 1, 1, 0.35); lg.rectangle('fill', x + 3, y + 1.5, max(1, w * frac - 6), 2, 1)
  end
end
local function feather(x, y, a)
  lg.push(); lg.translate(x, y); lg.rotate(-0.5)
  lg.setColor(1, 1, 1, a); lg.ellipse('fill', 0, 0, 3.4, 8)
  lg.setColor(0.6, 0.66, 0.72, a); lg.setLineWidth(1); lg.line(0, -7, 0, 10)
  lg.pop()
end

local function fmt(n)
  local s = tostring(floor(n))
  local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse()
  if out:sub(1, 1) == ',' then out = out:sub(2) end
  return out
end
St.fmt = fmt

function St.drawHUD(g, VW, t)
  if g.demo then return end
  U.panel(12, 12, 150, 56)
  U.text('SCORE', 11, 24, 19, { 0.62, 0.83, 0.97 })
  U.text(fmt(g.score), 28, 23, 30, { 1, 1, 1 })
  if g.combo >= 2 then
    local m = min(5, g.combo)
    lg.setColor(hex('ff7a2f')); lg.rectangle('fill', 170, 22, 86, 30, 15, 15, 16)
    lg.setColor(1, 1, 1, 0.22); lg.rectangle('fill', 174, 24, 78, 11, 6)
    U.text('x' .. m, 17, 182, 27, { 1, 1, 1 })
    U.text('COMBO', 11, 208, 31, { 1, 0.95, 0.85 })
  end
  -- stage + distance
  local stage = 'STAGE ' .. g.level .. '  \194\183  ' .. g.L.name
  local sw = U.f[11]:getWidth(stage) + 26
  local sx = VW / 2 - sw / 2 + 30
  U.panel(sx, 14, sw, 30)
  U.text(stage, 11, sx + 13, 19, { 1, 1, 1 })
  local prog = clamp(cam.z / g.L.len, 0, 1)
  lg.setColor(1, 1, 1, 0.18); lg.rectangle('fill', sx + 13, 36, sw - 26, 3, 1.5)
  lg.setColor(hex('ffd166')); lg.rectangle('fill', sx + 13, 36, (sw - 26) * prog, 3, 1.5)
  -- bars
  local rx = VW - 178
  U.panel(rx, 12, 166, 98)
  local hungry = g.hunger < 25
  local blink = hungry and (t * 3 % 1 < 0.5)
  U.text(hungry and 'HUNGRY!' or 'HUNGER', 11, rx + 34, 19, blink and { 1, 0.4, 0.35 } or { 1, 0.85, 0.65 })
  bar(rx + 34, 34, 120, 10, g.hunger / 100, hungry and hex('e63946') or hex('ff9f1c'))
  U.text('PAYLOAD', 11, rx + 34, 50, g.emptyT and { 1, 0.4, 0.35 } or { 0.9, 0.94, 1 })
  for k = 0, 9 do
    local on = k < g.payload
    lg.setColor(1, 1, 1, on and 0.95 or 0.14)
    lg.rectangle('fill', rx + 34 + k * 12.2, 65, 10, 10, 3)
  end
  lg.setColor(hex('d62828')); lg.polygon('fill', rx + 8, 34, rx + 24, 34, rx + 21, 46, rx + 11, 46)
  lg.setColor(hex('ffd166'))
  for i = 0, 3 do lg.rectangle('fill', rx + 10 + i * 3.6, 26 + (i % 2) * 2, 2.4, 9) end
  lg.setColor(1, 1, 1); lg.circle('fill', rx + 16, 72, 5.5); lg.polygon('fill', rx + 11, 70, rx + 21, 70, rx + 16, 60)
  for i = 0, 3 do feather(rx + 38 + i * 13, 93, i < g.feathers and 1 or 0.2) end
  lg.setColor(1, 0.35, 0.3); lg.setLineWidth(2); lg.circle('line', rx + 110, 93, 6); lg.circle('fill', rx + 110, 93, 2)
  U.text(tostring(g.hits), 13, rx + 121, 85, { 1, 1, 1 })
  -- the radio
  local m = g.radio[1]
  if m then
    local lines = U.wrap(m.text, 13, 206)
    local h = max(62, 30 + #lines * 16)
    local a = min(1, m.t * 3, (4.2 - m.t) * 5)
    lg.push(); lg.translate(-(1 - a) * 30, 0)
    U.panel(12, 76, 284, h, 0.66 * a)
    U.gannet(44, 76 + h / 2 + 1, 22)
    U.text('SGT GANNET', 11, 76, 84, { 1, 0.72, 0.2 }, nil, a)
    lg.setColor(1, 0.3, 0.3, a * (t * 2 % 1 < 0.6 and 1 or 0.3)); lg.circle('fill', 162, 91, 3)
    U.text('RADIO', 11, 169, 84, { 1, 0.6, 0.6 }, nil, a)
    for k, l in ipairs(lines) do U.text(l, 13, 76, 84 + k * 16, { 1, 1, 1 }, nil, a) end
    lg.pop()
  end
  -- banners
  if g.t < 2.8 and g.phase == 'play' then
    local a = min(1, (2.8 - g.t) * 2)
    U.otext('STAGE ' .. g.level, 22, VW / 2, 176, { 1, 0.84, 0.25 }, 'center', a)
    U.otext(g.L.name, 40, VW / 2, 200, { 1, 1, 1 }, 'center', a, 3)
  end
  if g.t < 14 and g.phase == 'play' then
    local a = min(1, (14 - g.t))
    local hint = St.touch and 'Left thumb: steer and climb.   Right thumb: drop, swoop, squawk, flap, roll.'
      or 'A drop    B swoop    Y squawk    X flap    L1 / R1 roll'
    local w = U.f[11]:getWidth(hint) + 24
    lg.setColor(0.03, 0.09, 0.16, 0.6 * a); lg.rectangle('fill', VW / 2 - w / 2, 366, w, 22, 11, 11, 12)
    U.text(hint, 11, VW / 2, 370, { 1, 1, 1 }, 'center', a)
  end
  if g.emptyT then U.otext('EMPTY! EAT SOMETHING', 17, VW / 2, 330, { 1, 0.45, 0.4 }, 'center', min(1, g.emptyT * 2)) end
  if g.phase == 'done' then
    local a = min(1, g.endT * 2)
    U.otext(g.L.done, 40, VW / 2, 190, { 1, 0.84, 0.25 }, 'center', a, 3)
  elseif g.phase == 'down' then
    local a = min(1, g.endT * 2)
    U.otext('GULL DOWN', 40, VW / 2, 190, { 1, 0.4, 0.35 }, 'center', a, 3)
    U.otext(g.downWhy == 'hunger' and 'Fainted from hunger.' or 'Out of feathers.', 17, VW / 2, 240, { 1, 1, 1 }, 'center', a)
  end
end

function St.medal(score, level)
  local m = 0
  for k, v in ipairs(St.LEVELS[level or 1].medals) do if score >= v then m = k end end
  return m
end

return St
