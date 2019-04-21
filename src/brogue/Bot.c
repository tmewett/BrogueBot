#include <lua.h>
#include <lauxlib.h>
#include "Rogue.h"
#include "IncludeGlobals.h"

#define QUEUE_LEN 16

lua_State *L;
char *botScript = "";
boolean inGame = false;

struct {
    rogueEvent events[QUEUE_LEN];
    int start;
    int end;
} eventQueue;

void pushEvent(rogueEvent ev) {
    eventQueue.events[eventQueue.end++] = ev;
    eventQueue.end %= QUEUE_LEN;
}

void pushKey(signed long key) {
    pushEvent((rogueEvent){KEYSTROKE, key, 0, false, false});
}

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

void nextBotEvent(rogueEvent *returnEvent) {
    pushKey(UP_KEY);

    if (eventQueue.start != eventQueue.end) {
        *returnEvent = eventQueue.events[eventQueue.start++];
        eventQueue.start %= QUEUE_LEN;
    }
}
