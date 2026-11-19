-- Seagull Strike (console edition)
function love.conf(t)
  t.identity = "seagullstrike"
  t.version = "11.0"
  t.window.title = "Seagull Strike"
  t.window.width = 640
  t.window.height = 480
  t.window.resizable = true
  t.window.vsync = 1
  t.window.stencil = true
  t.modules.physics = false
  t.modules.video = false
  t.accelerometerjoystick = false
  if love._os == 'Web' then   -- the website: a fixed 854 x 480 picture, scaled to fit by the page
    t.window.width = 854
    t.window.resizable = false
    t.window.vsync = nil
    t.window.stencil = nil
  end
end
if io and io.stdout then pcall(io.stdout.setvbuf, io.stdout, "no") end
