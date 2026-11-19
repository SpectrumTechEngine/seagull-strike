-- Makes the website pictures: icon-512.png, icon-192.png, apple-touch-icon.png and share.png.
--   lovec tools/art <output folder> <screenshot.png>
local lg = love.graphics
local out, shotPath

local function hex(h, a) return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 } end
local function vtx(x, y, c) return { x, y, 0, 0, c[1], c[2], c[3], c[4] or 1 } end
local function vgrad(x, y, w, h, c1, c2)
  lg.setColor(1, 1, 1); lg.draw(lg.newMesh({ vtx(x, y, c1), vtx(x + w, y, c1), vtx(x + w, y + h, c2), vtx(x, y + h, c2) }, 'fan', 'static'))
end
local function poly(p) for _, t in ipairs(love.math.triangulate(p)) do lg.polygon('fill', t) end end

local function save(canvas, name)
  local png = canvas:newImageData():encode('png'):getString()
  local f = assert(io.open(out .. '/' .. name, 'wb')); f:write(png); f:close()
end

-- the gull's head, facing right, drawn in a 512 box
local function gull()
  -- shoulder / wing
  lg.setColor(hex('a7b4bf')); poly({ 40, 512, 60, 380, 150, 330, 250, 360, 300, 512 })
  lg.setColor(hex('1e2227')); poly({ 40, 512, 46, 450, 90, 470, 70, 512 })
  -- neck + head
  lg.setColor(hex('f4f7f9')); lg.ellipse('fill', 236, 360, 110, 130)
  lg.setColor(1, 1, 1); lg.circle('fill', 240, 240, 128)
  lg.setColor(hex('dfe5ea')); lg.arc('fill', 240, 240, 128, math.pi * 0.25, math.pi * 0.75)
  lg.setColor(1, 1, 1); lg.ellipse('fill', 240, 236, 118, 118)
  -- beak
  lg.setColor(hex('f6c22c')); poly({ 330, 220, 430, 236, 452, 250, 444, 268, 420, 262, 330, 268 })
  lg.setColor(hex('e3a514')); poly({ 330, 248, 420, 254, 444, 268, 420, 280, 330, 276 })
  lg.setColor(hex('d28d0e')); poly({ 430, 236, 452, 250, 450, 272, 438, 262 })
  lg.setColor(hex('e2452c')); lg.circle('fill', 410, 266, 9)
  lg.setColor(hex('8a5a10')); lg.setLineWidth(5); lg.line(330, 249, 410, 254)
  -- eye + angry brow
  lg.setColor(hex('ffd166')); lg.circle('fill', 300, 205, 17)
  lg.setColor(hex('111317')); lg.circle('fill', 304, 205, 9)
  lg.setColor(1, 1, 1); lg.circle('fill', 307, 201, 3)
  lg.setColor(hex('5f6b76')); lg.setLineWidth(12); lg.line(268, 172, 330, 190)
end

local function icon(size, name, round)
  local c = lg.newCanvas(512, 512, { msaa = 8 })
  lg.setCanvas({ c, stencil = true }); lg.clear(0, 0, 0, 0)
  if round then lg.stencil(function() lg.rectangle('fill', 0, 0, 512, 512, 96, 96, 40) end, 'replace', 1); lg.setStencilTest('greater', 0) end
  vgrad(0, 0, 512, 380, hex('2f7fd0'), hex('a9dcf3'))
  vgrad(0, 380, 512, 132, hex('2a8fc4'), hex('17639e'))
  lg.setColor(1, 0.97, 0.85, 0.9); lg.circle('fill', 96, 96, 40)
  lg.push(); lg.translate(256, 256); lg.scale(0.86); lg.translate(-256, -250); gull(); lg.pop()
  -- a drop on its way down
  lg.setColor(1, 1, 1); lg.circle('fill', 400, 410, 22); lg.polygon('fill', 381, 398, 419, 398, 400, 360)
  lg.setStencilTest()
  lg.setCanvas()
  local o = lg.newCanvas(size, size)
  lg.setCanvas(o); lg.clear(0, 0, 0, 0); lg.setColor(1, 1, 1); lg.draw(c, 0, 0, 0, size / 512, size / 512); lg.setCanvas()
  save(o, name)
end

local function share()
  local W, H = 1200, 630
  local c = lg.newCanvas(W, H, { msaa = 4 })
  lg.setCanvas(c); lg.clear(0, 0, 0, 1)
  local img = lg.newImage(love.filesystem.newFileData(assert(io.open(shotPath, 'rb')):read('*a'), 'shot.png'))
  local s = W / img:getWidth()
  lg.setColor(1, 1, 1); lg.draw(img, 0, H / 2 - img:getHeight() * s / 2, 0, s, s)
  vgrad(0, 0, W, H, { 0.02, 0.06, 0.12, 0.15 }, { 0.02, 0.06, 0.12, 0.65 })
  local big, mid = lg.newFont(110), lg.newFont(34)
  local function otext(str, f, x, y, col)
    lg.setFont(f)
    local w = f:getWidth(str)
    lg.setColor(0.06, 0.08, 0.16)
    for dx = -6, 6, 2 do for dy = -6, 6, 2 do lg.print(str, x - w / 2 + dx, y + dy) end end
    lg.setColor(col); lg.print(str, x - w / 2, y)
  end
  otext('SEAGULL STRIKE', big, W / 2, 360, { 1, 0.84, 0.25 })
  otext('Eat chips. Drop on people. Taken extremely seriously.', mid, W / 2, 500, { 1, 1, 1 })
  lg.setCanvas()
  save(c, 'share.png')
end

function love.load(args)
  out, shotPath = args[1], args[2]
  icon(512, 'icon-512.png', false)
  icon(192, 'icon-192.png', false)
  icon(180, 'apple-touch-icon.png', false)
  share()
  love.event.quit()
end
