// Builds the website version (love.js, "compatibility" mode so it works on GitHub Pages).
//   node build-web.mjs <folder>     -> writes the whole website into <folder> (e.g. the seagull-strike repo)
// It packs src/ into game.love (via build.py), wraps it for the browser and copies the page, icons and offline files.
import { execSync } from "node:child_process";
import crypto from "node:crypto";
import fs from "node:fs";
import path from "node:path";

const here = path.dirname(new URL(import.meta.url).pathname.replace(/^\/(\w:)/, "$1"));
const out = process.argv[2];
if (!out) throw new Error("Usage: node build-web.mjs <output folder>");
fs.mkdirSync(out, { recursive: true });

execSync("python build.py", { cwd: here, stdio: "inherit" });
const love = fs.readFileSync(path.join(here, "port", "seagullstrike", "seagullstrike.love"));

// game.data is the .love file; game.js tells the browser engine where to find it
fs.writeFileSync(path.join(out, "game.data"), love);
const meta = { package_uuid: crypto.randomUUID(), remote_package_size: love.length,
  files: [{ filename: "/game.love", crunched: 0, start: 0, end: love.length, audio: false }] };
const tpl = fs.readFileSync(path.join(here, "web", "engine", "game.template.js"), "utf8");
fs.writeFileSync(path.join(out, "game.js"), tpl.replace("{{{create_file_paths}}}", "").replace("{{{metadata}}}", JSON.stringify(meta)));
for (const f of ["love.js", "love.wasm", "LICENSE-love.js.txt"]) fs.copyFileSync(path.join(here, "web", "engine", f), path.join(out, f));
for (const f of ["index.html", "manifest.webmanifest", "icon-192.png", "icon-512.png", "apple-touch-icon.png", "share.png"]) {
  fs.copyFileSync(path.join(here, "web", f), path.join(out, f));
}
const version = new Date().toISOString().replace(/[-:T]/g, "").slice(0, 12);
fs.writeFileSync(path.join(out, "sw.js"), fs.readFileSync(path.join(here, "web", "sw.js"), "utf8").replace("__VERSION__", version));
console.log("website built in", out, "(cache", version + ")");
