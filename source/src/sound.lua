-- Every sound and the music are made by the game itself when it starts (no sound files).
local S = { on = true, music = true }
local RATE = 22050
local src = {}
local rnd = love.math.random
local sin, pi, floor, min = math.sin, math.pi, math.floor, math.min

local function buf(d) local n = floor(d * RATE); local t = { n = n }; for i = 1, n do t[i] = 0 end; return t end
local function coeffs(kind, f, q)
  q = q or (kind == 'bandpass' and 1 or .7071)
  local w0 = 2 * pi * min(f, RATE * .45) / RATE
  local cs, sn = math.cos(w0), math.sin(w0)
  local al = sn / (2 * q)
  local b0, b1, b2
  if kind == 'lowpass' then b0 = (1 - cs) / 2; b1 = 1 - cs; b2 = (1 - cs) / 2
  elseif kind == 'highpass' then b0 = (1 + cs) / 2; b1 = -(1 + cs); b2 = (1 + cs) / 2
  else b0 = al; b1 = 0; b2 = -al end
  local a0 = 1 + al
  return b0 / a0, b1 / a0, b2 / a0, (-2 * cs) / a0, (1 - al) / a0
end
local function filter(x, n, kind, f, q)
  local b0, b1, b2, a1, a2 = coeffs(kind, f, q)
  local x1, x2, y1, y2 = 0, 0, 0, 0
  for i = 1, n do
    local v = x[i]
    local y = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
    x2 = x1; x1 = v; y2 = y1; y1 = y
    x[i] = y
  end
end
local function osc(typ, p)
  p = p % 1
  if typ == 'square' then return p < .5 and 1 or -1
  elseif typ == 'sawtooth' then return 2 * p - 1
  elseif typ == 'triangle' then return 1 - 4 * math.abs(p - .5) end
  return sin(2 * pi * p)
end
local function add(t, x, n, delay)
  local s0 = floor((delay or 0) * RATE)
  for i = 1, n do local j = s0 + i; if j <= t.n then t[j] = t[j] + x[i] end end
end
local function sweep(t, typ, f1, f2, d, v, delay)
  local n, ph, x = floor(d * RATE), 0, {}
  for i = 0, n - 1 do
    local k = i / n
    ph = ph + (f1 * (f2 / f1) ^ k) / RATE
    x[i + 1] = osc(typ, ph) * v * (1 - k) ^ 2 * min(1, i / 40)
  end
  add(t, x, n, delay)
end
local function noise(t, d, v, freq, kind, delay, q, shape)
  local n, x = floor(d * RATE), {}
  for i = 1, n do x[i] = (rnd() * 2 - 1) end
  filter(x, n, kind or 'lowpass', freq, q)
  for i = 1, n do
    local k = (i - 1) / n
    local env = shape == 'swell' and sin(k * pi) or (1 - k) ^ 2
    x[i] = x[i] * v * env
  end
  add(t, x, n, delay)
end
local function make(name, t, gain)
  gain = gain or 1
  local sd = love.sound.newSoundData(t.n, RATE, 16, 1)
  for i = 1, t.n do
    local v = t[i] * gain
    if v > 1 then v = 1 elseif v < -1 then v = -1 end
    sd:setSample(i - 1, v)
  end
  src[name] = love.audio.newSource(sd, 'static')
end

-- a gull's cry: a buzzy voice sliding down, "kee-ow"
local function cry(t, f1, f2, d, v, delay)
  local n = floor(d * RATE)
  local x, y, ph = {}, {}, 0
  for i = 1, n do
    local k = (i - 1) / n
    local f = f1 + (f2 - f1) * (k < .25 and k / .25 * .3 or .3 + (k - .25) / .75 * .7)
    ph = ph + f * (1 + .02 * sin(2 * pi * i / RATE * 30)) / RATE
    local env = min(1, k / .05) * (1 - k) ^ .7
    x[i] = osc('sawtooth', ph) * env; y[i] = x[i]
  end
  filter(x, n, 'bandpass', 1500, 1.4); filter(y, n, 'bandpass', 3200, 2.2)
  for i = 1, n do x[i] = (x[i] * 1.5 + y[i] * .7) * v end
  add(t, x, n, delay)
end

local function mtof(m) return 440 * 2 ^ ((m - 69) / 12) end
local function song(name, bpm, bass, lead, gain, leadWave)
  local step = 60 / bpm / 2
  local steps = #lead
  local t = buf(step * steps)
  local n = t.n
  local x = {}
  for i = 1, n do x[i] = 0 end
  local ph = { 0, 0, 0 }
  local sl = floor(step * RATE)
  for s = 0, steps - 1 do
    local b, l = bass[s % #bass + 1], lead[s + 1]
    local fb = b > 0 and mtof(b) or 0
    local fl = l > 0 and mtof(l) or 0
    for i = 1, sl do
      local j = s * sl + i
      if j > n then break end
      local k = i / sl
      local v = 0
      if fb > 0 then ph[1] = ph[1] + fb / RATE; v = v + osc('triangle', ph[1]) * .3 * (1 - k * .6) end
      if fl > 0 then
        ph[2] = ph[2] + fl / RATE; ph[3] = ph[3] + fl * 2.003 / RATE
        v = v + (osc(leadWave or 'square', ph[2]) * .085 + osc('triangle', ph[3]) * .05) * (1 - k * .5)
      end
      x[j] = v
    end
  end
  filter(x, n, 'lowpass', 3800)
  for i = 1, n do t[i] = x[i] end
  for s = 0, steps - 1 do
    local at = s * step
    if s % 4 == 0 then sweep(t, 'sine', 130, 45, .14, .45, at) end
    if s % 4 == 2 then noise(t, .1, .22, 2600, 'bandpass', at, .8) end
    noise(t, .025, .07, 8000, 'highpass', at)
  end
  make(name, t, gain or 1)
  src[name]:setLooping(true)
end

function S.load()
  local t
  t = buf(.9); cry(t, 1300, 800, .32, .9); cry(t, 1250, 760, .28, .8, .3); cry(t, 1150, 650, .3, .6, .56); make('squawk', t, 1.2)
  t = buf(.5); cry(t, 900, 500, .4, .9); make('hurtcry', t, 1.3)
  t = buf(.2); sweep(t, 'sine', 900, 300, .15, .6); make('plop', t)
  t = buf(.4); noise(t, .2, .9, 900, 'lowpass'); sweep(t, 'sine', 220, 60, .18, .8); noise(t, .12, .4, 3000, 'bandpass', .02, 2); make('splat', t, 1.3)
  t = buf(.3); noise(t, .2, .5, 600, 'lowpass'); sweep(t, 'sine', 140, 60, .12, .4); make('miss', t)
  t = buf(.5); for k = 0, 3 do noise(t, .05, .7, 2500, 'bandpass', k * .09, 2) end; sweep(t, 'sine', 300, 120, .12, .4, .38); make('chomp', t)
  t = buf(.6); noise(t, .55, .6, 700, 'bandpass', 0, .7, 'swell'); make('whoosh', t)
  t = buf(.5); for k = 0, 2 do noise(t, .14, .55, 380, 'lowpass', k * .15, 1, 'swell') end; make('flap', t, 1.3)
  t = buf(.3); noise(t, .12, 1, 2400, 'bandpass', 0, 1.2); sweep(t, 'sine', 180, 70, .1, .7); make('thwack', t, 1.2)
  t = buf(.5); noise(t, .45, .6, 4500, 'highpass', 0, nil, 'swell'); make('squirt', t)
  t = buf(.5); sweep(t, 'sine', 2600, 2500, .45, .25); for k = 0, 8 do sweep(t, 'sine', 2900, 2900, .03, .15, k * .05) end; make('whistle', t)
  t = buf(.5); for k = 0, 3 do sweep(t, 'square', 880, 880, .1, .12, k * .12) end; make('alarm', t)
  t = buf(.3); sweep(t, 'square', 1046, 1046, .1, .12); sweep(t, 'square', 1318, 1318, .16, .12, .08); make('ding', t)
  t = buf(.25); sweep(t, 'sine', 600, 600, .08, .2); sweep(t, 'sine', 600, 600, .08, .2, .12); make('warn', t)
  t = buf(.25); noise(t, .08, .25, 2200, 'bandpass', 0, 1.5); sweep(t, 'square', 1200, 1200, .06, .07, .08); make('radio', t)
  t = buf(1.2); for k, f in ipairs({ 523, 659, 784, 1046 }) do sweep(t, 'square', f, f, .35, .12, (k - 1) * .13) end; make('fanfare', t)
  t = buf(1.4); for k, f in ipairs({ 392, 370, 349, 262 }) do sweep(t, 'triangle', f, f * .98, .5, .3, (k - 1) * .26) end; make('sad', t)
  t = buf(.06); sweep(t, 'square', 660, 660, .05, .12); make('select', t)
  t = buf(.18); sweep(t, 'square', 660, 660, .07, .15); sweep(t, 'square', 990, 990, .1, .15, .07); make('confirm', t)
  t = buf(.18); sweep(t, 'square', 500, 300, .15, .14); make('back', t)
  t = buf(.35); sweep(t, 'sine', 400, 1200, .3, .3); make('blocked', t)
  -- the sea: slow waves breaking (loops every 6 s)
  do
    local n = 6 * RATE
    local x = { n = n }
    for i = 1, n do x[i] = rnd() * 2 - 1 end
    filter(x, n, 'lowpass', 900)
    for i = 1, n do local tt = (i - 1) / RATE; x[i] = x[i] * (.25 + .2 * sin(2 * pi * tt / 3) ^ 2) end
    make('sea', x, 1)
  end
  -- wind past the feathers
  do
    local n = 3 * RATE
    local x = { n = n }
    for i = 1, n do x[i] = rnd() * 2 - 1 end
    filter(x, n, 'bandpass', 500, .5)
    for i = 1, n do local tt = (i - 1) / RATE; x[i] = x[i] * (.5 + .15 * sin(2 * pi * tt / 1.5)) end
    make('wind', x, 1)
  end
  -- title tune: a jaunty seaside polka in C
  local bassM = { 36, 0, 43, 0, 36, 0, 43, 0, 41, 0, 48, 0, 43, 0, 50, 0 }
  local leadM = {
    72, 76, 79, 76, 84, 0, 79, 0, 77, 81, 84, 81, 79, 0, 76, 0,
    72, 76, 79, 76, 84, 83, 81, 79, 77, 76, 74, 72, 74, 0, 79, 0,
    76, 77, 79, 0, 81, 79, 77, 76, 74, 76, 77, 0, 79, 77, 76, 74,
    72, 76, 79, 84, 83, 79, 77, 74, 72, 0, 67, 0, 72, 0, 0, 0 }
  song('musicMenu', 184, bassM, leadM, .8, 'square')
  -- the mission tune: G minor, marching but daft
  local bassR = { 43, 43, 50, 43, 46, 46, 53, 46, 41, 41, 48, 41, 38, 38, 45, 50 }
  local leadR = {
    67, 0, 67, 70, 74, 0, 72, 70, 69, 0, 65, 0, 67, 0, 0, 0,
    67, 0, 67, 70, 74, 0, 77, 74, 72, 70, 69, 70, 67, 0, 0, 0,
    74, 0, 74, 75, 77, 0, 75, 74, 72, 0, 70, 72, 74, 0, 69, 0,
    70, 0, 69, 67, 65, 67, 69, 70, 67, 0, 62, 0, 67, 0, 0, 0 }
  song('musicStage', 150, bassR, leadR, .7, 'square')
end

function S.play(name, pitch, vol)
  if not S.on or not src[name] then return nil end
  local s = src[name]:clone()
  s:setPitch(pitch or 1); s:setVolume(min(1, vol or 1))
  s:play()
  return s
end

local LOOPS = { 'sea', 'wind' }
function S.loop(name, vol, pitch)
  local s = src[name]
  if not s then return end
  if not S.on or (vol or 1) <= 0 then if s:isPlaying() then s:stop() end; return end
  s:setVolume(min(1, vol or 1)); if pitch then s:setPitch(pitch) end
  if not s:isPlaying() then s:setLooping(true); s:play() end
end
function S.loopStop(name) local s = src[name]; if s and s:isPlaying() then s:stop() end end
function S.allLoopsStop() for _, n in ipairs(LOOPS) do S.loopStop(n) end end

local current, currentName
function S.musicPlay(name)
  if currentName == name and current and current:isPlaying() then return end
  if current then current:stop() end
  current, currentName = nil, name
  if not S.music or not src[name] then return end
  current = src[name]
  current:setVolume(.35)
  current:play()
end
function S.musicStop() if current then current:stop() end; current = nil; currentName = nil end
function S.refresh()
  local n = currentName; S.musicStop(); if n then S.musicPlay(n) end
  if not S.on then S.allLoopsStop() end
end

return S
