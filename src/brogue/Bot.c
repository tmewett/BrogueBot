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

// push an item table onto the Lua stack
static void pushItem(lua_State *L, item *it) {
    lua_newtable(L);
    enum itemCategory c = it->category;
    char letter[2] = {it->inventoryLetter, 0};

    lua_pushinteger(L, c);
    lua_setfield(L, -2, "category");
    lua_pushinteger(L, it->kind);
    lua_setfield(L, -2, "kind");
    lua_pushinteger(L, it->flags);
    lua_setfield(L, -2, "flags");
    lua_pushinteger(L, it->quantity);
    lua_setfield(L, -2, "quantity");
    lua_pushstring(L, letter);
    lua_setfield(L, -2, "letter");
    lua_pushinteger(L, DROWS * it->xLoc + it->yLoc + 1);
    lua_setfield(L, -2, "cell");

    if (c==WEAPON || c==ARMOR) {
        lua_pushinteger(L, it->strengthRequired);
        lua_setfield(L, -2, "strength");
        lua_pushinteger(L, it->enchant2);
        lua_setfield(L, -2, "runic");
    }
    if (c==WEAPON || c==ARMOR || c==STAFF || c==WAND || c==CHARM || c==RING) {
        lua_pushinteger(L, it->charges);
        lua_setfield(L, -2, "charges");
        lua_pushinteger(L, it->enchant1);
        lua_setfield(L, -2, "enchant");
    }
    if (c==ARMOR) {
        lua_pushinteger(L, it->armor);
        lua_setfield(L, -2, "armor");
    }
    // TODO damage
}

static int l_message(lua_State *L) {
    message(luaL_checkstring(L, 1), false);
    return 0;
}

static int l_presskeys(lua_State *L) {
    size_t len;
    const char *keys = luaL_checklstring(L, 1, &len);
    for (int i=0; i < len; i++) {
        pushKey(keys[i]);
    }
    return 0;
}

static int l_stepto(lua_State *L) {
    lua_Integer dir = luaL_checkinteger(L, 1) - 1;
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

static int l_getworld(lua_State *L) {
    lua_newtable(L);

    // put on stack, bottom-to-top:
    // dungeon, liquid, gas, surface, flags
    for (int s=0; s < 5; ++s)
        lua_createtable(L, DCOLS*DROWS, 0);

    // iterate all pcells, updating each subtable on the stack
    pcell *cell;
    int j;
    for (int i=1; i <= DCOLS*DROWS; ++i) {
        j = 2;
        cell = &pmap[0][i-1];

        for (int l=0; l < 4; ++l) {
            lua_pushinteger(L, cell->layers[l]);
            lua_seti(L, j++, i);
        }

        lua_pushinteger(L, cell->flags);
        lua_seti(L, j++, i);
    }

    lua_setfield(L, 1, "flags");
    lua_setfield(L, 1, "surface");
    lua_setfield(L, 1, "gas");
    lua_setfield(L, 1, "liquid");
    lua_setfield(L, 1, "dungeon");
    return 1;
}

static int l_getpack(lua_State *L) {
    lua_newtable(L);

    char let[2] = " ";
    for (item *it = packItems->nextItem; it != NULL; it = it->nextItem) {
        pushItem(L, it);
        let[0] = it->inventoryLetter;
        lua_setfield(L, -2, let);
    }
    return 1;
}

static luaL_Reg reg[] = {
    {"message", l_message},
    {"presskeys", l_presskeys},
    {"stepto", l_stepto},
    {"getworld", l_getworld},
    {"getpack", l_getpack},
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
