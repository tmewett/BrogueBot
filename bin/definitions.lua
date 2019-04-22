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
