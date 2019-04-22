#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "Rogue.h"
#include "IncludeGlobals.h"

#define QUEUE_LEN 16

static lua_State *L = NULL;
char *botScript = "";
boolean inGame = false;

static struct {
    rogueEvent events[QUEUE_LEN];
    int start;
    int end;
} eventQueue;

static void pushEvent(rogueEvent ev) {
    eventQueue.events[eventQueue.end++] = ev;
    eventQueue.end %= QUEUE_LEN;
}

static void pushKey(signed long key) {
    pushEvent((rogueEvent){KEYSTROKE, key, 0, false, false});
}

static void die(char *s) {
    printf(s);
    exit(1);
}

boolean botShouldAct() {
    return inGame && !rogue.playbackMode;
}

void nextBotEvent(rogueEvent *returnEvent) {
    returnEvent->eventType = EVENT_ERROR;

    if (eventQueue.start != eventQueue.end) {
        *returnEvent = eventQueue.events[eventQueue.start++];
        eventQueue.start %= QUEUE_LEN;
    } else {
        lua_getglobal(L, "pushevents");
        if (lua_pcall(L, 0, 0, 0)) {
            // there's an error object on stack; print it to message log
            inGame = false;
            message(luaL_checkstring(L, -1), false);
            dialogAlert("Error occured in Lua interpreter. Stopping bot. See message log for details.");
        } else {
            // the queue is no longer empty, so re-run
            nextBotEvent(returnEvent);
        }
    }
}

static int l_stepto(lua_State *L) {
    lua_Integer dir = luaL_checkinteger(L, 1);
    switch ((enum directions)dir) {
        case UP        : pushKey(UP_KEY); break;
        case DOWN      : pushKey(DOWN_KEY); break;
        case LEFT      : pushKey(LEFT_KEY); break;
        case RIGHT     : pushKey(RIGHT_KEY); break;
        case UPLEFT    : pushKey(UPLEFT_KEY); break;
        case DOWNLEFT  : pushKey(DOWNLEFT_KEY); break;
        case UPRIGHT   : pushKey(UPRIGHT_KEY); break;
        case DOWNRIGHT : pushKey(DOWNRIGHT_KEY); break;
        default:
            luaL_error(L, "invalid direction");
            break;
    }
    return 0;
}

static luaL_Reg reg[] = {
    {"stepto", l_stepto},
    {NULL, NULL},
};

void resetBot(char *filename) {
    eventQueue.start = eventQueue.end = 0;
    if (L != NULL) lua_close(L);
    L = luaL_newstate();
    if (L == NULL) die("Cannot initialise Lua\n");
    luaL_openlibs(L);
    lua_pushglobaltable(L);
    luaL_setfuncs(L, reg, 0);
    if (luaL_dofile(L, filename)) die("Could not load bot script\n");
}
