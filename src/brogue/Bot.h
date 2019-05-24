#define BROGUEBOT_VERSION_STRING "1.0-rc1"

extern char *botScript;
extern boolean botControl;

void resetBot(char *filename);
void nextBotEvent(rogueEvent *returnEvent);
void magicMapped();

void calculateDistancesNoClear (short **distanceMap,
                                unsigned long blockingTerrainFlags,
                                creature *traveler,
                                boolean canUseSecretDoors,
                                boolean eightWays);
