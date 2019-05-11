extern char *botScript;
extern boolean botControl;

void resetBot(char *filename);
void nextBotEvent(rogueEvent *returnEvent);

void calculateDistancesNoClear (short **distanceMap,
                                unsigned long blockingTerrainFlags,
                                creature *traveler,
                                boolean canUseSecretDoors,
                                boolean eightWays);
