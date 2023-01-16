local function Fl(n) return 1 << n end
local i
local function nexti() i = i + 1; return i end

-- dungeon width and height
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

UNREACHABLE = 30000     -- distance value indicating "infinity," i.e. that the cell cannot be reached


-- cell flags
DISCOVERED                  = Fl(0)
VISIBLE                     = Fl(1)    -- cell has sufficient light and is in field of view, ready to draw.
HAS_PLAYER                  = Fl(2)
IN_FIELD_OF_VIEW            = Fl(6)    -- player has unobstructed line of sight whether or not there is enough light
IS_IN_SHADOW                = Fl(10)   -- so that a player gains an automatic stealth bonus
MAGIC_MAPPED                = Fl(11)
ITEM_DETECTED               = Fl(12)   -- magic-detected item on cell
CLAIRVOYANT_VISIBLE         = Fl(13)
CLAIRVOYANT_DARKENED        = Fl(15)   -- magical blindness from a cursed ring of clairvoyance
CAUGHT_FIRE_THIS_TURN       = Fl(16)   -- so that fire does not spread asymmetrically
KNOWN_TO_BE_TRAP_FREE       = Fl(19)   -- keep track of where the player has stepped or watched monsters step as he knows no traps are there
TELEPATHIC_VISIBLE          = Fl(29)   -- potions of telepathy let you see through other creatures' eyes

-- ~ PERMANENT_TILE_FLAGS = (DISCOVERED | MAGIC_MAPPED | ITEM_DETECTED | HAS_ITEM | HAS_DORMANT_MONSTER
                        -- ~ | HAS_MONSTER | HAS_STAIRS | SEARCHED_FROM_HERE | PRESSURE_PLATE_DEPRESSED
                        -- ~ | STABLE_MEMORY | KNOWN_TO_BE_TRAP_FREE | IN_LOOP
                        -- ~ | IS_CHOKEPOINT | IS_GATE_SITE | IS_IN_MACHINE | IMPREGNABLE)

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
MA_HIT_BURN                     = Fl(2)    -- monster can hit to set you on fire
MA_ENTER_SUMMONS                = Fl(3)    -- monster will "become" its summoned leader, reappearing when that leader is defeated
MA_HIT_DEGRADE_ARMOR            = Fl(4)    -- monster damages armor
MA_CAST_SUMMON                  = Fl(5)    -- requires that there be one or more summon hordes with this monster type as the leader
MA_SEIZES                       = Fl(6)    -- monster seizes enemies before attacking
MA_POISONS                      = Fl(7)    -- monster's damage is dealt in the form of poison
MA_DF_ON_DEATH                  = Fl(8)    -- monster spawns its DF when it dies
MA_CLONE_SELF_ON_DEFEND         = Fl(9)    -- monster splits in two when struck
MA_KAMIKAZE                     = Fl(10)    -- monster dies instead of attacking
MA_TRANSFERENCE                 = Fl(11)   -- monster recovers 40 or 90% of the damage that it inflicts as health
MA_CAUSES_WEAKNESS              = Fl(12)   -- monster attacks cause weakness status in target
MA_ATTACKS_PENETRATE            = Fl(13)   -- monster attacks all adjacent enemies, like an axe
MA_ATTACKS_ALL_ADJACENT         = Fl(14)   -- monster attacks penetrate one layer of enemies, like a spear
MA_ATTACKS_EXTEND               = Fl(15)   -- monster attacks from a distance in a cardinal direction, like a whip
MA_ATTACKS_STAGGER              = Fl(16)   -- monster attacks will push the player backward by one space if there is room
MA_AVOID_CORRIDORS              = Fl(17)   -- monster will avoid corridors when hunting

SPECIAL_HIT                     = (MA_HIT_HALLUCINATE | MA_HIT_STEAL_FLEE | MA_HIT_DEGRADE_ARMOR | MA_POISONS
                                       | MA_TRANSFERENCE | MA_CAUSES_WEAKNESS | MA_HIT_BURN | MA_ATTACKS_STAGGER)
LEARNABLE_ABILITIES             = (MA_TRANSFERENCE | MA_CAUSES_WEAKNESS)

MA_NON_NEGATABLE_ABILITIES      = (MA_ATTACKS_PENETRATE | MA_ATTACKS_ALL_ADJACENT | MA_ATTACKS_EXTEND | MA_ATTACKS_STAGGER)
MA_NEVER_VORPAL_ENEMY           = (MA_KAMIKAZE)
MA_NEVER_MUTATED                = (MA_KAMIKAZE)


-- monster bookkeeping flags. only a few are actually given
MB_TELEPATHICALLY_REVEALED  = Fl(1)    -- player can magically see monster and adjacent cells
MB_CAPTIVE                  = Fl(8)    -- monster is all tied up
MB_SEIZED                   = Fl(9)    -- monster is being held
MB_SEIZING                  = Fl(10)   -- monster is holding another creature immobile
MB_SUBMERGED                = Fl(11)   -- monster is currently submerged and hence invisible until it attacks
MB_ABSORBING                = Fl(16)   -- currently learning a skill by absorbing an enemy corpse
MB_HAS_SOUL                 = Fl(22)   -- slaying the monster will count toward weapon auto-ID
MB_ALREADY_SEEN             = Fl(23)   -- seeing this monster won't interrupt exploration


-- monster states
i = -1
MONSTER_SLEEPING                = nexti()
MONSTER_HUNTING                 = nexti()  -- (MONSTER_TRACKING_SCENT internally)
MONSTER_WANDERING               = nexti()
MONSTER_FLEEING                 = nexti()
MONSTER_ALLY                    = nexti()


-- creature status effect indices
i = 0 -- start from 1 as these are table indices
STATUS_DONNING                  = nexti()
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
STATUS_ENRAGED                  = nexti() -- temporarily ignores normal MA_AVOID_CORRIDORS behavior
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
ITEM_CURSED             = Fl(2)    -- the item contains a "malevolent force," which prevents removing it. only given when known
ITEM_PROTECTED          = Fl(3)
ITEM_CAN_BE_IDENTIFIED  = Fl(8)
ITEM_PREPLACED          = Fl(9)
ITEM_FLAMMABLE          = Fl(10)
ITEM_MAGIC_DETECTED     = Fl(11)
ITEM_IS_KEY             = Fl(13)

ITEM_ATTACKS_STAGGER    = Fl(14)   -- mace, hammer
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


-- creature types
i = -1
PLAYER                          = nexti()
RAT                             = nexti()
KOBOLD                          = nexti()
JACKAL                          = nexti()
EEL                             = nexti()
MONKEY                          = nexti()
BLOAT                           = nexti()
PIT_BLOAT                       = nexti()
GOBLIN                          = nexti()
GOBLIN_CONJURER                 = nexti()
GOBLIN_MYSTIC                   = nexti()
GOBLIN_TOTEM                    = nexti()
PINK_JELLY                      = nexti()
TOAD                            = nexti()
VAMPIRE_BAT                     = nexti()
ARROW_TURRET                    = nexti()
ACID_MOUND                      = nexti()
CENTIPEDE                       = nexti()
OGRE                            = nexti()
BOG_MONSTER                     = nexti()
OGRE_TOTEM                      = nexti()
SPIDER                          = nexti()
SPARK_TURRET                    = nexti()
WILL_O_THE_WISP                 = nexti()
WRAITH                          = nexti()
ZOMBIE                          = nexti()
TROLL                           = nexti()
OGRE_SHAMAN                     = nexti()
NAGA                            = nexti()
SALAMANDER                      = nexti()
EXPLOSIVE_BLOAT                 = nexti()
DAR_BLADEMASTER                 = nexti()
DAR_PRIESTESS                   = nexti()
DAR_BATTLEMAGE                  = nexti()
ACID_JELLY                      = nexti()
CENTAUR                         = nexti()
UNDERWORM                       = nexti()
SENTINEL                        = nexti()
DART_TURRET                     = nexti()
KRAKEN                          = nexti()
LICH                            = nexti()
PHYLACTERY                      = nexti()
PIXIE                           = nexti()
PHANTOM                         = nexti()
FLAME_TURRET                    = nexti()
IMP                             = nexti()
FURY                            = nexti()
REVENANT                        = nexti()
TENTACLE_HORROR                 = nexti()
GOLEM                           = nexti()
DRAGON                          = nexti()
GOBLIN_WARLORD                  = nexti()
BLACK_JELLY                     = nexti()
VAMPIRE                         = nexti()
FLAMEDANCER                     = nexti()
SPECTRAL_BLADE                  = nexti()
SPECTRAL_SWORD                  = nexti()
GUARDIAN                        = nexti()
WINGED_GUARDIAN                 = nexti()
CHARM_GUARDIAN                  = nexti()
WARDEN_OF_YENDOR                = nexti()
ELDRITCH_TOTEM                  = nexti()
MIRRORED_TOTEM                  = nexti()
UNICORN                         = nexti()
IFRIT                           = nexti()
PHOENIX                         = nexti()
PHOENIX_EGG                     = nexti()
MANGROVE_DRYAD                  = nexti()


-- tile types
-- I'm really not sure what many of these are, they are just here in case you need to know a specific tile.
-- Most tile behaviours are determined completely by its tile flags; the only other thing are its dungeon features (not given yet)
-- There will likely be some future BrogueBot update to how tiles are given.
i = -1
NOTHING                                 = nexti()
GRANITE                                 = nexti()
FLOOR                                   = nexti()
FLOOR_FLOODABLE                         = nexti()
CARPET                                  = nexti()
MARBLE_FLOOR                            = nexti()
WALL                                    = nexti()
DOOR                                    = nexti()
OPEN_DOOR                               = nexti()
SECRET_DOOR                             = nexti()
LOCKED_DOOR                             = nexti()
OPEN_IRON_DOOR_INERT                    = nexti()
DOWN_STAIRS                             = nexti()
UP_STAIRS                               = nexti()
DUNGEON_EXIT                            = nexti()
DUNGEON_PORTAL                          = nexti()
TORCH_WALL                              = nexti()
CRYSTAL_WALL                            = nexti()
PORTCULLIS_CLOSED                       = nexti()
PORTCULLIS_DORMANT                      = nexti()
WOODEN_BARRICADE                        = nexti()
PILOT_LIGHT_DORMANT                     = nexti()
PILOT_LIGHT                             = nexti()
HAUNTED_TORCH_DORMANT                   = nexti()
HAUNTED_TORCH_TRANSITIONING             = nexti()
HAUNTED_TORCH                           = nexti()
WALL_LEVER_HIDDEN                       = nexti()
WALL_LEVER                              = nexti()
WALL_LEVER_PULLED                       = nexti()
WALL_LEVER_HIDDEN_DORMANT               = nexti()
STATUE_INERT                            = nexti()
STATUE_DORMANT                          = nexti()
STATUE_CRACKING                         = nexti()
STATUE_INSTACRACK                       = nexti()
PORTAL                                  = nexti()
TURRET_DORMANT                          = nexti()
WALL_MONSTER_DORMANT                    = nexti()
DARK_FLOOR_DORMANT                      = nexti()
DARK_FLOOR_DARKENING                    = nexti()
DARK_FLOOR                              = nexti()
MACHINE_TRIGGER_FLOOR                   = nexti()
ALTAR_INERT                             = nexti()
ALTAR_KEYHOLE                           = nexti()
ALTAR_CAGE_OPEN                         = nexti()
ALTAR_CAGE_CLOSED                       = nexti()
ALTAR_SWITCH                            = nexti()
ALTAR_SWITCH_RETRACTING                 = nexti()
ALTAR_CAGE_RETRACTABLE                  = nexti()
PEDESTAL                                = nexti()
MONSTER_CAGE_OPEN                       = nexti()
MONSTER_CAGE_CLOSED                     = nexti()
COFFIN_CLOSED                           = nexti()
COFFIN_OPEN                             = nexti()
GAS_TRAP_POISON_HIDDEN                  = nexti()
GAS_TRAP_POISON                         = nexti()
TRAP_DOOR_HIDDEN                        = nexti()
TRAP_DOOR                               = nexti()
GAS_TRAP_PARALYSIS_HIDDEN               = nexti()
GAS_TRAP_PARALYSIS                      = nexti()
MACHINE_PARALYSIS_VENT_HIDDEN           = nexti()
MACHINE_PARALYSIS_VENT                  = nexti()
GAS_TRAP_CONFUSION_HIDDEN               = nexti()
GAS_TRAP_CONFUSION                      = nexti()
FLAMETHROWER_HIDDEN                     = nexti()
FLAMETHROWER                            = nexti()
FLOOD_TRAP_HIDDEN                       = nexti()
FLOOD_TRAP                              = nexti()
NET_TRAP_HIDDEN                         = nexti()
NET_TRAP                                = nexti()
ALARM_TRAP_HIDDEN                       = nexti()
ALARM_TRAP                              = nexti()
MACHINE_POISON_GAS_VENT_HIDDEN          = nexti()
MACHINE_POISON_GAS_VENT_DORMANT         = nexti()
MACHINE_POISON_GAS_VENT                 = nexti()
MACHINE_METHANE_VENT_HIDDEN             = nexti()
MACHINE_METHANE_VENT_DORMANT            = nexti()
MACHINE_METHANE_VENT                    = nexti()
STEAM_VENT                              = nexti()
MACHINE_PRESSURE_PLATE                  = nexti()
MACHINE_PRESSURE_PLATE_USED             = nexti()
MACHINE_GLYPH                           = nexti()
MACHINE_GLYPH_INACTIVE                  = nexti()
DEWAR_CAUSTIC_GAS                       = nexti()
DEWAR_CONFUSION_GAS                     = nexti()
DEWAR_PARALYSIS_GAS                     = nexti()
DEWAR_METHANE_GAS                       = nexti()
DEEP_WATER                              = nexti()
SHALLOW_WATER                           = nexti()
MUD                                     = nexti()
CHASM                                   = nexti()
CHASM_EDGE                              = nexti()
MACHINE_COLLAPSE_EDGE_DORMANT           = nexti()
MACHINE_COLLAPSE_EDGE_SPREADING         = nexti()
LAVA                                    = nexti()
LAVA_RETRACTABLE                        = nexti()
LAVA_RETRACTING                         = nexti()
SUNLIGHT_POOL                           = nexti()
DARKNESS_PATCH                          = nexti()
ACTIVE_BRIMSTONE                        = nexti()
INERT_BRIMSTONE                         = nexti()
OBSIDIAN                                = nexti()
BRIDGE                                  = nexti()
BRIDGE_FALLING                          = nexti()
BRIDGE_EDGE                             = nexti()
STONE_BRIDGE                            = nexti()
MACHINE_FLOOD_WATER_DORMANT             = nexti()
MACHINE_FLOOD_WATER_SPREADING           = nexti()
MACHINE_MUD_DORMANT                     = nexti()
ICE_DEEP                                = nexti()
ICE_DEEP_MELT                           = nexti()
ICE_SHALLOW                             = nexti()
ICE_SHALLOW_MELT                        = nexti()
HOLE                                    = nexti()
HOLE_GLOW                               = nexti()
HOLE_EDGE                               = nexti()
FLOOD_WATER_DEEP                        = nexti()
FLOOD_WATER_SHALLOW                     = nexti()
GRASS                                   = nexti()
DEAD_GRASS                              = nexti()
GRAY_FUNGUS                             = nexti()
LUMINESCENT_FUNGUS                      = nexti()
LICHEN                                  = nexti()
HAY                                     = nexti()
RED_BLOOD                               = nexti()
GREEN_BLOOD                             = nexti()
PURPLE_BLOOD                            = nexti()
ACID_SPLATTER                           = nexti()
VOMIT                                   = nexti()
URINE                                   = nexti()
UNICORN_POOP                            = nexti()
WORM_BLOOD                              = nexti()
ASH                                     = nexti()
BURNED_CARPET                           = nexti()
PUDDLE                                  = nexti()
BONES                                   = nexti()
RUBBLE                                  = nexti()
JUNK                                    = nexti()
BROKEN_GLASS                            = nexti()
ECTOPLASM                               = nexti()
EMBERS                                  = nexti()
SPIDERWEB                               = nexti()
NETTING                                 = nexti()
FOLIAGE                                 = nexti()
DEAD_FOLIAGE                            = nexti()
TRAMPLED_FOLIAGE                        = nexti()
FUNGUS_FOREST                           = nexti()
TRAMPLED_FUNGUS_FOREST                  = nexti()
FORCEFIELD                              = nexti()
FORCEFIELD_MELT                         = nexti()
SACRED_GLYPH                            = nexti()
MANACLE_TL                              = nexti()
MANACLE_BR                              = nexti()
MANACLE_TR                              = nexti()
MANACLE_BL                              = nexti()
MANACLE_T                               = nexti()
MANACLE_B                               = nexti()
MANACLE_L                               = nexti()
MANACLE_R                               = nexti()
PORTAL_LIGHT                            = nexti()
GUARDIAN_GLOW                           = nexti()
PLAIN_FIRE                              = nexti()
BRIMSTONE_FIRE                          = nexti()
FLAMEDANCER_FIRE                        = nexti()
GAS_FIRE                                = nexti()
GAS_EXPLOSION                           = nexti()
DART_EXPLOSION                          = nexti()
ITEM_FIRE                               = nexti()
CREATURE_FIRE                           = nexti()
POISON_GAS                              = nexti()
CONFUSION_GAS                           = nexti()
ROT_GAS                                 = nexti()
STENCH_SMOKE_GAS                        = nexti()
PARALYSIS_GAS                           = nexti()
METHANE_GAS                             = nexti()
STEAM                                   = nexti()
DARKNESS_CLOUD                          = nexti()
HEALING_CLOUD                           = nexti()
BLOODFLOWER_STALK                       = nexti()
BLOODFLOWER_POD                         = nexti()
HAVEN_BEDROLL                           = nexti()
DEEP_WATER_ALGAE_WELL                   = nexti()
DEEP_WATER_ALGAE_1                      = nexti()
DEEP_WATER_ALGAE_2                      = nexti()
ANCIENT_SPIRIT_VINES                    = nexti()
ANCIENT_SPIRIT_GRASS                    = nexti()
AMULET_SWITCH                           = nexti()
COMMUTATION_ALTAR                       = nexti()
COMMUTATION_ALTAR_INERT                 = nexti()
PIPE_GLOWING                            = nexti()
PIPE_INERT                              = nexti()
RESURRECTION_ALTAR                      = nexti()
RESURRECTION_ALTAR_INERT                = nexti()
MACHINE_TRIGGER_FLOOR_REPEATING         = nexti()
SACRIFICE_ALTAR_DORMANT                 = nexti()
SACRIFICE_ALTAR                         = nexti()
SACRIFICE_LAVA                          = nexti()
SACRIFICE_CAGE_DORMANT                  = nexti()
DEMONIC_STATUE                          = nexti()
STATUE_INERT_DOORWAY                    = nexti()
STATUE_DORMANT_DOORWAY                  = nexti()
CHASM_WITH_HIDDEN_BRIDGE                = nexti()
CHASM_WITH_HIDDEN_BRIDGE_ACTIVE         = nexti()
MACHINE_CHASM_EDGE                      = nexti()
RAT_TRAP_WALL_DORMANT                   = nexti()
RAT_TRAP_WALL_CRACKING                  = nexti()
ELECTRIC_CRYSTAL_OFF                    = nexti()
ELECTRIC_CRYSTAL_ON                     = nexti()
TURRET_LEVER                            = nexti()
WORM_TUNNEL_MARKER_DORMANT              = nexti()
WORM_TUNNEL_MARKER_ACTIVE               = nexti()
WORM_TUNNEL_OUTER_WALL                  = nexti()
BRAZIER                                 = nexti()
MUD_FLOOR                               = nexti()
MUD_WALL                                = nexti()
MUD_DOORWAY                             = nexti()
