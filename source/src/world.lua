-- Ballyspray seafront seen through the gull's eyes. Fake 3D: every point (X across, Y up, Z ahead, metres)
-- is projected with the camera (the gull). X: sea < -13, beach -13..-8.6, prom -8..0.2, cycle lane 0.2..3,
-- road 3.5..11, pavement 11..14, houses face the prom at X = 14.
local U = require 'ui'
local W = {}
local lg = love.graphics
local pi, min, max, floor, sin, cos, abs = math.pi, math.min, math.max, math.floor, math.sin, math.cos, math.abs
local hex = U.hex

local F = 330
W.F = F
local cam = { x = 0, y = 7, z = 0, roll = 0, hz = 170, cx = 320 }
W.cam = cam
local function P(X, Y, Z) local d = Z - cam.z; return cam.cx + (X - cam.x) * F / d, cam.hz + (cam.y - Y) * F / d end
W.P = P

-- The look of each stage. Colours are drawn first, then the whole view is tinted (evening / night)
-- and lamps + lit windows are added on top as glows.
W.THEMES = {
  prom = { sky1 = '3a86d6', sky2 = 'd4ebf6', haze = 'd4ebf6', sun = { 112, 60 }, sunC = { 1, 0.99, 0.93 }, glow = { 1, 0.9, 0.68 }, clouds = 0.95 },
  harbour = { sky1 = '4f8fcc', sky2 = 'dde9ee', haze = 'dde9ee', sun = { 90, 46 }, sunC = { 1, 0.99, 0.95 }, glow = { 1, 0.95, 0.85 }, clouds = 1,
    seaN = '145a86', seaF = '86b8cc', sand1 = 'a29d94', sand2 = 'd0ccc4', wet1 = '6f6a62', wet2 = 'b8b4ac',
    lane1 = '9a948a', lane2 = 'd2cec6', noLane = true, cranes = true, crates = true },
  fair = { sky1 = '3f7fcf', sky2 = 'f6e3b4', haze = 'f2e2c0', sun = { 160, 96 }, sunC = { 1, 0.95, 0.78 }, glow = { 1, 0.78, 0.45 }, clouds = 0.9,
    wheel = true, tint = { 1, 0.97, 0.9 } },
  match = { sky1 = '3a5aa8', sky2 = 'ffc890', haze = 'f3c39a', sun = { 150, 150 }, sunC = { 1, 0.85, 0.6 }, glow = { 1, 0.62, 0.35 }, clouds = 0.75,
    floods = true, tint = { 1, 0.84, 0.74 }, lampsOn = true },
  night = { sky1 = '1a2a60', sky2 = '5a6fa8', haze = '5a6fa8', sun = { 430, 84 }, sunC = { 1, 1, 0.95 }, glow = { 0.65, 0.75, 1 }, clouds = 0.35,
    moon = true, stars = true, tint = { 0.38, 0.43, 0.68 }, lampsOn = true, night = true, glare = 0.3 },
}
local T = W.THEMES.prom
local HAZE = hex('d4ebf6')
local glows = {}
local function th(key, def) return hex(T[key] or def) end
local function fogk(Z)
  local k = (Z - cam.z - 16) / 240
  if k < 0 then return 0 elseif k > 0.8 then return 0.8 end
  return k
end
local function mix(c, Z)
  local k = fogk(Z)
  return { c[1] + (HAZE[1] - c[1]) * k, c[2] + (HAZE[2] - c[2]) * k, c[3] + (HAZE[3] - c[3]) * k, c[4] or 1 }
end
local function col(c, Z, a)
  local k = fogk(Z)
  lg.setColor(c[1] + (HAZE[1] - c[1]) * k, c[2] + (HAZE[2] - c[2]) * k, c[3] + (HAZE[3] - c[3]) * k, a or c[4] or 1)
end
local function dk(c, k) k = k or 0.8; return { c[1] * k, c[2] * k, c[3] * k, c[4] or 1 } end
local function lt(c, k) k = k or 0.3; return { c[1] + (1 - c[1]) * k, c[2] + (1 - c[2]) * k, c[3] + (1 - c[3]) * k, c[4] or 1 } end
W.dk, W.lt = dk, lt

local function vtx(x, y, c) return { x, y, 0, 0, c[1], c[2], c[3], c[4] or 1 } end
local pool, poolN = {}, 0
local function quad(p, c1, c2, c3, c4)
  poolN = poolN + 1
  local v = { vtx(p[1], p[2], c1), vtx(p[3], p[4], c2), vtx(p[5], p[6], c3), vtx(p[7], p[8], c4) }
  local m = pool[poolN]
  if m then m:setVertices(v) else m = lg.newMesh(v, 'fan', 'dynamic'); pool[poolN] = m end
  lg.setColor(1, 1, 1, 1); lg.draw(m)
end
local function vgradOnce(x, y, w, h, c1, c2)
  local m = lg.newMesh({ vtx(x, y, c1), vtx(x + w, y, c1), vtx(x + w, y + h, c2), vtx(x, y + h, c2) }, 'fan', 'static')
  lg.setColor(1, 1, 1, 1); lg.draw(m)
end
local function poly(pts)
  local ok, tris = pcall(love.math.triangulate, pts)
  if ok then for _, t in ipairs(tris) do lg.polygon('fill', t) end end
end

local function ground(x1, x2, cn, cf, zA, zB)
  zA = zA or cam.z + 0.9; zB = zB or cam.z + 4000
  local ax, ay = P(x1, 0, zA); local bx, by = P(x2, 0, zA)
  local cx, cy = P(x2, 0, zB); local dx, dy = P(x1, 0, zB)
  quad({ ax, ay, bx, by, cx, cy, dx, dy }, cn, cn, cf, cf)
end
local function wallX(X, y0, y1, z0, z1)
  local a, b = P(X, y0, z0); local c, d = P(X, y0, z1); local e, f = P(X, y1, z1); local g, h = P(X, y1, z0)
  return { a, b, c, d, e, f, g, h }
end
local function faceZ(x0, x1, y0, y1, Z)
  local a, b = P(x0, y0, Z); local c, d = P(x1, y1, Z)
  return a, d, c - a, b - d
end
local function flatY(Y, x0, x1, z0, z1)
  local a, b = P(x0, Y, z0); local c, d = P(x1, Y, z0); local e, f = P(x1, Y, z1); local g, h = P(x0, Y, z1)
  return { a, b, c, d, e, f, g, h }
end
local function q3(...)
  local p = {}
  for _, v in ipairs({ ... }) do local x, y = P(v[1], v[2], v[3]); p[#p + 1] = x; p[#p + 1] = y end
  return p
end
local function hash(a, b) local v = sin(a * 127.1 + b * 311.7) * 43758.5453; return v - floor(v) end

---------------------------------------------------------------- baked pictures (made once)
local skyC, wingC, headC
local function newCanvas(w, h)
  if love.system.getOS() == 'Web' then return lg.newCanvas(w, h) end   -- browsers: no smoothing on canvases
  local ok, c = pcall(lg.newCanvas, w, h, { msaa = 4 })
  if not ok or not c then c = lg.newCanvas(w, h) end
  return c
end

local function cloud(x, base, sc, a)
  local parts = { { -42, -8, 20 }, { -18, -20, 27 }, { 12, -16, 24 }, { 38, -7, 17 }, { -2, -6, 24 } }
  lg.stencil(function() lg.rectangle('fill', x - 140 * sc, base - 200, 280 * sc, 200) end, 'replace', 1)
  lg.setStencilTest('greater', 0)
  lg.setColor(0.78, 0.86, 0.94, a)
  for _, p in ipairs(parts) do lg.circle('fill', x + p[1] * sc, base + p[2] * sc, p[3] * sc) end
  lg.setColor(1, 1, 1, a)
  for _, p in ipairs(parts) do lg.circle('fill', x + p[1] * sc - 1, base + p[2] * sc - 4 * sc, p[3] * sc) end
  lg.setStencilTest()
end

W.SUNX, W.SUNY = 112, 60
local function bakeSky()
  W.SUNX, W.SUNY = T.sun[1], T.sun[2]
  skyC = skyC or newCanvas(1100, 430)
  lg.push('all')
  lg.setCanvas({ skyC, stencil = true }); lg.clear(0, 0, 0, 0)
  lg.origin(); lg.translate(230, 240)
  vgradOnce(-230, -240, 1100, 414, hex(T.sky1), hex(T.sky2))
  if T.stars then
    local r = love.math.newRandomGenerator(9)
    for _ = 1, 140 do
      lg.setColor(1, 1, 1, 0.4 + r:random() * 0.6)
      lg.circle('fill', -230 + r:random() * 1100, -240 + r:random() * 360, 0.6 + r:random() * 1.1)
    end
  end
  local g = T.glow
  lg.setBlendMode('add')
  for i = 1, 16 do lg.setColor(g[1], g[2], g[3], T.moon and 0.012 or 0.026); lg.circle('fill', W.SUNX, W.SUNY, 16 + i * 13) end
  lg.setBlendMode('alpha')
  lg.setColor(T.sunC); lg.circle('fill', W.SUNX, W.SUNY, T.moon and 15 or 19)
  local ca = T.clouds
  cloud(470, 84, 1.25, 0.96 * ca); cloud(300, 114, 0.72, 0.92 * ca); cloud(640, 128, 0.6, 0.88 * ca); cloud(28, 124, 0.62, 0.9 * ca)
  cloud(-140, 70, 1.0, 0.9 * ca); cloud(800, 64, 1.1, 0.92 * ca)
  -- things on the skyline behind the town
  if T.wheel then
    local wx, wy, wr = 610, 96, 52
    lg.setColor(0.55, 0.6, 0.72); lg.setLineWidth(2)
    lg.line(wx - 26, 168, wx, wy); lg.line(wx + 26, 168, wx, wy)
    lg.circle('line', wx, wy, wr); lg.setLineWidth(1)
    for k = 0, 11 do
      local a = k * pi / 6
      lg.line(wx, wy, wx + cos(a) * wr, wy + sin(a) * wr)
      lg.setColor(({ { 0.95, 0.4, 0.5 }, { 1, 0.8, 0.3 }, { 0.4, 0.7, 1 } })[k % 3 + 1])
      lg.rectangle('fill', wx + cos(a) * wr - 4, wy + sin(a) * wr, 8, 7, 2)
      lg.setColor(0.55, 0.6, 0.72)
    end
  end
  if T.floods then
    for _, fx in ipairs({ 520, 700 }) do
      lg.setColor(0.35, 0.38, 0.45); lg.setLineWidth(3); lg.line(fx, 170, fx, 70)
      lg.rectangle('fill', fx - 16, 58, 32, 14, 2)
      lg.setColor(1, 1, 0.9); for k = 0, 3 do lg.rectangle('fill', fx - 13 + k * 7, 61, 5, 8) end
      lg.setBlendMode('add'); lg.setColor(1, 1, 0.8, 0.18); lg.circle('fill', fx, 65, 40); lg.setBlendMode('alpha')
    end
    lg.setColor(0.45, 0.48, 0.55); lg.polygon('fill', 540, 171, 560, 150, 680, 150, 700, 171)
  end
  if T.cranes then
    lg.setColor(0.85, 0.45, 0.25)
    for _, cx in ipairs({ 560, 690 }) do
      lg.setLineWidth(3); lg.line(cx, 170, cx, 92); lg.line(cx - 30, 96, cx + 70, 96); lg.setLineWidth(1)
      lg.line(cx + 60, 96, cx + 60, 130); lg.rectangle('fill', cx - 6, 100, 12, 10)
    end
  end
  -- headland + lighthouse (over the sea, left) and hills behind the town (right)
  lg.setColor(hex('8fb2c6'))
  poly({ -230, 171, -230, 150, -160, 146, -90, 152, -40, 148, 0, 146, 28, 141, 64, 134, 96, 137, 130, 146, 170, 155, 210, 162, 250, 171 })
  local lx, ly = 72, 135
  lg.setColor(0.95, 0.97, 0.98); lg.polygon('fill', lx - 3, ly, lx + 3, ly, lx + 2, ly - 18, lx - 2, ly - 18)
  lg.setColor(0.85, 0.42, 0.42); lg.rectangle('fill', lx - 2.6, ly - 8, 5.2, 3); lg.rectangle('fill', lx - 2.2, ly - 15, 4.4, 2.5)
  lg.setColor(0.3, 0.36, 0.42); lg.rectangle('fill', lx - 2.6, ly - 22, 5.2, 3.5)
  lg.setColor(1, 0.96, 0.75); lg.rectangle('fill', lx - 1.6, ly - 21.2, 3.2, 2)
  lg.setColor(hex('b3cfc8')); poly({ 330, 171, 360, 159, 410, 150, 470, 145, 530, 149, 590, 140, 660, 137, 740, 144, 870, 138, 870, 171 })
  lg.setColor(hex('97bfa8')); poly({ 360, 171, 420, 162, 500, 156, 560, 160, 640, 151, 720, 156, 870, 150, 870, 171 })
  lg.pop()
end

local function wingShape()
  poly({ 238, 480, 200, 452, 160, 425, 120, 401, 80, 380, 40, 362, 0, 348, -30, 340, -30, 480 })
end
local function bakeWing()
  wingC = newCanvas(300, 170)
  lg.push('all')
  lg.setCanvas({ wingC, stencil = true }); lg.clear(0, 0, 0, 0)
  lg.origin(); lg.translate(40, -320)
  lg.stencil(wingShape, 'replace', 1); lg.setStencilTest('greater', 0)
  vgradOnce(-40, 340, 300, 140, hex('e6ecf0'), hex('a7b4bf'))
  lg.setColor(0.42, 0.48, 0.55, 0.35); lg.setLineWidth(1.5)
  lg.line(250, 480, 214, 458, 172, 436, 130, 414, 88, 395, 46, 380, 0, 368, -30, 360)
  lg.line(230, 480, 190, 462, 150, 446, 110, 428, 70, 412, 30, 398, 0, 390, -30, 382)
  for i = 0, 9 do local t = i / 9; local x, y = 214 - t * 200, 458 - t * 82; lg.line(x, y, x - 6, y + 9) end
  lg.setColor(0.13, 0.14, 0.17)
  poly({ -30, 334, 0, 340, 34, 352, 22, 372, 46, 384, 30, 406, 52, 420, 30, 444, 0, 456, -30, 462 })
  lg.setColor(0.97, 0.97, 0.97)
  lg.ellipse('fill', 12, 386, 6, 4.5); lg.ellipse('fill', 14, 428, 7, 5)
  lg.setStencilTest()
  lg.setColor(1, 1, 1, 0.9); lg.setLineWidth(3)
  lg.line(236, 478, 199, 451, 159, 424, 119, 400, 79, 379, 50, 366)
  lg.setColor(1, 1, 1, 0.5); lg.setLineWidth(1.5); lg.line(50, 366, -30, 340)
  lg.pop()
end

local function bakeHead()
  headC = newCanvas(180, 80)
  lg.push('all')
  lg.setCanvas({ headC, stencil = true }); lg.clear(0, 0, 0, 0)
  lg.origin(); lg.translate(-230, -400)
  lg.stencil(function() lg.ellipse('fill', 320, 508, 76, 52) end, 'replace', 1); lg.setStencilTest('greater', 0)
  vgradOnce(240, 454, 160, 60, hex('ffffff'), hex('d5dce2'))
  lg.setColor(0.8, 0.84, 0.88, 0.7); lg.setLineWidth(1)
  lg.arc('line', 'open', 320, 520, 48, -pi * 0.85, -pi * 0.6)
  lg.arc('line', 'open', 320, 520, 48, -pi * 0.4, -pi * 0.15)
  lg.setStencilTest()
  lg.setColor(1, 0.83, 0.3); poly({ 296, 480, 320, 480, 320, 413, 315, 417, 308, 434, 301, 455 })
  lg.setColor(0.91, 0.66, 0.08); poly({ 320, 480, 344, 480, 339, 455, 332, 434, 325, 417, 320, 413 })
  lg.setColor(1, 0.95, 0.66); lg.setLineWidth(2); lg.line(319, 476, 319, 419)
  lg.setColor(0.82, 0.53, 0.05); lg.polygon('fill', 314, 421, 326, 421, 320, 411)
  lg.setColor(0.88, 0.27, 0.17); lg.ellipse('fill', 334, 441, 4, 6.5)
  lg.setColor(0.45, 0.3, 0.05); lg.setLineWidth(1.5)
  lg.line(309, 458, 312, 450); lg.line(331, 458, 328, 450)
  lg.pop()
end

function W.load()
  bakeSky(); bakeWing(); bakeHead()
end

-- switch the look (stage start). name: a key of W.THEMES
function W.setTheme(name)
  local t = W.THEMES[name] or W.THEMES.prom
  if t == T and skyC then return end
  T = t
  HAZE = hex(T.haze)
  W.theme = T
  if skyC then bakeSky() end
end

---------------------------------------------------------------- sky, sea, ground
local function sky()
  lg.setColor(1, 1, 1, 1)
  lg.draw(skyC, cam.cx - 320 - 230 - cam.x * 1.2, cam.hz - 410)
  -- top-up above the baked sky (only seen when rolling)
  lg.setColor(hex(T.sky1)); lg.rectangle('fill', -400, cam.hz - 410 - 600, 2000, 601)
end

local function sea(t)
  ground(-3000, -13, th('seaN', '17639e'), th('seaF', '8cc8e2'))
  local k0, k1 = floor((cam.z + 2) / 4), floor((cam.z + 360) / 4)
  for k = k0, k1 do
    local Z = k * 4
    local d = Z - cam.z
    if d > 2 then
      local s = F / d
      local step = max(3, d * 0.12)
      local left = cam.x - (cam.cx + 40) * d / F
      local a = 0.42 * (1 - fogk(Z))
      lg.setColor(0.86, 0.95, 1, a)
      lg.setLineWidth(max(1, 0.11 * s))
      local j = 0
      local X = -14.5 - hash(k, 0) * step
      while X > left and j < 40 do
        j = j + 1
        local w = 1.0 + hash(k, j) * 2.6
        local Xs = X + sin(t * 0.8 + k + j) * 0.6
        local x1, y1 = P(Xs, 0, Z); local x2 = P(Xs + w, 0, Z)
        if Xs + w < -13.4 then lg.line(x1, y1, (x1 + x2) / 2, y1 - 0.06 * s, x2, y1) end
        X = X - step * (0.7 + hash(j, k) * 0.8)
      end
    end
  end
  -- sun glitter on the water
  local rng = love.math.newRandomGenerator(floor(t * 9) + 1)
  local sx = W.SUNX + (cam.cx - 320) - cam.x * 1.2
  lg.setBlendMode('add')
  for y = floor(cam.hz) + 1, cam.hz + 200, 2 do
    local tt = (y - cam.hz) / 170
    local edge = select(1, P(-13.6, 0, cam.z + cam.y * F / max(1, y - cam.hz)))
    local spread = 6 + tt * 70
    for _ = 1, 2 do
      local x = sx + (rng:random() * 2 - 1) * spread
      local len = 2 + tt * 18 * rng:random()
      if x + len / 2 < edge then
        lg.setColor(T.glow[1], T.glow[2], T.glow[3], (T.glare or 0.55) * max(0, 1 - tt * 0.6) * rng:random())
        lg.rectangle('fill', x - len / 2, y, len, 1 + tt * 1.5)
      end
    end
  end
  lg.setBlendMode('alpha')
end

local function groundLayers()
  ground(-13.6, -12.9, { 1, 1, 1, 0.9 }, { 1, 1, 1, 0.55 })
  ground(-16.4, -16.0, { 1, 1, 1, 0.4 }, { 1, 1, 1, 0.15 })
  ground(-12.9, -12.0, th('wet1', 'c6a86e'), th('wet2', 'e2d3ae'))
  ground(-12.0, -8.6, th('sand1', 'efd497'), th('sand2', 'f2e5c2'))
  ground(-8.6, -8.0, hex('a7a198'), hex('dad6ce'))
  ground(-8.0, 0.2, hex('d8d1c4'), hex('ebe7de'))
  lg.setLineWidth(1)
  local z0 = math.ceil((cam.z + 1.5) / 2.4) * 2.4
  for z = z0, cam.z + 95, 2.4 do
    local x1, y1 = P(-8, 0, z); local x2, y2 = P(0.2, 0, z)
    lg.setColor(0.45, 0.4, 0.35, 0.14 * (1 - fogk(z)))
    lg.line(x1, y1, x2, y2)
  end
  for _, X in ipairs({ -5.2, -2.5 }) do
    local x1, y1 = P(X, 0, cam.z + 1); local x2, y2 = P(X, 0, cam.z + 120)
    lg.setColor(0.45, 0.4, 0.35, 0.1); lg.line(x1, y1, x2, y2)
  end
  ground(0.2, 3.0, th('lane1', 'b4614b'), th('lane2', 'dbb6a6'))
  if not T.noLane then
    ground(0.2, 0.32, { 1, 1, 1, 0.85 }, { 1, 1, 1, 0.3 })
    ground(2.88, 3.0, { 1, 1, 1, 0.85 }, { 1, 1, 1, 0.3 })
  end
  for z = math.ceil((cam.z + 1.5) / 22) * 22, T.noLane and cam.z or cam.z + 90, 22 do
    lg.setColor(1, 1, 1, 0.7 * (1 - fogk(z)))
    lg.polygon('fill', q3({ 1.3, 0, z }, { 1.9, 0, z }, { 1.9, 0, z + 2.2 }, { 1.3, 0, z + 2.2 }))
    lg.polygon('fill', q3({ 1.0, 0, z + 2.2 }, { 2.2, 0, z + 2.2 }, { 1.6, 0, z + 3.4 }))
  end
  ground(3.0, 3.5, hex('c4bfb5'), hex('e2dfd8'))
  ground(3.5, 11.0, hex('434851'), hex('9ba2ac'))
  ground(3.75, 3.85, hex('f2c230'), hex('efe0a8'))
  ground(3.95, 4.05, hex('f2c230'), hex('efe0a8'))
  for z = math.ceil((cam.z + 1.2) / 9) * 9, cam.z + 400, 9 do
    lg.setColor(1, 1, 1, 0.85 * (1 - fogk(z)))
    lg.polygon('fill', flatY(0, 7.15, 7.4, z, z + 3.5))
  end
  ground(10.9, 11.1, hex('bdb8ae'), hex('e2dfd8'))
  ground(11.1, 14.0, hex('d0cabf'), hex('e7e3db'))
end

---------------------------------------------------------------- props
local RAIL = hex('2c7d93')
local function railSeg(z1, z2)
  local X = -8.35
  local s = F / (z1 - cam.z)
  col(RAIL, z1)
  lg.setLineWidth(max(1, 0.075 * s))
  local a, b = P(X, 1.1, z1); local c, d = P(X, 1.1, z2); lg.line(a, b, c, d)
  a, b = P(X, 0.55, z1); c, d = P(X, 0.55, z2); lg.line(a, b, c, d)
  lg.setLineWidth(max(1, 0.03 * s))
  for k = 1, 3 do
    local zz = z1 + (z2 - z1) * k / 4
    a, b = P(X, 0.05, zz); c, d = P(X, 1.1, zz); lg.line(a, b, c, d)
  end
  lg.setLineWidth(max(1, 0.1 * s))
  a, b = P(X, 0, z1); c, d = P(X, 1.18, z1); lg.line(a, b, c, d)
  lg.circle('fill', c, d, max(0.8, 0.08 * s))
  lg.setColor(1, 1, 1, 0.35 * (1 - fogk(z1)))
  lg.setLineWidth(max(0.6, 0.025 * s))
  a, b = P(X + 0.02, 1.14, z1); c, d = P(X + 0.02, 1.14, z2); lg.line(a, b, c, d)
end

local LAMPC = hex('22413b')
local function lamp(e)
  local X, z = e.x, e.z
  local s = F / (z - cam.z)
  local bx, by = P(X, 0, z); local tx, ty = P(X, 4.6, z)
  col(LAMPC, z)
  lg.polygon('fill', bx - 0.17 * s, by, bx + 0.17 * s, by, bx + 0.07 * s, by - 0.75 * s, bx - 0.07 * s, by - 0.75 * s)
  lg.setLineWidth(max(1, 0.1 * s)); lg.line(bx, by, tx, ty)
  local lw, lh = 0.4 * s, 0.62 * s
  lg.rectangle('fill', tx - lw / 2 - 0.06 * s, ty - 0.05 * s, lw + 0.12 * s, 0.09 * s)
  col(hex('fff2c2'), z)
  lg.polygon('fill', tx - lw / 2, ty, tx + lw / 2, ty, tx + lw * 0.68, ty - lh, tx - lw * 0.68, ty - lh)
  col(LAMPC, z)
  lg.setLineWidth(max(0.6, 0.03 * s)); lg.line(tx, ty, tx, ty - lh)
  lg.polygon('fill', tx - lw * 0.85, ty - lh, tx + lw * 0.85, ty - lh, tx, ty - lh - 0.36 * s)
  lg.circle('fill', tx, ty - lh - 0.4 * s, max(0.6, 0.05 * s))
  if T.lampsOn then glows[#glows + 1] = { tx, ty - lh / 2, min(26, max(3, 0.8 * s)), 1 - fogk(z) * 0.5 } end
end

local WOOD = hex('a06f47')
local function bench(e)
  local z = e.z
  local X0, X1 = -7.8, -7.25
  local s = F / (z - cam.z)
  col(hex('2d3a3a'), z); lg.setLineWidth(max(1, 0.07 * s))
  for _, zz in ipairs({ z + 0.15, z + 1.85 }) do
    if zz - cam.z > 0.9 then
      local a, b = P(X1, 0, zz); local c, d = P(X1, 1.0, zz); lg.line(a, b, c, d)
      a, b = P(X0, 0, zz); c, d = P(X0, 0.45, zz); lg.line(a, b, c, d)
    end
  end
  local za = max(z, cam.z + 0.9)
  if z + 2 - cam.z < 1 then return end
  col(lt(WOOD, 0.15), z); lg.polygon('fill', flatY(0.45, X0, X1, za, z + 2))
  col(dk(WOOD, 0.85), z); lg.polygon('fill', wallX(X1, 0.55, 0.72, za, z + 2))
  col(dk(WOOD, 0.85), z); lg.polygon('fill', wallX(X1, 0.8, 0.98, za, z + 2))
end

local function bin(e)
  local X, z = e.x, e.z
  local x, y, w, h = faceZ(X - 0.3, X + 0.3, 0, 0.95, z)
  if T.crates then  -- fish crates on the quay
    col(hex('b07a45'), z); lg.rectangle('fill', x - w * 0.2, y + h * 0.1, w * 1.4, h * 0.9)
    col(hex('8a5a30'), z)
    for k = 0, 2 do lg.rectangle('fill', x - w * 0.2, y + h * (0.25 + k * 0.28), w * 1.4, h * 0.06) end
    col(hex('5fa8d3'), z); lg.rectangle('fill', x - w * 0.15, y + h * 0.05, w * 1.3, h * 0.1)
    return
  end
  col(hex('1d3557'), z); lg.rectangle('fill', x, y, w, h, w * 0.2)
  col(hex('2f4b72'), z); lg.rectangle('fill', x, y, w * 0.45, h, w * 0.2)
  col(hex('152740'), z); lg.rectangle('fill', x - w * 0.06, y - h * 0.06, w * 1.12, h * 0.14, w * 0.1)
end

local function windbreak(e)
  local z0 = e.z
  local X = -10.6
  for i = 0, 5 do
    local za, zb = z0 + i * 0.6, z0 + (i + 1) * 0.6
    if za - cam.z > 0.9 then
      col(i % 2 == 0 and hex('e63946') or hex('fbfbf7'), za)
      lg.polygon('fill', wallX(X, 0.05, 1.1, za, zb))
    end
  end
  col(hex('8a6a4a'), z0); lg.setLineWidth(max(1, 0.05 * F / (z0 - cam.z)))
  for i = 0, 3 do
    local zz = z0 + i * 1.2
    if zz - cam.z > 0.9 then local a, b = P(X, 0, zz); local c, d = P(X, 1.25, zz); lg.line(a, b, c, d) end
  end
  if z0 + 0.4 - cam.z > 0.9 then
    col(hex('2ec4b6'), z0); lg.polygon('fill', flatY(0, -10.2, -9.1, z0 + 0.4, z0 + 2.4))
    col(hex('fbfbf7'), z0); lg.polygon('fill', flatY(0, -10.2, -9.1, z0 + 1.1, z0 + 1.35))
  end
end

local function lifeguardChair(e)
  local X, z = e.x, e.z
  local s = F / (z - cam.z)
  col(hex('f4f1e8'), z); lg.setLineWidth(max(1, 0.08 * s))
  local a, b = P(X - 0.5, 0, z); local c, d = P(X - 0.3, 2.2, z); lg.line(a, b, c, d)
  a, b = P(X + 0.5, 0, z); c, d = P(X + 0.3, 2.2, z); lg.line(a, b, c, d)
  local x, y, w, h = faceZ(X - 0.5, X + 0.5, 2.0, 2.2, z)
  col(hex('e63946'), z); lg.rectangle('fill', x, y, w, h)
  a, b = P(X + 0.6, 0, z); c, d = P(X + 0.6, 4.0, z)
  col(hex('5a5a5a'), z); lg.setLineWidth(max(1, 0.04 * s)); lg.line(a, b, c, d)
  col(hex('e63946'), z); lg.polygon('fill', c, d, c + 0.6 * s, d + 0.2 * s, c, d + 0.4 * s)
  col(hex('ffd60a'), z); lg.polygon('fill', c, d + 0.2 * s, c + 0.6 * s, d + 0.2 * s, c, d + 0.4 * s)
end

local function pier(e)
  local z0, z1 = e.z, e.z + 6
  local woodC = hex('7b5b45')
  col(dk(woodC, 0.6), z0); lg.setLineWidth(max(1, 0.12 * F / (z0 - cam.z)))
  for X = -14, -74, -3 do
    local a, b = P(X, 1.6, z0); local c, d = P(X, -0.2, z0); lg.line(a, b, c, d)
  end
  col(lt(woodC, 0.2), z0); lg.polygon('fill', flatY(2, -74, -13, z0, z1))
  col(woodC, z0); lg.polygon('fill', q3({ -74, 1.5, z0 }, { -13, 1.5, z0 }, { -13, 2, z0 }, { -74, 2, z0 }))
  local x, y, w, h = faceZ(-75, -64, 2, 6, z0)
  col(hex('f6f1e6'), z0); lg.rectangle('fill', x, y, w, h)
  col(hex('2a9d8f'), z0); lg.ellipse('fill', x + w / 2, y, w * 0.38, h * 0.45)
  col(hex('2a9d8f'), z0); lg.rectangle('fill', x - 1, y - 1, w + 2, 2)
  col(hex('e63946'), z0); lg.rectangle('fill', x + w / 2 - 0.5, y - h * 0.75, max(1, w * 0.05), h * 0.35)
  -- lighthouse at the end of the pier
  x, y, w, h = faceZ(-80, -77, 2, 14, z0 + 3)
  col(hex('fbfbf7'), z0); lg.polygon('fill', x, y + h, x + w, y + h, x + w * 0.82, y, x + w * 0.18, y)
  col(hex('e63946'), z0); lg.rectangle('fill', x + w * 0.08, y + h * 0.55, w * 0.84, h * 0.12); lg.rectangle('fill', x + w * 0.14, y + h * 0.2, w * 0.72, h * 0.1)
  col(hex('2f3a45'), z0); lg.rectangle('fill', x + w * 0.1, y - h * 0.14, w * 0.8, h * 0.14)
  col(hex('fff2b0'), z0); lg.rectangle('fill', x + w * 0.22, y - h * 0.12, w * 0.56, h * 0.09)
end

local function sailboat(e)
  local X, z = e.x, e.z
  local s = F / (z - cam.z)
  local bob = sin(love.timer.getTime() * 1.3 + z) * 0.15 * s
  local bx, by = P(X, 0, z); by = by + bob
  col(hex('ffffff'), z); lg.polygon('fill', bx, by - 0.4 * s, bx, by - 6 * s, bx + 3.2 * s, by - 0.6 * s)
  col(hex('e9c46a'), z); lg.polygon('fill', bx - 0.3 * s, by - 0.5 * s, bx - 0.3 * s, by - 4.6 * s, bx - 2.4 * s, by - 0.6 * s)
  col(hex(e.c or '264653'), z); lg.polygon('fill', bx - 2.6 * s, by - 0.5 * s, bx + 3.6 * s, by - 0.5 * s, bx + 3 * s, by + 0.3 * s, bx - 2.2 * s, by + 0.3 * s)
end

---------------------------------------------------------------- houses
local function window(X, y0, y1, za, zb, z)
  col(hex('fbfaf6'), z); lg.polygon('fill', wallX(X - 0.01, y0 - 0.14, y1 + 0.14, za - 0.14, zb + 0.14))
  if T.night and hash(za, y0) > 0.4 then
    col(hex('ffd27a'), z); lg.polygon('fill', wallX(X - 0.02, y0, y1, za, zb))
    local wx, wy = P(X, (y0 + y1) / 2, (za + zb) / 2)
    glows[#glows + 1] = { wx, wy, min(18, max(2, 0.6 * F / ((za + zb) / 2 - cam.z))), 0.6 * (1 - fogk(z) * 0.6) }
  else
    col(hex('5d88ad'), z); lg.polygon('fill', wallX(X - 0.02, y0, y1, za, zb))
    col(hex('cfeaf8'), z); lg.polygon('fill', wallX(X - 0.025, y0 + (y1 - y0) * 0.55, y1, za, zb))
  end
  lg.setColor(1, 1, 1, 0.3 * (1 - fogk(z)))
  lg.polygon('fill', q3({ X - 0.03, y0 + (y1 - y0) * 0.55, za }, { X - 0.03, y1, za + (zb - za) * 0.35 },
    { X - 0.03, y1, za + (zb - za) * 0.55 }, { X - 0.03, y0 + (y1 - y0) * 0.35, za }))
  col(hex('fbfaf6'), z); lg.setLineWidth(max(1, 0.07 * F / (za - cam.z)))
  local a, b = P(X - 0.03, (y0 + y1) / 2, za); local c, d = P(X - 0.03, (y0 + y1) / 2, zb); lg.line(a, b, c, d)
  a, b = P(X - 0.03, y0, (za + zb) / 2); c, d = P(X - 0.03, y1, (za + zb) / 2); lg.line(a, b, c, d)
  col(hex('e1ddd4'), z); lg.polygon('fill', wallX(X - 0.03, y0 - 0.26, y0 - 0.12, za - 0.24, zb + 0.24))
end

local DOORS = { '1d3557', 'c1121f', '2a9d8f', '6a4c93', 'f4a261', '264653' }
local SHOPS = {
  chips = { band = '1b4332', glass = 'ffe8a8', awn = 'd62828', sign = 'd62828', text = 'CHIPS', tc = 'ffd166' },
  ices = { band = '1d3557', glass = 'd8f3ff', awn = '4cc9f0', sign = '4cc9f0', text = 'ICES', tc = 'ffffff' },
  cafe = { band = '6a4c93', glass = 'ffe8d6', awn = '6a4c93', sign = '2a9d8f', text = 'CAFE', tc = 'ffffff' },
  fish = { band = '1d3557', glass = 'e0f2f7', awn = '1d3557', sign = '1d3557', text = 'FISH', tc = 'ffffff' },
  arcade = { band = '7b2cbf', glass = 'ffd6ff', awn = 'f72585', sign = 'f72585', text = 'ARCADE', tc = 'ffff8a' },
  bingo = { band = 'ffb703', glass = 'fff1c1', awn = 'ffb703', sign = '3a0ca3', text = 'BINGO', tc = 'ffd166' },
  pub = { band = '1b4332', glass = 'ffe0a3', awn = '2d6a4f', sign = '1b4332', text = 'PUB', tc = 'ffd166' },
  kebab = { band = '9d0208', glass = 'ffe0a3', awn = 'dc2f02', sign = 'dc2f02', text = 'KEBAB', tc = 'ffffff' },
}
local function house(h)
  local X = 14
  local z0, z1, ht, c = h.z0, h.z1, h.h, h.c
  if z1 - cam.z < 1 then return end
  local zc = max(z0, cam.z + 0.95)
  local z = z0
  col(hex('5a6470'), z); lg.polygon('fill', q3({ X, ht, zc }, { X, ht, z1 }, { X + 3.2, ht + 2.4, z1 }, { X + 3.2, ht + 2.4, zc }))
  col(dk(c, 0.92), z); lg.polygon('fill', wallX(X, 0, ht, zc, z1))
  col(lt(c, 0.12), z); lg.polygon('fill', wallX(X - 0.005, ht * 0.62, ht, zc, z1))
  col(dk(c, 0.75), z); lg.polygon('fill', wallX(X - 0.01, 0, 0.45, zc, z1))
  col(hex('fbfaf6'), z); lg.polygon('fill', wallX(X - 0.02, ht - 0.5, ht + 0.05, zc, z1))
  lg.setColor(0, 0, 0, 0.12 * (1 - fogk(z))); lg.polygon('fill', wallX(X - 0.02, ht - 0.68, ht - 0.5, zc, z1))
  if z0 + 0.3 - cam.z > 0.95 then
    col(dk(c, 0.78), z); lg.polygon('fill', wallX(15.6, ht + 0.8, ht + 2.9, z0 + 0.3, z0 + 1.3))
    col(dk(c, 0.6), z); lg.polygon('fill', flatY(ht + 2.9, 15.6, 16.6, z0 + 0.3, z0 + 1.3))
    col(hex('c8553d'), z)
    for k = 0, 1 do
      local px, py, pw, ph = faceZ(15.75 + k * 0.4, 15.95 + k * 0.4, ht + 2.9, ht + 3.4, z0 + 0.5)
      lg.rectangle('fill', px, py, pw, ph)
    end
    lg.setColor(0, 0, 0, 0.18 * (1 - fogk(z))); lg.setLineWidth(1)
    local a, b = P(X - 0.02, 0, z0); local cc, d = P(X - 0.02, ht, z0); lg.line(a, b, cc, d)
  end
  if z0 - cam.z > 260 or z0 - cam.z < 1.2 then return end
  local wcol = { { 3.9, 5.6 } }
  if ht > 9.4 then wcol[2] = { 6.9, 8.4 } end
  for _, fl in ipairs(wcol) do
    window(X, fl[1], fl[2], z0 + 0.9, z0 + 2.2, z)
    window(X, fl[1], fl[2], z1 - 2.2, z1 - 0.9, z)
  end
  local shop = h.shop and SHOPS[h.shop]
  if shop then
    col(hex(shop.band), z); lg.polygon('fill', wallX(X - 0.03, 2.75, 3.45, z0 + 0.3, z1 - 0.3))
    col(hex(shop.glass), z); lg.polygon('fill', wallX(X - 0.03, 0.55, 2.55, z0 + 0.6, z1 - 2.0))
    col(dk(hex(shop.glass), 0.82), z); lg.polygon('fill', wallX(X - 0.035, 0.55, 1.3, z0 + 0.6, z1 - 2.0))
    col(hex(shop.band), z); lg.polygon('fill', wallX(X - 0.03, 0, 2.4, z1 - 1.7, z1 - 0.6))
    local n = 8
    for i = 0, n - 1 do
      local za = z0 + 0.4 + (z1 - z0 - 0.8) * i / n
      local zb = z0 + 0.4 + (z1 - z0 - 0.8) * (i + 1) / n
      col(i % 2 == 0 and hex(shop.awn) or hex('fbfaf6'), z)
      lg.polygon('fill', q3({ X, 3.3, za }, { X, 3.3, zb }, { X - 1.5, 2.6, zb }, { X - 1.5, 2.6, za }))
    end
  else
    local dz = z0 + 0.7
    col(hex('fbfaf6'), z); lg.polygon('fill', wallX(X - 0.02, 0, 2.55, dz - 0.15, dz + 1.25))
    col(hex(DOORS[h.door]), z); lg.polygon('fill', wallX(X - 0.03, 0.05, 2.25, dz, dz + 1.1))
    col(hex('cfeaf8'), z); lg.polygon('fill', wallX(X - 0.04, 2.3, 2.5, dz, dz + 1.1))
    window(X, 0.9, 2.5, z0 + 2.6, z1 - 0.9, z)
  end
end

local function shopSign(e)
  local h = e.h
  local shop = SHOPS[h.shop]
  local zs = h.z0 + 0.35
  local s = F / (zs - cam.z)
  local x, y, w, ht = faceZ(11.7, 13.8, 4.0, 5.3, zs)
  col(hex('22313a'), zs); lg.setLineWidth(max(1, 0.06 * s))
  local _, b = P(13.8, 5.5, zs); local c, d = P(14, 5.5, zs); lg.line(x + w * 0.2, b, c, d)
  lg.line(x + w * 0.25, b, x + w * 0.25, y); lg.line(x + w * 0.85, b, x + w * 0.85, y)
  col(hex(shop.sign), zs); lg.rectangle('fill', x, y, w, ht, ht * 0.18)
  col(hex('fbfaf6'), zs); lg.setLineWidth(max(1, 0.05 * s)); lg.rectangle('line', x + w * 0.04, y + ht * 0.08, w * 0.92, ht * 0.84, ht * 0.14)
  if w > 12 then
    local f = U.f[17]
    local fw = f:getWidth(shop.text)
    local sc = min((w * 0.72) / fw, (ht * 0.7) / f:getHeight())
    lg.setFont(f); col(hex(shop.tc), zs)
    lg.print(shop.text, x + w / 2 - fw * sc / 2, y + ht / 2 - f:getHeight() * sc / 2, 0, sc, sc)
  end
end

---------------------------------------------------------------- cars
local function car(e)
  local z0, c = e.z, e.c
  local XL, XR, len = 9.0, 10.8, 4.3
  local z = z0
  local glass = hex('2b3a4f')
  col(hex('1c1c22'), z)
  for _, zz in ipairs({ z0 + 0.85, z0 + 3.45 }) do
    local x, y = P(XL, 0.34, zz); local ss = F / (zz - cam.z)
    lg.ellipse('fill', x, y, 0.19 * ss, 0.34 * ss)
  end
  col(lt(c, 0.12), z); lg.polygon('fill', flatY(1.0, XL, XR, z0, z0 + len))
  col(dk(c, 0.75), z); lg.polygon('fill', q3({ XL, 0.3, z0 }, { XR, 0.3, z0 }, { XR, 1.0, z0 }, { XL, 1.0, z0 }))
  col(hex('e63946'), z)
  local x, y, w, h = faceZ(XL + 0.08, XL + 0.42, 0.66, 0.86, z0); lg.rectangle('fill', x, y, w, h)
  x, y, w, h = faceZ(XR - 0.42, XR - 0.08, 0.66, 0.86, z0); lg.rectangle('fill', x, y, w, h)
  col(hex('f5f5f2'), z); x, y, w, h = faceZ(9.6, 10.2, 0.42, 0.58, z0); lg.rectangle('fill', x, y, w, h)
  col(dk(c, 0.92), z); lg.polygon('fill', wallX(XL, 0.3, 1.0, z0, z0 + len))
  col(c, z); lg.polygon('fill', wallX(XL - 0.005, 0.65, 1.0, z0, z0 + len))
  local ca, cbz = z0 + 1.1, z0 + 3.25
  col(glass, z); lg.polygon('fill', q3({ XL + 0.12, 1.0, ca }, { XR - 0.12, 1.0, ca }, { XR - 0.25, 1.48, ca + 0.4 }, { XL + 0.25, 1.48, ca + 0.4 }))
  col(glass, z); lg.polygon('fill', q3({ XL + 0.12, 1.0, ca }, { XL + 0.12, 1.0, cbz }, { XL + 0.25, 1.48, cbz - 0.35 }, { XL + 0.25, 1.48, ca + 0.4 }))
  lg.setColor(1, 1, 1, 0.25 * (1 - fogk(z)))
  lg.polygon('fill', q3({ XL + 0.13, 1.05, ca + 0.5 }, { XL + 0.13, 1.05, ca + 0.9 }, { XL + 0.24, 1.43, ca + 0.75 }, { XL + 0.24, 1.43, ca + 0.5 }))
  col(c, z); lg.setLineWidth(max(1, 0.06 * F / (z0 - cam.z)))
  local a, b = P(XL + 0.12, 1.0, ca + 1.1); local cc, d = P(XL + 0.25, 1.48, ca + 1.0); lg.line(a, b, cc, d)
  col(lt(c, 0.22), z); lg.polygon('fill', flatY(1.48, XL + 0.25, XR - 0.25, ca + 0.4, cbz - 0.35))
  if e.splats then
    lg.setColor(0.99, 0.99, 0.97, 1 - fogk(z))
    for _, sp in ipairs(e.splats) do
      local sx, sy = P(sp[1], 1.49, sp[2]); local ss = F / (sp[2] - cam.z)
      lg.ellipse('fill', sx, sy, 0.25 * ss, 0.25 * ss * cam.y / (sp[2] - cam.z) + 0.6)
    end
  end
end

---------------------------------------------------------------- people
local function limb(x1, y1, x2, y2, w, c, z)
  col(c, z); lg.setLineWidth(w); lg.line(x1, y1, x2, y2)
  lg.circle('fill', x1, y1, w / 2); lg.circle('fill', x2, y2, w / 2)
end
local function limb2(x1, y1, x2, y2, x3, y3, w, c, z)
  limb(x1, y1, x2, y2, w, c, z); limb(x2, y2, x3, y3, w, c, z)
end

local function splat(x, y, r)
  lg.setColor(0.72, 0.75, 0.8)
  lg.circle('fill', x - r * 0.1 + 1, y - r * 0.7 + 1, r * 0.66)
  lg.setColor(0.995, 0.995, 0.975)
  lg.circle('fill', x - r * 0.1, y - r * 0.72, r * 0.66)
  lg.circle('fill', x + r * 0.5, y - r * 0.47, r * 0.46)
  lg.circle('fill', x - r * 0.62, y - r * 0.4, r * 0.4)
  lg.ellipse('fill', x + r * 0.88, y + r * 0.05, r * 0.2, r * 0.44)
  lg.circle('fill', x + r * 0.88, y + r * 0.45, r * 0.22)
  lg.circle('fill', x - r * 1.35, y - r * 1.25, r * 0.15)
  lg.circle('fill', x + r * 1.3, y - r * 1.3, r * 0.12)
  lg.setColor(0.5, 0.53, 0.58)
  lg.circle('fill', x + r * 0.05, y - r * 0.85, r * 0.1)
end

local function foodIcon(kind, x, y, s, z)
  if kind == 'cone' then
    col(hex('e0a458'), z); lg.polygon('fill', x - 0.06 * s, y, x + 0.06 * s, y, x, y + 0.15 * s)
    col(hex('fffaf0'), z); lg.circle('fill', x, y - 0.03 * s, 0.07 * s); lg.circle('fill', x + 0.01 * s, y - 0.09 * s, 0.045 * s)
    col(hex('5b3a29'), z); lg.setLineWidth(max(1, 0.02 * s)); lg.line(x + 0.02 * s, y - 0.08 * s, x + 0.07 * s, y - 0.2 * s)
  elseif kind == 'chips' then
    col(hex('ffd166'), z)
    for i = -2, 2 do lg.rectangle('fill', x + i * 0.035 * s - 0.012 * s, y - 0.12 * s - (i % 2) * 0.03 * s, 0.024 * s, 0.14 * s) end
    col(hex('d62828'), z); lg.polygon('fill', x - 0.1 * s, y - 0.04 * s, x + 0.1 * s, y - 0.04 * s, x + 0.07 * s, y + 0.1 * s, x - 0.07 * s, y + 0.1 * s)
    col(hex('fbfaf6'), z); lg.rectangle('fill', x - 0.06 * s, y + 0.01 * s, 0.12 * s, 0.025 * s)
  elseif kind == 'sandwich' then
    col(hex('f4e1b5'), z); lg.polygon('fill', x - 0.12 * s, y + 0.06 * s, x + 0.12 * s, y + 0.06 * s, x, y - 0.1 * s)
    col(hex('7cb518'), z); lg.rectangle('fill', x - 0.1 * s, y + 0.02 * s, 0.2 * s, 0.025 * s)
  elseif kind == 'fish' then
    col(hex('b8c7d3'), z); lg.ellipse('fill', x, y, 0.13 * s, 0.05 * s)
    lg.polygon('fill', x + 0.11 * s, y, x + 0.19 * s, y - 0.05 * s, x + 0.19 * s, y + 0.05 * s)
    col(hex('3d5a80'), z); lg.ellipse('fill', x, y - 0.02 * s, 0.11 * s, 0.025 * s)
    col(hex('111111'), z); lg.circle('fill', x - 0.08 * s, y - 0.01 * s, max(0.5, 0.012 * s))
  elseif kind == 'candyfloss' then
    col(hex('f2e8cf'), z); lg.setLineWidth(max(1, 0.015 * s)); lg.line(x, y + 0.14 * s, x, y)
    col(hex('ff8fab'), z); lg.circle('fill', x, y - 0.05 * s, 0.08 * s); lg.circle('fill', x - 0.05 * s, y - 0.02 * s, 0.06 * s); lg.circle('fill', x + 0.05 * s, y - 0.02 * s, 0.06 * s)
  elseif kind == 'burger' then
    col(hex('e09f3e'), z); lg.arc('fill', x, y - 0.01 * s, 0.1 * s, pi, 2 * pi)
    col(hex('7cb518'), z); lg.rectangle('fill', x - 0.11 * s, y - 0.01 * s, 0.22 * s, 0.025 * s)
    col(hex('6f1d1b'), z); lg.rectangle('fill', x - 0.1 * s, y + 0.015 * s, 0.2 * s, 0.035 * s)
    col(hex('e09f3e'), z); lg.rectangle('fill', x - 0.1 * s, y + 0.05 * s, 0.2 * s, 0.03 * s)
  elseif kind == 'pizza' then
    col(hex('f4a259'), z); lg.polygon('fill', x - 0.11 * s, y - 0.07 * s, x + 0.11 * s, y - 0.07 * s, x, y + 0.12 * s)
    col(hex('ffd166'), z); lg.polygon('fill', x - 0.09 * s, y - 0.05 * s, x + 0.09 * s, y - 0.05 * s, x, y + 0.09 * s)
    col(hex('c1121f'), z); lg.circle('fill', x - 0.02 * s, y - 0.02 * s, 0.02 * s); lg.circle('fill', x + 0.03 * s, y + 0.01 * s, 0.02 * s)
  end
end
W.foodIcon = foodIcon

-- things people throw at the gull
local function throwIcon(kind, x, y, s, rot, z)
  lg.push(); lg.translate(x, y); lg.rotate(rot or 0)
  if kind == 'shoe' then
    col(hex('3a86ff'), z); lg.ellipse('fill', 0, 0, 0.16 * s, 0.065 * s)
    col(hex('ffbe0b'), z); lg.setLineWidth(max(1, 0.02 * s)); lg.line(-0.05 * s, -0.05 * s, 0, 0, 0.05 * s, -0.05 * s)
  elseif kind == 'fish' then
    lg.pop(); foodIcon('fish', x, y, s * 1.2, z); lg.push(); lg.translate(x, y)
  elseif kind == 'ball' then
    col(hex('8d5524'), z); lg.circle('fill', 0, 0, 0.1 * s)
    col(hex('5a3418'), z); lg.setLineWidth(max(1, 0.015 * s)); lg.line(-0.08 * s, 0, 0.08 * s, 0)
  elseif kind == 'hat' then
    col(hex('2d6a4f'), z); lg.arc('fill', 0, 0.02 * s, 0.11 * s, pi, 2 * pi)
    col(hex('ffffff'), z); lg.rectangle('fill', -0.11 * s, 0, 0.22 * s, 0.035 * s); lg.circle('fill', 0, -0.11 * s, 0.035 * s)
  elseif kind == 'lid' then
    col(hex('6c757d'), z); lg.ellipse('fill', 0, 0, 0.2 * s, 0.07 * s)
    col(hex('adb5bd'), z); lg.ellipse('fill', 0, -0.015 * s, 0.17 * s, 0.05 * s)
    col(hex('495057'), z); lg.rectangle('fill', -0.04 * s, -0.06 * s, 0.08 * s, 0.03 * s)
  end
  lg.pop()
end
W.throwIcon = throwIcon

local overlay = {}
local function person(o)
  local z = o.z
  local d = z - cam.z
  local s = F / d
  local fx, fy = P(o.x, 0, z)
  local H = (o.h or 1.75) * s
  local hipY = fy - 0.49 * H
  local shY = fy - 0.80 * H
  local headY = fy - 0.905 * H
  local hr = 0.075 * H
  local lw = max(1, 0.085 * H)
  local aw = max(1, 0.068 * H)
  local walking = o.moving and o.state == 'walk'
  local amp = (o.pose == 'jog') and 0.11 or 0.05
  local st = walking and sin(o.phase) * amp * H or 0
  local sw = walking and sin(o.phase) * 0.04 * H or 0
  local skin, top = o.skin, o.top
  local state, t = o.state, o.st or 0
  lg.setColor(0.08, 0.12, 0.22, 0.2 * (1 - fogk(z)))
  lg.ellipse('fill', fx + 0.2 * H, fy + 0.015 * H, 0.32 * H, 0.05 * H)
  if o.pose == 'dog' then
    local dx, dy = fx - 0.5 * H, fy - 0.12 * H
    local dc = hex('8d5a3b')
    local dst = walking and sin(o.phase * 1.5) * 0.03 * H or 0
    for i, lx in ipairs({ -0.09, -0.04, 0.05, 0.1 }) do limb(dx + lx * H, dy, dx + lx * H + (i % 2 == 0 and dst or -dst), fy - 0.01 * H, 0.03 * H, dc, z) end
    col(dc, z); lg.ellipse('fill', dx, dy, 0.13 * H, 0.055 * H)
    lg.circle('fill', dx - 0.13 * H, dy - 0.06 * H, 0.05 * H)
    col(dk(dc, 0.7), z); lg.ellipse('fill', dx - 0.11 * H, dy - 0.07 * H, 0.02 * H, 0.04 * H)
    limb(dx + 0.12 * H, dy - 0.02 * H, dx + 0.19 * H, dy - 0.1 * H + sin(love.timer.getTime() * 12) * 0.02 * H, 0.025 * H, dc, z)
    col(hex('333333'), z); lg.setLineWidth(1)
    lg.line(dx - 0.12 * H, dy - 0.03 * H, fx - 0.2 * H, hipY + 0.02 * H)
  end
  local hair = o.hair or hex('3b2a20')
  if o.veil then col(hex('ffffff'), z, 0.8 * (1 - fogk(z))); lg.polygon('fill', fx - hr * 0.9, headY - hr * 0.6, fx + hr * 0.9, headY - hr * 0.6, fx + hr * 1.6, headY + hr * 3.2, fx - hr * 1.6, headY + hr * 3.2) end
  if o.hairStyle == 'long' then col(hair, z); lg.rectangle('fill', fx - hr * 1.08, headY - hr * 0.3, hr * 2.16, hr * 2.7, hr * 0.8) end
  if o.hairStyle == 'ponytail' then col(hair, z); lg.ellipse('fill', fx + hr * 1.05, headY + hr * 0.35, hr * 0.38, hr * 0.8) end
  if o.dress then
    col(o.bottom, z); lg.polygon('fill', fx - 0.1 * H, hipY - 0.05 * H, fx + 0.1 * H, hipY - 0.05 * H, fx + 0.2 * H, fy - 0.02 * H, fx - 0.2 * H, fy - 0.02 * H)
    col(dk(o.bottom, 0.9), z); lg.polygon('fill', fx + 0.02 * H, hipY - 0.05 * H, fx + 0.1 * H, hipY - 0.05 * H, fx + 0.2 * H, fy - 0.02 * H, fx + 0.05 * H, fy - 0.02 * H)
  else
    local legC = o.shorts and skin or o.bottom
    limb(fx + 0.045 * H, hipY, fx + 0.045 * H + st, fy - 0.035 * H, lw, dk(legC, 0.85), z)
    limb(fx - 0.045 * H, hipY, fx - 0.045 * H - st, fy - 0.035 * H, lw, legC, z)
    if o.shorts then
      col(o.bottom, z); lg.rectangle('fill', fx - 0.12 * H, hipY - 0.05 * H, 0.24 * H, 0.18 * H, 0.03 * H)
      col(dk(o.bottom, 0.85), z); lg.rectangle('fill', fx + 0.01 * H, hipY - 0.05 * H, 0.11 * H, 0.18 * H, 0.03 * H)
    end
    col(o.shoes or hex('2b2b2b'), z)
    lg.ellipse('fill', fx - 0.045 * H - st - 0.014 * H, fy - 0.022 * H, 0.058 * H, 0.028 * H)
    lg.ellipse('fill', fx + 0.045 * H + st + 0.014 * H, fy - 0.022 * H, 0.058 * H, 0.028 * H)
  end
  local shL, shR = fx - 0.11 * H, fx + 0.11 * H
  local armY = shY + 0.04 * H
  local pose = o.pose or 'walk'
  local mode = pose
  if state == 'hit' then mode = t < 1.3 and 'horror' or 'fist'
  elseif state == 'swing' then mode = 'swing'
  elseif state == 'look' then mode = 'look'
  elseif state == 'windup' then mode = 'windup'
  elseif state == 'thrown' then mode = 'thrown' end
  if (pose == 'cone' or pose == 'chips') and not o.food and mode == pose then mode = 'walk' end
  -- back arm
  if mode == 'walk' or mode == 'dog' or mode == 'cone' or mode == 'chips' or mode == 'map' or mode == 'look' or mode == 'camera' then
    limb(shR, armY, shR + 0.035 * H + sw, hipY + 0.04 * H, aw, dk(top, 0.78), z)
    col(dk(skin, 0.9), z); lg.circle('fill', shR + 0.035 * H + sw, hipY + 0.06 * H, aw * 0.6)
  elseif mode == 'jog' then
    limb2(shR, armY, shR + 0.06 * H, shY + 0.2 * H, shR + 0.12 * H, shY + 0.32 * H, aw, dk(top, 0.78), z)
  elseif mode == 'horror' then
    limb2(shR, armY, shR + 0.12 * H, shY - 0.02 * H, fx + 0.09 * H, headY - 0.03 * H, aw, dk(top, 0.78), z)
  elseif mode == 'fist' or mode == 'swing' or mode == 'pistol' or mode == 'phone' or mode == 'umb' or mode == 'pram' or mode == 'selfie'
    or mode == 'windup' or mode == 'thrown' or mode == 'thrower' then
    limb(shR, armY, shR + 0.03 * H, hipY + 0.04 * H, aw, dk(top, 0.78), z)
  end
  -- torso
  col(top, z); lg.rectangle('fill', fx - 0.125 * H, shY - 0.015 * H, 0.25 * H, hipY - shY + 0.07 * H, 0.06 * H)
  col(dk(top, 0.84), z); lg.rectangle('fill', fx + 0.035 * H, shY - 0.015 * H, 0.09 * H, hipY - shY + 0.07 * H, 0.06 * H)
  if o.stripe then col(o.stripe, z); lg.rectangle('fill', fx - 0.125 * H, shY + 0.12 * H, 0.25 * H, 0.04 * H) end
  if o.tie then col(o.tie, z); lg.polygon('fill', fx - 0.015 * H, shY, fx + 0.015 * H, shY, fx + 0.02 * H, shY + 0.2 * H, fx, shY + 0.23 * H, fx - 0.02 * H, shY + 0.2 * H) end
  -- neck + head
  col(dk(skin, 0.9), z); lg.rectangle('fill', fx - 0.025 * H, headY + hr * 0.5, 0.05 * H, 0.06 * H)
  col(skin, z); lg.circle('fill', fx, headY, hr)
  col(dk(skin, 0.9), z); lg.arc('fill', fx, headY, hr, -pi / 2, pi / 2)
  col(skin, z); lg.ellipse('fill', fx + hr * 0.05, headY, hr * 0.6, hr)
  local hs = o.hairStyle or 'short'
  if hs ~= 'bald' then
    col(hair, z)
    lg.arc('fill', fx, headY - hr * 0.05, hr * 1.06, pi, 2 * pi)
    lg.rectangle('fill', fx - hr * 1.06, headY - hr * 0.1, hr * 0.32, hr * 0.55)
    if hs == 'long' or hs == 'ponytail' then lg.rectangle('fill', fx + hr * 0.74, headY - hr * 0.1, hr * 0.32, hr * 0.55) end
    if hs == 'bun' then lg.circle('fill', fx + hr * 0.1, headY - hr * 1.15, hr * 0.48) end
  else
    col(hex('b8a68f'), z)
    lg.ellipse('fill', fx - hr * 0.9, headY + hr * 0.05, hr * 0.22, hr * 0.38)
    lg.ellipse('fill', fx + hr * 0.9, headY + hr * 0.05, hr * 0.22, hr * 0.38)
    lg.setColor(1, 1, 1, 0.5 * (1 - fogk(z))); lg.ellipse('fill', fx - hr * 0.3, headY - hr * 0.6, hr * 0.28, hr * 0.14)
  end
  if o.cap then col(o.cap, z); lg.arc('fill', fx, headY - hr * 0.1, hr * 1.1, pi, 2 * pi); lg.ellipse('fill', fx - hr * 0.6, headY - hr * 0.12, hr * 0.9, hr * 0.22) end
  if o.band then col(o.band, z); lg.rectangle('fill', fx - hr * 1.02, headY - hr * 0.42, hr * 2.04, hr * 0.3) end
  if hr > 2.6 then
    col(hex('2b2230'), z)
    local er = max(0.7, hr * 0.11)
    local ey = (mode == 'horror' or mode == 'look') and headY - hr * 0.12 or headY + hr * 0.12
    lg.circle('fill', fx - hr * 0.32, ey, er)
    lg.circle('fill', fx + hr * 0.32, ey, er)
    if mode == 'horror' and hr > 4 then lg.ellipse('fill', fx, headY + hr * 0.5, hr * 0.18, hr * 0.24) end
    if mode == 'fist' and hr > 4 then lg.setLineWidth(max(1, hr * 0.12)); lg.line(fx - hr * 0.5, headY - hr * 0.2, fx - hr * 0.15, headY - hr * 0.05); lg.line(fx + hr * 0.5, headY - hr * 0.2, fx + hr * 0.15, headY - hr * 0.05) end
    if o.blush then lg.setColor(1, 0.5, 0.5, 0.35); lg.circle('fill', fx - hr * 0.55, headY + hr * 0.4, hr * 0.2); lg.circle('fill', fx + hr * 0.55, headY + hr * 0.4, hr * 0.2) end
  end
  -- front arm + what they hold
  if mode == 'walk' or mode == 'dog' or mode == 'look' then
    local hx, hy = shL - 0.035 * H - sw, hipY + 0.06 * H
    if mode == 'look' then hx, hy = shL - 0.06 * H, shY + 0.05 * H end
    limb(shL, armY, hx, hy - 0.02 * H, aw, top, z)
    col(skin, z); lg.circle('fill', hx, hy, aw * 0.6)
  elseif mode == 'jog' then
    limb2(shL, armY, shL - 0.07 * H, shY + 0.18 * H, shL + 0.01 * H, shY + 0.09 * H, aw, top, z)
    col(skin, z); lg.circle('fill', shL + 0.01 * H, shY + 0.09 * H, aw * 0.6)
  elseif mode == 'cone' or mode == 'chips' then
    local hx, hy = fx - 0.06 * H, headY + 0.13 * H
    if mode == 'chips' then hx, hy = shL - 0.02 * H, shY + 0.16 * H end
    limb2(shL, armY, shL - 0.09 * H, shY + 0.15 * H, hx, hy, aw, top, z)
    col(skin, z); lg.circle('fill', hx, hy, aw * 0.62)
    foodIcon(o.food, hx, hy - 0.02 * H, H * 0.55, z)
  elseif mode == 'selfie' then
    limb(shL, armY, shL - 0.03 * H, hipY + 0.04 * H, aw, top, z)
    local hx, hy = shR + 0.16 * H, headY - 0.12 * H
    limb2(shR, armY, shR + 0.1 * H, shY - 0.04 * H, hx, hy, aw, top, z)
    col(skin, z); lg.circle('fill', hx, hy, aw * 0.6)
    col(hex('222222'), z); lg.setLineWidth(max(1, 0.012 * H)); lg.line(hx, hy, hx + 0.1 * H, hy - 0.24 * H)
    lg.rectangle('fill', hx + 0.06 * H, hy - 0.3 * H, 0.08 * H, 0.12 * H)
  elseif mode == 'pram' then
    local px, py = fx - 0.48 * H, fy - 0.25 * H
    col(hex('1c1c22'), z)
    lg.circle('fill', px - 0.13 * H, fy - 0.045 * H, 0.05 * H); lg.circle('fill', px + 0.13 * H, fy - 0.045 * H, 0.05 * H)
    lg.setLineWidth(max(1, 0.015 * H)); lg.line(px - 0.13 * H, fy - 0.05 * H, px, py + 0.05 * H, px + 0.13 * H, fy - 0.05 * H)
    local pc = o.pramC or hex('3d5a80')
    col(pc, z); lg.rectangle('fill', px - 0.19 * H, py - 0.1 * H, 0.38 * H, 0.17 * H, 0.06 * H)
    col(dk(pc, 0.75), z); lg.arc('fill', px - 0.06 * H, py - 0.09 * H, 0.13 * H, pi, 2 * pi)
    col(hex('1c1c22'), z); lg.line(px + 0.19 * H, py - 0.06 * H, fx - 0.2 * H, hipY - 0.07 * H)
    limb2(shL, armY, shL - 0.05 * H, hipY - 0.1 * H, fx - 0.2 * H, hipY - 0.07 * H, aw, top, z)
    col(skin, z); lg.circle('fill', fx - 0.2 * H, hipY - 0.07 * H, aw * 0.6)
  elseif mode == 'phone' then
    local hx, hy = fx - 0.09 * H, headY + 0.02 * H
    limb2(shL, armY, shL - 0.06 * H, shY + 0.14 * H, hx, hy, aw, top, z)
    col(hex('222222'), z); lg.rectangle('fill', hx - 0.02 * H, hy - 0.06 * H, 0.035 * H, 0.09 * H)
    col(skin, z); lg.circle('fill', hx, hy, aw * 0.55)
    col(hex('5b3a29'), z); lg.rectangle('fill', fx + 0.13 * H, hipY - 0.04 * H, 0.12 * H, 0.09 * H, 0.01 * H)
  elseif mode == 'map' then
    local mx, my = fx - 0.02 * H, shY + 0.1 * H
    col(hex('f2e8cf'), z); lg.rectangle('fill', mx - 0.2 * H, my - 0.1 * H, 0.36 * H, 0.24 * H)
    col(hex('8ecae6'), z); lg.rectangle('fill', mx - 0.17 * H, my - 0.07 * H, 0.12 * H, 0.18 * H)
    col(hex('90be6d'), z); lg.rectangle('fill', mx - 0.03 * H, my - 0.07 * H, 0.16 * H, 0.08 * H)
    col(skin, z); lg.circle('fill', mx - 0.2 * H, my, aw * 0.6); lg.circle('fill', mx + 0.16 * H, my, aw * 0.6)
  elseif mode == 'umb' then
    local hx, hy = fx - 0.02 * H, shY + 0.06 * H
    limb2(shL, armY, shL - 0.05 * H, shY + 0.16 * H, hx, hy, aw, top, z)
    col(hex('333333'), z); lg.setLineWidth(max(1, 0.015 * H))
    if o.umbOpen then
      lg.line(hx, hy, fx, headY - 0.18 * H)
      local uc = o.umbC or hex('e63946')
      col(uc, z); lg.arc('fill', fx, headY - 0.1 * H, 0.42 * H, pi, 2 * pi)
      col(dk(uc, 0.8), z); lg.arc('fill', fx, headY - 0.1 * H, 0.42 * H, pi * 1.5, pi * 1.75)
      col(lt(uc, 0.4), z); lg.arc('fill', fx, headY - 0.1 * H, 0.42 * H, pi * 1.08, pi * 1.25)
      col(hex('333333'), z); lg.line(fx, headY - 0.52 * H, fx, headY - 0.58 * H)
    else
      lg.line(hx, hy, hx + 0.05 * H, fy - 0.1 * H)
      col(o.umbC or hex('e63946'), z); lg.polygon('fill', hx - 0.03 * H, hy + 0.02 * H, hx + 0.04 * H, hy + 0.02 * H, hx + 0.05 * H, fy - 0.15 * H)
    end
    col(skin, z); lg.circle('fill', hx, hy, aw * 0.6)
  elseif mode == 'paper' or mode == 'swing' then
    local a = mode == 'swing' and (-1.6 + sin(t * 16) * 1.2) or 0.3
    local ex, ey = shL - 0.06 * H, shY + 0.1 * H
    if mode == 'swing' then ex, ey = shL - 0.08 * H, shY - 0.06 * H end
    limb(shL, armY, ex, ey, aw, top, z)
    col(hex('e9ecef'), z); lg.setLineWidth(max(1, 0.05 * H))
    lg.line(ex, ey, ex + cos(a - pi / 2) * 0.32 * H, ey + sin(a - pi / 2) * 0.32 * H)
    col(skin, z); lg.circle('fill', ex, ey, aw * 0.6)
  elseif mode == 'pistol' then
    local hx, hy = shL - 0.12 * H, shY - 0.12 * H
    limb(shL, armY, hx, hy, aw, top, z)
    col(hex('70e000'), z); lg.rectangle('fill', hx - 0.04 * H, hy - 0.1 * H, 0.06 * H, 0.12 * H, 0.01 * H)
    col(hex('ff006e'), z); lg.circle('fill', hx - 0.01 * H, hy - 0.02 * H, 0.04 * H)
    col(skin, z); lg.circle('fill', hx, hy + 0.01 * H, aw * 0.55)
  elseif mode == 'camera' then
    local hx, hy = fx - 0.05 * H, headY + 0.03 * H
    limb2(shL, armY, shL - 0.05 * H, shY + 0.12 * H, hx, hy, aw, top, z)
    col(hex('222222'), z); lg.rectangle('fill', fx - 0.1 * H, headY - 0.03 * H, 0.16 * H, 0.08 * H, 0.01 * H)
    col(hex('3a506b'), z); lg.circle('fill', fx - 0.02 * H, headY + 0.01 * H, 0.025 * H)
  elseif mode == 'thrower' or mode == 'windup' or mode == 'thrown' then
    local ex, ey, hx, hy
    if mode == 'windup' then ex, ey, hx, hy = shL - 0.04 * H, shY - 0.1 * H, shL + 0.05 * H, headY - 0.2 * H
    elseif mode == 'thrown' then ex, ey, hx, hy = shL - 0.1 * H, shY + 0.0 * H, shL - 0.18 * H, shY - 0.08 * H
    else ex, ey, hx, hy = shL - 0.04 * H, shY + 0.18 * H, shL - 0.04 * H, hipY + 0.05 * H end
    limb2(shL, armY, ex, ey, hx, hy, aw, top, z)
    col(skin, z); lg.circle('fill', hx, hy, aw * 0.6)
    if mode ~= 'thrown' and o.throwKind then throwIcon(o.throwKind, hx, hy - 0.03 * H, H * 0.6, mode == 'windup' and -0.6 or 0.3, z) end
  elseif mode == 'horror' then
    limb2(shL, armY, shL - 0.12 * H, shY - 0.02 * H, fx - 0.09 * H, headY - 0.03 * H, aw, top, z)
    col(skin, z); lg.circle('fill', fx - 0.09 * H, headY - 0.03 * H, aw * 0.6)
  elseif mode == 'fist' then
    local hx, hy = shL - 0.05 * H, headY - 0.12 * H + sin(t * 22) * 0.03 * H
    limb2(shL, armY, shL - 0.1 * H, shY - 0.02 * H, hx, hy, aw, top, z)
    col(skin, z); lg.circle('fill', hx, hy, aw * 0.75)
  else
    limb(shL, armY, shL - 0.035 * H, hipY + 0.04 * H, aw, top, z)
    col(skin, z); lg.circle('fill', shL - 0.035 * H, hipY + 0.06 * H, aw * 0.6)
  end
  if o.splat then splat(fx, headY, max(hr * 1.6, 3.5)) end
  if o.bodySplat then lg.setColor(0.99, 0.99, 0.97); lg.circle('fill', fx - 0.03 * H, shY + 0.1 * H, max(1.5, 0.06 * H)); lg.circle('fill', fx + 0.02 * H, shY + 0.13 * H, max(1, 0.04 * H)) end
  o.hx, o.htop, o.hr, o.sx, o.sy = fx, headY - hr, hr, fx, fy
  if o.say and o.sayT and o.sayT > 0 then overlay[#overlay + 1] = o end
end

---------------------------------------------------------------- small things
local function item(it)
  local d = it.z - cam.z
  local s = F / d
  local x, y = P(it.x, it.y or 0, it.z)
  if (it.y or 0) < 0.1 then
    lg.setColor(0.08, 0.12, 0.22, 0.18 * (1 - fogk(it.z))); lg.ellipse('fill', x + 0.05 * s, y + 0.02 * s, 0.22 * s, 0.05 * s)
  end
  lg.setBlendMode('add')
  local gl = 0.18 + 0.1 * sin(love.timer.getTime() * 6 + it.z)
  lg.setColor(1, 0.85, 0.4, gl * (1 - fogk(it.z))); lg.circle('fill', x, y - 0.1 * s, 0.35 * s)
  lg.setBlendMode('alpha')
  foodIcon(it.food, x, y - 0.12 * s, s * 1.4, it.z)
  if s > 6 then
    local tw = love.timer.getTime() * 3 + it.z
    lg.setColor(1, 1, 1, (0.5 + 0.5 * sin(tw * 2)) * (1 - fogk(it.z)))
    local gx, gy, r = x + 0.15 * s, y - 0.3 * s, 0.07 * s
    lg.polygon('fill', gx, gy - r * 2, gx + r * 0.5, gy, gx, gy + r * 2, gx - r * 0.5, gy)
    lg.polygon('fill', gx - r * 2, gy, gx, gy - r * 0.5, gx + r * 2, gy, gx, gy + r * 0.5)
  end
end

local function drop(dp)
  local d = dp.z - cam.z
  local s = F / d
  local x, y = P(dp.x, dp.y, dp.z)
  local r = min(7, max(1.6, 0.13 * s))
  lg.setColor(1, 1, 1, 0.3); lg.setLineWidth(max(1, r * 0.4))
  lg.line(x, y - r * 1.2, x, y - r * 4)
  lg.setColor(0.72, 0.75, 0.8); lg.circle('fill', x + r * 0.2, y + r * 0.2, r)
  lg.setColor(1, 1, 1); lg.circle('fill', x, y, r)
  lg.polygon('fill', x - r * 0.8, y - r * 0.5, x + r * 0.8, y - r * 0.5, x, y - r * 2)
end

local function jet(j)
  local s = F / (j.z - cam.z)
  for k = 0, 4 do
    local px, py, pz = j.x - j.vx * k * 0.03, j.y - j.vy * k * 0.03, j.z - j.vz * k * 0.03
    if pz - cam.z > 0.6 then
      local x, y = P(px, py, pz)
      local ss = F / (pz - cam.z)
      lg.setColor(0.55, 0.85, 1, 0.85 - k * 0.15); lg.circle('fill', x, y, max(1.2, 0.09 * ss * (1 - k * 0.12)))
    end
  end
  local x, y = P(j.x, j.y, j.z)
  lg.setColor(1, 1, 1, 0.8); lg.circle('fill', x - 0.03 * s, y - 0.03 * s, max(0.6, 0.03 * s))
end

local function thrown(o)
  local s = F / (o.z - cam.z)
  local x, y = P(o.x, o.y, o.z)
  lg.setColor(0.08, 0.12, 0.22, 0.15 * (1 - fogk(o.z)))
  local gx, gy = P(o.x, 0, o.z); lg.ellipse('fill', gx, gy, 0.15 * s, 0.04 * s)
  local r = max(6, 0.3 * s)
  lg.setColor(1, 0.25, 0.2, 0.25 + 0.2 * sin(love.timer.getTime() * 20)); lg.circle('fill', x, y, r * 1.3)
  lg.setColor(1, 1, 1, 0.8); lg.setLineWidth(2); lg.circle('line', x, y, r * 1.3)
  throwIcon(o.what, x, y, max(30, s * 2.6), o.rot, o.z)
end

-- a fishing boat tied up beside the quay (harbour)
local function trawler(e)
  local z0, z1 = e.z, e.z + 9
  local X = -14.2
  if z0 - cam.z < 1 then return end
  local c = hex(e.c or '1d3557')
  col(dk(c, 0.8), z0); lg.polygon('fill', q3({ X, -0.2, z0 + 0.6 }, { X, -0.2, z1 - 0.4 }, { X, 1.1, z1 }, { X, 1.1, z0 }))
  col(hex('fbfaf6'), z0); lg.polygon('fill', wallX(X - 0.01, 0.85, 1.1, z0, z1))
  col(hex('fbfaf6'), z0); lg.polygon('fill', wallX(X - 0.6, 1.1, 2.7, z0 + 5, z0 + 8))
  col(hex('2b3a4f'), z0)
  for k = 0, 2 do lg.polygon('fill', wallX(X - 0.62, 1.8, 2.3, z0 + 5.2 + k * 0.95, z0 + 5.9 + k * 0.95)) end
  col(hex('e63946'), z0); lg.polygon('fill', wallX(X - 0.62, 2.7, 2.9, z0 + 4.9, z0 + 8.1))
  local a, b = P(X - 0.6, 1.1, z0 + 2.5); local cc, d = P(X - 0.6, 7, z0 + 2.5)
  col(hex('5a5a5a'), z0); lg.setLineWidth(max(1, 0.08 * F / (z0 - cam.z))); lg.line(a, b, cc, d)
  local fx, fy = P(X - 0.6, 7, z0 + 4.5); lg.setLineWidth(1); lg.line(cc, d, fx, fy)
  col(hex('ffd166'), z0); lg.polygon('fill', cc, d, cc + 0.8 * F / (z0 - cam.z), d + 0.3 * F / (z0 - cam.z), cc, d + 0.6 * F / (z0 - cam.z))
end

local function decal(dc)
  local d = dc.z - cam.z
  local s = F / d
  local x, y = P(dc.x, 0, dc.z)
  local k = cam.y / d
  lg.setColor(0.99, 0.99, 0.97, 0.95 * (1 - fogk(dc.z)))
  lg.ellipse('fill', x, y, 0.32 * s, 0.32 * s * k + 0.5)
  lg.ellipse('fill', x + 0.25 * s, y - 0.1 * s * k, 0.14 * s, 0.14 * s * k + 0.3)
  lg.ellipse('fill', x - 0.28 * s, y + 0.08 * s * k, 0.1 * s, 0.1 * s * k + 0.3)
end

---------------------------------------------------------------- the whole view
local objs = {}
local KIND = { house = house, sign = shopSign, lamp = lamp, bench = bench, bin = bin, wind = windbreak, chair = lifeguardChair,
  pier = pier, boat = sailboat, car = car, person = person, item = item, drop = drop, jet = jet, throw = thrown, trawler = trawler }

-- g: the stage (lists of things), t: clock
function W.draw(g, t)
  poolN = 0
  for i = #overlay, 1, -1 do overlay[i] = nil end
  for i = #glows, 1, -1 do glows[i] = nil end
  sky()
  sea(t)
  groundLayers()
  for _, dc in ipairs(g.decals) do if dc.z - cam.z > 1 and dc.z - cam.z < 120 then decal(dc) end end
  -- the drop zone ring
  local rt = g.ret
  if rt and rt.z - cam.z > 1 then
    local d = rt.z - cam.z
    local s = F / d
    local x, y = P(rt.x, 0, rt.z)
    local k = cam.y / d
    local c = rt.lock and { 1, 0.25, 0.2 } or { 1, 1, 1 }
    lg.setColor(c[1], c[2], c[3], 0.18); lg.ellipse('fill', x, y, 0.85 * s, 0.85 * s * k)
    lg.setColor(c[1], c[2], c[3], 0.95); lg.setLineWidth(2.5); lg.ellipse('line', x, y, 0.85 * s, 0.85 * s * k)
    lg.setColor(1, 1, 1, 0.7); lg.setLineWidth(1.5)
    for q = 0, 5 do lg.arc('line', 'open', x, y, 1.25 * s, q * pi / 3, q * pi / 3 + pi / 6) end
    lg.setColor(c[1], c[2], c[3], 0.95); lg.setLineWidth(2)
    lg.line(x - 1.0 * s, y, x - 1.5 * s, y); lg.line(x + 1.0 * s, y, x + 1.5 * s, y)
    lg.line(x, y - 1.0 * s * k, x, y - 1.5 * s * k); lg.line(x, y + 1.0 * s * k, x, y + 1.5 * s * k)
  end

  local n = 0
  local function add(z, kind, e)
    local d = z - cam.z
    if d > 0.95 and d < 420 then
      n = n + 1
      local o = objs[n]
      if not o then o = {}; objs[n] = o end
      o.z, o.kind, o.e = z, kind, e
    end
  end
  for _, h in ipairs(g.houses) do
    if h.z1 - cam.z > 1 and h.z0 - cam.z < 520 then
      n = n + 1
      local o = objs[n]; if not o then o = {}; objs[n] = o end
      o.z, o.kind, o.e = max(h.z0, cam.z + 1) + 0.5, 'house', h
      if h.shop then add(h.z0 + 0.3, 'sign', { h = h }) end
    end
  end
  for _, list in ipairs({ g.lamps, g.benches, g.bins, g.winds, g.chairs, g.boats, g.piers, g.people, g.items, g.drops, g.jets, g.throws, g.trawlers }) do
    for _, e in ipairs(list) do
      if not e.gone and not (e.kind == 'person' and e.z - cam.z < 1.8) then add(e.z + (e.zo or 0), e.kind, e) end
    end
  end
  for _, c in ipairs(g.cars) do add(c.z, 'car', c) end
  -- railing segments (made on the fly)
  local zz = math.ceil((cam.z + 1) / 1.9) * 1.9
  local railN0 = n
  while zz < cam.z + 170 do
    n = n + 1
    local o = objs[n]; if not o then o = {}; objs[n] = o end
    o.z, o.kind, o.e = zz, 'rail', zz
    zz = zz + 1.9
  end
  for i = n + 1, #objs do objs[i] = nil end
  table.sort(objs, function(a, b) return a.z > b.z end)
  -- the far railing as one line
  do
    local a, b = P(-8.35, 1.1, cam.z + 170); local c, d = P(-8.35, 1.1, cam.z + 4000)
    col(RAIL, cam.z + 170); lg.setLineWidth(1); lg.line(a, b, c, d)
  end
  for i = 1, #objs do
    local o = objs[i]
    if o.kind == 'rail' then railSeg(o.e, o.e + 1.9)
    else KIND[o.kind](o.e) end
  end

  -- evening / night: tint everything, then add the lights
  if T.tint then
    lg.setBlendMode('multiply', 'premultiplied')
    lg.setColor(T.tint[1], T.tint[2], T.tint[3], 1)
    lg.rectangle('fill', -600, -600, 2400, 1700)
    lg.setBlendMode('alpha')
  end
  if #glows > 0 or T.moon then
    lg.setBlendMode('add')
    for _, gl in ipairs(glows) do
      lg.setColor(1, 0.78, 0.4, 0.13 * gl[4]); lg.circle('fill', gl[1], gl[2], gl[3] * 1.6)
      lg.setColor(1, 0.85, 0.5, 0.22 * gl[4]); lg.circle('fill', gl[1], gl[2], gl[3] * 0.7)
    end
    if T.moon then
      local mx, my = cam.cx - 320 - cam.x * 1.2 + W.SUNX, cam.hz - 170 + W.SUNY
      lg.setColor(0.8, 0.85, 1, 0.5); lg.circle('fill', mx, my, 15)
      lg.setColor(0.6, 0.7, 1, 0.08); lg.circle('fill', mx, my, 60)
    end
    lg.setBlendMode('alpha')
  end

  -- things over the top: lock marker, speech bubbles, score pop-ups
  if g.lock and not g.lock.gone and g.lock.hx then
    local mx, my = g.lock.hx, g.lock.htop - 8
    lg.setColor(0.06, 0.08, 0.16, 0.9); lg.polygon('fill', mx - 9, my - 13, mx + 9, my - 13, mx, my + 1)
    lg.setColor(1, 0.3, 0.25); lg.polygon('fill', mx - 6.5, my - 11.5, mx + 6.5, my - 11.5, mx, my - 1.5)
  end
  for _, o in ipairs(overlay) do
    if o.say == '!' then  -- a thrower winding up: a big red warning
      local wx, wy = o.hx, o.htop - 22
      local pulse = 1 + 0.15 * sin(love.timer.getTime() * 25)
      lg.setColor(0.06, 0.08, 0.16, 0.9); lg.circle('fill', wx, wy, 13 * pulse)
      lg.setColor(1, 0.25, 0.2); lg.circle('fill', wx, wy, 11 * pulse)
      U.otext('!', 17, wx, wy - 11, { 1, 1, 1 }, 'center', 1, 1)
    else
      local f = U.f[11]
      local w = f:getWidth(o.say) + 12
      local x, y = o.hx - w / 2, o.htop - 30
      local a = min(1, o.sayT * 3)
      lg.setColor(1, 1, 1, 0.95 * a); lg.rectangle('fill', x, y, w, 18, 8, 8, 10)
      lg.polygon('fill', o.hx - 4, y + 17, o.hx + 4, y + 17, o.hx, y + 23)
      lg.setFont(f); lg.setColor(0.1, 0.12, 0.2, a); lg.print(o.say, x + 6, y + 2)
    end
  end
  for _, p in ipairs(g.pops) do
    local d = p.z - cam.z
    if d > 1 then
      local x, y = P(p.x, p.y, p.z)
      local a = min(1, p.t * 2.5)
      U.otext(p.text, p.size or 17, x, y - (1.2 - p.t) * 40, p.c or { 1, 0.84, 0.25 }, 'center', a)
      if p.sub then U.otext(p.sub, 13, x, y - (1.2 - p.t) * 40 + 20, { 1, 1, 1 }, 'center', a) end
    end
  end
end

-- the gull's own wings and beak, fixed to the screen. flap: 0..1, VW: screen width
function W.drawGull(flap, VW)
  local a = sin(flap * pi * 2) * 0.07
  lg.setColor(1, 1, 1, 1)
  lg.push(); lg.translate(238, 480); lg.rotate(-a); lg.translate(-238, -480); lg.draw(wingC, -40, 320); lg.pop()
  lg.push(); lg.translate(VW, 0); lg.scale(-1, 1)
  lg.translate(238, 480); lg.rotate(-a); lg.translate(-238, -480); lg.draw(wingC, -40, 320); lg.pop()
  lg.draw(headC, VW / 2 - 90, 400)
end

function W.speedLines(t, amt)
  lg.setLineWidth(2)
  for k, a in ipairs({ 196, 204, 214, -16, -24, -36, 150, 30, 160, 20 }) do
    local r = math.rad(a)
    local dx, dy = cos(r), sin(r)
    local o = ((t * 3 + k * 0.37) % 1) * 120
    lg.setColor(1, 1, 1, 0.22 * amt)
    lg.line(cam.cx + dx * (300 + o), 200 + dy * (300 + o), cam.cx + dx * (380 + o), 200 + dy * (380 + o))
  end
end

return W
