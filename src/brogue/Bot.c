#include <math.h>
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "Rogue.h"
#include "IncludeGlobals.h"

#define QUEUE_LEN 16

static lua_State *L = NULL;
char *botScript = "";

// whether to hijack user input. set by resetBot based on botMode, unset on death
boolean botControl = false;

// 0=none 1=control 2=report. set by command line flags
short botMode = 0;

// 0=playing 1=enchanting 2=identifying 3=zapping
short botAction = 0;

static short **workGrid = NULL;
static pcell psnap[DCOLS][DROWS]; // pmap snapshot
static short snapValid = -1;


    // Core functions for interfacing with Brogue

static struct {
    rogueEvent events[QUEUE_LEN];
    int start;
    int end;
} eventQueue;

static void pushEvent(rogueEvent ev) {
    eventQueue.events[eventQueue.end++] = ev;
    eventQueue.end %= QUEUE_LEN;
}

static void pressKey(signed long key) {
    pushEvent((rogueEvent){KEYSTROKE, key, 0, false, false});
}

static void botAbort(char *s) {
    botControl = false;
    rogue.autoPlayingLevel = false;
    dialogAlert(s);
}
// And see resetBot, at the bottom of this file.

void magicMapped() {
    memcpy(psnap, pmap, sizeof(pmap));
    snapValid = rogue.depthLevel;
}

// The following two functions are taken from lua.c in the Lua 5.3 source
// (would be nice to have them built-in...!)
static int msghandler(lua_State *L) {
    const char *msg = lua_tostring(L, 1);
    if (msg == NULL) {    /* is error object not a string? */
        if (luaL_callmeta(L, 1, "__tostring") &&    /* does it have a metamethod */
            lua_type(L, -1) == LUA_TSTRING)    /* that produces a string? */
                return 1;    /* that is the message */
        else
            msg = lua_pushfstring(L, "(error object is a %s value)", luaL_typename(L, 1));
    }
    luaL_traceback(L, L, msg, 1);    /* append a standard traceback */
    return 1;    /* return the traceback */
}

static int docall(lua_State *L, int narg, int nres) {
    int status;
    int base = lua_gettop(L) - narg;  /* function index */
    lua_pushcfunction(L, msghandler);  /* push message handler */
    lua_insert(L, base);  /* put it under function and args */
    status = lua_pcall(L, narg, nres, base);
    lua_remove(L, base);  /* remove message handler from the stack */
    return status;
}

void nextBotEvent(rogueEvent *returnEvent) {
    returnEvent->eventType = EVENT_ERROR;

    if (eventQueue.start != eventQueue.end) {
        *returnEvent = eventQueue.events[eventQueue.start++];
        eventQueue.start %= QUEUE_LEN;
    } else {
        lua_getglobal(L, "pushevents");
        if (docall(L, 0, 0)) {
            // there's an error object on stack; print it to message log
            message(luaL_checkstring(L, -1), false);
            botAbort("Error occured in Lua interpreter. Stopping bot. See message log for details.");
        } else {
            // the queue is no longer empty, so re-run
            nextBotEvent(returnEvent);
        }
    }
}

void botReport() {
    lua_getglobal(L, "pushevents");
    if (docall(L, 0, 0)) {
        // there's an error object on stack; print it to message log
        message(luaL_checkstring(L, -1), false);
        botAbort("Error occured in Lua interpreter. Stopping bot. See message log for details.");
    }
}


    // Lua API helper functions

#define ALLOWED_MONST_BOOKFLAGS \
    (MB_TELEPATHICALLY_REVEALED | MB_CAPTIVE | MB_SEIZED | MB_SEIZING | MB_SUBMERGED \
    | MB_ABSORBING | MB_HAS_SOUL | MB_ALREADY_SEEN)

static lua_Integer checkCell(lua_State *L, int i) {
    lua_Integer c = luaL_checkinteger(L, i) - 1;
    if (c < 0 || c >= DROWS*DCOLS) {
        luaL_error(L, "cell index out of range");
    }
    return c;
}

static enum tileType hideSecrets(enum tileType tt) {
    char ch = tileCatalog[tt].displayChar;
    char *desc = tileCatalog[tt].description;

    // weak but general check for secret tiles
    if (ch == WALL_CHAR && strcmp(desc, "a stone wall") == 0) {
        return WALL;
    } else if (ch == FLOOR_CHAR && strcmp(desc, "the ground") == 0) {
        return FLOOR;
    } else if (ch == 0 && strcmp(desc, tileCatalog[SHALLOW_WATER].description) == 0) {
        return SHALLOW_WATER;
    } else {
        return tt;
    }
}

// push an item table onto the Lua stack. the existence of item is assumed to be somehow known.
static void pushItem(lua_State *L, item *it) {
    boolean carried = itemIsCarried(it), visible = carried || playerCanSee(it->xLoc, it->yLoc);

    lua_newtable(L);

    uchar magicChar = itemMagicChar(it);
    if (magicChar != 0 && (it->flags & ITEM_MAGIC_DETECTED)) {
        lua_pushboolean(L, true);
        lua_setfield(L, -2, (magicChar == GOOD_MAGIC_CHAR ? "blessed" : "cursed"));
    }

    if (carried) {
        char letter[] = {it->inventoryLetter, 0};
        lua_pushstring(L, letter);
        lua_setfield(L, -2, "letter");
    } else {
        lua_pushinteger(L, DROWS * it->xLoc + it->yLoc + 1);
        lua_setfield(L, -2, "cell");
    }

    if (carried || visible && !player.status[STATUS_HALLUCINATING]) {
        enum itemCategory c = it->category;
        enum itemFlags flags = it->flags;

        if (!(flags & (ITEM_IDENTIFIED | ITEM_EQUIPPED))) flags &= ~ITEM_CURSED;

        if (c==WEAPON || c==ARMOR) {
            lua_pushinteger(L, it->strengthRequired);
            lua_setfield(L, -2, "strength");
            lua_pushnumber(L, strengthModifier(it));
            lua_setfield(L, -2, "strengthmod");

            if (flags & ITEM_RUNIC) {
                // only give the info about the runic that the player knows
                if ((flags & (ITEM_IDENTIFIED | ITEM_RUNIC_HINTED))
                    && !(flags & ITEM_RUNIC_IDENTIFIED)) {
                    lua_pushboolean(L, true);
                    lua_setfield(L, -2, "runic");
                } else if ((flags & ITEM_RUNIC_IDENTIFIED)) {
                    lua_pushinteger(L, it->enchant2);
                    lua_setfield(L, -2, "runic");
                } else {
                    // we have no idea about the runic; mask out the flag
                    flags &= ~ITEM_RUNIC;
                }
            } else if (flags & ITEM_IDENTIFIED) {
                // we know there is no runic
                lua_pushboolean(L, false);
                lua_setfield(L, -2, "runic");
            }
        }

        if (flags & ITEM_IDENTIFIED) {
            if (c==WEAPON || c==ARMOR || c==STAFF || c==CHARM || c==RING) {
                lua_pushinteger(L, it->enchant1);
                lua_setfield(L, -2, "enchant");
                lua_pushnumber(L, netEnchant(it));
                lua_setfield(L, -2, "netenchant");
            }
        }

        if (c==WEAPON) {
            // these values are assuming the item is +0 with str req equal to the player's str
            lua_pushinteger(L, it->damage.lowerBound);
            lua_setfield(L, -2, "minbasedamage");
            lua_pushinteger(L, it->damage.upperBound);
            lua_setfield(L, -2, "maxbasedamage");

            float power = flags & ITEM_IDENTIFIED ? netEnchant(it) : strengthModifier(it);
            float dmgfactor = pow(WEAPON_ENCHANT_DAMAGE_FACTOR, power),
                  accfactor = pow(WEAPON_ENCHANT_ACCURACY_FACTOR, power);

            lua_pushinteger(L, it->damage.lowerBound * dmgfactor);
            lua_setfield(L, -2, "mindamage");
            lua_pushinteger(L, it->damage.upperBound * dmgfactor);
            lua_setfield(L, -2, "maxdamage");
            lua_pushinteger(L, player.info.accuracy * accfactor);
            lua_setfield(L, -2, "accuracy");

            lua_pushinteger(L, flags & ITEM_IDENTIFIED ? 0 : it->charges);
            lua_setfield(L, -2, "killstoreveal");
        }

        if (c==ARMOR) {
            short armor = it->armor;
            lua_pushinteger(L, armor);
            lua_setfield(L, -2, "basedefense");

            armor += 10 * (flags & ITEM_IDENTIFIED ? netEnchant(it) : strengthModifier(it));
            if (armor < 0) armor = 0;

            lua_pushinteger(L, armor);
            lua_setfield(L, -2, "defense");
        }

        if (c==ARMOR || c==RING) {
            lua_pushinteger(L, flags & ITEM_IDENTIFIED ? 0 : it->charges);
            lua_setfield(L, -2, "turnstoreveal");
        }

        if (c==STAFF) {
            if (flags & (ITEM_MAX_CHARGES_KNOWN | ITEM_IDENTIFIED)) {
                lua_pushinteger(L, it->enchant1);
                lua_setfield(L, -2, "maxcharges");
                if (flags & ITEM_IDENTIFIED) {
                    lua_pushinteger(L, it->charges);
                    lua_setfield(L, -2, "charges");
                }
            }
        }

        if (c==WAND) {
            lua_pushinteger(L, it->enchant2);
            lua_setfield(L, -2, "timesused");
            if (flags & (ITEM_MAX_CHARGES_KNOWN | ITEM_IDENTIFIED)) {
                lua_pushinteger(L, it->charges);
                lua_setfield(L, -2, "charges");
            }
        }

        if (c==CHARM) {
            lua_pushinteger(L, it->charges);
            lua_setfield(L, -2, "turnstocharge");
        }

        lua_pushinteger(L, flags);
        lua_setfield(L, -2, "flags");

        lua_pushinteger(L, c);
        lua_setfield(L, -2, "category");
        lua_pushinteger(L, it->quantity);
        lua_setfield(L, -2, "quantity");

        itemTable *table = tableForItemCategory(c, NULL);
        if (table != NULL) {
            table = &table[it->kind];

            lua_pushstring(L, table->flavor);
            lua_setfield(L, -2, "flavor");

            if (table->identified) {
                lua_pushinteger(L, it->kind);
                lua_setfield(L, -2, "kind");
            }
        }
    }
}

static short creatureAccuracy(creature *cr) {
    if (cr == &player && rogue.weapon) {
        float ench = rogue.weapon->flags & ITEM_IDENTIFIED ?
            netEnchant(rogue.weapon) : strengthModifier(rogue.weapon);
        return player.info.accuracy *
            pow(WEAPON_ENCHANT_ACCURACY_FACTOR, ench + FLOAT_FUDGE);
    } else {
        return monsterAccuracyAdjusted(cr);
    }
}

static short playerKnownDefense() {
    // referring to monsterDetails and recalculateEquipmentBonuses
    if (!rogue.armor || (rogue.armor->flags & ITEM_IDENTIFIED)) {
        return player.info.defense;
    } else {
        short def =
            (armorTable[rogue.armor->kind].range.upperBound + armorTable[rogue.armor->kind].range.lowerBound) / 2 +
            10 * (strengthModifier(rogue.armor) - player.status[STATUS_DONNING] + FLOAT_FUDGE);
        if (def < 0) def = 0;
        return def;
    }
}

// push a creature table onto the Lua stack. The existence of the creature is assumed to be somehow known.
/*  seen = not hidden and is either on a visible cell or is revealed (shows up in sidebar)
    hidden = submerged, invisible not in gas, dormant (can't be directly seen)
    revealed = entranced, telepathically linked, player telepathic */
static void pushCreature(lua_State *L, creature *cr) {
    lua_newtable(L);

    lua_pushinteger(L, cr->xLoc * DROWS + cr->yLoc + 1);
    lua_setfield(L, -2, "cell");

    // psychic emanation
    if (!canSeeMonster(cr) && monsterRevealed(cr)) {
        if (player.status[STATUS_HALLUCINATING]) lua_pushboolean(L, true);
        else lua_pushstring(L,
            (cr->info.displayChar >= 'a' && cr->info.displayChar <= 'z') ? "small" : "large");
        lua_setfield(L, -2, "emanation");
        return;
    }

    lua_pushnumber(L, (float) cr->currentHP / cr->info.maxHP);
    lua_setfield(L, -2, "health");

    // if we're hallucinating, that's all we know about monsters
    if (cr != &player && player.status[STATUS_HALLUCINATING]) return;

    lua_pushinteger(L, cr->info.flags);
    lua_setfield(L, -2, "flags");
    lua_pushinteger(L, cr->bookkeepingFlags & ALLOWED_MONST_BOOKFLAGS);
    lua_setfield(L, -2, "bookflags");

    lua_pushinteger(L, cr->currentHP);
    lua_setfield(L, -2, "hp");
    lua_pushinteger(L, cr->info.maxHP);
    lua_setfield(L, -2, "maxhp");
    lua_pushinteger(L, creatureAccuracy(cr));
    lua_setfield(L, -2, "accuracy");
    lua_pushinteger(L, cr->attackSpeed);
    lua_setfield(L, -2, "attackticks");

    short mindmg, maxdmg, def;

    if (cr == &player) {
        if (!rogue.weapon || (rogue.weapon->flags & ITEM_IDENTIFIED)) {
            mindmg = cr->info.damage.lowerBound;
            maxdmg = cr->info.damage.upperBound;
        } else {
            // thought we should consider str modifiers here but monsterDetails doesn't...
            mindmg = rogue.weapon->damage.lowerBound;
            maxdmg = rogue.weapon->damage.upperBound;
        }
        def = playerKnownDefense();
    } else {
        mindmg = cr->info.damage.lowerBound * monsterDamageAdjustmentAmount(cr);
        maxdmg = cr->info.damage.upperBound * monsterDamageAdjustmentAmount(cr);
        def = monsterDefenseAdjusted(cr);

        // base stats, before str modifiers. not sure if these will stay
        lua_pushinteger(L, cr->info.damage.lowerBound);
        lua_setfield(L, -2, "minbasedamage");
        lua_pushinteger(L, cr->info.damage.upperBound);
        lua_setfield(L, -2, "maxbasedamage");
        lua_pushinteger(L, cr->info.defense);
        lua_setfield(L, -2, "basedefense");
        lua_pushinteger(L, cr->info.accuracy);
        lua_setfield(L, -2, "baseaccuracy");
    }

    lua_pushinteger(L, mindmg);
    lua_setfield(L, -2, "mindamage");
    lua_pushinteger(L, maxdmg);
    lua_setfield(L, -2, "maxdamage");
    lua_pushinteger(L, def);
    lua_setfield(L, -2, "defense");

    lua_pushinteger(L, cr->weaknessAmount);
    lua_setfield(L, -2, "weakness");
    lua_pushinteger(L, cr->poisonAmount);
    lua_setfield(L, -2, "poison");
    lua_pushinteger(L, cr->movementSpeed);
    lua_setfield(L, -2, "moveticks");

    if (cr != &player) {
        lua_pushinteger(L, cr->creatureState);
        lua_setfield(L, -2, "state");
        lua_pushinteger(L, cr->newPowerCount);
        lua_setfield(L, -2, "abilityslots");
        lua_pushinteger(L, cr->info.abilityFlags);
        lua_setfield(L, -2, "abilities");
        if (cr->bookkeepingFlags & MB_ABSORBING) {
            lua_pushinteger(L, cr->corpseAbsorptionCounter);
            lua_setfield(L, -2, "turnstoabsorb");
        }
    }

    lua_newtable(L);
    for (int i=1; i <= NUMBER_OF_STATUS_EFFECTS; i++) {
        lua_pushinteger(L, cr->status[i-1]);
        lua_seti(L, -2, i);
    }
    lua_setfield(L, -2, "statuses");
}


    // Lua API

static int l_message(lua_State *L) {
    message(luaL_checkstring(L, 1), false);
    return 0;
}

static int l_presskeys(lua_State *L) {
    size_t len;
    const char *keys = luaL_checklstring(L, 1, &len);
    for (int i=0; i < len; i++) {
        pressKey(keys[i]);
    }
    return 0;
}

static int l_clickcell(lua_State *L) {
    lua_Integer cell = checkCell(L, 1);
    short sx = mapToWindowX(cell / DROWS), sy = mapToWindowY(cell % DROWS);
    pushEvent((rogueEvent){MOUSE_DOWN, sx, sy, false, false});
    pushEvent((rogueEvent){MOUSE_UP, sx, sy, false, false});
    return 0;
}

static int l_tileflags(lua_State *L) {
    lua_Integer t = luaL_checkinteger(L, 1);
    if (t < 0 || t >= NUMBER_TILETYPES) {
        luaL_error(L, "invalid tile type");
    }
    lua_pushinteger(L, tileCatalog[t].flags);
    return 1;
}

static int l_iskindknown(lua_State *L) {
    enum itemCategory cat = luaL_checkinteger(L, 1);
    short kind = luaL_checkinteger(L, 2);

    short nkinds;
    itemTable *table = tableForItemCategory(cat, &nkinds);
    if (!table) {
        // invalid category (gold, lumenstone or amulet); just return true
        lua_pushboolean(L, true);
        return 1;
    }
    if (kind >= nkinds) luaL_error(L, "invalid item kind for category");

    lua_pushboolean(L, table[kind].identified);
    return 1;
}

static int l_stepto(lua_State *L) {
    lua_Integer dir = luaL_checkinteger(L, 1) - 1;
    switch ((enum directions)dir) {
        case UP        : pressKey(UP_KEY); break;
        case DOWN      : pressKey(DOWN_KEY); break;
        case LEFT      : pressKey(LEFT_KEY); break;
        case RIGHT     : pressKey(RIGHT_KEY); break;
        case UPLEFT    : pressKey(UPLEFT_KEY); break;
        case DOWNLEFT  : pressKey(DOWNLEFT_KEY); break;
        case UPRIGHT   : pressKey(UPRIGHT_KEY); break;
        case DOWNRIGHT : pressKey(DOWNRIGHT_KEY); break;
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
    unsigned long cellflags;
    for (int i=1; i <= DCOLS*DROWS; ++i) {
        short x = (i-1) / DROWS, y = (i-1) % DROWS;

        // check whether we have magic map info available
        if (snapValid == rogue.depthLevel && !(pmap[x][y].flags & DISCOVERED) && (pmap[x][y].flags & MAGIC_MAPPED)) {
            cell = &psnap[x][y];
        } else if (!playerCanSee(x, y)) {
            continue;
        } else {
            cell = &pmap[x][y];
        }

        j = 2; // Lua stack index of table we will push to

        for (int l=0; l < 4; ++l) {
            lua_pushinteger(L, hideSecrets(cell->layers[l]));
            lua_seti(L, j++, i);
        }

        getLocationFlags(x, y, NULL, NULL, &cellflags, true);
        lua_pushinteger(L, cellflags);
        lua_seti(L, j++, i);
    }

    lua_setfield(L, 1, "flags");
    lua_setfield(L, 1, "surface");
    lua_setfield(L, 1, "gas");
    lua_setfield(L, 1, "liquid");
    lua_setfield(L, 1, "dungeon");

    if (snapValid == rogue.depthLevel) snapValid = -1;
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

static int l_getitems(lua_State *L) {
    lua_newtable(L);

    for (item *it = floorItems->nextItem; it != NULL; it = it->nextItem) {
        // only give info on items that can be seen or are magic-detected
        if (!playerCanSee(it->xLoc, it->yLoc) && !(it->flags & ITEM_MAGIC_DETECTED)) continue;
        pushItem(L, it);
        lua_seti(L, -2, it->xLoc * DROWS + it->yLoc + 1);
    }
    return 1;
}

static int l_getcreatures(lua_State *L) {
    lua_newtable(L);

    for (creature *cr = monsters->nextCreature; cr != NULL; cr = cr->nextCreature) {
        if (!(canSeeMonster(cr) || monsterRevealed(cr))) continue;
        pushCreature(L, cr);
        lua_seti(L, -2, cr->xLoc * DROWS + cr->yLoc + 1);
    }
    for (creature *cr = dormantMonsters->nextCreature; cr != NULL; cr = cr->nextCreature) {
        if (!(canSeeMonster(cr) || monsterRevealed(cr))) continue;
        pushCreature(L, cr);
        lua_seti(L, -2, cr->xLoc * DROWS + cr->yLoc + 1);
    }

    return 1;
}

static int l_getplayer(lua_State *L) {
    pushCreature(L, &player);

    lua_pushinteger(L, rogue.depthLevel);
    lua_setfield(L, -2, "depth");
    lua_pushinteger(L, rogue.absoluteTurnNumber);
    lua_setfield(L, -2, "turn");
    lua_pushinteger(L, rogue.strength);
    lua_setfield(L, -2, "strength");
    lua_pushinteger(L, rogue.aggroRange);
    lua_setfield(L, -2, "stealthrange");

    lua_pushinteger(L, botAction);
    lua_setfield(L, -2, "action");

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
    if (rogue.ringLeft) {
        let[0] = rogue.ringLeft->inventoryLetter;
        lua_pushstring(L, let);
        lua_setfield(L, -2, "leftring");
    }
    if (rogue.ringRight) {
        let[0] = rogue.ringRight->inventoryLetter;
        lua_pushstring(L, let);
        lua_setfield(L, -2, "rightring");
    }

    return 1;
}

static int l_distmap(lua_State *L) {
    luaL_checktype(L, 1, LUA_TTABLE);
    lua_Integer blockflags = luaL_checkinteger(L, 2);
    int monstblock = lua_toboolean(L, 3);

    lua_createtable(L, DCOLS*DROWS, 0);

    fillGrid(workGrid, 30000);

    lua_Integer i;
    lua_pushnil(L);
    while (lua_next(L, 1) != 0) {
        i = checkCell(L, -1);
        workGrid[0][i] = 0;
        lua_pop(L, 1);
    }

    calculateKnownDistances(workGrid, blockflags, monstblock);

    short d;
    for (int i=0; i < DCOLS*DROWS; ++i) {
        d = workGrid[0][i];
        if (!(pmap[i / DROWS][i % DROWS].flags & (DISCOVERED | MAGIC_MAPPED))) continue;
        lua_pushinteger(L, d);
        lua_seti(L, -2, i+1);
    }

    return 1;
}

static luaL_Reg reg[] = {
    {"message", l_message},
    {"presskeys", l_presskeys},
    {"clickcell", l_clickcell},
    {"tileflags", l_tileflags},
    {"iskindknown", l_iskindknown},
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

    if (workGrid == NULL) workGrid = allocGrid();

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

    if (botMode == 1) {
        botControl = true;
        rogue.autoPlayingLevel = true;
    }
}
