# BrogueBot

BrogueBot is a modification which adds a control API to the roguelike game [Brogue](https://sites.google.com/site/broguegame/). It allows writing Lua programs which can inspect the game state, take actions, and hence play the game completely automatically.

## Installation

Download a release archive, or clone the *release* branch with

	$ git clone -b release <url>

In general, any build for Brogue can be modified to build BrogueBot like so:

1. Install Lua 5.3 or later
2. Replace the Brogue source with the files in *src/brogue* and the platform-dependent source with the files in *src/platform*
3. Add *Bot.c* as a source file in the build system
4. Build and run as normal

Brogue contains some build instructions for the platform it is downloaded for; refer to those for further details.

The repo is set up for Linux (and maybe Linux-like build environments, untested), so in that case you can build directly:

1. Install Lua 5.3 or later
2. Run either `make curses`, `make tcod`, or `make both`

The curses build requires ncurses. For the TCOD build, a recent libtcod source directory must be placed as *src/libtcod-1.5.2*. (This can be copied/symlinked from a recent Brogue release.) Also, to run the TCOD build, the compiled libtcod library must be copied/linked to *bin*. On Linux this means *src/libtcod-1.5.2/libtcod.so* must be copied to *bin/libtcod.so.1*.

## Usage

As *bin* contains all the Lua files, BrogueBot should be run with that as the current working directory. In Linux-like environments, execute `cd bin; ./brogue`.

See the [User's Guide](https://github.com/tmewett/BrogueBot/wiki/User-Guide) for more information.

Personal suggestion: check out [lua-stdlib](https://github.com/lua-stdlib/lua-stdlib) for a useful general Lua library, and [Awesome Lua](https://github.com/LewisJEllis/awesome-lua) for a huge list of Lua utilites.
