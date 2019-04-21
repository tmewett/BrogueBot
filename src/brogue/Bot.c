#include <lua.h>
#include <lauxlib.h>
#include "Rogue.h"
#include "IncludeGlobals.h"

lua_State *L;
char *botScript = "";
boolean inGame = false;

static void die(char *s) {
    printf(s);
    exit(1);
}

void resetBot(char *filename) {
    if (L != NULL) lua_close(L);
    L = luaL_newstate();
    if (L == NULL) die("Cannot initialise Lua\n");
    if (luaL_dofile(L, filename)) die("Could not load bot script\n");
}

boolean botShouldAct() {
    return inGame && !rogue.playbackMode;
}
