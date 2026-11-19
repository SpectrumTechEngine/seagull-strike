-- Shared drawing helpers: fonts, colours, panels, text, Sergeant Gannet's portrait.
local U = {}
local lg = love.graphics

U.f = {}
function U.load()
  for _, s in ipairs({ 10, 11, 13, 15, 17, 22, 28, 40, 60 }) do U.f[s] = lg.newFont(s) end
end

function U.hex(h, a)
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 }
end
local hex = U.hex

function U.panel(x, y, w, h, a)
  lg.setColor(0.03, 0.09, 0.16, a or 0.66); lg.rectangle('fill', x, y, w, h, 12, 12, 16)
  lg.setColor(1, 1, 1, 0.14); lg.setLineWidth(1); lg.rectangle('line', x + 0.5, y + 0.5, w - 1, h - 1, 12, 12, 16)
end

local function place(font, str, x, align)
  if align == 'center' then return x - font:getWidth(str) / 2 elseif align == 'right' then return x - font:getWidth(str) end
  return x
end

-- text with a soft drop shadow
function U.text(str, size, x, y, c, align, a)
  local f = U.f[size]; lg.setFont(f)
  x = place(f, str, x, align)
  lg.setColor(0, 0, 0, 0.4 * (a or 1)); lg.print(str, x + 1, y + 2)
  lg.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1)); lg.print(str, x, y)
end

-- text with a dark outline (for things floating over the world)
function U.otext(str, size, x, y, c, align, a, thick)
  local f = U.f[size]; lg.setFont(f)
  x = place(f, str, x, align)
  local t = thick or 2
  lg.setColor(0.06, 0.08, 0.16, 0.95 * (a or 1))
  for dx = -t, t do for dy = -t, t do
    if dx * dx + dy * dy <= t * t + 1 and (dx ~= 0 or dy ~= 0) then lg.print(str, x + dx, y + dy) end
  end end
  lg.setColor(c[1], c[2], c[3], (c[4] or 1) * (a or 1)); lg.print(str, x, y)
end

function U.wrap(str, size, w)
  local _, lines = U.f[size]:getWrap(str, w)
  return lines
end

-- Sergeant Gannet in a round frame (r = radius)
function U.gannet(cx, cy, r)
  local k = r / 22
  lg.stencil(function() lg.circle('fill', cx, cy, r) end, 'replace', 1)
  lg.setStencilTest('greater', 0)
  lg.setColor(hex('2a9d8f')); lg.circle('fill', cx, cy, r)
  lg.setColor(1, 1, 1); lg.ellipse('fill', cx - 2 * k, cy + 23 * k, 18 * k, 14 * k)
  lg.setColor(0.96, 0.97, 0.98); lg.circle('fill', cx - 2 * k, cy + 3 * k, 12 * k)
  lg.setColor(hex('f2c230')); lg.polygon('fill', cx + 7 * k, cy - 1 * k, cx + 22 * k, cy + 3 * k, cx + 20 * k, cy + 6 * k, cx + 7 * k, cy + 7 * k)
  lg.setColor(hex('e2452c')); lg.circle('fill', cx + 17 * k, cy + 5.5 * k, 1.6 * k)
  lg.setColor(0.1, 0.1, 0.12); lg.circle('fill', cx + 3 * k, cy - 1 * k, 1.9 * k)
  lg.setLineWidth(2 * k); lg.line(cx - 2 * k, cy - 5.5 * k, cx + 7 * k, cy - 3.5 * k)
  lg.setColor(hex('2d6a4f')); lg.push(); lg.translate(cx - 5 * k, cy - 9 * k); lg.rotate(-0.25); lg.ellipse('fill', 0, 0, 14 * k, 6 * k); lg.pop()
  lg.setColor(hex('ffd166')); lg.circle('fill', cx - 13 * k, cy - 9 * k, 2.4 * k)
  lg.setStencilTest()
  lg.setColor(1, 1, 1, 0.5); lg.setLineWidth(1.5); lg.circle('line', cx, cy, r)
end

return U
