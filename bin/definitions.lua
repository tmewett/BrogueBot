function Fl(n) return 1 << n end

DCOLS = 79
DROWS = 29

-- directions
UP              = 1
DOWN            = 2
LEFT            = 3
RIGHT           = 4
UPLEFT          = 5
DOWNLEFT        = 6
UPRIGHT         = 7
DOWNRIGHT       = 8

-- cell flags
DISCOVERED                  = Fl(0)
VISIBLE                     = Fl(1)    -- cell has sufficient light and is in field of view, ready to draw.
HAS_PLAYER                  = Fl(2)
HAS_MONSTER                 = Fl(3)
HAS_DORMANT_MONSTER         = Fl(4)    -- hidden monster on the square
HAS_ITEM                    = Fl(5)
IN_FIELD_OF_VIEW            = Fl(6)    -- player has unobstructed line of sight whether or not there is enough light
WAS_VISIBLE                 = Fl(7)
HAS_DOWN_STAIRS             = Fl(8)
HAS_UP_STAIRS               = Fl(9)
IS_IN_SHADOW                = Fl(10)   -- so that a player gains an automatic stealth bonus
MAGIC_MAPPED                = Fl(11)
ITEM_DETECTED               = Fl(12)
CLAIRVOYANT_VISIBLE         = Fl(13)
WAS_CLAIRVOYANT_VISIBLE     = Fl(14)
CLAIRVOYANT_DARKENED        = Fl(15)   -- magical blindness from a cursed ring of clairvoyance
CAUGHT_FIRE_THIS_TURN       = Fl(16)   -- so that fire does not spread asymmetrically
PRESSURE_PLATE_DEPRESSED    = Fl(17)   -- so that traps do not trigger repeatedly while you stand on them
STABLE_MEMORY               = Fl(18)   -- redraws will simply be pulled from the memory array, not recalculated
KNOWN_TO_BE_TRAP_FREE       = Fl(19)   -- keep track of where the player has stepped as he knows no traps are there
IS_IN_PATH                  = Fl(20)   -- the yellow trail leading to the cursor
IN_LOOP                     = Fl(21)   -- this cell is part of a terrain loop
IS_CHOKEPOINT               = Fl(22)   -- if this cell is blocked, part of the map will be rendered inaccessible
IS_GATE_SITE                = Fl(23)   -- consider placing a locked door here
IS_IN_ROOM_MACHINE          = Fl(24)
IS_IN_AREA_MACHINE          = Fl(25)
IS_POWERED                  = Fl(26)   -- has been activated by machine power this turn (can probably be eliminate if needed)
IMPREGNABLE                 = Fl(27)   -- no tunneling allowed!
TERRAIN_COLORS_DANCING      = Fl(28)   -- colors here will sparkle when the game is idle
TELEPATHIC_VISIBLE          = Fl(29)   -- potions of telepathy let you see through other creatures' eyes
WAS_TELEPATHIC_VISIBLE      = Fl(30)   -- potions of telepathy let you see through other creatures' eyes

HAS_STAIRS                  = (HAS_UP_STAIRS | HAS_DOWN_STAIRS)
IS_IN_MACHINE               = (IS_IN_ROOM_MACHINE | IS_IN_AREA_MACHINE)    -- sacred ground; don't generate items here, or teleport randomly to it

PERMANENT_TILE_FLAGS = (DISCOVERED | MAGIC_MAPPED | ITEM_DETECTED | HAS_ITEM | HAS_DORMANT_MONSTER
                        | HAS_UP_STAIRS | HAS_DOWN_STAIRS | PRESSURE_PLATE_DEPRESSED
                        | STABLE_MEMORY | KNOWN_TO_BE_TRAP_FREE | IN_LOOP
                        | IS_CHOKEPOINT | IS_GATE_SITE | IS_IN_MACHINE | IMPREGNABLE)

ANY_KIND_OF_VISIBLE         = (VISIBLE | CLAIRVOYANT_VISIBLE | TELEPATHIC_VISIBLE)

-- terrain/tile flags
T_OBSTRUCTS_PASSABILITY         = Fl(0)        -- cannot be walked through
T_OBSTRUCTS_VISION              = Fl(1)        -- blocks line of sight
T_OBSTRUCTS_ITEMS               = Fl(2)        -- items can't be on this tile
T_OBSTRUCTS_SURFACE_EFFECTS     = Fl(3)        -- grass, blood, etc. cannot exist on this tile
T_OBSTRUCTS_GAS                 = Fl(4)        -- blocks the permeation of gas
T_OBSTRUCTS_DIAGONAL_MOVEMENT   = Fl(5)        -- can't step diagonally around this tile
T_SPONTANEOUSLY_IGNITES         = Fl(6)        -- monsters avoid unless chasing player or immune to fire
T_AUTO_DESCENT                  = Fl(7)        -- automatically drops creatures down a depth level and does some damage (2d6)
T_LAVA_INSTA_DEATH              = Fl(8)        -- kills any non-levitating non-fire-immune creature instantly
T_CAUSES_POISON                 = Fl(9)        -- any non-levitating creature gets 10 poison
T_IS_FLAMMABLE                  = Fl(10)       -- terrain can catch fire
T_IS_FIRE                       = Fl(11)       -- terrain is a type of fire; ignites neighboring flammable cells
T_ENTANGLES                     = Fl(12)       -- entangles players and monsters like a spiderweb
T_IS_DEEP_WATER                 = Fl(13)       -- steals items 50% of the time and moves them around randomly
T_CAUSES_DAMAGE                 = Fl(14)       -- anything on the tile takes max(1-2, 10%) damage per turn
T_CAUSES_NAUSEA                 = Fl(15)       -- any creature on the tile becomes nauseous
T_CAUSES_PARALYSIS              = Fl(16)       -- anything caught on this tile is paralyzed
T_CAUSES_CONFUSION              = Fl(17)       -- causes creatures on this tile to become confused
T_CAUSES_HEALING                = Fl(18)       -- heals 20% max HP per turn for any player or non-inanimate monsters
T_IS_DF_TRAP                    = Fl(19)       -- spews gas of type specified in fireType when stepped on
T_CAUSES_EXPLOSIVE_DAMAGE       = Fl(20)       -- is an explosion; deals higher of 15-20 or 50% damage instantly, but not again for five turns
T_SACRED                        = Fl(21)       -- monsters that aren't allies of the player will avoid stepping here

T_OBSTRUCTS_SCENT               = (T_OBSTRUCTS_PASSABILITY | T_OBSTRUCTS_VISION | T_AUTO_DESCENT | T_LAVA_INSTA_DEATH | T_IS_DEEP_WATER | T_SPONTANEOUSLY_IGNITES)
T_PATHING_BLOCKER               = (T_OBSTRUCTS_PASSABILITY | T_AUTO_DESCENT | T_IS_DF_TRAP | T_LAVA_INSTA_DEATH | T_IS_DEEP_WATER | T_IS_FIRE | T_SPONTANEOUSLY_IGNITES)
T_DIVIDES_LEVEL                 = (T_OBSTRUCTS_PASSABILITY | T_AUTO_DESCENT | T_IS_DF_TRAP | T_LAVA_INSTA_DEATH | T_IS_DEEP_WATER)
T_LAKE_PATHING_BLOCKER          = (T_AUTO_DESCENT | T_LAVA_INSTA_DEATH | T_IS_DEEP_WATER | T_SPONTANEOUSLY_IGNITES)
T_WAYPOINT_BLOCKER              = (T_OBSTRUCTS_PASSABILITY | T_AUTO_DESCENT | T_IS_DF_TRAP | T_LAVA_INSTA_DEATH | T_IS_DEEP_WATER | T_SPONTANEOUSLY_IGNITES)
T_MOVES_ITEMS                   = (T_IS_DEEP_WATER | T_LAVA_INSTA_DEATH)
T_CAN_BE_BRIDGED                = (T_AUTO_DESCENT)
T_OBSTRUCTS_EVERYTHING          = (T_OBSTRUCTS_PASSABILITY | T_OBSTRUCTS_VISION | T_OBSTRUCTS_ITEMS | T_OBSTRUCTS_GAS | T_OBSTRUCTS_SURFACE_EFFECTS | T_OBSTRUCTS_DIAGONAL_MOVEMENT)
T_HARMFUL_TERRAIN               = (T_CAUSES_POISON | T_IS_FIRE | T_CAUSES_DAMAGE | T_CAUSES_PARALYSIS | T_CAUSES_CONFUSION | T_CAUSES_EXPLOSIVE_DAMAGE)
T_RESPIRATION_IMMUNITIES        = (T_CAUSES_DAMAGE | T_CAUSES_CONFUSION | T_CAUSES_PARALYSIS | T_CAUSES_NAUSEA)
