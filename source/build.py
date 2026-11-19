# Builds the PortMaster port: zips src/ into port/seagullstrike/seagullstrike.love and makes sure the
# console's script files use Linux line endings. Optional: pass a drive (e.g. F:) to copy it to the SD card.
#   python build.py        -> just build
#   python build.py F:     -> build and copy to F:\ports
import os, sys, zipfile, shutil

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, 'src')
PORT = os.path.join(HERE, 'port')
SH = 'Seagull Strike.sh'

love = os.path.join(PORT, 'seagullstrike', 'seagullstrike.love')
with zipfile.ZipFile(love, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in sorted(os.listdir(SRC)):
        p = os.path.join(SRC, name)
        if os.path.isfile(p):
            z.write(p, name)
print('built', love, os.path.getsize(love), 'bytes')

for rel in [SH, os.path.join('seagullstrike', 'seagullstrike.gptk'), os.path.join('seagullstrike', 'port.json')]:
    p = os.path.join(PORT, rel)
    data = open(p, 'rb').read().replace(b'\r\n', b'\n')
    open(p, 'wb').write(data)

if len(sys.argv) > 1:
    dest = os.path.join(sys.argv[1] + os.sep, 'ports')
    if not os.path.isdir(dest):
        sys.exit('No ports folder at ' + dest)
    shutil.copyfile(os.path.join(PORT, SH), os.path.join(dest, SH))
    gd = os.path.join(dest, 'seagullstrike')
    os.makedirs(gd, exist_ok=True)
    for name in ['seagullstrike.love', 'seagullstrike.gptk', 'port.json']:
        shutil.copyfile(os.path.join(PORT, 'seagullstrike', name), os.path.join(gd, name))
    print('copied to', dest)
