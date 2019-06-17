local function Fl(n) return 1 << n end
local i
local function nexti() i = i + 1; return i end

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

UNREACHABLE = 30000


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


-- monster behaviour flags
MONST_INVISIBLE                 = Fl(0)    -- monster is invisible
MONST_INANIMATE                 = Fl(1)    -- monster has abbreviated stat bar display and is immune to many things
MONST_IMMOBILE                  = Fl(2)    -- monster won't move or perform melee attacks
MONST_CARRY_ITEM_100            = Fl(3)    -- monster carries an item 100% of the time
MONST_CARRY_ITEM_25             = Fl(4)    -- monster carries an item 25% of the time
MONST_ALWAYS_HUNTING            = Fl(5)    -- monster is never asleep or in wandering mode
MONST_FLEES_NEAR_DEATH          = Fl(6)    -- monster flees when under 25% health and re-engages when over 75%
MONST_ATTACKABLE_THRU_WALLS     = Fl(7)    -- can be attacked when embedded in a wall
MONST_DEFEND_DEGRADE_WEAPON     = Fl(8)    -- hitting the monster damages the weapon
MONST_IMMUNE_TO_WEAPONS         = Fl(9)    -- weapons ineffective
MONST_FLIES                     = Fl(10)   -- permanent levitation
MONST_FLITS                     = Fl(11)   -- moves randomly a third of the time
MONST_IMMUNE_TO_FIRE            = Fl(12)   -- won't burn, won't die in lava
MONST_CAST_SPELLS_SLOWLY        = Fl(13)   -- takes twice the attack duration to cast a spell
MONST_IMMUNE_TO_WEBS            = Fl(14)   -- monster passes freely through webs
MONST_REFLECT_4                 = Fl(15)   -- monster reflects projectiles as though wearing +4 armor of reflection
MONST_NEVER_SLEEPS              = Fl(16)   -- monster is always awake
MONST_FIERY                     = Fl(17)   -- monster carries an aura of flame (but no automatic fire light)
MONST_INVULNERABLE              = Fl(18)   -- monster is immune to absolutely everything
MONST_IMMUNE_TO_WATER           = Fl(19)   -- monster moves at full speed in deep water and (if player) doesn't drop items
MONST_RESTRICTED_TO_LIQUID      = Fl(20)   -- monster can move only on tiles that allow submersion
MONST_SUBMERGES                 = Fl(21)   -- monster can submerge in appropriate terrain
MONST_MAINTAINS_DISTANCE        = Fl(22)   -- monster tries to keep a distance of 3 tiles between it and player
MONST_WILL_NOT_USE_STAIRS       = Fl(23)   -- monster won't chase the player between levels
MONST_DIES_IF_NEGATED           = Fl(24)   -- monster will die if exposed to negation magic
MONST_MALE                      = Fl(25)   -- monster is male (or 50% likely to be male if also has MONST_FEMALE)
MONST_FEMALE                    = Fl(26)   -- monster is female (or 50% likely to be female if also has MONST_MALE)
MONST_NOT_LISTED_IN_SIDEBAR     = Fl(27)   -- monster doesn't show up in the sidebar
MONST_GETS_TURN_ON_ACTIVATION   = Fl(28)   -- monster never gets a turn, except when its machine is activated
MONST_ALWAYS_USE_ABILITY        = Fl(29)   -- monster will never fail to use special ability if eligible (no random factor)
MONST_NO_POLYMORPH              = Fl(30)   -- monster cannot result from a polymorph spell (liches, phoenixes and Warden of Yendor)

NEGATABLE_TRAITS                = (MONST_INVISIBLE | MONST_DEFEND_DEGRADE_WEAPON | MONST_IMMUNE_TO_WEAPONS | MONST_FLIES
                                   | MONST_FLITS | MONST_IMMUNE_TO_FIRE | MONST_REFLECT_4 | MONST_FIERY | MONST_MAINTAINS_DISTANCE)
MONST_TURRET                    = (MONST_IMMUNE_TO_WEBS | MONST_NEVER_SLEEPS | MONST_IMMOBILE | MONST_INANIMATE |
                                   MONST_ATTACKABLE_THRU_WALLS | MONST_WILL_NOT_USE_STAIRS)
LEARNABLE_BEHAVIORS             = (MONST_INVISIBLE | MONST_FLIES | MONST_IMMUNE_TO_FIRE | MONST_REFLECT_4)
MONST_NEVER_VORPAL_ENEMY        = (MONST_INANIMATE | MONST_INVULNERABLE | MONST_IMMOBILE | MONST_RESTRICTED_TO_LIQUID | MONST_GETS_TURN_ON_ACTIVATION | MONST_MAINTAINS_DISTANCE)
MONST_NEVER_MUTATED             = (MONST_INVISIBLE | MONST_INANIMATE | MONST_IMMOBILE | MONST_INVULNERABLE)


-- monster ability flags
MA_HIT_HALLUCINATE              = Fl(0)    -- monster can hit to cause hallucinations
MA_HIT_STEAL_FLEE               = Fl(1)    -- monster can steal an item and then run away
MA_ENTER_SUMMONS                = Fl(2)    -- monster will "become" its summoned leader, reappearing when that leader is defeated
MA_HIT_DEGRADE_ARMOR            = Fl(3)    -- monster damages armor
MA_CAST_SUMMON                  = Fl(4)    -- requires that there be one or more summon hordes with this monster type as the leader
MA_SEIZES                       = Fl(5)    -- monster seizes enemies before attacking
MA_POISONS                      = Fl(6)    -- monster's damage is dealt in the form of poison
MA_DF_ON_DEATH                  = Fl(7)    -- monster spawns its DF when it dies
MA_CLONE_SELF_ON_DEFEND         = Fl(8)    -- monster splits in two when struck
MA_KAMIKAZE                     = Fl(9)    -- monster dies instead of attacking
MA_TRANSFERENCE                 = Fl(10)   -- monster recovers 40 or 90% of the damage that it inflicts as health
MA_CAUSES_WEAKNESS              = Fl(11)   -- monster attacks cause weakness status in target
MA_ATTACKS_PENETRATE            = Fl(12)   -- monster attacks all adjacent enemies, like an axe
MA_ATTACKS_ALL_ADJACENT         = Fl(13)   -- monster attacks penetrate one layer of enemies, like a spear
MA_ATTACKS_EXTEND               = Fl(14)   -- monster attacks from a distance in a cardinal direction, like a whip
MA_AVOID_CORRIDORS              = Fl(15)   -- monster will avoid corridors when hunting

SPECIAL_HIT                     = (MA_HIT_HALLUCINATE | MA_HIT_STEAL_FLEE | MA_HIT_DEGRADE_ARMOR | MA_POISONS | MA_TRANSFERENCE | MA_CAUSES_WEAKNESS)
LEARNABLE_ABILITIES             = (MA_TRANSFERENCE | MA_CAUSES_WEAKNESS)

MA_NON_NEGATABLE_ABILITIES      = (MA_ATTACKS_PENETRATE | MA_ATTACKS_ALL_ADJACENT)
MA_NEVER_VORPAL_ENEMY           = (MA_KAMIKAZE)
MA_NEVER_MUTATED                = (MA_KAMIKAZE)


-- monster bookkeeping flags. only a few are actually given
MB_TELEPATHICALLY_REVEALED  = Fl(1)    -- player can magically see monster and adjacent cells
MB_CAPTIVE                  = Fl(8)    -- monster is all tied up
MB_SEIZED                   = Fl(9)    -- monster is being held
MB_SEIZING                  = Fl(10)   -- monster is holding another creature immobile
MB_SUBMERGED                = Fl(11)   -- monster is currently submerged and hence invisible until it attacks
MB_ABSORBING                = Fl(15)   -- currently learning a skill by absorbing an enemy corpse
MB_HAS_SOUL                 = Fl(21)   -- slaying the monster will count toward weapon auto-ID
MB_ALREADY_SEEN             = Fl(22)   -- seeing this monster won't interrupt exploration


-- monster states
i = -1
MONSTER_SLEEPING                = nexti()
MONSTER_HUNTING                 = nexti()  -- MONSTER_TRACKING_SCENT internally
MONSTER_WANDERING               = nexti()
MONSTER_FLEEING                 = nexti()
MONSTER_ALLY                    = nexti()


-- creature status effect indices
i = 0 -- start from 1 as these are table indices
STATUS_WEAKENED                 = nexti()
STATUS_TELEPATHIC               = nexti()
STATUS_HALLUCINATING            = nexti()
STATUS_LEVITATING               = nexti()
STATUS_SLOWED                   = nexti()
STATUS_HASTED                   = nexti()
STATUS_CONFUSED                 = nexti()
STATUS_BURNING                  = nexti()
STATUS_PARALYZED                = nexti()
STATUS_POISONED                 = nexti()
STATUS_STUCK                    = nexti()
STATUS_NAUSEOUS                 = nexti()
STATUS_DISCORDANT               = nexti()
STATUS_IMMUNE_TO_FIRE           = nexti()
STATUS_EXPLOSION_IMMUNITY       = nexti()
STATUS_NUTRITION                = nexti()
STATUS_ENTERS_LEVEL_IN          = nexti()
STATUS_MAGICAL_FEAR             = nexti()
STATUS_ENTRANCED                = nexti()
STATUS_DARKNESS                 = nexti()
STATUS_LIFESPAN_REMAINING       = nexti()
STATUS_SHIELDED                 = nexti()
STATUS_INVISIBLE                = nexti()
STATUS_AGGRAVATING              = nexti()


-- item flags
ITEM_IDENTIFIED         = Fl(0)
ITEM_EQUIPPED           = Fl(1)
ITEM_CURSED             = Fl(2)
ITEM_PROTECTED          = Fl(3)
ITEM_RUNIC              = Fl(5)
ITEM_RUNIC_HINTED       = Fl(6)
ITEM_RUNIC_IDENTIFIED   = Fl(7)
ITEM_CAN_BE_IDENTIFIED  = Fl(8)
ITEM_PREPLACED          = Fl(9)
ITEM_FLAMMABLE          = Fl(10)
ITEM_MAGIC_DETECTED     = Fl(11)
ITEM_MAX_CHARGES_KNOWN  = Fl(12)
ITEM_IS_KEY             = Fl(13)

ITEM_ATTACKS_HIT_SLOWLY = Fl(14)   -- mace, hammer
ITEM_ATTACKS_EXTEND     = Fl(15)   -- whip
ITEM_ATTACKS_QUICKLY    = Fl(16)   -- rapier
ITEM_ATTACKS_PENETRATE  = Fl(17)   -- spear, pike
ITEM_ATTACKS_ALL_ADJACENT=Fl(18)   -- axe, war axe
ITEM_LUNGE_ATTACKS      = Fl(19)   -- rapier
ITEM_SNEAK_ATTACK_BONUS = Fl(20)   -- dagger
ITEM_PASS_ATTACKS       = Fl(21)   -- flail

ITEM_KIND_AUTO_ID       = Fl(22)   -- the item type will become known when the item is picked up.
ITEM_PLAYER_AVOIDS      = Fl(23)   -- explore and travel will try to avoid picking the item up


-- item categories
FOOD                = Fl(0)
WEAPON              = Fl(1)
ARMOR               = Fl(2)
POTION              = Fl(3)
SCROLL              = Fl(4)
STAFF               = Fl(5)
WAND                = Fl(6)
RING                = Fl(7)
CHARM               = Fl(8)
GOLD                = Fl(9)
AMULET              = Fl(10)
GEM                 = Fl(11)
KEY                 = Fl(12)

CAN_BE_DETECTED     = (WEAPON | ARMOR | POTION | SCROLL | RING | CHARM | WAND | STAFF | AMULET)
CAN_BE_ENCHANTED    = (WEAPON | ARMOR | RING | STAFF | WAND | CHARM)
PRENAMED_CATEGORY   = (FOOD | GOLD | AMULET | GEM | KEY)
NEVER_IDENTIFIABLE  = (FOOD | CHARM | GOLD | AMULET | GEM | KEY)
COUNTS_TOWARD_SCORE = (GOLD | AMULET | GEM)
CAN_BE_SWAPPED      = (WEAPON | ARMOR | STAFF | CHARM | RING)
ALL_ITEMS           = (FOOD|POTION|WEAPON|ARMOR|STAFF|WAND|SCROLL|RING|CHARM|GOLD|AMULET|GEM|KEY)


-- item kinds
i = -1
KEY_DOOR                        = nexti()
KEY_CAGE                        = nexti()
KEY_PORTAL                      = nexti()

i = -1
RATION                          = nexti()
FRUIT                           = nexti()

i = -1
POTION_LIFE                     = nexti()
POTION_STRENGTH                 = nexti()
POTION_TELEPATHY                = nexti()
POTION_LEVITATION               = nexti()
POTION_DETECT_MAGIC             = nexti()
POTION_HASTE_SELF               = nexti()
POTION_FIRE_IMMUNITY            = nexti()
POTION_INVISIBILITY             = nexti()
POTION_POISON                   = nexti()
POTION_PARALYSIS                = nexti()
POTION_HALLUCINATION            = nexti()
POTION_CONFUSION                = nexti()
POTION_INCINERATION             = nexti()
POTION_DARKNESS                 = nexti()
POTION_DESCENT                  = nexti()
POTION_LICHEN                   = nexti()

i = -1
DAGGER                          = nexti()
SWORD                           = nexti()
BROADSWORD                      = nexti()

WHIP                            = nexti()
RAPIER                          = nexti()
FLAIL                           = nexti()

MACE                            = nexti()
HAMMER                          = nexti()

SPEAR                           = nexti()
PIKE                            = nexti()

AXE                             = nexti()
WAR_AXE                         = nexti()

DART                            = nexti()
INCENDIARY_DART                 = nexti()
JAVELIN                         = nexti()

i = -1
LEATHER_ARMOR                   = nexti()
SCALE_MAIL                      = nexti()
CHAIN_MAIL                      = nexti()
BANDED_MAIL                     = nexti()
SPLINT_MAIL                     = nexti()
PLATE_MAIL                      = nexti()

i = -1
WAND_TELEPORT                   = nexti()
WAND_SLOW                       = nexti()
WAND_POLYMORPH                  = nexti()
WAND_NEGATION                   = nexti()
WAND_DOMINATION                 = nexti()
WAND_BECKONING                  = nexti()
WAND_PLENTY                     = nexti()
WAND_INVISIBILITY               = nexti()
WAND_EMPOWERMENT                = nexti()

i = -1
STAFF_LIGHTNING                 = nexti()
STAFF_FIRE                      = nexti()
STAFF_POISON                    = nexti()
STAFF_TUNNELING                 = nexti()
STAFF_BLINKING                  = nexti()
STAFF_ENTRANCEMENT              = nexti()
STAFF_OBSTRUCTION               = nexti()
STAFF_DISCORD                   = nexti()
STAFF_CONJURATION               = nexti()
STAFF_HEALING                   = nexti()
STAFF_HASTE                     = nexti()
STAFF_PROTECTION                = nexti()

i = -1
RING_CLAIRVOYANCE               = nexti()
RING_STEALTH                    = nexti()
RING_REGENERATION               = nexti()
RING_TRANSFERENCE               = nexti()
RING_LIGHT                      = nexti()
RING_AWARENESS                  = nexti()
RING_WISDOM                     = nexti()
RING_REAPING                    = nexti()

i = -1
CHARM_HEALTH                    = nexti()
CHARM_PROTECTION                = nexti()
CHARM_HASTE                     = nexti()
CHARM_FIRE_IMMUNITY             = nexti()
CHARM_INVISIBILITY              = nexti()
CHARM_TELEPATHY                 = nexti()
CHARM_LEVITATION                = nexti()
CHARM_SHATTERING                = nexti()
CHARM_GUARDIAN                  = nexti()
CHARM_TELEPORTATION             = nexti()
CHARM_RECHARGING                = nexti()
CHARM_NEGATION                  = nexti()

i = -1
SCROLL_ENCHANTING               = nexti()
SCROLL_IDENTIFY                 = nexti()
SCROLL_TELEPORT                 = nexti()
SCROLL_REMOVE_CURSE             = nexti()
SCROLL_RECHARGING               = nexti()
SCROLL_PROTECT_ARMOR            = nexti()
SCROLL_PROTECT_WEAPON           = nexti()
SCROLL_SANCTUARY                = nexti()
SCROLL_MAGIC_MAPPING            = nexti()
SCROLL_NEGATION                 = nexti()
SCROLL_SHATTERING               = nexti()
SCROLL_DISCORD                  = nexti()
SCROLL_AGGRAVATE_MONSTER        = nexti()
SCROLL_SUMMON_MONSTER           = nexti()


-- item runics
i = -1
W_SPEED                         = nexti()
W_QUIETUS                       = nexti()
W_PARALYSIS                     = nexti()
W_MULTIPLICITY                  = nexti()
W_SLOWING                       = nexti()
W_CONFUSION                     = nexti()
W_FORCE                         = nexti()
W_SLAYING                       = nexti()
W_MERCY                         = nexti()
W_PLENTY                        = nexti()

i = -1
A_MULTIPLICITY                  = nexti()
A_MUTUALITY                     = nexti()
A_ABSORPTION                    = nexti()
A_REPRISAL                      = nexti()
A_IMMUNITY                      = nexti()
A_REFLECTION                    = nexti()
A_RESPIRATION                   = nexti()
A_DAMPENING                     = nexti()
A_BURDEN                        = nexti()
A_VULNERABILITY                 = nexti()
A_IMMOLATION                    = nexti()
