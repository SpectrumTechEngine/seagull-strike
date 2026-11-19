#!/bin/bash
# Seagull Strike (console edition) - PortMaster launcher

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/" ]; then
  controlfolder="$XDG_DATA_HOME/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

source $controlfolder/control.txt
[ -f "${controlfolder}/mod_${CFW_NAME}.txt" ] && source "${controlfolder}/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="/$directory/ports/seagullstrike"

cd "$GAMEDIR"
> "$GAMEDIR/log.txt" && exec > >(tee "$GAMEDIR/log.txt") 2>&1

# saves (settings) stay in the game's own folder
export XDG_DATA_HOME="$GAMEDIR/conf"
mkdir -p "$XDG_DATA_HOME"

export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"
# the buttons reach the game as keys (see seagullstrike.gptk)
export SEAGULL_GPTK=1

source $controlfolder/runtimes/"love_11.5"/love.txt

$GPTOKEYB "$LOVE_GPTK" -c "$GAMEDIR/seagullstrike.gptk" &
pm_platform_helper "$LOVE_BINARY"

$LOVE_RUN "$GAMEDIR/seagullstrike.love"

pm_finish
