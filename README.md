# [Magnavox Odyssey2/Videopac](https://en.wikipedia.org/wiki/Magnavox_Odyssey_2) for [MiSTer Platform](https://github.com/MiSTer-devel/Main_MiSTer/wiki) 

### This is an FPGA implementation of the Magnavox Odyssey2 based on [FPGA Videopac](http://www.fpgaarcade.com/?q=node%2F14) by Arnim Laeuger and ported to MiSTer (With additional work from wsoltys).

## Features
 * Switch between Odyssey2 and Videopac mode.
 * Fully working keyboard.
 * Joystick buttons for keys 0-9.

## Installation
Copy the Odyssey2_\*.rbf file to the root of the SD card. Create an **Odyssey2** folder on the root of the card, and place Odyssey2 roms (\*.BIN) inside this folder. When loading a ROM, most games will prompt the user with "SELECT GAME". Press 0-9 on the keyboard or mapped controller button to play the game. Unfortunately, there is no on-screen display of the game options, so looking at the [instruction manuals](https://videopac.weebly.com/) may be helpful in selecting a game. Note that the system did not have a well defined player 1 or player 2 controller, they would alternate on a game-to-game basis. You may need to swap controllers to use the input.

## System Differences
The American Odyssey2 runs about 20% faster than the European Videopac. This is true to the original systems, and is not a bug. Some games, like Frogger, will not display correctly on Odyssey2. Each system will output its native video mode, so NTSC for Odyssey2, and PAL for Videopac. This may impact the aspect ratio of games and the refresh rate, as it did on the original systems.

## Known Issues
The sound is not ideal. Many people will find it acceptable, but it is something that could use work in the future. Also, if you mash multiple number keys on the joystick at once, one of the keys may be stuck down until you press that button again. A few games (gunfighter) don't work at this time.
