# Seagull Strike

You are a seagull over the prom at Ballyspray. Eat chips. Drop on people. Taken extremely seriously.

Play: https://thespectrumtechengine.com/seagull-strike/

- Made with LÖVE (Lua). The website runs it with love.js (compatibility mode, so it works on GitHub Pages).
- The same game runs on the K36 handheld as a PortMaster port.
- `source/` holds the game code, the K36 launcher and the build scripts:
  - `python build.py F:` builds the K36 port and copies it to the SD card.
  - `node build-web.mjs <folder>` builds this website (needs love.js's `compat` engine files in `web/engine/`).
- Every push to `main` also builds the Android app (see `android-app/README.md`).

© The Spectrum Tech Engine. All rights reserved. The love.js engine files are under their own licence (`LICENSE-love.js.txt`).
