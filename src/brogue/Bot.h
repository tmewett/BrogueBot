#define BROGUEBOT_VERSION_STRING "1.0-rc1"

extern char *botScript;
extern boolean botControl;
extern short botMode;

void resetBot(char *filename);
void nextBotEvent(rogueEvent *returnEvent);
void botReport();
void magicMapped();

void calculateDistancesNoClear (short **distanceMap,
                                unsigned long blockingTerrainFlags,
                                creature *traveler,
                                boolean canUseSecretDoors,
                                boolean eightWays);
