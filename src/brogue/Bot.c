#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "Rogue.h"
#include "IncludeGlobals.h"

#define QUEUE_LEN 16
#define UNKNOWN_RUNIC -1

static lua_State *L = NULL;
char *botScript = "";
boolean botControl = false;

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

static void botAbort(char *s) {
    botControl = false;
    rogue.autoPlayingLevel = false;
    dialogAlert(s);
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
            message(luaL_checkstring(L, -1), false);
            botAbort("Error occured in Lua interpreter. Stopping bot. See message log for details.");
        } else {
            // the queue is no longer empty, so re-run
            nextBotEvent(returnEvent);
        }
    }
}

// push an item table onto the Lua stack
static void pushItem(lua_State *L, item *it, boolean inPack, boolean visible) {
    lua_newtable(L);

    enum itemCategory c = it->category;
    uchar magicChar = itemMagicChar(it);

    if (magicChar != 0 && (it->flags & ITEM_MAGIC_DETECTED)) {
        lua_pushboolean(L, true);
        lua_setfield(L, -2, (magicChar == GOOD_MAGIC_CHAR ? "blessed" : "cursed"));
    }

    if (inPack) {
        enum itemFlags flags = it->flags;
        char letter[] = {it->inventoryLetter, 0};

        lua_pushstring(L, letter);
        lua_setfield(L, -2, "letter");

        if (c==WEAPON || c==ARMOR) {
            lua_pushinteger(L, it->strengthRequired);
            lua_setfield(L, -2, "strength");

            if (it->flags & ITEM_RUNIC) {
                // only give the info about the runic that the player knows
                if ((it->flags & (ITEM_IDENTIFIED | ITEM_RUNIC_HINTED))
                    && !(it->flags & ITEM_RUNIC_IDENTIFIED)) {
                    lua_pushinteger(L, UNKNOWN_RUNIC);
                    lua_setfield(L, -2, "runic");
                } else if ((it->flags & ITEM_RUNIC_IDENTIFIED)) {
                    lua_pushinteger(L, it->enchant2);
                    lua_setfield(L, -2, "runic");
                } else {
                    // if player has no idea about the runic, tell the bot there is none
                    flags &= ~ITEM_RUNIC;
                }
            }
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

        lua_pushinteger(L, flags);
        lua_setfield(L, -2, "flags");

        // TODO damage
    } else {
        lua_pushinteger(L, DROWS * it->xLoc + it->yLoc + 1);
        lua_setfield(L, -2, "cell");

        // if we can't see the item either, that's all
        if (!visible) return;
    }

    lua_pushinteger(L, c);
    lua_setfield(L, -2, "category");
    lua_pushinteger(L, it->quantity);
    lua_setfield(L, -2, "quantity");

    if ((c==WEAPON || c==ARMOR) || (it->flags & ITEM_IDENTIFIED)) {
        lua_pushinteger(L, it->kind);
        lua_setfield(L, -2, "kind");
    }
}

// push a creature table onto the Lua stack
static void pushCreature(lua_State *L, creature *cr) {
    lua_newtable(L);

    lua_pushinteger(L, cr->xLoc * DROWS + cr->yLoc + 1);
    lua_setfield(L, -2, "cell");
    lua_pushinteger(L, cr->currentHP);
    lua_setfield(L, -2, "hp");
    lua_pushinteger(L, cr->creatureState);
    lua_setfield(L, -2, "state");
    lua_pushinteger(L, cr->info.maxHP);
    lua_setfield(L, -2, "maxhp");
    lua_pushinteger(L, cr->weaknessAmount);
    lua_setfield(L, -2, "weakness");
    lua_pushinteger(L, cr->poisonAmount);
    lua_setfield(L, -2, "poison");
    lua_pushinteger(L, cr->movementSpeed);
    lua_setfield(L, -2, "movespeed");
    lua_pushinteger(L, cr->attackSpeed);
    lua_setfield(L, -2, "attackspeed");
    lua_pushinteger(L, cr->info.damage.lowerBound);
    lua_setfield(L, -2, "mindamage");
    lua_pushinteger(L, cr->info.damage.upperBound);
    lua_setfield(L, -2, "maxdamage");
    lua_pushinteger(L, cr->info.flags);
    lua_setfield(L, -2, "flags");
    lua_pushinteger(L, cr->info.abilityFlags);
    lua_setfield(L, -2, "abilities");

    lua_newtable(L);
    for (int i=1; i <= NUMBER_OF_STATUS_EFFECTS; i++) {
        lua_pushinteger(L, cr->status[i-1]);
        lua_seti(L, -2, i);
    }
    lua_setfield(L, -2, "statuses");
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

static int l_tileflags(lua_State *L) {
    lua_pushinteger(L, tileCatalog[luaL_checkinteger(L, 1)].flags);
    return 1;
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
        if (!playerCanSee((i-1) / DROWS, (i-1) % DROWS)) continue;
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
        pushItem(L, it, true, true);
        let[0] = it->inventoryLetter;
        lua_setfield(L, -2, let);
    }
    return 1;
}

static int l_getitems(lua_State *L) {
    lua_newtable(L);

    int i = 1;
    for (item *it = floorItems->nextItem; it != NULL; it = it->nextItem) {
        // only give info on items that can be seen or are magic-detected
        boolean seen = playerCanSee(it->xLoc, it->yLoc);
        if (!seen && !(it->flags & ITEM_MAGIC_DETECTED)) continue;
        pushItem(L, it, false, seen);
        lua_seti(L, -2, i++);
    }
    return 1;
}

static int l_getcreatures(lua_State *L) {
    lua_newtable(L);

    int i = 1;
    for (creature *cr = monsters->nextCreature; cr != NULL; cr = cr->nextCreature) {
        if (!canSeeMonster(cr)) continue;
        pushCreature(L, cr);
        lua_seti(L, -2, i++);
    }

    return 1;
}

static int l_getplayer(lua_State *L) {
    pushCreature(L, &player);

    lua_pushinteger(L, rogue.depthLevel);
    lua_setfield(L, -2, "depth");
    lua_pushinteger(L, rogue.playerTurnNumber);
    lua_setfield(L, -2, "turn");
    lua_pushinteger(L, rogue.strength);
    lua_setfield(L, -2, "strength");
    lua_pushinteger(L, rogue.aggroRange);
    lua_setfield(L, -2, "stealthrange");

    char let[] = " ";
    if (rogue.weapon) {
        let[0] = rogue.weapon->inventoryLetter;
        lua_pushstring(L, let);
        lua_setfield(L, -2, "weapon");
    }
    if (rogue.armor) {
        let[0] = rogue.armor->inventoryLetter;
        lua_pushstring(L, let);
        lua_setfield(L, -2, "armor");
    }

    return 1;
}

static int l_distmap(lua_State *L) {
    lua_createtable(L, DCOLS*DROWS, 0);

    short **dists = allocGrid();
    lua_Integer cell = luaL_checkinteger(L, 1) - 1;
    lua_Integer blockflags = luaL_checkinteger(L, 2);
    calculateDistances(dists, cell/DROWS, cell%DROWS, blockflags, NULL, false, true);

    short d;
    for (int i=1; i <= DCOLS*DROWS; ++i) {
        d = dists[0][i-1];
        lua_pushinteger(L, d);
        lua_seti(L, -2, i);
    }

    freeGrid(dists);
    return 1;
}

static luaL_Reg reg[] = {
    {"message", l_message},
    {"presskeys", l_presskeys},
    {"tileflags", l_tileflags},
    {"stepto", l_stepto},
    {"getworld", l_getworld},
    {"getpack", l_getpack},
    {"getitems", l_getitems},
    {"getcreatures", l_getcreatures},
    {"getplayer", l_getplayer},
    {"distancemap", l_distmap},
    {NULL, NULL},
};

void resetBot(char *filename) {
    eventQueue.start = eventQueue.end = 0;

    if (L != NULL) lua_close(L);
    L = luaL_newstate();

    if (L == NULL) {
        botAbort("Cannot initialise Lua.");
        return;
    }

    luaL_openlibs(L);
    lua_pushglobaltable(L);
    luaL_setfuncs(L, reg, 0);

    if (luaL_dofile(L, filename)) {
        botAbort("Could not load bot script.");
        return;
    }

    rogue.autoPlayingLevel = true;
}
